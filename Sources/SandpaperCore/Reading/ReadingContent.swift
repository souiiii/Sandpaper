import Foundation
import NaturalLanguage

public enum ReaderError: Error, Equatable, Sendable {
    case invalidDocument
    case lockedPDF
    case unsupportedEncoding
    case resourceTooLarge
    case resourceNotFound
    case unsupportedEPUBLayout
    case noOpenDocument
    case staleSelection
    case explanationNotReady
    case noSelectableText
}

public struct ReadingResource: Equatable, Sendable {
    public let source: SourceResource
    public let title: String
}

public struct ReadingNavigationItem: Equatable, Sendable {
    public let title: String
    public let resource: SourceResource
    public let fragment: String?
    public let depth: Int
}

public struct ReadingDocument: Sendable {
    public let document: LibraryDocument
    /// PDF frontends render this managed file directly with PDFKit; never rewrite it.
    public let fileURL: URL
    public let resources: [ReadingResource]
    public let navigation: [ReadingNavigationItem]
}

public enum ReadingBlockKind: Equatable, Sendable {
    case paragraph, heading(level: Int), quotation, listItem, code
}

public struct ReadingBlock: Equatable, Sendable {
    public let range: NSRange
    public let kind: ReadingBlockKind
}

public struct ReadingImage: Equatable, Sendable {
    public let utf16Offset: Int
    public let archivePath: String?
    public let alternativeText: String
}

/// Render this attributed text for reflowable formats. Its characters ARE the canonical text;
/// offsets into original Markdown/XHTML markup must never be used as selection offsets.
public struct ReadingContent: Sendable {
    public let documentID: UUID
    public let revision: String
    public let resource: SourceResource
    public let attributedText: AttributedString
    public let blocks: [ReadingBlock]
    public let images: [ReadingImage]
    public let fragmentOffsets: [String: Int]
    public var text: String { String(attributedText.characters) }

    public func anchor(for selection: NSRange) throws -> SourceAnchor {
        try SourceAnchor(documentID: documentID, revision: revision, resource: resource, text: text, selection: selection)
    }

    /// Following context stops at the selected sentence, optionally bounded further by the
    /// frontend's visible range. No subsequent resource, paragraph, or book summary is retrieved.
    public func selection(_ range: NSRange, visibleRange: NSRange? = nil) throws -> ReadingSelection {
        let source = text
        let anchor = try anchor(for: range)
        guard anchor.quote.unicodeScalars.contains(where: { $0.value != 0xFFFC && !CharacterSet.whitespacesAndNewlines.contains($0) }) else {
            throw ReaderError.noSelectableText
        }
        guard range.length <= 4_096 else { throw LibraryError.invalidInput("Select at most 4096 UTF-16 units for an explanation.") }
        let selected = Range(range, in: source)!
        let lower = source.index(selected.lowerBound, offsetBy: -1_000, limitedBy: source.startIndex) ?? source.startIndex
        let upperLimit = source.index(selected.upperBound, offsetBy: 1_000, limitedBy: source.endIndex) ?? source.endIndex
        let sentences = NLTokenizer(unit: .sentence)
        sentences.string = source; sentences.setLanguage(.english)
        var upper = max(selected.upperBound, min(upperLimit, sentences.tokenRange(at: source.index(before: selected.upperBound)).upperBound))
        if let paragraphEnd = source.range(of: #"\r?\n[\t \r]*\n"#, options: .regularExpression, range: selected.upperBound..<upper) {
            upper = paragraphEnd.lowerBound
        }
        if let visibleRange {
            guard let visible = Range(visibleRange, in: source), NSRange(visible, in: source) == visibleRange,
                  visible.lowerBound <= selected.lowerBound, visible.upperBound >= selected.upperBound else {
                throw LibraryError.invalidInput("Visible context must contain the selection.")
            }
            upper = min(upper, visible.upperBound)
        }
        let offset = NSRange(source.startIndex..<lower, in: source).length
        let passage = try AnalysisPassage(documentID: documentID, revision: revision, resource: resource,
            resourceOffset: offset, text: String(source[lower..<upper]))
        // Keep full-resource context for navigation, but validate AI against its bounded excerpt.
        let analysisAnchor = try passage.anchor(for: NSRange(location: range.location - offset, length: range.length))
        return ReadingSelection(id: UUID(), anchor: anchor, request: try ExplanationRequest(passage: passage, selection: analysisAnchor))
    }
}

public struct ReadingSelection: Sendable {
    public let id: UUID
    public let anchor: SourceAnchor
    public let request: ExplanationRequest
}
