import Foundation
import SandpaperCore

struct EvaluationCase: Sendable {
    let id: String
    let passage: String
    let selection: String
    let reviewFocus: String
    var memories: [KnownSense] = []

    static let cases: [EvaluationCase] = [
        .init(
            id: "idioms", passage: "After months of negotiations, the agreement finally fell through, leaving both parties back at square one.",
            selection: "fell through", reviewFocus: "Discover both idioms; explain the failed agreement without a literal falling interpretation."
        ),
        .init(
            id: "literary-understatement", passage: "He was a gentleman of considerable means, though his manners were rather wanting.",
            selection: "his manners were rather wanting", reviewFocus: "Recognize wealth, deficiency, formal understatement, and a natural modern equivalent."
        ),
        .init(
            id: "implied-criticism", passage: "The committee praised his enthusiasm, though they stopped short of endorsing any of his proposals.",
            selection: "stopped short of", reviewFocus: "Distinguish explicit withholding of endorsement from possible criticism; do not assert a definite motive."
        ),
        .init(
            id: "known-word-new-sense", passage: "His apology was a fig leaf for his indifference.", selection: "fig leaf",
            reviewFocus: "Literal familiarity must not suppress the figurative concealment sense.",
            memories: [.init(expression: "fig leaf", senseKey: "literal-leaf", meaning: "A leaf from a fig tree.", familiarity: .known)]
        ),
        .init(
            id: "unremarkable-prose", passage: "She opened the window and put the book on the table.", selection: "opened",
            reviewFocus: "Prefer no automatic highlights. A manual explanation should remain short."
        ),
        .init(
            id: "known-idiom", passage: "The agreement fell through.", selection: "fell through",
            reviewFocus: "Suppress the recorded known sense without declaring the idiom intrinsically uninteresting.",
            memories: [.init(expression: "fall through", senseKey: "fail-to-happen", meaning: "For a plan or agreement to fail to happen.", familiarity: .known)]
        )
    ]
}
