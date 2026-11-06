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
            var arguments = Array(CommandLine.arguments.dropFirst())[...]
            while let argument = arguments.popFirst() {
                switch argument {
                case "--help", "-h":
                    print("""
                        Usage: sandpaper-evaluate [--port 8087] [--output report.json]
                               [--extended] [--case CASE-ID ...] [--repeat 1...5]
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
                case "--case":
                    guard let value = arguments.popFirst() else { throw CLIError.arguments }
                    selectedIDs.insert(value)
                case "--repeat":
                    guard let value = arguments.popFirst(), let count = Int(value), (1...5).contains(count) else { throw CLIError.arguments }
                    repetitions = count
                default: throw CLIError.arguments
                }
            }
            let allCases = EvaluationCase.cases + EvaluationCase.extendedCases
            guard selectedIDs.isSubset(of: Set(allCases.map(\.id))) else { throw CLIError.arguments }
            let cases = selectedIDs.isEmpty ? (extended ? allCases : EvaluationCase.cases)
                : allCases.filter { selectedIDs.contains($0.id) }
            let engine = LlamaLocalEngine(configuration: try LlamaServerConfiguration(port: port))
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
                do {
                    discovery = try await coordinator.discover(DiscoveryRequest(passage: passage, familiarity: fixture.memories))
                    discoveryMetrics = await engine.lastMetrics
                } catch { discoveryError = String(describing: error) }
                let discoveryWallSeconds = elapsed(since: discoveryStart)
                var explanation: Explanation?
                var explanationError: String?
                var explanationMetrics: InferenceMetrics?
                let explanationStart = ContinuousClock.now
                let preview = PreviewTiming(start: explanationStart)
                do {
                    let selection = try passage.anchor(for: (passage.text as NSString).range(of: fixture.selection))
                    explanation = try await coordinator.explain(ExplanationRequest(passage: passage, selection: selection)) {
                        await preview.observe($0)
                    }
                    explanationMetrics = await engine.lastMetrics
                } catch { explanationError = String(describing: error) }
                records.append(Record(
                    id: fixture.id, iteration: iteration, passage: fixture.passage, selection: fixture.selection,
                    reviewFocus: fixture.reviewFocus, source: fixture.source,
                    discovery: discovery, discoveryWallSeconds: discoveryWallSeconds, discoveryMetrics: discoveryMetrics, discoveryError: discoveryError,
                    explanation: explanation, explanationWallSeconds: elapsed(since: explanationStart), firstMeaningSeconds: await preview.first,
                    explanationMetrics: explanationMetrics, explanationError: explanationError
                ))
                // Preserve completed observations if a later request is interrupted.
                if let output {
                    try encodeReport(identity: identity, records: records).write(to: output, options: .atomic)
                }
              }
            }
            let data = try encodeReport(identity: identity, records: records)
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

    private static func encodeReport(identity: String, records: [Record]) throws -> Data {
        let report = Report(
            generatedAt: Date(), modelIdentity: identity, promptVersion: LlamaLocalEngine.promptVersion,
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
