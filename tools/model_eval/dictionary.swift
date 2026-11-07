import CoreServices
import Foundation
import NaturalLanguage

// Mirrors the reader's exact-phrase/first-word-lemma lookup and bounded excerpt.
func definition(_ query: String) -> String? {
    DCSCopyTextDefinition(nil, query as CFString, CFRange(location: 0, length: query.utf16.count))?.takeRetainedValue() as String?
}
for query in CommandLine.arguments.dropFirst() {
    let start = Date()
    var headword = query
    var article = definition(query)
    let words = query.split(whereSeparator: \.isWhitespace)
    if article == nil, (2...8).contains(words.count), let first = words.first {
        let tagger = NLTagger(tagSchemes: [.lemma]); tagger.string = query
        tagger.setLanguage(.english, range: query.startIndex..<query.endIndex)
        let lemma = first.lowercased() == "fell" ? "fall" : tagger.tag(at: query.startIndex, unit: .word, scheme: .lemma).0?.rawValue
        if let lemma, lemma.caseInsensitiveCompare(String(first)) != .orderedSame {
            let candidate = ([lemma] + words.dropFirst().map(String.init)).joined(separator: " ")
            if let text = definition(candidate), text.range(of: candidate, options: .caseInsensitive) != nil { article = text; headword = candidate }
        }
    }
    let source = (article ?? "") as NSString
    var end = source.length
    let origin = source.range(of: " ORIGIN ")
    if origin.location != NSNotFound { end = origin.location }
    var offset = 0
    if headword.split(whereSeparator: \.isWhitespace).count > 1 {
        let normalized = (article ?? "").replacingOccurrences(of: "’", with: "'") as NSString
        let term = headword.replacingOccurrences(of: "’", with: "'")
        let match = normalized.range(of: term, options: [.caseInsensitive, .backwards], range: NSRange(location: 0, length: end))
        if match.location != NSNotFound {
            offset = match.location
            let stop = source.range(of: ". ", options: [], range: NSRange(location: NSMaxRange(match), length: end - NSMaxRange(match)))
            if stop.location != NSNotFound { end = min(end, stop.location + 1) }
        } else { end = 0 }
    }
    end = min(end, offset + 1000)
    if end > 0, end < source.length { end = source.rangeOfComposedCharacterSequence(at: end).location }
    let text = end > offset ? source.substring(with: NSRange(location: offset, length: end-offset)) : ""
    let result: [String: Any] = ["query": query, "headword": headword, "text": text, "seconds": Date().timeIntervalSince(start)]
    let data = try JSONSerialization.data(withJSONObject: result, options: [.sortedKeys])
    print(String(decoding: data, as: UTF8.self))
}
