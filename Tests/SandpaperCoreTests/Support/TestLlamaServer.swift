import Foundation
import Network

/// A real loopback HTTP fixture. It exercises the production URLSession path;
/// canned responses are test data, never a product inference implementation.
final class TestLlamaServer: Sendable {
    struct Behavior: Sendable {
        var discovery = #"{"candidates":[]}"#
        var explanation = #"{"meaning":"The agreement failed to happen.","notes":[]}"#
        var tokenCount = 64
        var alias = "sandpaper-local"
        var finishReason = "stop"
        var includeDone = true
        var redirectHealth = false
        var stallGeneration = false
    }

    let port: Int
    let state: TestLlamaServerState
    private let listener: NWListener

    private init(port: Int, state: TestLlamaServerState, listener: NWListener) {
        self.port = port
        self.state = state
        self.listener = listener
    }

    static func start(_ behavior: Behavior = Behavior()) async throws -> TestLlamaServer {
        let parameters = NWParameters.tcp
        parameters.requiredLocalEndpoint = .hostPort(host: "127.0.0.1", port: .any)
        let listener = try NWListener(using: parameters)
        let state = TestLlamaServerState(behavior: behavior)
        listener.newConnectionHandler = { connection in Task { await state.serve(connection) } }
        let port: Int = try await withCheckedThrowingContinuation { continuation in
            listener.stateUpdateHandler = { status in
                switch status {
                case .ready:
                    listener.stateUpdateHandler = nil
                    if let port = listener.port { continuation.resume(returning: Int(port.rawValue)) }
                    else { continuation.resume(throwing: TestServerError.invalidRequest) }
                case .failed(let error):
                    listener.stateUpdateHandler = nil
                    listener.cancel()
                    continuation.resume(throwing: error)
                default: break
                }
            }
            listener.start(queue: .global())
        }
        return TestLlamaServer(port: port, state: state, listener: listener)
    }

    func close() {
        listener.cancel()
        let state = state
        Task { await state.stop() }
    }

    deinit {
        listener.cancel()
        let state = state
        Task { await state.stop() }
    }
}

enum TestServerError: Error { case invalidRequest, timedOut }

actor TestLlamaServerState {
    struct Request: Sendable { let path: String; let body: Data }
    private let behavior: TestLlamaServer.Behavior
    private var connections: [NWConnection] = []
    private(set) var requests: [Request] = []

    init(behavior: TestLlamaServer.Behavior) { self.behavior = behavior }

    func waitForGeneration(count: Int = 1) async throws {
        let deadline = ContinuousClock.now.advanced(by: .seconds(3))
        while requests.filter({ $0.path == "/v1/chat/completions" }).count < count {
            guard ContinuousClock.now < deadline else { throw TestServerError.timedOut }
            try await Task.sleep(for: .milliseconds(2))
        }
    }

    func stop() {
        connections.forEach { $0.cancel() }
        connections.removeAll()
    }

    func serve(_ connection: NWConnection) async {
        connections.append(connection)
        connection.start(queue: .global())
        defer {
            connection.cancel()
            connections.removeAll { $0 === connection }
        }
        do {
            let request = try await readRequest(connection)
            requests.append(request)
            if request.path == "/health", behavior.redirectHealth {
                try await send(Data("HTTP/1.1 302 Found\r\nLocation: https://example.invalid/collect\r\nContent-Length: 0\r\nConnection: close\r\n\r\n".utf8), to: connection)
                return
            }
            if request.path == "/v1/chat/completions", behavior.stallGeneration {
                try await send(Data("HTTP/1.1 200 OK\r\nContent-Type: text/event-stream\r\nConnection: close\r\n\r\n".utf8), to: connection)
                _ = try? await receive(connection) // Finishes when client cancels/times out.
                return
            }
            let body: Data
            var type = "application/json"
            switch request.path {
            case "/health": body = Data(#"{"status":"ok"}"#.utf8)
            case "/props":
                body = Data(#"{"default_generation_settings":{"n_ctx":8192},"total_slots":1,"model_path":"fixture.gguf"}"#.utf8)
            case "/v1/models": body = try JSONSerialization.data(withJSONObject: ["data": [["id": behavior.alias]]])
            case "/apply-template": body = Data(#"{"prompt":"A formatted fixture prompt."}"#.utf8)
            case "/tokenize": body = try JSONSerialization.data(withJSONObject: ["tokens": Array(repeating: 1, count: behavior.tokenCount)])
            case "/v1/chat/completions":
                let object = try JSONSerialization.jsonObject(with: request.body) as? [String: Any]
                let format = object?["response_format"] as? [String: Any]
                let schema = format?["json_schema"] as? [String: Any]
                let isDiscovery = schema?["name"] as? String == "discovery"
                body = try stream(isDiscovery ? behavior.discovery : behavior.explanation)
                type = "text/event-stream"
            default: body = Data("{}".utf8)
            }
            var response = Data("HTTP/1.1 200 OK\r\nContent-Type: \(type)\r\nContent-Length: \(body.count)\r\nConnection: close\r\n\r\n".utf8)
            response.append(body)
            try await send(response, to: connection)
        } catch { /* A cancelled client intentionally closes the connection. */ }
    }

    private func stream(_ content: String) throws -> Data {
        var wire = ""
        // Split within the generated JSON so preview parsing is exercised too.
        let middle = content.index(content.startIndex, offsetBy: content.count / 2)
        for chunk in [String(content[..<middle]), String(content[middle...])] {
            let frame = try JSONSerialization.data(withJSONObject: ["choices": [[
                "index": 0, "delta": ["content": chunk], "finish_reason": NSNull()
            ]]])
            wire += "data: " + String(decoding: frame, as: UTF8.self) + "\n\n"
        }
        let final = try JSONSerialization.data(withJSONObject: ["choices": [[
            "index": 0, "delta": [:], "finish_reason": behavior.finishReason
        ]]])
        wire += "data: " + String(decoding: final, as: UTF8.self) + "\n\n"
        wire += "data: {\"choices\":[],\"usage\":{\"prompt_tokens\":64,\"completion_tokens\":20}}\n\n"
        if behavior.includeDone { wire += "data: [DONE]\n\n" }
        return Data(wire.utf8)
    }

    private func readRequest(_ connection: NWConnection) async throws -> Request {
        var buffer = Data()
        while buffer.count < 1_048_576 {
            buffer.append(try await receive(connection))
            guard let separator = buffer.range(of: Data("\r\n\r\n".utf8)),
                  let header = String(data: buffer[..<separator.lowerBound], encoding: .utf8) else { continue }
            let lines = header.components(separatedBy: "\r\n")
            guard let first = lines.first, let path = first.split(separator: " ").dropFirst().first else {
                throw TestServerError.invalidRequest
            }
            let length = lines.first { $0.lowercased().hasPrefix("content-length:") }
                .flatMap { Int($0.split(separator: ":", maxSplits: 1)[1].trimmingCharacters(in: .whitespaces)) } ?? 0
            guard length >= 0, length < 1_048_576 else { throw TestServerError.invalidRequest }
            if buffer.count - separator.upperBound >= length {
                return Request(path: String(path), body: buffer.subdata(in: separator.upperBound..<(separator.upperBound + length)))
            }
        }
        throw TestServerError.invalidRequest
    }

    private func receive(_ connection: NWConnection) async throws -> Data {
        try await withCheckedThrowingContinuation { continuation in
            connection.receive(minimumIncompleteLength: 1, maximumLength: 65_536) { data, _, complete, error in
                if let error { continuation.resume(throwing: error) }
                else if let data, !data.isEmpty { continuation.resume(returning: data) }
                else if complete { continuation.resume(throwing: TestServerError.invalidRequest) }
                else { continuation.resume(throwing: TestServerError.invalidRequest) }
            }
        }
    }

    private func send(_ data: Data, to connection: NWConnection) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, any Error>) in
            connection.send(content: data, completion: .contentProcessed { error in
                if let error { continuation.resume(throwing: error) }
                else { continuation.resume() }
            })
        }
    }
}
