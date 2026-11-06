import Foundation
import GRDB

extension DocumentLibrary {
    public func openReader(for id: UUID) throws -> DocumentReader {
        DocumentReader(document: try document(id: id), fileURL: try contentURL(for: id))
    }

    public func saveReadingPosition(_ position: ReadingPosition) throws {
        try database.write { db in
            try validate(position, in: db)
            try db.execute(sql: "INSERT INTO readingState (documentID, payload) VALUES (?, ?) ON CONFLICT(documentID) DO UPDATE SET payload=excluded.payload",
                arguments: [position.documentID.uuidString, try LibraryDatabase.encode(position)])
        }
    }

    public func readingPosition(for id: UUID) throws -> ReadingPosition? {
        try database.read { db in
            _ = try requireDocument(id, in: db)
            guard let data = try Data.fetchOne(db, sql: "SELECT payload FROM readingState WHERE documentID=?", arguments: [id.uuidString]) else { return nil }
            if let position = try? JSONDecoder().decode(ReadingPosition.self, from: data) {
                return try ReadingPosition(documentID: position.documentID, revision: position.revision, resource: position.resource,
                    anchor: position.anchor, progression: position.progression)
            }
            let old = try JSONDecoder().decode(ReadingState.self, from: data)
            return try ReadingPosition(documentID: old.anchor.documentID, revision: old.anchor.revision, resource: old.anchor.resource,
                anchor: old.anchor, progression: old.progression)
        }
    }

    public func saveBookmark(at position: ReadingPosition, title: String) throws -> Bookmark {
        let title = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !title.isEmpty, title.utf16.count <= 1_024 else { throw LibraryError.invalidInput("A bookmark needs a short title.") }
        return try database.write { db in
            try validate(position, in: db)
            let value = Bookmark(id: UUID(), position: position, title: title, createdAt: Date())
            try db.execute(sql: "INSERT INTO bookmarks VALUES (?, ?, ?, ?)",
                arguments: [value.id.uuidString, position.documentID.uuidString, try LibraryDatabase.encode(value), value.createdAt.timeIntervalSince1970])
            return value
        }
    }

    public func bookmarks(for id: UUID, limit: Int = 100, offset: Int = 0) throws -> [Bookmark] {
        try validatePage(limit: limit, offset: offset)
        return try database.read { db in
            _ = try requireDocument(id, in: db)
            return try Data.fetchAll(db, sql: "SELECT payload FROM bookmarks WHERE documentID=? ORDER BY createdAt, id LIMIT ? OFFSET ?", arguments: [id.uuidString, limit, offset])
                .map { try JSONDecoder().decode(Bookmark.self, from: $0) }
        }
    }

    public func deleteBookmark(id: UUID) throws {
        try database.write { db in try db.execute(sql: "DELETE FROM bookmarks WHERE id=?", arguments: [id.uuidString]) }
    }

    public func readingPreferences() throws -> ReadingPreferences {
        try database.read { db in
            guard let data = try Data.fetchOne(db, sql: "SELECT payload FROM preferences WHERE key='reading'") else { return ReadingPreferences() }
            let value = try JSONDecoder().decode(ReadingPreferences.self, from: data)
            try value.validate(); return value
        }
    }

    public func saveReadingPreferences(_ value: ReadingPreferences) throws {
        try value.validate()
        try database.write { db in
            try db.execute(sql: "INSERT INTO preferences VALUES ('reading', ?) ON CONFLICT(key) DO UPDATE SET payload=excluded.payload",
                arguments: [try LibraryDatabase.encode(value)])
        }
    }

    public func vocabularyEntry(id: UUID) throws -> VocabularyEntry {
        try database.read { db in
            guard let row = try Row.fetchOne(db, sql: "SELECT * FROM vocabulary WHERE id=?", arguments: [id.uuidString]) else { throw LibraryError.vocabularyNotFound }
            return try LibraryDatabase.vocabulary(row)
        }
    }

    public func occurrence(id: UUID) throws -> VocabularyOccurrence {
        try database.read { db in
            guard let row = try Row.fetchOne(db, sql: "SELECT * FROM occurrences WHERE id=?", arguments: [id.uuidString]) else { throw LibraryError.vocabularyNotFound }
            return try LibraryDatabase.occurrence(row)
        }
    }

    private func validate(_ position: ReadingPosition, in db: Database) throws {
        _ = try ReadingPosition(documentID: position.documentID, revision: position.revision, resource: position.resource,
            anchor: position.anchor, progression: position.progression)
        try validateLocation(documentID: position.documentID, revision: position.revision, resource: position.resource, in: db)
        if let anchor = position.anchor { try validate(anchor, in: db) }
    }
}
