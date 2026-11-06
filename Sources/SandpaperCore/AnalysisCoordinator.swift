import Foundation

/// Explicit selection requests only. A newer request cancels and drains the previous one;
/// opening documents, navigating and dictionary lookup never schedule inference.
public actor AnalysisCoordinator {
    private struct Job { let id: UUID; let task: Task<Explanation, Error> }
    private let engine: any LocalAnalysisEngine
    private var active: Job?
    private var latest: UUID?

    public init(engine: any LocalAnalysisEngine = UnconfiguredLocalEngine()) { self.engine = engine }

    public func availability() async -> LocalModelAvailability { await engine.availability() }

    public func explain(_ request: ExplanationRequest,
        onUpdate: @escaping @Sendable (String) async -> Void = { _ in }) async throws -> Explanation {
        try Task.checkCancellation()
        let id = UUID()
        latest = id
        if let previous = active {
            previous.task.cancel()
            _ = await previous.task.result
        }
        try Task.checkCancellation()
        guard latest == id else { throw CancellationError() }
        let task = Task { [engine, weak self] in
            let availability = await engine.availability()
            try Task.checkCancellation()
            switch availability {
            case .ready: break
            case .notConfigured: throw AnalysisError.modelNotConfigured
            case .unavailable(let reason): throw AnalysisError.modelUnavailable(reason)
            }
            try Task.checkCancellation()
            let explanation = try await engine.explain(request) { [weak self] update in
                await self?.deliver(update, id: id, to: onUpdate)
            }
            try Task.checkCancellation()
            try explanation.validate()
            return explanation
        }
        active = Job(id: id, task: task)
        defer { if active?.id == id { active = nil } }
        return try await withTaskCancellationHandler {
            let result = try await task.value
            try Task.checkCancellation()
            guard latest == id else { throw CancellationError() }
            return result
        } onCancel: { task.cancel() }
    }

    public func cancelAll() { latest = nil; active?.task.cancel() }

    private func deliver(_ update: String, id: UUID, to callback: @Sendable (String) async -> Void) async {
        guard latest == id, active?.id == id, active?.task.isCancelled == false else { return }
        await callback(update)
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
