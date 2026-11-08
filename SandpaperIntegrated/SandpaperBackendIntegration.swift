import Foundation
import Observation
import SwiftUI
import SandpaperCore

// MARK: - Canonical Block & Document Presentation Models

struct CanonicalBlockItem: Equatable, Sendable {
    let blockID: String
    let text: String
    let resourceRange: NSRange
    let kind: ReadingBlockKind

    var id: String { blockID }

    var isHeading: Bool {
        if case .heading = kind {
            return true
        }
        return false
    }
}

struct CanonicalDocumentPresentation: Sendable {
    let document: LibraryDocument
    let canonicalText: String
    let blocks: [CanonicalBlockItem]
    let blockResourceRanges: [String: NSRange]
    let chapterSectionRanges: [String: NSRange]
    let chapterSectionBlockIDs: [String: String]
    let position: ReadingPosition?
    let restoredBlockID: String?
    let restoredRange: NSRange?
    let isBookmarked: Bool
    let libraryBook: LibraryBook

    var chapter: BookChapter { libraryBook.sampleChapter }
    var blockRangesByID: [String: NSRange] { blockResourceRanges }
}

// MARK: - Canonical Text & UTF-16 Offset Adapter

enum CanonicalDocumentAdapter {
    static func isSupportedFormat(_ format: DocumentFormat) -> Bool {
        format == .plainText || format == .markdown
    }

    static func isSupportedFileURL(_ url: URL) -> Bool {
        let ext = url.pathExtension.lowercased()
        return ext == "txt" || ext == "md" || ext == "markdown"
    }

    /// Extracts canonical blocks from `ReadingContent`, preserving the exact canonical text
    /// and exact UTF-16 `NSRange` offsets within `content.text`.
    static func extractBlocks(from content: ReadingContent, format: DocumentFormat) -> [CanonicalBlockItem] {
        let canonicalText = content.text
        let nsText = canonicalText as NSString
        guard nsText.length > 0 else { return [] }

        if format == .markdown && !content.blocks.isEmpty {
            var items: [CanonicalBlockItem] = []
            for (idx, block) in content.blocks.enumerated() {
                guard block.range.location >= 0,
                      block.range.length > 0,
                      NSMaxRange(block.range) <= nsText.length else {
                    continue
                }
                let blockID = "p\(idx + 1)"
                let text = nsText.substring(with: block.range)
                items.append(
                    CanonicalBlockItem(
                        blockID: blockID,
                        text: text,
                        resourceRange: block.range,
                        kind: block.kind
                    )
                )
            }
            if !items.isEmpty {
                return items
            }
        }

        return extractPlainTextBlocks(from: nsText)
    }

    private static func extractPlainTextBlocks(from nsText: NSString) -> [CanonicalBlockItem] {
        guard nsText.length > 0 else { return [] }

        let fullRange = NSRange(location: 0, length: nsText.length)
        let doubleNewlineRegex = try? NSRegularExpression(pattern: #"\r?\n[\t \r]*\r?\n"#)
        let doubleMatches = doubleNewlineRegex?.matches(in: nsText as String, range: fullRange) ?? []

        let candidateRanges: [NSRange]
        if !doubleMatches.isEmpty {
            candidateRanges = rangesBetweenMatches(doubleMatches, totalLength: nsText.length)
        } else {
            let singleNewlineRegex = try? NSRegularExpression(pattern: #"\r?\n"#)
            let singleMatches = singleNewlineRegex?.matches(in: nsText as String, range: fullRange) ?? []
            if !singleMatches.isEmpty {
                candidateRanges = rangesBetweenMatches(singleMatches, totalLength: nsText.length)
            } else {
                candidateRanges = [fullRange]
            }
        }

        var items: [CanonicalBlockItem] = []
        for rawRange in candidateRanges {
            if let trimmed = trimNewlinesOnly(in: rawRange, within: nsText),
               containsNonWhitespace(in: trimmed, within: nsText) {
                let blockID = "p\(items.count + 1)"
                let text = nsText.substring(with: trimmed)
                items.append(
                    CanonicalBlockItem(
                        blockID: blockID,
                        text: text,
                        resourceRange: trimmed,
                        kind: .paragraph
                    )
                )
            }
        }

        if items.isEmpty {
            let text = nsText.substring(with: fullRange)
            items.append(
                CanonicalBlockItem(
                    blockID: "p1",
                    text: text,
                    resourceRange: fullRange,
                    kind: .paragraph
                )
            )
        }

        return items
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

    private static func trimNewlinesOnly(in range: NSRange, within nsText: NSString) -> NSRange? {
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

    private static func containsNonWhitespace(in range: NSRange, within nsText: NSString) -> Bool {
        let sub = nsText.substring(with: range)
        return sub.unicodeScalars.contains { !CharacterSet.whitespacesAndNewlines.contains($0) }
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

    /// Resolves a saved `ReadingPosition` against `ReadingContent` and returns the matching block ID and UTF-16 range.
    static func resolveRestoredLocation(
        in blocks: [CanonicalBlockItem],
        content: ReadingContent,
        position: ReadingPosition?,
        resolution: AnchorResolution? = nil
    ) -> (blockID: String?, range: NSRange?) {
        guard !blocks.isEmpty else { return (nil, nil) }

        let resolvedAnchor = resolution ?? position?.anchor.map {
            $0.resolve(in: content.text, revision: content.revision)
        }

        if let resolvedAnchor {
            switch resolvedAnchor {
            case .exact(let range), .relocated(let range):
                if let match = blocks.first(where: { NSIntersectionRange($0.resourceRange, range).length > 0 })
                    ?? blocks.first(where: { NSLocationInRange(range.location, $0.resourceRange) })
                    ?? blocks.min(by: {
                        abs($0.resourceRange.location - range.location) < abs($1.resourceRange.location - range.location)
                    }) {
                    return (match.blockID, range)
                }
            case .ambiguous, .missing:
                break
            }
        }

        if let progression = position?.progression, progression > 0 {
            let totalUTF16 = max(1, (content.text as NSString).length)
            let targetOffset = Int(round(progression * Double(max(0, totalUTF16 - 1))))
            if let match = blocks.first(where: {
                targetOffset >= $0.resourceRange.location && targetOffset <= NSMaxRange($0.resourceRange)
            }) ?? blocks.last(where: { $0.resourceRange.location <= targetOffset }) ?? blocks.first {
                return (match.blockID, match.resourceRange)
            }
        }

        return (nil, nil)
    }

    /// Produces a bounded, valid UTF-16 `NSRange` inside `content.text` suitable for `SourceAnchor`.
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
        guard quote.unicodeScalars.contains(where: { !CharacterSet.whitespacesAndNewlines.contains($0) }) else {
            return nil
        }
        return aligned
    }

    static func buildPresentation(
        document: LibraryDocument,
        content: ReadingContent,
        position: ReadingPosition?,
        resolution: AnchorResolution? = nil,
        bookmarks: [Bookmark],
        sortRank: Int
    ) -> CanonicalDocumentPresentation {
        let blocks = extractBlocks(from: content, format: document.format)
        var blockResourceRanges: [String: NSRange] = [:]
        for item in blocks {
            blockResourceRanges[item.blockID] = item.resourceRange
        }

        // Build chapter/section navigation from headings if present, or fallback to document title
        var sectionTitles: [String] = []
        var sectionRanges: [String: NSRange] = [:]
        var sectionBlockIDs: [String: String] = [:]

        for item in blocks {
            if case .heading = item.kind {
                let cleanTitle = item.text
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                    .components(separatedBy: .newlines)
                    .first ?? item.text
                if !cleanTitle.isEmpty && !sectionTitles.contains(cleanTitle) {
                    sectionTitles.append(cleanTitle)
                    sectionRanges[cleanTitle] = item.resourceRange
                    sectionBlockIDs[cleanTitle] = item.blockID
                }
            }
        }

        let defaultSectionTitle = sectionTitles.first ?? (document.format == .markdown ? "Markdown Text" : "Full Text")
        if sectionTitles.isEmpty {
            sectionTitles = [defaultSectionTitle]
            if let firstBlock = blocks.first {
                sectionRanges[defaultSectionTitle] = firstBlock.resourceRange
                sectionBlockIDs[defaultSectionTitle] = firstBlock.blockID
            }
        }

        let restored = resolveRestoredLocation(
            in: blocks,
            content: content,
            position: position,
            resolution: resolution
        )

        let totalUTF16 = max(1, (content.text as NSString).length)
        let totalPages = max(1, Int(ceil(Double(totalUTF16) / 1400.0)))
        let progress = min(1.0, max(0.0, position?.progression ?? 0.0))
        let currentPage = max(1, min(totalPages, Int(round(progress * Double(max(0, totalPages - 1)))) + 1))

        // Determine active section label based on restored position or first section
        let activeOffset = restored.range?.location ?? 0
        var activeSectionLabel = defaultSectionTitle
        for title in sectionTitles {
            if let r = sectionRanges[title], r.location <= activeOffset {
                activeSectionLabel = title
            }
        }

        let currentSectionSummary: String
        if let quote = position?.anchor?.quote.trimmingCharacters(in: .whitespacesAndNewlines), !quote.isEmpty {
            let singleLine = quote.replacingOccurrences(of: "\n", with: " ")
            let snippet = singleLine.count > 36 ? String(singleLine.prefix(36)) + "…" : singleLine
            currentSectionSummary = "\(activeSectionLabel) · “\(snippet)”"
        } else if let firstBookmark = bookmarks.first {
            currentSectionSummary = firstBookmark.title
        } else if progress > 0 {
            currentSectionSummary = "\(activeSectionLabel) · Page \(currentPage)"
        } else {
            currentSectionSummary = activeSectionLabel
        }

        let contentBlocks: [ContentBlock]
        if blocks.isEmpty {
            contentBlocks = [
                .paragraph(id: "p1", segments: [.plain("")])
            ]
        } else {
            contentBlocks = blocks.map { item in
                .paragraph(id: item.blockID, segments: [.plain(item.text)])
            }
        }

        let isMarkdown = document.format == .markdown
        let formatBadge: BookFormatBadge = isMarkdown ? .md : .txt
        let formatLabel = isMarkdown ? "Markdown" : "Plain Text"
        let partLabel = isMarkdown ? "MARKDOWN DOCUMENT" : "PLAIN TEXT DOCUMENT"
        let subtitle = isMarkdown ? "Canonical Markdown Text" : "Canonical Plain Text"

        let currentSectionIdx = sectionTitles.firstIndex(of: activeSectionLabel) ?? 0
        let prevNav: ChapterNavigationItem? = currentSectionIdx > 0
            ? ChapterNavigationItem(title: sectionTitles[currentSectionIdx - 1])
            : nil
        let nextNav: ChapterNavigationItem? = (currentSectionIdx + 1) < sectionTitles.count
            ? ChapterNavigationItem(title: sectionTitles[currentSectionIdx + 1])
            : nil

        let bookChapter = BookChapter(
            id: document.id.uuidString,
            bookTitle: document.title,
            author: formatLabel,
            partLabel: partLabel,
            chapterLabel: activeSectionLabel,
            locationTitle: document.title,
            subtitle: subtitle,
            currentPage: currentPage,
            totalPages: totalPages,
            progress: progress,
            syncStatus: "Saved",
            blocks: contentBlocks,
            previousChapter: prevNav,
            nextChapter: nextNav,
            availableChapters: sectionTitles
        )

        let isFinished = progress >= 0.99
        let pct = Int(round(progress * 100))
        let gridMeta: String
        if isFinished {
            gridMeta = "Finished · \(totalPages) pp"
        } else if pct > 0 {
            gridMeta = "\(formatBadge.rawValue) · \(pct)%"
        } else {
            gridMeta = "\(formatBadge.rawValue) · \(totalPages) \(totalPages == 1 ? "p" : "pp")"
        }

        let progressLabelLeft: String
        if isFinished {
            progressLabelLeft = "Finished"
        } else if totalPages > 1 {
            progressLabelLeft = "Page \(currentPage) of \(totalPages)"
        } else {
            progressLabelLeft = formatBadge.rawValue
        }

        let libraryBook = LibraryBook(
            id: document.id.uuidString,
            backendDocumentID: document.id,
            title: document.title,
            author: formatLabel,
            genreTag: formatLabel,
            filterGroup: isMarkdown ? .essays : .nonfiction,
            format: formatBadge,
            coverStyle: .importedDocument(
                title: document.title,
                formatLabel: isMarkdown ? "MARKDOWN EDITION" : "PLAIN TEXT EDITION",
                isMarkdown: isMarkdown
            ),
            isOnReadingDesk: true,
            isCurrentlyReading: !isFinished,
            isFinished: isFinished,
            lastReadRelative: relativeTimestamp(from: document.importedAt),
            lastOpenedSortRank: sortRank,
            currentSectionLabel: currentSectionSummary,
            progressLabelLeft: progressLabelLeft,
            progressFraction: progress,
            totalPages: totalPages,
            gridMetadataLine: gridMeta,
            sampleChapter: bookChapter
        )

        return CanonicalDocumentPresentation(
            document: document,
            canonicalText: content.text,
            blocks: blocks,
            blockResourceRanges: blockResourceRanges,
            chapterSectionRanges: sectionRanges,
            chapterSectionBlockIDs: sectionBlockIDs,
            position: position,
            restoredBlockID: restored.blockID,
            restoredRange: restored.range,
            isBookmarked: !bookmarks.isEmpty,
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
    let workspace: ReaderWorkspace

    var importedBooks: [LibraryBook] = []
    var presentationsByBookID: [String: CanonicalDocumentPresentation] = [:]
    var lastSelectionByBookID: [String: ReadingSelection] = [:]
    var readingFontSize: CGFloat = 20.5
    var isLoaded: Bool = false

    init(directory: URL? = nil) {
        let resolvedDirectory: URL
        if let directory {
            resolvedDirectory = directory
        } else {
            resolvedDirectory = Self.defaultLibraryDirectory()
        }
        self.directory = resolvedDirectory
        do {
            self.workspace = try ReaderWorkspace(directory: resolvedDirectory)
        } catch {
            let fallback = FileManager.default.temporaryDirectory
                .appendingPathComponent("SandpaperFallback-\(UUID().uuidString)", isDirectory: true)
            self.workspace = try! ReaderWorkspace(directory: fallback)
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
        )) ?? FileManager.default.temporaryDirectory
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
        presentationsByBookID[id.uuidString]?.isBookmarked ?? false
    }

    /// Loads all persisted TXT and Markdown documents and their saved reading positions from `DocumentLibrary`.
    func reloadFromBackend() async {
        _ = try? await workspace.restore()

        if let prefs = try? await workspace.library.readingPreferences() {
            let size = CGFloat(prefs.fontSize)
            if (17.5...25.5).contains(size) {
                readingFontSize = size
            }
        }

        guard let documents = try? await workspace.library.documents(inTrash: false) else {
            isLoaded = true
            return
        }

        let supported = documents.filter { CanonicalDocumentAdapter.isSupportedFormat($0.format) }
        var loadedBooks: [LibraryBook] = []
        var loadedPresentations: [String: CanonicalDocumentPresentation] = [:]

        for (index, doc) in supported.enumerated() {
            do {
                let reader = try await workspace.library.openReader(for: doc.id)
                let content = try await reader.content(for: .text)
                let position = try await workspace.library.readingPosition(for: doc.id)
                let bookmarks = (try? await workspace.library.bookmarks(for: doc.id)) ?? []
                let sortRank = -(supported.count - index)

                let presentation = CanonicalDocumentAdapter.buildPresentation(
                    document: doc,
                    content: content,
                    position: position,
                    bookmarks: bookmarks,
                    sortRank: sortRank
                )
                loadedBooks.append(presentation.libraryBook)
                loadedPresentations[doc.id.uuidString] = presentation
            } catch {
                continue
            }
        }

        self.presentationsByBookID = loadedPresentations
        self.importedBooks = loadedBooks
        self.isLoaded = true
    }

    /// Imports real TXT and Markdown files into `DocumentLibrary` and refreshes the Library state.
    @discardableResult
    func importFiles(_ urls: [URL]) async -> String {
        guard !urls.isEmpty else { return "No files selected." }

        let supportedURLs = urls.filter { CanonicalDocumentAdapter.isSupportedFileURL($0) }
        let unsupportedCount = urls.count - supportedURLs.count

        guard !supportedURLs.isEmpty else {
            return "Only TXT and Markdown (.txt, .md, .markdown) files are supported for backend import."
        }

        var importedTitles: [String] = []
        var duplicateTitles: [String] = []
        var failedNames: [String] = []

        for url in supportedURLs {
            do {
                let result = try await workspace.library.importDocument(from: url)
                if result.alreadyImported {
                    duplicateTitles.append(result.document.title)
                } else {
                    importedTitles.append(result.document.title)
                }
            } catch {
                failedNames.append(url.lastPathComponent)
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
        if unsupportedCount > 0 {
            parts.append("Skipped \(unsupportedCount) non-TXT/Markdown file(s).")
        }
        if !failedNames.isEmpty {
            parts.append("Failed to import: \(failedNames.joined(separator: ", ")).")
        }
        return parts.isEmpty ? "Import completed." : parts.joined(separator: " ")
    }

    /// Opens a document in `ReaderWorkspace` / `ReaderSession` and resolves its saved `ReadingPosition`.
    @discardableResult
    func openDocumentInReader(documentID: UUID) async -> CanonicalDocumentPresentation? {
        do {
            let workspaceReader = try await workspace.open(documentID: documentID)
            let session = workspaceReader.session
            let savedPosition = try await workspace.library.readingPosition(for: documentID)
                ?? workspaceReader.initialPosition

            let content: ReadingContent
            let resolution: AnchorResolution?
            if let savedPosition {
                let destination = try await session.navigate(to: savedPosition)
                content = destination.content
                resolution = destination.resolution
            } else {
                content = try await session.content(for: .text)
                resolution = nil
            }

            let bookmarks = (try? await workspace.library.bookmarks(for: documentID)) ?? []
            let existingRank = presentationsByBookID[documentID.uuidString]?.libraryBook.lastOpenedSortRank ?? -100

            let presentation = CanonicalDocumentAdapter.buildPresentation(
                document: workspaceReader.document.document,
                content: content,
                position: savedPosition,
                resolution: resolution,
                bookmarks: bookmarks,
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
            return presentationsByBookID[documentID.uuidString]
        }
    }

    /// Registers a canonical UTF-16 text selection with the backend `ReaderSession`.
    @discardableResult
    func selectText(
        documentID: UUID,
        range: NSRange,
        visibleRange: NSRange? = nil
    ) async -> ReadingSelection? {
        do {
            let workspaceReader = try await workspace.open(documentID: documentID)
            let selection = try await workspaceReader.session.select(
                documentID: documentID,
                resource: .text,
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
    func recordReadingProgress(
        documentID: UUID,
        visibleRange: NSRange?,
        progression: Double
    ) async {
        let clampedProgression = min(1.0, max(0.0, progression.isFinite ? progression : 0.0))
        do {
            let workspaceReader = try await workspace.open(documentID: documentID)
            let session = workspaceReader.session
            let content = try await session.content(for: .text)

            // Fall back to existing anchor range if no new visibleRange was supplied and progression matches
            let effectiveRange = CanonicalDocumentAdapter.safeAnchorRange(
                for: visibleRange,
                in: content.text
            )

            try await session.recordProgress(
                documentID: documentID,
                resource: .text,
                visibleRange: effectiveRange,
                progression: clampedProgression
            )

            let updatedPosition = try await workspace.library.readingPosition(for: documentID)
            let bookmarks = (try? await workspace.library.bookmarks(for: documentID)) ?? []
            let existingRank = presentationsByBookID[documentID.uuidString]?.libraryBook.lastOpenedSortRank ?? -100

            let updatedPresentation = CanonicalDocumentAdapter.buildPresentation(
                document: workspaceReader.document.document,
                content: content,
                position: updatedPosition,
                bookmarks: bookmarks,
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

    /// Toggles a bookmark on the document via `ReaderSession.bookmark` / `DocumentLibrary.deleteBookmark`.
    @discardableResult
    func toggleBookmark(
        documentID: UUID,
        visibleRange: NSRange?,
        title: String
    ) async -> Bool {
        do {
            let existing = try await workspace.library.bookmarks(for: documentID)
            if !existing.isEmpty {
                for bm in existing {
                    try await workspace.library.deleteBookmark(id: bm.id)
                }
                await refreshSingleDocument(documentID: documentID)
                return false
            } else {
                let workspaceReader = try await workspace.open(documentID: documentID)
                let content = try await workspaceReader.session.content(for: .text)
                let safeRange = CanonicalDocumentAdapter.safeAnchorRange(for: visibleRange, in: content.text)
                let cleanTitle = title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                    ? workspaceReader.document.document.title
                    : title
                _ = try await workspaceReader.session.bookmark(
                    documentID: documentID,
                    resource: .text,
                    range: safeRange,
                    title: cleanTitle
                )
                await refreshSingleDocument(documentID: documentID)
                return true
            }
        } catch {
            return false
        }
    }

    func saveTypographyFontSize(_ fontSize: CGFloat) async {
        readingFontSize = fontSize
        do {
            var prefs = (try? await workspace.library.readingPreferences()) ?? ReadingPreferences()
            prefs.fontSize = Double(fontSize)
            try await workspace.library.saveReadingPreferences(prefs)
        } catch {
            return
        }
    }

    func shutdown() async {
        try? await workspace.shutdown()
    }

    private func refreshSingleDocument(documentID: UUID) async {
        do {
            let doc = try await workspace.library.document(id: documentID)
            let reader = try await workspace.library.openReader(for: documentID)
            let content = try await reader.content(for: .text)
            let position = try await workspace.library.readingPosition(for: documentID)
            let bookmarks = (try? await workspace.library.bookmarks(for: documentID)) ?? []
            let existingRank = presentationsByBookID[documentID.uuidString]?.libraryBook.lastOpenedSortRank ?? -100

            let presentation = CanonicalDocumentAdapter.buildPresentation(
                document: doc,
                content: content,
                position: position,
                bookmarks: bookmarks,
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

