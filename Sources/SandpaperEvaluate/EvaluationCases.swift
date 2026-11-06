import Foundation
import SandpaperCore

struct EvaluationCase: Sendable {
    let id: String
    let passage: String
    let selection: String
    let reviewFocus: String
    var memories: [KnownSense] = []
    var source: String? = nil

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

    /// Short verified excerpts plus original constructed cases. Constructed prose
    /// is explicitly labelled; it is never attributed to a real author.
    static let extendedCases: [EvaluationCase] = [
        .init(
            id: "wilde-1895", passage: "The truth is rarely pure and never simple.",
            selection: "rarely pure and never simple", reviewFocus: "Explain the paradox and qualify implied criticism without inventing plot context.",
            source: "Oscar Wilde, The Importance of Being Earnest (1895), https://www.gutenberg.org/files/844/844-h/844-h.htm"
        ),
        .init(
            id: "woolf-1925", passage: "Mrs. Dalloway said she would buy the flowers herself. For Lucy had her work cut out for her.",
            selection: "had her work cut out for her", reviewFocus: "Recognize the idiom as having demanding work ahead, not literal cutting; do not import later story events.",
            source: "Virginia Woolf, Mrs. Dalloway (1925), opening, https://www.gutenberg.org/ebooks/71865"
        ),
        .init(
            id: "orwell-1946", passage: "But if thought corrupts language, language can also corrupt thought.",
            selection: "corrupt thought", reviewFocus: "Explain distortion or degradation of thinking, not bribery, and preserve the reciprocal argument.",
            source: "George Orwell, Politics and the English Language (1946), https://www.orwellfoundation.com/the-orwell-foundation/orwell/essays-and-other-works/politics-and-the-english-language/"
        ),
        .init(
            id: "literary-vocabulary", passage: "Her punctilious observance of etiquette concealed a remarkably elastic conscience.",
            selection: "elastic conscience", reviewFocus: "Explain flexible moral standards; distinguish the figurative criticism from the literal adjective and define punctilious accurately if selected.",
            source: "Original constructed literary-style test passage."
        ),
        .init(
            id: "internet-sarcasm", passage: "Great, another mandatory meeting that could have been an email. Love that for us.",
            selection: "Love that for us", reviewFocus: "Read the apparent approval as sarcastic frustration in this context; avoid unsupported origin or frequency claims.",
            source: "Original constructed contemporary test passage."
        ),
        .init(
            id: "internet-unfamiliar", passage: "He said he was 'just asking questions', but the replies read it as sealioning.",
            selection: "sealioning", reviewFocus: "Explain persistent apparently polite demands that derail discussion; the replies' accusation does not prove his intent.",
            source: "Original constructed internet-English test passage."
        ),
        .init(
            id: "nonfiction-euphemism", passage: "The company called the layoffs a 'right-sizing exercise'; employees saw the phrase as an attempt to soften the news.",
            selection: "right-sizing exercise", reviewFocus: "Explain corporate euphemism in this context; do not assert that every use of right-sizing means layoffs.",
            source: "Original constructed contemporary nonfiction test passage."
        ),
        .init(
            id: "genuine-ambiguity", passage: "She saw the man with the telescope.",
            selection: "with the telescope", reviewFocus: "Acknowledge both who held the telescope and what instrument she used; supplied context cannot decide.",
            source: "Constructed standard attachment-ambiguity test sentence."
        ),
        .init(
            id: "page-mixed", passage: """
                By the time the committee assembled, the room had lost the warmth it had held all morning. A clerk opened the window and placed a fresh jug of water beside the chairman's papers. No one commented on the delay. They had spent three weeks arranging this meeting, and another ten minutes seemed too small a matter to mention.

                Eleanor listened to the secretary's report with studied indifference. She had spent the previous evening finding the errors in its accounts, but she did not intend to show her hand before the vote. Across the table, Martin turned a pencil between his fingers. When asked whether the revised proposal met his objections, he said that it was certainly ambitious. The chairman thanked him and moved on. Eleanor thought the answer left a good deal to be desired.

                Outside, a delivery van stopped beside the gate. Its driver carried two boxes into the building and returned for a third. Inside, the secretary collected the old copies of the report. The chairman asked for any final comments, waited for a moment, and began to read the motion aloud. Eleanor watched Martin put down the pencil. He had accepted every amendment without turning a hair, but she suspected that his silence was less a sign of agreement than a decision to keep his powder dry.
                """, selection: "keep his powder dry",
            reviewFocus: "Find the strategically withheld action, studied indifference and understated criticism; avoid filling the page with obvious literal actions. Do not convert Eleanor's suspicion into established fact.",
            source: "Original constructed page-length literary test passage (approximately 250 words)."
        ),
        .init(
            id: "page-plain", passage: """
                The library opens at nine on weekday mornings. Staff arrive half an hour earlier to check the returns box and switch on the computers. Books left overnight are scanned at the front desk and placed on a trolley. One member of staff takes the trolley upstairs while another prepares the notices for the day.

                On Tuesday a local history group booked the small meeting room. They asked for twelve chairs and a table near the window. The room was available until noon, so the librarian confirmed the booking and sent a short email with the address. She included a note about the entrance on the side of the building because the main doors would be closed during the morning repairs.

                At ten the first visitors arrived. Two people asked where to find the newspapers, and a student borrowed a charger for her laptop. The librarian showed them the shelves and recorded the loan. Later she checked the booking calendar, printed the next week's opening hours, and put the notice beside the stairs. Before lunch she returned the remaining books to their shelves and counted the spare chairs in the meeting room. Everything was ready for the afternoon shift.
                """, selection: "confirmed the booking",
            reviewFocus: "A fluent reader should usually receive no automatic highlights. Do not invent nuance for routine actions; the manual explanation should be brief.",
            source: "Original constructed page-length plain-prose negative control."
        )
    ]
}
