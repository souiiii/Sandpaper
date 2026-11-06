import CryptoKit
import Foundation

/// Talks only to a single-model, single-slot llama.cpp server on IPv4 loopback.
/// Server/model installation is explicit; this adapter never downloads anything.
public actor LlamaLocalEngine: LocalAnalysisEngine {
    public nonisolated static var promptVersion: String { LlamaPrompts.version }
    private struct Health: Decodable { let status: String }
    private struct Properties: Decodable {
        struct Settings: Decodable { let n_ctx: Int }
        let default_generation_settings: Settings
        let total_slots: Int
        let model_path: String?
    }
    private struct Models: Decodable {
        struct Model: Decodable { let id: String }
        let data: [Model]
    }
    private struct Template: Decodable { let prompt: String }
    private struct Tokens: Decodable { let tokens: [Int] }
    private struct DiscoveryOutput: Decodable {
        struct Candidate: Decodable {
            let quote: String
            let occurrence: Int
            let assessment: DiscoveryAssessment
        }
        let candidates: [Candidate]
    }
    private struct ExplanationOutput: Decodable {
        struct Note: Decodable { let kind: Explanation.Kind; let text: String }
        let meaning: String
        let notes: [Note]
    }

    private let configuration: LlamaServerConfiguration
    private let client: LoopbackHTTPClient
    let lexicon: LexiconStore?
    private var running = false
    public private(set) var lastMetrics: InferenceMetrics?
    public internal(set) var lastHybridDiagnostics: HybridDiscoveryDiagnostics?

    public init(configuration: LlamaServerConfiguration, lexicon: LexiconStore? = nil) {
        self.configuration = configuration
        self.client = LoopbackHTTPClient(configuration: configuration)
        self.lexicon = lexicon
    }

    public func availability() async -> LocalModelAvailability {
        do {
            let properties = try await probe()
            let identity = configuration.modelAlias + ":" + (properties.model_path ?? "")
            return .ready(modelID: SHA256.hash(data: Data(identity.utf8)).map { String(format: "%02x", $0) }.joined())
        } catch is CancellationError {
            return .unavailable(reason: "Availability check cancelled.")
        } catch LocalInferenceError.httpStatus(503) {
            return .unavailable(reason: "The local model is still loading.")
        } catch LocalInferenceError.modelMismatch {
            return .unavailable(reason: "The local server has a different model alias.")
        } catch LocalInferenceError.unsupportedServer {
            return .unavailable(reason: "Use a single-model llama.cpp server with one inference slot.")
        } catch {
            return .unavailable(reason: "The local model server is unavailable. Start it with the configured port and alias.")
        }
    }

    public func discover(_ request: DiscoveryRequest) async throws -> [DiscoveryCandidate] {
        try request.validate()
        try acquire()
        defer { running = false }
        lastHybridDiagnostics = nil
        if let lexicon { return try await groundedDiscovery(request, lexicon: lexicon) }
        let data = try await complete(
            messages: LlamaPrompts.discovery(request), schema: LlamaPrompts.discoverySchema(),
            name: "discovery", maximumOutputTokens: 2_048
        )
        let output: DiscoveryOutput
        do { output = try JSONDecoder().decode(DiscoveryOutput.self, from: data) }
        catch { throw AnalysisError.invalidModelOutput }
        guard output.candidates.count <= 64 else { throw AnalysisError.invalidModelOutput }
        let candidates = try output.candidates.map { candidate in
            guard !candidate.quote.isEmpty, candidate.quote.utf16.count <= 1_024,
                  (0...255).contains(candidate.occurrence) else { throw AnalysisError.invalidModelOutput }
            var search = NSRange(location: 0, length: request.passage.text.utf16.count)
            var found = NSRange(location: NSNotFound, length: 0)
            let source = request.passage.text as NSString
            for _ in 0...candidate.occurrence {
                found = source.range(of: candidate.quote, options: .literal, range: search)
                guard found.location != NSNotFound else { throw AnalysisError.invalidModelOutput }
                let next = found.location + found.length
                search = NSRange(location: next, length: source.length - next)
            }
            return DiscoveryCandidate(anchor: try request.passage.anchor(for: found), assessment: candidate.assessment)
        }
        // Direct engine callers receive the same validation as coordinator callers.
        _ = try DiscoveryPolicy.evaluate(candidates, for: request)
        return candidates
    }

    public func explain(
        _ request: ExplanationRequest, onUpdate: @escaping @Sendable (String) async -> Void
    ) async throws -> Explanation {
        try acquire()
        defer { running = false }
        if let lexicon { return try await groundedExplanation(request, lexicon: lexicon, onUpdate: onUpdate) }
        let data = try await complete(
            messages: LlamaPrompts.explanation(request), schema: LlamaPrompts.explanationSchema(),
            name: "explanation", maximumOutputTokens: 1_024, onUpdate: onUpdate
        )
        let output: ExplanationOutput
        do { output = try JSONDecoder().decode(ExplanationOutput.self, from: data) }
        catch { throw AnalysisError.invalidModelOutput }
        // No lexical data is available yet. A model cannot promote its own prose
        // into sourced facts or invent an etymology by adding a citation field.
        guard output.notes.count <= 8, output.notes.allSatisfy({ $0.kind != .etymology }) else {
            throw AnalysisError.invalidModelOutput
        }
        let result = Explanation(meaning: output.meaning, details: output.notes.map {
            .init(kind: $0.kind, text: $0.text, basis: $0.kind == .example ? .generatedExample : .interpretation)
        })
        try result.validate()
        return result
    }

    private func acquire() throws {
        try Task.checkCancellation()
        guard !running else { throw LocalInferenceError.engineBusy }
        running = true
        lastMetrics = nil
    }

    private func probe() async throws -> Properties {
        let health: Health = try await client.json("/health", timeout: 3)
        guard health.status == "ok" else { throw LocalInferenceError.unsupportedServer }
        let properties: Properties = try await client.json("/props", timeout: 3)
        guard properties.total_slots == 1, properties.default_generation_settings.n_ctx >= 2_048 else {
            throw LocalInferenceError.unsupportedServer
        }
        let models: Models = try await client.json("/v1/models", timeout: 3)
        guard models.data.count == 1, models.data.first?.id == configuration.modelAlias else {
            throw LocalInferenceError.modelMismatch
        }
        return properties
    }

    func complete(
        messages: [ChatMessage], schema: [String: Any], name: String, maximumOutputTokens: Int,
        onUpdate: (@Sendable (String) async -> Void)? = nil
    ) async throws -> Data {
        let start = ContinuousClock.now
        let properties = try await probe()
        let messageData = try LibraryDatabase.encode(configuration.chatFormat.messages(messages))
        let messageObjects = try JSONSerialization.jsonObject(with: messageData)
        var templateParameters: [String: Any] = ["messages": messageObjects]
        if configuration.chatFormat == .native {
            templateParameters["chat_template_kwargs"] = ["enable_thinking": false]
        }
        let templateBody = try JSONSerialization.data(withJSONObject: templateParameters, options: [.sortedKeys])
        let template: Template = try await client.json("/apply-template", body: templateBody)
        let tokenBody = try JSONSerialization.data(withJSONObject: [
            "content": template.prompt, "add_special": true, "parse_special": true
        ], options: [.sortedKeys])
        let tokens: Tokens = try await client.json("/tokenize", body: tokenBody)
        let available = min(configuration.contextTokenLimit, properties.default_generation_settings.n_ctx)
        // Reserve output plus a small template/special-token margin. Never let the
        // server silently discard the beginning of the reading passage.
        let required = tokens.tokens.count + maximumOutputTokens + 256
        guard required <= available else { throw LocalInferenceError.contextExceeded(required: required, available: available) }
        var parameters: [String: Any] = [
            "model": configuration.modelAlias, "messages": messageObjects,
            "stream": true, "stream_options": ["include_usage": true],
            "temperature": 0.2, "max_tokens": maximumOutputTokens,
            "cache_prompt": true,
            "response_format": ["type": "json_schema", "json_schema": ["name": name, "strict": true, "schema": schema]]
        ]
        if configuration.chatFormat == .native {
            parameters["reasoning_effort"] = "none"
            parameters["chat_template_kwargs"] = ["enable_thinking": false]
        }
        let body = try JSONSerialization.data(withJSONObject: parameters, options: [.sortedKeys])
        let collector = ChatStreamCollector(start: start)
        try await client.stream("/v1/chat/completions", body: body) { event in
            try await collector.ingest(event, onUpdate: onUpdate)
        }
        try Task.checkCancellation()
        let (data, metrics) = try await collector.result()
        lastMetrics = metrics
        return data
    }
}
