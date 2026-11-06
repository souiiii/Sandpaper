import Foundation

/// Offsets are UTF-16, matching NSString, AppKit text selections, and web DOM text.
/// EPUB adapters must supply an agreed canonical resource text, not rendered HTML.
public struct SourceAnchor: Codable, Equatable, Hashable, Sendable {
    public let documentID: UUID
    public let revision: String
    public let resource: SourceResource
    public let utf16Offset: Int
    public let utf16Length: Int
    public let quote: String
    public let prefix: String
    public let suffix: String

    public init(
        documentID: UUID,
        revision: String,
        resource: SourceResource,
        text: String,
        selection: NSRange,
        resourceOffset: Int = 0
    ) throws {
        guard !revision.isEmpty, resourceOffset >= 0,
              selection.location >= 0, selection.length > 0,
              selection.location <= text.utf16.count,
              selection.length <= text.utf16.count - selection.location,
              resourceOffset <= Int.max - text.utf16.count,
              let range = Range(selection, in: text) else {
            throw LibraryError.invalidInput("Selection is outside the passage or splits a Unicode character.")
        }
        let selectedText = String(text[range])
        // Some Foundation versions round a half-surrogate range to an empty
        // Swift substring instead of returning nil. Require an exact round trip.
        guard selectedText.utf16.count == selection.length, NSRange(range, in: text) == selection else {
            throw LibraryError.invalidInput("Selection splits a Unicode character.")
        }
        switch resource {
        case .pdfPage(let index) where index < 0:
            throw LibraryError.invalidInput("PDF page index must be nonnegative.")
        case .epub(let path) where path.isEmpty:
            throw LibraryError.invalidInput("EPUB resource path must not be empty.")
        default: break
        }
        self.documentID = documentID
        self.revision = revision
        self.resource = resource
        self.utf16Offset = resourceOffset + selection.location
        self.utf16Length = selection.length
        self.quote = selectedText
        self.prefix = String(text[..<range.lowerBound].suffix(48))
        self.suffix = String(text[range.upperBound...].prefix(48))
    }

    /// Resolve against the complete canonical text of this resource. No fuzzy
    /// replacement is attempted: ambiguous matches must be shown as unresolved.
    public func resolve(in text: String, revision currentRevision: String) -> AnchorResolution {
        if revision == currentRevision,
           utf16Offset >= 0, utf16Length > 0,
           utf16Offset <= text.utf16.count,
           utf16Length <= text.utf16.count - utf16Offset,
           let range = Range(NSRange(location: utf16Offset, length: utf16Length), in: text),
           text[range] == quote {
            return .exact(NSRange(range, in: text))
        }
        guard !quote.isEmpty else { return .missing }
        var matches: [(range: NSRange, score: Int)] = []
        var start = text.startIndex
        while start < text.endIndex,
              let range = text.range(of: quote, options: .literal, range: start..<text.endIndex) {
            let before = text[..<range.lowerBound]
            let after = text[range.upperBound...]
            let score = (!prefix.isEmpty && before.hasSuffix(prefix) ? 1 : 0)
                + (!suffix.isEmpty && after.hasPrefix(suffix) ? 1 : 0)
            matches.append((NSRange(range, in: text), score))
            // Account for overlapping occurrences without looping on empty text.
            start = text.index(after: range.lowerBound)
            if matches.count > 1_024 { return .ambiguous }
        }
        guard let best = matches.max(by: { $0.score < $1.score }) else { return .missing }
        if matches.count == 1 { return .relocated(best.range) }
        guard best.score > 0, matches.filter({ $0.score == best.score }).count == 1 else {
            return .ambiguous
        }
        return .relocated(best.range)
    }
}

public enum AnchorResolution: Equatable, Sendable {
    case exact(NSRange)
    case relocated(NSRange)
    case ambiguous
    case missing
}
