import CryptoKit
import Foundation
import GRDB

/// Own one instance per library. All mutations are serialized away from the main actor.
public actor DocumentLibrary {
    let database: DatabaseQueue
    private let documentsURL: URL
    private let stagingURL: URL
    private let maximumImportBytes: Int

    public init(directory: URL, maximumImportBytes: Int = 2_147_483_648) throws {
        guard directory.isFileURL, maximumImportBytes > 0 else {
            throw LibraryError.invalidInput("A local library directory and positive import limit are required.")
        }
        let root = directory.standardizedFileURL
        self.documentsURL = root.appendingPathComponent("Documents", isDirectory: true)
        self.stagingURL = root.appendingPathComponent("Staging", isDirectory: true)
        self.maximumImportBytes = maximumImportBytes
        for url in [root, documentsURL, stagingURL] {
            try FileManager.default.createDirectory(
                at: url, withIntermediateDirectories: true,
                attributes: [.posixPermissions: 0o700]
            )
        }
        self.database = try LibraryDatabase.open(at: root.appendingPathComponent("Library.sqlite"))
    }

    /// Streams the source into owned storage; originals are never modified.
    /// The file is installed before its database record, so an interrupted import
    /// can leave an orphan file but never a committed record pointing at half a file.
    public func importDocument(from source: URL, title: String? = nil) throws -> ImportResult {
        try Task.checkCancellation()
        guard source.isFileURL else { throw LibraryError.sourceIsNotAFile }
        let scoped = source.startAccessingSecurityScopedResource()
        defer { if scoped { source.stopAccessingSecurityScopedResource() } }
        let format = try DocumentFormat(fileExtension: source.pathExtension)
        let information = try source.resourceValues(forKeys: [.isRegularFileKey, .fileSizeKey])
        guard information.isRegularFile == true else { throw LibraryError.sourceIsNotAFile }
        guard (information.fileSize ?? 0) <= maximumImportBytes else { throw LibraryError.sourceTooLarge }
        let documentTitle = (title ?? source.deletingPathExtension().lastPathComponent)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !documentTitle.isEmpty, documentTitle.count <= 4_096 else {
            throw LibraryError.invalidInput("Document title is empty or too long.")
        }

        let id = UUID()
        let stage = stagingURL.appendingPathComponent(id.uuidString)
        defer { try? FileManager.default.removeItem(at: stage) }
        let revision = try copyAndHash(from: source, to: stage)
        let fileName = id.uuidString + "." + source.pathExtension.lowercased()
        let destination = documentsURL.appendingPathComponent(fileName)
        try Task.checkCancellation()
        try FileManager.default.moveItem(at: stage, to: destination)
        do {
            try Task.checkCancellation()
            let now = Date().timeIntervalSince1970
            let document = try database.write { db -> LibraryDocument in
                try db.execute(sql: """
                    INSERT INTO documents (id, title, format, revision, fileName, importedAt)
                    VALUES (?, ?, ?, ?, ?, ?)
                    ON CONFLICT(revision, format) DO NOTHING
                    """, arguments: [id.uuidString, documentTitle, format.rawValue, revision, fileName, now])
                guard let row = try Row.fetchOne(
                    db, sql: "SELECT * FROM documents WHERE revision = ? AND format = ?",
                    arguments: [revision, format.rawValue]
                ) else { throw LibraryError.corruptStoredData }
                return try LibraryDatabase.document(row)
            }
            if document.id != id { try FileManager.default.removeItem(at: destination) }
            return ImportResult(document: document, alreadyImported: document.id != id)
        } catch {
            try? FileManager.default.removeItem(at: destination)
            throw error
        }
    }

    public func documents(inTrash: Bool = false) throws -> [LibraryDocument] {
        try database.read { db in
            let predicate = inTrash ? "IS NOT NULL" : "IS NULL"
            return try Row.fetchAll(
                db, sql: "SELECT * FROM documents WHERE trashedAt \(predicate) ORDER BY importedAt DESC, id"
            ).map(LibraryDatabase.document)
        }
    }

    public func document(id: UUID) throws -> LibraryDocument {
        try database.read { try LibraryDatabase.document(requireDocument(id, in: $0)) }
    }

    /// Read-only access for format adapters; editing must use a future revision-aware API.
    public func contentURL(for id: UUID) throws -> URL {
        try database.read { db in
            let row = try requireDocument(id, in: db, active: true)
            let name: String = row["fileName"]
            guard name == URL(fileURLWithPath: name).lastPathComponent, !name.isEmpty else {
                throw LibraryError.corruptStoredData
            }
            return documentsURL.appendingPathComponent(name)
        }
    }

    /// Trash is a database state change. Associated state and owned files stay intact.
    public func trashDocument(id: UUID) throws {
        try database.write { db in
            _ = try requireDocument(id, in: db)
            try db.execute(
                sql: "UPDATE documents SET trashedAt = COALESCE(trashedAt, ?) WHERE id = ?",
                arguments: [Date().timeIntervalSince1970, id.uuidString]
            )
        }
    }

    public func restoreDocument(id: UUID) throws {
        try database.write { db in
            _ = try requireDocument(id, in: db)
            try db.execute(sql: "UPDATE documents SET trashedAt = NULL WHERE id = ?", arguments: [id.uuidString])
        }
    }

    public func saveReadingState(_ state: ReadingState) throws {
        guard state.progression.isFinite, (0...1).contains(state.progression) else {
            throw LibraryError.invalidInput("Reading progression must be between zero and one.")
        }
        try database.write { db in
            try validate(state.anchor, in: db)
            try db.execute(sql: """
                INSERT INTO readingState (documentID, payload) VALUES (?, ?)
                ON CONFLICT(documentID) DO UPDATE SET payload = excluded.payload
                """, arguments: [state.anchor.documentID.uuidString, try LibraryDatabase.encode(state)])
        }
    }

    public func readingState(for documentID: UUID) throws -> ReadingState? {
        try database.read { db in
            _ = try requireDocument(documentID, in: db)
            return try Data.fetchOne(
                db, sql: "SELECT payload FROM readingState WHERE documentID = ?", arguments: [documentID.uuidString]
            ).map { try JSONDecoder().decode(ReadingState.self, from: $0) }
        }
    }

    private func requireDocument(_ id: UUID, in db: Database, active: Bool = false) throws -> Row {
        guard let row = try Row.fetchOne(db, sql: "SELECT * FROM documents WHERE id = ?", arguments: [id.uuidString]) else {
            throw LibraryError.documentNotFound
        }
        let trashed: Double? = row["trashedAt"]
        if active, trashed != nil { throw LibraryError.documentInTrash }
        return row
    }

    func validate(_ anchor: SourceAnchor, in db: Database) throws {
        let row = try requireDocument(anchor.documentID, in: db, active: true)
        let revision: String = row["revision"]
        guard revision == anchor.revision else { throw LibraryError.revisionMismatch }
        let format = DocumentFormat(rawValue: row["format"])
        switch (format, anchor.resource) {
        case (.plainText, .text), (.markdown, .text), (.pdf, .pdfPage),
             (.epub, .epub), (.html, .article): break
        default: throw LibraryError.invalidInput("Source resource does not match the document format.")
        }
        guard anchor.utf16Length == anchor.quote.utf16.count,
              anchor.prefix.count <= 48, anchor.suffix.count <= 48 else {
            throw LibraryError.invalidInput("Malformed source anchor.")
        }
        _ = try SourceAnchor(
            documentID: anchor.documentID, revision: anchor.revision, resource: anchor.resource,
            text: anchor.quote,
            selection: NSRange(location: 0, length: anchor.utf16Length), resourceOffset: anchor.utf16Offset
        )
    }

    private func copyAndHash(from source: URL, to destination: URL) throws -> String {
        guard FileManager.default.createFile(atPath: destination.path, contents: nil) else {
            throw CocoaError(.fileWriteUnknown)
        }
        let input = try FileHandle(forReadingFrom: source)
        defer { try? input.close() }
        let output = try FileHandle(forWritingTo: destination)
        defer { try? output.close() }
        var hasher = SHA256()
        var size = 0
        while true {
            try Task.checkCancellation()
            let count = try autoreleasepool {
                let chunk = try input.read(upToCount: 1_048_576) ?? Data()
                guard chunk.count <= maximumImportBytes - size else { throw LibraryError.sourceTooLarge }
                hasher.update(data: chunk)
                try output.write(contentsOf: chunk)
                return chunk.count
            }
            if count == 0 { break }
            size += count
        }
        try output.synchronize()
        return hasher.finalize().map { String(format: "%02x", $0) }.joined()
    }
}
