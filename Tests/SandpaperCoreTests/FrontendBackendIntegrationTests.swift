import AppKit
import Foundation
import Testing
import ZIPFoundation
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

        let txtReader = try await #require(store.workspace).library.openReader(for: txtID)
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

        let mdReader = try await #require(store.workspace).library.openReader(for: mdID)
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

    private func makeTestEPUB(
        at url: URL,
        fixedLayout: Bool = false
    ) throws {
        let archive = try Archive(url: url, accessMode: .create)
        // Minimal valid 1x1 transparent PNG
        let pngBase64 = "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNk+M9QDwADhgGAWjR9awAAAABJRU5ErkJggg=="
        let pngData = try #require(Data(base64Encoded: pngBase64))

        let metadataBlock = fixedLayout
            ? "<metadata><meta property='rendition:layout'>pre-paginated</meta></metadata>"
            : "<metadata/>"

        let textEntries: [String: String] = [
            "mimetype": "application/epub+zip",
            "META-INF/container.xml": """
            <container version="1.0" xmlns="urn:oasis:names:tc:opendocument:xmlns:container">
              <rootfiles>
                <rootfile full-path="OPS/package.opf" media-type="application/oebps-package+xml"/>
              </rootfiles>
            </container>
            """,
            "OPS/package.opf": """
            <package version="3.0" xmlns="http://www.idpf.org/2007/opf">
              \(metadataBlock)
              <manifest>
                <item id="nav" href="nav.xhtml" media-type="application/xhtml+xml" properties="nav"/>
                <item id="ch1" href="ch1.xhtml" media-type="application/xhtml+xml"/>
                <item id="ch2" href="ch2.xhtml" media-type="application/xhtml+xml"/>
                <item id="img1" href="images/harbour.png" media-type="image/png"/>
              </manifest>
              <spine>
                <itemref idref="ch1"/>
                <itemref idref="ch2"/>
              </spine>
            </package>
            """,
            "OPS/nav.xhtml": """
            <html xmlns="http://www.w3.org/1999/xhtml" xmlns:epub="http://www.idpf.org/2007/ops">
              <body>
                <nav epub:type="toc">
                  <ol>
                    <li><a href="ch1.xhtml">Chapter One: The Harbour</a></li>
                    <li>
                      <a href="ch2.xhtml#sec-light">Chapter Two: The Lighthouse</a>
                      <ol>
                        <li><a href="ch2.xhtml#sec-lamp">Signal Lamp</a></li>
                      </ol>
                    </li>
                  </ol>
                </nav>
              </body>
            </html>
            """,
            "OPS/ch1.xhtml": """
            <html xmlns="http://www.w3.org/1999/xhtml">
              <body>
                <h1>Chapter One: The Harbour</h1>
                <p>📖 At the Café we observed <em>considerable</em> composure and <strong>resolute</strong> craft alongside <code>logbook</code> entries.</p>
                <blockquote>A vessel at anchor still answers the tide.</blockquote>
                <ul>
                  <li>First mooring line secured</li>
                  <li>Second lantern trimmed</li>
                </ul>
                <p><img src="images/harbour.png" alt="Harbour sketch"/></p>
              </body>
            </html>
            """,
            "OPS/ch2.xhtml": """
            <html xmlns="http://www.w3.org/1999/xhtml">
              <body>
                <h1 id="sec-light">Chapter Two: The Lighthouse</h1>
                <p>The spiral stair ascended through salt-cooled masonry toward the lantern room.</p>
                <h2 id="sec-lamp">Signal Lamp</h2>
                <p>Beyond the breakwater, the nocturnal horizon remained incandescent and calm.</p>
              </body>
            </html>
            """
        ]

        for (path, content) in textEntries {
            let bytes = Data(content.utf8)
            try archive.addEntry(
                with: path,
                type: .file,
                uncompressedSize: Int64(bytes.count),
                compressionMethod: .deflate
            ) { position, size in
                bytes.subdata(in: Int(position)..<min(Int(position) + size, bytes.count))
            }
        }

        try archive.addEntry(
            with: "OPS/images/harbour.png",
            type: .file,
            uncompressedSize: Int64(pngData.count),
            compressionMethod: .deflate
        ) { position, size in
            pngData.subdata(in: Int(position)..<min(Int(position) + size, pngData.count))
        }
    }

    @Test
    @MainActor
    func importsReflowableEPUBNavigatesSpineAndTOCExtractsStructureAndImagesAndPersistsPosition() async throws {
        let tempRoot = FileManager.default.temporaryDirectory
            .appendingPathComponent("SandpaperEPUBIntegration-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: tempRoot, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempRoot) }

        let libraryDir = tempRoot.appendingPathComponent("LibraryStore", isDirectory: true)
        let sourceDir = tempRoot.appendingPathComponent("SourceFiles", isDirectory: true)
        try FileManager.default.createDirectory(at: sourceDir, withIntermediateDirectories: true)

        let epubURL = sourceDir.appendingPathComponent("Coastal Chronicles.epub")
        try makeTestEPUB(at: epubURL)

        // Session 1: Import EPUB and open in Reader
        let store1 = SandpaperBackendStore(directory: libraryDir)
        let importMessage = await store1.importFiles([epubURL])
        #expect(importMessage.contains("Imported"))
        #expect(store1.lastErrorMessage == nil)
        #expect(store1.importedBooks.count == 1)

        let epubBook = try #require(store1.importedBooks.first)
        #expect(epubBook.format == .epub)
        #expect(epubBook.title == "Coastal Chronicles")
        // Verify no fabricated author or sample-book metadata is injected
        #expect(epubBook.author.isEmpty)
        #expect(epubBook.sampleChapter.partLabel.isEmpty)
        #expect(epubBook.sampleChapter.locationTitle.isEmpty)
        #expect(epubBook.sampleChapter.subtitle.isEmpty)

        let docID = try #require(epubBook.backendDocumentID)
        let ch1Pres = try #require(await store1.openDocumentInReader(documentID: docID))
        #expect(ch1Pres.activeResource == .epub(path: "OPS/ch1.xhtml"))
        #expect(ch1Pres.totalResourcesCount == 2)
        #expect(ch1Pres.chapter.availableChapters.contains("Chapter One: The Harbour"))
        #expect(ch1Pres.chapter.availableChapters.contains("Chapter Two: The Lighthouse"))

        // Verify semantic blocks (heading, paragraph with inline runs, quotation, list items, image)
        #expect(ch1Pres.blocks.contains(where: { $0.kind == .heading(level: 1) && $0.text == "Chapter One: The Harbour" }))
        #expect(ch1Pres.blocks.contains(where: { $0.kind == .quotation && $0.text.contains("A vessel at anchor") }))
        #expect(ch1Pres.blocks.contains(where: { $0.kind == .listItem && $0.listBullet == "•" && $0.text.contains("First mooring line") }))

        let styledParagraph = try #require(ch1Pres.blocks.first(where: { $0.text.contains("considerable composure") }))
        #expect(styledParagraph.inlineRuns.contains(where: { $0.isItalic }))
        #expect(styledParagraph.inlineRuns.contains(where: { $0.isBold }))
        #expect(styledParagraph.inlineRuns.contains(where: { $0.isCode }))

        let allImages = ch1Pres.blocks.flatMap(\.attachedImages)
        let harbourImage = try #require(allImages.first(where: { $0.archivePath == "OPS/images/harbour.png" }))
        #expect(harbourImage.alternativeText == "Harbour sketch")
        #expect(harbourImage.imageData != nil)

        // Verify resource-specific canonical UTF-16 selection in Chapter 1
        let ch1TargetRange = (ch1Pres.canonicalText as NSString).range(of: "resolute craft")
        #expect(ch1TargetRange.location != NSNotFound)
        let ch1Selection = try #require(
            await store1.selectText(
                documentID: docID,
                range: ch1TargetRange,
                visibleRange: styledParagraph.resourceRange
            )
        )
        #expect(ch1Selection.anchor.resource == .epub(path: "OPS/ch1.xhtml"))
        #expect(ch1Selection.anchor.quote == "resolute craft")
        #expect(NSRange(location: ch1Selection.anchor.utf16Offset, length: ch1Selection.anchor.utf16Length) == ch1TargetRange)

        // Navigate to Chapter 2 via TOC title
        let ch2Pres = try #require(
            await store1.navigateToChapter(
                documentID: docID,
                chapterTitle: "Chapter Two: The Lighthouse"
            )
        )
        #expect(ch2Pres.activeResource == .epub(path: "OPS/ch2.xhtml"))
        #expect(ch2Pres.canonicalText.contains("spiral stair ascended"))
        #expect(ch2Pres.canonicalText.contains("incandescent and calm"))

        // Verify resource-specific canonical UTF-16 selection in Chapter 2
        let ch2LastBlock = try #require(ch2Pres.blocks.last)
        let ch2TargetRange = (ch2Pres.canonicalText as NSString).range(of: "incandescent and calm")
        #expect(ch2TargetRange.location != NSNotFound)
        let ch2Selection = try #require(
            await store1.selectText(
                documentID: docID,
                range: ch2TargetRange,
                visibleRange: ch2LastBlock.resourceRange
            )
        )
        #expect(ch2Selection.anchor.resource == .epub(path: "OPS/ch2.xhtml"))
        #expect(ch2Selection.anchor.quote == "incandescent and calm")
        #expect(NSRange(location: ch2Selection.anchor.utf16Offset, length: ch2Selection.anchor.utf16Length) == ch2TargetRange)

        // Record reading progress and bookmark in Chapter 2
        await store1.recordReadingProgress(
            documentID: docID,
            visibleRange: ch2LastBlock.resourceRange,
            progression: 0.88
        )
        let bookmarked = await store1.toggleBookmark(
            documentID: docID,
            visibleRange: ch2LastBlock.resourceRange,
            title: "Signal Lamp"
        )
        #expect(bookmarked == true)
        await store1.shutdown()

        // Session 2: Simulate restart and verify EPUB chapter, block, and bookmark restoration
        let store2 = SandpaperBackendStore(directory: libraryDir)
        await store2.reloadFromBackend()
        #expect(store2.importedBooks.count == 1)

        let reopenedEPUB = try #require(await store2.openDocumentInReader(documentID: docID))
        #expect(reopenedEPUB.activeResource == .epub(path: "OPS/ch2.xhtml"))
        #expect(reopenedEPUB.restoredBlockID == ch2LastBlock.blockID)
        #expect(reopenedEPUB.isBookmarked == true)
        #expect(abs((reopenedEPUB.position?.progression ?? 0) - 0.88) < 0.001)
        #expect(abs(reopenedEPUB.chapter.progress - 0.94) < 0.001)

        await store2.shutdown()
    }

    @Test
    @MainActor
    func rejectsFixedLayoutAndMalformedEPUBsAndRestoresIntraParagraphOffsets() async throws {
        let tempRoot = FileManager.default.temporaryDirectory
            .appendingPathComponent("SandpaperEPUBValidation-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: tempRoot, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempRoot) }

        let libraryDir = tempRoot.appendingPathComponent("LibraryStore", isDirectory: true)
        let sourceDir = tempRoot.appendingPathComponent("SourceFiles", isDirectory: true)
        try FileManager.default.createDirectory(at: sourceDir, withIntermediateDirectories: true)

        let store = SandpaperBackendStore(directory: libraryDir)
        #expect(store.includeMockDemoBooks == false)
        #expect(store.initializationError == nil)

        // 1. Fixed-layout EPUB should be rejected gracefully and removed from the library
        let fixedEPUBURL = sourceDir.appendingPathComponent("FixedLayout.epub")
        try makeTestEPUB(at: fixedEPUBURL, fixedLayout: true)
        let fixedMsg = await store.importFiles([fixedEPUBURL])
        #expect(fixedMsg.localizedCaseInsensitiveContains("fixed-layout") || fixedMsg.localizedCaseInsensitiveContains("reflowable"))
        #expect(store.lastErrorMessage != nil)
        #expect(store.importedBooks.isEmpty)

        // 2. Malformed EPUB should be rejected gracefully and removed from the library
        let malformedURL = sourceDir.appendingPathComponent("Corrupted.epub")
        try Data("not a valid zip archive".utf8).write(to: malformedURL)
        let malformedMsg = await store.importFiles([malformedURL])
        #expect(!malformedMsg.isEmpty)
        #expect(store.lastErrorMessage != nil)
        #expect(store.importedBooks.isEmpty)

        // 3. Long paragraph intra-block progress & restoration accuracy
        let longTxtURL = sourceDir.appendingPathComponent("Long Paragraph.txt")
        let shortHeading = "Brief Prelude"
        let longBody = Array(repeating: "A measured sentence inside a very long paragraph of canonical prose.", count: 40).joined(separator: " ")
        let fullText = "\(shortHeading)\n\n\(longBody)"
        try Data(fullText.utf8).write(to: longTxtURL)

        _ = await store.importFiles([longTxtURL])
        let longBook = try #require(store.importedBooks.first)
        let longDocID = try #require(longBook.backendDocumentID)
        let longPres = try #require(await store.openDocumentInReader(documentID: longDocID))
        #expect(longPres.blocks.count == 2)

        let coordinator = ReaderSelectionCoordinator()
        let midScrollResolved = coordinator.resolveVisiblePosition(in: longPres, scrollFraction: 0.55)
        #expect(midScrollResolved.blockID == longPres.blocks[1].blockID)
        #expect(midScrollResolved.visibleRange.location > longPres.blocks[1].resourceRange.location + 400)

        await store.recordReadingProgress(
            documentID: longDocID,
            visibleRange: midScrollResolved.visibleRange,
            progression: midScrollResolved.progression
        )

        let reopenedLongPres = try #require(await store.openDocumentInReader(documentID: longDocID))
        #expect(reopenedLongPres.restoredBlockID == longPres.blocks[1].blockID)
        #expect(reopenedLongPres.restoredIntraBlockFraction > 0.35)

        await store.shutdown()
    }
}
