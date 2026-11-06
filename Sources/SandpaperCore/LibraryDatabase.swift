import Foundation
import GRDB

enum LibraryDatabase {
    static func open(at url: URL) throws -> DatabaseQueue {
        var configuration = Configuration()
        configuration.foreignKeysEnabled = true
        configuration.busyMode = .timeout(5)
        let queue = try DatabaseQueue(path: url.path, configuration: configuration)
        try queue.writeWithoutTransaction { db in
            try db.execute(sql: "PRAGMA journal_mode = WAL")
            try db.execute(sql: "PRAGMA synchronous = FULL")
        }
        var migrator = DatabaseMigrator()
        migrator.registerMigration("v1_library") { db in
            try db.create(table: "documents") { table in
                table.column("id", .text).primaryKey()
                table.column("title", .text).notNull()
                table.column("format", .text).notNull()
                table.column("revision", .text).notNull()
                table.column("fileName", .text).notNull().unique()
                table.column("importedAt", .double).notNull()
                table.column("trashedAt", .double)
                table.uniqueKey(["revision", "format"])
            }
            try db.create(table: "readingState") { table in
                table.column("documentID", .text).primaryKey().references("documents", onDelete: .cascade)
                table.column("payload", .blob).notNull()
            }
            try db.create(table: "vocabulary") { table in
                table.column("id", .text).primaryKey()
                table.column("expression", .text).notNull()
                table.column("normalizedExpression", .text).notNull()
                table.column("senseKey", .text).notNull()
                table.column("familiarity", .text).notNull()
                table.column("notes", .text).notNull()
                table.column("createdAt", .double).notNull()
                table.uniqueKey(["normalizedExpression", "senseKey"])
            }
            try db.create(table: "occurrences") { table in
                table.column("id", .text).primaryKey()
                table.column("vocabularyID", .text).notNull().indexed().references("vocabulary", onDelete: .cascade)
                table.column("documentID", .text).notNull().indexed().references("documents", onDelete: .cascade)
                table.column("anchorKey", .text).notNull()
                table.column("anchor", .blob).notNull()
                table.column("explanation", .blob)
                table.column("createdAt", .double).notNull()
                table.uniqueKey(["vocabularyID", "documentID", "anchorKey"])
            }
        }
        try migrator.migrate(queue)
        return queue
    }

    static func encode<T: Encodable>(_ value: T) throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        return try encoder.encode(value)
    }

    static func document(_ row: Row) throws -> LibraryDocument {
        guard let id = UUID(uuidString: row["id"]),
              let format = DocumentFormat(rawValue: row["format"]) else {
            throw LibraryError.corruptStoredData
        }
        let trashed: Double? = row["trashedAt"]
        return LibraryDocument(
            id: id, title: row["title"], format: format, revision: row["revision"],
            importedAt: Date(timeIntervalSince1970: row["importedAt"]),
            trashedAt: trashed.map(Date.init(timeIntervalSince1970:))
        )
    }

    static func vocabulary(_ row: Row) throws -> VocabularyEntry {
        guard let id = UUID(uuidString: row["id"]),
              let familiarity = Familiarity(rawValue: row["familiarity"]) else {
            throw LibraryError.corruptStoredData
        }
        return VocabularyEntry(
            id: id, expression: row["expression"], normalizedExpression: row["normalizedExpression"],
            senseKey: row["senseKey"], familiarity: familiarity, notes: row["notes"],
            createdAt: Date(timeIntervalSince1970: row["createdAt"])
        )
    }

    static func occurrence(_ row: Row) throws -> VocabularyOccurrence {
        guard let id = UUID(uuidString: row["id"]),
              let vocabularyID = UUID(uuidString: row["vocabularyID"]) else {
            throw LibraryError.corruptStoredData
        }
        let data: Data? = row["explanation"]
        return VocabularyOccurrence(
            id: id, vocabularyID: vocabularyID,
            anchor: try JSONDecoder().decode(SourceAnchor.self, from: row["anchor"]),
            explanation: try data.map { try JSONDecoder().decode(Explanation.self, from: $0) },
            createdAt: Date(timeIntervalSince1970: row["createdAt"])
        )
    }
}
