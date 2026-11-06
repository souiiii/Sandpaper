import Foundation
import GRDB
import Testing
@testable import SandpaperCore

struct SenseMemoryTests {
    @Test func originalDatabaseMigratesWithoutLosingLearnerState() async throws {
        let root = try temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: root) }
        let database = try DatabaseQueue(path: root.appendingPathComponent("Library.sqlite").path)
        try await database.write { db in
            try db.execute(sql: """
                CREATE TABLE grdb_migrations (identifier TEXT NOT NULL PRIMARY KEY);
                INSERT INTO grdb_migrations VALUES ('v1_library');
                CREATE TABLE documents (
                    id TEXT PRIMARY KEY, title TEXT NOT NULL, format TEXT NOT NULL, revision TEXT NOT NULL,
                    fileName TEXT NOT NULL UNIQUE, importedAt DOUBLE NOT NULL, trashedAt DOUBLE,
                    UNIQUE(revision, format)
                );
                CREATE TABLE readingState (documentID TEXT PRIMARY KEY REFERENCES documents(id), payload BLOB NOT NULL);
                CREATE TABLE occurrences (
                    id TEXT PRIMARY KEY, vocabularyID TEXT NOT NULL REFERENCES vocabulary(id),
                    documentID TEXT NOT NULL REFERENCES documents(id), anchorKey TEXT NOT NULL,
                    anchor BLOB NOT NULL, explanation BLOB, createdAt DOUBLE NOT NULL,
                    UNIQUE(vocabularyID, documentID, anchorKey)
                );
                CREATE TABLE vocabulary (
                    id TEXT PRIMARY KEY, expression TEXT NOT NULL, normalizedExpression TEXT NOT NULL,
                    senseKey TEXT NOT NULL, familiarity TEXT NOT NULL, notes TEXT NOT NULL, createdAt DOUBLE NOT NULL,
                    UNIQUE(normalizedExpression, senseKey)
                );
                INSERT INTO vocabulary VALUES (?, 'means', 'means', 'wealth', 'known', 'My note', 100);
                """, arguments: [UUID().uuidString])
        }
        let library = try DocumentLibrary(directory: root)
        let entries = try await library.vocabulary()
        #expect(entries.count == 1)
        #expect(entries.first?.familiarity == .known)
        #expect(entries.first?.notes == "My note")
        #expect(entries.first?.meaning == nil)
        let columns = try await database.read { try $0.columns(in: "vocabulary").map(\.name) }
        #expect(columns.contains("meaning"))
    }

    @Test func savedMeaningIsRetrievedWithoutOverwritingPersonalKnowledge() async throws {
        let root = try temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: root) }
        let source = root.appendingPathComponent("book.txt")
        try Data("He had considerable means.".utf8).write(to: source)
        let library = try DocumentLibrary(directory: root.appendingPathComponent("Library"))
        let document = try await library.importDocument(from: source).document
        let passage = try AnalysisPassage(documentID: document.id, revision: document.revision, resource: .text, text: "He had considerable means.")
        let anchor = try passage.anchor(for: (passage.text as NSString).range(of: "means"))
        let occurrence = try await library.saveVocabulary(expression: "means", senseKey: "wealth", anchor: anchor)
        try await library.updateVocabulary(id: occurrence.vocabularyID, familiarity: .known, notes: "Remembered")
        _ = try await library.saveVocabulary(
            expression: "means", senseKey: "wealth", anchor: anchor,
            explanation: Explanation(meaning: "Financial resources or wealth.")
        )
        _ = try await library.saveVocabulary(
            expression: "means", senseKey: "wealth", anchor: anchor, meaning: "A replacement interpretation."
        )
        let saved = try #require(await library.vocabulary().first { $0.senseKey == "wealth" })
        #expect(saved.meaning == "Financial resources or wealth.")
        #expect(saved.familiarity == .known)
        #expect(try await library.vocabulary().first?.notes == "Remembered")
        let longMeaning = String(repeating: "A", count: 3_000)
        let longOccurrence = try await library.saveVocabulary(
            expression: "means", senseKey: "long-context", anchor: anchor, explanation: Explanation(meaning: longMeaning)
        )
        #expect(longOccurrence.explanation?.meaning == longMeaning)
        let longEntry = try #require(await library.vocabulary().first { $0.senseKey == "long-context" })
        #expect(longEntry.meaning == nil)
    }

    private func temporaryDirectory() throws -> URL {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("SandpaperSenseTests-" + UUID().uuidString)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        return root
    }
}
