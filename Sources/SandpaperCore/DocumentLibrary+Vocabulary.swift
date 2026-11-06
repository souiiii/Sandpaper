import CryptoKit
import Foundation
import GRDB

extension DocumentLibrary {
    /// Saving an occurrence never resets familiarity or overwrites personal notes.
    /// One expression can have multiple senses and multiple source occurrences.
    public func saveVocabulary(
        expression: String, senseKey: String, anchor: SourceAnchor,
        explanation: Explanation? = nil, meaning: String? = nil
    ) throws -> VocabularyOccurrence {
        let normalized = TextNormalization.expression(expression)
        let sense = senseKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalized.isEmpty, normalized.count <= 1_024, !sense.isEmpty, sense.count <= 1_024 else {
            throw LibraryError.invalidInput("A bounded expression and a nonempty sense key are required.")
        }
        if let explanation { try explanation.validate() }
        let explicitMeaning = meaning?.trimmingCharacters(in: .whitespacesAndNewlines)
        guard explicitMeaning.map({ !$0.isEmpty && $0.utf16.count <= 2_048 }) ?? true else {
            throw LibraryError.invalidInput("A sense meaning must be nonempty and at most 2048 UTF-16 units.")
        }
        // Preserve the existing ability to save a detailed explanation. A long
        // contextual answer must not be truncated into a misleading memory gloss.
        let inferredMeaning = explanation?.meaning.trimmingCharacters(in: .whitespacesAndNewlines)
        let senseMeaning = explicitMeaning ?? inferredMeaning.flatMap { $0.utf16.count <= 2_048 ? $0 : nil }
        let anchorData = try LibraryDatabase.encode(anchor)
        let identityData = try LibraryDatabase.encode(OccurrenceIdentity(anchor: anchor))
        let anchorKey = SHA256.hash(data: identityData).map { String(format: "%02x", $0) }.joined()
        let explanationData = try explanation.map(LibraryDatabase.encode)
        return try database.write { db in
            try validate(anchor, in: db)
            let now = Date().timeIntervalSince1970
            try db.execute(sql: """
                INSERT INTO vocabulary
                (id, expression, normalizedExpression, senseKey, familiarity, notes, createdAt, meaning)
                VALUES (?, ?, ?, ?, ?, '', ?, ?)
                ON CONFLICT(normalizedExpression, senseKey) DO UPDATE
                SET meaning = COALESCE(vocabulary.meaning, excluded.meaning)
                """, arguments: [
                    UUID().uuidString, expression.trimmingCharacters(in: .whitespacesAndNewlines),
                    normalized, sense, Familiarity.unfamiliar.rawValue, now, senseMeaning
                ])
            guard let vocabularyID = try String.fetchOne(
                db, sql: "SELECT id FROM vocabulary WHERE normalizedExpression = ? AND senseKey = ?",
                arguments: [normalized, sense]
            ) else { throw LibraryError.corruptStoredData }
            try db.execute(sql: """
                INSERT INTO occurrences (id, vocabularyID, documentID, anchorKey, anchor, explanation, createdAt)
                VALUES (?, ?, ?, ?, ?, ?, ?)
                ON CONFLICT(vocabularyID, documentID, anchorKey) DO UPDATE
                SET explanation = COALESCE(excluded.explanation, occurrences.explanation)
                """, arguments: [
                    UUID().uuidString, vocabularyID, anchor.documentID.uuidString,
                    anchorKey, anchorData, explanationData, now
                ])
            guard let row = try Row.fetchOne(
                db, sql: "SELECT * FROM occurrences WHERE vocabularyID = ? AND documentID = ? AND anchorKey = ?",
                arguments: [vocabularyID, anchor.documentID.uuidString, anchorKey]
            ) else { throw LibraryError.corruptStoredData }
            return try LibraryDatabase.occurrence(row)
        }
    }

    public func vocabulary(
        matching search: String = "", limit: Int = 100, offset: Int = 0
    ) throws -> [VocabularyEntry] {
        try validatePage(limit: limit, offset: offset)
        let query = TextNormalization.expression(search)
        return try database.read { db in
            try Row.fetchAll(db, sql: """
                SELECT * FROM vocabulary WHERE instr(normalizedExpression, ?) > 0
                ORDER BY normalizedExpression, senseKey LIMIT ? OFFSET ?
                """, arguments: [query, limit, offset]).map(LibraryDatabase.vocabulary)
        }
    }

    public func updateVocabulary(id: UUID, familiarity: Familiarity, notes: String) throws {
        guard notes.utf8.count <= 1_048_576 else {
            throw LibraryError.invalidInput("Vocabulary notes exceed the storage limit.")
        }
        try database.write { db in
            try db.execute(
                sql: "UPDATE vocabulary SET familiarity = ?, notes = ? WHERE id = ?",
                arguments: [familiarity.rawValue, notes, id.uuidString]
            )
            guard db.changesCount == 1 else { throw LibraryError.vocabularyNotFound }
        }
    }

    /// Supply relevant dictionary expressions, including lemmas from the local
    /// lexicon when available. This never loads the entire learner vocabulary.
    public func discoveryMemories(for expressions: [String]) throws -> [KnownSense] {
        guard expressions.count <= 256, expressions.allSatisfy({ $0.utf16.count <= 512 }) else {
            throw LibraryError.invalidInput("Too many expressions for a familiarity lookup.")
        }
        let normalized = Array(Set(expressions.map(TextNormalization.expression))).sorted()
        guard !normalized.isEmpty else { return [] }
        let placeholders = Array(repeating: "?", count: normalized.count).joined(separator: ",")
        let entries = try database.read { db in
            try Row.fetchAll(db, sql: """
                SELECT * FROM vocabulary WHERE normalizedExpression IN (\(placeholders))
                ORDER BY normalizedExpression, senseKey LIMIT 256
                """, arguments: StatementArguments(normalized)).map(LibraryDatabase.vocabulary)
        }
        var budget = 12_288
        return entries.compactMap { entry in
            let size = entry.expression.utf16.count + entry.senseKey.utf16.count + (entry.meaning?.utf16.count ?? 0)
            guard entry.expression.utf16.count <= 512, entry.senseKey.utf16.count <= 512, size <= budget else { return nil }
            budget -= size
            return KnownSense(expression: entry.expression, senseKey: entry.senseKey, meaning: entry.meaning, familiarity: entry.familiarity)
        }
    }

    public func occurrences(
        for vocabularyID: UUID, includingTrash: Bool = false, limit: Int = 100, offset: Int = 0
    ) throws -> [VocabularyOccurrence] {
        try validatePage(limit: limit, offset: offset)
        return try database.read { db in
            guard try Bool.fetchOne(
                db, sql: "SELECT EXISTS(SELECT 1 FROM vocabulary WHERE id = ?)", arguments: [vocabularyID.uuidString]
            ) == true else { throw LibraryError.vocabularyNotFound }
            return try Row.fetchAll(db, sql: """
                SELECT occurrences.* FROM occurrences JOIN documents ON documents.id = occurrences.documentID
                WHERE vocabularyID = ? AND (? OR documents.trashedAt IS NULL)
                ORDER BY occurrences.createdAt, occurrences.id LIMIT ? OFFSET ?
                """, arguments: [vocabularyID.uuidString, includingTrash, limit, offset])
                .map(LibraryDatabase.occurrence)
        }
    }

    private func validatePage(limit: Int, offset: Int) throws {
        guard (1...500).contains(limit), offset >= 0 else {
            throw LibraryError.invalidInput("Query limit must be 1–500 and offset must be nonnegative.")
        }
    }
}

private struct OccurrenceIdentity: Encodable {
    let revision: String
    let resource: SourceResource
    let offset: Int
    let length: Int
    let quote: String

    init(anchor: SourceAnchor) {
        revision = anchor.revision
        resource = anchor.resource
        offset = anchor.utf16Offset
        length = anchor.utf16Length
        quote = anchor.quote
    }
}
