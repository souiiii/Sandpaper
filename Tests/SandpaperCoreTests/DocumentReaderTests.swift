import CoreGraphics
import CoreText
import Foundation
import PDFKit
import Testing
import ZIPFoundation
@testable import SandpaperCore

struct DocumentReaderTests {
    private func directory() throws -> URL {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        return root
    }

    private func epub(at root: URL, containerPath: String = "OPS/book.opf", customEntity: Bool = false,
        legacyNavigation: Bool = false, fixedLayout: Bool = false) throws -> URL {
        let url = root.appendingPathComponent("book.epub")
        let archive = try Archive(url: url, accessMode: .create)
        var files = [
            "mimetype": "application/epub+zip",
            "META-INF/container.xml": "<container><rootfiles><rootfile full-path='\(containerPath)'/></rootfiles></container>",
            "OPS/book.opf": "<package><manifest><item id='a' href='one.xhtml' media-type='application/xhtml+xml'/><item id='b' href='two.xhtml' media-type='application/xhtml+xml'/><item id='nav' href='nav.xhtml' media-type='application/xhtml+xml' properties='nav'/><item id='remote' href='https://example.invalid/cover.png' media-type='image/png'/></manifest><spine><itemref idref='b'/><itemref idref='a'/></spine></package>",
            "OPS/nav.xhtml": "<html xmlns:epub='http://www.idpf.org/2007/ops'><body><nav epub:type='toc'><ol><li><a href='two.xhtml#target'>Second</a></li></ol></nav></body></html>",
            "OPS/one.xhtml": "<html><body><p>First chapter.</p></body></html>",
            "OPS/two.xhtml": (customEntity ? "<!DOCTYPE html [<!ENTITY leak SYSTEM 'file:///etc/passwd'>]>" : "") + "<html><head><title>Hidden title</title></head><body><h1 id='target'>Second</h1><p>📖 He had <em>considerable</em> means.</p><script>Never show this</script></body></html>"
        ]
        if legacyNavigation {
            files["OPS/book.opf"] = files["OPS/book.opf"]!.replacingOccurrences(of: " properties='nav'", with: "")
                .replacingOccurrences(of: "</manifest>", with: "<item id='ncx' href='toc.ncx' media-type='application/x-dtbncx+xml'/></manifest>")
            files["OPS/toc.ncx"] = "<ncx xmlns='http://www.daisy.org/z3986/2005/ncx/'><navMap><navPoint><navLabel><text>Legacy chapter</text></navLabel><content src='two.xhtml#target'/></navPoint></navMap></ncx>"
        }
        if fixedLayout {
            files["OPS/book.opf"] = files["OPS/book.opf"]!.replacingOccurrences(of: "<package>", with: "<package><metadata><meta property='rendition:layout'> pre-paginated </meta></metadata>")
        }
        for (path, text) in files {
            let bytes = Data(text.utf8)
            try archive.addEntry(with: path, type: .file, uncompressedSize: Int64(bytes.count), compressionMethod: .deflate) { position, size in
                bytes.subdata(in: Int(position)..<min(Int(position) + size, bytes.count))
            }
        }
        return url
    }

    @Test func epubSpineNavigationFormattingAndCanonicalSelectionAgree() async throws {
        let root = try directory(); defer { try? FileManager.default.removeItem(at: root) }
        let library = try DocumentLibrary(directory: root.appendingPathComponent("Library"))
        let document = try await library.importDocument(from: epub(at: root)).document
        let reader = try await library.openReader(for: document.id)
        let manifest = try await reader.manifest()
        #expect(manifest.resources.first?.source == .epub(path: "OPS/two.xhtml"))
        #expect(manifest.navigation.first?.fragment == "target")
        let content = try await reader.content(for: .epub(path: "OPS/two.xhtml"))
        #expect(content.text.contains("He had considerable means."))
        #expect(!content.text.contains("Hidden title")); #expect(!content.text.contains("Never show"))
        #expect(content.fragmentOffsets["target"] == 0)
        #expect(content.attributedText.runs.contains { $0.inlinePresentationIntent?.contains(.emphasized) == true })
        let selection = try content.selection((content.text as NSString).range(of: "means"))
        #expect(selection.anchor.resource == .epub(path: "OPS/two.xhtml"))
        #expect(selection.anchor.resolve(in: content.text, revision: document.revision) == .exact((content.text as NSString).range(of: "means")))
        let session = ReaderSession(library: library)
        _ = try await session.open(documentID: document.id)
        let item = try #require(manifest.navigation.first)
        #expect(try await session.navigate(to: item).resolution == .exact(NSRange(location: 0, length: 0)))
    }

    @Test func epubTraversalAndExternalEntityDeclarationsAreRejected() async throws {
        let root = try directory(); defer { try? FileManager.default.removeItem(at: root) }
        let path = try epub(at: root, containerPath: "../../outside.opf")
        #expect(throws: ReaderError.invalidDocument) { try EPUBBook(url: path) }
        try FileManager.default.removeItem(at: path)
        let entityPath = try epub(at: root, customEntity: true)
        let book = try EPUBBook(url: entityPath)
        #expect(throws: ReaderError.invalidDocument) { try book.content(path: "OPS/two.xhtml") }
    }

    @Test func epub2NavigationWorksAndFixedLayoutIsExplicitlyRejected() throws {
        let root = try directory(); defer { try? FileManager.default.removeItem(at: root) }
        let url = try epub(at: root, legacyNavigation: true)
        let book = try EPUBBook(url: url)
        #expect(book.navigation.first?.title == "Legacy chapter")
        #expect(book.navigation.first?.resource == .epub(path: "OPS/two.xhtml"))
        try FileManager.default.removeItem(at: url)
        let fixed = try epub(at: root, fixedLayout: true)
        #expect(throws: ReaderError.unsupportedEPUBLayout) { try EPUBBook(url: fixed) }
    }

    @Test func plainTextBOMUnicodeAndUnsupportedBytesAreHandledExplicitly() async throws {
        let root = try directory(); defer { try? FileManager.default.removeItem(at: root) }
        let url = root.appendingPathComponent("text.txt")
        let text = "📖 Café means coffee."
        try text.data(using: .utf16)!.write(to: url)
        let library = try DocumentLibrary(directory: root.appendingPathComponent("Library"))
        let document = try await library.importDocument(from: url).document
        let reader = try await library.openReader(for: document.id)
        let content = try await reader.content(for: .text)
        #expect(content.text == text)
        #expect(throws: (any Error).self) { try content.selection(NSRange(location: 1, length: 1)) }
        #expect(try content.selection((text as NSString).range(of: "Café")).anchor.quote == "Café")
        let invalid = root.appendingPathComponent("invalid.txt")
        try Data([0xFF, 0x00, 0xFF]).write(to: invalid)
        let bad = try await library.importDocument(from: invalid).document
        let badReader = try await library.openReader(for: bad.id)
        await #expect(throws: ReaderError.unsupportedEncoding) { try await badReader.content(for: .text) }
    }

    @Test func pdfTextAndImageOnlyPageLocationsAreSupported() async throws {
        let root = try directory(); defer { try? FileManager.default.removeItem(at: root) }
        let url = root.appendingPathComponent("book.pdf")
        var box = CGRect(x: 0, y: 0, width: 300, height: 300)
        let consumer = try #require(CGDataConsumer(url: url as CFURL))
        let context = try #require(CGContext(consumer: consumer, mediaBox: &box, nil))
        context.beginPDFPage(nil); context.textPosition = CGPoint(x: 20, y: 200)
        let font = CTFontCreateWithName("Times" as CFString, 16, nil)
        let line = NSAttributedString(string: "He had considerable means.", attributes: [NSAttributedString.Key(kCTFontAttributeName as String): font])
        CTLineDraw(CTLineCreateWithAttributedString(line), context)
        context.endPDFPage(); context.beginPDFPage(nil); context.endPDFPage(); context.closePDF()
        let library = try DocumentLibrary(directory: root.appendingPathComponent("Library"))
        let document = try await library.importDocument(from: url).document
        let session = ReaderSession(library: library)
        let manifest = try await session.open(documentID: document.id)
        #expect(manifest.resources.count == 2)
        #expect(try await session.content(for: .pdfPage(index: 0)).text.contains("considerable means"))
        let native = try #require(PDFDocument(url: manifest.fileURL))
        let page = try #require(native.page(at: 0))
        let range = ((try #require(page.string)) as NSString).range(of: "means")
        let nativeSelection = try #require(page.selection(for: range))
        let bridged = try PDFSelectionBridge.ranges(for: nativeSelection, in: native)
        #expect(bridged.first?.range == range)
        let selected = try await session.select(documentID: document.id, resource: .pdfPage(index: 0), range: range)
        #expect(selected.anchor.quote == "means")
        #expect(try await session.content(for: .pdfPage(index: 1)).text.isEmpty)
        try await session.recordProgress(documentID: document.id, resource: .pdfPage(index: 1), progression: 0.5)
        let bookmark = try await session.bookmark(documentID: document.id, resource: .pdfPage(index: 1), title: "Image page")
        #expect(try await library.readingPosition(for: document.id)?.anchor == nil)
        #expect(try await library.readingPosition(for: document.id)?.resource == .pdfPage(index: 1))
        #expect(try await session.navigate(to: bookmark.position).resolution == nil)
    }

    @Test func selectionContextIncludesTheCurrentSentenceButNotTheFollowingParagraph() throws {
        let text = "He received a cold reception.\n\nA later paragraph reveals a secret."
        let content = ReadingContent(documentID: UUID(), revision: "v1", resource: .text, attributedText: AttributedString(text), blocks: [], images: [], fragmentOffsets: [:])
        let selected = try content.selection((text as NSString).range(of: "cold"))
        #expect(selected.request.passage.text.contains("cold reception"))
        #expect(!selected.request.passage.text.contains("secret"))
    }
}

