import Foundation
import SandpaperCore

@main
struct SandpaperEvaluate {
    private struct Record: Encodable {
        let id: String
        let passage: String
        let selection: String
        let reviewFocus: String
        let discovery: DiscoveryReport?
        let discoveryMetrics: InferenceMetrics?
        let discoveryError: String?
        let explanation: Explanation?
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
            var arguments = Array(CommandLine.arguments.dropFirst())[...]
            while let argument = arguments.popFirst() {
                switch argument {
                case "--help", "-h":
                    print("""
                        Usage: sandpaper-evaluate [--port 8087] [--output report.json]
                        Requires a local llama.cpp server with alias sandpaper-local and one slot.
                        Evaluates six reading cases and writes genuine model responses and timings.
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
                default: throw CLIError.arguments
                }
            }
            let engine = LlamaLocalEngine(configuration: try LlamaServerConfiguration(port: port))
            guard case .ready(let identity) = await engine.availability() else { throw CLIError.serverUnavailable }
            let coordinator = AnalysisCoordinator(engine: engine, debounce: .zero)
            var records: [Record] = []
            for fixture in EvaluationCase.cases {
                FileHandle.standardError.write(Data("Evaluating \(fixture.id)…\n".utf8))
                let passage = try AnalysisPassage(documentID: UUID(), revision: "evaluation-v1", resource: .text, text: fixture.passage)
                var discovery: DiscoveryReport?
                var discoveryError: String?
                var discoveryMetrics: InferenceMetrics?
                do {
                    discovery = try await coordinator.discover(DiscoveryRequest(passage: passage, familiarity: fixture.memories))
                    discoveryMetrics = await engine.lastMetrics
                } catch { discoveryError = String(describing: error) }
                var explanation: Explanation?
                var explanationError: String?
                var explanationMetrics: InferenceMetrics?
                do {
                    let selection = try passage.anchor(for: (passage.text as NSString).range(of: fixture.selection))
                    explanation = try await coordinator.explain(ExplanationRequest(passage: passage, selection: selection))
                    explanationMetrics = await engine.lastMetrics
                } catch { explanationError = String(describing: error) }
                records.append(Record(
                    id: fixture.id, passage: fixture.passage, selection: fixture.selection, reviewFocus: fixture.reviewFocus,
                    discovery: discovery, discoveryMetrics: discoveryMetrics, discoveryError: discoveryError,
                    explanation: explanation, explanationMetrics: explanationMetrics, explanationError: explanationError
                ))
            }
            let report = Report(
                generatedAt: Date(), modelIdentity: identity, promptVersion: LlamaLocalEngine.promptVersion,
                operatingSystem: ProcessInfo.processInfo.operatingSystemVersionString,
                physicalMemoryBytes: ProcessInfo.processInfo.physicalMemory, records: records
            )
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            encoder.dateEncodingStrategy = .iso8601
            let data = try encoder.encode(report)
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
}

private enum CLIError: Error { case arguments, serverUnavailable }
