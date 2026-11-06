import Foundation

public struct InferenceMetrics: Codable, Equatable, Sendable {
    public let elapsedSeconds: Double
    public let firstContentSeconds: Double?
    public let promptTokens: Int?
    public let completionTokens: Int?
}

actor ChatStreamCollector {
    private struct Event: Decodable {
        struct Choice: Decodable {
            struct Delta: Decodable { let content: String? }
            let index: Int
            let delta: Delta?
            let finish_reason: String?
        }
        struct Usage: Decodable { let prompt_tokens: Int; let completion_tokens: Int }
        struct ServerError: Decodable { let message: String? }
        let choices: [Choice]?
        let usage: Usage?
        let error: ServerError?
    }

    private let start: ContinuousClock.Instant
    private var content = ""
    private var finishReason: String?
    private var done = false
    private var lastPreview = ""
    private var firstContentSeconds: Double?
    private var usage: Event.Usage?

    init(start: ContinuousClock.Instant = .now) { self.start = start }

    func ingest(_ event: String, onUpdate: (@Sendable (String) async -> Void)?) async throws -> Bool {
        try Task.checkCancellation()
        if event == "[DONE]" { done = true; return false }
        let decoded: Event
        do { decoded = try JSONDecoder().decode(Event.self, from: Data(event.utf8)) }
        catch { throw LocalInferenceError.invalidResponse }
        guard decoded.error == nil, let choices = decoded.choices, choices.count <= 1 else {
            throw LocalInferenceError.invalidResponse
        }
        if let metrics = decoded.usage { usage = metrics }
        for choice in choices {
            guard choice.index == 0, finishReason == nil else { throw LocalInferenceError.invalidResponse }
            if let chunk = choice.delta?.content, !chunk.isEmpty {
                if firstContentSeconds == nil { firstContentSeconds = seconds(start.duration(to: .now)) }
                guard content.utf8.count + chunk.utf8.count <= 65_536 else { throw LocalInferenceError.responseTooLarge }
                content += chunk
                if let onUpdate, let preview = Self.meaningPreview(in: content), preview != lastPreview {
                    lastPreview = preview
                    await onUpdate(preview)
                    try Task.checkCancellation()
                }
            }
            if let reason = choice.finish_reason { finishReason = reason }
        }
        return true
    }

    func result() throws -> (Data, InferenceMetrics) {
        guard done else { throw LocalInferenceError.generationIncomplete }
        if finishReason == "length" { throw LocalInferenceError.generationTruncated }
        guard finishReason == "stop", !content.isEmpty else { throw LocalInferenceError.generationIncomplete }
        return (Data(content.utf8), InferenceMetrics(
            elapsedSeconds: seconds(start.duration(to: .now)), firstContentSeconds: firstContentSeconds,
            promptTokens: usage?.prompt_tokens, completionTokens: usage?.completion_tokens
        ))
    }

    /// Decode only a provisional human-readable meaning, never raw JSON or the
    /// model's reasoning channel. Incomplete escapes wait for the next chunk.
    static func meaningPreview(in content: String) -> String? {
        guard let header = content.range(of: #"^\s*\{\s*"meaning"\s*:\s*""#, options: .regularExpression) else { return nil }
        let tail = content[header.upperBound...]
        var escaped = false
        var end = tail.endIndex
        for index in tail.indices {
            let character = tail[index]
            if character == "\"", !escaped { end = index; break }
            if character == "\\", !escaped { escaped = true } else { escaped = false }
        }
        let raw = "\"" + tail[..<end] + "\""
        return try? JSONDecoder().decode(String.self, from: Data(raw.utf8))
    }
}

private func seconds(_ duration: Duration) -> Double {
    let value = duration.components
    return Double(value.seconds) + Double(value.attoseconds) / 1e18
}
