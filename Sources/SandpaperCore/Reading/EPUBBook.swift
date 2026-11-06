import Foundation
import ZIPFoundation

/// No filesystem extraction, script execution, external entities, or remote-resource fetching.
/// Ordinary reflowable XHTML is exposed as native attributed text and semantic blocks.
final class EPUBBook {
    let spine: [String]
    let navigation: [ReadingNavigationItem]
    private let archive: Archive
    private let paths: Set<String>

    init(url: URL) throws {
        archive = try Archive(url: url, accessMode: .read)
        var seen: Set<String> = []
        for entry in archive {
            guard seen.count < 100_000, !entry.path.hasPrefix("/"), !entry.path.contains("\\"),
                  !entry.path.split(separator: "/").contains(".."), !entry.path.contains("\0"),
                  seen.insert(entry.path).inserted else { throw ReaderError.invalidDocument }
        }
        paths = seen
        let container = try Self.xml(Self.read("META-INF/container.xml", archive: archive, paths: paths, maximumBytes: 1_048_576))
        guard let root = try container.nodes(forXPath: "//*[local-name()='rootfile']").first as? XMLElement,
              let location = root.attribute(forName: "full-path")?.stringValue else { throw ReaderError.invalidDocument }
        let packagePath = try Self.resolve(location, relativeTo: "").path
        let package = try Self.xml(Self.read(packagePath, archive: archive, paths: paths, maximumBytes: 4_194_304))
        let metadata = try package.nodes(forXPath: "//*[local-name()='meta']").compactMap { $0 as? XMLElement }
        if metadata.contains(where: { $0.attribute(forName: "property")?.stringValue == "rendition:layout" && $0.stringValue?.trimmingCharacters(in: .whitespacesAndNewlines) == "pre-paginated" }) {
            throw ReaderError.unsupportedEPUBLayout
        }
        var manifest: [String: (path: String, type: String, properties: String)] = [:]
        for case let item as XMLElement in try package.nodes(forXPath: "//*[local-name()='manifest']/*[local-name()='item']") {
            guard let id = item.attribute(forName: "id")?.stringValue,
                  let href = item.attribute(forName: "href")?.stringValue,
                  let type = item.attribute(forName: "media-type")?.stringValue, manifest[id] == nil else { throw ReaderError.invalidDocument }
            // Optional remote assets must not prevent offline reading. A remote spine item
            // still fails below because only local XHTML resources can enter the spine.
            if let link = URLComponents(string: href), link.scheme != nil || link.host != nil { continue }
            let path = try Self.resolve(href, relativeTo: packagePath).path
            manifest[id] = (path, type, item.attribute(forName: "properties")?.stringValue ?? "")
        }
        var ordered: [String] = []
        for case let item as XMLElement in try package.nodes(forXPath: "//*[local-name()='spine']/*[local-name()='itemref']") {
            if item.attribute(forName: "linear")?.stringValue == "no" { continue }
            guard let id = item.attribute(forName: "idref")?.stringValue, let resource = manifest[id],
                  resource.type == "application/xhtml+xml", paths.contains(resource.path) else { throw ReaderError.invalidDocument }
            if !ordered.contains(resource.path) { ordered.append(resource.path) }
        }
        guard !ordered.isEmpty else { throw ReaderError.invalidDocument }
        spine = ordered
        var toc: [ReadingNavigationItem] = []
        let nav = manifest.values.first { $0.properties.split(separator: " ").contains("nav") }
        let ncx = manifest.values.first { $0.type == "application/x-dtbncx+xml" }
        if let nav, let data = try? Self.read(nav.path, archive: archive, paths: paths, maximumBytes: 2_097_152), let xml = try? Self.xml(data, html: true) {
            let nodes = (try? xml.nodes(forXPath: "//*[local-name()='nav']")) ?? []
            let section = nodes.first { ($0 as? XMLElement)?.attribute(forName: "epub:type")?.stringValue?.split(separator: " ").contains("toc") == true } ?? nodes.first
            for case let a as XMLElement in (try? section?.nodes(forXPath: ".//*[local-name()='a']")) ?? [] {
                guard let href = a.attribute(forName: "href")?.stringValue,
                      let target = try? Self.resolve(href, relativeTo: nav.path), ordered.contains(target.path) else { continue }
                var parent = a.parent, depth = -1
                while let node = parent { if node.name?.split(separator: ":").last == "li" { depth += 1 }; parent = node.parent }
                toc.append(ReadingNavigationItem(title: a.stringValue?.trimmingCharacters(in: .whitespacesAndNewlines) ?? "",
                    resource: .epub(path: target.path), fragment: target.fragment, depth: max(0, depth)))
            }
        } else if let ncx, let data = try? Self.read(ncx.path, archive: archive, paths: paths, maximumBytes: 2_097_152), let xml = try? Self.xml(data) {
            for case let point as XMLElement in (try? xml.nodes(forXPath: "//*[local-name()='navPoint']")) ?? [] {
                guard let content = try? point.nodes(forXPath: "./*[local-name()='content']").first as? XMLElement,
                      let src = content.attribute(forName: "src")?.stringValue,
                      let target = try? Self.resolve(src, relativeTo: ncx.path), ordered.contains(target.path) else { continue }
                let title = (try? point.nodes(forXPath: "./*[local-name()='navLabel']/*[local-name()='text']").first?.stringValue) ?? ""
                toc.append(ReadingNavigationItem(title: title, resource: .epub(path: target.path), fragment: target.fragment, depth: 0))
            }
        }
        navigation = toc
    }

    func read(_ path: String, maximumBytes: Int) throws -> Data {
        try Self.read(path, archive: archive, paths: paths, maximumBytes: maximumBytes)
    }

    private static func read(_ path: String, archive: Archive, paths: Set<String>, maximumBytes: Int) throws -> Data {
        guard paths.contains(path), let entry = archive[path], entry.type == .file else { throw ReaderError.resourceNotFound }
        guard entry.uncompressedSize <= UInt64(maximumBytes) else { throw ReaderError.resourceTooLarge }
        var bytes = Data()
        let crc = try archive.extract(entry) { chunk in
            try Task.checkCancellation()
            guard chunk.count <= maximumBytes - bytes.count else { throw ReaderError.resourceTooLarge }
            bytes.append(chunk)
        }
        guard crc == entry.checksum else { throw ReaderError.invalidDocument }
        return bytes
    }

    private static func xml(_ data: Data, html: Bool = false) throws -> XMLDocument {
        let source = String(data: data, encoding: .utf8) ?? String(data: data, encoding: .utf16) ?? ""
        guard source.range(of: "<!ENTITY", options: .caseInsensitive) == nil else { throw ReaderError.invalidDocument }
        // Never attempt to resolve an external DTD, including XHTML entity files.
        if let xml = try? XMLDocument(data: data, options: [.nodeLoadExternalEntitiesNever]) { return xml }
        guard html else { throw ReaderError.invalidDocument }
        return try XMLDocument(data: data, options: [.nodeLoadExternalEntitiesNever, .documentTidyHTML])
    }

    private static func resolve(_ href: String, relativeTo base: String) throws -> (path: String, fragment: String?) {
        guard !href.hasPrefix("/"), !href.contains("\\"), !href.contains("\0"),
              let components = URLComponents(string: href), components.scheme == nil, components.host == nil,
              let path = components.percentEncodedPath.removingPercentEncoding else { throw ReaderError.invalidDocument }
        var pieces = base.split(separator: "/").dropLast().map(String.init)
        if path.isEmpty { return (base, components.fragment) }
        for piece in path.split(separator: "/") {
            if piece == "." { continue }
            if piece == ".." { guard !pieces.isEmpty else { throw ReaderError.invalidDocument }; pieces.removeLast() }
            else { pieces.append(String(piece)) }
        }
        guard !pieces.isEmpty else { throw ReaderError.invalidDocument }
        return (pieces.joined(separator: "/"), components.fragment)
    }

    struct Content {
        var text = AttributedString()
        var blocks: [ReadingBlock] = []
        var images: [ReadingImage] = []
        var fragments: [String: Int] = [:]
    }

    func content(path: String) throws -> Content {
        let xml = try Self.xml(read(path, maximumBytes: 4_194_304), html: true)
        guard let body = try xml.nodes(forXPath: "//*[local-name()='body']").first else { throw ReaderError.invalidDocument }
        var result = Content(), length = 0, pendingSpace = false, lastWasNewline = true, visited = 0
        func append(_ text: String, intent: InlinePresentationIntent = []) throws {
            guard length + text.utf16.count <= 8_388_608 else { throw ReaderError.resourceTooLarge }
            var piece = AttributedString(text); if !intent.isEmpty { piece.inlinePresentationIntent = intent }
            result.text.append(piece); length += text.utf16.count
            lastWasNewline = text.last == "\n"
        }
        func boundary() throws {
            pendingSpace = false
            if length > 0, !lastWasNewline { try append("\n\n") }
        }
        func walk(_ node: XMLNode, intent: InlinePresentationIntent, preformatted: Bool, depth: Int) throws {
            visited += 1
            guard depth < 128, visited < 100_000 else { throw ReaderError.resourceTooLarge }
            try Task.checkCancellation()
            if node.kind == .text {
                let text = node.stringValue ?? ""
                if preformatted { try append(text, intent: intent); return }
                for part in text.split(omittingEmptySubsequences: false, whereSeparator: \.isWhitespace) {
                    if part.isEmpty { pendingSpace = !lastWasNewline; continue }
                    if pendingSpace, length > 0, !lastWasNewline { try append(" ", intent: intent) }
                    try append(String(part), intent: intent); pendingSpace = true
                }
                // Adjacent inline elements without source whitespace must remain adjacent.
                pendingSpace = text.last?.isWhitespace == true && !lastWasNewline
                return
            }
            guard let element = node as? XMLElement else { return }
            let tag = String(element.name?.split(separator: ":").last ?? "").lowercased()
            if ["script", "style", "head", "noscript", "iframe", "object", "form"].contains(tag) { return }
            if element.attribute(forName: "hidden") != nil { return }
            let block = ["p", "div", "section", "article", "h1", "h2", "h3", "h4", "h5", "h6", "blockquote", "li", "pre", "tr"].contains(tag)
            if block { try boundary() }
            let start = length
            if let id = element.attribute(forName: "id")?.stringValue, result.fragments[id] == nil { result.fragments[id] = start }
            if tag == "img" {
                let src = element.attribute(forName: "src")?.stringValue ?? ""
                let imagePath = try? Self.resolve(src, relativeTo: path).path
                result.images.append(ReadingImage(utf16Offset: length, archivePath: imagePath,
                    alternativeText: element.attribute(forName: "alt")?.stringValue ?? ""))
                try append("\u{FFFC}")
            } else if tag == "br" { try append("\n"); pendingSpace = false }
            else {
                var childIntent = intent
                if ["strong", "b"].contains(tag) { childIntent.insert(.stronglyEmphasized) }
                if ["em", "i"].contains(tag) { childIntent.insert(.emphasized) }
                if ["code", "pre"].contains(tag) { childIntent.insert(.code) }
                for child in element.children ?? [] { try walk(child, intent: childIntent, preformatted: preformatted || tag == "pre", depth: depth + 1) }
            }
            if length > start {
                let kind: ReadingBlockKind?
                if tag.hasPrefix("h"), let level = Int(tag.dropFirst()), (1...6).contains(level) { kind = .heading(level: level) }
                else { kind = ["p": .paragraph, "li": .listItem, "blockquote": .quotation, "pre": .code][tag] }
                if let kind { result.blocks.append(ReadingBlock(range: NSRange(location: start, length: length - start), kind: kind)) }
            }
            if block { try boundary() }
        }
        try walk(body, intent: [], preformatted: false, depth: 0)
        return result
    }
}
