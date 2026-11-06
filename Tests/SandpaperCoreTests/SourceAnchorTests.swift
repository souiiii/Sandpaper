import Foundation
import Testing
@testable import SandpaperCore

struct SourceAnchorTests {
    @Test func unicodeSelectionUsesUTF16() throws {
        let text = "📖 Her manners were rather wanting."
        let selection = (text as NSString).range(of: "rather wanting")
        let anchor = try makeAnchor(text: text, selection: selection)
        #expect(anchor.quote == "rather wanting")
        #expect(anchor.resolve(in: text, revision: "v1") == .exact(selection))
        let emoji = try makeAnchor(text: text, selection: NSRange(location: 0, length: 2))
        #expect(emoji.quote == "📖")
        for offset in [0, 1] {
            #expect(throws: (any Error).self) {
                try makeAnchor(text: text, selection: NSRange(location: offset, length: 1))
            }
        }
    }

    @Test func extremeOffsetsAreRejectedWithoutOverflow() {
        #expect(throws: (any Error).self) {
            try makeAnchor(text: "hello", selection: NSRange(location: Int.max, length: Int.max))
        }
        #expect(throws: (any Error).self) {
            try SourceAnchor(
                documentID: UUID(), revision: "v1", resource: .text,
                text: "hello", selection: NSRange(location: 0, length: 1), resourceOffset: Int.max
            )
        }
    }

    @Test func repairUsesContextAndNeverChoosesAnAmbiguousOccurrence() throws {
        let text = "She had considerable means. He searched for other means."
        let selection = (text as NSString).range(of: "means", options: .backwards)
        let anchor = try makeAnchor(text: text, selection: selection)
        let edited = "An introduction. " + text
        let expected = (edited as NSString).range(of: "means", options: .backwards)
        #expect(anchor.resolve(in: edited, revision: "v2") == .relocated(expected))

        let noContext = try makeAnchor(text: "means", selection: NSRange(location: 0, length: 5))
        #expect(noContext.resolve(in: "means and means", revision: "v2") == .ambiguous)
        #expect(noContext.resolve(in: "something else", revision: "v2") == .missing)
    }

    @Test func staleOffsetDoesNotOverrideChangedRevision() throws {
        let anchor = try makeAnchor(text: "means", selection: NSRange(location: 0, length: 5))
        #expect(anchor.resolve(in: "means and means", revision: "v2") == .ambiguous)
    }

    @Test func passageOffsetIsResourceRelative() throws {
        let text = "back at square one"
        let passage = try AnalysisPassage(
            documentID: UUID(), revision: "v1", resource: .epub(path: "chapter1.xhtml"),
            resourceOffset: 500, text: text
        )
        let anchor = try passage.anchor(for: NSRange(location: 0, length: text.utf16.count))
        #expect(anchor.utf16Offset == 500)
        _ = try ExplanationRequest(passage: passage, selection: anchor)
    }

    private func makeAnchor(text: String, selection: NSRange) throws -> SourceAnchor {
        try SourceAnchor(documentID: UUID(), revision: "v1", resource: .text, text: text, selection: selection)
    }

    @Test func changedCanonicalContextCannotSilentlySelectAnIdenticalWrongOccurrence() throws {
        let original = "A one. B one. C"
        let anchor = try makeAnchor(text: original, selection: (original as NSString).range(of: "one"))
        let changed = "? one. A one. B one. C"
        let correct = (changed as NSString).range(of: "one", options: [], range: NSRange(location: 7, length: changed.utf16.count - 7))
        #expect(anchor.resolve(in: changed, revision: "v1") == .relocated(correct))
    }
}
