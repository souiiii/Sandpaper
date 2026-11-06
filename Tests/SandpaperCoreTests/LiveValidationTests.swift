import Foundation
import PDFKit
import Testing
@testable import SandpaperCore

/// Explicit developer-run validation only; ordinary tests never load a model or download books.
@Suite(.serialized)
struct LiveValidationTests {
    struct Passage: Codable {
        let id: String
        let text: String
        let selection: String
        let focus: String
    }
    static let passages: [Passage] = [
        .init(id: "agreement", text: "After months of negotiations, the agreement finally fell through, leaving both parties back at square one.", selection: "fell through", focus: "Failed agreement; no literal falling or invented reasons."),
        .init(id: "wealth", text: "He was a gentleman of considerable means, though his manners were rather wanting.", selection: "of considerable means", focus: "Financial resources or wealth, not methods."),
        .init(id: "understatement", text: "He was a gentleman of considerable means, though his manners were rather wanting.", selection: "his manners were rather wanting", focus: "Deficient manners; formal understatement, not desire."),
        .init(id: "endorsement", text: "The committee praised his enthusiasm, though they stopped short of endorsing any of his proposals.", selection: "stopped short of", focus: "Withheld endorsement does not prove rejection or private motives."),
        .init(id: "fig-leaf", text: "His apology was a fig leaf for his indifference.", selection: "fig leaf", focus: "Superficial concealment; no unsolicited biblical-origin story."),
        .init(id: "plain", text: "She opened the window and put the book on the table.", selection: "opened", focus: "Simple opening, no invented unlocking or extra significance."),
        .init(id: "wilde-1895", text: "The truth is rarely pure and never simple.", selection: "rarely pure and never simple", focus: "Complexity of truth, no plot knowledge. Wilde, The Importance of Being Earnest, 1895."),
        .init(id: "woolf-1925", text: "Mrs. Dalloway said she would buy the flowers herself. For Lucy had her work cut out for her.", selection: "had her work cut out for her", focus: "Large/demanding task. Woolf, Mrs. Dalloway, 1925, opening."),
        .init(id: "orwell-1946", text: "But if thought corrupts language, language can also corrupt thought.", selection: "corrupt thought", focus: "Language distorting thinking; preserve reciprocal direction. Orwell, Politics and the English Language, 1946."),
        .init(id: "sarcasm", text: "Great, another mandatory meeting that could have been an email. Love that for us.", selection: "Love that for us", focus: "Likely ironic disapproval; no invented details."),
        .init(id: "sealioning", text: "He said he was 'just asking questions', but the replies read it as sealioning.", selection: "sealioning", focus: "Persistent superficially civil demands; accusation does not prove intent."),
        .init(id: "ambiguity", text: "She saw the man with the telescope.", selection: "with the telescope", focus: "Both telescope attachments, no initial definite assertion."),
        .init(id: "powder-figurative", text: "Martin accepted the amendment without comment. Eleanor suspected he was keeping his powder dry until the final vote.", selection: "keeping his powder dry", focus: "Preserve readiness for later action; Eleanor's suspicion is not proven intent."),
        .init(id: "powder-literal", text: "He kept his powder dry by the stove before loading the musket.", selection: "kept his powder dry", focus: "Literal dry gunpowder, no strategic-restraint idiom."),
        .init(id: "almost-convincing", text: "He congratulated her with an enthusiasm that was almost convincing.", selection: "almost convincing", focus: "Suggestion of insincerity; not proof of internal feelings."),
        .init(id: "heldout-cat", text: "She let the cat out of the bag, and it ran under the sofa.", selection: "let the cat out of the bag", focus: "Literal animal released, not disclosure of a secret."),
        .init(id: "heldout-wanting", text: "The explanation was wanting, though everyone wanted it to be true.", selection: "wanting", focus: "Deficient, distinct from desired in the same sentence."),
        .init(id: "heldout-circumstantial", text: "Her evidence was merely circumstantial; it did not establish causation.", selection: "circumstantial", focus: "Indirect evidence, not proof of causation; no invented legal outcome."),
        .init(id: "heldout-metaphor", text: "His courtesy was a locked gate. Every polite answer left her outside the real discussion.", selection: "a locked gate", focus: "Metaphorical exclusion; qualify intent, no actual gate."),
        .init(id: "new-literal-ice", text: "The ice broke under the weight of the sled, and both men scrambled onto the bank.", selection: "ice broke", focus: "Physical ice, not easing social tension."),
        .init(id: "new-duck", text: "She watched her duck.", selection: "her duck", focus: "Her bird or a woman lowering her head; genuinely unresolved."),
        .init(id: "new-litotes", text: "His reply was not without merit, though it left the central objection untouched.", selection: "not without merit", focus: "Qualified praise: some merit, but no answer to the main objection."),
        .init(id: "new-restive", text: "The horse grew restive as the crowd pressed closer.", selection: "restive", focus: "Restless or difficult to control, not restful."),
        .init(id: "new-heavy-lifting", text: "That single assumption is doing a lot of heavy lifting in your argument.", selection: "doing a lot of heavy lifting", focus: "Figurative dependence on the assumption; not physical work or necessarily valid reasoning.")
    ]

    struct Observation: Encodable {
        let id: String
        let iteration: Int
        let passage: String
        let selection: String
        let reviewFocus: String
        let dictionarySeconds: Double
        let dictionaryArticleBytes: Int
        let seconds: Double
        let firstMeaningSeconds: Double?
        let metrics: InferenceMetrics?
        let answer: Explanation?
        let error: String?
    }

    @Test(.enabled(if: ProcessInfo.processInfo.environment["SANDPAPER_LIVE_MODE"] == "ai"))
    func evaluateExplicitExplanations() async throws {
        let env = ProcessInfo.processInfo.environment
        let port = Int(env["SANDPAPER_LIVE_PORT"] ?? "8087")!
        let engine = LlamaLocalEngine(configuration: try LlamaServerConfiguration(port: port, chatFormat: .gemma3))
        let dictionary = MacOSDictionary()
        let ids = Set((env["SANDPAPER_LIVE_CASES"] ?? "").split(separator: ",").map(String.init))
        let cases = Self.passages.filter { ids.isEmpty || ids.contains($0.id) }
        let iterations = Int(env["SANDPAPER_LIVE_REPEAT"] ?? "1")!
        var rows: [Observation] = []
        for iteration in 1...iterations {
            for item in cases {
                let p = try AnalysisPassage(documentID: UUID(), revision: "validation-1", resource: .text, text: item.text)
                let anchor = try p.anchor(for: (item.text as NSString).range(of: item.selection))
                let lookupStart = ContinuousClock.now
                let entries = try await dictionary.lookup(item.selection)
                let dictionarySeconds = elapsed(lookupStart)
                let evidence = env["SANDPAPER_LIVE_EVIDENCE"] == "1" ? try DictionaryEvidence.relevantExcerpts(from: entries) : []
                let request = try ExplanationRequest(passage: p, selection: anchor, dictionaryEvidence: evidence)
                let start = ContinuousClock.now
                let preview = Preview(start: start)
                var answer: Explanation?, failure: String?
                do { answer = try await engine.explain(request) { await preview.observe($0) } }
                catch { failure = String(describing: error) }
                rows.append(Observation(id: item.id, iteration: iteration, passage: item.text, selection: item.selection,
                    reviewFocus: item.focus, dictionarySeconds: dictionarySeconds,
                    dictionaryArticleBytes: entries.reduce(0) { $0 + $1.text.utf8.count }, seconds: elapsed(start),
                    firstMeaningSeconds: await preview.first, metrics: await engine.lastMetrics, answer: answer, error: failure))
                try write(rows, promptVersion: LlamaLocalEngine.promptVersion, to: env["SANDPAPER_LIVE_OUTPUT"]!)
            }
        }
    }

    struct DocumentObservation: Encodable {
        let file: String
        let resources: Int
        let characters: Int
        let navigationItems: Int
        let importSeconds: Double
        let readAllSeconds: Double
        let lookupSeconds: Double
        let saveSeconds: Double
        let reopenAndReturnSeconds: Double
        let dictionaryEntries: Int
        let aiMeaning: String?
    }

    @Test(.enabled(if: ["documents", "workflow"].contains(ProcessInfo.processInfo.environment["SANDPAPER_LIVE_MODE"] ?? "")))
    func realDocumentsRoundTrip() async throws {
        let env = ProcessInfo.processInfo.environment
        let assets = URL(fileURLWithPath: env["SANDPAPER_LIVE_ASSETS"]!)
        let root = env["SANDPAPER_LIVE_LIBRARY"].map { URL(fileURLWithPath: $0) }
            ?? FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { if env["SANDPAPER_LIVE_LIBRARY"] == nil { try? FileManager.default.removeItem(at: root) } }
        struct Asset: Decodable { let file: String; let term: String }
        let files = try JSONDecoder().decode([Asset].self, from: Data(contentsOf: assets.appendingPathComponent("assets.json")))
        var records: [DocumentObservation] = []
        var resume: [ResumeRecord] = []
        for file in files {
            let location = root.appendingPathComponent(file.file)
            let library = try DocumentLibrary(directory: location)
            let start = ContinuousClock.now
            let doc = try await library.importDocument(from: assets.appendingPathComponent(file.file)).document
            let imported = elapsed(start)
            let engine: any LocalAnalysisEngine = env["SANDPAPER_LIVE_MODE"] == "workflow"
                ? LlamaLocalEngine(configuration: try LlamaServerConfiguration(port: Int(env["SANDPAPER_LIVE_PORT"]!)!, chatFormat: .gemma3))
                : UnconfiguredLocalEngine()
            let session = ReaderSession(library: library, engine: engine)
            let readStart = ContinuousClock.now
            let manifest = try await session.open(documentID: doc.id)
            var found: (SourceResource, NSRange)?, total = 0
            for resource in manifest.resources {
                let content = try await session.content(for: resource.source)
                let text = content.text
                total += text.utf16.count
                #expect(!text.contains("\u{FFFD}"))
                let range = (text as NSString).range(of: file.term, options: .caseInsensitive)
                if found == nil, range.location != NSNotFound { found = (resource.source, range) }
            }
            for item in manifest.navigation {
                let target = try await session.navigate(to: item)
                #expect(target.resolution != .missing)
            }
            let readSeconds = elapsed(readStart)
            let (resource, range) = try #require(found)
            let selection = try await session.select(documentID: doc.id, resource: resource, range: range)
            if case .pdfPage(let index) = resource {
                let pdf = try #require(PDFDocument(url: manifest.fileURL))
                let native = try #require(pdf.page(at: index)?.selection(for: range))
                #expect(try PDFSelectionBridge.ranges(for: native, in: pdf) == [PDFTextRange(pageIndex: index, range: range)])
            }
            let lookupStart = ContinuousClock.now
            let dictionary = try await session.lookup(selectionID: selection.id)
            let lookupSeconds = elapsed(lookupStart)
            #expect(!dictionary.isEmpty)
            var answer: Explanation?
            if env["SANDPAPER_LIVE_MODE"] == "workflow" {
                answer = try await session.explain(selectionID: selection.id)
            }
            let saveStart = ContinuousClock.now
            let meaning: VocabularyMeaningChoice
            if answer != nil { meaning = .aiInterpretation() }
            else {
                let entry = try #require(dictionary.first)
                let excerpt = String(entry.text.prefix(500))
                meaning = .dictionary(entryID: entry.id, range: NSRange(location: 0, length: excerpt.utf16.count))
            }
            let saved = try await session.save(selectionID: selection.id, meaning: meaning, notes: "Live round-trip")
            let bookmark = try await session.bookmark(documentID: doc.id, resource: resource, range: range, title: file.term)
            try await session.recordProgress(documentID: doc.id, resource: resource, visibleRange: range, progression: 0.5)
            let saveSeconds = elapsed(saveStart)
            resume.append(ResumeRecord(file: file.file, occurrenceID: saved.id, rangeLocation: range.location, rangeLength: range.length, quote: selection.anchor.quote))
            await session.clearSelection()
            let reopenStart = ContinuousClock.now
            let reopened = try DocumentLibrary(directory: location)
            let occurrence = try await reopened.occurrence(id: saved.id)
            #expect(occurrence.explanation == answer)
            #expect(occurrence.sourcePassage == selection.request.passage)
            #expect(try await reopened.vocabularyEntry(id: saved.vocabularyID).notes == "Live round-trip")
            #expect(try await reopened.readingPosition(for: doc.id)?.progression == 0.5)
            let fresh = ReaderSession(library: reopened)
            #expect(try await fresh.navigate(to: occurrence).resolution == .exact(range))
            #expect(try await fresh.navigate(to: bookmark.position).resolution == .exact(range))
            records.append(DocumentObservation(file: file.file, resources: manifest.resources.count, characters: total,
                navigationItems: manifest.navigation.count, importSeconds: imported, readAllSeconds: readSeconds,
                lookupSeconds: lookupSeconds, saveSeconds: saveSeconds, reopenAndReturnSeconds: elapsed(reopenStart),
                dictionaryEntries: dictionary.count, aiMeaning: answer?.meaning))
            let encoder = JSONEncoder(); encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            try encoder.encode(records).write(to: URL(fileURLWithPath: env["SANDPAPER_LIVE_OUTPUT"]!), options: .atomic)
        }
        try JSONEncoder().encode(resume).write(to: root.appendingPathComponent("resume.json"), options: .atomic)
    }

    @Test(.enabled(if: ProcessInfo.processInfo.environment["SANDPAPER_LIVE_MODE"] == "cancel"))
    func realCancellationAndRecovery() async throws {
        let env = ProcessInfo.processInfo.environment
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let file = root.appendingPathComponent("cancel.txt")
        try Data(Self.passages[2].text.utf8).write(to: file)
        let library = try DocumentLibrary(directory: root.appendingPathComponent("Library"))
        let doc = try await library.importDocument(from: file).document
        let engine = LlamaLocalEngine(configuration: try LlamaServerConfiguration(port: Int(env["SANDPAPER_LIVE_PORT"]!)!, chatFormat: .gemma3))
        let session = ReaderSession(library: library, engine: engine)
        _ = try await session.open(documentID: doc.id)
        let text = try await session.content(for: .text).text
        let range = (text as NSString).range(of: "his manners were rather wanting")
        let selection = try await session.select(documentID: doc.id, resource: .text, range: range)
        let preview = Preview(start: .now)
        let request = Task { try await session.explain(selectionID: selection.id) { await preview.observe($0) } }
        defer { request.cancel() }
        let deadline = ContinuousClock.now.advanced(by: .seconds(30))
        while await preview.first == nil, ContinuousClock.now < deadline { try await Task.sleep(for: .milliseconds(20)) }
        #expect(await preview.first != nil)
        let dictionaryStart = ContinuousClock.now
        _ = try await session.lookup(selectionID: selection.id)
        let lookup = elapsed(dictionaryStart)
        let start = ContinuousClock.now
        await session.clearSelection()
        let clear = elapsed(start)
        do { _ = try await request.value; Issue.record("Cancelled model request completed") }
        catch is CancellationError {}
        let cancelled = elapsed(start)
        let next = try await session.select(documentID: doc.id, resource: .text, range: range)
        let recoveryStart = ContinuousClock.now
        let answer = try await session.explain(selectionID: next.id)
        struct Result: Encodable {
            let dictionaryWhileGeneratingSeconds: Double; let clearSelectionSeconds: Double
            let cancellationAcknowledgedSeconds: Double; let recoverySeconds: Double; let recoveryMeaning: String
        }
        let result = Result(dictionaryWhileGeneratingSeconds: lookup, clearSelectionSeconds: clear,
            cancellationAcknowledgedSeconds: cancelled, recoverySeconds: elapsed(recoveryStart), recoveryMeaning: answer.meaning)
        let encoder = JSONEncoder(); encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        try encoder.encode(result).write(to: URL(fileURLWithPath: env["SANDPAPER_LIVE_OUTPUT"]!), options: .atomic)
    }

    struct ResumeRecord: Codable {
        let file: String; let occurrenceID: UUID; let rangeLocation: Int; let rangeLength: Int; let quote: String
    }

    @Test(.enabled(if: ProcessInfo.processInfo.environment["SANDPAPER_LIVE_MODE"] == "restore"))
    func restoreInFreshProcess() async throws {
        let env = ProcessInfo.processInfo.environment
        let root = URL(fileURLWithPath: env["SANDPAPER_LIVE_LIBRARY"]!)
        let records = try JSONDecoder().decode([ResumeRecord].self, from: Data(contentsOf: root.appendingPathComponent("resume.json")))
        let start = ContinuousClock.now
        for record in records {
            let library = try DocumentLibrary(directory: root.appendingPathComponent(record.file))
            let occurrence = try await library.occurrence(id: record.occurrenceID)
            #expect(occurrence.anchor.quote == record.quote)
            #expect(occurrence.sourcePassage != nil)
            #expect(occurrence.explanation != nil)
            #expect(try await library.vocabularyEntry(id: occurrence.vocabularyID).meaningSource == .aiInterpretation)
            let session = ReaderSession(library: library)
            let target = try await session.navigate(to: occurrence)
            #expect(target.resolution == .exact(NSRange(location: record.rangeLocation, length: record.rangeLength)))
        }
        let output: [String: Double] = ["documents": Double(records.count), "restoreSeconds": elapsed(start)]
        try JSONEncoder().encode(output).write(to: root.appendingPathComponent("restored.json"), options: .atomic)
    }

    static func elapsed(_ start: ContinuousClock.Instant) -> Double {
        let value = start.duration(to: .now).components
        return Double(value.seconds) + Double(value.attoseconds) / 1e18
    }
    private func elapsed(_ start: ContinuousClock.Instant) -> Double { Self.elapsed(start) }
    private func write(_ records: [Observation], promptVersion: String, to path: String) throws {
        struct Report: Encodable { let promptVersion: String; let records: [Observation] }
        let encoder = JSONEncoder(); encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        try encoder.encode(Report(promptVersion: promptVersion, records: records)).write(to: URL(fileURLWithPath: path), options: .atomic)
    }
    private actor Preview {
        let start: ContinuousClock.Instant
        var first: Double?
        init(start: ContinuousClock.Instant) { self.start = start }
        func observe(_ value: String) { if first == nil, !value.isEmpty { first = LiveValidationTests.elapsed(start) } }
    }
}
