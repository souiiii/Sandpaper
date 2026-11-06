import CryptoKit
import Foundation
import GRDB

extension DocumentLibrary {
    /// Saving an occurrence never resets familiarity. Notes change only when explicitly supplied.
    /// One expression can have multiple senses and multiple source occurrences.
    public func saveVocabulary(
        expression: String, senseKey: String, anchor: SourceAnchor,
        explanation: Explanation? = nil, meaning: String? = nil, meaningSource: MeaningSource? = nil,
        notes: String? = nil, sourcePassage: AnalysisPassage? = nil
    ) throws -> VocabularyOccurrence {
        let normalized = TextNormalization.expression(expression)
        let sense = senseKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalized.isEmpty, normalized.count <= 1_024, !sense.isEmpty, sense.count <= 1_024 else {
            throw LibraryError.invalidInput("A bounded expression and a nonempty sense key are required.")
        }
        if let explanation { try explanation.validate() }
        if let sourcePassage {
            try sourcePassage.validate()
            guard sourcePassage.documentID == anchor.documentID, sourcePassage.revision == anchor.revision,
                  sourcePassage.resource == anchor.resource, anchor.utf16Offset >= sourcePassage.resourceOffset else {
                throw LibraryError.invalidInput("Source passage must contain the saved occurrence.")
            }
            let local = NSRange(location: anchor.utf16Offset - sourcePassage.resourceOffset, length: anchor.utf16Length)
            guard try sourcePassage.anchor(for: local).quote == anchor.quote else {
                throw LibraryError.invalidInput("Source passage does not match the saved quotation.")
            }
        }
        guard notes.map({ $0.utf8.count <= 1_048_576 }) ?? true else { throw LibraryError.invalidInput("Vocabulary notes exceed the storage limit.") }
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
                (id, expression, normalizedExpression, senseKey, familiarity, notes, createdAt, meaning, meaningSource)
                VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
                ON CONFLICT(normalizedExpression, senseKey) DO UPDATE
                SET meaning = COALESCE(vocabulary.meaning, excluded.meaning),
                    meaningSource = CASE WHEN vocabulary.meaning IS NULL THEN excluded.meaningSource ELSE vocabulary.meaningSource END,
                    notes = COALESCE(?, vocabulary.notes)
                """, arguments: [
                    UUID().uuidString, expression.trimmingCharacters(in: .whitespacesAndNewlines),
                    normalized, sense, Familiarity.unfamiliar.rawValue, notes ?? "", now, senseMeaning,
                    try meaningSource.map(LibraryDatabase.encode), notes
                ])
            guard let vocabularyID = try String.fetchOne(
                db, sql: "SELECT id FROM vocabulary WHERE normalizedExpression = ? AND senseKey = ?",
                arguments: [normalized, sense]
            ) else { throw LibraryError.corruptStoredData }
            try db.execute(sql: """
                INSERT INTO occurrences (id, vocabularyID, documentID, anchorKey, anchor, explanation, createdAt, sourcePassage)
                VALUES (?, ?, ?, ?, ?, ?, ?, ?)
                ON CONFLICT(vocabularyID, documentID, anchorKey) DO UPDATE
                SET explanation = COALESCE(excluded.explanation, occurrences.explanation),
                    sourcePassage = COALESCE(excluded.sourcePassage, occurrences.sourcePassage)
                """, arguments: [
                    UUID().uuidString, vocabularyID, anchor.documentID.uuidString,
                    anchorKey, anchorData, explanationData, now, try sourcePassage.map(LibraryDatabase.encode)
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

    /// Editing a meaning makes it personal prose; it must no longer be labeled a dictionary fact.
    public func updateVocabularyMeaning(id: UUID, meaning: String) throws {
        let meaning = meaning.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !meaning.isEmpty, meaning.utf16.count <= 2_048 else { throw LibraryError.invalidInput("A meaning must contain 1–2048 UTF-16 units.") }
        try database.write { db in
            try db.execute(sql: "UPDATE vocabulary SET meaning=?, meaningSource=? WHERE id=?",
                arguments: [meaning, try LibraryDatabase.encode(MeaningSource.personal), id.uuidString])
            guard db.changesCount == 1 else { throw LibraryError.vocabularyNotFound }
        }
    }

    public func deleteVocabulary(id: UUID) throws {
        try database.write { db in
            try db.execute(sql: "DELETE FROM vocabulary WHERE id=?", arguments: [id.uuidString])
            guard db.changesCount == 1 else { throw LibraryError.vocabularyNotFound }
        }
    }

    /// Removing a source occurrence retains the vocabulary sense and its personal notes.
    public func deleteOccurrence(id: UUID) throws {
        try database.write { db in
            try db.execute(sql: "DELETE FROM occurrences WHERE id=?", arguments: [id.uuidString])
            guard db.changesCount == 1 else { throw LibraryError.vocabularyNotFound }
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

    func validatePage(limit: Int, offset: Int) throws {
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
