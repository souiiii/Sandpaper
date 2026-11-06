import Foundation
import Testing
@testable import SandpaperCore

struct DocumentLibraryTests {
    @Test func largeImportsPreserveBytesAcrossChunkBoundaries() async throws {
        let root = try temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: root) }
        let source = root.appendingPathComponent("large.txt")
        var bytes = Data(repeating: 65, count: 2_097_151)
        bytes.append(Data("📖 End of document.".utf8))
        try bytes.write(to: source)
        let library = try DocumentLibrary(directory: root.appendingPathComponent("Library"))
        let imported = try await library.importDocument(from: source)
        let owned = try await library.contentURL(for: imported.document.id)
        #expect(try Data(contentsOf: owned) == bytes)
    }

    @Test func importsAreManagedDeduplicatedAndSurviveReopening() async throws {
        let root = try temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: root) }
        let source = root.appendingPathComponent("book.txt")
        let bytes = Data("The agreement fell through. 📖".utf8)
        try bytes.write(to: source)
        let directory = root.appendingPathComponent("Library")
        let library = try DocumentLibrary(directory: directory)
        let first = try await library.importDocument(from: source)
        let second = try await library.importDocument(from: source)
        #expect(!first.alreadyImported)
        #expect(second.alreadyImported)
        #expect(first.document == second.document)
        #expect(try Data(contentsOf: source) == bytes)
        try FileManager.default.removeItem(at: source)
        let managed = try await library.contentURL(for: first.document.id)
        #expect(try Data(contentsOf: managed) == bytes)
        let reopened = try DocumentLibrary(directory: directory)
        #expect(try await reopened.documents() == [first.document])
        let managedFiles = try FileManager.default.contentsOfDirectory(
            at: directory.appendingPathComponent("Documents"), includingPropertiesForKeys: nil
        )
        #expect(managedFiles.count == 1)
    }

    @Test func trashRestorePreservesStateVocabularyAndOriginal() async throws {
        let fixture = try await fixture()
        defer { try? FileManager.default.removeItem(at: fixture.root) }
        let anchor = try fixture.anchor()
        let state = try ReadingState(anchor: anchor, progression: 0.45)
        try await fixture.library.saveReadingState(state)
        let occurrence = try await fixture.library.saveVocabulary(
            expression: "fall through", senseKey: "fail-to-happen", anchor: anchor,
            explanation: Explanation(meaning: "The agreement failed to happen.")
        )
        try await fixture.library.updateVocabulary(
            id: occurrence.vocabularyID, familiarity: .learning, notes: "Usually used for plans."
        )
        try await fixture.library.trashDocument(id: fixture.document.id)
        try await fixture.library.trashDocument(id: fixture.document.id)
        #expect(try await fixture.library.documents().isEmpty)
        #expect(try await fixture.library.documents(inTrash: true).count == 1)
        #expect(try await fixture.library.occurrences(for: occurrence.vocabularyID).isEmpty)
        #expect(try await fixture.library.occurrences(for: occurrence.vocabularyID, includingTrash: true) == [occurrence])
        await #expect(throws: LibraryError.documentInTrash) {
            try await fixture.library.saveReadingState(state)
        }
        await #expect(throws: LibraryError.documentInTrash) {
            try await fixture.library.contentURL(for: fixture.document.id)
        }
        #expect(try String(contentsOf: fixture.source, encoding: .utf8) == fixture.text)

        let reopened = try DocumentLibrary(directory: fixture.directory)
        try await reopened.restoreDocument(id: fixture.document.id)
        #expect(try await reopened.readingState(for: fixture.document.id) == state)
        #expect(try await reopened.occurrences(for: occurrence.vocabularyID) == [occurrence])
        let entry = try #require(await reopened.vocabulary().first)
        #expect(entry.familiarity == .learning)
        #expect(entry.notes == "Usually used for plans.")
        #expect(try await reopened.document(id: fixture.document.id).trashedAt == nil)
    }

    @Test func duplicateOccurrencesIgnoreViewportContextAndPreserveLearning() async throws {
        let fixture = try await fixture()
        defer { try? FileManager.default.removeItem(at: fixture.root) }
        let fullAnchor = try fixture.anchor()
        let first = try await fixture.library.saveVocabulary(
            expression: "Fall Through", senseKey: "fail-to-happen", anchor: fullAnchor
        )
        try await fixture.library.updateVocabulary(id: first.vocabularyID, familiarity: .known, notes: "Remembered")
        let tightAnchor = try SourceAnchor(
            documentID: fixture.document.id, revision: fixture.document.revision, resource: .text,
            text: "fell through", selection: NSRange(location: 0, length: 12),
            resourceOffset: fullAnchor.utf16Offset
        )
        let repeated = try await fixture.library.saveVocabulary(
            expression: "  fall   through ", senseKey: "fail-to-happen", anchor: tightAnchor,
            explanation: Explanation(meaning: "It did not happen.")
        )
        #expect(first.id == repeated.id)
        #expect(try await fixture.library.vocabulary().count == 1)
        #expect(try await fixture.library.occurrences(for: first.vocabularyID).count == 1)
        let entry = try #require(await fixture.library.vocabulary().first)
        #expect(entry.familiarity == .known)
        #expect(entry.notes == "Remembered")
        #expect(repeated.explanation?.meaning == "It did not happen.")
    }

    @Test func distinctSensesRemainSeparate() async throws {
        let fixture = try await fixture()
        defer { try? FileManager.default.removeItem(at: fixture.root) }
        let anchor = try fixture.anchor()
        let first = try await fixture.library.saveVocabulary(expression: "means", senseKey: "wealth", anchor: anchor)
        let second = try await fixture.library.saveVocabulary(expression: "means", senseKey: "method", anchor: anchor)
        #expect(first.vocabularyID != second.vocabularyID)
        #expect(try await fixture.library.vocabulary(matching: "MEANS").count == 2)
    }

    @Test func invalidReferencesNeverCreatePartialVocabularyRecords() async throws {
        let fixture = try await fixture()
        defer { try? FileManager.default.removeItem(at: fixture.root) }
        let wrongRevision = try SourceAnchor(
            documentID: fixture.document.id, revision: "old", resource: .text,
            text: "fell through", selection: NSRange(location: 0, length: 12)
        )
        await #expect(throws: LibraryError.revisionMismatch) {
            try await fixture.library.saveVocabulary(expression: "fall through", senseKey: "fail", anchor: wrongRevision)
        }
        let wrongResource = try SourceAnchor(
            documentID: fixture.document.id, revision: fixture.document.revision, resource: .pdfPage(index: 0),
            text: "fell through", selection: NSRange(location: 0, length: 12)
        )
        await #expect(throws: (any Error).self) {
            try await fixture.library.saveVocabulary(expression: "fall through", senseKey: "fail", anchor: wrongResource)
        }
        #expect(try await fixture.library.vocabulary().isEmpty)
    }

    @Test func failedImportsLeaveNoLibraryRecordsOrStagingFiles() async throws {
        let root = try temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: root) }
        let source = root.appendingPathComponent("big.txt")
        try Data(repeating: 65, count: 20).write(to: source)
        let directory = root.appendingPathComponent("Library")
        let library = try DocumentLibrary(directory: directory, maximumImportBytes: 10)
        await #expect(throws: LibraryError.sourceTooLarge) { try await library.importDocument(from: source) }
        #expect(try await library.documents().isEmpty)
        #expect(try FileManager.default.contentsOfDirectory(atPath: directory.appendingPathComponent("Staging").path).isEmpty)
        #expect(try FileManager.default.contentsOfDirectory(atPath: directory.appendingPathComponent("Documents").path).isEmpty)
        #expect(try Data(contentsOf: source).count == 20)
    }

    @Test func cancelledImportLeavesOriginalUntouched() async throws {
        let root = try temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: root) }
        let source = root.appendingPathComponent("book.md")
        try Data("# A book".utf8).write(to: source)
        let library = try DocumentLibrary(directory: root.appendingPathComponent("Library"))
        let task = Task {
            withUnsafeCurrentTask { $0?.cancel() }
            return try await library.importDocument(from: source)
        }
        do {
            _ = try await task.value
            Issue.record("Cancelled import unexpectedly succeeded")
        } catch is CancellationError {}
        #expect(try await library.documents().isEmpty)
        #expect(try String(contentsOf: source, encoding: .utf8) == "# A book")
    }

    @Test func invalidProgressAndUnsupportedFormatsAreRejected() async throws {
        let fixture = try await fixture()
        defer { try? FileManager.default.removeItem(at: fixture.root) }
        #expect(throws: (any Error).self) { try ReadingState(anchor: fixture.anchor(), progression: .nan) }
        await #expect(throws: LibraryError.unsupportedFormat("docx")) {
            try await fixture.library.importDocument(from: fixture.root.appendingPathComponent("book.docx"))
        }
    }

    private func temporaryDirectory() throws -> URL {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("SandpaperTests-" + UUID().uuidString)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        return root
    }

    private func fixture() async throws -> Fixture {
        let root = try temporaryDirectory()
        let source = root.appendingPathComponent("book.txt")
        let text = "After months of negotiations, the agreement finally fell through."
        try Data(text.utf8).write(to: source)
        let directory = root.appendingPathComponent("Library")
        let library = try DocumentLibrary(directory: directory)
        let result = try await library.importDocument(from: source)
        return Fixture(root: root, directory: directory, source: source, text: text, library: library, document: result.document)
    }
}

private struct Fixture {
    let root: URL
    let directory: URL
    let source: URL
    let text: String
    let library: DocumentLibrary
    let document: LibraryDocument

    func anchor() throws -> SourceAnchor {
        try SourceAnchor(
            documentID: document.id, revision: document.revision, resource: .text,
            text: text, selection: (text as NSString).range(of: "fell through")
        )
    }
}
