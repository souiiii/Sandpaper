import Foundation
import NaturalLanguage

public struct LexicalEvidence: Codable, Equatable, Sendable {
    public let entry: LexicalEntry
    public let sense: LexicalSense
}

public struct LexicalCandidate: Codable, Equatable, Sendable {
    public let id: String
    public let anchor: SourceAnchor
    public let evidence: [LexicalEvidence]
}

public struct LexicalScan: Codable, Sendable {
    public let candidates: [LexicalCandidate]
    public let omittedCandidates: Int
}

public enum LexicalScanner {
    private struct Token { let range: NSRange; let text: String; let lemma: String }
    private static let words = try! NSRegularExpression(pattern: #"[\p{L}\p{M}]+(?:['’][\p{L}\p{M}]+)*|\p{N}+"#)

    static func normalize(_ text: String) -> String {
        let source = text as NSString
        return words.matches(in: text, range: NSRange(location: 0, length: source.length))
            .map { source.substring(with: $0.range).lowercased().replacingOccurrences(of: "’", with: "'") }.joined(separator: " ")
    }

    /// Bounded page work. Lemmas and dictionary possessive slots only generate lookup candidates;
    /// a matching phrase is never by itself evidence that its figurative sense applies.
    public static func scan(_ passage: AnalysisPassage, in store: LexiconStore, limit: Int = 32) throws -> LexicalScan {
        try passage.validate()
        guard (1...64).contains(limit) else { throw LibraryError.invalidInput("Invalid candidate limit.") }
        let text = passage.text, source = text as NSString
        let tagger = NLTagger(tagSchemes: [.lemma, .lexicalClass])
        tagger.string = text
        tagger.setLanguage(.english, range: text.startIndex..<text.endIndex)
        let tokens = words.matches(in: text, range: NSRange(location: 0, length: source.length)).map { match in
            let index = Range(match.range, in: text)!.lowerBound
            let lemma = tagger.tag(at: index, unit: .word, scheme: .lemma).0?.rawValue
            let surface = normalize(source.substring(with: match.range))
            return Token(range: match.range, text: surface, lemma: lemma.map(normalize) ?? surface)
        }
        var spans: [String: [NSRange]] = [:]
        let separators = CharacterSet.whitespacesAndNewlines.union(CharacterSet(charactersIn: "-‐‑"))
        for start in tokens.indices {
            try Task.checkCancellation()
            for end in start..<min(start + 10, tokens.count) {
                if end > start {
                    let gap = NSRange(location: NSMaxRange(tokens[end-1].range), length: tokens[end].range.location - NSMaxRange(tokens[end-1].range))
                    if source.substring(with: gap).unicodeScalars.contains(where: { !separators.contains($0) }) { break }
                }
                let part = Array(tokens[start...end])
                let range = NSRange(location: tokens[start].range.location, length: NSMaxRange(tokens[end].range) - tokens[start].range.location)
                var sequences = [part.map(\.text), part.map(\.lemma)]
                var inflected = part.map(\.text)
                inflected[0] = part[0].lemma
                sequences.append(inflected)
                for sequence in sequences {
                    let possessive = sequence.map { ["my", "your", "his", "her", "its", "our", "their"].contains($0) ? "one's" : $0 }
                    let object = possessive.enumerated().map { index, word in
                        index == possessive.count - 1 && ["me", "you", "him", "her", "us", "them", "one's"].contains(word) ? "one" : word
                    }
                    for key in Set([sequence.joined(separator: " "), possessive.joined(separator: " "), object.joined(separator: " ")]) {
                        spans[key, default: []].append(range)
                    }
                }
            }
        }
        let entries = try store.entries(for: Set(spans.keys))
        var matches: [NSRange: [String: LexicalEvidence]] = [:]
        for entry in entries {
            for form in Set(([entry.headword] + entry.forms).map(normalize)) {
                for range in spans[form] ?? [] {
                    for sense in entry.senses {
                        matches[range, default: [:]][entry.id + ":" + sense.id] = LexicalEvidence(entry: entry, sense: sense)
                    }
                }
            }
        }
        // Prefer complete expressions when a dense passage exceeds the explicit page budget.
        let ranked = matches.keys.sorted { $0.length == $1.length ? $0.location < $1.location : $0.length > $1.length }
        let selected = ranked.prefix(limit).sorted { $0.location == $1.location ? $0.length > $1.length : $0.location < $1.location }
        let candidates = try selected.map { range in
            let index = Range(range, in: text)!.lowerBound
            let tag = tagger.tag(at: index, unit: .word, scheme: .lexicalClass).0
            let pos: String? = switch tag { case .noun: "noun"; case .verb: "verb"; case .adjective: "adj"; case .adverb: "adv"; default: nil }
            let evidence = matches[range]!.values.sorted {
                let a = $0.entry.partOfSpeech == pos, b = $1.entry.partOfSpeech == pos
                if a != b { return a }
                return ($0.entry.id, $0.sense.id) < ($1.entry.id, $1.sense.id)
            }
            return LexicalCandidate(id: "l\(range.location)_\(range.length)", anchor: try passage.anchor(for: range), evidence: evidence)
        }
        return LexicalScan(candidates: candidates, omittedCandidates: max(0, matches.count - limit))
    }
}
