import CoreServices
import CryptoKit
import Foundation
import NaturalLanguage

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
        var headword = query
        var definition = Self.definition(query)
        // Retry an inflected phrase only after an exact miss. Do not fall back to a
        // component word: its definition could be mistaken for the whole idiom.
        if definition == nil, let lemma = Self.phraseLemma(query), let candidate = Self.definition(lemma),
           candidate.range(of: lemma, options: .caseInsensitive) != nil {
            headword = lemma; definition = candidate
        }
        try Task.checkCancellation()
        var entries: [DictionaryEntry] = []
        if let definition, !definition.isEmpty {
            let id = SHA256.hash(data: Data((headword + "\0" + definition).utf8)).map { String(format: "%02x", $0) }.joined()
            entries = [DictionaryEntry(id: "macos:" + id, query: headword, text: definition, provider: "macOS active dictionaries")]
        }
        // Bound retained article text as well as entry count.
        if (definition?.utf8.count ?? 0) <= 262_144 {
            cache.append((query, entries))
            while cache.count > 32 || cache.reduce(0, { $0 + $1.1.reduce(0, { $0 + $1.text.utf8.count }) }) > 2_097_152 { cache.removeFirst() }
        }
        return entries
    }

    private static func definition(_ query: String) -> String? {
        DCSCopyTextDefinition(nil, query as CFString, CFRange(location: 0, length: query.utf16.count))?.takeRetainedValue() as String?
    }

    static func phraseLemma(_ query: String) -> String? {
        let words = query.split(whereSeparator: \.isWhitespace)
        guard (2...8).contains(words.count), let first = words.first else { return nil }
        let tagger = NLTagger(tagSchemes: [.lemma])
        tagger.string = query
        tagger.setLanguage(.english, range: query.startIndex..<query.endIndex)
        // The system tagger treats the homograph "fell" as the tree-cutting verb,
        // even in "fell through". Retry the other common verb only on an exact miss.
        let lemma = first.lowercased() == "fell" ? "fall"
            : tagger.tag(at: query.startIndex, unit: .word, scheme: .lemma).0?.rawValue
        guard let lemma, lemma.caseInsensitiveCompare(String(first)) != .orderedSame else { return nil }
        return ([lemma] + words.dropFirst().map(String.init)).joined(separator: " ")
    }
}
