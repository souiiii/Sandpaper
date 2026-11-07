import Foundation

public struct WorkspaceReader: Sendable {
    public let document: ReadingDocument
    public let session: ReaderSession
    /// Snapshot at opening. Progress continues to be saved through ReaderSession.
    public let initialPosition: ReadingPosition?
}

public struct ReaderRestorationIssue: Sendable {
    public let documentID: UUID
    public let message: String
}

public enum WorkspaceError: Error, Equatable, Sendable { case closed, invalidSessionFile, tooManyOpenDocuments }

/// Owns app-lifetime readers without owning windows, presentation or model processes.
public actor ReaderWorkspace {
    public nonisolated let library: DocumentLibrary
    private let stateURL: URL
    private let dictionary: any LocalDictionary
    private let engine: any LocalAnalysisEngine
    private var opened: [UUID: WorkspaceReader] = [:]
    private var order: [UUID] = []
    private var closeVersions: [UUID: Int] = [:]
    private var isClosed = false

    public init(directory: URL, dictionary: any LocalDictionary = MacOSDictionary(),
        engine: any LocalAnalysisEngine = UnconfiguredLocalEngine()) throws {
        library = try DocumentLibrary(directory: directory)
        stateURL = directory.appendingPathComponent("OpenReaders.json")
        self.dictionary = dictionary; self.engine = engine
    }

    public func readers() -> [WorkspaceReader] { order.compactMap { opened[$0] } }

    public func open(from url: URL) async throws -> WorkspaceReader {
        guard !isClosed else { throw WorkspaceError.closed }
        let document = try await library.importDocument(from: url).document
        try Task.checkCancellation()
        return try await open(documentID: document.id)
    }

    public func open(documentID: UUID) async throws -> WorkspaceReader {
        guard !isClosed else { throw WorkspaceError.closed }
        try Task.checkCancellation()
        if let existing = opened[documentID] { return existing }
        guard order.contains(documentID) || order.count < 256 else { throw WorkspaceError.tooManyOpenDocuments }
        let version = closeVersions[documentID, default: 0]
        let session = ReaderSession(library: library, dictionary: dictionary, engine: engine)
        do {
            let document = try await session.open(documentID: documentID)
            let position = try await library.readingPosition(for: documentID)
            try Task.checkCancellation()
            guard !isClosed, closeVersions[documentID, default: 0] == version else { throw CancellationError() }
            // Concurrent open requests share the reader that finished first.
            if let existing = opened[documentID] { await session.close(); return existing }
            guard order.contains(documentID) || order.count < 256 else { throw WorkspaceError.tooManyOpenDocuments }
            let reader = WorkspaceReader(document: document, session: session, initialPosition: position)
            opened[documentID] = reader
            if !order.contains(documentID) { order.append(documentID) }
            do { try persist() }
            catch { opened.removeValue(forKey: documentID); order.removeAll { $0 == documentID }; throw error }
            return reader
        } catch {
            await session.close()
            throw error
        }
    }

    /// A bad/missing book does not prevent the other saved readers from reopening.
    /// A corrupt session file is reported without changing library/vocabulary data.
    public func restore() async throws -> [ReaderRestorationIssue] {
        guard !isClosed else { throw WorkspaceError.closed }
        guard FileManager.default.fileExists(atPath: stateURL.path) else { return [] }
        let handle = try FileHandle(forReadingFrom: stateURL)
        defer { try? handle.close() }
        let data = try handle.read(upToCount: 65_537) ?? Data()
        guard data.count <= 65_536, let ids = try? JSONDecoder().decode([UUID].self, from: data),
              ids.count <= 256, Set(ids).count == ids.count else { throw WorkspaceError.invalidSessionFile }
        // Retain not-yet-restored readers if launch is interrupted partway through.
        let restoredOrder = order + ids.filter { !order.contains($0) }
        guard restoredOrder.count <= 256 else { throw WorkspaceError.tooManyOpenDocuments }
        order = restoredOrder
        var issues: [ReaderRestorationIssue] = []
        for id in ids {
            try Task.checkCancellation()
            guard !isClosed else { throw WorkspaceError.closed }
            if !order.contains(id) { continue }
            do { _ = try await open(documentID: id) }
            catch is CancellationError { throw CancellationError() }
            catch {
                order.removeAll { $0 == id }
                issues.append(ReaderRestorationIssue(documentID: id, message: String(describing: error)))
            }
        }
        try persist()
        return issues
    }

    public func close(documentID: UUID) async throws {
        guard !isClosed else { throw WorkspaceError.closed }
        closeVersions[documentID, default: 0] += 1
        let reader = opened.removeValue(forKey: documentID)
        order.removeAll { $0 == documentID }
        do { try persist() }
        catch { await reader?.session.close(); throw error }
        await reader?.session.close()
    }

    /// Preserves the open-document list for the next launch, but releases live readers.
    public func shutdown() async throws {
        guard !isClosed else { return }
        isClosed = true
        let readers = opened.values.map(\.session)
        opened.removeAll()
        let saveError: (any Error)?
        do { try persist(); saveError = nil } catch { saveError = error }
        for reader in readers { await reader.close() }
        if let saveError { throw saveError }
    }

    private func persist() throws {
        try JSONEncoder().encode(order).write(to: stateURL, options: .atomic)
    }
}
