import Foundation

/// A verbatim, bounded excerpt of a retrieved article. It is a lexical possibility,
/// not a claim that the article's sense applies to the selected passage.
public struct DictionaryEvidence: Codable, Equatable, Sendable {
    public let entryID: String
    public let provider: String
    public let query: String
    public let text: String

    public init(entry: DictionaryEntry, range: NSRange) throws {
        guard range.location >= 0, range.length > 0, range.location <= entry.text.utf16.count,
              range.length <= entry.text.utf16.count - range.location,
              let selected = Range(range, in: entry.text), NSRange(selected, in: entry.text) == range,
              String(entry.text[selected]).utf16.count == range.length else {
            throw LibraryError.invalidInput("Dictionary evidence must be an exact article excerpt.")
        }
        entryID = entry.id; provider = entry.provider; query = entry.query; text = String(entry.text[selected])
        try validate()
    }

    func validate() throws {
        guard !entryID.isEmpty, entryID.utf16.count <= 512, !provider.isEmpty, provider.utf16.count <= 512,
              !query.isEmpty, query.utf16.count <= 512, !text.isEmpty, text.utf16.count <= 1_200 else {
            throw LibraryError.invalidInput("Dictionary evidence exceeds its bounds.")
        }
    }

    static func relevantExcerpts(from entries: [DictionaryEntry]) throws -> [DictionaryEvidence] {
        try entries.prefix(2).compactMap { entry in
            let source = entry.text as NSString
            var end = source.length
            // Root-word origins must not become fabricated origins of a phrasal expression.
            let origin = source.range(of: " ORIGIN ")
            if origin.location != NSNotFound { end = origin.location }
            guard end > 0 else { return nil }
            var start = 0
            let isPhrase = entry.query.split(whereSeparator: \.isWhitespace).count > 1
            if isPhrase {
                let normalized = entry.text.replacingOccurrences(of: "’", with: "'") as NSString
                let term = entry.query.replacingOccurrences(of: "’", with: "'")
                let match = normalized.range(of: term, options: [.caseInsensitive, .backwards], range: NSRange(location: 0, length: end))
                guard match.location != NSNotFound else { return nil }
                start = match.location
                let stop = source.range(of: ". ", options: [], range: NSRange(location: NSMaxRange(match), length: end - NSMaxRange(match)))
                if stop.location != NSNotFound { end = min(end, stop.location + 1) }
            }
            end = min(end, start + 1_000)
            // Never split a surrogate or a composed character at the size boundary.
            if end < source.length { end = source.rangeOfComposedCharacterSequence(at: end).location }
            guard end > start else { return nil }
            return try DictionaryEvidence(entry: entry, range: NSRange(location: start, length: end - start))
        }
    }
}
