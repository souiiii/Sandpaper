import Foundation
import NaturalLanguage

public struct GroundedJudgment: Codable, Sendable {
    public let sense: Int
    public let confidence: Int
    public let value: Int
    public let memory: Int
    public let reason: String
}

public struct HybridStageMetrics: Codable, Sendable {
    public let stage: String
    public let metrics: InferenceMetrics?
}

public struct HybridDiscoveryDiagnostics: Codable, Sendable {
    public internal(set) var lexicalAnchors: [SourceAnchor]
    public internal(set) var omittedCandidates: Int
    public internal(set) var omittedSenses: Int = 0
    public internal(set) var judgments: [String: GroundedJudgment] = [:]
    public internal(set) var stages: [HybridStageMetrics] = []
    /// Retained for inspection even when a precise lexical highlight already occupies the sentence.
    public internal(set) var interpretiveCandidates: [DiscoveryCandidate] = []
    public internal(set) var completed = false
}

struct GroundedOption: Encodable {
    let id: Int
    let expression: String
    let definition: String
    let labels: [String]
}

struct GroundedInput: Encodable {
    let id: String
    let text: String
    let senses: [GroundedOption]
    let memories: [GroundedMemory]
}

struct GroundedMemory: Encodable { let id: Int; let expression: String; let meaning: String }
struct InterpretationSpan: Encodable { let id: String; let text: String; let range: NSRange
    enum CodingKeys: String, CodingKey { case id, text }
}

extension LlamaLocalEngine {
    public nonisolated static var hybridPromptVersion: String { "grounded-reading-3" }

    /// Lexical possibilities only, not a claim that a particular sense applies. No inference or network.
    public func lexicalInformation(for request: ExplanationRequest) throws -> [LexicalCandidate] {
        guard let lexicon else { return [] }
        return try relevantLexicalCandidates(request, lexicon: lexicon)
    }

    func groundedDiscovery(_ request: DiscoveryRequest, lexicon: LexiconStore) async throws -> [DiscoveryCandidate] {
        let scan = try LexicalScanner.scan(request.passage, in: lexicon)
        lastHybridDiagnostics = HybridDiscoveryDiagnostics(lexicalAnchors: scan.candidates.map(\.anchor), omittedCandidates: scan.omittedCandidates)
        var candidates: [DiscoveryCandidate] = []
        for start in stride(from: 0, to: scan.candidates.count, by: 4) {
            try Task.checkCancellation()
            let batch = Array(scan.candidates[start..<min(start + 4, scan.candidates.count)])
            var supplied: [String: ([LexicalEvidence], [KnownSense])] = [:]
            let inputs = batch.map { candidate in
                let evidence = boundedEvidence(candidate, limit: 8)
                lastHybridDiagnostics?.omittedSenses += max(0, candidate.evidence.count - evidence.count)
                let expressions = Set(evidence.map { TextNormalization.expression($0.entry.headword) })
                let memories = request.familiarity.filter {
                    expressions.contains(TextNormalization.expression($0.expression)) && !($0.meaning?.isEmpty ?? true)
                }
                supplied[candidate.id] = (evidence, memories)
                return GroundedInput(id: candidate.id, text: candidate.anchor.quote,
                    senses: evidence.enumerated().map { index, e in
                        GroundedOption(id: index + 1, expression: e.entry.headword, definition: e.sense.definition, labels: e.sense.tags)
                    }, memories: memories.enumerated().map { GroundedMemory(id: $0.offset + 1, expression: $0.element.expression, meaning: $0.element.meaning!) })
            }
            let data = try await complete(messages: HybridPrompts.assessment(passage: request.passage.text, candidates: inputs),
                schema: HybridPrompts.assessmentSchema(inputs), name: "grounded_discovery", maximumOutputTokens: 768)
            lastHybridDiagnostics?.stages.append(HybridStageMetrics(stage: "lexical", metrics: lastMetrics))
            let judgments: [String: GroundedJudgment]
            do { judgments = try JSONDecoder().decode([String: GroundedJudgment].self, from: data) }
            catch { throw AnalysisError.invalidModelOutput }
            guard Set(judgments.keys) == Set(batch.map(\.id)) else { throw AnalysisError.invalidModelOutput }
            for candidate in batch {
                let judgment = judgments[candidate.id]!
                let (evidence, memories) = supplied[candidate.id]!
                guard (0...evidence.count).contains(judgment.sense), (0...memories.count).contains(judgment.memory),
                      (0...2).contains(judgment.confidence), (0...2).contains(judgment.value),
                      !judgment.reason.isEmpty, judgment.reason.utf16.count <= 512 else { throw AnalysisError.invalidModelOutput }
                lastHybridDiagnostics?.judgments[candidate.id] = judgment
                guard judgment.sense > 0 else { continue }
                let chosen = evidence[judgment.sense - 1]
                let memory = judgment.memory > 0 && judgment.confidence == 2 ? memories[judgment.memory - 1] : nil
                // Memory spelling must agree with the CHOSEN entry, not another homograph option.
                let matchingMemory = memory.flatMap { TextNormalization.expression($0.expression) == TextNormalization.expression(chosen.entry.headword) ? $0 : nil }
                let assessment = try DiscoveryAssessment(expression: chosen.entry.headword,
                    contextualMeaning: chosen.sense.definition, interpretationConfidence: rating(judgment.confidence),
                    learningValue: rating(judgment.value), learningReason: judgment.reason,
                    signals: signals(chosen.sense.tags), matchedSenseKey: matchingMemory?.senseKey,
                    senseMatchConfidence: matchingMemory == nil ? nil : .high)
                candidates.append(DiscoveryCandidate(anchor: candidate.anchor, assessment: assessment))
            }
        }

        // An independent route for novel metaphors, implication and grammar; lexical coverage is not a gate.
        let spans = interpretationSpans(request.passage.text)
        if !spans.isEmpty {
            let data = try await complete(messages: HybridPrompts.interpretation(passage: request.passage.text, spans: spans,
                    covered: candidates.filter { $0.assessment.learningValue != .low }.map { $0.anchor.quote }),
                schema: HybridPrompts.interpretationSchema(spans), name: "interpretive_discovery", maximumOutputTokens: 768)
            lastHybridDiagnostics?.stages.append(HybridStageMetrics(stage: "interpretive", metrics: lastMetrics))
            struct Output: Decodable { let candidates: [Item] }
            struct Item: Decodable { let span: String; let meaning: String; let reason: String; let confidence: Int; let value: Int }
            let output: Output
            do { output = try JSONDecoder().decode(Output.self, from: data) } catch { throw AnalysisError.invalidModelOutput }
            // Several valid insights may refer to one sentence. The shared overlap policy
            // already resolves these; redundancy is not an invented source location.
            guard output.candidates.count <= 4 else { throw AnalysisError.invalidModelOutput }
            for item in output.candidates {
                guard let span = spans.first(where: { $0.id == item.span }), (0...2).contains(item.confidence), (0...2).contains(item.value) else { throw AnalysisError.invalidModelOutput }
                let anchor = try request.passage.anchor(for: span.range)
                let assessment = try DiscoveryAssessment(expression: anchor.quote, contextualMeaning: item.meaning,
                    interpretationConfidence: rating(item.confidence), learningValue: rating(item.value),
                    learningReason: item.reason, signals: [.toneOrImplication])
                let interpretation = DiscoveryCandidate(anchor: anchor, assessment: assessment)
                lastHybridDiagnostics?.interpretiveCandidates.append(interpretation)
                // Preserve both routes. The shared policy chooses among overlapping highlights
                // while retaining the other assessments, rather than discarding clause insights
                // merely because the dictionary also matched an ordinary word in that sentence.
                candidates.append(interpretation)
            }
        }
        _ = try DiscoveryPolicy.evaluate(candidates, for: request)
        lastHybridDiagnostics?.completed = true
        return candidates
    }

    func groundedExplanation(_ request: ExplanationRequest, lexicon: LexiconStore,
        onUpdate: @escaping @Sendable (String) async -> Void) async throws -> Explanation {
        let matches = try relevantLexicalCandidates(request, lexicon: lexicon)
        var seen: Set<String> = []
        let evidence = Array(matches.flatMap { boundedEvidence($0, limit: 8) }.filter {
            seen.insert($0.entry.id + ":" + $0.sense.id).inserted
        }.prefix(12))
        let options = evidence.enumerated().map { GroundedOption(id: $0.offset + 1, expression: $0.element.entry.headword,
            definition: $0.element.sense.definition, labels: $0.element.sense.tags) }
        let data = try await complete(messages: HybridPrompts.explanation(request, options: options),
            schema: HybridPrompts.explanationSchema(), name: "grounded_explanation",
            maximumOutputTokens: 512, onUpdate: onUpdate)
        struct Output: Decodable { let meaning: String }
        let output: Output
        do { output = try JSONDecoder().decode(Output.self, from: data) } catch { throw AnalysisError.invalidModelOutput }
        let meaning = output.meaning.trimmingCharacters(in: .whitespacesAndNewlines)
        guard meaning.count >= 12, let last = meaning.last, ".!?".contains(last),
              !meaning.contains("\""), !meaning.contains("\n") else { throw AnalysisError.invalidModelOutput }
        // Dictionary possibilities remain separately available through lexicalInformation.
        // A model choosing a citation does not prove that definition applies in context.
        let result = Explanation(meaning: meaning, details: [])
        try result.validate()
        return result
    }

    private func relevantLexicalCandidates(_ request: ExplanationRequest, lexicon: LexiconStore) throws -> [LexicalCandidate] {
        let low = request.selection.utf16Offset, high = low + request.selection.utf16Length
        return try LexicalScanner.scan(request.passage, in: lexicon, limit: 64).candidates.filter {
            $0.anchor.utf16Offset < high && low < $0.anchor.utf16Offset + $0.anchor.utf16Length
        }.sorted { $0.anchor.utf16Length > $1.anchor.utf16Length }
    }

    private func rating(_ value: Int) -> DiscoveryRating { value == 2 ? .high : value == 1 ? .medium : .low }

    private func boundedEvidence(_ candidate: LexicalCandidate, limit: Int) -> [LexicalEvidence] {
        // Avoid filling the entire budget with one highly polysemous homograph. Dictionary
        // cross-reference boilerplate is retained in lookup, but is not a contextual definition.
        let usable = candidate.evidence.filter { !$0.sense.definition.lowercased().hasPrefix("used other than") }
        var order: [String] = []
        var groups: [String: [LexicalEvidence]] = [:]
        for item in usable {
            if groups[item.entry.id] == nil { order.append(item.entry.id) }
            groups[item.entry.id, default: []].append(item)
        }
        var result: [LexicalEvidence] = []
        var index = 0
        while result.count < limit {
            var added = false
            for id in order where index < groups[id]!.count {
                result.append(groups[id]![index]); added = true
                if result.count == limit { break }
            }
            if !added { break }
            index += 1
        }
        return result
    }
    private func signals(_ tags: [String]) -> [LearningSignal] {
        var result: [LearningSignal] = []
        if tags.contains("idiomatic") { result.append(.idiom) }
        if tags.contains("figuratively") || tags.contains("figurative") { result.append(.figurativeMeaning) }
        if tags.contains("archaic") || tags.contains("dated") { result.append(.historicalUsage) }
        if tags.contains("slang") || tags.contains("informal") { result.append(.informalUsage) }
        return result.isEmpty ? [.usefulVocabulary] : result
    }

    private func interpretationSpans(_ text: String) -> [InterpretationSpan] {
        let tokenizer = NLTokenizer(unit: .sentence)
        tokenizer.string = text
        tokenizer.setLanguage(.english)
        var spans: [InterpretationSpan] = []
        tokenizer.enumerateTokens(in: text.startIndex..<text.endIndex) { range, _ in
            // Split unusually long sentences at whitespace, preserving exact UTF-16 anchors.
            var start = range.lowerBound
            while start < range.upperBound {
                var end = start
                var count = 0
                while end < range.upperBound && count + text[end].utf16.count <= 500 {
                    count += text[end].utf16.count
                    end = text.index(after: end)
                }
                if end < range.upperBound, let space = text[start..<end].lastIndex(where: \.isWhitespace) { end = space }
                if end == start { end = text.index(after: start) }
                let piece = String(text[start..<end]).trimmingCharacters(in: .whitespacesAndNewlines)
                if !piece.isEmpty, let exact = text.range(of: piece, range: start..<end) {
                    let sourceRange = NSRange(exact, in: text)
                    spans.append(InterpretationSpan(id: "s\(sourceRange.location)", text: piece, range: sourceRange))
                }
                start = end
            }
            return true
        }
        return spans
    }
}
