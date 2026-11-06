import Foundation
import SandpaperCore

enum EvaluationReplay {
    /// Reuse actual generations to measure policy changes, never relabeling generation timings.
    static func run(from input: URL, to output: URL, fixtures: [EvaluationCase]) throws {
        guard input.standardizedFileURL != output.standardizedFileURL else {
            throw LibraryError.invalidInput("Replay input and output must differ.")
        }
        let handle = try FileHandle(forReadingFrom: input)
        defer { try? handle.close() }
        let data = try handle.read(upToCount: 16_777_217) ?? Data()
        guard data.count <= 16_777_216,
              var object = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              var rows = object["records"] as? [[String: Any]] else {
            throw LibraryError.invalidInput("Invalid replay report.")
        }
        let start = ContinuousClock.now
        for index in rows.indices {
            let row = rows[index]
            guard let diagnosticObject = row["hybridDiagnostics"], row["discoveryError"] == nil else { continue }
            let diagnostics = try JSONDecoder().decode(HybridDiscoveryDiagnostics.self, from: JSONSerialization.data(withJSONObject: diagnosticObject))
            guard diagnostics.completed, let discoveryObject = row["discovery"],
                  let text = row["passage"] as? String, let id = row["id"] as? String else { continue }
            let report = try JSONDecoder().decode(DiscoveryReport.self, from: JSONSerialization.data(withJSONObject: discoveryObject))
            var candidates = report.assessments.map(\.candidate)
            for candidate in diagnostics.interpretiveCandidates where !candidates.contains(candidate) { candidates.append(candidate) }
            let anchor = candidates.first?.anchor
            let passage = try AnalysisPassage(documentID: anchor?.documentID ?? UUID(), revision: anchor?.revision ?? "evaluation-v1",
                resource: anchor?.resource ?? .text, text: text)
            let request = try DiscoveryRequest(passage: passage, familiarity: fixtures.first { $0.id == id }?.memories ?? [])
            let evaluated = try DiscoveryReport.evaluate(candidates, for: request)
            rows[index]["discovery"] = try JSONSerialization.jsonObject(with: JSONEncoder().encode(evaluated))
        }
        object["records"] = rows
        object["policyReplay"] = ["input": input.path,
            "seconds": Double(start.duration(to: .now).components.seconds) + Double(start.duration(to: .now).components.attoseconds) / 1e18,
            "note": "Current shared policy applied to saved lexical and interpretive candidates. Original generation timings and errors retained; no inference rerun. Independent sentence insights are not discarded before overlap selection."]
        try JSONSerialization.data(withJSONObject: object, options: [.prettyPrinted, .sortedKeys]).write(to: output, options: .atomic)
    }
}
