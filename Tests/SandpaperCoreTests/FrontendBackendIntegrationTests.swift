import AppKit
import Foundation
import Testing
@testable import SandpaperCore
@testable import SandpaperIntegrated

@MainActor
private final class MockSelectableBlockEndpoint: SelectableBlockEndpoint {
    let blockID: String
    let fullText: String
    let contextText: String
    var blockFrameInReader: CGRect
    var window: NSWindow? = nil

    init(
        blockID: String,
        fullText: String,
        contextText: String? = nil,
        blockFrameInReader: CGRect = CGRect(x: 48, y: 120, width: 620, height: 84)
    ) {
        self.blockID = blockID
        self.fullText = fullText
        self.contextText = contextText ?? fullText
        self.blockFrameInReader = blockFrameInReader
    }

    func convert(_ point: NSPoint, from view: NSView?) -> NSPoint {
        point
    }

    func clampedCharacterIndex(forPointInWindow windowPoint: CGPoint) -> Int {
        0
    }

    func selectionRects(for range: NSRange) -> [CGRect] {
        guard range.location != NSNotFound, range.length > 0 else { return [] }
        return [
            CGRect(
                x: CGFloat(range.location) * 7.0,
                y: 8,
                width: max(24, CGFloat(range.length) * 7.0),
                height: 24
            )
        ]
    }
}

@Suite("Frontend–Backend TXT & Markdown Integration")
struct FrontendBackendIntegrationTests {
    @Test
    @MainActor
    func importsTxtAndMarkdownPersistsAcrossRestartAndOpensActualTextInReader() async throws {
        let tempRoot = FileManager.default.temporaryDirectory
            .appendingPathComponent("SandpaperFrontendIntegration-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: tempRoot, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempRoot) }

        let libraryDir = tempRoot.appendingPathComponent("LibraryStore", isDirectory: true)
        let sourceDir = tempRoot.appendingPathComponent("SourceFiles", isDirectory: true)
        try FileManager.default.createDirectory(at: sourceDir, withIntermediateDirectories: true)

        let txtURL = sourceDir.appendingPathComponent("Field Notes on Solitude.txt")
        let txtBody = """
        First paragraph of the plain text notebook with Café and 📖 emoji in the margin.

        Second paragraph records observations on circumspection and unhurried attention.

        Third paragraph concludes the field notes at dusk.
        """
        try Data(txtBody.utf8).write(to: txtURL)

        let mdURL = sourceDir.appendingPathComponent("On Literary Architecture.md")
        let mdBody = """
        # Architectural Prelude

        A **measured** reflection on *canonical* prose and structural clarity.

        ## Second Movement

        > Every quotation preserves its exact offset in the canonical stream.

        Final paragraph with `inline code` and a closing cadence.
        """
        try Data(mdBody.utf8).write(to: mdURL)

        // 1. First session: Import TXT and Markdown via SandpaperBackendStore
        let storeSession1 = SandpaperBackendStore(directory: libraryDir)
        let statusMessage = await storeSession1.importFiles([txtURL, mdURL])
        #expect(statusMessage.contains("Imported"))
        #expect(storeSession1.importedBooks.count == 2)

        let importedTxtBook = try #require(storeSession1.importedBooks.first(where: { $0.format == .txt }))
        let importedMdBook = try #require(storeSession1.importedBooks.first(where: { $0.format == .md }))

        #expect(importedTxtBook.title == "Field Notes on Solitude")
        #expect(importedMdBook.title == "On Literary Architecture")
        #expect(importedTxtBook.backendDocumentID != nil)
        #expect(importedMdBook.backendDocumentID != nil)

        // Verify Reader chapter contains actual imported text, NOT mock content
        let txtDocID = try #require(importedTxtBook.backendDocumentID)
        let mdDocID = try #require(importedMdBook.backendDocumentID)

        let txtPresentation = try #require(await storeSession1.openDocumentInReader(documentID: txtDocID))
        #expect(txtPresentation.canonicalText == txtBody)
        #expect(txtPresentation.blocks.count == 3)
        #expect(txtPresentation.blocks[0].text.contains("First paragraph of the plain text notebook with Café and 📖 emoji"))
        #expect(txtPresentation.blocks[1].text.contains("circumspection and unhurried attention"))
        #expect(!txtPresentation.canonicalText.contains("Darlington Hall"))

        let mdPresentation = try #require(await storeSession1.openDocumentInReader(documentID: mdDocID))
        #expect(mdPresentation.canonicalText.contains("Architectural Prelude"))
        #expect(mdPresentation.canonicalText.contains("A measured reflection on canonical prose"))
        #expect(!mdPresentation.canonicalText.contains("**measured**"))
        #expect(mdPresentation.chapter.availableChapters == ["Architectural Prelude", "Second Movement"])

        await storeSession1.shutdown()

        // 2. Second session (simulated application restart): verify Library persistence
        let storeSession2 = SandpaperBackendStore(directory: libraryDir)
        await storeSession2.reloadFromBackend()

        #expect(storeSession2.importedBooks.count == 2)
        let restoredTxtBook = try #require(storeSession2.book(for: txtDocID.uuidString))
        let restoredMdBook = try #require(storeSession2.book(for: mdDocID.uuidString))
        #expect(restoredTxtBook.title == "Field Notes on Solitude")
        #expect(restoredMdBook.title == "On Literary Architecture")

        // Verify rendered blocks in BookChapter match canonical substrings
        for item in txtPresentation.blocks {
            let sub = (txtPresentation.canonicalText as NSString).substring(with: item.resourceRange)
            #expect(sub == item.text)
        }
        for item in mdPresentation.blocks {
            let sub = (mdPresentation.canonicalText as NSString).substring(with: item.resourceRange)
            #expect(sub == item.text)
        }

        await storeSession2.shutdown()
    }

    @Test
    @MainActor
    func preservesCanonicalTextAndAccurateUTF16SelectionOffsetsAcrossTxtAndMarkdown() async throws {
        let tempRoot = FileManager.default.temporaryDirectory
            .appendingPathComponent("SandpaperUTF16Offsets-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: tempRoot, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempRoot) }

        let libraryDir = tempRoot.appendingPathComponent("LibraryStore", isDirectory: true)
        let sourceDir = tempRoot.appendingPathComponent("SourceFiles", isDirectory: true)
        try FileManager.default.createDirectory(at: sourceDir, withIntermediateDirectories: true)

        let txtURL = sourceDir.appendingPathComponent("Unicode Offsets.txt")
        let txtContent = """
        Preface with Café ☕️ and 📖 emoji before target word.

        In the second paragraph we study ineluctable consequences after astral symbols 𝌆 and accents.
        """
        try Data(txtContent.utf8).write(to: txtURL)

        let mdURL = sourceDir.appendingPathComponent("Formatted Offsets.md")
        let mdContent = """
        # First Heading

        Opening paragraph with **bold emphasis** and *italicized phrasing* before circumspection in context.

        ## Second Heading

        Another paragraph discussing `hermeneutic` precision after stripped Markdown syntax.
        """
        try Data(mdContent.utf8).write(to: mdURL)

        let store = SandpaperBackendStore(directory: libraryDir)
        _ = await store.importFiles([txtURL, mdURL])

        let txtBook = try #require(store.importedBooks.first(where: { $0.format == .txt }))
        let mdBook = try #require(store.importedBooks.first(where: { $0.format == .md }))
        let txtID = try #require(txtBook.backendDocumentID)
        let mdID = try #require(mdBook.backendDocumentID)

        let txtPres = try #require(await store.openDocumentInReader(documentID: txtID))
        let mdPres = try #require(await store.openDocumentInReader(documentID: mdID))

        // Verify single-block selection in TXT after multi-byte UTF-16 emojis (☕️, 📖, 𝌆)
        let txtCoordinator = ReaderSelectionCoordinator()
        txtCoordinator.orderedBlockIDs = txtPres.blocks.map(\.blockID)
        txtCoordinator.canonicalText = txtPres.canonicalText
        txtCoordinator.blockResourceRanges = txtPres.blockResourceRanges

        for block in txtPres.blocks {
            txtCoordinator.register(MockSelectableBlockEndpoint(blockID: block.blockID, fullText: block.text))
        }

        let secondTxtBlock = try #require(txtPres.blocks.last)
        let localTargetRangeInTxt = (secondTxtBlock.text as NSString).range(of: "ineluctable consequences")
        #expect(localTargetRangeInTxt.location != NSNotFound)

        let txtEndpoint = MockSelectableBlockEndpoint(blockID: secondTxtBlock.blockID, fullText: secondTxtBlock.text)
        let uiTxtSelection = try #require(
            txtCoordinator.buildSingleBlockSelection(
                endpoint: txtEndpoint,
                range: localTargetRangeInTxt,
                trim: true
            )
        )

        let expectedCanonicalTxtRange = (txtPres.canonicalText as NSString).range(of: "ineluctable consequences")
        #expect(uiTxtSelection.selectedText == "ineluctable consequences")
        let resolvedTxtCanonicalRange = try #require(uiTxtSelection.canonicalUTF16Range)
        #expect(resolvedTxtCanonicalRange == expectedCanonicalTxtRange)

        let backendTxtSelection = try #require(
            await store.selectText(
                documentID: txtID,
                range: resolvedTxtCanonicalRange,
                visibleRange: secondTxtBlock.resourceRange
            )
        )
        #expect(backendTxtSelection.anchor.quote == "ineluctable consequences")
        #expect(
            NSRange(
                location: backendTxtSelection.anchor.utf16Offset,
                length: backendTxtSelection.anchor.utf16Length
            ) == expectedCanonicalTxtRange
        )

        let txtReader = try await store.workspace.library.openReader(for: txtID)
        let canonicalTxtReadingContent = try await txtReader.content(for: .text)
        #expect(
            backendTxtSelection.anchor.resolve(
                in: canonicalTxtReadingContent.text,
                revision: canonicalTxtReadingContent.revision
            ) == .exact(expectedCanonicalTxtRange)
        )

        // Verify single-block selection in Markdown after stripped formatting (**bold**, *italic*, `code`)
        let mdCoordinator = ReaderSelectionCoordinator()
        mdCoordinator.orderedBlockIDs = mdPres.blocks.map(\.blockID)
        mdCoordinator.canonicalText = mdPres.canonicalText
        mdCoordinator.blockResourceRanges = mdPres.blockResourceRanges

        for block in mdPres.blocks {
            mdCoordinator.register(MockSelectableBlockEndpoint(blockID: block.blockID, fullText: block.text))
        }

        let lastMdBlock = try #require(mdPres.blocks.last)
        let localMdRange = (lastMdBlock.text as NSString).range(of: "hermeneutic precision")
        #expect(localMdRange.location != NSNotFound)

        let mdEndpoint = MockSelectableBlockEndpoint(blockID: lastMdBlock.blockID, fullText: lastMdBlock.text)
        let uiMdSelection = try #require(
            mdCoordinator.buildSingleBlockSelection(
                endpoint: mdEndpoint,
                range: localMdRange,
                trim: true
            )
        )

        let expectedCanonicalMdRange = (mdPres.canonicalText as NSString).range(of: "hermeneutic precision")
        #expect(uiMdSelection.selectedText == "hermeneutic precision")
        let resolvedMdCanonicalRange = try #require(uiMdSelection.canonicalUTF16Range)
        #expect(resolvedMdCanonicalRange == expectedCanonicalMdRange)

        let backendMdSelection = try #require(
            await store.selectText(
                documentID: mdID,
                range: resolvedMdCanonicalRange,
                visibleRange: lastMdBlock.resourceRange
            )
        )
        #expect(backendMdSelection.anchor.quote == "hermeneutic precision")
        #expect(
            NSRange(
                location: backendMdSelection.anchor.utf16Offset,
                length: backendMdSelection.anchor.utf16Length
            ) == expectedCanonicalMdRange
        )

        let mdReader = try await store.workspace.library.openReader(for: mdID)
        let canonicalMdReadingContent = try await mdReader.content(for: .text)
        #expect(
            backendMdSelection.anchor.resolve(
                in: canonicalMdReadingContent.text,
                revision: canonicalMdReadingContent.revision
            ) == .exact(expectedCanonicalMdRange)
        )

        // Verify multi-block selection canonical UTF-16 range mapping across paragraphs
        let firstMdBlock = try #require(mdPres.blocks.first)
        let secondMdBlock = mdPres.blocks[1]
        let multiBlockSelection = ReaderTextSelection(
            blockID: firstMdBlock.blockID,
            nsRange: NSRange(location: 0, length: (firstMdBlock.text as NSString).length),
            selectedText: "\(firstMdBlock.text)\n\n\(secondMdBlock.text)",
            contextText: "\(firstMdBlock.text) \(secondMdBlock.text)",
            lineHighlightRects: [CGRect(x: 0, y: 0, width: 120, height: 24)],
            anchorRectInReader: CGRect(x: 48, y: 120, width: 120, height: 24),
            blockSelections: [
                firstMdBlock.blockID: BlockHighlightSelection(
                    nsRange: NSRange(location: 0, length: (firstMdBlock.text as NSString).length),
                    lineHighlightRects: [CGRect(x: 0, y: 0, width: 120, height: 24)]
                ),
                secondMdBlock.blockID: BlockHighlightSelection(
                    nsRange: NSRange(location: 0, length: 17),
                    lineHighlightRects: [CGRect(x: 0, y: 28, width: 120, height: 24)]
                )
            ]
        )

        let multiCanonicalRange = try #require(
            CanonicalDocumentAdapter.canonicalUTF16Range(for: multiBlockSelection, in: mdPres)
        )
        let expectedMultiSpan = NSRange(
            location: firstMdBlock.resourceRange.location,
            length: (secondMdBlock.resourceRange.location + 17) - firstMdBlock.resourceRange.location
        )
        #expect(multiCanonicalRange == expectedMultiSpan)

        let backendMultiSelection = try #require(
            await store.selectText(
                documentID: mdID,
                range: multiCanonicalRange,
                visibleRange: multiCanonicalRange
            )
        )
        #expect(
            backendMultiSelection.anchor.resolve(
                in: canonicalMdReadingContent.text,
                revision: canonicalMdReadingContent.revision
            ) == .exact(expectedMultiSpan)
        )

        await store.shutdown()
    }

    @Test
    @MainActor
    func savesAndRestoresReadingPositionsAndBookmarksUsingBackendAPIs() async throws {
        let tempRoot = FileManager.default.temporaryDirectory
            .appendingPathComponent("SandpaperReadingPosition-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: tempRoot, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempRoot) }

        let libraryDir = tempRoot.appendingPathComponent("LibraryStore", isDirectory: true)
        let sourceDir = tempRoot.appendingPathComponent("SourceFiles", isDirectory: true)
        try FileManager.default.createDirectory(at: sourceDir, withIntermediateDirectories: true)

        let mdURL = sourceDir.appendingPathComponent("MultiSection Essay.md")
        let mdText = """
        # Part One: Departure

        The morning mist lingered over the valley as the carriage set out along the ridge.

        ## Part Two: The Archive

        Inside the archive, rows of folios preserved centuries of correspondence and marginalia.

        ## Part Three: Return

        By evening the lamps were lit and the final ledger entry was recorded in silence.
        """
        try Data(mdText.utf8).write(to: mdURL)

        // Session 1: Import, open, record reading progress at Part Three, toggle bookmark & save font size
        let store1 = SandpaperBackendStore(directory: libraryDir)
        _ = await store1.importFiles([mdURL])

        let book1 = try #require(store1.importedBooks.first)
        let docID = try #require(book1.backendDocumentID)
        let initialPres = try #require(await store1.openDocumentInReader(documentID: docID))
        #expect(initialPres.chapter.progress == 0.0)

        let targetBlock = try #require(initialPres.blocks.last)
        #expect(targetBlock.text.contains("By evening the lamps were lit"))

        await store1.recordReadingProgress(
            documentID: docID,
            visibleRange: targetBlock.resourceRange,
            progression: 0.78
        )

        let bookmarked = await store1.toggleBookmark(
            documentID: docID,
            visibleRange: targetBlock.resourceRange,
            title: "Part Three: Return"
        )
        #expect(bookmarked == true)
        #expect(store1.hasBookmarks(for: docID) == true)

        await store1.saveTypographyFontSize(22.5)
        await store1.shutdown()

        // Session 2: New store instance on the same directory restores saved ReadingPosition, block ID, bookmark, and font size
        let store2 = SandpaperBackendStore(directory: libraryDir)
        await store2.reloadFromBackend()

        #expect(store2.readingFontSize == 22.5)
        let restoredLibraryBook = try #require(store2.book(for: docID.uuidString))
        #expect(abs(restoredLibraryBook.progressFraction - 0.78) < 0.001)

        let reopenedPres = try #require(await store2.openDocumentInReader(documentID: docID))
        #expect(abs(reopenedPres.chapter.progress - 0.78) < 0.001)
        #expect(reopenedPres.restoredBlockID == targetBlock.blockID)
        #expect(reopenedPres.restoredRange == targetBlock.resourceRange)
        #expect(reopenedPres.isBookmarked == true)
        #expect(reopenedPres.chapter.chapterLabel == "Part Three: Return")

        await store2.shutdown()
    }
}
