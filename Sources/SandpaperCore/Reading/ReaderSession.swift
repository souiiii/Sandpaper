import CryptoKit
import Foundation

public enum VocabularyMeaningChoice: Sendable {
    /// The exact user-selected part of a dictionary article, not an inferred contextual sense.
    case dictionary(entryID: String, range: NSRange)
    case personal(String)
    case aiInterpretation(range: NSRange? = nil)
    case existingSense(UUID)
}

public struct ReadingDestination: Sendable {
    public let document: ReadingDocument
    public let content: ReadingContent
    /// nil means a resource-only location, e.g. a bookmark on an image-only PDF page.
    public let resolution: AnchorResolution?
}

/// Backend entry point for one reader window. Selection/dictionary work never probes or starts AI.
/// The frontend owns presentation; call explain only after an explicit user action.
public actor ReaderSession {
    private let library: DocumentLibrary
    private let dictionary: any LocalDictionary
    private let analysis: AnalysisCoordinator
    private var reader: DocumentReader?
    private var opened: ReadingDocument?
    private var generation = UUID()
    private var selectionRequest = UUID()
    private var selected: ReadingSelection?
    private var entries: [DictionaryEntry] = []
    private var completedExplanation: Explanation?
    private var explanationRequest = UUID()

    public init(library: DocumentLibrary, dictionary: any LocalDictionary = MacOSDictionary(),
        engine: any LocalAnalysisEngine = UnconfiguredLocalEngine()) {
        self.library = library; self.dictionary = dictionary
        self.analysis = AnalysisCoordinator(engine: engine)
    }

    @discardableResult
    public func open(documentID: UUID) async throws -> ReadingDocument {
        let token = UUID(); generation = token
        selected = nil; entries = []; completedExplanation = nil; selectionRequest = UUID()
        reader = nil; opened = nil
        await analysis.cancelAll()
        let candidate = try await library.openReader(for: documentID)
        let manifest = try await candidate.manifest()
        try Task.checkCancellation()
        guard generation == token else { throw CancellationError() }
        reader = candidate; opened = manifest
        return manifest
    }

    public func content(for resource: SourceResource) async throws -> ReadingContent {
        guard let reader else { throw ReaderError.noOpenDocument }
        let token = generation
        let value = try await reader.content(for: resource)
        guard generation == token else { throw CancellationError() }
        return value
    }

    public func select(documentID: UUID, resource: SourceResource, range: NSRange, visibleRange: NSRange? = nil) async throws -> ReadingSelection {
        guard opened?.document.id == documentID else { throw ReaderError.staleSelection }
        let token = UUID(); selectionRequest = token
        selected = nil; entries = []; completedExplanation = nil
        await analysis.cancelAll()
        let content = try await content(for: resource)
        guard content.documentID == documentID else { throw ReaderError.staleSelection }
        let selection = try content.selection(range, visibleRange: visibleRange)
        guard selectionRequest == token else { throw CancellationError() }
        selected = selection
        return selection
    }

    public func clearSelection() async {
        _ = invalidateSelection()
        await analysis.cancelAll()
    }

    /// Releases this reader and invalidates work still returning from another actor.
    public func close() async {
        generation = UUID()
        _ = invalidateSelection()
        reader = nil; opened = nil
        await analysis.cancelAll()
    }

    public func epubAsset(at path: String) async throws -> Data {
        guard let reader else { throw ReaderError.noOpenDocument }
        let token = generation
        let bytes = try await reader.epubAsset(at: path)
        guard generation == token else { throw CancellationError() }
        return bytes
    }

    public func lookup(selectionID: UUID) async throws -> [DictionaryEntry] {
        let selection = try requireSelection(selectionID)
        // Sentences and long clauses are valid AI selections, not dictionary headwords.
        guard selection.anchor.quote.utf16.count <= 512 else { entries = []; return [] }
        let result = try await dictionary.lookup(selection.anchor.quote)
        _ = try requireSelection(selectionID)
        entries = result
        return result
    }

    public func explain(selectionID: UUID,
        dictionaryAssistance: Bool = false,
        onUpdate: @escaping @Sendable (String) async -> Void = { _ in }) async throws -> Explanation {
        let selection = try requireSelection(selectionID)
        let token = UUID(); explanationRequest = token
        completedExplanation = nil
        await analysis.cancelAll()
        var evidence: [DictionaryEvidence] = []
        if dictionaryAssistance, selection.anchor.quote.utf16.count <= 512 {
            if entries.isEmpty { _ = try await lookup(selectionID: selectionID) }
            evidence = try DictionaryEvidence.relevantExcerpts(from: entries)
        }
        _ = try requireSelection(selectionID)
        guard explanationRequest == token else { throw CancellationError() }
        let request = try ExplanationRequest(passage: selection.request.passage, selection: selection.request.selection, dictionaryEvidence: evidence)
        let result = try await analysis.explain(request, onUpdate: onUpdate)
        _ = try requireSelection(selectionID)
        guard explanationRequest == token else { throw CancellationError() }
        completedExplanation = result
        return result
    }

    public func save(selectionID: UUID, meaning choice: VocabularyMeaningChoice,
        expression: String? = nil, notes: String? = nil) async throws -> VocabularyOccurrence {
        let selection = try requireSelection(selectionID)
        var expression = expression ?? selection.anchor.quote
        let meaning: String?
        let source: MeaningSource?
        let key: String
        switch choice {
        case .dictionary(let entryID, let range):
            guard let entry = entries.first(where: { $0.id == entryID }) else { throw LibraryError.invalidInput("Look up this selection before choosing a dictionary meaning.") }
            meaning = try excerpt(entry.text, range: range)
            source = .dictionary(provider: entry.provider, entryID: entry.id)
            key = senseKey(namespace: entry.provider, meaning: meaning!)
        case .personal(let text):
            meaning = try checkedMeaning(text); source = .personal
            key = senseKey(namespace: "personal", meaning: meaning!)
        case .aiInterpretation(let range):
            guard let explanation = completedExplanation else { throw ReaderError.explanationNotReady }
            meaning = try excerpt(explanation.meaning, range: range ?? NSRange(location: 0, length: explanation.meaning.utf16.count))
            source = .aiInterpretation; key = senseKey(namespace: "interpretation", meaning: meaning!)
        case .existingSense(let id):
            let entry = try await library.vocabularyEntry(id: id)
            _ = try requireSelection(selectionID)
            expression = entry.expression; meaning = entry.meaning; source = entry.meaningSource; key = entry.senseKey
        }
        return try await library.saveVocabulary(expression: expression, senseKey: key, anchor: selection.anchor,
            explanation: completedExplanation, meaning: meaning, meaningSource: source, notes: notes,
            sourcePassage: selection.request.passage)
    }

    public func recordProgress(documentID: UUID, resource: SourceResource, visibleRange: NSRange? = nil, progression: Double) async throws {
        let content = try await content(for: resource)
        guard content.documentID == documentID else { throw ReaderError.staleSelection }
        let anchor = try visibleRange.map { try content.anchor(for: $0) }
        let position = try ReadingPosition(documentID: content.documentID, revision: content.revision,
            resource: resource, anchor: anchor, progression: progression)
        try await library.saveReadingPosition(position)
    }

    public func bookmark(documentID: UUID, resource: SourceResource, range: NSRange? = nil, title: String) async throws -> Bookmark {
        let content = try await content(for: resource)
        guard content.documentID == documentID else { throw ReaderError.staleSelection }
        let position = try ReadingPosition(documentID: content.documentID, revision: content.revision, resource: resource,
            anchor: range.map { try content.anchor(for: $0) }, progression: 0)
        return try await library.saveBookmark(at: position, title: title)
    }

    public func navigate(to position: ReadingPosition) async throws -> ReadingDestination {
        _ = try ReadingPosition(documentID: position.documentID, revision: position.revision, resource: position.resource,
            anchor: position.anchor, progression: position.progression)
        let manifest: ReadingDocument
        if let opened, opened.document.id == position.documentID { manifest = opened }
        else { manifest = try await open(documentID: position.documentID) }
        let token = generation
        let navigation = invalidateSelection()
        await analysis.cancelAll()
        guard generation == token, selectionRequest == navigation,
              opened?.document.id == position.documentID else { throw CancellationError() }
        let content = try await content(for: position.resource)
        guard content.documentID == position.documentID, generation == token,
              selectionRequest == navigation else { throw CancellationError() }
        let resolution = position.anchor.map { $0.resolve(in: content.text, revision: content.revision) }
        return ReadingDestination(document: manifest, content: content, resolution: resolution)
    }

    public func navigate(to occurrence: VocabularyOccurrence) async throws -> ReadingDestination {
        try await navigate(to: ReadingPosition(documentID: occurrence.anchor.documentID, revision: occurrence.anchor.revision,
            resource: occurrence.anchor.resource, anchor: occurrence.anchor, progression: 0))
    }

    public func navigate(to item: ReadingNavigationItem) async throws -> ReadingDestination {
        guard let opened else { throw ReaderError.noOpenDocument }
        let token = generation
        let navigation = invalidateSelection()
        await analysis.cancelAll()
        guard generation == token, selectionRequest == navigation else { throw CancellationError() }
        let content = try await content(for: item.resource)
        guard generation == token, selectionRequest == navigation else { throw CancellationError() }
        let resolution: AnchorResolution?
        if let fragment = item.fragment {
            if let offset = content.fragmentOffsets[fragment] { resolution = .exact(NSRange(location: offset, length: 0)) }
            else { resolution = .missing }
        } else { resolution = nil }
        return ReadingDestination(document: opened, content: content, resolution: resolution)
    }

    private func requireSelection(_ id: UUID) throws -> ReadingSelection {
        guard let selected, selected.id == id else { throw ReaderError.staleSelection }
        return selected
    }

    private func invalidateSelection() -> UUID {
        selectionRequest = UUID(); explanationRequest = UUID()
        selected = nil; entries = []; completedExplanation = nil
        return selectionRequest
    }

    private func excerpt(_ text: String, range: NSRange) throws -> String {
        guard range.location >= 0, range.length > 0, range.location <= text.utf16.count,
              range.length <= text.utf16.count - range.location, let swiftRange = Range(range, in: text),
              NSRange(swiftRange, in: text) == range, String(text[swiftRange]).utf16.count == range.length else { throw LibraryError.invalidInput("Meaning selection is outside the entry or splits a character.") }
        return try checkedMeaning(String(text[swiftRange]))
    }

    private func checkedMeaning(_ text: String) throws -> String {
        let text = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty, text.utf16.count <= 2_048 else { throw LibraryError.invalidInput("Choose a meaning of 1–2048 UTF-16 units; long explanations remain attached separately.") }
        return text
    }

    private func senseKey(namespace: String, meaning: String) -> String {
        let normalized = meaning.precomposedStringWithCanonicalMapping.split(whereSeparator: \.isWhitespace).joined(separator: " ")
        return "meaning:" + SHA256.hash(data: Data((namespace + "\0" + normalized).utf8)).map { String(format: "%02x", $0) }.joined()
    }
}
