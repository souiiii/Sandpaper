import Foundation
import Testing
@testable import SandpaperCore

struct DictionaryEvidenceTests {
    @Test func phraseExcerptFindsDefinitionDeepInArticleAndExcludesRootOrigin() throws {
        let text = String(repeating: "Other senses. ", count: 150) + "fall through come to nothing; fail: the project fell through. fall to begin. ORIGIN Old English."
        let entry = DictionaryEntry(id: "fall", query: "fall through", text: text, provider: "Fixture")
        let excerpts = try DictionaryEvidence.relevantExcerpts(from: [entry])
        #expect(excerpts.first?.text == "fall through come to nothing; fail: the project fell through.")
        #expect(excerpts.first?.entryID == "fall")
        let unrelated = DictionaryEntry(id: "x", query: "missing phrase", text: text, provider: "Fixture")
        #expect(try DictionaryEvidence.relevantExcerpts(from: [unrelated]).isEmpty)
    }

    @Test func evidenceBoundsAndOldSavedExplanationsRemainCompatible() throws {
        let entry = DictionaryEntry(id: "id", query: "test", text: String(repeating: "🌊", count: 800), provider: "Fixture")
        let excerpts = try DictionaryEvidence.relevantExcerpts(from: [entry])
        #expect(excerpts.first?.text.utf16.count == 1_000)
        #expect(throws: (any Error).self) { try DictionaryEvidence(entry: entry, range: NSRange(location: 1, length: 1)) }
        let old = try JSONDecoder().decode(Explanation.self, from: Data(#"{"meaning":"A meaning.","details":[]}"#.utf8))
        #expect(old.dictionaryEvidence.isEmpty)
    }

    @Test func localPhraseLemmatizationOnlyChangesInflectedHead() {
        #expect(MacOSDictionary.phraseLemma("fell through") == "fall through")
        #expect(MacOSDictionary.phraseLemma("fall through") == nil)
        #expect(MacOSDictionary.phraseLemma("wanting") == nil)
    }

    @Test func adapterSuppliesEvidenceButNeverLabelsGeneratedProseAsDictionaryFact() async throws {
        let server = try await TestLlamaServer.start(); defer { server.close() }
        let engine = LlamaLocalEngine(configuration: try LlamaServerConfiguration(port: server.port))
        let passage = try AnalysisPassage(documentID: UUID(), revision: "v1", resource: .text, text: "The agreement fell through.")
        let entry = DictionaryEntry(id: "fall", query: "fall through", text: "fall through: fail.", provider: "Fixture")
        let evidence = try DictionaryEvidence.relevantExcerpts(from: [entry])
        let request = try ExplanationRequest(passage: passage, selection: passage.anchor(for: (passage.text as NSString).range(of: "fell through")), dictionaryEvidence: evidence)
        let answer = try await engine.explain(request, onUpdate: { _ in })
        #expect(answer.dictionaryEvidence == evidence)
        #expect(answer.details.isEmpty)
        let sent = try #require(await server.state.requests.first { $0.path == "/v1/chat/completions" })
        #expect(String(decoding: sent.body, as: UTF8.self).contains("fall through: fail."))
    }
}
