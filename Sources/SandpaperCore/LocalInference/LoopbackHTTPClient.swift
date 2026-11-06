import Foundation

public enum LocalInferenceError: Error, Equatable, Sendable {
    case invalidConfiguration
    case serverNotRunning
    case timedOut
    case httpStatus(Int)
    case redirectRejected
    case invalidResponse
    case responseTooLarge
    case contextExceeded(required: Int, available: Int)
    case generationTruncated
    case generationIncomplete
    case modelMismatch
    case unsupportedServer
    case engineBusy
    case transportFailure(Int)
}

/// A port, not an arbitrary URL: inference cannot be directed to a remote host.
public struct LlamaServerConfiguration: Sendable {
    public let port: Int
    public let modelAlias: String
    public let contextTokenLimit: Int
    public let timeout: TimeInterval

    public init(
        port: Int = 8_087, modelAlias: String = "sandpaper-local",
        contextTokenLimit: Int = 8_192, timeout: TimeInterval = 45
    ) throws {
        guard (1...65_535).contains(port), !modelAlias.isEmpty, modelAlias.utf8.count <= 256,
              (2_048...16_384).contains(contextTokenLimit), timeout.isFinite, (1...120).contains(timeout) else {
            throw LocalInferenceError.invalidConfiguration
        }
        self.port = port
        self.modelAlias = modelAlias
        self.contextTokenLimit = contextTokenLimit
        self.timeout = timeout
    }
}

final class LoopbackHTTPClient: Sendable {
    private let configuration: LlamaServerConfiguration
    private let session: URLSession

    init(configuration: LlamaServerConfiguration) {
        self.configuration = configuration
        let settings = URLSessionConfiguration.ephemeral
        settings.urlCache = nil
        settings.httpCookieStorage = nil
        settings.urlCredentialStorage = nil
        settings.requestCachePolicy = .reloadIgnoringLocalCacheData
        settings.timeoutIntervalForRequest = configuration.timeout
        settings.timeoutIntervalForResource = configuration.timeout
        settings.connectionProxyDictionary = [
            "HTTPEnable": 0, "HTTPSEnable": 0, "SOCKSEnable": 0,
            "ProxyAutoConfigEnable": 0, "ProxyAutoDiscoveryEnable": 0
        ]
        session = URLSession(configuration: settings, delegate: RejectRedirects(), delegateQueue: nil)
    }

    deinit { session.invalidateAndCancel() }

    func json<T: Decodable & Sendable>(
        _ path: String, body: Data? = nil, timeout: TimeInterval? = nil
    ) async throws -> T {
        let request = request(path, body: body, timeout: timeout)
        let (bytes, response) = try await open(request)
        defer { bytes.task.cancel() }
        try validate(response, for: request)
        let data: Data
        do {
            data = try await withTaskCancellationHandler {
                var data = Data()
                for try await byte in bytes {
                    try Task.checkCancellation()
                    guard data.count < 1_048_576 else { throw LocalInferenceError.responseTooLarge }
                    data.append(byte)
                }
                return data
            } onCancel: { bytes.task.cancel() }
        } catch { throw normalized(error) }
        try Task.checkCancellation()
        do { return try JSONDecoder().decode(T.self, from: data) }
        catch { throw LocalInferenceError.invalidResponse }
    }

    func stream(_ path: String, body: Data, onEvent: @Sendable (String) async throws -> Bool) async throws {
        let request = request(path, body: body)
        let (bytes, response) = try await open(request)
        defer { bytes.task.cancel() }
        try validate(response, for: request)
        guard let http = response as? HTTPURLResponse,
              http.value(forHTTPHeaderField: "Content-Type")?.lowercased().hasPrefix("text/event-stream") == true else {
            throw LocalInferenceError.invalidResponse
        }
        do {
            try await withTaskCancellationHandler {
                var decoder = ServerSentEvents()
                for try await byte in bytes {
                    try Task.checkCancellation()
                    if let event = try decoder.append(byte), try await !onEvent(event) { return }
                }
                if let event = try decoder.finish() { _ = try await onEvent(event) }
            } onCancel: { bytes.task.cancel() }
        } catch { throw normalized(error) }
    }

    private func request(_ path: String, body: Data?, timeout: TimeInterval? = nil) -> URLRequest {
        // All callers use fixed internal paths. No DNS lookup or system proxy is required.
        let url = URL(string: "http://127.0.0.1:\(configuration.port)\(path)")!
        var request = URLRequest(url: url)
        request.timeoutInterval = timeout ?? configuration.timeout
        request.httpMethod = body == nil ? "GET" : "POST"
        request.httpBody = body
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json, text/event-stream", forHTTPHeaderField: "Accept")
        return request
    }

    private func open(_ request: URLRequest) async throws -> (URLSession.AsyncBytes, URLResponse) {
        try Task.checkCancellation()
        do { return try await session.bytes(for: request) }
        catch { throw normalized(error) }
    }

    private func validate(_ response: URLResponse, for request: URLRequest) throws {
        guard response.url == request.url, let http = response as? HTTPURLResponse else {
            throw LocalInferenceError.redirectRejected
        }
        if (300...399).contains(http.statusCode) { throw LocalInferenceError.redirectRejected }
        guard (200...299).contains(http.statusCode) else { throw LocalInferenceError.httpStatus(http.statusCode) }
        guard response.expectedContentLength <= 1_048_576 else { throw LocalInferenceError.responseTooLarge }
    }

    private func normalized(_ error: any Error) -> any Error {
        if Task.isCancelled { return CancellationError() }
        guard let error = error as? URLError else { return error }
        switch error.code {
        case .timedOut: return LocalInferenceError.timedOut
        case .cannotConnectToHost, .cannotFindHost, .networkConnectionLost:
            return LocalInferenceError.serverNotRunning
        default: return LocalInferenceError.transportFailure(error.errorCode)
        }
    }
}

private final class RejectRedirects: NSObject, URLSessionTaskDelegate, Sendable {
    func urlSession(
        _ session: URLSession, task: URLSessionTask, willPerformHTTPRedirection response: HTTPURLResponse,
        newRequest request: URLRequest, completionHandler: @escaping @Sendable (URLRequest?) -> Void
    ) { completionHandler(nil) }
}

/// Byte-based framing avoids unbounded buffering by AsyncBytes.lines. Handles
/// fragmented UTF-8, CRLF, comments and multi-line data events before decoding JSON.
struct ServerSentEvents {
    private var line = Data()
    private var event = Data()
    private var total = 0

    mutating func append(_ byte: UInt8) throws -> String? {
        total += 1
        guard total <= 1_048_576, line.count < 65_536 else { throw LocalInferenceError.responseTooLarge }
        if byte == 10 { return try consumeLine() }
        line.append(byte)
        return nil
    }

    mutating func finish() throws -> String? {
        if !line.isEmpty, let completed = try consumeLine() { return completed }
        return try flush()
    }

    private mutating func consumeLine() throws -> String? {
        defer { line.removeAll(keepingCapacity: true) }
        if line.last == 13 { line.removeLast() }
        if line.isEmpty { return try flush() }
        guard line.starts(with: Data("data:".utf8)) else { return nil }
        var payload = line.dropFirst(5)
        if payload.first == 32 { payload = payload.dropFirst() }
        if !event.isEmpty { event.append(10) }
        event.append(contentsOf: payload)
        guard event.count <= 65_536 else { throw LocalInferenceError.responseTooLarge }
        return nil
    }

    private mutating func flush() throws -> String? {
        guard !event.isEmpty else { return nil }
        defer { event.removeAll(keepingCapacity: true) }
        guard let string = String(data: event, encoding: .utf8) else { throw LocalInferenceError.invalidResponse }
        return string
    }
}
