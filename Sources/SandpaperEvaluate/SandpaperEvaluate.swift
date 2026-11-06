import Foundation
import SandpaperCore

@main
struct SandpaperEvaluate {
    private struct Record: Encodable {
        let id: String
        let iteration: Int
        let passage: String
        let selection: String
        let reviewFocus: String
        let source: String?
        let discovery: DiscoveryReport?
        let discoveryWallSeconds: Double
        let discoveryMetrics: InferenceMetrics?
        let discoveryError: String?
        let hybridDiagnostics: HybridDiscoveryDiagnostics?
        let lexicalLookupSeconds: Double?
        let lexicalPossibilityCount: Int?
        let explanation: Explanation?
        let explanationWallSeconds: Double
        let firstMeaningSeconds: Double?
        let explanationMetrics: InferenceMetrics?
        let explanationError: String?
    }

    private struct Report: Encodable {
        let generatedAt: Date
        let modelIdentity: String
        let promptVersion: String
        let analysisMode: String
        let lexiconPath: String?
        let evaluationTasks: [String]
        let chatFormat: LocalChatFormat
        let requestTimeoutSeconds: TimeInterval
        let operatingSystem: String
        let physicalMemoryBytes: UInt64
        let records: [Record]
        let note = "Review linguistic quality manually. Timings are real requests on this host; this is not an automatic quality score or a peak-memory measurement."
    }

    static func main() async {
        do {
            var port = 8_087
            var output: URL?
            var extended = false
            var selectedIDs: Set<String> = []
            var repetitions = 1
            var chatFormat = LocalChatFormat.native
            var timeout: TimeInterval = 45
            var lexiconURL: URL?
            var lexicalInput: URL?
            var additionalCases: URL?
            var explanationOnly = false
            var replayInput: URL?
            var arguments = Array(CommandLine.arguments.dropFirst())[...]
            while let argument = arguments.popFirst() {
                switch argument {
                case "--help", "-h":
                    print("""
                        Usage: sandpaper-evaluate [--port 8087] [--output report.json]
                               [--extended] [--case CASE-ID ...] [--repeat 1...5]
                               [--chat-format native|gemma3] [--timeout 1...120]
                               [--lexicon dictionary.sqlite] [--additional-cases cases.json]
                               [--explain-only]
                               [--replay-discovery previous-report.json --output replay.json]
                        Build an offline dictionary index without running inference:
                          --build-lexicon entries.jsonl --lexicon dictionary.sqlite
                        Requires a local llama.cpp server with alias sandpaper-local and one slot.
                        Evaluates six baseline cases; --extended adds ten representative passages.
                        No model downloads, cloud requests, or automatic quality claims.
                        See docs/local-inference.md for setup.
                        """)
                    return
                case "--port":
                    guard let value = arguments.popFirst(), let parsed = Int(value) else { throw CLIError.arguments }
                    port = parsed
                case "--output":
                    guard let value = arguments.popFirst(), !value.isEmpty else { throw CLIError.arguments }
                    output = URL(fileURLWithPath: value)
                case "--extended": extended = true
                case "--explain-only": explanationOnly = true
                case "--replay-discovery":
                    guard let value = arguments.popFirst() else { throw CLIError.arguments }
                    replayInput = URL(fileURLWithPath: value)
                case "--case":
                    guard let value = arguments.popFirst() else { throw CLIError.arguments }
                    selectedIDs.insert(value)
                case "--repeat":
                    guard let value = arguments.popFirst(), let count = Int(value), (1...5).contains(count) else { throw CLIError.arguments }
                    repetitions = count
                case "--chat-format":
                    guard let value = arguments.popFirst(), let parsed = LocalChatFormat(rawValue: value) else { throw CLIError.arguments }
                    chatFormat = parsed
                case "--timeout":
                    guard let value = arguments.popFirst(), let seconds = Double(value) else { throw CLIError.arguments }
                    timeout = seconds
                case "--lexicon":
                    guard let value = arguments.popFirst() else { throw CLIError.arguments }
                    lexiconURL = URL(fileURLWithPath: value)
                case "--build-lexicon":
                    guard let value = arguments.popFirst() else { throw CLIError.arguments }
                    lexicalInput = URL(fileURLWithPath: value)
                case "--additional-cases":
                    guard let value = arguments.popFirst() else { throw CLIError.arguments }
                    additionalCases = URL(fileURLWithPath: value)
                default: throw CLIError.arguments
                }
            }
            if let lexicalInput {
                guard let lexiconURL else { throw CLIError.arguments }
                try LexiconStore.build(fromJSONL: lexicalInput, at: lexiconURL)
                print("Built local dictionary index at \(lexiconURL.path)")
                return
            }
            let extra = try additionalCases.map { try EvaluationCase.loadAdditional(from: $0) } ?? []
            let allCases = EvaluationCase.cases + EvaluationCase.extendedCases + extra
            guard Set(allCases.map(\.id)).count == allCases.count else { throw CLIError.arguments }
            if let replayInput {
                guard let output else { throw CLIError.arguments }
                try EvaluationReplay.run(from: replayInput, to: output, fixtures: allCases)
                return
            }
            guard selectedIDs.isSubset(of: Set(allCases.map(\.id))) else { throw CLIError.arguments }
            let cases = selectedIDs.isEmpty ? ((extended ? EvaluationCase.cases + EvaluationCase.extendedCases : EvaluationCase.cases) + extra)
                : allCases.filter { selectedIDs.contains($0.id) }
            let lexicon = try lexiconURL.map { try LexiconStore(at: $0) }
            let engine = LlamaLocalEngine(configuration: try LlamaServerConfiguration(port: port, timeout: timeout, chatFormat: chatFormat), lexicon: lexicon)
            guard case .ready(let identity) = await engine.availability() else { throw CLIError.serverUnavailable }
            let coordinator = AnalysisCoordinator(engine: engine, debounce: .zero)
            var records: [Record] = []
            for iteration in 1...repetitions {
              for fixture in cases {
                FileHandle.standardError.write(Data("Evaluating \(fixture.id) (trial \(iteration))…\n".utf8))
                let passage = try AnalysisPassage(documentID: UUID(), revision: "evaluation-v1", resource: .text, text: fixture.passage)
                var discovery: DiscoveryReport?
                var discoveryError: String?
                var discoveryMetrics: InferenceMetrics?
                let discoveryStart = ContinuousClock.now
                if !explanationOnly { do {
                    discovery = try await coordinator.discover(DiscoveryRequest(passage: passage, familiarity: fixture.memories))
                    discoveryMetrics = await engine.lastMetrics
                } catch { discoveryError = String(describing: error) } }
                let discoveryWallSeconds = explanationOnly ? 0 : elapsed(since: discoveryStart)
                let diagnostics = await engine.lastHybridDiagnostics
                var explanation: Explanation?
                var explanationError: String?
                var explanationMetrics: InferenceMetrics?
                var lexicalLookupSeconds: Double?
                var lexicalPossibilityCount: Int?
                let selection = try passage.anchor(for: (passage.text as NSString).range(of: fixture.selection))
                let explanationRequest = try ExplanationRequest(passage: passage, selection: selection)
                if lexicon != nil {
                    let start = ContinuousClock.now
                    lexicalPossibilityCount = try await engine.lexicalInformation(for: explanationRequest).count
                    lexicalLookupSeconds = elapsed(since: start)
                }
                let explanationStart = ContinuousClock.now
                let preview = PreviewTiming(start: explanationStart)
                do {
                    explanation = try await coordinator.explain(explanationRequest) {
                        await preview.observe($0)
                    }
                    explanationMetrics = await engine.lastMetrics
                } catch { explanationError = String(describing: error) }
                records.append(Record(
                    id: fixture.id, iteration: iteration, passage: fixture.passage, selection: fixture.selection,
                    reviewFocus: fixture.reviewFocus, source: fixture.source,
                    discovery: discovery, discoveryWallSeconds: discoveryWallSeconds, discoveryMetrics: discoveryMetrics, discoveryError: discoveryError,
                    hybridDiagnostics: diagnostics, lexicalLookupSeconds: lexicalLookupSeconds, lexicalPossibilityCount: lexicalPossibilityCount,
                    explanation: explanation, explanationWallSeconds: elapsed(since: explanationStart), firstMeaningSeconds: await preview.first,
                    explanationMetrics: explanationMetrics, explanationError: explanationError
                ))
                // Preserve completed observations if a later request is interrupted.
                if let output {
                    try encodeReport(identity: identity, records: records, chatFormat: chatFormat, timeout: timeout, lexiconURL: lexiconURL, explanationOnly: explanationOnly).write(to: output, options: .atomic)
                }
              }
            }
            let data = try encodeReport(identity: identity, records: records, chatFormat: chatFormat, timeout: timeout, lexiconURL: lexiconURL, explanationOnly: explanationOnly)
            if let output { try data.write(to: output, options: .atomic) }
            else { FileHandle.standardOutput.write(data); print("") }
            if records.contains(where: { $0.discoveryError != nil || $0.explanationError != nil }) { exit(1) }
        } catch {
            let message: String
            switch error {
            case CLIError.arguments: message = "Invalid arguments. Run sandpaper-evaluate --help."
            case CLIError.serverUnavailable: message = "The local model server is unavailable. Follow docs/local-inference.md, then retry."
            default: message = String(describing: error)
            }
            FileHandle.standardError.write(Data((message + "\n").utf8))
            exit(2)
        }
    }

    private static func encodeReport(identity: String, records: [Record], chatFormat: LocalChatFormat, timeout: TimeInterval, lexiconURL: URL?, explanationOnly: Bool) throws -> Data {
        let report = Report(
            generatedAt: Date(), modelIdentity: identity,
            promptVersion: lexiconURL == nil ? LlamaLocalEngine.promptVersion : LlamaLocalEngine.hybridPromptVersion,
            analysisMode: lexiconURL == nil ? "modelOnly" : "hybrid", lexiconPath: lexiconURL?.path,
            evaluationTasks: explanationOnly ? ["explanation"] : ["discovery", "explanation"],
            chatFormat: chatFormat, requestTimeoutSeconds: timeout,
            operatingSystem: ProcessInfo.processInfo.operatingSystemVersionString,
            physicalMemoryBytes: ProcessInfo.processInfo.physicalMemory, records: records
        )
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        return try encoder.encode(report)
    }
}

private enum CLIError: Error { case arguments, serverUnavailable }

private actor PreviewTiming {
    let start: ContinuousClock.Instant
    var first: Double?
    init(start: ContinuousClock.Instant) { self.start = start }
    func observe(_ preview: String) {
        if first == nil, !preview.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { first = elapsed(since: start) }
    }
}

private func elapsed(since start: ContinuousClock.Instant) -> Double {
    let value = start.duration(to: .now).components
    return Double(value.seconds) + Double(value.attoseconds) / 1e18
}
