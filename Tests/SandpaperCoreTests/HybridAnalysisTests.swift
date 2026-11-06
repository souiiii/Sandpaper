import Foundation
import Testing
@testable import SandpaperCore

struct HybridAnalysisTests {
    private func entry(_ word: String = "fall through", forms: [String] = ["fell through"], definitions: [String] = ["For a plan or agreement to fail to happen."]) -> LexicalEntry {
        LexicalEntry(id: word, headword: word, partOfSpeech: "verb", forms: forms,
            senses: definitions.enumerated().map { LexicalSense(id: "sense-\($0.offset)", definition: $0.element, tags: ["idiomatic"]) },
            source: "Dictionary test fixture", sourceURL: "https://example.invalid/dictionary", licenseURL: "https://example.invalid/license", datasetVersion: "test-1")
    }
    private func directory() throws -> URL {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }
    private func store(_ entries: [LexicalEntry], in directory: URL) throws -> LexiconStore {
        let input = directory.appendingPathComponent("entries.jsonl"), output = directory.appendingPathComponent("lexicon.sqlite")
        var data = Data()
        for entry in entries { data.append(try JSONEncoder().encode(entry)); data.append(10) }
        try data.write(to: input)
        try LexiconStore.build(fromJSONL: input, at: output)
        return try LexiconStore(at: output)
    }
    private func passage(_ text: String = "The agreement fell through.") throws -> AnalysisPassage {
        try AnalysisPassage(documentID: UUID(), revision: "r1", resource: .text, text: text)
    }

    @Test func lexicalIndexPreservesProvenanceAndNeverOverwritesAnExistingFile() throws {
        let dir = try directory(); defer { try? FileManager.default.removeItem(at: dir) }
        let dictionary = try store([entry()], in: dir)
        #expect(try dictionary.lookup("FELL THROUGH").first?.sourceURL == "https://example.invalid/dictionary")
        let destination = dir.appendingPathComponent("lexicon.sqlite")
        let before = try Data(contentsOf: destination)
        #expect(throws: (any Error).self) { try LexiconStore.build(fromJSONL: dir.appendingPathComponent("entries.jsonl"), at: destination) }
        #expect(try Data(contentsOf: destination) == before)
    }

    @Test func malformedImportRollsBackAndRemovesOnlyItsOwnOutput() throws {
        let dir = try directory(); defer { try? FileManager.default.removeItem(at: dir) }
        let input = dir.appendingPathComponent("bad.jsonl"), output = dir.appendingPathComponent("out.sqlite")
        var data = try JSONEncoder().encode(entry()); data.append(Data("\n{bad json}\n".utf8)); try data.write(to: input)
        #expect(throws: (any Error).self) { try LexiconStore.build(fromJSONL: input, at: output) }
        #expect(!FileManager.default.fileExists(atPath: output.path))
        #expect(try Data(contentsOf: input) == data)
    }

    @Test func scannerPreservesUnicodeRepeatedAnchorsAndDoesNotCrossPunctuation() throws {
        let dir = try directory(); defer { try? FileManager.default.removeItem(at: dir) }
        let dictionary = try store([entry()], in: dir)
        let p = try passage("🙂 It fell through. It fell through again. Fall, through the opening.")
        let scan = try LexicalScanner.scan(p, in: dictionary)
        #expect(scan.candidates.count == 2)
        #expect(scan.candidates.map(\.anchor.quote) == ["fell through", "fell through"])
        #expect(Set(scan.candidates.map(\.id)).count == 2)
        for candidate in scan.candidates {
            #expect((p.text as NSString).substring(with: NSRange(location: candidate.anchor.utf16Offset, length: candidate.anchor.utf16Length)) == candidate.anchor.quote)
        }
    }

    @Test func possessivePatternMatchesLiteralUsageOnlyAsACandidateAndReportsBudgetLoss() throws {
        let dir = try directory(); defer { try? FileManager.default.removeItem(at: dir) }
        let dictionary = try store([entry("keep one's powder dry", forms: ["kept one's powder dry"])], in: dir)
        let scan = try LexicalScanner.scan(passage("He kept his powder dry by the stove. She kept her powder dry too."), in: dictionary, limit: 1)
        #expect(scan.candidates.count == 1)
        #expect(scan.omittedCandidates == 1)
        #expect(scan.candidates.first?.anchor.quote == "kept his powder dry")
    }

    @Test func groundedAssessmentUsesAppAnchorAndValidatesSuppliedMemory() async throws {
        let dir = try directory(); defer { try? FileManager.default.removeItem(at: dir) }
        let dictionary = try store([entry()], in: dir)
        var behavior = TestLlamaServer.Behavior()
        behavior.groundedDiscovery = #"{"l14_12":{"sense":1,"confidence":2,"value":2,"memory":1,"reason":"Useful plan-failure idiom."}}"#
        let server = try await TestLlamaServer.start(behavior); defer { server.close() }
        let engine = LlamaLocalEngine(configuration: try LlamaServerConfiguration(port: server.port, chatFormat: .gemma3), lexicon: dictionary)
        let p = try passage()
        let request = try DiscoveryRequest(passage: p, familiarity: [.init(expression: "fall through", senseKey: "known", meaning: "For a plan or agreement to fail to happen.", familiarity: .known)])
        let candidates = try await engine.discover(request)
        #expect(candidates.first?.anchor.quote == "fell through")
        #expect(candidates.first?.assessment.expression == "fall through")
        #expect(try DiscoveryPolicy.evaluate(candidates, for: request).highlights.isEmpty)
        let learning = try DiscoveryRequest(passage: p, familiarity: [.init(expression: "fall through", senseKey: "known",
            meaning: "For a plan or agreement to fail to happen.", familiarity: .learning)])
        #expect(try DiscoveryReport.evaluate(candidates, for: learning).highlights.count == 1)
        #expect(await engine.lastHybridDiagnostics?.completed == true)
        #expect(await engine.lastHybridDiagnostics?.stages.count == 2)
    }

    @Test func unsupportedDictionarySenseDoesNotBlockNovelInterpretation() async throws {
        let dir = try directory(); defer { try? FileManager.default.removeItem(at: dir) }
        let dictionary = try store([entry()], in: dir)
        var behavior = TestLlamaServer.Behavior()
        behavior.interpretiveDiscovery = #"{"candidates":[{"span":"s0","meaning":"His courteous manner appears to keep her at a distance.","reason":"Courtesy as an exclusion metaphor.","confidence":2,"value":2}]}"#
        let server = try await TestLlamaServer.start(behavior); defer { server.close() }
        let engine = LlamaLocalEngine(configuration: try LlamaServerConfiguration(port: server.port), lexicon: dictionary)
        let candidates = try await engine.discover(DiscoveryRequest(passage: passage("His politeness was a locked door.")))
        #expect(candidates.count == 1)
        #expect(candidates.first?.anchor.quote == "His politeness was a locked door.")
        #expect(await engine.lastHybridDiagnostics?.lexicalAnchors.isEmpty == true)
    }

    @Test func inventedSpanIDIsRejected() async throws {
        let dir = try directory(); defer { try? FileManager.default.removeItem(at: dir) }
        let dictionary = try store([entry()], in: dir)
        var behavior = TestLlamaServer.Behavior()
        behavior.interpretiveDiscovery = #"{"candidates":[{"span":"s999","meaning":"An invented reading.","reason":"Invented.","confidence":2,"value":2}]}"#
        let server = try await TestLlamaServer.start(behavior); defer { server.close() }
        let engine = LlamaLocalEngine(configuration: try LlamaServerConfiguration(port: server.port), lexicon: dictionary)
        await #expect(throws: AnalysisError.invalidModelOutput) { try await engine.discover(DiscoveryRequest(passage: passage("A plain sentence."))) }
    }

    @Test func overlapPolicyRetainsAssessmentsFromBothRoutesForCheapReevaluation() async throws {
        let dir = try directory(); defer { try? FileManager.default.removeItem(at: dir) }
        let dictionary = try store([entry()], in: dir)
        var behavior = TestLlamaServer.Behavior()
        behavior.groundedDiscovery = #"{"l14_12":{"sense":1,"confidence":2,"value":1,"memory":0,"reason":"Useful failure idiom."}}"#
        behavior.interpretiveDiscovery = #"{"candidates":[{"span":"s0","meaning":"The plan failed.","reason":"A setback.","confidence":2,"value":2},{"span":"s0","meaning":"The intended outcome was not achieved.","reason":"A repeated insight.","confidence":2,"value":1}]}"#
        let server = try await TestLlamaServer.start(behavior); defer { server.close() }
        let engine = LlamaLocalEngine(configuration: try LlamaServerConfiguration(port: server.port), lexicon: dictionary)
        let p = try passage(), request = try DiscoveryRequest(passage: p)
        let candidates = try await engine.discover(request)
        let report = try DiscoveryReport.evaluate(candidates, for: request)
        #expect(report.assessments.count == 3)
        #expect(report.highlights.map(\.anchor.quote) == ["The agreement fell through."])
        #expect(await engine.lastHybridDiagnostics?.interpretiveCandidates.count == 2)
    }

    @Test func aRejectedDictionaryMatchDoesNotBecomeAnAutomaticHighlight() async throws {
        let dir = try directory(); defer { try? FileManager.default.removeItem(at: dir) }
        let dictionary = try store([entry("keep one's powder dry", forms: ["kept one's powder dry"])], in: dir)
        var behavior = TestLlamaServer.Behavior()
        behavior.groundedDiscovery = #"{"l3_19":{"sense":0,"confidence":2,"value":0,"memory":0,"reason":"Literal physical action."}}"#
        let server = try await TestLlamaServer.start(behavior); defer { server.close() }
        let engine = LlamaLocalEngine(configuration: try LlamaServerConfiguration(port: server.port), lexicon: dictionary)
        let result = try await engine.discover(DiscoveryRequest(passage: passage("He kept his powder dry by the stove.")))
        #expect(result.isEmpty)
    }

    @Test func quickLookupNeedsNoServerAndGeneratedTextCannotInventLexicalProvenance() async throws {
        let dir = try directory(); defer { try? FileManager.default.removeItem(at: dir) }
        let dictionary = try store([entry()], in: dir)
        var behavior = TestLlamaServer.Behavior()
        behavior.groundedExplanation = #"{"meaning":"The agreement did not happen.","senses":[1]}"#
        let server = try await TestLlamaServer.start(behavior); defer { server.close() }
        let engine = LlamaLocalEngine(configuration: try LlamaServerConfiguration(port: server.port), lexicon: dictionary)
        let p = try passage(), selection = try p.anchor(for: NSRange(location: 14, length: 12))
        let request = try ExplanationRequest(passage: p, selection: selection)
        #expect(try await engine.lexicalInformation(for: request).count == 1)
        #expect(await server.state.requests.isEmpty)
        let explanation = try await engine.explain(request, onUpdate: { _ in })
        #expect(explanation.details.isEmpty)
        let possibilities = try await engine.lexicalInformation(for: request)
        #expect(possibilities.first?.evidence.first?.sense.definition == "For a plan or agreement to fail to happen.")
        #expect(possibilities.first?.evidence.first?.entry.sourceURL == "https://example.invalid/dictionary")
    }

    @Test func incompleteContextualFragmentIsNotAcceptedAsAnExplanation() async throws {
        let dir = try directory(); defer { try? FileManager.default.removeItem(at: dir) }
        let dictionary = try store([entry()], in: dir)
        var behavior = TestLlamaServer.Behavior()
        behavior.groundedExplanation = #"{"meaning":"Here, "}"#
        let server = try await TestLlamaServer.start(behavior); defer { server.close() }
        let engine = LlamaLocalEngine(configuration: try LlamaServerConfiguration(port: server.port), lexicon: dictionary)
        let p = try passage()
        let request = try ExplanationRequest(passage: p, selection: p.anchor(for: NSRange(location: 14, length: 12)))
        await #expect(throws: AnalysisError.invalidModelOutput) { try await engine.explain(request, onUpdate: { _ in }) }
    }
}
