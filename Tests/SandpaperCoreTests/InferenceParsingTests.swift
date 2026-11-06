import Foundation
import Testing
@testable import SandpaperCore

struct InferenceParsingTests {
    @Test func eventFramingHandlesFragmentedUnicodeCRLFAndComments() throws {
        var decoder = ServerSentEvents()
        let wire = ": heartbeat\r\ndata: {\"text\":\r\ndata: \"📖\"}\r\n\r\ndata: [DONE]\n\n"
        let events = try wire.utf8.compactMap { try decoder.append($0) }
        #expect(events == ["{\"text\":\n\"📖\"}", "[DONE]"])
    }

    @Test func unfinishedFinalEventIsDeliveredButUnboundedLinesAreRejected() throws {
        var decoder = ServerSentEvents()
        for byte in "data: [DONE]".utf8 { _ = try decoder.append(byte) }
        #expect(try decoder.finish() == "[DONE]")
        var unbounded = ServerSentEvents()
        #expect(throws: LocalInferenceError.responseTooLarge) {
            for _ in 0...65_536 { _ = try unbounded.append(65) }
        }
    }

    @Test func meaningPreviewDecodesEscapesAndWaitsForIncompleteUnicode() {
        #expect(ChatStreamCollector.meaningPreview(in: #"{"meaning":"A \"small\" point"#) == "A \"small\" point")
        #expect(ChatStreamCollector.meaningPreview(in: #"{"meaning":"A \uD83D"#) == nil)
        #expect(ChatStreamCollector.meaningPreview(in: #"{"meaning":"A \uD83D\uDCD6"#) == "A 📖")
        #expect(ChatStreamCollector.meaningPreview(in: #"{"notes":[],"meaning":"Late"}"#) == nil)
        #expect(ChatStreamCollector.meaningPreview(in: #"{"meaning":"Done","notes":[]}"#) == "Done")
    }

    @Test func incompleteAndTruncatedStreamsNeverBecomeSuccessfulExplanations() async throws {
        let truncated = ChatStreamCollector()
        _ = try await truncated.ingest(event(content: "{}", reason: "length"), onUpdate: nil)
        _ = try await truncated.ingest("[DONE]", onUpdate: nil)
        await #expect(throws: LocalInferenceError.generationTruncated) { try await truncated.result() }
        let interrupted = ChatStreamCollector()
        _ = try await interrupted.ingest(event(content: "{}", reason: "stop"), onUpdate: nil)
        await #expect(throws: LocalInferenceError.generationIncomplete) { try await interrupted.result() }
    }

    private func event(content: String, reason: String) throws -> String {
        String(decoding: try JSONSerialization.data(withJSONObject: ["choices": [[
            "index": 0, "delta": ["content": content], "finish_reason": reason
        ]]]), as: UTF8.self)
    }
}
