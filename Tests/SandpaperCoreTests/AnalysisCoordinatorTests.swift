import Foundation
import Testing
@testable import SandpaperCore

struct AnalysisCoordinatorTests {
    private func request() throws -> ExplanationRequest {
        let p = try AnalysisPassage(documentID: UUID(), revision: "v1", resource: .text, text: "The agreement fell through.")
        return try ExplanationRequest(passage: p, selection: p.anchor(for: NSRange(location: 14, length: 12)))
    }

    @Test func missingModelIsExplicit() async throws {
        let coordinator = AnalysisCoordinator()
        #expect(await coordinator.availability() == .notConfigured)
        await #expect(throws: AnalysisError.modelNotConfigured) { try await coordinator.explain(request()) }
    }

    @Test func newExplicitRequestCancelsAndDrainsThePreviousOne() async throws {
        let engine = SelectionProbeEngine(holdFirst: true)
        let coordinator = AnalysisCoordinator(engine: engine)
        let request = try request()
        let first = Task { try await coordinator.explain(request) }
        await engine.waitForStart()
        let result = try await coordinator.explain(request)
        #expect(result.meaning == "The agreement failed to happen.")
        do { _ = try await first.value; Issue.record("Superseded request returned a result") } catch is CancellationError {}
        #expect(await engine.maximumConcurrentCalls == 1)
    }

    @Test func cancellationSuppressesAnUncooperativeEnginesLateResult() async throws {
        let engine = SelectionProbeEngine(holdFirst: true, ignoreCancellation: true)
        let coordinator = AnalysisCoordinator(engine: engine)
        let collector = SelectionUpdates()
        let request = try request()
        let first = Task { try await coordinator.explain(request) { await collector.append($0) } }
        await engine.waitForStart()
        await coordinator.cancelAll()
        do { _ = try await first.value; Issue.record("Cancelled request returned a result") } catch is CancellationError {}
        #expect(await collector.values.isEmpty)
    }

    @Test func callerCancellationReleasesTheEngine() async throws {
        let engine = SelectionProbeEngine(holdFirst: true)
        let coordinator = AnalysisCoordinator(engine: engine)
        let request = try request()
        let task = Task { try await coordinator.explain(request) }
        await engine.waitForStart(); task.cancel()
        do { _ = try await task.value; Issue.record("Cancelled request returned a result") } catch is CancellationError {}
        #expect(try await coordinator.explain(request).meaning == "The agreement failed to happen.")
        #expect(await engine.maximumConcurrentCalls == 1)
    }

    @Test func streamingAndProvenanceValidationRemainActive() async throws {
        let collector = SelectionUpdates()
        let coordinator = AnalysisCoordinator(engine: SelectionProbeEngine())
        _ = try await coordinator.explain(request()) { await collector.append($0) }
        #expect(await collector.values == ["The agreement"])
        let invalid = AnalysisCoordinator(engine: SelectionProbeEngine(unsourcedOrigin: true))
        await #expect(throws: AnalysisError.invalidModelOutput) { try await invalid.explain(request()) }
    }
}

actor SelectionProbeEngine: LocalAnalysisEngine {
    var calls = 0
    var availabilityCalls = 0
    var maximumConcurrentCalls = 0
    private var active = 0
    private let holdFirst: Bool
    private let ignoreCancellation: Bool
    private let unsourcedOrigin: Bool
    private var waiters: [CheckedContinuation<Void, Never>] = []
    init(holdFirst: Bool = false, ignoreCancellation: Bool = false, unsourcedOrigin: Bool = false) {
        self.holdFirst = holdFirst; self.ignoreCancellation = ignoreCancellation; self.unsourcedOrigin = unsourcedOrigin
    }
    func availability() -> LocalModelAvailability { availabilityCalls += 1; return .ready(modelID: "test") }
    func waitForStart() async { if calls > 0 { return }; await withCheckedContinuation { waiters.append($0) } }
    func explain(_ request: ExplanationRequest, onUpdate: @escaping @Sendable (String) async -> Void) async throws -> Explanation {
        calls += 1; active += 1; maximumConcurrentCalls = max(active, maximumConcurrentCalls)
        defer { active -= 1 }
        waiters.forEach { $0.resume() }; waiters.removeAll()
        if holdFirst, calls == 1 {
            do { try await Task.sleep(for: .seconds(10)) } catch { if !ignoreCancellation { throw error } }
        }
        await onUpdate("The agreement")
        return Explanation(meaning: "The agreement failed to happen.", details: unsourcedOrigin
            ? [.init(kind: .etymology, text: "An unsourced origin.", basis: .interpretation)] : [])
    }
}

private actor SelectionUpdates {
    var values: [String] = []
    func append(_ value: String) { values.append(value) }
}
