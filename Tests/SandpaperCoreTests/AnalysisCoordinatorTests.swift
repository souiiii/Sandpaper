import Foundation
import Testing
@testable import SandpaperCore

struct AnalysisCoordinatorTests {
    @Test func missingModelIsExplicitRatherThanEmptySuccess() async throws {
        let coordinator = AnalysisCoordinator(debounce: .zero)
        #expect(await coordinator.availability() == .notConfigured)
        await #expect(throws: AnalysisError.modelNotConfigured) {
            try await coordinator.discover(DiscoveryRequest(passage: passage()))
        }
    }

    @Test func foregroundCancelsDiscoveryAndNeverOverlapsInference() async throws {
        let engine = ProbeEngine(hold: .firstDiscovery)
        let coordinator = AnalysisCoordinator(engine: engine, debounce: .zero)
        let passage = try passage()
        let discovery = Task { try await coordinator.discover(DiscoveryRequest(passage: passage)) }
        defer { discovery.cancel() }
        await engine.waitForStart()
        let explanation = try await coordinator.explain(explanationRequest(passage))
        #expect(explanation.meaning == "The agreement failed to happen.")
        do {
            _ = try await discovery.value
            Issue.record("Discovery should have been cancelled")
        } catch is CancellationError {}
        #expect(await engine.maximumConcurrentCalls == 1)
        #expect(await engine.discoveryWasCancelled)
    }

    @Test func navigationReplacesOldDiscovery() async throws {
        let engine = ProbeEngine(hold: .firstDiscovery)
        let coordinator = AnalysisCoordinator(engine: engine, debounce: .zero)
        let request = try DiscoveryRequest(passage: passage())
        let first = Task { try await coordinator.discover(request) }
        defer { first.cancel() }
        await engine.waitForStart()
        let second = try await coordinator.discover(request)
        #expect(second.isEmpty) // A valid page need not contain suggestions.
        do {
            _ = try await first.value
            Issue.record("Old viewport should have been cancelled")
        } catch is CancellationError {}
        #expect(await engine.maximumConcurrentCalls == 1)
    }

    @Test func callerCancellationReleasesTheEngine() async throws {
        let engine = ProbeEngine(hold: .firstDiscovery)
        let coordinator = AnalysisCoordinator(engine: engine, debounce: .zero)
        let request = try DiscoveryRequest(passage: passage())
        let first = Task { try await coordinator.discover(request) }
        await engine.waitForStart()
        first.cancel()
        do {
            _ = try await first.value
            Issue.record("Cancelled request should throw")
        } catch is CancellationError {}
        #expect(try await coordinator.discover(request).isEmpty)
        #expect(await engine.maximumConcurrentCalls == 1)
    }

    @Test func backgroundDoesNotPreemptForeground() async throws {
        let engine = ProbeEngine(hold: .explanation)
        let coordinator = AnalysisCoordinator(engine: engine, debounce: .zero)
        let passage = try passage()
        let request = try explanationRequest(passage)
        let foreground = Task { try await coordinator.explain(request) }
        defer { foreground.cancel() }
        await engine.waitForStart()
        await #expect(throws: AnalysisError.foregroundBusy) {
            try await coordinator.discover(DiscoveryRequest(passage: passage))
        }
        foreground.cancel()
        do {
            _ = try await foreground.value
            Issue.record("Cancelled explanation should throw")
        } catch is CancellationError {}
        #expect(await engine.maximumConcurrentCalls == 1)
    }

    @Test func unsourcedEtymologyIsRejected() async throws {
        let engine = ProbeEngine(hold: .none, unsourcedEtymology: true)
        let coordinator = AnalysisCoordinator(engine: engine, debounce: .zero)
        await #expect(throws: AnalysisError.invalidModelOutput) {
            try await coordinator.explain(explanationRequest(passage()))
        }
    }

    @Test func streamingUpdatesReachCaller() async throws {
        let collector = UpdateCollector()
        let coordinator = AnalysisCoordinator(engine: ProbeEngine(hold: .none), debounce: .zero)
        _ = try await coordinator.explain(explanationRequest(passage())) { update in
            await collector.append(update)
        }
        #expect(await collector.updates == ["The agreement"])
    }

    @Test func decodedInputCannotBypassPassageLimits() async throws {
        let request = try DiscoveryRequest(passage: passage())
        let encoded = try JSONEncoder().encode(request)
        var object = try #require(JSONSerialization.jsonObject(with: encoded) as? [String: Any])
        var passageObject = try #require(object["passage"] as? [String: Any])
        passageObject["resourceOffset"] = -1
        object["passage"] = passageObject
        let modified = try JSONSerialization.data(withJSONObject: object)
        let decoded = try JSONDecoder().decode(DiscoveryRequest.self, from: modified)
        let coordinator = AnalysisCoordinator(engine: ProbeEngine(hold: .none), debounce: .zero)
        await #expect(throws: (any Error).self) { try await coordinator.discover(decoded) }
    }

    @Test func cancellationSuppressesLateEngineUpdatesAndResults() async throws {
        let engine = ProbeEngine(hold: .explanation, ignoreExplanationCancellation: true)
        let coordinator = AnalysisCoordinator(engine: engine, debounce: .zero)
        let collector = UpdateCollector()
        let request = try explanationRequest(passage())
        let task = Task {
            try await coordinator.explain(request) { update in await collector.append(update) }
        }
        await engine.waitForStart()
        await coordinator.cancelAll()
        do {
            _ = try await task.value
            Issue.record("Late results must not survive cancellation")
        } catch is CancellationError {}
        #expect(await collector.updates.isEmpty)
    }

    private func passage() throws -> AnalysisPassage {
        try AnalysisPassage(documentID: UUID(), revision: "v1", resource: .text, text: "The agreement fell through.")
    }

    private func explanationRequest(_ passage: AnalysisPassage) throws -> ExplanationRequest {
        try ExplanationRequest(
            passage: passage,
            selection: passage.anchor(for: (passage.text as NSString).range(of: "fell through"))
        )
    }
}

/// Only used by scheduler tests. No generated fixture response is installed in the product.
private actor ProbeEngine: LocalAnalysisEngine {
    enum Hold: Sendable { case firstDiscovery, explanation, none }
    let hold: Hold
    let unsourcedEtymology: Bool
    let ignoreExplanationCancellation: Bool
    var maximumConcurrentCalls = 0
    var discoveryWasCancelled = false
    private var activeCalls = 0
    private var discoveryCount = 0
    private var started = false
    private var startWaiters: [CheckedContinuation<Void, Never>] = []

    init(hold: Hold, unsourcedEtymology: Bool = false, ignoreExplanationCancellation: Bool = false) {
        self.hold = hold
        self.unsourcedEtymology = unsourcedEtymology
        self.ignoreExplanationCancellation = ignoreExplanationCancellation
    }

    func availability() async -> LocalModelAvailability { .ready(modelID: "test-engine") }

    func waitForStart() async {
        if started { return }
        await withCheckedContinuation { startWaiters.append($0) }
    }

    func discover(_ request: DiscoveryRequest) async throws -> [DiscoverySuggestion] {
        discoveryCount += 1
        begin()
        defer { activeCalls -= 1 }
        if hold == .firstDiscovery, discoveryCount == 1 {
            do { try await Task.sleep(for: .seconds(10)) }
            catch {
                discoveryWasCancelled = true
                throw error
            }
        }
        return []
    }

    func explain(
        _ request: ExplanationRequest, onUpdate: @escaping @Sendable (String) async -> Void
    ) async throws -> Explanation {
        begin()
        defer { activeCalls -= 1 }
        if hold == .explanation {
            do { try await Task.sleep(for: .seconds(10)) }
            catch { if !ignoreExplanationCancellation { throw error } }
        }
        await onUpdate("The agreement")
        return Explanation(
            meaning: "The agreement failed to happen.",
            details: unsourcedEtymology
                ? [.init(kind: .etymology, text: "Unsupported origin.", basis: .interpretation)] : []
        )
    }

    private func begin() {
        activeCalls += 1
        maximumConcurrentCalls = max(maximumConcurrentCalls, activeCalls)
        started = true
        for waiter in startWaiters { waiter.resume() }
        startWaiters.removeAll()
    }
}

private actor UpdateCollector {
    var updates: [String] = []
    func append(_ value: String) { updates.append(value) }
}
