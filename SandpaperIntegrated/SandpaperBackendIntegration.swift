import AppKit
import Foundation
import Observation
import SwiftUI
import SandpaperCore

// MARK: - Inline Styling & Semantic Block Models

struct CanonicalInlineStyleRun: Equatable, Sendable {
    let range: NSRange
    let isBold: Bool
    let isItalic: Bool
    let isCode: Bool
}

struct CanonicalImageAttachment: Equatable, Sendable, Identifiable {
    var id: String { "\(utf16Offset)-\(archivePath ?? "inline")" }
    let utf16Offset: Int
    let archivePath: String?
    let alternativeText: String
    let imageData: Data?
}

struct CanonicalBlockItem: Equatable, Sendable, Identifiable {
    let blockID: String
    let text: String
    let resourceRange: NSRange
    let kind: ReadingBlockKind
    let listBullet: String?
    let inlineRuns: [CanonicalInlineStyleRun]
    let attachedImages: [CanonicalImageAttachment]

    var id: String { blockID }

    var isHeading: Bool {
        if case .heading = kind {
            return true
        }
        return false
    }

    init(
        blockID: String,
        text: String,
        resourceRange: NSRange,
        kind: ReadingBlockKind,
        listBullet: String? = nil,
        inlineRuns: [CanonicalInlineStyleRun] = [],
        attachedImages: [CanonicalImageAttachment] = []
    ) {
        self.blockID = blockID
        self.text = text
        self.resourceRange = resourceRange
        self.kind = kind
        self.listBullet = listBullet
        self.inlineRuns = inlineRuns
        self.attachedImages = attachedImages
    }
}

struct ReaderNavigationTarget: Equatable, Sendable, Identifiable {
    let id: String
    let title: String
    let displayTitle: String
    let resource: SourceResource
    let fragment: String?
    let depth: Int
    let headingRangeInResource: NSRange?
    let navigationItem: ReadingNavigationItem?
}

struct CanonicalDocumentPresentation: Sendable {
    let document: LibraryDocument
    let activeResource: SourceResource
    let activeResourceIndex: Int
    let totalResourcesCount: Int
    let resources: [ReadingResource]
    let navigationTargets: [ReaderNavigationTarget]
    let canonicalText: String
    let blocks: [CanonicalBlockItem]
    let blockResourceRanges: [String: NSRange]
    let chapterSectionRanges: [String: NSRange]
    let chapterSectionBlockIDs: [String: String]
    let position: ReadingPosition?
    let restoredBlockID: String?
    let restoredRange: NSRange?
    let restoredIntraBlockFraction: Double
    let isBookmarked: Bool
    let bookmarks: [Bookmark]
    let libraryBook: LibraryBook

    var chapter: BookChapter { libraryBook.sampleChapter }
    var blockRangesByID: [String: NSRange] { blockResourceRanges }
}

// MARK: - Canonical Text, EPUB & UTF-16 Offset Adapter

enum CanonicalDocumentAdapter {
    static func isSupportedFormat(_ format: DocumentFormat) -> Bool {
        switch format {
        case .plainText, .markdown, .epub:
            return true
        case .pdf, .html:
            return false
        }
    }

    static func isSupportedFileURL(_ url: URL) -> Bool {
        let ext = url.pathExtension.lowercased()
        return ext == "txt" || ext == "md" || ext == "markdown" || ext == "epub"
    }

    static func humanReadableError(_ error: any Error, fileName: String? = nil) -> String {
        let prefix = fileName.map { "“\($0)”: " } ?? ""
        if let readerError = error as? ReaderError {
            switch readerError {
            case .unsupportedEPUBLayout:
                return "\(prefix)Fixed-layout (pre-paginated) EPUB books are not supported. Please import a reflowable EPUB."
            case .invalidDocument:
                return "\(prefix)The document archive or structure is malformed or invalid."
            case .unsupportedEncoding:
                return "\(prefix)The text encoding is not supported (expected UTF-8 or UTF-16)."
            case .resourceTooLarge:
                return "\(prefix)The document or chapter exceeds the maximum supported size."
            case .resourceNotFound:
                return "\(prefix)The requested chapter or resource could not be found in the document."
            case .lockedPDF:
                return "\(prefix)Password-protected PDF files are not supported."
            case .noOpenDocument, .staleSelection, .explanationNotReady, .noSelectableText:
                return "\(prefix)The reader session could not complete the requested operation."
            }
        }
        if let libraryError = error as? LibraryError {
            switch libraryError {
            case .unsupportedFormat(let ext):
                return "\(prefix)Unsupported format (\(ext)). Supported formats are EPUB, Markdown, and Plain Text."
            case .invalidInput(let message):
                return "\(prefix)\(message)"
            case .sourceIsNotAFile:
                return "\(prefix)Selected item is not a regular file."
            case .sourceTooLarge:
                return "\(prefix)The file is too large to import."
            case .documentNotFound:
                return "\(prefix)The document record was not found in the library."
            case .documentInTrash:
                return "\(prefix)The document is currently in the Trash."
            case .revisionMismatch:
                return "\(prefix)The document revision has changed on disk."
            case .vocabularyNotFound:
                return "\(prefix)The requested vocabulary entry was not found."
            case .corruptStoredData:
                return "\(prefix)Stored library metadata is corrupted."
            }
        }
        if let workspaceError = error as? WorkspaceError {
            switch workspaceError {
            case .closed:
                return "\(prefix)The reader workspace is closed."
            case .invalidSessionFile:
                return "\(prefix)The saved reader session file is invalid."
            case .tooManyOpenDocuments:
                return "\(prefix)Too many documents are open simultaneously."
            }
        }
        return "\(prefix)\(error.localizedDescription)"
    }

    /// Extracts canonical blocks from `ReadingContent`, preserving the exact canonical text,
    /// inline presentation styles, semantic block kinds, and exact UTF-16 `NSRange` offsets within `content.text`.
    static func extractBlocks(
        from content: ReadingContent,
        format: DocumentFormat,
        imageDataByPath: [String: Data] = [:]
    ) -> [CanonicalBlockItem] {
        let canonicalText = content.text
        let nsText = canonicalText as NSString
        guard nsText.length > 0 else { return [] }

        let runSlices = extractAttributedRunSlices(from: content.attributedText, totalUTF16Length: nsText.length)
        let resolvedBlocks = resolveSemanticBlocks(
            from: content,
            nsText: nsText,
            format: format,
            runSlices: runSlices
        )

        var items: [CanonicalBlockItem] = []
        items.reserveCapacity(resolvedBlocks.count)

        for (idx, rawBlock) in resolvedBlocks.enumerated() {
            guard rawBlock.range.location >= 0,
                  rawBlock.range.length > 0,
                  NSMaxRange(rawBlock.range) <= nsText.length else {
                continue
            }
            let blockID = "p\(idx + 1)"
            let text = nsText.substring(with: rawBlock.range)
            let inlineRuns = buildInlineRuns(for: rawBlock.range, from: runSlices)
            let blockImages = content.images.compactMap { img -> CanonicalImageAttachment? in
                guard NSLocationInRange(img.utf16Offset, rawBlock.range) else { return nil }
                let data = img.archivePath.flatMap { imageDataByPath[$0] }
                return CanonicalImageAttachment(
                    utf16Offset: img.utf16Offset - rawBlock.range.location,
                    archivePath: img.archivePath,
                    alternativeText: img.alternativeText,
                    imageData: data
                )
            }

            items.append(
                CanonicalBlockItem(
                    blockID: blockID,
                    text: text,
                    resourceRange: rawBlock.range,
                    kind: rawBlock.kind,
                    listBullet: rawBlock.listBullet,
                    inlineRuns: inlineRuns,
                    attachedImages: blockImages
                )
            )
        }

        return items
    }

    private struct AttributedRunSlice {
        let range: NSRange
        let isBold: Bool
        let isItalic: Bool
        let isCode: Bool
        let blockKindHint: ReadingBlockKind?
        let listBulletHint: String?
    }

    private struct ResolvedBlockSpec {
        let range: NSRange
        let kind: ReadingBlockKind
        let listBullet: String?
    }

    private static func extractAttributedRunSlices(
        from attributed: AttributedString,
        totalUTF16Length: Int
    ) -> [AttributedRunSlice] {
        var slices: [AttributedRunSlice] = []
        var utf16Cursor = 0

        for run in attributed.runs {
            let segmentString = String(attributed[run.range].characters)
            let len = (segmentString as NSString).length
            guard len > 0 else { continue }
            let clampedLen = min(len, max(0, totalUTF16Length - utf16Cursor))
            guard clampedLen > 0 else { break }

            let nsRange = NSRange(location: utf16Cursor, length: clampedLen)
            utf16Cursor += clampedLen

            let inlineIntent = run.inlinePresentationIntent ?? []
            let isBold = inlineIntent.contains(.stronglyEmphasized)
            let isItalic = inlineIntent.contains(.emphasized)
            var isCode = inlineIntent.contains(.code)

            var kindHint: ReadingBlockKind? = nil
            var listBullet: String? = nil

            if let components = run.presentationIntent?.components {
                for comp in components {
                    switch comp.kind {
                    case .header(let level):
                        kindHint = .heading(level: level)
                    case .blockQuote:
                        if kindHint == nil { kindHint = .quotation }
                    case .codeBlock:
                        kindHint = .code
                        isCode = true
                    case .listItem(let ordinal):
                        if kindHint == nil { kindHint = .listItem }
                        if listBullet == nil {
                            let isOrdered = components.contains {
                                if case .orderedList = $0.kind { return true }
                                return false
                            }
                            listBullet = isOrdered ? "\(ordinal)." : "•"
                        }
                    default:
                        break
                    }
                }
            }

            slices.append(
                AttributedRunSlice(
                    range: nsRange,
                    isBold: isBold,
                    isItalic: isItalic,
                    isCode: isCode,
                    blockKindHint: kindHint,
                    listBulletHint: listBullet
                )
            )
        }

        return slices
    }

    private static func buildInlineRuns(
        for blockRange: NSRange,
        from slices: [AttributedRunSlice]
    ) -> [CanonicalInlineStyleRun] {
        var result: [CanonicalInlineStyleRun] = []
        for slice in slices {
            let intersection = NSIntersectionRange(blockRange, slice.range)
            guard intersection.length > 0 else { continue }
            guard slice.isBold || slice.isItalic || slice.isCode else { continue }
            let localRange = NSRange(
                location: intersection.location - blockRange.location,
                length: intersection.length
            )
            if let last = result.last,
               NSMaxRange(last.range) == localRange.location,
               last.isBold == slice.isBold,
               last.isItalic == slice.isItalic,
               last.isCode == slice.isCode {
                result[result.count - 1] = CanonicalInlineStyleRun(
                    range: NSRange(location: last.range.location, length: last.range.length + localRange.length),
                    isBold: last.isBold,
                    isItalic: last.isItalic,
                    isCode: last.isCode
                )
            } else {
                result.append(
                    CanonicalInlineStyleRun(
                        range: localRange,
                        isBold: slice.isBold,
                        isItalic: slice.isItalic,
                        isCode: slice.isCode
                    )
                )
            }
        }
        return result
    }

    /// Resolves non-overlapping blocks covering all content in `nsText`, handling nested EPUB tags
    /// (such as `<blockquote><p>...</p></blockquote>`) and Markdown `presentationIntent` hints.
    private static func resolveSemanticBlocks(
        from content: ReadingContent,
        nsText: NSString,
        format: DocumentFormat,
        runSlices: [AttributedRunSlice]
    ) -> [ResolvedBlockSpec] {
        let paragraphRanges = splitByParagraphBoundaries(in: nsText)
        guard !paragraphRanges.isEmpty else { return [] }

        return paragraphRanges.map { paraRange in
            // 1. Check explicit ReadingBlocks from content.blocks that overlap this paragraph range
            let overlappingBlocks = content.blocks.filter {
                NSIntersectionRange($0.range, paraRange).length > 0
            }

            var resolvedKind: ReadingBlockKind? = nil
            for b in overlappingBlocks {
                switch b.kind {
                case .heading(let level):
                    resolvedKind = .heading(level: level)
                case .code:
                    if resolvedKind == nil { resolvedKind = .code }
                case .quotation:
                    if resolvedKind == nil { resolvedKind = .quotation }
                case .listItem:
                    if resolvedKind == nil { resolvedKind = .listItem }
                case .paragraph:
                    break
                }
            }

            // 2. Check presentationIntent hints from AttributedString runs (for Markdown blockquotes, lists, code)
            var listBullet: String? = nil
            for slice in runSlices {
                guard NSIntersectionRange(slice.range, paraRange).length > 0 else { continue }
                if resolvedKind == nil, let hint = slice.blockKindHint {
                    resolvedKind = hint
                }
                if listBullet == nil, let bullet = slice.listBulletHint {
                    listBullet = bullet
                }
            }

            let finalKind = resolvedKind ?? overlappingBlocks.first?.kind ?? .paragraph
            if finalKind == .listItem && listBullet == nil {
                listBullet = "•"
            }

            return ResolvedBlockSpec(
                range: paraRange,
                kind: finalKind,
                listBullet: listBullet
            )
        }
    }

    private static func splitByParagraphBoundaries(in nsText: NSString) -> [NSRange] {
        guard nsText.length > 0 else { return [] }
        let fullRange = NSRange(location: 0, length: nsText.length)
        let doubleNewlineRegex = try? NSRegularExpression(pattern: #"\r?\n[\t \r]*\r?\n"#)
        let matches = doubleNewlineRegex?.matches(in: nsText as String, range: fullRange) ?? []

        let rawRanges: [NSRange]
        if !matches.isEmpty {
            rawRanges = rangesBetweenMatches(matches, totalLength: nsText.length)
        } else {
            rawRanges = [fullRange]
        }

        var trimmedRanges: [NSRange] = []
        for raw in rawRanges {
            if let trimmed = trimOuterNewlines(in: raw, within: nsText),
               containsRenderableContent(in: trimmed, within: nsText) {
                trimmedRanges.append(trimmed)
            }
        }

        if trimmedRanges.isEmpty, containsRenderableContent(in: fullRange, within: nsText) {
            trimmedRanges = [fullRange]
        }

        return trimmedRanges
    }

    private static func rangesBetweenMatches(_ matches: [NSTextCheckingResult], totalLength: Int) -> [NSRange] {
        var ranges: [NSRange] = []
        var cursor = 0
        for match in matches {
            let matchRange = match.range
            if matchRange.location > cursor {
                ranges.append(NSRange(location: cursor, length: matchRange.location - cursor))
            }
            cursor = NSMaxRange(matchRange)
        }
        if cursor < totalLength {
            ranges.append(NSRange(location: cursor, length: totalLength - cursor))
        }
        return ranges
    }

    private static func trimOuterNewlines(in range: NSRange, within nsText: NSString) -> NSRange? {
        guard range.location >= 0, range.length > 0, NSMaxRange(range) <= nsText.length else {
            return nil
        }
        var start = range.location
        var end = NSMaxRange(range)

        while start < end {
            let ch = nsText.character(at: start)
            if ch == 0x0A || ch == 0x0D {
                start += 1
            } else {
                break
            }
        }

        while end > start {
            let ch = nsText.character(at: end - 1)
            if ch == 0x0A || ch == 0x0D {
                end -= 1
            } else {
                break
            }
        }

        guard end > start else { return nil }
        return NSRange(location: start, length: end - start)
    }

    private static func containsRenderableContent(in range: NSRange, within nsText: NSString) -> Bool {
        let sub = nsText.substring(with: range)
        return sub.unicodeScalars.contains { scalar in
            scalar.value == 0xFFFC || !CharacterSet.whitespacesAndNewlines.contains(scalar)
        }
    }

    /// Maps a local or multi-block `ReaderTextSelection` to its exact UTF-16 `NSRange` in `content.text`.
    static func canonicalUTF16Range(
        for selection: ReaderTextSelection,
        in blockResourceRanges: [String: NSRange]
    ) -> NSRange? {
        if let existing = selection.canonicalUTF16Range {
            return existing
        }

        var minUTF16: Int?
        var maxUTF16: Int?

        for (blockID, blockSel) in selection.blockSelections {
            guard blockSel.nsRange.length > 0,
                  let resourceRange = blockResourceRanges[blockID] else {
                continue
            }
            let start = resourceRange.location + blockSel.nsRange.location
            let end = resourceRange.location + NSMaxRange(blockSel.nsRange)
            minUTF16 = minUTF16.map { min($0, start) } ?? start
            maxUTF16 = maxUTF16.map { max($0, end) } ?? end
        }

        if let lo = minUTF16, let hi = maxUTF16, hi > lo {
            return NSRange(location: lo, length: hi - lo)
        }

        if let resourceRange = blockResourceRanges[selection.blockID],
           selection.nsRange.length > 0 {
            return NSRange(
                location: resourceRange.location + selection.nsRange.location,
                length: selection.nsRange.length
            )
        }

        return nil
    }

    static func canonicalUTF16Range(
        for selection: ReaderTextSelection,
        in presentation: CanonicalDocumentPresentation
    ) -> NSRange? {
        canonicalUTF16Range(for: selection, in: presentation.blockResourceRanges)
    }

    /// Resolves a saved `ReadingPosition` or `AnchorResolution` against `ReadingContent` and returns
    /// the matching block ID, UTF-16 range, and intra-block fraction `[0, 1]` for precise restoration.
    static func resolveRestoredLocation(
        in blocks: [CanonicalBlockItem],
        content: ReadingContent,
        position: ReadingPosition?,
        resolution: AnchorResolution? = nil
    ) -> (blockID: String?, range: NSRange?, intraBlockFraction: Double) {
        guard !blocks.isEmpty else { return (nil, nil, 0.0) }

        let resolvedAnchor: AnchorResolution?
        if let resolution {
            resolvedAnchor = resolution
        } else if let anchor = position?.anchor, anchor.resource == content.resource {
            resolvedAnchor = anchor.resolve(in: content.text, revision: content.revision)
        } else {
            resolvedAnchor = nil
        }

        if let resolvedAnchor {
            switch resolvedAnchor {
            case .exact(let range), .relocated(let range):
                if let match = blocks.first(where: { NSIntersectionRange($0.resourceRange, range).length > 0 })
                    ?? blocks.first(where: {
                        range.location >= $0.resourceRange.location && range.location <= NSMaxRange($0.resourceRange)
                    })
                    ?? blocks.min(by: {
                        abs($0.resourceRange.location - range.location) < abs($1.resourceRange.location - range.location)
                    }) {
                    let relativeOffset = max(0, min(match.resourceRange.length, range.location - match.resourceRange.location))
                    let intraFraction = match.resourceRange.length > 0
                        ? Double(relativeOffset) / Double(match.resourceRange.length)
                        : 0.0
                    return (match.blockID, range, min(1.0, max(0.0, intraFraction)))
                }
            case .ambiguous, .missing:
                break
            }
        }

        if let position, position.resource == content.resource, position.progression > 0 {
            let totalUTF16 = max(1, (content.text as NSString).length)
            let targetOffset = Int(round(position.progression * Double(max(0, totalUTF16 - 1))))
            if let match = blocks.first(where: {
                targetOffset >= $0.resourceRange.location && targetOffset <= NSMaxRange($0.resourceRange)
            }) ?? blocks.last(where: { $0.resourceRange.location <= targetOffset }) ?? blocks.first {
                let relativeOffset = max(0, min(match.resourceRange.length, targetOffset - match.resourceRange.location))
                let intraFraction = match.resourceRange.length > 0
                    ? Double(relativeOffset) / Double(match.resourceRange.length)
                    : 0.0
                let targetRange = NSRange(
                    location: match.resourceRange.location + relativeOffset,
                    length: min(max(1, match.resourceRange.length - relativeOffset), 64)
                )
                return (
                    match.blockID,
                    safeAnchorRange(for: targetRange, in: content.text) ?? match.resourceRange,
                    min(1.0, max(0.0, intraFraction))
                )
            }
        }

        return (nil, nil, 0.0)
    }

    /// Produces a bounded, valid UTF-16 `NSRange` inside `content.text` suitable for `SourceAnchor`.
    /// Strips `\u{FFFC}` object replacement characters from anchor quotes when possible.
    static func safeAnchorRange(for candidate: NSRange?, in canonicalText: String) -> NSRange? {
        guard let candidate, candidate.location >= 0, candidate.length > 0 else { return nil }
        let nsText = canonicalText as NSString
        guard nsText.length > 0, candidate.location < nsText.length else { return nil }

        let clampedLength = min(candidate.length, nsText.length - candidate.location, 160)
        guard clampedLength > 0 else { return nil }

        let bounded = NSRange(location: candidate.location, length: clampedLength)
        let aligned = nsText.rangeOfComposedCharacterSequences(for: bounded)
        guard aligned.location >= 0,
              aligned.length > 0,
              NSMaxRange(aligned) <= nsText.length,
              let swiftRange = Range(aligned, in: canonicalText),
              NSRange(swiftRange, in: canonicalText) == aligned else {
            return nil
        }

        let quote = String(canonicalText[swiftRange])
        guard quote.unicodeScalars.contains(where: {
            $0.value != 0xFFFC && !CharacterSet.whitespacesAndNewlines.contains($0)
        }) else {
            return nil
        }
        return aligned
    }

    /// Builds navigation targets from `ReadingDocument` spine resources, TOC items, or document headings.
    static func buildNavigationTargets(
        manifest: ReadingDocument,
        activeContent: ReadingContent,
        blocks: [CanonicalBlockItem]
    ) -> [ReaderNavigationTarget] {
        if manifest.document.format == .epub {
            var targets: [ReaderNavigationTarget] = []
            var seenDisplayTitles: Set<String> = []

            if !manifest.navigation.isEmpty {
                for (idx, navItem) in manifest.navigation.enumerated() {
                    let rawTitle = navItem.title.trimmingCharacters(in: .whitespacesAndNewlines)
                    let baseTitle = rawTitle.isEmpty ? "Section \(idx + 1)" : rawTitle
                    let indentPrefix = navItem.depth > 0 ? String(repeating: "  ", count: min(navItem.depth, 3)) : ""
                    var displayTitle = indentPrefix + baseTitle
                    if seenDisplayTitles.contains(displayTitle) {
                        displayTitle = "\(displayTitle) (\(idx + 1))"
                    }
                    seenDisplayTitles.insert(displayTitle)

                    var headingRange: NSRange? = nil
                    if navItem.resource == activeContent.resource,
                       let frag = navItem.fragment,
                       let offset = activeContent.fragmentOffsets[frag] {
                        headingRange = NSRange(location: offset, length: 0)
                    }

                    targets.append(
                        ReaderNavigationTarget(
                            id: "epub-nav-\(idx)-\(displayTitle)",
                            title: baseTitle,
                            displayTitle: displayTitle,
                            resource: navItem.resource,
                            fragment: navItem.fragment,
                            depth: navItem.depth,
                            headingRangeInResource: headingRange,
                            navigationItem: navItem
                        )
                    )
                }
            }

            // Ensure every spine resource is reachable even if omitted from TOC
            for (idx, res) in manifest.resources.enumerated() {
                let alreadyCovered = targets.contains { $0.resource == res.source && $0.fragment == nil }
                    || targets.contains { $0.resource == res.source }
                if !alreadyCovered {
                    var fallbackTitle = res.title
                    if res.source == activeContent.resource,
                       let firstHeading = blocks.first(where: { $0.isHeading }) {
                        let cleaned = firstHeading.text
                            .replacingOccurrences(of: "\u{FFFC}", with: "")
                            .trimmingCharacters(in: .whitespacesAndNewlines)
                        if !cleaned.isEmpty {
                            fallbackTitle = cleaned
                        }
                    }
                    if seenDisplayTitles.contains(fallbackTitle) {
                        fallbackTitle = "\(fallbackTitle) (\(idx + 1))"
                    }
                    seenDisplayTitles.insert(fallbackTitle)

                    targets.append(
                        ReaderNavigationTarget(
                            id: "epub-spine-\(idx)",
                            title: fallbackTitle,
                            displayTitle: fallbackTitle,
                            resource: res.source,
                            fragment: nil,
                            depth: 0,
                            headingRangeInResource: nil,
                            navigationItem: nil
                        )
                    )
                }
            }

            return targets
        }

        // Plain Text & Markdown: build navigation from real document headings if present
        var headingTargets: [ReaderNavigationTarget] = []
        var seenTitles: Set<String> = []
        for (idx, item) in blocks.enumerated() {
            if case .heading(let level) = item.kind {
                let cleanTitle = item.text
                    .replacingOccurrences(of: "\u{FFFC}", with: "")
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                    .components(separatedBy: .newlines)
                    .first ?? item.text
                guard !cleanTitle.isEmpty else { continue }
                var displayTitle = cleanTitle
                if seenTitles.contains(displayTitle) {
                    displayTitle = "\(cleanTitle) (\(idx + 1))"
                }
                seenTitles.insert(displayTitle)
                headingTargets.append(
                    ReaderNavigationTarget(
                        id: "heading-\(item.blockID)",
                        title: cleanTitle,
                        displayTitle: displayTitle,
                        resource: activeContent.resource,
                        fragment: nil,
                        depth: max(0, level - 1),
                        headingRangeInResource: item.resourceRange,
                        navigationItem: nil
                    )
                )
            }
        }
        return headingTargets
    }

    static func buildPresentation(
        manifest: ReadingDocument,
        content: ReadingContent,
        position: ReadingPosition?,
        resolution: AnchorResolution? = nil,
        bookmarks: [Bookmark],
        imageDataByPath: [String: Data] = [:],
        coverImageData: Data? = nil,
        sortRank: Int
    ) -> CanonicalDocumentPresentation {
        let document = manifest.document
        let blocks = extractBlocks(from: content, format: document.format, imageDataByPath: imageDataByPath)

        var blockResourceRanges: [String: NSRange] = [:]
        for item in blocks {
            blockResourceRanges[item.blockID] = item.resourceRange
        }

        let navTargets = buildNavigationTargets(manifest: manifest, activeContent: content, blocks: blocks)
        var sectionRanges: [String: NSRange] = [:]
        var sectionBlockIDs: [String: String] = [:]

        for target in navTargets {
            if target.resource == content.resource {
                if let range = target.headingRangeInResource {
                    sectionRanges[target.displayTitle] = range
                    if let matchingBlock = blocks.first(where: {
                        NSIntersectionRange($0.resourceRange, range).length > 0
                            || NSLocationInRange(range.location, $0.resourceRange)
                    }) ?? blocks.min(by: {
                        abs($0.resourceRange.location - range.location) < abs($1.resourceRange.location - range.location)
                    }) {
                        sectionBlockIDs[target.displayTitle] = matchingBlock.blockID
                    }
                } else if let firstBlock = blocks.first {
                    sectionRanges[target.displayTitle] = firstBlock.resourceRange
                    sectionBlockIDs[target.displayTitle] = firstBlock.blockID
                }
            }
        }

        let restored = resolveRestoredLocation(
            in: blocks,
            content: content,
            position: position,
            resolution: resolution
        )

        let resourceIndex = manifest.resources.firstIndex(where: { $0.source == content.resource }) ?? 0
        let totalResources = max(1, manifest.resources.count)

        let totalUTF16InResource = max(1, (content.text as NSString).length)
        let resourcePages = max(1, Int(ceil(Double(totalUTF16InResource) / 1400.0)))

        let resourceProgress: Double
        if let position, position.resource == content.resource {
            resourceProgress = min(1.0, max(0.0, position.progression))
        } else if let restoredRange = restored.range {
            resourceProgress = min(1.0, max(0.0, Double(restoredRange.location) / Double(totalUTF16InResource)))
        } else {
            resourceProgress = 0.0
        }

        let overallProgress: Double
        if document.format == .epub && totalResources > 1 {
            let raw = (Double(resourceIndex) + resourceProgress) / Double(totalResources)
            overallProgress = min(1.0, max(0.0, raw))
        } else {
            overallProgress = resourceProgress
        }

        let totalPages: Int
        let currentPage: Int
        if document.format == .epub && totalResources > 1 {
            totalPages = max(totalResources, resourcePages * totalResources)
            currentPage = max(1, min(totalPages, Int(round(overallProgress * Double(max(0, totalPages - 1)))) + 1))
        } else {
            totalPages = resourcePages
            currentPage = max(1, min(totalPages, Int(round(overallProgress * Double(max(0, totalPages - 1)))) + 1))
        }

        // Determine active chapter/section label without inventing artificial labels
        let activeOffset = restored.range?.location ?? 0
        var activeSectionLabel = ""
        if document.format == .epub {
            let matchingTargets = navTargets.filter { $0.resource == content.resource }
            if let firstMatch = matchingTargets.first {
                activeSectionLabel = firstMatch.displayTitle
                for target in matchingTargets {
                    if let r = target.headingRangeInResource, r.location <= activeOffset {
                        activeSectionLabel = target.displayTitle
                    }
                }
            } else {
                activeSectionLabel = manifest.resources[resourceIndex].title
            }
        } else if !navTargets.isEmpty {
            activeSectionLabel = navTargets[0].displayTitle
            for target in navTargets {
                if let r = target.headingRangeInResource, r.location <= activeOffset {
                    activeSectionLabel = target.displayTitle
                }
            }
        }

        let availableChapters = navTargets.map(\.displayTitle)

        // Previous / Next navigation items:
        // For EPUB with multiple spine resources, navigate across spine chapters or TOC targets.
        // For Markdown/TXT with headings, navigate across headings.
        let prevNav: ChapterNavigationItem?
        let nextNav: ChapterNavigationItem?
        if document.format == .epub && totalResources > 1 {
            let spineTargets: [String] = manifest.resources.map { res in
                navTargets.first(where: { $0.resource == res.source })?.displayTitle ?? res.title
            }
            if resourceIndex > 0 {
                prevNav = ChapterNavigationItem(title: spineTargets[resourceIndex - 1])
            } else {
                prevNav = nil
            }
            if resourceIndex + 1 < spineTargets.count {
                nextNav = ChapterNavigationItem(title: spineTargets[resourceIndex + 1])
            } else {
                nextNav = nil
            }
        } else if availableChapters.count > 1,
                  let currentIdx = availableChapters.firstIndex(of: activeSectionLabel) {
            prevNav = currentIdx > 0 ? ChapterNavigationItem(title: availableChapters[currentIdx - 1]) : nil
            nextNav = (currentIdx + 1) < availableChapters.count
                ? ChapterNavigationItem(title: availableChapters[currentIdx + 1])
                : nil
        } else {
            prevNav = nil
            nextNav = nil
        }

        // Build rich ContentBlocks preserving semantic kinds, inline runs, and images
        let contentBlocks: [ContentBlock]
        if blocks.isEmpty {
            contentBlocks = [
                .paragraph(id: "p1", segments: [.plain("")])
            ]
        } else {
            contentBlocks = blocks.map { item in
                .canonicalBlock(item)
            }
        }

        let formatBadge: BookFormatBadge
        let genreTag: String
        let filterGroup: LibraryFilterCategory
        switch document.format {
        case .epub:
            formatBadge = .epub
            genreTag = "EPUB"
            filterGroup = .literature
        case .markdown:
            formatBadge = .md
            genreTag = "Markdown"
            filterGroup = .essays
        case .plainText:
            formatBadge = .txt
            genreTag = "Plain Text"
            filterGroup = .nonfiction
        case .pdf:
            formatBadge = .pdf
            genreTag = "PDF"
            filterGroup = .nonfiction
        case .html:
            formatBadge = .web
            genreTag = "Web"
            filterGroup = .essays
        }

        let currentSectionSummary: String
        if let quote = position?.anchor?.quote
            .replacingOccurrences(of: "\u{FFFC}", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines),
           !quote.isEmpty {
            let singleLine = quote.replacingOccurrences(of: "\n", with: " ")
            let snippet = singleLine.count > 38 ? String(singleLine.prefix(38)) + "…" : singleLine
            if !activeSectionLabel.isEmpty {
                currentSectionSummary = "\(activeSectionLabel.trimmingCharacters(in: .whitespaces)) · “\(snippet)”"
            } else {
                currentSectionSummary = "“\(snippet)”"
            }
        } else if let firstBookmark = bookmarks.first {
            currentSectionSummary = firstBookmark.title
        } else if !activeSectionLabel.isEmpty {
            currentSectionSummary = activeSectionLabel.trimmingCharacters(in: .whitespaces)
        } else {
            currentSectionSummary = "Page \(currentPage) of \(totalPages)"
        }

        let bookChapter = BookChapter(
            id: document.id.uuidString,
            bookTitle: document.title,
            author: "",
            partLabel: "",
            chapterLabel: activeSectionLabel,
            locationTitle: "",
            subtitle: "",
            currentPage: currentPage,
            totalPages: totalPages,
            progress: overallProgress,
            syncStatus: "Saved",
            blocks: contentBlocks,
            previousChapter: prevNav,
            nextChapter: nextNav,
            availableChapters: availableChapters
        )

        let isFinished = overallProgress >= 0.99
        let pct = Int(round(overallProgress * 100))
        let gridMeta: String
        if isFinished {
            gridMeta = "Finished · \(totalPages) \(totalPages == 1 ? "p" : "pp")"
        } else if pct > 0 {
            if document.format == .epub && totalResources > 1 {
                gridMeta = "Ch. \(resourceIndex + 1)/\(totalResources) · \(pct)%"
            } else {
                gridMeta = "\(formatBadge.rawValue) · \(pct)%"
            }
        } else {
            if document.format == .epub && totalResources > 1 {
                gridMeta = "\(totalResources) chapters"
            } else {
                gridMeta = "\(totalPages) \(totalPages == 1 ? "p" : "pp")"
            }
        }

        let progressLabelLeft: String
        if isFinished {
            progressLabelLeft = "Finished"
        } else if document.format == .epub && totalResources > 1 {
            progressLabelLeft = "Ch. \(resourceIndex + 1) of \(totalResources)"
        } else if totalPages > 1 {
            progressLabelLeft = "Page \(currentPage) of \(totalPages)"
        } else {
            progressLabelLeft = formatBadge.rawValue
        }

        let libraryBook = LibraryBook(
            id: document.id.uuidString,
            backendDocumentID: document.id,
            title: document.title,
            author: "",
            genreTag: genreTag,
            filterGroup: filterGroup,
            format: formatBadge,
            coverStyle: .importedDocument(
                title: document.title,
                formatLabel: formatBadge.rawValue,
                isMarkdown: document.format == .markdown,
                coverImageData: coverImageData
            ),
            isOnReadingDesk: true,
            isCurrentlyReading: !isFinished,
            isFinished: isFinished,
            lastReadRelative: relativeTimestamp(from: document.importedAt),
            lastOpenedSortRank: sortRank,
            currentSectionLabel: currentSectionSummary,
            progressLabelLeft: progressLabelLeft,
            progressFraction: overallProgress,
            totalPages: totalPages,
            gridMetadataLine: gridMeta,
            sampleChapter: bookChapter
        )

        return CanonicalDocumentPresentation(
            document: document,
            activeResource: content.resource,
            activeResourceIndex: resourceIndex,
            totalResourcesCount: totalResources,
            resources: manifest.resources,
            navigationTargets: navTargets,
            canonicalText: content.text,
            blocks: blocks,
            blockResourceRanges: blockResourceRanges,
            chapterSectionRanges: sectionRanges,
            chapterSectionBlockIDs: sectionBlockIDs,
            position: position,
            restoredBlockID: restored.blockID,
            restoredRange: restored.range,
            restoredIntraBlockFraction: restored.intraBlockFraction,
            isBookmarked: !bookmarks.isEmpty,
            bookmarks: bookmarks,
            libraryBook: libraryBook
        )
    }

    private static func relativeTimestamp(from date: Date) -> String {
        let elapsed = max(0, Date().timeIntervalSince(date))
        if elapsed < 90 {
            return "Just now"
        } else if elapsed < 3600 {
            return "\(Int(elapsed / 60))m ago"
        } else if elapsed < 86_400 {
            return "\(Int(elapsed / 3600))h ago"
        } else {
            return "\(Int(elapsed / 86_400))d ago"
        }
    }
}

// MARK: - Persistent Backend Store

@Observable
@MainActor
final class SandpaperBackendStore {
    let directory: URL
    let workspace: ReaderWorkspace?
    var initializationError: String? = nil
    var lastErrorMessage: String? = nil
    var documentLoadErrors: [UUID: String] = [:]
    var includeMockDemoBooks: Bool

    var importedBooks: [LibraryBook] = []
    var presentationsByBookID: [String: CanonicalDocumentPresentation] = [:]
    var lastSelectionByBookID: [String: ReadingSelection] = [:]
    var readingFontSize: CGFloat = 20.5
    var isLoaded: Bool = false

    /// Monotonically increasing sequence counter per document to prevent stale async saves
    /// from overwriting newer reading positions.
    private var latestProgressSequenceByDocID: [UUID: UInt64] = [:]
    private var epubCoverCache: [UUID: Data] = [:]

    init(directory: URL? = nil, includeMockDemoBooks: Bool? = nil) {
        let resolvedDirectory = directory ?? Self.defaultLibraryDirectory()
        self.directory = resolvedDirectory
        if let includeMockDemoBooks {
            self.includeMockDemoBooks = includeMockDemoBooks
        } else {
            self.includeMockDemoBooks = ProcessInfo.processInfo.environment["SANDPAPER_INCLUDE_MOCK_BOOKS"] == "1"
        }

        do {
            self.workspace = try ReaderWorkspace(directory: resolvedDirectory)
            self.initializationError = nil
        } catch {
            self.workspace = nil
            self.initializationError = "Unable to initialize Sandpaper Library at “\(resolvedDirectory.path)”: \(CanonicalDocumentAdapter.humanReadableError(error)). Imports and persistence are disabled until storage is accessible."
            self.lastErrorMessage = self.initializationError
        }
    }

    static func defaultLibraryDirectory() -> URL {
        let environment = ProcessInfo.processInfo.environment
        if let path = environment["SANDPAPER_LIBRARY_DIRECTORY"], !path.isEmpty {
            return URL(fileURLWithPath: path, isDirectory: true)
        }
        let appSupport = (try? FileManager.default.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )) ?? URL(fileURLWithPath: NSHomeDirectory()).appendingPathComponent("Library/Application Support", isDirectory: true)
        return appSupport.appendingPathComponent("Sandpaper", isDirectory: true)
    }

    func book(for id: String) -> LibraryBook? {
        importedBooks.first { $0.id == id }
    }

    func presentation(for id: String) -> CanonicalDocumentPresentation? {
        presentationsByBookID[id]
    }

    func presentation(for id: UUID) -> CanonicalDocumentPresentation? {
        presentationsByBookID[id.uuidString]
    }

    func hasBookmarks(for id: UUID) -> Bool {
        guard let presentation = presentationsByBookID[id.uuidString] else { return false }
        return presentation.bookmarks.contains { $0.position.resource == presentation.activeResource }
            || presentation.isBookmarked
    }

    /// Loads all persisted EPUB, TXT, and Markdown documents and their saved reading positions from `DocumentLibrary`.
    func reloadFromBackend() async {
        guard let workspace else {
            isLoaded = true
            return
        }

        do {
            let restorationIssues = try await workspace.restore()
            if !restorationIssues.isEmpty {
                for issue in restorationIssues {
                    documentLoadErrors[issue.documentID] = issue.message
                }
            }
        } catch {
            lastErrorMessage = CanonicalDocumentAdapter.humanReadableError(error)
        }

        if let prefs = try? await workspace.library.readingPreferences() {
            let size = CGFloat(prefs.fontSize)
            if (17.5...25.5).contains(size) {
                readingFontSize = size
            }
        }

        let documents: [LibraryDocument]
        do {
            documents = try await workspace.library.documents(inTrash: false)
        } catch {
            lastErrorMessage = "Failed to load library catalog: \(CanonicalDocumentAdapter.humanReadableError(error))"
            isLoaded = true
            return
        }

        let supported = documents.filter { CanonicalDocumentAdapter.isSupportedFormat($0.format) }
        var loadedBooks: [LibraryBook] = []
        var loadedPresentations: [String: CanonicalDocumentPresentation] = [:]
        var loadFailureMessages: [String] = []

        for (index, doc) in supported.enumerated() {
            do {
                let reader = try await workspace.library.openReader(for: doc.id)
                let manifest = try await reader.manifest()
                let position = try await workspace.library.readingPosition(for: doc.id)

                let targetResource: SourceResource
                if let savedResource = position?.resource,
                   manifest.resources.contains(where: { $0.source == savedResource }) {
                    targetResource = savedResource
                } else if let firstResource = manifest.resources.first?.source {
                    targetResource = firstResource
                } else {
                    throw ReaderError.invalidDocument
                }

                let content = try await reader.content(for: targetResource)
                let bookmarks = (try? await workspace.library.bookmarks(for: doc.id)) ?? []
                let imageMap = await loadEPUBImages(from: reader, content: content, documentID: doc.id)
                let sortRank = -(supported.count - index)

                let presentation = CanonicalDocumentAdapter.buildPresentation(
                    manifest: manifest,
                    content: content,
                    position: position,
                    bookmarks: bookmarks,
                    imageDataByPath: imageMap,
                    coverImageData: epubCoverCache[doc.id],
                    sortRank: sortRank
                )
                loadedBooks.append(presentation.libraryBook)
                loadedPresentations[doc.id.uuidString] = presentation
                documentLoadErrors.removeValue(forKey: doc.id)
            } catch {
                let msg = CanonicalDocumentAdapter.humanReadableError(error, fileName: doc.title)
                documentLoadErrors[doc.id] = msg
                loadFailureMessages.append(msg)
            }
        }

        self.presentationsByBookID = loadedPresentations
        self.importedBooks = loadedBooks
        if !loadFailureMessages.isEmpty {
            self.lastErrorMessage = loadFailureMessages.joined(separator: " ")
        }
        self.isLoaded = true
    }

    /// Imports real EPUB, TXT, and Markdown files into `DocumentLibrary`, validating structure before keeping.
    @discardableResult
    func importFiles(_ urls: [URL]) async -> String {
        if let initializationError {
            lastErrorMessage = initializationError
            return initializationError
        }
        guard let workspace else {
            let msg = "Library workspace is unavailable."
            lastErrorMessage = msg
            return msg
        }
        guard !urls.isEmpty else { return "No files selected." }

        var importedTitles: [String] = []
        var duplicateTitles: [String] = []
        var errorDetails: [String] = []

        for url in urls {
            let ext = url.pathExtension.lowercased()
            if ext == "pdf" {
                errorDetails.append("“\(url.lastPathComponent)”: PDF reading is not yet integrated in this build.")
                continue
            }
            guard CanonicalDocumentAdapter.isSupportedFileURL(url) else {
                errorDetails.append("“\(url.lastPathComponent)”: Unsupported file format. Choose an EPUB (.epub), Markdown (.md), or Plain Text (.txt) file.")
                continue
            }

            let accessedSecurityScope = url.startAccessingSecurityScopedResource()
            defer {
                if accessedSecurityScope {
                    url.stopAccessingSecurityScopedResource()
                }
            }

            do {
                let result = try await workspace.library.importDocument(from: url)
                // Validate that the imported document can be opened and its primary resource decoded
                do {
                    let reader = try await workspace.library.openReader(for: result.document.id)
                    let manifest = try await reader.manifest()
                    guard let firstResource = manifest.resources.first?.source else {
                        throw ReaderError.invalidDocument
                    }
                    _ = try await reader.content(for: firstResource)
                } catch {
                    try? await workspace.library.trashDocument(id: result.document.id)
                    throw error
                }

                if result.alreadyImported {
                    duplicateTitles.append(result.document.title)
                } else {
                    importedTitles.append(result.document.title)
                }
            } catch {
                errorDetails.append(CanonicalDocumentAdapter.humanReadableError(error, fileName: url.lastPathComponent))
            }
        }

        await reloadFromBackend()

        var parts: [String] = []
        if !importedTitles.isEmpty {
            parts.append("Imported \(importedTitles.joined(separator: ", ")) into Sandpaper Library.")
        }
        if !duplicateTitles.isEmpty {
            parts.append("Already in library: \(duplicateTitles.joined(separator: ", ")).")
        }
        if !errorDetails.isEmpty {
            let joinedErrors = errorDetails.joined(separator: " ")
            lastErrorMessage = joinedErrors
            parts.append(joinedErrors)
        } else {
            lastErrorMessage = nil
        }

        return parts.isEmpty ? "Import completed." : parts.joined(separator: " ")
    }

    /// Opens a document in `ReaderWorkspace` / `ReaderSession` and resolves its saved `ReadingPosition`.
    @discardableResult
    func openDocumentInReader(documentID: UUID) async -> CanonicalDocumentPresentation? {
        guard let workspace else { return nil }
        do {
            let workspaceReader = try await workspace.open(documentID: documentID)
            let session = workspaceReader.session
            let manifest = workspaceReader.document
            let savedPosition = try await workspace.library.readingPosition(for: documentID)
                ?? workspaceReader.initialPosition

            let content: ReadingContent
            let resolution: AnchorResolution?
            if let savedPosition,
               manifest.resources.contains(where: { $0.source == savedPosition.resource }) {
                let destination = try await session.navigate(to: savedPosition)
                content = destination.content
                resolution = destination.resolution
            } else if let firstResource = manifest.resources.first?.source {
                content = try await session.content(for: firstResource)
                resolution = nil
            } else {
                throw ReaderError.invalidDocument
            }

            let bookmarks = (try? await workspace.library.bookmarks(for: documentID)) ?? []
            let imageMap = await loadEPUBImages(from: session, content: content, documentID: documentID)
            let existingRank = presentationsByBookID[documentID.uuidString]?.libraryBook.lastOpenedSortRank ?? -100

            let presentation = CanonicalDocumentAdapter.buildPresentation(
                manifest: manifest,
                content: content,
                position: savedPosition,
                resolution: resolution,
                bookmarks: bookmarks,
                imageDataByPath: imageMap,
                coverImageData: epubCoverCache[documentID],
                sortRank: existingRank
            )

            presentationsByBookID[documentID.uuidString] = presentation
            if let idx = importedBooks.firstIndex(where: { $0.id == documentID.uuidString }) {
                importedBooks[idx] = presentation.libraryBook
            } else {
                importedBooks.insert(presentation.libraryBook, at: 0)
            }
            return presentation
        } catch {
            let msg = CanonicalDocumentAdapter.humanReadableError(error)
            documentLoadErrors[documentID] = msg
            lastErrorMessage = msg
            return presentationsByBookID[documentID.uuidString]
        }
    }

    /// Navigates to a chapter or section by its display title or `ReaderNavigationTarget` (supporting EPUB spine & TOC items).
    @discardableResult
    func navigateToChapter(
        documentID: UUID,
        chapterTitle: String
    ) async -> CanonicalDocumentPresentation? {
        guard let workspace else { return nil }
        guard let currentPres = presentationsByBookID[documentID.uuidString] else {
            return await openDocumentInReader(documentID: documentID)
        }

        // Invalidate any in-flight progress saves from the previous chapter
        let nextSeq = (latestProgressSequenceByDocID[documentID] ?? 0) + 1
        latestProgressSequenceByDocID[documentID] = nextSeq

        do {
            let workspaceReader = try await workspace.open(documentID: documentID)
            let session = workspaceReader.session
            let manifest = workspaceReader.document

            let matchedTarget = currentPres.navigationTargets.first {
                $0.displayTitle == chapterTitle || $0.title == chapterTitle
            }
            let matchedResource = matchedTarget?.resource
                ?? manifest.resources.first(where: { $0.title == chapterTitle })?.source

            guard let targetResource = matchedResource else {
                return currentPres
            }

            let content: ReadingContent
            var resolution: AnchorResolution? = nil

            if let navItem = matchedTarget?.navigationItem, manifest.document.format == .epub {
                let destination = try await session.navigate(to: navItem)
                content = destination.content
                resolution = destination.resolution
            } else {
                content = try await session.content(for: targetResource)
                if let frag = matchedTarget?.fragment, let offset = content.fragmentOffsets[frag] {
                    resolution = .exact(NSRange(location: offset, length: 0))
                } else if let headingRange = matchedTarget?.headingRangeInResource {
                    resolution = .exact(headingRange)
                }
            }

            // Determine visible anchor range at the destination
            let blocks = CanonicalDocumentAdapter.extractBlocks(from: content, format: manifest.document.format)
            let restored = CanonicalDocumentAdapter.resolveRestoredLocation(
                in: blocks,
                content: content,
                position: nil,
                resolution: resolution
            )
            let anchorRange = CanonicalDocumentAdapter.safeAnchorRange(
                for: restored.range ?? blocks.first?.resourceRange,
                in: content.text
            )
            let totalUTF16 = max(1, (content.text as NSString).length)
            let resourceProgression: Double
            if let r = restored.range, r.location > 0 {
                resourceProgression = min(1.0, max(0.0, Double(r.location) / Double(totalUTF16)))
            } else {
                resourceProgression = 0.0
            }

            try await session.recordProgress(
                documentID: documentID,
                resource: targetResource,
                visibleRange: anchorRange,
                progression: resourceProgression
            )

            let updatedPosition = try await workspace.library.readingPosition(for: documentID)
            let bookmarks = (try? await workspace.library.bookmarks(for: documentID)) ?? []
            let imageMap = await loadEPUBImages(from: session, content: content, documentID: documentID)

            let updatedPresentation = CanonicalDocumentAdapter.buildPresentation(
                manifest: manifest,
                content: content,
                position: updatedPosition,
                resolution: resolution,
                bookmarks: bookmarks,
                imageDataByPath: imageMap,
                coverImageData: epubCoverCache[documentID],
                sortRank: currentPres.libraryBook.lastOpenedSortRank
            )

            presentationsByBookID[documentID.uuidString] = updatedPresentation
            if let idx = importedBooks.firstIndex(where: { $0.id == documentID.uuidString }) {
                importedBooks[idx] = updatedPresentation.libraryBook
            }
            return updatedPresentation
        } catch {
            lastErrorMessage = CanonicalDocumentAdapter.humanReadableError(error)
            return currentPres
        }
    }

    /// Registers a canonical UTF-16 text selection with the backend `ReaderSession` for the active resource.
    @discardableResult
    func selectText(
        documentID: UUID,
        resource: SourceResource? = nil,
        range: NSRange,
        visibleRange: NSRange? = nil
    ) async -> ReadingSelection? {
        guard let workspace else { return nil }
        let targetResource = resource
            ?? presentationsByBookID[documentID.uuidString]?.activeResource
            ?? .text
        do {
            let workspaceReader = try await workspace.open(documentID: documentID)
            let selection = try await workspaceReader.session.select(
                documentID: documentID,
                resource: targetResource,
                range: range,
                visibleRange: visibleRange
            )
            lastSelectionByBookID[documentID.uuidString] = selection
            return selection
        } catch {
            return nil
        }
    }

    /// Persists the reading position (`progression` and optional `visibleRange` anchor) via `ReaderSession.recordProgress`.
    /// Uses a sequence token so out-of-order async tasks never overwrite newer reading positions.
    func recordReadingProgress(
        documentID: UUID,
        resource: SourceResource? = nil,
        visibleRange: NSRange?,
        progression: Double
    ) async {
        guard let workspace else { return }
        let clampedProgression = min(1.0, max(0.0, progression.isFinite ? progression : 0.0))
        let targetResource = resource
            ?? presentationsByBookID[documentID.uuidString]?.activeResource
            ?? .text

        let sequence = (latestProgressSequenceByDocID[documentID] ?? 0) + 1
        latestProgressSequenceByDocID[documentID] = sequence

        do {
            let workspaceReader = try await workspace.open(documentID: documentID)
            guard latestProgressSequenceByDocID[documentID] == sequence else { return }

            let session = workspaceReader.session
            let manifest = workspaceReader.document
            let content = try await session.content(for: targetResource)
            guard latestProgressSequenceByDocID[documentID] == sequence else { return }

            let effectiveRange = CanonicalDocumentAdapter.safeAnchorRange(
                for: visibleRange,
                in: content.text
            )

            try await session.recordProgress(
                documentID: documentID,
                resource: targetResource,
                visibleRange: effectiveRange,
                progression: clampedProgression
            )
            guard latestProgressSequenceByDocID[documentID] == sequence else { return }

            let updatedPosition = try await workspace.library.readingPosition(for: documentID)
            let bookmarks = (try? await workspace.library.bookmarks(for: documentID)) ?? []
            let existingPres = presentationsByBookID[documentID.uuidString]
            let existingRank = existingPres?.libraryBook.lastOpenedSortRank ?? -100
            let imageMap = await loadEPUBImages(from: session, content: content, documentID: documentID)
            guard latestProgressSequenceByDocID[documentID] == sequence else { return }

            let updatedPresentation = CanonicalDocumentAdapter.buildPresentation(
                manifest: manifest,
                content: content,
                position: updatedPosition,
                bookmarks: bookmarks,
                imageDataByPath: imageMap,
                coverImageData: epubCoverCache[documentID],
                sortRank: existingRank
            )

            presentationsByBookID[documentID.uuidString] = updatedPresentation
            if let idx = importedBooks.firstIndex(where: { $0.id == documentID.uuidString }) {
                importedBooks[idx] = updatedPresentation.libraryBook
            }
        } catch {
            return
        }
    }

    /// Toggles a bookmark on the document's active resource via `ReaderSession.bookmark` / `DocumentLibrary.deleteBookmark`.
    @discardableResult
    func toggleBookmark(
        documentID: UUID,
        resource: SourceResource? = nil,
        visibleRange: NSRange?,
        title: String
    ) async -> Bool {
        guard let workspace else { return false }
        let targetResource = resource
            ?? presentationsByBookID[documentID.uuidString]?.activeResource
            ?? .text
        do {
            let existing = try await workspace.library.bookmarks(for: documentID)
            let matchingOnResource = existing.filter { $0.position.resource == targetResource }
            if !matchingOnResource.isEmpty {
                for bm in matchingOnResource {
                    try await workspace.library.deleteBookmark(id: bm.id)
                }
                await refreshSingleDocument(documentID: documentID, resource: targetResource)
                return false
            } else {
                let workspaceReader = try await workspace.open(documentID: documentID)
                let content = try await workspaceReader.session.content(for: targetResource)
                let safeRange = CanonicalDocumentAdapter.safeAnchorRange(for: visibleRange, in: content.text)
                let cleanTitle = title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                    ? workspaceReader.document.document.title
                    : title.trimmingCharacters(in: .whitespacesAndNewlines)
                _ = try await workspaceReader.session.bookmark(
                    documentID: documentID,
                    resource: targetResource,
                    range: safeRange,
                    title: cleanTitle
                )
                await refreshSingleDocument(documentID: documentID, resource: targetResource)
                return true
            }
        } catch {
            return false
        }
    }

    func saveTypographyFontSize(_ fontSize: CGFloat) async {
        readingFontSize = fontSize
        guard let workspace else { return }
        do {
            var prefs = (try? await workspace.library.readingPreferences()) ?? ReadingPreferences()
            prefs.fontSize = Double(fontSize)
            try await workspace.library.saveReadingPreferences(prefs)
        } catch {
            return
        }
    }

    func shutdown() async {
        guard let workspace else { return }
        try? await workspace.shutdown()
    }

    private func loadEPUBImages(
        from reader: SandpaperCore.DocumentReader,
        content: ReadingContent,
        documentID: UUID
    ) async -> [String: Data] {
        guard !content.images.isEmpty else { return [:] }
        var map: [String: Data] = [:]
        for img in content.images {
            guard let path = img.archivePath, map[path] == nil else { continue }
            if let data = try? await reader.epubAsset(at: path), !data.isEmpty {
                map[path] = data
                if epubCoverCache[documentID] == nil {
                    epubCoverCache[documentID] = data
                }
            }
        }
        return map
    }

    private func loadEPUBImages(
        from session: ReaderSession,
        content: ReadingContent,
        documentID: UUID
    ) async -> [String: Data] {
        guard !content.images.isEmpty else { return [:] }
        var map: [String: Data] = [:]
        for img in content.images {
            guard let path = img.archivePath, map[path] == nil else { continue }
            if let data = try? await session.epubAsset(at: path), !data.isEmpty {
                map[path] = data
                if epubCoverCache[documentID] == nil {
                    epubCoverCache[documentID] = data
                }
            }
        }
        return map
    }

    private func refreshSingleDocument(documentID: UUID, resource: SourceResource? = nil) async {
        guard let workspace else { return }
        do {
            let reader = try await workspace.library.openReader(for: documentID)
            let manifest = try await reader.manifest()
            let position = try await workspace.library.readingPosition(for: documentID)
            let targetResource = resource
                ?? presentationsByBookID[documentID.uuidString]?.activeResource
                ?? position?.resource
                ?? manifest.resources.first?.source
                ?? .text
            let content = try await reader.content(for: targetResource)
            let bookmarks = (try? await workspace.library.bookmarks(for: documentID)) ?? []
            let imageMap = await loadEPUBImages(from: reader, content: content, documentID: documentID)
            let existingRank = presentationsByBookID[documentID.uuidString]?.libraryBook.lastOpenedSortRank ?? -100

            let presentation = CanonicalDocumentAdapter.buildPresentation(
                manifest: manifest,
                content: content,
                position: position,
                bookmarks: bookmarks,
                imageDataByPath: imageMap,
                coverImageData: epubCoverCache[documentID],
                sortRank: existingRank
            )
            presentationsByBookID[documentID.uuidString] = presentation
            if let idx = importedBooks.firstIndex(where: { $0.id == documentID.uuidString }) {
                importedBooks[idx] = presentation.libraryBook
            }
        } catch {
            return
        }
    }
}
