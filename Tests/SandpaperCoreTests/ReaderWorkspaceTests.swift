import Foundation
import Testing
@testable import SandpaperCore

struct ReaderWorkspaceTests {
    private func fixture() throws -> (URL, URL) {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        let file = root.appendingPathComponent("book.txt")
        try Data("The agreement fell through.\n\nAnother passage follows.".utf8).write(to: file)
        return (root, file)
    }

    @Test func workspaceRestoresReadersAndExactSavedPassagesWithoutAI() async throws {
        let (root, file) = try fixture(); defer { try? FileManager.default.removeItem(at: root) }
        let location = root.appendingPathComponent("Library")
        let engine = SelectionProbeEngine()
        let workspace = try ReaderWorkspace(directory: location, dictionary: WorkspaceDictionary(), engine: engine)
        let reader = try await workspace.open(from: file)
        let documentID = reader.document.document.id
        let content = try await reader.session.content(for: .text)
        let range = (content.text as NSString).range(of: "fell through")
        let selection = try await reader.session.select(documentID: documentID, resource: .text, range: range)
        let entry = try #require(await reader.session.lookup(selectionID: selection.id).first)
        let saved = try await reader.session.save(selectionID: selection.id,
            meaning: .dictionary(entryID: entry.id, range: NSRange(location: 0, length: entry.text.utf16.count)))
        let bookmark = try await reader.session.bookmark(documentID: documentID, resource: .text, range: range, title: "Agreement")
        try await reader.session.recordProgress(documentID: documentID, resource: .text, visibleRange: range, progression: 0.4)
        try await workspace.shutdown()
        await #expect(throws: ReaderError.noOpenDocument) { try await reader.session.content(for: .text) }
        await #expect(throws: WorkspaceError.closed) { try await workspace.open(from: file) }

        let next = try ReaderWorkspace(directory: location, engine: engine)
        #expect(try await next.restore().isEmpty)
        let restored = try #require(await next.readers().first)
        #expect(restored.document.document.id == documentID)
        #expect(restored.initialPosition?.progression == 0.4)
        let occurrence = try await next.library.occurrence(id: saved.id)
        #expect(try await restored.session.navigate(to: occurrence).resolution == .exact(range))
        #expect(try await restored.session.navigate(to: bookmark.position).resolution == .exact(range))
        #expect(await engine.calls == 0); #expect(await engine.availabilityCalls == 0)
        try await next.close(documentID: documentID)
        let afterClose = try ReaderWorkspace(directory: location)
        #expect(try await afterClose.restore().isEmpty)
        #expect(await afterClose.readers().isEmpty)
    }

    @Test func duplicateConcurrentOpenRequestsReuseOneReader() async throws {
        let (root, file) = try fixture(); defer { try? FileManager.default.removeItem(at: root) }
        let workspace = try ReaderWorkspace(directory: root.appendingPathComponent("Library"))
        async let first = workspace.open(from: file)
        async let second = workspace.open(from: file)
        let (a, b) = try await (first, second)
        #expect(a.document.document.id == b.document.document.id)
        #expect(a.session === b.session)
        #expect(await workspace.readers().count == 1)
        #expect(try await workspace.library.documents().count == 1)
        try await workspace.shutdown()
    }

    @Test func missingOrTrashedRestoredBookDoesNotBlockOtherBooks() async throws {
        let (root, file) = try fixture(); defer { try? FileManager.default.removeItem(at: root) }
        let other = root.appendingPathComponent("other.md")
        try Data("# Other book\n\nA valid paragraph.".utf8).write(to: other)
        let location = root.appendingPathComponent("Library")
        let first = try ReaderWorkspace(directory: location)
        let a = try await first.open(from: file)
        let b = try await first.open(from: other)
        try await first.shutdown()
        try await first.library.trashDocument(id: a.document.document.id)
        let restored = try ReaderWorkspace(directory: location)
        let issues = try await restored.restore()
        #expect(issues.map(\.documentID) == [a.document.document.id])
        #expect(await restored.readers().map { $0.document.document.id } == [b.document.document.id])
        try await restored.shutdown()
    }

    @Test func corruptSessionListLeavesTheLibraryUsable() async throws {
        let (root, file) = try fixture(); defer { try? FileManager.default.removeItem(at: root) }
        let location = root.appendingPathComponent("Library")
        let workspace = try ReaderWorkspace(directory: location)
        try Data("not JSON".utf8).write(to: location.appendingPathComponent("OpenReaders.json"))
        await #expect(throws: WorkspaceError.invalidSessionFile) { try await workspace.restore() }
        let opened = try await workspace.open(from: file)
        #expect(try await opened.session.content(for: .text).text.contains("fell through"))
        try await workspace.shutdown()
    }

    @Test func workspaceKeepsExistingAIExplicitAndOptional() async throws {
        let (root, file) = try fixture(); defer { try? FileManager.default.removeItem(at: root) }
        let engine = SelectionProbeEngine()
        let workspace = try ReaderWorkspace(directory: root.appendingPathComponent("Library"), engine: engine)
        let reader = try await workspace.open(from: file)
        let content = try await reader.session.content(for: .text)
        let selection = try await reader.session.select(documentID: reader.document.document.id, resource: .text,
            range: (content.text as NSString).range(of: "fell through"))
        #expect(await engine.calls == 0); #expect(await engine.availabilityCalls == 0)
        _ = try await reader.session.explain(selectionID: selection.id)
        #expect(await engine.calls == 1)
        try await workspace.shutdown()
    }

    @Test func missingAIStillAllowsDictionarySavingAndReturnToPassage() async throws {
        let (root, file) = try fixture(); defer { try? FileManager.default.removeItem(at: root) }
        let workspace = try ReaderWorkspace(directory: root.appendingPathComponent("Library"), dictionary: WorkspaceDictionary())
        let reader = try await workspace.open(from: file)
        let text = try await reader.session.content(for: .text).text
        let range = (text as NSString).range(of: "fell through")
        let selection = try await reader.session.select(documentID: reader.document.document.id, resource: .text, range: range)
        await #expect(throws: AnalysisError.modelNotConfigured) { try await reader.session.explain(selectionID: selection.id) }
        let entry = try #require(await reader.session.lookup(selectionID: selection.id).first)
        let saved = try await reader.session.save(selectionID: selection.id,
            meaning: .dictionary(entryID: entry.id, range: NSRange(location: 0, length: entry.text.utf16.count)))
        #expect(try await reader.session.navigate(to: saved).resolution == .exact(range))
        try await workspace.shutdown()
    }

    @Test(arguments: [false, true]) func navigationClearsOldSelectionAndCancelsItsExplanation(useContents: Bool) async throws {
        let (root, file) = try fixture(); defer { try? FileManager.default.removeItem(at: root) }
        let engine = SelectionProbeEngine(holdFirst: true)
        let workspace = try ReaderWorkspace(directory: root.appendingPathComponent("Library"), engine: engine)
        let reader = try await workspace.open(from: file)
        let content = try await reader.session.content(for: .text)
        let id = reader.document.document.id
        let selection = try await reader.session.select(documentID: id, resource: .text,
            range: (content.text as NSString).range(of: "fell through"))
        let explanation = Task { try await reader.session.explain(selectionID: selection.id) }
        await engine.waitForStart()
        if useContents {
            _ = try await reader.session.navigate(to: ReadingNavigationItem(title: "Start", resource: .text, fragment: nil, depth: 0))
        } else {
            let range = (content.text as NSString).range(of: "Another")
            let position = try ReadingPosition(documentID: id, revision: content.revision, resource: .text,
                anchor: content.anchor(for: range), progression: 0.5)
            #expect(try await reader.session.navigate(to: position).resolution == .exact(range))
        }
        do { _ = try await explanation.value; Issue.record("Navigation retained old AI work") } catch is CancellationError {}
        await #expect(throws: ReaderError.staleSelection) { try await reader.session.lookup(selectionID: selection.id) }
        try await workspace.shutdown()
    }

    @Test func closingReaderCancelsAIAndInvalidatesSelection() async throws {
        let (root, file) = try fixture(); defer { try? FileManager.default.removeItem(at: root) }
        let engine = SelectionProbeEngine(holdFirst: true)
        let workspace = try ReaderWorkspace(directory: root.appendingPathComponent("Library"), engine: engine)
        let reader = try await workspace.open(from: file)
        let content = try await reader.session.content(for: .text)
        let id = reader.document.document.id
        let selection = try await reader.session.select(documentID: id, resource: .text,
            range: (content.text as NSString).range(of: "fell through"))
        let explanation = Task { try await reader.session.explain(selectionID: selection.id) }
        await engine.waitForStart()
        try await workspace.close(documentID: id)
        do { _ = try await explanation.value; Issue.record("Closed reader returned AI") } catch is CancellationError {}
        await #expect(throws: ReaderError.staleSelection) { try await reader.session.save(selectionID: selection.id, meaning: .personal("Failed")) }
        await #expect(throws: ReaderError.noOpenDocument) { try await reader.session.content(for: .text) }
    }
}

private struct WorkspaceDictionary: LocalDictionary {
    func lookup(_ expression: String) async throws -> [DictionaryEntry] {
        [DictionaryEntry(id: "fixture:failed", query: expression, text: "failed to happen", provider: "Test dictionary")]
    }
}
