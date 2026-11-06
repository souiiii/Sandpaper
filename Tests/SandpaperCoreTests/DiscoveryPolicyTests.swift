import Foundation
import Testing
@testable import SandpaperCore

struct DiscoveryPolicyTests {
    @Test func familiarLiteralSenseDoesNotSuppressFigurativeMeaning() throws {
        let request = try request(memories: [KnownSense(
            expression: "fig leaf", senseKey: "leaf", meaning: "A leaf of a fig tree.", familiarity: .known
        )])
        let candidate = try candidate(request, matchedKey: nil, signals: [.figurativeMeaning])
        let report = try DiscoveryPolicy.evaluate([candidate], for: request)
        #expect(report.highlights.count == 1)
        #expect(report.assessments.first?.familiarity.state == .unknown)
        #expect(report.highlights.first?.candidate.assessment.contextualMeaning == "An inadequate disguise for an embarrassing truth.")
    }

    @Test func clearKnownSenseIsSuppressedWithoutChangingIntrinsicValue() throws {
        let request = try request(memories: [memory()])
        let candidate = try candidate(request, matchedKey: "concealment")
        let report = try DiscoveryPolicy.evaluate([candidate], for: request)
        #expect(report.highlights.isEmpty)
        #expect(report.assessments.first?.decision == .alreadyKnown)
        #expect(report.assessments.first?.candidate.assessment.learningValue == .high)
        #expect(report.assessments.first?.familiarity.supportingSenseKey == "concealment")
    }

    @Test func opaqueOrUncertainMemoryDoesNotEstablishFamiliarity() throws {
        let opaque = KnownSense(expression: "fig leaf", senseKey: "concealment", familiarity: .known)
        let request = try request(memories: [opaque])
        let report = try DiscoveryPolicy.evaluate([candidate(request, matchedKey: "concealment")], for: request)
        #expect(report.highlights.count == 1)
        #expect(report.assessments.first?.familiarity.state == .unknown)

        let uncertain = try self.request(memories: [memory()])
        let uncertainCandidate = try candidate(uncertain, matchedKey: "concealment", matchConfidence: .medium)
        #expect(try DiscoveryPolicy.evaluate([uncertainCandidate], for: uncertain).highlights.count == 1)
    }

    @Test func modelCannotInventKnowledgeOrBorrowAnUnrelatedExpressionMemory() throws {
        let request = try request(memories: [KnownSense(
            expression: "a different expression", senseKey: "concealment", meaning: "Concealment.", familiarity: .known
        )])
        let candidate = try candidate(request, matchedKey: "concealment")
        #expect(try DiscoveryPolicy.evaluate([candidate], for: request).highlights.count == 1)
        let invented = try self.candidate(request, matchedKey: "invented-id")
        #expect(throws: AnalysisError.invalidModelOutput) {
            try DiscoveryPolicy.evaluate([invented], for: request)
        }
    }

    @Test func repetitionAndFamiliarityAreSeparateDecisions() throws {
        let request = try request(
            memories: [memory(familiarity: .learning)], explained: ["concealment"]
        )
        let report = try DiscoveryPolicy.evaluate([candidate(request, matchedKey: "concealment")], for: request)
        #expect(report.assessments.first?.decision == .alreadyExplained)
        #expect(report.assessments.first?.familiarity.state == .learning)
        #expect(report.highlights.isEmpty)
    }

    @Test func rareButLowValueTextDoesNotSatisfyAnyQuota() throws {
        let request = try request()
        let candidate = try candidate(request, value: .low, signals: [.usefulVocabulary])
        #expect(try DiscoveryPolicy.evaluate([candidate], for: request).highlights.isEmpty)
        #expect(try DiscoveryPolicy.evaluate([], for: request).highlights.isEmpty)
    }

    @Test func uncertainMeaningIsNotAutomaticallyHighlighted() throws {
        let request = try request()
        let candidate = try candidate(request, interpretation: .low)
        #expect(try DiscoveryPolicy.evaluate([candidate], for: request).assessments.first?.decision == .uncertainMeaning)
    }

    @Test func sensitivityChangesThresholdWithoutInventingSelections() throws {
        let balanced = try request()
        let selective = try request(sensitivity: .selective)
        // Both requests need the same passage identity for this shared candidate.
        let selected = try DiscoveryRequest(passage: balanced.passage, sensitivity: selective.sensitivity)
        let candidate = try candidate(balanced, value: .medium)
        #expect(try DiscoveryPolicy.evaluate([candidate], for: balanced).highlights.count == 1)
        #expect(try DiscoveryPolicy.evaluate([candidate], for: selected).highlights.isEmpty)
    }

    @Test func overlappingCandidatesRetainStrongerAssessment() throws {
        let request = try request()
        let candidate = try candidate(request)
        let weaker = DiscoveryCandidate(anchor: candidate.anchor, assessment: try DiscoveryAssessment(
            expression: "fig leaf", contextualMeaning: "A disguise.", interpretationConfidence: .high,
            learningValue: .medium, learningReason: "Figurative usage.", signals: [.figurativeMeaning]
        ))
        let report = try DiscoveryPolicy.evaluate([weaker, candidate], for: request)
        #expect(report.highlights.count == 1)
        #expect(report.highlights.first?.candidate.assessment.learningValue == .high)
        #expect(report.assessments.contains { $0.decision == .overlappingSelection })
    }

    @Test func invalidSourceOrEmptyAssessmentIsRejected() throws {
        let request = try request()
        let foreign = try self.request()
        #expect(throws: AnalysisError.invalidModelOutput) {
            try DiscoveryPolicy.evaluate([candidate(foreign)], for: request)
        }
        #expect(throws: AnalysisError.invalidModelOutput) {
            try DiscoveryAssessment(
                expression: "fig leaf", contextualMeaning: "", interpretationConfidence: .high,
                learningValue: .high, learningReason: "Figurative.", signals: [.figurativeMeaning]
            )
        }
    }

    private func request(
        memories: [KnownSense] = [], explained: [String] = [], sensitivity: DiscoverySensitivity = .balanced
    ) throws -> DiscoveryRequest {
        try DiscoveryRequest(
            passage: AnalysisPassage(documentID: UUID(), revision: "v1", resource: .text, text: "His apology was a fig leaf for his indifference."),
            familiarity: memories, previouslyExplainedSenseKeys: explained, sensitivity: sensitivity
        )
    }

    private func memory(familiarity: Familiarity = .known) -> KnownSense {
        KnownSense(expression: "fig leaf", senseKey: "concealment", meaning: "An inadequate disguise for an embarrassing truth.", familiarity: familiarity)
    }

    private func candidate(
        _ request: DiscoveryRequest, matchedKey: String? = nil, matchConfidence: DiscoveryRating = .high,
        value: DiscoveryRating = .high, interpretation: DiscoveryRating = .high,
        signals: [LearningSignal] = [.figurativeMeaning]
    ) throws -> DiscoveryCandidate {
        DiscoveryCandidate(
            anchor: try request.passage.anchor(for: (request.passage.text as NSString).range(of: "fig leaf")),
            assessment: try DiscoveryAssessment(
                expression: "fig leaf", contextualMeaning: "An inadequate disguise for an embarrassing truth.",
                interpretationConfidence: interpretation, learningValue: value,
                learningReason: "The figurative use reveals why the apology is inadequate.", signals: signals,
                matchedSenseKey: matchedKey, senseMatchConfidence: matchedKey == nil ? nil : matchConfidence
            )
        )
    }
}
