import Foundation
import PDFKit

public struct PDFTextRange: Equatable, Sendable {
    public let pageIndex: Int
    public let range: NSRange
}

public enum PDFSelectionBridge {
    /// Call on the same executor that owns the frontend's PDFDocument/selection.
    /// Disjoint ranges stay disjoint; never manufacture a continuous quotation across pages.
    public static func ranges(for selection: PDFSelection, in document: PDFDocument) throws -> [PDFTextRange] {
        var result: [PDFTextRange] = []
        for page in selection.pages {
            let index = document.index(for: page)
            guard index != NSNotFound, let text = page.string else { throw ReaderError.resourceNotFound }
            let count = selection.numberOfTextRanges(on: page)
            guard count <= 1_024 else { throw ReaderError.resourceTooLarge }
            for item in 0..<count {
                let range = selection.range(at: item, on: page)
                guard range.location != NSNotFound, range.length > 0,
                      let swiftRange = Range(range, in: text), NSRange(swiftRange, in: text) == range,
                      String(text[swiftRange]).utf16.count == range.length else { throw ReaderError.invalidDocument }
                result.append(PDFTextRange(pageIndex: index, range: range))
            }
        }
        return result
    }
}
