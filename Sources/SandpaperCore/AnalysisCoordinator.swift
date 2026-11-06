import Foundation

/// There is no unbounded inference queue: new navigation replaces old discovery,
/// and a foreground explanation cancels discovery before acquiring the engine.
/// Engines must finish cancellation before the next generation is started.
public actor AnalysisCoordinator {
    private enum Result: Sendable {
        case discovery(DiscoveryReport)
        case explanation(Explanation)
    }

    private struct Job {
        let id: UUID
        let task: Task<Result, Error>
    }

    private let engine: any LocalAnalysisEngine
    private let debounce: Duration
    private var active: Job?
    private var latestDiscovery: UUID?
    private var foreground: UUID?

    public init(engine: any LocalAnalysisEngine = UnconfiguredLocalEngine(), debounce: Duration = .milliseconds(250)) {
        self.engine = engine
        self.debounce = debounce
    }

    public func availability() async -> LocalModelAvailability { await engine.availability() }

    public func discover(_ request: DiscoveryRequest) async throws -> DiscoveryReport {
        try Task.checkCancellation()
        // Codable input can bypass throwing initializers; validate at the boundary.
        try request.validate()
        guard foreground == nil else { throw AnalysisError.foregroundBusy }
        let id = UUID()
        latestDiscovery = id
        if let previous = active {
            previous.task.cancel()
            _ = await previous.task.result
        }
        try Task.checkCancellation()
        guard latestDiscovery == id else { throw CancellationError() }
        guard foreground == nil else { throw AnalysisError.foregroundBusy }
        let task = Task { [engine, debounce] () throws -> Result in
            try await Task.sleep(for: debounce)
            try await Self.requireModel(engine)
            try Task.checkCancellation()
            let candidates = try await engine.discover(request)
            try Task.checkCancellation()
            return .discovery(try DiscoveryPolicy.evaluate(candidates, for: request))
        }
        active = Job(id: id, task: task)
        let result = try await finish(id: id, task: task)
        guard latestDiscovery == id else { throw CancellationError() }
        guard case .discovery(let suggestions) = result else { throw AnalysisError.invalidModelOutput }
        return suggestions
    }

    public func explain(
        _ request: ExplanationRequest,
        onUpdate: @escaping @Sendable (String) async -> Void = { _ in }
    ) async throws -> Explanation {
        try Task.checkCancellation()
        let id = UUID()
        foreground = id
        latestDiscovery = nil
        defer { if foreground == id { foreground = nil } }
        if let previous = active {
            previous.task.cancel()
            _ = await previous.task.result
        }
        try Task.checkCancellation()
        guard foreground == id else { throw CancellationError() }
        let task = Task { [engine, weak self] () throws -> Result in
            try await Self.requireModel(engine)
            try Task.checkCancellation()
            let explanation = try await engine.explain(request) { [weak self] update in
                await self?.deliver(update, for: id, to: onUpdate)
            }
            try Task.checkCancellation()
            try explanation.validate()
            return .explanation(explanation)
        }
        active = Job(id: id, task: task)
        let result = try await finish(id: id, task: task)
        guard foreground == id else { throw CancellationError() }
        guard case .explanation(let explanation) = result else { throw AnalysisError.invalidModelOutput }
        return explanation
    }

    public func cancelAll() {
        latestDiscovery = nil
        foreground = nil
        active?.task.cancel()
    }

    private func finish(id: UUID, task: Task<Result, Error>) async throws -> Result {
        defer { if active?.id == id { active = nil } }
        return try await withTaskCancellationHandler {
            let result = try await task.value
            try Task.checkCancellation()
            return result
        } onCancel: {
            task.cancel()
        }
    }

    private func deliver(_ update: String, for id: UUID, to callback: @Sendable (String) async -> Void) async {
        guard active?.id == id, foreground == id, active?.task.isCancelled == false else { return }
        await callback(update)
    }

    private static func requireModel(_ engine: any LocalAnalysisEngine) async throws {
        switch await engine.availability() {
        case .ready: return
        case .notConfigured: throw AnalysisError.modelNotConfigured
        case .unavailable(let reason): throw AnalysisError.modelUnavailable(reason)
        }
    }
}

extension Explanation {
    func validate() throws {
        guard !meaning.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              meaning.utf16.count <= 16_384, details.count <= 16 else {
            throw AnalysisError.invalidModelOutput
        }
        for detail in details {
            guard !detail.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                  detail.text.utf16.count <= 16_384 else { throw AnalysisError.invalidModelOutput }
            if detail.kind == .etymology {
                guard case .lexical = detail.basis else { throw AnalysisError.invalidModelOutput }
            }
            if case .lexical(let source, let entryID) = detail.basis {
                guard !source.isEmpty, !entryID.isEmpty else { throw AnalysisError.invalidModelOutput }
            }
        }
    }
}
