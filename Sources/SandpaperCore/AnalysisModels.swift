import Foundation

public struct Explanation: Codable, Equatable, Sendable {
    /// The concise contextual answer is always present. Additional sections are optional.
    public let meaning: String
    public let details: [Detail]

    public init(meaning: String, details: [Detail] = []) {
        self.meaning = meaning
        self.details = details
    }

    public struct Detail: Codable, Equatable, Sendable {
        public let kind: Kind
        public let text: String
        public let basis: Basis

        public init(kind: Kind, text: String, basis: Basis) {
            self.kind = kind
            self.text = text
            self.basis = basis
        }
    }

    public enum Kind: String, Codable, Sendable {
        case definition, usage, implication, tone, grammar, etymology, example, relatedExpression
    }

    public enum Basis: Codable, Equatable, Sendable {
        case interpretation
        case generatedExample
        /// IDs must be checked against retrieved local lexical records by the engine adapter.
        case lexical(source: String, entryID: String)
    }
}

public struct AnalysisPassage: Codable, Equatable, Sendable {
    public let documentID: UUID
    public let revision: String
    public let resource: SourceResource
    public let resourceOffset: Int
    public let text: String

    public init(
        documentID: UUID, revision: String, resource: SourceResource,
        resourceOffset: Int = 0, text: String
    ) throws {
        guard !text.isEmpty, text.utf16.count <= 16_384,
              resourceOffset >= 0, resourceOffset <= Int.max - text.utf16.count else {
            throw LibraryError.invalidInput("Analysis requires a nonempty, bounded passage and a valid offset.")
        }
        // Validate the resource and revision using the same rules as saved anchors.
        _ = try SourceAnchor(
            documentID: documentID, revision: revision, resource: resource,
            text: text, selection: NSRange(text.startIndex..<text.endIndex, in: text),
            resourceOffset: resourceOffset
        )
        self.documentID = documentID
        self.revision = revision
        self.resource = resource
        self.resourceOffset = resourceOffset
        self.text = text
    }

    public func anchor(for selection: NSRange) throws -> SourceAnchor {
        try SourceAnchor(
            documentID: documentID, revision: revision, resource: resource,
            text: text, selection: selection, resourceOffset: resourceOffset
        )
    }

    func validate() throws {
        _ = try AnalysisPassage(
            documentID: documentID, revision: revision, resource: resource,
            resourceOffset: resourceOffset, text: text
        )
    }
}

public struct ExplanationRequest: Sendable {
    public let passage: AnalysisPassage
    public let selection: SourceAnchor

    public init(passage: AnalysisPassage, selection: SourceAnchor) throws {
        try passage.validate()
        guard selection.documentID == passage.documentID,
              selection.revision == passage.revision,
              selection.resource == passage.resource,
              selection.utf16Offset >= passage.resourceOffset else {
            throw LibraryError.invalidInput("Selection must belong to the supplied passage.")
        }
        let local = NSRange(
            location: selection.utf16Offset - passage.resourceOffset,
            length: selection.utf16Length
        )
        guard try passage.anchor(for: local) == selection else {
            throw LibraryError.invalidInput("Selection does not match the supplied passage.")
        }
        self.passage = passage
        self.selection = selection
    }
}

public enum LocalModelAvailability: Equatable, Sendable {
    case ready(modelID: String)
    case notConfigured
    case unavailable(reason: String)
}

public enum AnalysisError: Error, Equatable, Sendable {
    case modelNotConfigured
    case modelUnavailable(String)
    case foregroundBusy
    case invalidModelOutput
}

/// Implementations must run locally and honor cooperative cancellation. They must
/// validate lexical provenance before returning an Explanation. No network fallback.
public protocol LocalAnalysisEngine: Sendable {
    func availability() async -> LocalModelAvailability
    func discover(_ request: DiscoveryRequest) async throws -> [DiscoveryCandidate]
    func explain(
        _ request: ExplanationRequest,
        onUpdate: @escaping @Sendable (String) async -> Void
    ) async throws -> Explanation
}

public struct UnconfiguredLocalEngine: LocalAnalysisEngine {
    public init() {}
    public func availability() async -> LocalModelAvailability { .notConfigured }
    public func discover(_ request: DiscoveryRequest) async throws -> [DiscoveryCandidate] {
        throw AnalysisError.modelNotConfigured
    }
    public func explain(
        _ request: ExplanationRequest, onUpdate: @escaping @Sendable (String) async -> Void
    ) async throws -> Explanation {
        throw AnalysisError.modelNotConfigured
    }
}
