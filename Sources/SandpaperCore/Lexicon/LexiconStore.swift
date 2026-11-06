import Foundation
import GRDB

public struct LexicalSense: Codable, Equatable, Sendable {
    public let id: String
    public let definition: String
    public let tags: [String]
}

/// Imported lexical text retains its own provenance; generated prose cannot become a lexical fact.
public struct LexicalEntry: Codable, Equatable, Sendable {
    public let id: String
    public let headword: String
    public let partOfSpeech: String
    public let forms: [String]
    public let senses: [LexicalSense]
    public let source: String
    public let sourceURL: String
    public let licenseURL: String
    public let datasetVersion: String

    func validate() throws {
        guard !id.isEmpty, id.utf16.count <= 512, !headword.isEmpty, headword.utf16.count <= 512,
              !partOfSpeech.isEmpty, partOfSpeech.utf16.count <= 64,
              forms.count <= 256, forms.allSatisfy({ !$0.isEmpty && $0.utf16.count <= 512 }),
              !senses.isEmpty, senses.count <= 256, Set(senses.map(\.id)).count == senses.count,
              senses.allSatisfy({ !$0.id.isEmpty && $0.id.utf16.count <= 512 && !$0.definition.isEmpty
                  && $0.definition.utf16.count <= 4_096 && $0.tags.count <= 64
                  && $0.tags.allSatisfy({ $0.utf16.count <= 128 }) }),
              !source.isEmpty, source.utf16.count <= 512, !datasetVersion.isEmpty, datasetVersion.utf16.count <= 128,
              [sourceURL, licenseURL].allSatisfy({ value in
                  guard value.utf16.count <= 2_048, let url = URL(string: value) else { return false }
                  return url.scheme == "https" && url.host != nil
              }) else {
            throw LibraryError.invalidInput("Invalid lexical record.")
        }
    }
}

/// An independently installed, indexed dictionary. Opening/lookup never needs a network or model.
public final class LexiconStore: Sendable {
    private let database: DatabaseQueue

    public init(at url: URL) throws {
        var configuration = Configuration()
        configuration.readonly = true
        database = try DatabaseQueue(path: url.path, configuration: configuration)
        try database.read { db in
            guard try Int.fetchOne(db, sql: "PRAGMA user_version") == 1 else {
                throw LibraryError.invalidInput("Unsupported lexical database version.")
            }
        }
    }

    /// Builds an index from normalized JSONL records in one transaction. Existing files are never replaced.
    /// Raw Wiktextract normalization is performed separately, retaining source/version/license metadata.
    public static func build(fromJSONL source: URL, at destination: URL) throws {
        guard source.standardizedFileURL != destination.standardizedFileURL else {
            throw LibraryError.invalidInput("Dictionary input and output must differ.")
        }
        try Data().write(to: destination, options: .withoutOverwriting)
        do {
            let queue = try DatabaseQueue(path: destination.path)
            try queue.write { db in
                try db.execute(sql: "CREATE TABLE entries (id TEXT PRIMARY KEY NOT NULL, payload BLOB NOT NULL)")
                try db.execute(sql: "CREATE TABLE forms (form TEXT NOT NULL, entryID TEXT NOT NULL REFERENCES entries(id), PRIMARY KEY(form, entryID))")
                let handle = try FileHandle(forReadingFrom: source)
                defer { try? handle.close() }
                var buffer = Data()
                func insert(_ line: Data) throws {
                    guard line.count <= 4_194_304 else { throw LibraryError.invalidInput("Lexical record exceeds import limit.") }
                    if line.allSatisfy({ $0 == 10 || $0 == 13 || $0 == 32 || $0 == 9 }) { return }
                    let entry = try JSONDecoder().decode(LexicalEntry.self, from: line)
                    try entry.validate()
                    try db.execute(sql: "INSERT INTO entries VALUES (?, ?)", arguments: [entry.id, try LibraryDatabase.encode(entry)])
                    for form in Set(([entry.headword] + entry.forms).map(LexicalScanner.normalize)) where !form.isEmpty {
                        try db.execute(sql: "INSERT INTO forms VALUES (?, ?)", arguments: [form, entry.id])
                    }
                }
                while let chunk = try handle.read(upToCount: 65_536), !chunk.isEmpty {
                    try Task.checkCancellation()
                    buffer.append(chunk)
                    while let newline = buffer.firstIndex(of: 10) {
                        try insert(Data(buffer[..<newline]))
                        buffer.removeSubrange(...newline)
                    }
                    guard buffer.count <= 4_194_304 else { throw LibraryError.invalidInput("Lexical record exceeds import limit.") }
                }
                if !buffer.isEmpty { try insert(buffer) }
                try db.execute(sql: "PRAGMA user_version = 1")
            }
        } catch {
            try? FileManager.default.removeItem(at: destination)
            throw error
        }
    }

    public func lookup(_ expression: String) throws -> [LexicalEntry] {
        try entries(for: [LexicalScanner.normalize(expression)])
    }

    func entries(for forms: Set<String>) throws -> [LexicalEntry] {
        try database.read { db in
            var entries: [String: LexicalEntry] = [:]
            let sorted = forms.sorted()
            for start in stride(from: 0, to: sorted.count, by: 200) {
                try Task.checkCancellation()
                let batch = Array(sorted[start..<min(start + 200, sorted.count)])
                let marks = Array(repeating: "?", count: batch.count).joined(separator: ",")
                let rows = try Row.fetchAll(db, sql: "SELECT DISTINCT e.id, e.payload FROM entries e JOIN forms f ON e.id=f.entryID WHERE f.form IN (\(marks))", arguments: StatementArguments(batch))
                for row in rows {
                    let entry = try JSONDecoder().decode(LexicalEntry.self, from: row["payload"])
                    try entry.validate()
                    entries[entry.id] = entry
                }
            }
            return entries.values.sorted { $0.id < $1.id }
        }
    }
}
