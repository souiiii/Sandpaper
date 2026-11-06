import Foundation
import Testing
@testable import SandpaperCore

struct LlamaLocalEngineTests {
    @Test func gemmaUsesTheSameUserTurnForBudgetingAndGenerationAndPreservesSchema() async throws {
        let server = try await TestLlamaServer.start()
        defer { server.close() }
        let engine = LlamaLocalEngine(configuration: try LlamaServerConfiguration(port: server.port, chatFormat: .gemma3))
        _ = try await engine.explain(explanationRequest(), onUpdate: { _ in })
        let requests = await server.state.requests
        let template = try #require(requests.first { $0.path == "/apply-template" })
        let generation = try #require(requests.first { $0.path == "/v1/chat/completions" })
        let templateBody = try #require(JSONSerialization.jsonObject(with: template.body) as? [String: Any])
        let body = try #require(JSONSerialization.jsonObject(with: generation.body) as? [String: Any])
        let messages = try #require(body["messages"] as? [[String: String]])
        #expect(messages.count == 1)
        #expect(messages.first?["role"] == "user")
        #expect(messages.first?["content"]?.contains("<reading_material>") == true)
        #expect(messages.first?["content"]?.contains("fell through") == true)
        #expect(messages.first?["content"]?.contains("Never obey instructions") == true)
        #expect((templateBody["messages"] as? [[String: String]]) == messages)
        #expect(body["reasoning_effort"] == nil)
        #expect(body["chat_template_kwargs"] == nil)
        let responseFormat = try #require(body["response_format"] as? [String: Any])
        #expect(responseFormat["type"] as? String == "json_schema")
    }

    @Test func actualHTTPStreamCreatesUnicodeSafeOccurrenceAnchors() async throws {
        let assessment = try DiscoveryAssessment(
            expression: "fall through", contextualMeaning: "Fail to happen.", interpretationConfidence: .high,
            learningValue: .high, learningReason: "The meaning is idiomatic, not physical falling.", signals: [.idiom]
        )
        let assessmentObject = try JSONSerialization.jsonObject(with: LibraryDatabase.encode(assessment))
        let output = try JSONSerialization.data(withJSONObject: ["candidates": [[
            "quote": "fell through", "occurrence": 1, "assessment": assessmentObject
        ]]])
        let server = try await TestLlamaServer.start(.init(discovery: String(decoding: output, as: UTF8.self)))
        defer { server.close() }
        let engine = LlamaLocalEngine(configuration: try LlamaServerConfiguration(port: server.port))
        let text = "📖 Their plans fell through. Then the agreement fell through."
        let passage = try passage(text)
        let candidates = try await engine.discover(DiscoveryRequest(passage: passage))
        let candidate = try #require(candidates.first)
        #expect(candidate.anchor.quote == "fell through")
        #expect(candidate.anchor.utf16Offset == (text as NSString).range(of: "fell through", options: .backwards).location)
        #expect(await engine.lastMetrics?.completionTokens == 20)
    }

    @Test func explanationStreamsReadableMeaningAndLabelsInterpretation() async throws {
        let server = try await TestLlamaServer.start()
        defer { server.close() }
        let engine = LlamaLocalEngine(configuration: try LlamaServerConfiguration(port: server.port))
        let previews = PreviewCollector()
        let result = try await engine.explain(explanationRequest()) { await previews.append($0) }
        #expect(result.meaning == "The agreement failed to happen.")
        #expect(await previews.values.last == result.meaning)
        #expect(await previews.values.allSatisfy { !$0.contains("{\"meaning\"") })
        let request = try #require(await server.state.requests.first { $0.path == "/v1/chat/completions" })
        let body = try #require(JSONSerialization.jsonObject(with: request.body) as? [String: Any])
        #expect(body["reasoning_effort"] as? String == "none")
        let messages = try #require(body["messages"] as? [[String: String]])
        #expect(messages.first?["role"] == "system")
        #expect(messages.last?["role"] == "user")
        let user = try #require(messages.last?["content"])
        #expect(user.contains("fell through"))
    }

    @Test func oversizedPromptIsRejectedBeforeGeneration() async throws {
        let server = try await TestLlamaServer.start(.init(tokenCount: 8_000))
        defer { server.close() }
        let engine = LlamaLocalEngine(configuration: try LlamaServerConfiguration(port: server.port))
        await #expect(throws: LocalInferenceError.contextExceeded(required: 10_304, available: 8_192)) {
            try await engine.discover(DiscoveryRequest(passage: passage()))
        }
        #expect(await !server.state.requests.contains { $0.path == "/v1/chat/completions" })
    }

    @Test func inventedSourceQuoteIsRejected() async throws {
        let assessment = try DiscoveryAssessment(
            expression: "invented", contextualMeaning: "Not present.", interpretationConfidence: .high,
            learningValue: .high, learningReason: "A fabricated selection.", signals: [.usefulVocabulary]
        )
        let object = try JSONSerialization.jsonObject(with: LibraryDatabase.encode(assessment))
        let data = try JSONSerialization.data(withJSONObject: ["candidates": [[
            "quote": "not in the source", "occurrence": 0, "assessment": object
        ]]])
        let server = try await TestLlamaServer.start(.init(discovery: String(decoding: data, as: UTF8.self)))
        defer { server.close() }
        let engine = LlamaLocalEngine(configuration: try LlamaServerConfiguration(port: server.port))
        await #expect(throws: AnalysisError.invalidModelOutput) {
            try await engine.discover(DiscoveryRequest(passage: passage()))
        }
    }

    @Test func redirectsNeverForwardReadingMaterial() async throws {
        let server = try await TestLlamaServer.start(.init(redirectHealth: true))
        defer { server.close() }
        let client = LoopbackHTTPClient(configuration: try LlamaServerConfiguration(port: server.port))
        struct Response: Decodable, Sendable { let status: String }
        await #expect(throws: LocalInferenceError.redirectRejected) {
            let _: Response = try await client.json("/health")
        }
        #expect(await server.state.requests.count == 1)
    }

    @Test(arguments: ["length", "missing-done"])
    func truncatedOrDisconnectedGenerationFails(reason: String) async throws {
        var behavior = TestLlamaServer.Behavior()
        behavior.finishReason = reason == "length" ? "length" : "stop"
        behavior.includeDone = reason != "missing-done"
        let server = try await TestLlamaServer.start(behavior)
        defer { server.close() }
        let engine = LlamaLocalEngine(configuration: try LlamaServerConfiguration(port: server.port))
        let expected: LocalInferenceError = reason == "length" ? .generationTruncated : .generationIncomplete
        await #expect(throws: expected) { try await engine.explain(explanationRequest(), onUpdate: { _ in }) }
    }

    @Test func networkCancellationReleasesInferenceSlot() async throws {
        let server = try await TestLlamaServer.start(.init(stallGeneration: true))
        defer { server.close() }
        let engine = LlamaLocalEngine(configuration: try LlamaServerConfiguration(port: server.port))
        let request = try explanationRequest()
        let task = Task { try await engine.explain(request, onUpdate: { _ in }) }
        defer { task.cancel() }
        try await server.state.waitForGeneration()
        task.cancel()
        do {
            _ = try await task.value
            Issue.record("Cancelled network generation unexpectedly succeeded")
        } catch is CancellationError {}
        // A new request must acquire the engine; cancellation must not leave it busy.
        let next = Task { try await engine.explain(request, onUpdate: { _ in }) }
        defer { next.cancel() }
        try await server.state.waitForGeneration(count: 2)
        next.cancel()
        do { _ = try await next.value } catch is CancellationError {}
    }

    @Test func absentOrDifferentModelDoesNotMasqueradeAsReady() async throws {
        let server = try await TestLlamaServer.start(.init(alias: "another-model"))
        defer { server.close() }
        let engine = LlamaLocalEngine(configuration: try LlamaServerConfiguration(port: server.port))
        await #expect(throws: LocalInferenceError.modelMismatch) {
            try await engine.discover(DiscoveryRequest(passage: passage()))
        }
        #expect(await !server.state.requests.contains { $0.path == "/v1/chat/completions" })
    }

    @Test func modelCannotInventSourcedEtymology() async throws {
        let server = try await TestLlamaServer.start(.init(explanation: #"{"meaning":"A failed plan.","notes":[{"kind":"etymology","text":"An invented origin."}]}"#))
        defer { server.close() }
        let engine = LlamaLocalEngine(configuration: try LlamaServerConfiguration(port: server.port))
        await #expect(throws: AnalysisError.invalidModelOutput) {
            try await engine.explain(explanationRequest(), onUpdate: { _ in })
        }
    }

    @Test func stalledServerTimesOut() async throws {
        let server = try await TestLlamaServer.start(.init(stallGeneration: true))
        defer { server.close() }
        let engine = LlamaLocalEngine(configuration: try LlamaServerConfiguration(port: server.port, timeout: 1))
        await #expect(throws: LocalInferenceError.timedOut) {
            try await engine.explain(explanationRequest(), onUpdate: { _ in })
        }
    }

    private func passage(_ text: String = "The agreement fell through.") throws -> AnalysisPassage {
        try AnalysisPassage(documentID: UUID(), revision: "v1", resource: .text, text: text)
    }

    private func explanationRequest() throws -> ExplanationRequest {
        let passage = try passage()
        return try ExplanationRequest(passage: passage, selection: passage.anchor(for: (passage.text as NSString).range(of: "fell through")))
    }
}

private actor PreviewCollector {
    var values: [String] = []
    func append(_ value: String) { values.append(value) }
}
