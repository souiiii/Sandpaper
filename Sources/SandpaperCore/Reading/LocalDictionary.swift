import CoreServices
import CryptoKit
import Foundation

public struct DictionaryEntry: Identifiable, Equatable, Sendable {
    public let id: String
    public let query: String
    public let text: String
    public let provider: String

    public init(id: String, query: String, text: String, provider: String) {
        self.id = id; self.query = query; self.text = text; self.provider = provider
    }
}

public protocol LocalDictionary: Sendable {
    func lookup(_ expression: String) async throws -> [DictionaryEntry]
}

/// Uses installed, active system dictionaries. A missing definition is an empty result,
/// never a generated answer. The system API returns articles, not structured sense IDs.
public actor MacOSDictionary: LocalDictionary {
    private var cache: [(String, [DictionaryEntry])] = []
    public init() {}

    public func lookup(_ expression: String) throws -> [DictionaryEntry] {
        try Task.checkCancellation()
        let query = expression.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty, query.utf16.count <= 512 else { throw LibraryError.invalidInput("Dictionary selections must contain 1–512 UTF-16 units.") }
        if let index = cache.firstIndex(where: { $0.0 == query }) {
            let value = cache.remove(at: index); cache.append(value); return value.1
        }
        let definition = DCSCopyTextDefinition(nil, query as CFString, CFRange(location: 0, length: query.utf16.count))?.takeRetainedValue() as String?
        try Task.checkCancellation()
        var entries: [DictionaryEntry] = []
        if let definition, !definition.isEmpty {
            let id = SHA256.hash(data: Data((query + "\0" + definition).utf8)).map { String(format: "%02x", $0) }.joined()
            entries = [DictionaryEntry(id: "macos:" + id, query: query, text: definition, provider: "macOS active dictionaries")]
        }
        // Bound retained article text as well as entry count.
        if (definition?.utf8.count ?? 0) <= 262_144 {
            cache.append((query, entries))
            while cache.count > 32 || cache.reduce(0, { $0 + $1.1.reduce(0, { $0 + $1.text.utf8.count }) }) > 2_097_152 { cache.removeFirst() }
        }
        return entries
    }
}
