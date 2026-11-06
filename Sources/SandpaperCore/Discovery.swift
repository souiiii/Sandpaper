import Foundation

public struct KnownSense: Codable, Equatable, Sendable {
    public let expression: String
    public let senseKey: String
    /// An opaque ID alone does not establish what the user knows.
    public let meaning: String?
    public let familiarity: Familiarity

    public init(expression: String, senseKey: String, meaning: String? = nil, familiarity: Familiarity) {
        self.expression = expression
        self.senseKey = senseKey
        self.meaning = meaning
        self.familiarity = familiarity
    }
}

public enum DiscoverySensitivity: String, Codable, Sendable {
    case selective, balanced, exploratory
}

public struct DiscoveryRequest: Codable, Equatable, Sendable {
    public let passage: AnalysisPassage
    public let familiarity: [KnownSense]
    public let previouslyExplainedSenseKeys: [String]
    public let sensitivity: DiscoverySensitivity

    public init(
        passage: AnalysisPassage, familiarity: [KnownSense] = [],
        previouslyExplainedSenseKeys: [String] = [], sensitivity: DiscoverySensitivity = .balanced
    ) throws {
        self.passage = passage
        self.familiarity = familiarity
        self.previouslyExplainedSenseKeys = previouslyExplainedSenseKeys
        self.sensitivity = sensitivity
        try validate()
    }

    func validate() throws {
        try passage.validate()
        guard familiarity.count <= 256,
              familiarity.allSatisfy({
                  !$0.expression.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                      && $0.expression.utf16.count <= 512
                      && !$0.senseKey.isEmpty && $0.senseKey.utf16.count <= 512
                      && ($0.meaning?.utf16.count ?? 0) <= 2_048
              }),
              familiarity.reduce(0, { $0 + $1.expression.utf16.count + $1.senseKey.utf16.count + ($1.meaning?.utf16.count ?? 0) }) <= 12_288,
              previouslyExplainedSenseKeys.count <= 256,
              previouslyExplainedSenseKeys.allSatisfy({ key in familiarity.contains { $0.senseKey == key } }) else {
            throw LibraryError.invalidInput("Discovery requires bounded, relevant sense memories.")
        }
    }
}

/// Ordinal model judgments, not calibrated probabilities or word-frequency scores.
public enum DiscoveryRating: String, Codable, Sendable {
    case low, medium, high

    var rank: Int {
        switch self { case .low: 0; case .medium: 1; case .high: 2 }
    }
}

public enum LearningSignal: String, Codable, Sendable {
    case idiom, figurativeMeaning, historicalUsage, toneOrImplication
    case grammar, usefulVocabulary, informalUsage, semanticNuance
}

public struct DiscoveryAssessment: Codable, Equatable, Sendable {
    public let expression: String
    public let contextualMeaning: String
    public let interpretationConfidence: DiscoveryRating
    public let learningValue: DiscoveryRating
    public let learningReason: String
    public let signals: [LearningSignal]
    /// This must reference a supplied memory, never a newly invented stable ID.
    public let matchedSenseKey: String?
    public let senseMatchConfidence: DiscoveryRating?

    public init(
        expression: String, contextualMeaning: String, interpretationConfidence: DiscoveryRating,
        learningValue: DiscoveryRating, learningReason: String, signals: [LearningSignal],
        matchedSenseKey: String? = nil, senseMatchConfidence: DiscoveryRating? = nil
    ) throws {
        self.expression = expression
        self.contextualMeaning = contextualMeaning
        self.interpretationConfidence = interpretationConfidence
        self.learningValue = learningValue
        self.learningReason = learningReason
        self.signals = signals
        self.matchedSenseKey = matchedSenseKey
        self.senseMatchConfidence = senseMatchConfidence
        try validate()
    }

    func validate() throws {
        guard !TextNormalization.expression(expression).isEmpty, expression.utf16.count <= 512,
              !contextualMeaning.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              contextualMeaning.utf16.count <= 2_048,
              !learningReason.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              learningReason.utf16.count <= 2_048, !signals.isEmpty, signals.count <= 8,
              Set(signals).count == signals.count,
              (matchedSenseKey == nil) == (senseMatchConfidence == nil),
              matchedSenseKey.map({ !$0.isEmpty && $0.utf16.count <= 512 }) ?? true else {
            throw AnalysisError.invalidModelOutput
        }
    }
}

public struct DiscoveryCandidate: Codable, Equatable, Sendable {
    public let anchor: SourceAnchor
    public let assessment: DiscoveryAssessment

    public init(anchor: SourceAnchor, assessment: DiscoveryAssessment) {
        self.anchor = anchor
        self.assessment = assessment
    }
}

public enum DiscoveredFamiliarity: String, Codable, Sendable {
    case unknown, unfamiliar, learning, known
}

public struct FamiliarityJudgment: Codable, Equatable, Sendable {
    public let state: DiscoveredFamiliarity
    /// Non-nil only for a clear match to an explicit memory with a meaning.
    public let supportingSenseKey: String?
}

public enum HighlightDecision: String, Codable, Sendable {
    case eligible, lowLearningValue, uncertainMeaning, alreadyKnown, alreadyExplained, overlappingSelection
}

public struct DiscoverySuggestion: Codable, Equatable, Sendable {
    public let candidate: DiscoveryCandidate
    public let familiarity: FamiliarityJudgment
    public let decision: HighlightDecision

    public var anchor: SourceAnchor { candidate.anchor }
}

public struct DiscoveryReport: Codable, Equatable, Sendable {
    /// Includes suppressed candidates so decisions can be inspected and evaluated.
    public let assessments: [DiscoverySuggestion]
    public var highlights: [DiscoverySuggestion] { assessments.filter { $0.decision == .eligible } }
}

enum DiscoveryPolicy {
    static func evaluate(_ candidates: [DiscoveryCandidate], for request: DiscoveryRequest) throws -> DiscoveryReport {
        try request.validate()
        guard candidates.count <= 64 else { throw AnalysisError.invalidModelOutput }
        var suggestions = try candidates.map { candidate in
            try candidate.assessment.validate()
            do { _ = try ExplanationRequest(passage: request.passage, selection: candidate.anchor) }
            catch { throw AnalysisError.invalidModelOutput }
            let assessment = candidate.assessment
            if let key = assessment.matchedSenseKey,
               !request.familiarity.contains(where: { $0.senseKey == key }) {
                throw AnalysisError.invalidModelOutput
            }
            let memory = request.familiarity.first {
                $0.senseKey == assessment.matchedSenseKey
                    && TextNormalization.expression($0.expression) == TextNormalization.expression(assessment.expression)
                    && !($0.meaning?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ?? true)
                    && assessment.senseMatchConfidence == .high
                    && assessment.interpretationConfidence == .high
            }
            let familiarity = FamiliarityJudgment(
                state: memory.map {
                    switch $0.familiarity {
                    case .unfamiliar: .unfamiliar
                    case .learning: .learning
                    case .known: .known
                    }
                } ?? .unknown,
                supportingSenseKey: memory?.senseKey
            )
            let decision: HighlightDecision
            if assessment.learningValue == .low {
                decision = .lowLearningValue
            } else if assessment.interpretationConfidence == .low
                || (assessment.interpretationConfidence == .medium && request.sensitivity != .exploratory) {
                decision = .uncertainMeaning
            } else if memory?.familiarity == .known {
                decision = .alreadyKnown
            } else if let memory, request.previouslyExplainedSenseKeys.contains(memory.senseKey) {
                decision = .alreadyExplained
            } else if request.sensitivity == .selective && assessment.learningValue != .high {
                decision = .lowLearningValue
            } else {
                decision = .eligible
            }
            return DiscoverySuggestion(candidate: candidate, familiarity: familiarity, decision: decision)
        }
        // Retain the strongest assessment when interesting spans overlap. A quota
        // never forces a selection or discards non-overlapping worthwhile spans.
        let ranked = suggestions.indices.sorted { lhs, rhs in
            let a = suggestions[lhs].candidate
            let b = suggestions[rhs].candidate
            if a.assessment.learningValue != b.assessment.learningValue {
                return a.assessment.learningValue.rank > b.assessment.learningValue.rank
            }
            if a.assessment.interpretationConfidence != b.assessment.interpretationConfidence {
                return a.assessment.interpretationConfidence.rank > b.assessment.interpretationConfidence.rank
            }
            if a.anchor.utf16Length != b.anchor.utf16Length { return a.anchor.utf16Length < b.anchor.utf16Length }
            if a.anchor.utf16Offset != b.anchor.utf16Offset { return a.anchor.utf16Offset < b.anchor.utf16Offset }
            return lhs < rhs
        }
        var selected: [SourceAnchor] = []
        for index in ranked where suggestions[index].decision == .eligible {
            let suggestion = suggestions[index]
            let anchor = suggestion.anchor
            if selected.contains(where: {
                anchor.utf16Offset < $0.utf16Offset + $0.utf16Length
                    && $0.utf16Offset < anchor.utf16Offset + anchor.utf16Length
            }) {
                suggestions[index] = DiscoverySuggestion(
                    candidate: suggestion.candidate, familiarity: suggestion.familiarity, decision: .overlappingSelection
                )
            } else { selected.append(anchor) }
        }
        return DiscoveryReport(assessments: suggestions.sorted { $0.anchor.utf16Offset < $1.anchor.utf16Offset })
    }
}
