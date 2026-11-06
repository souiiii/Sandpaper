import Foundation
import Testing
@testable import SandpaperCore

struct ReaderWorkflowTests {
    private func setup() async throws -> (URL, DocumentLibrary, LibraryDocument) {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        let file = root.appendingPathComponent("book.md")
        try Data("# A chapter\n\nHe had **considerable means**.\n\nShe chose another means.".utf8).write(to: file)
        let library = try DocumentLibrary(directory: root.appendingPathComponent("Library"))
        return (root, library, try await library.importDocument(from: file).document)
    }

    @Test func completeReadingDictionaryVocabularyAndReturnWorkflowNeedsNoAI() async throws {
        let (root, library, document) = try await setup()
        defer { try? FileManager.default.removeItem(at: root) }
        let engine = SelectionProbeEngine()
        let session = ReaderSession(library: library, dictionary: WorkflowDictionary(), engine: engine)
        _ = try await session.open(documentID: document.id)
        let content = try await session.content(for: .text)
        #expect(content.text.contains("A chapter\n\nHe had considerable means."))
        #expect(!content.text.contains("**"))
        let selection = try await session.select(documentID: document.id, resource: .text, range: (content.text as NSString).range(of: "means"))
        let dictionary = try await session.lookup(selectionID: selection.id)
        let entry = try #require(dictionary.first)
        let wealth = (entry.text as NSString).range(of: "financial resources; wealth")
        let saved = try await session.save(selectionID: selection.id, meaning: .dictionary(entryID: entry.id, range: wealth), notes: "Remember this sense")
        let repeated = try await session.save(selectionID: selection.id, meaning: .dictionary(entryID: entry.id, range: wealth))
        #expect(repeated.id == saved.id)
        #expect(saved.sourcePassage?.text.contains("He had considerable means.") == true)
        let vocabulary = try await library.vocabularyEntry(id: saved.vocabularyID)
        #expect(vocabulary.meaning == "financial resources; wealth")
        #expect(vocabulary.notes == "Remember this sense")
        #expect(vocabulary.meaningSource == .dictionary(provider: "Fixture dictionary", entryID: entry.id))
        let method = (entry.text as NSString).range(of: "a method")
        _ = try await session.save(selectionID: selection.id, meaning: .dictionary(entryID: entry.id, range: method))
        #expect(try await library.vocabulary().count == 2)
        try await session.recordProgress(documentID: document.id, resource: .text, visibleRange: (content.text as NSString).range(of: "means"), progression: 0.4)
        let bookmark = try await session.bookmark(documentID: document.id, resource: .text, range: (content.text as NSString).range(of: "means"), title: "Wealth")
        try await library.saveReadingPreferences(ReadingPreferences(fontSize: 24, lineHeight: 1.8, theme: .dark))
        let reopened = try DocumentLibrary(directory: root.appendingPathComponent("Library"))
        #expect(try await reopened.occurrence(id: saved.id).sourcePassage == saved.sourcePassage)
        #expect(try await reopened.readingPosition(for: document.id)?.progression == 0.4)
        #expect(try await reopened.readingState(for: document.id)?.progression == 0.4)
        #expect(try await reopened.bookmarks(for: document.id).first?.id == bookmark.id)
        #expect(try await reopened.readingPreferences().fontSize == 24)
        let secondSession = ReaderSession(library: reopened, dictionary: WorkflowDictionary(), engine: engine)
        let destination = try await secondSession.navigate(to: saved)
        #expect(destination.resolution == .exact((content.text as NSString).range(of: "means")))
        #expect(await engine.calls == 0)
        #expect(await engine.availabilityCalls == 0)
    }

    @Test func dictionaryAndSavingStayAvailableWhileExplicitAIIsRunning() async throws {
        let (root, library, document) = try await setup()
        defer { try? FileManager.default.removeItem(at: root) }
        let engine = SelectionProbeEngine(holdFirst: true)
        let session = ReaderSession(library: library, dictionary: WorkflowDictionary(), engine: engine)
        _ = try await session.open(documentID: document.id)
        let content = try await session.content(for: .text)
        let first = try await session.select(documentID: document.id, resource: .text, range: (content.text as NSString).range(of: "means"))
        await #expect(throws: ReaderError.explanationNotReady) { try await session.save(selectionID: first.id, meaning: .aiInterpretation()) }
        let explanation = Task { try await session.explain(selectionID: first.id) }
        await engine.waitForStart()
        #expect(try await session.lookup(selectionID: first.id).count == 1)
        _ = try await session.save(selectionID: first.id, meaning: .personal("Financial resources."))
        let next = try await session.select(documentID: document.id, resource: .text, range: (content.text as NSString).range(of: "another"))
        do { _ = try await explanation.value; Issue.record("Cancelled explanation returned") } catch is CancellationError {}
        await #expect(throws: ReaderError.staleSelection) { try await session.lookup(selectionID: first.id) }
        await #expect(throws: ReaderError.explanationNotReady) { try await session.save(selectionID: next.id, meaning: .aiInterpretation()) }
    }

    @Test func completedAIIsSavedAsInterpretationAndCannotMasqueradeAsDictionaryFact() async throws {
        let (root, library, document) = try await setup()
        defer { try? FileManager.default.removeItem(at: root) }
        let session = ReaderSession(library: library, dictionary: WorkflowDictionary(), engine: SelectionProbeEngine())
        _ = try await session.open(documentID: document.id)
        let text = try await session.content(for: .text).text
        let selection = try await session.select(documentID: document.id, resource: .text, range: (text as NSString).range(of: "means"))
        _ = try await session.explain(selectionID: selection.id)
        let saved = try await session.save(selectionID: selection.id, meaning: .aiInterpretation())
        #expect(try await library.vocabularyEntry(id: saved.vocabularyID).meaningSource == .aiInterpretation)
        #expect(saved.explanation != nil)
        await #expect(throws: (any Error).self) {
            try await session.save(selectionID: selection.id, meaning: .dictionary(entryID: "invented", range: NSRange(location: 0, length: 4)))
        }
    }

    @Test func previousDocumentSelectionAndProgressCannotBeAppliedToANewDocument() async throws {
        let (root, library, document) = try await setup()
        defer { try? FileManager.default.removeItem(at: root) }
        let file = root.appendingPathComponent("other.txt"); try Data("A different document.".utf8).write(to: file)
        let other = try await library.importDocument(from: file).document
        let session = ReaderSession(library: library)
        _ = try await session.open(documentID: other.id)
        await #expect(throws: ReaderError.staleSelection) { try await session.select(documentID: document.id, resource: .text, range: NSRange(location: 0, length: 1)) }
        await #expect(throws: ReaderError.staleSelection) { try await session.recordProgress(documentID: document.id, resource: .text, progression: 0.8) }
        #expect(try await library.readingPosition(for: other.id) == nil)
    }

    @Test func nativeDictionaryReturnsFactsOrAnExplicitEmptyResultWithoutAI() async throws {
        let entries = try await MacOSDictionary().lookup("serendipity")
        for entry in entries { #expect(!entry.text.isEmpty); #expect(entry.provider == "macOS active dictionaries") }
        await #expect(throws: (any Error).self) { try await MacOSDictionary().lookup(" ") }
    }

    @Test func vocabularyEditsAndDeletionPreserveProvenanceAndDocumentIntegrity() async throws {
        let (root, library, document) = try await setup()
        defer { try? FileManager.default.removeItem(at: root) }
        let session = ReaderSession(library: library, dictionary: WorkflowDictionary())
        _ = try await session.open(documentID: document.id)
        let text = try await session.content(for: .text).text
        let selection = try await session.select(documentID: document.id, resource: .text, range: (text as NSString).range(of: "means"))
        let entry = try #require(await session.lookup(selectionID: selection.id).first)
        let saved = try await session.save(selectionID: selection.id,
            meaning: .dictionary(entryID: entry.id, range: (entry.text as NSString).range(of: "financial resources; wealth")))
        try await library.updateVocabulary(id: saved.vocabularyID, familiarity: .known, notes: "My note")
        try await library.updateVocabularyMeaning(id: saved.vocabularyID, meaning: "Money available to him.")
        let edited = try await library.vocabularyEntry(id: saved.vocabularyID)
        #expect(edited.meaningSource == .personal); #expect(edited.familiarity == .known)
        try await library.deleteOccurrence(id: saved.id)
        #expect(try await library.occurrences(for: saved.vocabularyID).isEmpty)
        #expect(try await library.vocabularyEntry(id: saved.vocabularyID).notes == "My note")
        _ = try await session.save(selectionID: selection.id, meaning: .existingSense(saved.vocabularyID))
        try await library.deleteVocabulary(id: saved.vocabularyID)
        #expect(try await library.vocabulary().isEmpty)
        #expect(try await library.contentURL(for: document.id).isFileURL)
    }

    @Test func bookmarksAndProgressSurviveTrashAndInvalidPreferencesNeverOverwriteValidOnes() async throws {
        let (root, library, document) = try await setup()
        defer { try? FileManager.default.removeItem(at: root) }
        let session = ReaderSession(library: library)
        _ = try await session.open(documentID: document.id)
        let bookmark = try await session.bookmark(documentID: document.id, resource: .text, title: "Start")
        try await session.recordProgress(documentID: document.id, resource: .text, progression: 0.2)
        try await library.saveReadingPreferences(ReadingPreferences(fontSize: 22))
        await #expect(throws: (any Error).self) { try await library.saveReadingPreferences(ReadingPreferences(fontSize: .nan)) }
        #expect(try await library.readingPreferences().fontSize == 22)
        try await library.trashDocument(id: document.id)
        #expect(try await library.bookmarks(for: document.id).count == 1)
        let fresh = ReaderSession(library: library)
        await #expect(throws: LibraryError.documentInTrash) { try await fresh.navigate(to: bookmark.position) }
        try await library.restoreDocument(id: document.id)
        #expect(try await fresh.navigate(to: bookmark.position).document.document.id == document.id)
        #expect(try await library.readingPosition(for: document.id)?.progression == 0.2)
    }
}

private actor WorkflowDictionary: LocalDictionary {
    func lookup(_ expression: String) -> [DictionaryEntry] {
        [DictionaryEntry(id: "fixture:means", query: expression,
            text: "means: 1 financial resources; wealth. 2 a method.", provider: "Fixture dictionary")]
    }
}
