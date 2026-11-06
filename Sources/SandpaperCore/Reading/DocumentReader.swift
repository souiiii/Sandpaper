import Foundation
import PDFKit

/// Lazy resource loading, serialized off the main actor. Only two resources are cached.
public actor DocumentReader {
    private let document: LibraryDocument
    private let url: URL
    private var opened: ReadingDocument?
    private var pdf: PDFDocument?
    private var epub: EPUBBook?
    private var cache: [(SourceResource, ReadingContent)] = []

    public init(document: LibraryDocument, fileURL: URL) {
        self.document = document
        self.url = fileURL
    }

    public func manifest() throws -> ReadingDocument {
        if let opened { return opened }
        try Task.checkCancellation()
        let resources: [ReadingResource]
        var navigation: [ReadingNavigationItem] = []
        switch document.format {
        case .plainText, .markdown:
            resources = [ReadingResource(source: .text, title: document.title)]
        case .pdf:
            guard let pdf = PDFDocument(url: url) else { throw ReaderError.invalidDocument }
            guard !pdf.isLocked else { throw ReaderError.lockedPDF }
            guard pdf.pageCount > 0, pdf.pageCount <= 100_000 else { throw ReaderError.invalidDocument }
            self.pdf = pdf
            resources = (0..<pdf.pageCount).map { ReadingResource(source: .pdfPage(index: $0), title: "Page \($0 + 1)") }
        case .epub:
            let book = try EPUBBook(url: url)
            epub = book
            resources = book.spine.enumerated().map { ReadingResource(source: .epub(path: $0.element), title: "Chapter \($0.offset + 1)") }
            navigation = book.navigation
        case .html:
            throw LibraryError.unsupportedFormat("Standalone HTML reading is outside the current scope.")
        }
        let value = ReadingDocument(document: document, fileURL: url, resources: resources, navigation: navigation)
        opened = value
        return value
    }

    public func content(for resource: SourceResource) throws -> ReadingContent {
        let manifest = try manifest()
        guard manifest.resources.contains(where: { $0.source == resource }) else { throw ReaderError.resourceNotFound }
        if let index = cache.firstIndex(where: { $0.0 == resource }) {
            let value = cache.remove(at: index); cache.append(value); return value.1
        }
        try Task.checkCancellation()
        var attributed: AttributedString
        var blocks: [ReadingBlock] = []
        var images: [ReadingImage] = []
        var fragments: [String: Int] = [:]
        switch resource {
        case .text:
            let handle = try FileHandle(forReadingFrom: url)
            defer { try? handle.close() }
            let bytes = try handle.read(upToCount: 16_777_217) ?? Data()
            guard bytes.count <= 16_777_216 else { throw ReaderError.resourceTooLarge }
            let text = try Self.decodeText(bytes)
            if document.format == .markdown {
                let parsed = try AttributedString(markdown: text)
                attributed = AttributedString()
                var previousID: Int?
                var start = 0, length = 0, kind = ReadingBlockKind.paragraph
                for run in parsed.runs {
                    let component = run.presentationIntent?.components.first
                    if component?.identity != previousID, length > start {
                        blocks.append(ReadingBlock(range: NSRange(location: start, length: length - start), kind: kind))
                        attributed.append(AttributedString("\n\n")); length += 2; start = length
                    }
                    previousID = component?.identity
                    if let component, case .header(let level) = component.kind { kind = .heading(level: level) }
                    else { kind = .paragraph }
                    let piece = AttributedString(parsed[run.range])
                    attributed.append(piece); length += String(piece.characters).utf16.count
                }
                if length > start { blocks.append(ReadingBlock(range: NSRange(location: start, length: length - start), kind: kind)) }
            } else { attributed = AttributedString(text) }
        case .pdfPage(let index):
            guard let page = pdf?.page(at: index) else { throw ReaderError.resourceNotFound }
            // Image-only PDFs remain renderable; absence of selectable text is explicit.
            attributed = AttributedString(pdf?.allowsCopying == true ? (page.string ?? "") : "")
        case .epub(let path):
            guard let epub else { throw ReaderError.invalidDocument }
            let rendered = try epub.content(path: path)
            attributed = rendered.text; blocks = rendered.blocks; images = rendered.images; fragments = rendered.fragments
        case .article: throw ReaderError.resourceNotFound
        }
        let content = ReadingContent(documentID: document.id, revision: document.revision, resource: resource,
            attributedText: attributed, blocks: blocks, images: images, fragmentOffsets: fragments)
        cache.append((resource, content))
        if cache.count > 2 { cache.removeFirst() }
        return content
    }

    public func epubAsset(at path: String) throws -> Data {
        _ = try manifest()
        guard let epub else { throw ReaderError.resourceNotFound }
        return try epub.read(path, maximumBytes: 20_971_520)
    }

    private static func decodeText(_ data: Data) throws -> String {
        let utf16 = data.starts(with: [0xFF, 0xFE]) || data.starts(with: [0xFE, 0xFF])
        guard var text = String(data: data, encoding: utf16 ? .utf16 : .utf8), !text.contains("\0") else { throw ReaderError.unsupportedEncoding }
        if text.first == "\u{FEFF}" { text.removeFirst() }
        return text
    }
}
