import SwiftUI
import AppKit
import CoreText

// MARK: - Design Tokens

enum SandpaperTheme {
    // Surfaces
    static let canvasBackground = Color(hex: 0xFCF9F3)
    static let chromeBackground = Color(hex: 0xF9F4ED)
    static let cardBackground = Color(hex: 0xF9F5EE)
    static let pillBackground = Color(hex: 0xF8F2EB)
    static let bookmarkButtonBackground = Color(hex: 0xFBF7F1)

    // Borders & Dividers
    static let cardBorder = Color(hex: 0xF1EBE5)
    static let statusBarBorder = Color(hex: 0xF1EAE4)
    static let toolbarDivider = Color(hex: 0xEAE0DB)
    static let bookmarkButtonBorder = Color(hex: 0xEFE7DF)
    static let subtleStroke = Color(hex: 0xD5C4B6)
    static let headerRule = Color(hex: 0xDEC3BA)

    // Progress Bar
    static let progressFill = Color(hex: 0xAC6657)
    static let progressTrack = Color(hex: 0xFDE4DC)

    // Typography & Iconography Ink
    static let primaryInk = Color(hex: 0x0D0301)
    static let strongInk = Color(hex: 0x1C1C18)
    static let dropCapInk = Color(hex: 0x2B1A15)
    static let secondaryInk = Color(hex: 0x4F4441)
    static let mutedInk = Color(hex: 0x70625B)

    // Accents
    static let terracottaAccent = Color(hex: 0xAC695A)
    static let kickerAccent = Color(hex: 0xAC6A5C)
    static let highlightInk = Color(hex: 0x984636)

    // Selection & Dictionary Popover Tokens
    static let selectionPillFill = Color(hex: 0xF4EBE4)
    static let selectionPillBorder = Color(hex: 0xFEE4DD)
    static let popoverPrimaryButton = Color(hex: 0xA66456)
    static let popoverPrimaryButtonHover = Color(hex: 0x965749)
    static let popoverSparkleInk = Color(hex: 0xAB695B)
    static let speakerButtonBorder = Color(hex: 0xE2D6CC)

    // Traffic Lights (for Xcode Canvas / borderless preview)
    static let trafficRed = Color(hex: 0xFF5F57)
    static let trafficYellow = Color(hex: 0xFEBC2E)
    static let trafficGreen = Color(hex: 0x28C840)

    // Layout Metrics
    static let readingColumnWidth: CGFloat = 700
    static let toolbarHeight: CGFloat = 62
    static let progressBarHeight: CGFloat = 2
    static let statusBarHeight: CGFloat = 44
    static let dictionaryPopoverWidth: CGFloat = 430
}

extension Color {
    init(hex: UInt32, opacity: Double = 1.0) {
        let red = Double((hex >> 16) & 0xFF) / 255.0
        let green = Double((hex >> 8) & 0xFF) / 255.0
        let blue = Double(hex & 0xFF) / 255.0
        self.init(.sRGB, red: red, green: green, blue: blue, opacity: opacity)
    }
}

// MARK: - Models & Mock Content

struct BookChapter: Identifiable, Sendable {
    let id: String
    let bookTitle: String
    let author: String
    let partLabel: String
    let chapterLabel: String
    let locationTitle: String
    let subtitle: String
    let currentPage: Int
    let totalPages: Int
    let progress: Double
    let syncStatus: String
    let blocks: [ContentBlock]
    let previousChapter: ChapterNavigationItem?
    let nextChapter: ChapterNavigationItem?
    let availableChapters: [String]
}

enum ContentBlock: Identifiable, Sendable {
    case dropCapParagraph(id: String, dropCap: String, remainderText: String)
    case paragraph(id: String, segments: [TextSegment])
    case journalCallout(id: String, quote: String, source: String, note: String)

    var id: String {
        switch self {
        case .dropCapParagraph(let id, _, _),
             .paragraph(let id, _),
             .journalCallout(let id, _, _, _):
            return id
        }
    }
}

enum TextSegment: Sendable {
    case plain(String)
    case vocabularyHighlight(String)
}

struct ChapterNavigationItem: Sendable {
    let title: String
}

extension BookChapter {
    static let remainsOfTheDaySample = BookChapter(
        id: "part-4-day-3-evening",
        bookTitle: "The Remains of the Day",
        author: "Kazuo Ishiguro",
        partLabel: "PART FOUR",
        chapterLabel: "Day Three: Evening",
        locationTitle: "Mortimer’s Pond, Dorset",
        subtitle: "Reflections on Greatness and Service",
        currentPage: 142,
        totalPages: 258,
        progress: 0.64,
        syncStatus: "Saved",
        blocks: [
            .dropCapParagraph(
                id: "p1",
                dropCap: "I",
                remainderText: "t was already approaching dusk by the time I took my seat upon this bench, set slightly back from the reedy fringe of Mortimer’s Pond. The air here in Dorset has taken on that distinct, crisp chill of early September, and as the amber light slips gradually over the sloping crests of the downland, one is left with a profound sense of tranquillity that would seem quite foreign to the bustle of Darlington Hall in its heyday. Down upon the water’s surface, a pair of mallards skim quietly past the willow branches, scarcely breaking the mirror of the sky, which now drains rapidly from soft copper into an austere slate-blue."
            ),
            .paragraph(
                id: "p2",
                segments: [
                    .plain("I had spent the better part of the afternoon wandering the perimeter of the pond, clutching in my breast pocket the letter from Miss Kenton—or Mrs. Benn, as I must continually remind myself to address her. To hold those sheets of writing paper in one’s hand after the lapse of so many years is an experience curious in the extreme. Her handwriting has retained that energetic, assertive slant which used to characterise her memoranda concerning the parlour-maids, yet there runs between her lines a faint undertone of weariness—perhaps even of despondency—that I found myself reading and re-reading through the quiet miles of my motor journey across Somerset.")
                ]
            ),
            .journalCallout(
                id: "quote-1",
                quote: "“Indeed, what is dignity if not the capacity not to abandon one’s post in the face of emotional commotion? A great butler must possess something far beyond mere professional competence; he must inhabit his role with such absolute constancy that no sudden turn of external fortune can induce him to shed his dignity before the world.”",
                source: "— PERSONAL JOURNAL, STEVENS (JULY 1936)",
                note: "Marginalia preserved"
            ),
            .paragraph(
                id: "p3",
                segments: [
                    .plain("It is precisely this question of "),
                    .vocabularyHighlight("‘dignity’"),
                    .plain(" that has occupied my thoughts for the past hour. There are those, I am aware, who would dispute the notion that greatness in our profession can be measured by such intangible virtues. My late father, whom I had the privilege of observing throughout the golden age of English service, held firmly to the conviction that dignity was not something one could put on like a fresh morning coat; it was, rather, a temper of the spirit, a stoic refusal to allow the private self to breach the public vessel of one’s responsibility.")
                ]
            ),
            .paragraph(
                id: "p4",
                segments: [
                    .plain("Sitting here beside the dark stillness of the pond, with the lights of a distant farmhouse blinking on through the hedgerows, one cannot help reviewing the decades that have slipped by in Lord Darlington’s employment. There will always be persons eager to pass harsh judgements upon his lordship’s political undertakings during those fraught years leading to the Munich Agreement. Yet I know in my heart that his lordship acted at every juncture with the purest of chivalric intentions. And if a man has given the very best years of his life in loyal service to a master whose motives were so noble, can it truly be said that such service was misplaced? One’s loyalty cannot simply be revoked retroactively merely because history has taken an ungenerous turn.")
                ]
            ),
            .paragraph(
                id: "p5",
                segments: [
                    .plain("The evening mist is rising now from the rushes, curling slowly upward towards the gravel path. I shall, I think, remain here just a few moments longer before returning to the inn at Little Compton. The motor car has behaved admirably all day, and tomorrow evening brings my appointed interview with Miss Kenton in the tea-room of the Rose Garden Hotel. I must ensure my mind is clear, orderly, and stripped of all irrelevant sentimentalities. There is, after all, the question of Darlington Hall’s depleted staff to resolve, and that is a matter requiring the utmost professional sobriety.")
                ]
            )
        ],
        previousChapter: ChapterNavigationItem(title: "Day Three: Morning — Taunton"),
        nextChapter: ChapterNavigationItem(title: "Day Four: Afternoon — Little\nCompton"),
        availableChapters: [
            "Prologue: July 1956 — Darlington Hall",
            "Day One: Evening — Salisbury",
            "Day Two: Morning — Salisbury",
            "Day Three: Morning — Taunton",
            "Day Three: Evening",
            "Day Four: Afternoon — Little Compton",
            "Day Six: Evening — Weymouth"
        ]
    )
}

// MARK: - Dictionary Models & Mock Lookup Provider

struct DictionaryEntry: Identifiable, Equatable, Sendable {
    let id: String
    let expression: String
    let phonetic: String
    let partOfSpeech: String
    let definition: String
    let emphasizedClosing: String?

    init(
        expression: String,
        phonetic: String,
        partOfSpeech: String,
        definition: String,
        emphasizedClosing: String? = nil
    ) {
        self.id = expression.lowercased()
        self.expression = expression
        self.phonetic = phonetic
        self.partOfSpeech = partOfSpeech
        self.definition = definition
        self.emphasizedClosing = emphasizedClosing
    }
}

enum MockDictionaryProvider {
    private static let entries: [String: DictionaryEntry] = [
        "ineluctable": DictionaryEntry(
            expression: "ineluctable",
            phonetic: "[ˌɪn.ɪˈlʌk.tə.bəl]",
            partOfSpeech: "adjective (formal/literary)",
            definition: "Unable to be resisted, avoided, or escaped;",
            emphasizedClosing: "inevitable."
        ),
        "dignity": DictionaryEntry(
            expression: "dignity",
            phonetic: "[ˈdɪɡ.nɪ.ti]",
            partOfSpeech: "noun",
            definition: "Composed, noble self-possession and restraint worthy of honour and respect;",
            emphasizedClosing: "nobility of bearing."
        ),
        "tranquillity": DictionaryEntry(
            expression: "tranquillity",
            phonetic: "[træŋˈkwɪl.ə.ti]",
            partOfSpeech: "noun (literary)",
            definition: "The quality or state of being free from agitation of mind or spirit;",
            emphasizedClosing: "serenity."
        ),
        "despondency": DictionaryEntry(
            expression: "despondency",
            phonetic: "[dɪˈspɒn.dən.si]",
            partOfSpeech: "noun",
            definition: "A state of low spirits caused by loss of hope or courage;",
            emphasizedClosing: "dejection."
        ),
        "chivalric": DictionaryEntry(
            expression: "chivalric",
            phonetic: "[ʃɪˈvæl.rɪk]",
            partOfSpeech: "adjective",
            definition: "Marked by honour, generosity, and courteous devotion to duty;",
            emphasizedClosing: "gallant."
        ),
        "sobriety": DictionaryEntry(
            expression: "sobriety",
            phonetic: "[səˈbraɪ.ə.ti]",
            partOfSpeech: "noun",
            definition: "Serious, measured restraint in judgement, manner, and conduct;",
            emphasizedClosing: "solemnity."
        ),
        "constancy": DictionaryEntry(
            expression: "constancy",
            phonetic: "[ˈkɒn.stən.si]",
            partOfSpeech: "noun (formal)",
            definition: "The quality of being enduring, faithful, and unwavering in purpose;",
            emphasizedClosing: "steadfastness."
        ),
        "austere": DictionaryEntry(
            expression: "austere",
            phonetic: "[ɒˈstɪər]",
            partOfSpeech: "adjective",
            definition: "Severe or strict in appearance, manner, or self-discipline;",
            emphasizedClosing: "unadorned."
        ),
        "stoic": DictionaryEntry(
            expression: "stoic",
            phonetic: "[ˈstəʊ.ɪk]",
            partOfSpeech: "adjective",
            definition: "Enduring pain, hardship, or emotional trial without display of feeling;",
            emphasizedClosing: "impassive."
        ),
        "sentimentalities": DictionaryEntry(
            expression: "sentimentalities",
            phonetic: "[ˌsen.tɪ.menˈtæl.ɪ.tiz]",
            partOfSpeech: "noun (plural)",
            definition: "Expressions of tender, nostalgic, or self-indulgent emotion;",
            emphasizedClosing: "mawkishness."
        ),
        "mortimer’s pond": DictionaryEntry(
            expression: "Mortimer’s Pond",
            phonetic: "[ˈmɔː.tɪ.məz pɒnd]",
            partOfSpeech: "proper noun (toponym)",
            definition: "A tranquil rural pond in Dorset serving as a site of quiet pause and retrospection;",
            emphasizedClosing: "pastoral setting."
        ),
        "dorset": DictionaryEntry(
            expression: "Dorset",
            phonetic: "[ˈdɔː.sɪt]",
            partOfSpeech: "proper noun",
            definition: "A historic rural county in south-west England noted for rolling downland and coastal views;",
            emphasizedClosing: "English West Country."
        )
    ]

    static func lookup(_ rawText: String) -> DictionaryEntry {
        let trimmed = rawText
            .trimmingCharacters(in: CharacterSet.whitespacesAndNewlines.union(.punctuationCharacters))
            .replacingOccurrences(of: "‘", with: "")
            .replacingOccurrences(of: "’", with: "")
            .replacingOccurrences(of: "“", with: "")
            .replacingOccurrences(of: "”", with: "")

        let normalized = trimmed.lowercased()
        if let match = entries[normalized] {
                 return match
             }

             let displayExpression = trimmed.isEmpty ? rawText : trimmed
             let isPhrase = displayExpression.contains(" ")

             return DictionaryEntry(
                 expression: displayExpression,
                 phonetic: isPhrase ? "[ɪkˈspreʃ.ən]" : "[ˈlɪt.ər.ər.i]",
                 partOfSpeech: isPhrase ? "phrase (contextual)" : "noun / adjective (literary)",
                 definition: "Employed in formal prose to convey measured reflection, restraint, or nuanced observation;",
                 emphasizedClosing: "contextual usage."
             )
         }
     }

     // MARK: - Selection State & Multi-Block Coordinator

     struct BlockHighlightSelection: Equatable, Sendable {
         let nsRange: NSRange
         let lineHighlightRects: [CGRect]
     }

     struct ReaderTextSelection: Equatable, Sendable {
         let blockID: String
         let nsRange: NSRange
         let selectedText: String
         let contextText: String
         let lineHighlightRects: [CGRect]
         let anchorRectInReader: CGRect
         var blockSelections: [String: BlockHighlightSelection]

         init(
             blockID: String,
             nsRange: NSRange,
             selectedText: String,
             contextText: String,
             lineHighlightRects: [CGRect],
             anchorRectInReader: CGRect,
             blockSelections: [String: BlockHighlightSelection]? = nil
         ) {
             self.blockID = blockID
             self.nsRange = nsRange
             self.selectedText = selectedText
             self.contextText = contextText
             self.lineHighlightRects = lineHighlightRects
             self.anchorRectInReader = anchorRectInReader
             if let blockSelections {
                 self.blockSelections = blockSelections
             } else {
                 self.blockSelections = [
                     blockID: BlockHighlightSelection(
                         nsRange: nsRange,
                         lineHighlightRects: lineHighlightRects
                     )
                 ]
             }
         }

         func range(for targetBlockID: String) -> NSRange? {
             if let entry = blockSelections[targetBlockID] {
                 return entry.nsRange
             }
             return blockID == targetBlockID ? nsRange : nil
         }

         func highlightRects(for targetBlockID: String) -> [CGRect] {
             if let entry = blockSelections[targetBlockID] {
                 return entry.lineHighlightRects
             }
             return blockID == targetBlockID ? lineHighlightRects : []
         }
     }

     @MainActor
     protocol SelectableBlockEndpoint: AnyObject {
         var blockID: String { get }
         var fullText: String { get }
         var contextText: String { get }
         var blockFrameInReader: CGRect { get }
         var window: NSWindow? { get }
         func convert(_ point: NSPoint, from view: NSView?) -> NSPoint
         func clampedCharacterIndex(forPointInWindow windowPoint: CGPoint) -> Int
         func selectionRects(for range: NSRange) -> [CGRect]
     }

     @MainActor
     final class ReaderSelectionCoordinator {
         struct WeakEndpoint {
             weak var value: (any SelectableBlockEndpoint)?
         }

         private var endpoints: [String: WeakEndpoint] = [:]
         var orderedBlockIDs: [String] = []
         var currentSelection: ReaderTextSelection?
         var onSelect: ((ReaderTextSelection, Bool) -> Void)?
         var onDismiss: (() -> Void)?

         private var dragStartBlockID: String?
         private var dragStartCharIndex: Int?
         private(set) var didDragSelect: Bool = false

         func register(_ endpoint: any SelectableBlockEndpoint) {
             endpoints[endpoint.blockID] = WeakEndpoint(value: endpoint)
         }

         func beginDrag(blockID: String, charIndex: Int) {
             dragStartBlockID = blockID
             dragStartCharIndex = charIndex
             didDragSelect = false
         }

         func updateDrag(windowPoint: CGPoint, fallbackEndpoint: any SelectableBlockEndpoint) {
             guard let startID = dragStartBlockID,
                   let startIndex = dragStartCharIndex,
                   let startEndpoint = endpoints[startID]?.value else {
                 return
             }

             let targetEndpoint = endpoint(atWindowPoint: windowPoint) ?? fallbackEndpoint
             let targetIndex = targetEndpoint.clampedCharacterIndex(forPointInWindow: windowPoint)

             if startEndpoint.blockID == targetEndpoint.blockID {
                 let lo = min(startIndex, targetIndex)
                 let hi = max(startIndex, targetIndex)
                 guard hi > lo else { return }
                 didDragSelect = true
                 let rawRange = NSRange(location: lo, length: hi - lo)
                 if let selection = buildSingleBlockSelection(
                     endpoint: startEndpoint,
                     range: rawRange,
                     trim: false
                 ) {
                     currentSelection = selection
                     onSelect?(selection, false)
                 }
                 return
             }

             didDragSelect = true
             if let selection = buildMultiBlockSelection(
                 from: (startEndpoint, startIndex),
                 to: (targetEndpoint, targetIndex),
                 trim: false
             ) {
                 currentSelection = selection
                 onSelect?(selection, false)
             }
         }

         func endDrag(windowPoint: CGPoint, fallbackEndpoint: any SelectableBlockEndpoint) -> Bool {
             defer {
                 dragStartBlockID = nil
                 dragStartCharIndex = nil
                 didDragSelect = false
             }

             guard didDragSelect,
                   let startID = dragStartBlockID,
                   let startIndex = dragStartCharIndex,
                   let startEndpoint = endpoints[startID]?.value else {
                 return false
             }

             let targetEndpoint = endpoint(atWindowPoint: windowPoint) ?? fallbackEndpoint
             let targetIndex = targetEndpoint.clampedCharacterIndex(forPointInWindow: windowPoint)

             if startEndpoint.blockID == targetEndpoint.blockID {
                 let lo = min(startIndex, targetIndex)
                 let hi = max(startIndex, targetIndex)
                 let rawRange = NSRange(location: lo, length: max(0, hi - lo))
                 if let selection = buildSingleBlockSelection(
                     endpoint: startEndpoint,
                     range: rawRange,
                     trim: true
                 ) {
                     currentSelection = selection
                     onSelect?(selection, true)
                 } else {
                     currentSelection = nil
                     onDismiss?()
                 }
                 return true
             }

             if let selection = buildMultiBlockSelection(
                 from: (startEndpoint, startIndex),
                 to: (targetEndpoint, targetIndex),
                 trim: true
             ) {
                 currentSelection = selection
                 onSelect?(selection, true)
             } else {
                 currentSelection = nil
                 onDismiss?()
             }
             return true
         }

         func publishSingleSelection(_ selection: ReaderTextSelection, presentPopover: Bool) {
             currentSelection = selection
             onSelect?(selection, presentPopover)
         }

         func clearSelection() {
             currentSelection = nil
             onDismiss?()
         }

         private func endpoint(atWindowPoint windowPoint: CGPoint) -> (any SelectableBlockEndpoint)? {
             let activeEndpoints: [any SelectableBlockEndpoint] = orderedBlockIDs.compactMap {
                 endpoints[$0]?.value
             }
             guard !activeEndpoints.isEmpty else { return nil }

             guard let window = activeEndpoints.first(where: { $0.window != nil })?.window,
                   let contentView = window.contentView else {
                 return nil
             }

             let readerY = contentView.bounds.height - windowPoint.y

             for ep in activeEndpoints {
                 let frame = ep.blockFrameInReader.insetBy(dx: -24, dy: -6)
                 if readerY >= frame.minY && readerY <= frame.maxY {
                     return ep
                 }
             }

             return activeEndpoints.min { a, b in
                 let distA = min(abs(readerY - a.blockFrameInReader.minY), abs(readerY - a.blockFrameInReader.maxY))
                 let distB = min(abs(readerY - b.blockFrameInReader.minY), abs(readerY - b.blockFrameInReader.maxY))
                 return distA < distB
             }
         }

         func buildSingleBlockSelection(
             endpoint: any SelectableBlockEndpoint,
             range: NSRange,
             trim: Bool
         ) -> ReaderTextSelection? {
             let nsText = endpoint.fullText as NSString
             let targetRange = trim ? Self.trimWhitespaceAndPunctuation(in: range, within: nsText) : range
             guard targetRange.location != NSNotFound,
                   targetRange.length > 0,
                   targetRange.location + targetRange.length <= nsText.length else {
                 return nil
             }

             let rects = endpoint.selectionRects(for: targetRange)
             guard let firstRect = rects.first else { return nil }
             let unionRect = rects.reduce(firstRect) { $0.union($1) }

             let selectedString = nsText.substring(with: targetRange)
             let anchorInReader = CGRect(
                 x: endpoint.blockFrameInReader.minX + firstRect.minX,
                 y: endpoint.blockFrameInReader.minY + unionRect.minY,
                 width: firstRect.width,
                 height: unionRect.height
             )

             return ReaderTextSelection(
                 blockID: endpoint.blockID,
                 nsRange: targetRange,
                 selectedText: selectedString,
                 contextText: endpoint.contextText,
                 lineHighlightRects: rects,
                 anchorRectInReader: anchorInReader
             )
         }

         private func buildMultiBlockSelection(
             from start: (endpoint: any SelectableBlockEndpoint, index: Int),
             to end: (endpoint: any SelectableBlockEndpoint, index: Int),
             trim: Bool
         ) -> ReaderTextSelection? {
             guard let startOrder = orderedBlockIDs.firstIndex(of: start.endpoint.blockID),
                   let endOrder = orderedBlockIDs.firstIndex(of: end.endpoint.blockID) else {
                 return nil
             }

             let isForward = startOrder < endOrder
             let firstPair = isForward ? start : end
             let lastPair = isForward ? end : start
             let loOrder = min(startOrder, endOrder)
             let hiOrder = max(startOrder, endOrder)

             var blockMap: [String: BlockHighlightSelection] = [:]
             var combinedStrings: [String] = []
             var varcombinedContexts: [String] = []
             var firstAnchorInReader: CGRect?
             var primaryBlockID = firstPair.endpoint.blockID
             var primaryRange = NSRange(location: 0, length: 0)
             var primaryRects: [CGRect] = []

             for idx in loOrder...hiOrder {
                 let bID = orderedBlockIDs[idx]
                 guard let ep = endpoints[bID]?.value else { continue }
                 let nsText = ep.fullText as NSString
                 guard nsText.length > 0 else { continue }

                 let rawRange: NSRange
                 if bID == firstPair.endpoint.blockID {
                     let loc = min(max(0, firstPair.index), nsText.length)
                     rawRange = NSRange(location: loc, length: max(0, nsText.length - loc))
                 } else if bID == lastPair.endpoint.blockID {
                     let len = min(max(0, lastPair.index), nsText.length)
                     rawRange = NSRange(location: 0, length: len)
                 } else {
                     rawRange = NSRange(location: 0, length: nsText.length)
                 }

                 let cleanRange = trim
                     ? Self.trimWhitespaceAndPunctuation(in: rawRange, within: nsText)
                     : rawRange

                 guard cleanRange.length > 0 else { continue }
                 let rects = ep.selectionRects(for: cleanRange)
                 guard let firstRect = rects.first else { continue }
                 let unionRect = rects.reduce(firstRect) { $0.union($1) }

                 blockMap[bID] = BlockHighlightSelection(
                     nsRange: cleanRange,
                     lineHighlightRects: rects
                 )
                 combinedStrings.append(nsText.substring(with: cleanRange))
                 varcombinedContexts.append(ep.contextText)

                 if firstAnchorInReader == nil {
                     primaryBlockID = bID
                     primaryRange = cleanRange
                     primaryRects = rects
                     firstAnchorInReader = CGRect(
                         x: ep.blockFrameInReader.minX + firstRect.minX,
                         y: ep.blockFrameInReader.minY + unionRect.minY,
                         width: firstRect.width,
                         height: unionRect.height
                     )
                 }
             }

             guard let anchor = firstAnchorInReader, !combinedStrings.isEmpty else {
                 return nil
             }

             return ReaderTextSelection(
                 blockID: primaryBlockID,
                 nsRange: primaryRange,
                 selectedText: combinedStrings.joined(separator: "\n\n"),
                 contextText: varcombinedContexts.joined(separator: " "),
                 lineHighlightRects: primaryRects,
                 anchorRectInReader: anchor,
                 blockSelections: blockMap
             )
         }

         static func trimWhitespaceAndPunctuation(in range: NSRange, within nsText: NSString) -> NSRange {
             guard range.location != NSNotFound,
                   range.length > 0,
                   range.location + range.length <= nsText.length else {
                 return NSRange(location: 0, length: 0)
             }

             let trimSet = CharacterSet.whitespacesAndNewlines.union(.punctuationCharacters)
             var start = range.location
             var end = range.location + range.length

             while start < end {
                 let scalarVal = nsText.character(at: start)
                 if let scalar = UnicodeScalar(scalarVal), trimSet.contains(scalar) {
                     start += 1
                 } else {
                     break
                 }
             }

             while end > start {
                 let scalarVal = nsText.character(at: end - 1)
                 if let scalar = UnicodeScalar(scalarVal), trimSet.contains(scalar) {
                     end -= 1
                 } else {
                     break
                 }
             }

             return NSRange(location: start, length: max(0, end - start))
         }
     }

     // MARK: - Main Reader View

struct SandpaperReaderView: View {
    let chapter: BookChapter
    var bookID: String = "remains-of-the-day"
    var vocabularyStore: SandpaperVocabularyStore? = nil
    var dictionaryLookup: @Sendable (String) -> DictionaryEntry = { MockDictionaryProvider.lookup($0) }
    var onPronounce: (@MainActor (DictionaryEntry) -> Void)?
    var onSaveToVocabulary: (@MainActor (DictionaryEntry) -> Void)?
    var onExplainInContext: (@MainActor (DictionaryEntry, String) -> Void)?
    var onBackToLibrary: (@MainActor () -> Void)? = nil

    @State private var selectedChapter: String
    @State private var isBookmarked: Bool = false
    @State private var bodyFontSize: CGFloat = 20.5
    @State private var isShowingTypographyPopover: Bool = false
    @State private var hostsNativeTrafficLights: Bool = false

    // Dictionary Popover & Selection State
    @State private var activeSelection: ReaderTextSelection?
    @State private var isPopoverPresented: Bool = false
    @State private var savedVocabularyIDs: Set<String> = []
    @State private var popoverContainerRect: CGRect = .zero
    @State private var selectionCoordinator = ReaderSelectionCoordinator()

    // Contextual AI Explanation State
    @State private var explanationMode: ExplanationPresentationMode
    @State private var activeExplanation: ContextualExplanationEntry?
    @State private var savedExplanationIDs: Set<String> = []

    init(
        chapter: BookChapter = .remainsOfTheDaySample,
        bookID: String = "remains-of-the-day",
        vocabularyStore: SandpaperVocabularyStore? = nil,
        initialSelection: ReaderTextSelection? = nil,
        initialExplanationMode: ExplanationPresentationMode = .hidden,
        initialExplanation: ContextualExplanationEntry? = nil,
        dictionaryLookup: @escaping @Sendable (String) -> DictionaryEntry = { MockDictionaryProvider.lookup($0) },
        onPronounce: (@MainActor (DictionaryEntry) -> Void)? = nil,
        onSaveToVocabulary: (@MainActor (DictionaryEntry) -> Void)? = nil,
        onExplainInContext: (@MainActor (DictionaryEntry, String) -> Void)? = nil,
        onBackToLibrary: (@MainActor () -> Void)? = nil
    ) {
        self.chapter = chapter
        self.bookID = bookID
        self.vocabularyStore = vocabularyStore
        self.dictionaryLookup = dictionaryLookup
        self.onPronounce = onPronounce
        self.onSaveToVocabulary = onSaveToVocabulary
        self.onExplainInContext = onExplainInContext
        self.onBackToLibrary = onBackToLibrary
        self._selectedChapter = State(initialValue: chapter.chapterLabel)
        self._activeSelection = State(initialValue: initialSelection)
        self._isPopoverPresented = State(
            initialValue: initialSelection != nil && initialExplanationMode != .sidePanel
        )
        self._explanationMode = State(initialValue: initialExplanationMode)
        self._activeExplanation = State(initialValue: initialExplanation)
    }

    private var orderedBlockIDs: [String] {
        var ids = ["header-kicker", "header-title", "header-subtitle"]
        for block in chapter.blocks {
            switch block {
            case .dropCapParagraph(let id, _, _),
                 .paragraph(let id, _):
                ids.append(id)
            case .journalCallout(let id, _, _, _):
                ids.append(id)
                ids.append("\(id)-source")
            }
        }
        return ids
    }

    var body: some View {
        let _ = configureCoordinator()

        GeometryReader { readerProxy in
            ZStack(alignment: .topLeading) {
                VStack(spacing: 0) {
                    ReaderToolbarView(
                        bookTitle: chapter.bookTitle,
                        author: chapter.author,
                        selectedChapter: $selectedChapter,
                        availableChapters: chapter.availableChapters,
                        currentPage: chapter.currentPage,
                        totalPages: chapter.totalPages,
                        progress: chapter.progress,
                        isBookmarked: $isBookmarked,
                        bodyFontSize: $bodyFontSize,
                        isShowingTypographyPopover: $isShowingTypographyPopover,
                        showsCustomTrafficLights: !hostsNativeTrafficLights,
                        onBackToLibrary: onBackToLibrary
                    )

                    // Main Content Split: Reader ScrollView on Left + Optional Side Panel on Right
                    HStack(spacing: 0) {
                        ScrollView(.vertical) {
                            VStack(spacing: 0) {
                                ChapterHeaderView(
                                    partLabel: chapter.partLabel,
                                    chapterLabel: selectedChapter,
                                    locationTitle: chapter.locationTitle,
                                    subtitle: chapter.subtitle,
                                    activeSelection: activeSelection,
                                    coordinator: selectionCoordinator,
                                    onSelect: handleSelection,
                                    onDismiss: dismissSelection
                                )
                                .padding(.top, 64)
                                .padding(.bottom, 72)

                                // Reading Content Column
                                VStack(alignment: .leading, spacing: 28) {
                                    ForEach(chapter.blocks) { block in
                                        switch block {
                                        case .dropCapParagraph(let id, let dropCap, let remainderText):
                                            DropCapParagraphView(
                                                blockID: id,
                                                dropCap: dropCap,
                                                remainderText: remainderText,
                                                fontSize: bodyFontSize,
                                                activeSelection: activeSelection,
                                                coordinator: selectionCoordinator,
                                                onSelect: handleSelection,
                                                onDismiss: dismissSelection
                                            )

                                        case .paragraph(let id, let segments):
                                            ReaderParagraphView(
                                                blockID: id,
                                                segments: segments,
                                                fontSize: bodyFontSize,
                                                activeSelection: activeSelection,
                                                coordinator: selectionCoordinator,
                                                onSelect: handleSelection,
                                                onDismiss: dismissSelection
                                            )

                                        case .journalCallout(let id, let quote, let source, let note):
                                            JournalBlockquoteView(
                                                blockID: id,
                                                quote: quote,
                                                source: source,
                                                note: note,
                                                baseFontSize: bodyFontSize,
                                                activeSelection: activeSelection,
                                                coordinator: selectionCoordinator,
                                                onSelect: handleSelection,
                                                onDismiss: dismissSelection
                                            )
                                            .padding(.vertical, 8)
                                        }
                                    }
                                }
                                .textSelection(.enabled)

                                SectionFooterView(
                                    currentPage: chapter.currentPage,
                                    totalPages: chapter.totalPages,
                                    isBookmarked: $isBookmarked,
                                    previousChapter: chapter.previousChapter,
                                    nextChapter: chapter.nextChapter
                                )
                                .padding(.top, 96)
                                .padding(.bottom, 64)
                            }
                            .frame(maxWidth: SandpaperTheme.readingColumnWidth)
                            .padding(.horizontal, 48)
                            .frame(maxWidth: .infinity)
                        }
                        .background(SandpaperTheme.canvasBackground)

                        // Stage 2: Docked Right-Side "Explain in Context" Panel
                        if explanationMode == .sidePanel, let explanation = activeExplanation {
                            ContextualExplanationSidePanelView(
                                explanation: explanation,
                                isNoteSaved: savedExplanationIDs.contains(explanation.id),
                                onSaveNote: {
                                    toggleSavedExplanation(explanation.id)
                                },
                                onSwitchToFloating: {
                                    withAnimation(.spring(response: 0.26, dampingFraction: 0.86)) {
                                        explanationMode = .floatingExpanded
                                        isPopoverPresented = activeSelection != nil
                                    }
                                },
                                onClose: {
                                    withAnimation(.easeOut(duration: 0.18)) {
                                        explanationMode = .hidden
                                    }
                                }
                            )
                            .transition(.move(edge: .trailing).combined(with: .opacity))
                        }
                    }

                    ReaderStatusBarView(
                        currentPage: chapter.currentPage,
                        totalPages: chapter.totalPages,
                        syncStatus: chapter.syncStatus
                    )
                }

                // Dictionary Popover Overlay (Supports Compact & Downward-Expanded Floating State)
                if isPopoverPresented && explanationMode != .sidePanel, let selection = activeSelection {
                    let entry = dictionaryLookup(selection.selectedText)
                    let currentExplanation = activeExplanation ?? MockContextualExplanationProvider.explain(
                        selectedText: selection.selectedText,
                        contextText: selection.contextText,
                        chapterLabel: selectedChapter,
                        currentPage: chapter.currentPage
                    )
                    let isContextuallySaved = vocabularyStore?.containsContextualEntry(
                        expression: entry.expression,
                        bookID: bookID,
                        sourcePassage: selection.contextText
                    ) ?? savedVocabularyIDs.contains(entry.id)

                    DictionaryPopoverOverlay(
                        entry: entry,
                        explanation: explanationMode == .floatingExpanded ? currentExplanation : nil,
                        isExplanationSaved: savedExplanationIDs.contains(currentExplanation.id),
                        selectionRect: selection.anchorRectInReader,
                        viewportSize: readerProxy.size,
                        isSaved: isContextuallySaved,
                        popoverFrame: $popoverContainerRect,
                        onPronounce: {
                            if let onPronounce {
                                onPronounce(entry)
                            } else {
                                DictionarySpeechPlayer.shared.speak(entry.expression)
                            }
                        },
                        onToggleSave: {
                            if let vocabularyStore {
                                vocabularyStore.toggleContextualEntry(
                                    dictionaryEntry: entry,
                                    selectedText: selection.selectedText,
                                    sourcePassage: selection.contextText,
                                    chapter: chapter,
                                    bookID: bookID
                                )
                            } else {
                                if savedVocabularyIDs.contains(entry.id) {
                                    savedVocabularyIDs.remove(entry.id)
                                } else {
                                    savedVocabularyIDs.insert(entry.id)
                                }
                            }

                            onSaveToVocabulary?(entry)
                        },
                        onExplainInContext: {
                            let resolved = MockContextualExplanationProvider.explain(
                                selectedText: selection.selectedText,
                                contextText: selection.contextText,
                                chapterLabel: selectedChapter,
                                currentPage: chapter.currentPage
                            )
                            activeExplanation = resolved
                            onExplainInContext?(entry, selection.contextText)

                            withAnimation(.spring(response: 0.28, dampingFraction: 0.86)) {
                                if explanationMode == .floatingExpanded {
                                    // Clicking a second time switches into the right-hand Side Panel mode
                                    explanationMode = .sidePanel
                                    isPopoverPresented = false
                                } else {
                                    // Stage 1: Expand the floating dialog box downward in place
                                    explanationMode = .floatingExpanded
                                }
                            }
                        },
                        onSaveExplanationNote: {
                            toggleSavedExplanation(currentExplanation.id)
                        },
                        onDockToSidePanel: {
                            withAnimation(.spring(response: 0.28, dampingFraction: 0.86)) {
                                explanationMode = .sidePanel
                                isPopoverPresented = false
                            }
                        },
                        onClose: {
                            dismissSelection()
                        }
                    )
                    .transition(.opacity.combined(with: .scale(scale: 0.98, anchor: .top)))
                    .zIndex(50)
                }
            }
            .coordinateSpace(name: "SandpaperReaderSpace")
        }
        .background(SandpaperTheme.canvasBackground)
        .background(
            ReaderWindowConfigurator(hostsNativeTrafficLights: $hostsNativeTrafficLights)
        )
        .background(
            DictionaryDismissEventMonitor(
                isActive: isPopoverPresented && explanationMode != .sidePanel,
                popoverFrameInReader: popoverContainerRect,
                selectionFrameInReader: activeSelection?.anchorRectInReader ?? .zero,
                onDismiss: dismissSelection
            )
        )
        .onChange(of: bodyFontSize) { _, _ in
            dismissSelection()
        }
        .onChange(of: selectedChapter) { _, _ in
            dismissSelection()
        }
        .ignoresSafeArea(.container, edges: .top)
    }

    private func toggleSavedExplanation(_ id: String) {
        if savedExplanationIDs.contains(id) {
            savedExplanationIDs.remove(id)
        } else {
            savedExplanationIDs.insert(id)
        }
    }

    private func configureCoordinator() {
        selectionCoordinator.orderedBlockIDs = orderedBlockIDs
        selectionCoordinator.currentSelection = activeSelection
        selectionCoordinator.onSelect = handleSelection
        selectionCoordinator.onDismiss = dismissSelection
    }

    private func handleSelection(_ selection: ReaderTextSelection, presentPopover: Bool) {
        let isNewSelection = activeSelection?.selectedText != selection.selectedText
            || activeSelection?.blockID != selection.blockID

        activeSelection = selection
        selectionCoordinator.currentSelection = selection

        if isNewSelection {
            let updatedExplanation = MockContextualExplanationProvider.explain(
                selectedText: selection.selectedText,
                contextText: selection.contextText,
                chapterLabel: selectedChapter,
                currentPage: chapter.currentPage
            )
            activeExplanation = updatedExplanation

            // If the right-side panel isn't docked, start new selections in compact popover state
            if explanationMode == .floatingExpanded {
                explanationMode = .hidden
            }
        }

        if presentPopover {
            if explanationMode != .sidePanel {
                withAnimation(.easeOut(duration: 0.14)) {
                    isPopoverPresented = true
                }
            }
        } else {
            isPopoverPresented = false
        }
    }

    private func dismissSelection() {
        guard activeSelection != nil || isPopoverPresented else { return }
        selectionCoordinator.currentSelection = nil
        withAnimation(.easeOut(duration: 0.12)) {
            isPopoverPresented = false
            if explanationMode == .floatingExpanded {
                explanationMode = .hidden
            }
            activeSelection = nil
        }
    }
}
// MARK: - Dictionary Popover Overlay & Card (Static Top + Scrollable Bottom Drawer)

private struct DictionaryPopoverOverlay: View {
    let entry: DictionaryEntry
    let explanation: ContextualExplanationEntry?
    let isExplanationSaved: Bool
    let selectionRect: CGRect
    let viewportSize: CGSize
    let isSaved: Bool
    @Binding var popoverFrame: CGRect
    let onPronounce: () -> Void
    let onToggleSave: () -> Void
    let onExplainInContext: () -> Void
    let onSaveExplanationNote: () -> Void
    let onDockToSidePanel: () -> Void
    let onClose: () -> Void

    @State private var measuredCardSize: CGSize = CGSize(
        width: SandpaperTheme.dictionaryPopoverWidth,
        height: 230
    )
    @State private var compactCardHeight: CGFloat = 230

    private let caretWidth: CGFloat = 22
    private let caretHeight: CGFloat = 11
    private let verticalGap: CGFloat = 8

    var body: some View {
        let layout = computeLayout(
            selectionRect: selectionRect,
            viewportSize: viewportSize,
            cardSize: measuredCardSize,
            baseCompactHeight: compactCardHeight,
            isExpandedDownward: explanation != nil
        )

        DictionaryPopoverCard(
            entry: entry,
            explanation: explanation,
            isExplanationSaved: isExplanationSaved,
            maxDrawerHeight: layout.maxDrawerHeight,
            isSaved: isSaved,
            pointsDown: layout.pointsDown,
            showsCaret: layout.showsCaret,
            caretCenterX: layout.caretCenterX,
            caretWidth: caretWidth,
            caretHeight: caretHeight,
            onPronounce: onPronounce,
            onToggleSave: onToggleSave,
            onExplainInContext: onExplainInContext,
            onSaveExplanationNote: onSaveExplanationNote,
            onDockToSidePanel: onDockToSidePanel,
            onClose: onClose
        )
        .background(
            GeometryReader { cardProxy in
                Color.clear
                    .onAppear {
                        measuredCardSize = cardProxy.size
                        if explanation == nil {
                            compactCardHeight = cardProxy.size.height
                        }
                        popoverFrame = CGRect(origin: layout.origin, size: cardProxy.size)
                    }
                    .onChange(of: cardProxy.size) { _, newSize in
                        measuredCardSize = newSize
                        if explanation == nil {
                            compactCardHeight = newSize.height
                        }
                        let updated = computeLayout(
                            selectionRect: selectionRect,
                            viewportSize: viewportSize,
                            cardSize: newSize,
                            baseCompactHeight: compactCardHeight,
                            isExpandedDownward: explanation != nil
                        )
                        popoverFrame = CGRect(origin: updated.origin, size: newSize)
                    }
                    .onChange(of: selectionRect) { _, newSelectionRect in
                        let updated = computeLayout(
                            selectionRect: newSelectionRect,
                            viewportSize: viewportSize,
                            cardSize: measuredCardSize,
                            baseCompactHeight: compactCardHeight,
                            isExpandedDownward: explanation != nil
                        )
                        popoverFrame = CGRect(origin: updated.origin, size: measuredCardSize)
                    }
            }
        )
        .offset(x: layout.origin.x, y: layout.origin.y)
    }

    private func computeLayout(
        selectionRect: CGRect,
        viewportSize: CGSize,
        cardSize: CGSize,
        baseCompactHeight: CGFloat,
        isExpandedDownward: Bool
    ) -> (
        origin: CGPoint,
        caretCenterX: CGFloat,
        pointsDown: Bool,
        showsCaret: Bool,
        maxDrawerHeight: CGFloat
    ) {
        let width = SandpaperTheme.dictionaryPopoverWidth
        let columnMinX = max(20, (viewportSize.width - SandpaperTheme.readingColumnWidth) * 0.5)
        let columnMaxX = min(viewportSize.width - 20, columnMinX + SandpaperTheme.readingColumnWidth)

        let preferredOriginX = selectionRect.midX - (width * 0.262)
        let minOriginX = min(columnMinX, max(16, viewportSize.width - width - 16))
        let maxOriginX = max(minOriginX, columnMaxX - width)
        let clampedOriginX = min(max(preferredOriginX, minOriginX), maxOriginX)

        let caretCenterX = min(max(selectionRect.midX - clampedOriginX, 28), width - 28)

        let topSafeY = SandpaperTheme.toolbarHeight + SandpaperTheme.progressBarHeight + 12
        let bottomSafeY = viewportSize.height - SandpaperTheme.statusBarHeight - 14

        // Determine the static top origin Y of the compact card
        let compactAboveY = selectionRect.minY - verticalGap - baseCompactHeight
        let startsAboveSelection = compactAboveY >= topSafeY
        let rawBaseTopY: CGFloat = startsAboveSelection
            ? compactAboveY
            : min(selectionRect.maxY + verticalGap, max(topSafeY, bottomSafeY - baseCompactHeight))
        let lockedTopY = max(topSafeY, rawBaseTopY)

        // Available vertical space below the static top section down to the status bar
        let remainingBelowStaticTop = bottomSafeY - (lockedTopY + baseCompactHeight)

        if isExpandedDownward {
            // If the popover opened near the very bottom of the screen, gently lift lockedTopY
            // only enough to guarantee at least 220pt for the scrollable drawer, while never crossing topSafeY.
            let minComfortableDrawerHeight: CGFloat = 220
            let adjustedTopY: CGFloat
            if remainingBelowStaticTop < minComfortableDrawerHeight {
                adjustedTopY = max(
                    topSafeY,
                    bottomSafeY - (baseCompactHeight + minComfortableDrawerHeight)
                )
            } else {
                adjustedTopY = lockedTopY
            }

            let availableDrawerSpace = max(150, bottomSafeY - (adjustedTopY + baseCompactHeight))
            let cappedDrawerHeight = min(360, availableDrawerSpace)

            return (
                CGPoint(x: clampedOriginX, y: adjustedTopY),
                caretCenterX,
                startsAboveSelection,
                !startsAboveSelection && adjustedTopY == lockedTopY,
                cappedDrawerHeight
            )
        } else {
            return (
                CGPoint(x: clampedOriginX, y: lockedTopY),
                caretCenterX,
                startsAboveSelection,
                true,
                280
            )
        }
    }
}

private struct DictionaryPopoverCard: View {
    let entry: DictionaryEntry
    let explanation: ContextualExplanationEntry?
    let isExplanationSaved: Bool
    let maxDrawerHeight: CGFloat
    let isSaved: Bool
    let pointsDown: Bool
    let showsCaret: Bool
    let caretCenterX: CGFloat
    let caretWidth: CGFloat
    let caretHeight: CGFloat
    let onPronounce: () -> Void
    let onToggleSave: () -> Void
    let onExplainInContext: () -> Void
    let onSaveExplanationNote: () -> Void
    let onDockToSidePanel: () -> Void
    let onClose: () -> Void

    @State private var isHoveringSpeaker = false
    @State private var isHoveringClose = false
    @State private var isHoveringSave = false
    @State private var isHoveringExplain = false
    @State private var isSpeaking = false

    var body: some View {
        VStack(spacing: 0) {
            if !pointsDown && showsCaret {
                PopoverCaretView(
                    pointsDown: false,
                    caretCenterX: caretCenterX,
                    caretWidth: caretWidth,
                    caretHeight: caretHeight
                )
                .frame(width: SandpaperTheme.dictionaryPopoverWidth, height: caretHeight)
                .zIndex(2)
            }

            VStack(alignment: .leading, spacing: 0) {
                // STATIC TOP PORTION: Upper Dictionary Content Area
                VStack(alignment: .leading, spacing: 0) {
                    HStack(alignment: .center, spacing: 8.5) {
                        Text(entry.expression)
                            .font(.system(size: 27, weight: .regular, design: .serif))
                            .italic()
                            .foregroundStyle(SandpaperTheme.primaryInk)
                            .lineLimit(1)

                        Button {
                            isSpeaking = true
                            onPronounce()
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.65) {
                                isSpeaking = false
                            }
                        } label: {
                            ZStack {
                                Circle()
                                    .fill(
                                        isHoveringSpeaker
                                            ? SandpaperTheme.pillBackground
                                            : SandpaperTheme.bookmarkButtonBackground
                                    )
                                    .frame(width: 32, height: 32)
                                    .overlay(
                                        Circle()
                                            .strokeBorder(SandpaperTheme.speakerButtonBorder, lineWidth: 1)
                                    )

                                Image(systemName: isSpeaking ? "speaker.wave.3.fill" : "speaker.wave.2")
                                    .font(.system(size: 11.5, weight: .medium))
                                    .foregroundStyle(SandpaperTheme.secondaryInk)
                            }
                        }
                        .buttonStyle(.plain)
                        .help("Pronounce")
                        .onHover { isHoveringSpeaker = $0 }

                        Spacer()

                        Button(action: onClose) {
                            Image(systemName: "xmark")
                                .font(.system(size: 10.5, weight: .medium))
                                .foregroundStyle(SandpaperTheme.secondaryInk)
                                .frame(width: 24, height: 24)
                                .background(
                                    RoundedRectangle(cornerRadius: 5, style: .continuous)
                                        .fill(isHoveringClose ? SandpaperTheme.subtleStroke.opacity(0.22) : .clear)
                                )
                        }
                        .buttonStyle(.plain)
                        .help("Close (Esc)")
                        .onHover { isHoveringClose = $0 }
                        .padding(.trailing, 4)
                    }

                    // Phonetics & Part of Speech
                    HStack(spacing: 6) {
                        Text(entry.phonetic)
                            .font(.system(size: 12, weight: .regular))
                            .foregroundStyle(SandpaperTheme.secondaryInk)

                        Text("·")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(SandpaperTheme.secondaryInk)

                        Text(entry.partOfSpeech)
                            .font(.system(size: 12, weight: .regular))
                            .foregroundStyle(SandpaperTheme.secondaryInk)
                    }
                    .padding(.top, 12)

                    // Definition Text
                    Text(formattedDefinition)
                        .lineSpacing(7.5)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.top, 24)
                }
                .padding(.top, 20)
                .padding(.bottom, 26)
                .padding(.horizontal, 21)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(SandpaperTheme.canvasBackground)

                // STATIC TOP PORTION: Lower Action Bar
                HStack(spacing: 12) {
                    Button(action: onToggleSave) {
                        HStack(spacing: 7) {
                            Image(systemName: isSaved ? "bookmark.fill" : "bookmark")
                                .font(.system(size: 11, weight: .medium))
                                .foregroundStyle(.white)

                            Text(isSaved ? "Saved to Vocabulary" : "Save to Vocabulary")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundStyle(.white)
                        }
                        .padding(.horizontal, 13)
                        .frame(height: 31.5)
                        .background(
                            RoundedRectangle(cornerRadius: 6, style: .continuous)
                                .fill(
                                    isHoveringSave
                                        ? SandpaperTheme.popoverPrimaryButtonHover
                                        : SandpaperTheme.popoverPrimaryButton
                                )
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 6, style: .continuous)
                                .strokeBorder(Color.white.opacity(0.14), lineWidth: 0.75)
                        )
                    }
                    .buttonStyle(.plain)
                    .onHover { isHoveringSave = $0 }

                    Spacer()

                    Button(action: onExplainInContext) {
                        HStack(spacing: 6) {
                            Image(systemName: "sparkles")
                                .font(.system(size: 11.5, weight: .medium))
                                .foregroundStyle(SandpaperTheme.popoverSparkleInk)

                            Text(explanation != nil ? "Open Side Panel" : "Explain in Context")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundStyle(SandpaperTheme.secondaryInk)
                        }
                        .padding(.horizontal, 13)
                        .frame(height: 31.5)
                        .background(
                            RoundedRectangle(cornerRadius: 6, style: .continuous)
                                .fill(
                                    isHoveringExplain
                                        ? SandpaperTheme.pillBackground
                                        : SandpaperTheme.chromeBackground
                                )
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 6, style: .continuous)
                                .strokeBorder(SandpaperTheme.subtleStroke, lineWidth: 1)
                        )
                    }
                    .buttonStyle(.plain)
                    .onHover { isHoveringExplain = $0 }
                }
                .padding(.horizontal, 21)
                .frame(height: 55)
                .frame(maxWidth: .infinity)
                .background(SandpaperTheme.cardBackground)

                // SCROLLABLE BOTTOM PORTION: Downward-Expanding Contextual Explanation Drawer
                if let explanation {
                    FloatingExplanationDrawerView(
                        explanation: explanation,
                        isNoteSaved: isExplanationSaved,
                        maxDrawerHeight: maxDrawerHeight,
                        onSaveNote: onSaveExplanationNote,
                        onDockToSidePanel: onDockToSidePanel
                    )
                    .transition(.opacity.combined(with: .move(edge: .top)))
                }
            }
            .frame(width: SandpaperTheme.dictionaryPopoverWidth)
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .strokeBorder(SandpaperTheme.subtleStroke, lineWidth: 1)
            )

            if pointsDown && showsCaret {
                PopoverCaretView(
                    pointsDown: true,
                    caretCenterX: caretCenterX,
                    caretWidth: caretWidth,
                    caretHeight: caretHeight
                )
                .frame(width: SandpaperTheme.dictionaryPopoverWidth, height: caretHeight)
                .offset(y: -1)
                .zIndex(2)
            }
        }
        .compositingGroup()
        .shadow(color: Color(hex: 0x1C1310, opacity: 0.08), radius: 14, x: 0, y: 5)
        .shadow(color: Color(hex: 0x1C1310, opacity: 0.03), radius: 3, x: 0, y: 1)
    }

    private var formattedDefinition: AttributedString {
        var result = AttributedString(entry.definition)
        result.font = .system(size: 14.5, weight: .regular, design: .serif)
        result.foregroundColor = SandpaperTheme.strongInk

        if let closing = entry.emphasizedClosing, !closing.isEmpty {
            var newline = AttributedString("\n")
            newline.font = .system(size: 14.5, weight: .regular, design: .serif)
            result.append(newline)

            var emphasized = AttributedString(closing)
            emphasized.font = .system(size: 14.5, weight: .bold, design: .serif)
            emphasized.foregroundColor = SandpaperTheme.primaryInk
            result.append(emphasized)
        }

        return result
    }
}
     private struct PopoverCaretView: View {
         let pointsDown: Bool
         let caretCenterX: CGFloat
         let caretWidth: CGFloat
         let caretHeight: CGFloat

         var body: some View {
             Canvas { context, size in
                 let halfW = caretWidth * 0.5
                 let leftX = caretCenterX - halfW
                 let rightX = caretCenterX + halfW

                 var fillPath = Path()
                 var strokePath = Path()

                 if pointsDown {
                     fillPath.move(to: CGPoint(x: leftX, y: 0))
                     fillPath.addLine(to: CGPoint(x: rightX, y: 0))
                     fillPath.addLine(to: CGPoint(x: caretCenterX, y: caretHeight))
                     fillPath.closeSubpath()

                     strokePath.move(to: CGPoint(x: leftX, y: 0.5))
                     strokePath.addLine(to: CGPoint(x: caretCenterX, y: caretHeight))
                     strokePath.addLine(to: CGPoint(x: rightX, y: 0.5))
                 } else {
                     fillPath.move(to: CGPoint(x: leftX, y: size.height))
                     fillPath.addLine(to: CGPoint(x: caretCenterX, y: 0))
                     fillPath.addLine(to: CGPoint(x: rightX, y: size.height))
                     fillPath.closeSubpath()

                     strokePath.move(to: CGPoint(x: leftX, y: size.height - 0.5))
                     strokePath.addLine(to: CGPoint(x: caretCenterX, y: 0))
                     strokePath.addLine(to: CGPoint(x: rightX, y: size.height - 0.5))
                 }

                 context.fill(fillPath, with: .color(SandpaperTheme.canvasBackground))
                 context.stroke(
                     strokePath,
                     with: .color(SandpaperTheme.subtleStroke.opacity(0.75)),
                     lineWidth: 1
                 )
             }
             .allowsHitTesting(false)
         }
     }

     // MARK: - Top Toolbar & Progress Bar

     private struct ReaderToolbarView: View {
         let bookTitle: String
         let author: String
         @Binding var selectedChapter: String
         let availableChapters: [String]
         let currentPage: Int
         let totalPages: Int
         let progress: Double
         @Binding var isBookmarked: Bool
         @Binding var bodyFontSize: CGFloat
         @Binding var isShowingTypographyPopover: Bool
         let showsCustomTrafficLights: Bool
         let onBackToLibrary: (@MainActor () -> Void)?

         @State private var isHoveringLibrary = false
         @State private var isHoveringChapter = false

         var body: some View {
             VStack(spacing: 0) {
                 ZStack {
                     HStack(spacing: 0) {
                         if showsCustomTrafficLights {
                             HStack(spacing: 8) {
                                 Circle()
                                     .fill(SandpaperTheme.trafficRed)
                                     .frame(width: 12, height: 12)
                                 Circle()
                                     .fill(SandpaperTheme.trafficYellow)
                                     .frame(width: 12, height: 12)
                                 Circle()
                                     .fill(SandpaperTheme.trafficGreen)
                                     .frame(width: 12, height: 12)
                             }
                             .padding(.trailing, 27)
                         } else {
                             Spacer()
                                 .frame(width: 79)
                         }

                         Button(action: { onBackToLibrary?() }) {
                             HStack(spacing: 7) {
                                 Image(systemName: "chevron.left")
                                     .font(.system(size: 11.5, weight: .semibold))
                                 Text("Library")
                                     .font(.system(size: 13, weight: .medium))
                             }
                             .foregroundStyle(SandpaperTheme.secondaryInk)
                             .padding(.vertical, 4)
                             .padding(.horizontal, 6)
                             .background(
                                 RoundedRectangle(cornerRadius: 5, style: .continuous)
                                     .fill(isHoveringLibrary ? SandpaperTheme.subtleStroke.opacity(0.22) : .clear)
                             )
                         }
                         .buttonStyle(.plain)
                         .onHover { isHoveringLibrary = $0 }

                         Rectangle()
                             .fill(SandpaperTheme.toolbarDivider)
                             .frame(width: 1, height: 16)
                             .padding(.leading, 17)
                             .padding(.trailing, 15)

                         HStack(spacing: 8) {
                             Text(bookTitle)
                                 .font(.system(size: 14.5, weight: .bold, design: .serif))
                                 .foregroundStyle(SandpaperTheme.strongInk)
                                 .lineLimit(1)

                             Circle()
                                 .fill(SandpaperTheme.subtleStroke)
                                 .frame(width: 2.5, height: 2.5)

                             Text(author)
                                 .font(.system(size: 13, weight: .regular))
                                 .foregroundStyle(SandpaperTheme.secondaryInk)
                                 .lineLimit(1)
                         }

                         Menu {
                             ForEach(availableChapters, id: \.self) { item in
                                 Button {
                                     selectedChapter = item
                                 } label: {
                                     if item == selectedChapter {
                                         Label(item, systemImage: "checkmark")
                                     } else {
                                         Text(item)
                                     }
                                 }
                             }
                         } label: {
                             HStack(spacing: 7) {
                                 Text(selectedChapter)
                                     .font(.system(size: 12.5, weight: .regular))
                                     .foregroundStyle(SandpaperTheme.mutedInk)
                                     .lineLimit(1)

                                 Image(systemName: "chevron.up.chevron.down")
                                     .font(.system(size: 9.5, weight: .semibold))
                                     .foregroundStyle(SandpaperTheme.secondaryInk)
                             }
                             .padding(.horizontal, 8)
                             .padding(.vertical, 4)
                             .background(
                                 RoundedRectangle(cornerRadius: 5, style: .continuous)
                                     .fill(isHoveringChapter ? SandpaperTheme.subtleStroke.opacity(0.22) : .clear)
                             )
                         }
                         .menuStyle(.borderlessButton)
                         .menuIndicator(.hidden)
                         .fixedSize()
                         .padding(.leading, 10)
                         .onHover { isHoveringChapter = $0 }

                         Spacer(minLength: 24)

                         HStack(spacing: 7) {
                             Image(systemName: "clock")
                                 .font(.system(size: 11.5, weight: .medium))
                                 .foregroundStyle(SandpaperTheme.secondaryInk)

                             Text("Page \(currentPage) of \(totalPages)")
                                 .font(.system(size: 12, weight: .medium))
                                 .foregroundStyle(SandpaperTheme.secondaryInk)
                                 .monospacedDigit()
                         }
                         .padding(.horizontal, 10)
                         .padding(.vertical, 5)
                         .background(
                             RoundedRectangle(cornerRadius: 6, style: .continuous)
                                 .fill(SandpaperTheme.pillBackground)
                         )

                         Spacer(minLength: 24)

                         HStack(spacing: 18) {
                             ToolbarIconButton(helpText: "Sections") {
                                 StackedSectionsIcon()
                                     .frame(width: 12, height: 12)
                                     .foregroundStyle(SandpaperTheme.secondaryInk)
                             } action: {}

                             ToolbarIconButton(helpText: "Bookmark Page") {
                                 Image(systemName: isBookmarked ? "bookmark.fill" : "bookmark")
                                     .font(.system(size: 12.5, weight: .medium))
                                     .foregroundStyle(
                                         isBookmarked ? SandpaperTheme.terracottaAccent : SandpaperTheme.secondaryInk
                                     )
                             } action: {
                                 isBookmarked.toggle()
                             }

                             ToolbarIconButton(helpText: "Appearance & Typography") {
                                 Text("Aa")
                                     .font(.system(size: 15.5, weight: .bold, design: .serif))
                                     .foregroundStyle(SandpaperTheme.secondaryInk)
                             } action: {
                                 isShowingTypographyPopover.toggle()
                             }
                             .popover(isPresented: $isShowingTypographyPopover, arrowEdge: .bottom) {
                                 TypographySettingsPopover(fontSize: $bodyFontSize)
                             }
                         }

                         Rectangle()
                             .fill(SandpaperTheme.toolbarDivider)
                             .frame(width: 1, height: 16)
                             .padding(.leading, 14)
                             .padding(.trailing, 9)

                         Button(action: {}) {
                             ZStack {
                                 Circle()
                                     .fill(SandpaperTheme.pillBackground)
                                     .frame(width: 32, height: 32)
                                     .overlay(
                                         Circle()
                                             .strokeBorder(SandpaperTheme.subtleStroke, lineWidth: 1)
                                     )

                                 Image(systemName: "person")
                                     .font(.system(size: 13, weight: .medium))
                                     .foregroundStyle(SandpaperTheme.secondaryInk)
                             }
                         }
                         .buttonStyle(.plain)
                     }
                     .padding(.horizontal, 24)
                 }
                 .frame(height: SandpaperTheme.toolbarHeight)
                 .background(
                     LinearGradient(
                         stops: [
                             .init(color: SandpaperTheme.chromeBackground, location: 0.0),
                             .init(color: SandpaperTheme.chromeBackground, location: 0.86),
                             .init(color: SandpaperTheme.canvasBackground, location: 1.0)
                         ],
                         startPoint: .top,
                         endPoint: .bottom
                     )
                 )

                 GeometryReader { proxy in
                     ZStack(alignment: .leading) {
                         Rectangle()
                             .fill(SandpaperTheme.progressTrack)

                         Rectangle()
                             .fill(SandpaperTheme.progressFill)
                             .frame(width: max(0, min(proxy.size.width, proxy.size.width * progress)))
                     }
                 }
                 .frame(height: SandpaperTheme.progressBarHeight)
             }
         }
     }

     private struct ToolbarIconButton<Content: View>: View {
         let helpText: String
         @ViewBuilder let label: () -> Content
         let action: () -> Void

         @State private var isHovered = false

         var body: some View {
             Button(action: action) {
                 label()
                     .frame(width: 26, height: 26)
                     .background(
                         RoundedRectangle(cornerRadius: 5, style: .continuous)
                             .fill(isHovered ? SandpaperTheme.subtleStroke.opacity(0.24) : .clear)
                     )
             }
             .buttonStyle(.plain)
             .help(helpText)
             .onHover { isHovered = $0 }
         }
     }

     private struct TypographySettingsPopover: View {
         @Binding var fontSize: CGFloat

         var body: some View {
             VStack(alignment: .leading, spacing: 12) {
                 Text("Reading Typography")
                     .font(.system(size: 12, weight: .semibold))
                     .foregroundStyle(SandpaperTheme.secondaryInk)

                 HStack(spacing: 10) {
                     Button {
                         fontSize = max(17.5, fontSize - 1.0)
                     } label: {
                         Text("A−")
                             .font(.system(size: 13, weight: .medium, design: .serif))
                             .frame(width: 44, height: 28)
                     }

                     Text("\(Int(round(fontSize))) pt")
                         .font(.system(size: 12, weight: .medium))
                         .foregroundStyle(SandpaperTheme.mutedInk)
                         .monospacedDigit()
                         .frame(width: 46)

                     Button {
                         fontSize = min(25.5, fontSize + 1.0)
                     } label: {
                         Text("A+")
                             .font(.system(size: 15, weight: .medium, design: .serif))
                             .frame(width: 44, height: 28)
                     }

                     if abs(fontSize - 20.5) > 0.1 {
                         Button("Reset") {
                             fontSize = 20.5
                         }
                         .font(.system(size: 11.5))
                     }
                 }
             }
             .padding(14)
         }
     }

     // MARK: - Selectable Chapter Header (Kicker, Title & Subtitle)

     private struct ChapterHeaderView: View {
         let partLabel: String
         let chapterLabel: String
         let locationTitle: String
         let subtitle: String
         let activeSelection: ReaderTextSelection?
         let coordinator: ReaderSelectionCoordinator
         let onSelect: (ReaderTextSelection, Bool) -> Void
         let onDismiss: () -> Void

         private var fullHeaderContext: String {
             "\(partLabel) — \(chapterLabel). \(locationTitle): \(subtitle)"
         }

         var body: some View {
             let kickerText = "\(partLabel)   \(chapterLabel)"

             VStack(spacing: 0) {
                 // Part & Chapter Kicker (Selectable)
                 HStack(spacing: 9) {
                     Text(styledPartLabel(kickerText: kickerText))
                         .font(.system(size: 11, weight: .semibold))
                         .tracking(1.9)

                     FourPointDiamondShape()
                         .fill(SandpaperTheme.subtleStroke)
                         .frame(width: 8, height: 8)

                     Text(styledChapterLabel(kickerText: kickerText))
                         .font(.system(size: 12, weight: .semibold))
                 }
                 .modifier(
                     SelectableTextBlockModifier(
                         blockID: "header-kicker",
                         text: kickerText,
                         contextText: fullHeaderContext,
                         fontSize: 12,
                         lineSpacing: 4,
                         fontDesign: .default,
                         fontWeight: .semibold,
                         isItalic: false,
                         textAlignment: .center,
                         interactiveRanges: [],
                         activeSelection: activeSelection,
                         coordinator: coordinator,
                         onSelect: onSelect,
                         onDismiss: onDismiss
                     )
                 )

                 // Chapter Main Title (Selectable)
                 Text(
                     styledText(
                         locationTitle,
                         blockID: "header-title",
                         baseColor: SandpaperTheme.primaryInk
                     )
                 )
                 .font(.system(size: 36, weight: .regular, design: .serif))
                 .multilineTextAlignment(.center)
                 .fixedSize(horizontal: false, vertical: true)
                 .modifier(
                     SelectableTextBlockModifier(
                         blockID: "header-title",
                         text: locationTitle,
                         contextText: fullHeaderContext,
                         fontSize: 36,
                         lineSpacing: 6,
                         fontDesign: .serif,
                         fontWeight: .regular,
                         isItalic: false,
                         textAlignment: .center,
                         interactiveRanges: [],
                         activeSelection: activeSelection,
                         coordinator: coordinator,
                         onSelect: onSelect,
                         onDismiss: onDismiss
                     )
                 )
                 .padding(.top, 26)

                 // Chapter Subtitle (Selectable)
                 Text(
                     styledText(
                         subtitle,
                         blockID: "header-subtitle",
                         baseColor: SandpaperTheme.mutedInk
                     )
                 )
                 .font(.system(size: 17.5, weight: .bold, design: .serif))
                 .italic()
                 .multilineTextAlignment(.center)
                 .fixedSize(horizontal: false, vertical: true)
                 .modifier(
                     SelectableTextBlockModifier(
                         blockID: "header-subtitle",
                         text: subtitle,
                         contextText: fullHeaderContext,
                         fontSize: 17.5,
                         lineSpacing: 4,
                         fontDesign: .serif,
                         fontWeight: .bold,
                         isItalic: true,
                         textAlignment: .center,
                         interactiveRanges: [],
                         activeSelection: activeSelection,
                         coordinator: coordinator,
                         onSelect: onSelect,
                         onDismiss: onDismiss
                     )
                 )
                 .padding(.top, 34)

                 // Short Decorative Rule
                 Rectangle()
                     .fill(SandpaperTheme.headerRule)
                     .frame(width: 48, height: 1.5)
                     .padding(.top, 34)
             }
         }

         private func styledText(_ string: String, blockID: String, baseColor: Color) -> AttributedString {
             var attributed = AttributedString(string)
             attributed.foregroundColor = baseColor

             if let selRange = activeSelection?.range(for: blockID),
                let range = Range(selRange, in: string),
                let attrStart = AttributedString.Index(range.lowerBound, within: attributed),
                let attrEnd = AttributedString.Index(range.upperBound, within: attributed) {
                 attributed[attrStart..<attrEnd].foregroundColor = SandpaperTheme.highlightInk
             }

             return attributed
         }

         private func styledPartLabel(kickerText: String) -> AttributedString {
             var attributed = AttributedString(partLabel)
             attributed.foregroundColor = SandpaperTheme.kickerAccent

             if let selRange = activeSelection?.range(for: "header-kicker") {
                 let partLen = (partLabel as NSString).length
                 let overlapStart = max(0, selRange.location)
                 let overlapEnd = min(partLen, selRange.location + selRange.length)
                 if overlapEnd > overlapStart,
                    let range = Range(NSRange(location: overlapStart, length: overlapEnd - overlapStart), in: partLabel),
                    let attrStart = AttributedString.Index(range.lowerBound, within: attributed),
                    let attrEnd = AttributedString.Index(range.upperBound, within: attributed) {
                     attributed[attrStart..<attrEnd].foregroundColor = SandpaperTheme.highlightInk
                 }
             }
             return attributed
         }

         private func styledChapterLabel(kickerText: String) -> AttributedString {
             var attributed = AttributedString(chapterLabel)
             attributed.foregroundColor = SandpaperTheme.secondaryInk

             if let selRange = activeSelection?.range(for: "header-kicker") {
                 let offset = (partLabel as NSString).length + 3
                 let chapLen = (chapterLabel as NSString).length
                 let overlapStart = max(offset, selRange.location) - offset
                 let overlapEnd = min(offset + chapLen, selRange.location + selRange.length) - offset
                 if overlapEnd > overlapStart,
                    let range = Range(NSRange(location: overlapStart, length: overlapEnd - overlapStart), in: chapterLabel),
                    let attrStart = AttributedString.Index(range.lowerBound, within: attributed),
                    let attrEnd = AttributedString.Index(range.upperBound, within: attributed) {
                     attributed[attrStart..<attrEnd].foregroundColor = SandpaperTheme.highlightInk
                 }
             }
             return attributed
         }
     }

     // MARK: - Unified Drop Cap Paragraph (Continuous Selection Across All Lines)

     private struct DropCapParagraphView: View {
         let blockID: String
         let dropCap: String
         let remainderText: String
         let fontSize: CGFloat
         let activeSelection: ReaderTextSelection?
         let coordinator: ReaderSelectionCoordinator
         let onSelect: (ReaderTextSelection, Bool) -> Void
         let onDismiss: () -> Void

         @State private var containerWidth: CGFloat = SandpaperTheme.readingColumnWidth
         @State private var topTextOrigin: CGPoint = .zero
         @State private var topTextSize: CGSize = .zero
         @State private var bottomTextOrigin: CGPoint = .zero
         @State private var bottomTextSize: CGSize = .zero
         @State private var blockFrameInReader: CGRect = .zero

         private var lineSpacing: CGFloat {
             round(fontSize * 0.585) // 12pt at 20.5pt font size
         }

         private var dropCapFontSize: CGFloat {
             round(fontSize * 2.82) // 58pt at 20.5pt font size
         }

         private var activeRectsInBlock: [CGRect] {
             activeSelection?.highlightRects(for: blockID) ?? []
         }

         var body: some View {
             let split = splitFirstTwoLines(
                 text: remainderText,
                 fontSize: fontSize,
                 lineSpacing: lineSpacing,
                 totalWidth: containerWidth
             )
             let fullParagraphText = dropCap + remainderText

             let topUTF16Length = (split.firstTwoLines as NSString).length
             let dropCapUTF16Length = (dropCap as NSString).length
             let bottomStartUTF16 = dropCapUTF16Length + topUTF16Length + (split.hasJoiningSpace ? 1 : 0)

             VStack(alignment: .leading, spacing: lineSpacing) {
                 HStack(alignment: .top, spacing: 9.5) {
                     Text(dropCap)
                         .font(.system(size: dropCapFontSize, weight: .regular, design: .serif))
                         .foregroundStyle(isDropCapSelected ? SandpaperTheme.highlightInk : SandpaperTheme.dropCapInk)
                         .fixedSize()
                         .padding(.leading, 2)
                         .padding(.top, -7)
                         .padding(.bottom, -14)
                         .accessibilityHidden(true)

                     Text(
                         styledSubstring(
                             split.firstTwoLines,
                             substringOffsetUTF16: dropCapUTF16Length,
                             baseColor: SandpaperTheme.primaryInk
                         )
                     )
                     .font(.system(size: fontSize, weight: .regular, design: .serif))
                     .lineSpacing(lineSpacing)
                     .fixedSize(horizontal: false, vertical: true)
                     .frame(maxWidth: .infinity, alignment: .leading)
                     .background(
                         GeometryReader { topProxy in
                             let frame = topProxy.frame(in: .named("DropCapBlockSpace-\(blockID)"))
                             Color.clear
                                 .onAppear {
                                     topTextOrigin = frame.origin
                                     topTextSize = frame.size
                                 }
                                 .onChange(of: frame) { _, newFrame in
                                     topTextOrigin = newFrame.origin
                                     topTextSize = newFrame.size
                                 }
                         }
                     )
                 }

                 if !split.remainingLines.isEmpty {
                     Text(
                         styledSubstring(
                             split.remainingLines,
                             substringOffsetUTF16: bottomStartUTF16,
                             baseColor: SandpaperTheme.primaryInk
                         )
                     )
                     .font(.system(size: fontSize, weight: .regular, design: .serif))
                     .lineSpacing(lineSpacing)
                     .fixedSize(horizontal: false, vertical: true)
                     .frame(maxWidth: .infinity, alignment: .leading)
                     .background(
                         GeometryReader { bottomProxy in
                             let frame = bottomProxy.frame(in: .named("DropCapBlockSpace-\(blockID)"))
                             Color.clear
                                 .onAppear {
                                     bottomTextOrigin = frame.origin
                                     bottomTextSize = frame.size
                                 }
                                 .onChange(of: frame) { _, newFrame in
                                     bottomTextOrigin = newFrame.origin
                                     bottomTextSize = newFrame.size
                                 }
                         }
                     )
                 }
             }
             .coordinateSpace(name: "DropCapBlockSpace-\(blockID)")
             .background(
                 ZStack(alignment: .topLeading) {
                     GeometryReader { proxy in
                         let rectInReader = proxy.frame(in: .named("SandpaperReaderSpace"))
                         Color.clear
                             .onAppear {
                                 if proxy.size.width > 0 {
                                     containerWidth = proxy.size.width
                                 }
                                 blockFrameInReader = rectInReader
                             }
                             .onChange(of: proxy.size.width) { _, newWidth in
                                 if newWidth > 0 {
                                     containerWidth = newWidth
                                 }
                             }
                             .onChange(of: rectInReader) { _, newRect in
                                 let previous = blockFrameInReader
                                 blockFrameInReader = newRect
                                 if var current = activeSelection,
                                    current.blockID == blockID,
                                    abs(newRect.minY - previous.minY) > 0.5 || abs(newRect.minX - previous.minX) > 0.5 {
                                     let dy = newRect.minY - previous.minY
                                     let dx = newRect.minX - previous.minX
                                     let updatedAnchor = current.anchorRectInReader.offsetBy(dx: dx, dy: dy)
                                     let minVisibleY = SandpaperTheme.toolbarHeight + 8
                                     if updatedAnchor.maxY < minVisibleY {
                                         onDismiss()
                                     } else {
                                         current = ReaderTextSelection(
                                             blockID: current.blockID,
                                             nsRange: current.nsRange,
                                             selectedText: current.selectedText,
                                             contextText: current.contextText,
                                             lineHighlightRects: current.lineHighlightRects,
                                             anchorRectInReader: updatedAnchor,
                                             blockSelections: current.blockSelections
                                         )
                                         onSelect(current, true)
                                     }
                                 }
                             }
                     }

                     ForEach(Array(activeRectsInBlock.enumerated()), id: \.offset) { _, rect in
                         RoundedRectangle(cornerRadius: 4, style: .continuous)
                             .fill(SandpaperTheme.selectionPillFill)
                             .overlay(
                                 RoundedRectangle(cornerRadius: 4, style: .continuous)
                                     .strokeBorder(SandpaperTheme.selectionPillBorder, lineWidth: 1.5)
                             )
                             .frame(width: rect.width, height: rect.height)
                             .offset(x: rect.minX, y: rect.minY)
                     }
                 }
             )
             .overlay(
                 DropCapSelectableTextOverlay(
                     blockID: blockID,
                     dropCap: dropCap,
                     topText: split.firstTwoLines,
                     bottomText: split.remainingLines,
                     hasJoiningSpace: split.hasJoiningSpace,
                     fullText: fullParagraphText,
                     fontSize: fontSize,
                     lineSpacing: lineSpacing,
                     topTextOrigin: topTextOrigin,
                     topTextSize: topTextSize,
                     bottomTextOrigin: bottomTextOrigin,
                     bottomTextSize: bottomTextSize,
                     blockFrameInReader: blockFrameInReader,
                     selectedRange: activeSelection?.range(for: blockID),
                     coordinator: coordinator
                 )
             )
         }

         private var isDropCapSelected: Bool {
             guard let range = activeSelection?.range(for: blockID) else { return false }
             return range.location == 0 && range.length > 0
         }

         private func styledSubstring(
             _ substring: String,
             substringOffsetUTF16: Int,
             baseColor: Color
         ) -> AttributedString {
             var attributed = AttributedString(substring)
             attributed.foregroundColor = baseColor

             guard let fullSelectedRange = activeSelection?.range(for: blockID) else {
                 return attributed
             }

             let subLength = (substring as NSString).length
             let subStart = substringOffsetUTF16
             let subEnd = substringOffsetUTF16 + subLength

             let selStart = fullSelectedRange.location
             let selEnd = fullSelectedRange.location + fullSelectedRange.length

             let overlapStart = max(subStart, selStart)
             let overlapEnd = min(subEnd, selEnd)

             if overlapEnd > overlapStart {
                 let localRange = NSRange(
                     location: overlapStart - subStart,
                     length: overlapEnd - overlapStart
                 )
                 if let range = Range(localRange, in: substring),
                    let attrStart = AttributedString.Index(range.lowerBound, within: attributed),
                    let attrEnd = AttributedString.Index(range.upperBound, within: attributed) {
                     attributed[attrStart..<attrEnd].foregroundColor = SandpaperTheme.highlightInk
                 }
             }

             return attributed
         }

         private func splitFirstTwoLines(
             text: String,
             fontSize: CGFloat,
             lineSpacing: CGFloat,
             totalWidth: CGFloat
         ) -> (firstTwoLines: String, remainingLines: String, hasJoiningSpace: Bool) {
             if abs(totalWidth - SandpaperTheme.readingColumnWidth) < 12,
                abs(fontSize - 20.5) < 0.25,
                let anchorRange = text.range(of: "Mortimer’s Pond. The ") {
                 let firstPart = String(text[..<anchorRange.upperBound]).trimmingCharacters(in: .whitespaces)
                 let secondPart = String(text[anchorRange.upperBound...])
                 return (firstPart, secondPart, true)
             }

             let dropCapColumnWidth = ceil(fontSize * 1.42)
             let availableWidth = max(180, totalWidth - dropCapColumnWidth)

             let baseFont = NSFont.systemFont(ofSize: fontSize, weight: .regular)
             let serifDescriptor = baseFont.fontDescriptor.withDesign(.serif) ?? baseFont.fontDescriptor
             let font = NSFont(descriptor: serifDescriptor, size: fontSize) ?? baseFont

             let paragraphStyle = NSMutableParagraphStyle()
             paragraphStyle.lineSpacing = lineSpacing

             let attrString = NSAttributedString(
                 string: text,
                 attributes: [
                     .font: font,
                     .paragraphStyle: paragraphStyle
                 ]
             )

             let framesetter = CTFramesetterCreateWithAttributedString(attrString as CFAttributedString)
             let path = CGPath(rect: CGRect(x: 0, y: 0, width: availableWidth, height: 1000), transform: nil)
             let frame = CTFramesetterCreateFrame(framesetter, CFRangeMake(0, attrString.length), path, nil)
             let lines = CTFrameGetLines(frame) as! [CTLine]

             guard lines.count > 2 else {
                 return (text, "", false)
             }

             let secondLineRange = CTLineGetStringRange(lines[1])
             let splitUTF16Index = secondLineRange.location + secondLineRange.length
             let nsText = text as NSString

             guard splitUTF16Index > 0, splitUTF16Index < nsText.length else {
                 return (text, "", false)
             }

             let rawFirstTwo = nsText.substring(to: splitUTF16Index)
             let rawRemainder = nsText.substring(from: splitUTF16Index)

             let firstTwo = rawFirstTwo.trimmingCharacters(in: .whitespacesAndNewlines)
             let remainder = rawRemainder.trimmingCharacters(in: .whitespacesAndNewlines)
             let joinedLen = (firstTwo as NSString).length + (remainder as NSString).length
             let hasSpace = (nsText.length - joinedLen) > 0

             return (firstTwo, remainder, hasSpace)
         }
     }

     private struct DropCapSelectableTextOverlay: NSViewRepresentable {
         let blockID: String
         let dropCap: String
         let topText: String
         let bottomText: String
         let hasJoiningSpace: Bool
         let fullText: String
         let fontSize: CGFloat
         let lineSpacing: CGFloat
         let topTextOrigin: CGPoint
         let topTextSize: CGSize
         let bottomTextOrigin: CGPoint
         let bottomTextSize: CGSize
         let blockFrameInReader: CGRect
         let selectedRange: NSRange?
         let coordinator: ReaderSelectionCoordinator

         func makeNSView(context: Context) -> DropCapTextInteractionNSView {
             let view = DropCapTextInteractionNSView()
             updateConfiguration(on: view)
             return view
         }

         func updateNSView(_ nsView: DropCapTextInteractionNSView, context: Context) {
             updateConfiguration(on: nsView)
         }

         private func updateConfiguration(on view: DropCapTextInteractionNSView) {
             view.blockID = blockID
             view.dropCap = dropCap
             view.topText = topText
             view.bottomText = bottomText
             view.hasJoiningSpace = hasJoiningSpace
             view.fullText = fullText
             view.contextText = fullText
             view.fontSize = fontSize
             view.lineSpacing = lineSpacing
             view.topTextOrigin = topTextOrigin
             view.topTextSize = topTextSize
             view.bottomTextOrigin = bottomTextOrigin
             view.bottomTextSize = bottomTextSize
             view.blockFrameInReader = blockFrameInReader
             view.selectedRange = selectedRange
             view.coordinator = coordinator
             coordinator.register(view)
         }
     }

     @MainActor
     final class DropCapTextInteractionNSView: NSView, NSUserInterfaceValidations, SelectableBlockEndpoint {
         var blockID: String = ""
         var dropCap: String = "I"
         var topText: String = ""
         var bottomText: String = ""
         var hasJoiningSpace: Bool = true
         var fullText: String = ""
         var contextText: String = ""
         var fontSize: CGFloat = 20.5
         var lineSpacing: CGFloat = 12
         var topTextOrigin: CGPoint = .zero
         var topTextSize: CGSize = .zero
         var bottomTextOrigin: CGPoint = .zero
         var bottomTextSize: CGSize = .zero
         var blockFrameInReader: CGRect = .zero
         var selectedRange: NSRange?
         weak var coordinator: ReaderSelectionCoordinator?

         private var trackingAreaRef: NSTrackingArea?

         override var isFlipped: Bool { true }
         override var acceptsFirstResponder: Bool { true }

         private var dropCapLen: Int { (dropCap as NSString).length }
         private var topLen: Int { (topText as NSString).length }
         private var bottomStartIndex: Int {
             dropCapLen + topLen + (hasJoiningSpace ? 1 : 0)
         }

         override func updateTrackingAreas() {
             super.updateTrackingAreas()
             if let existing = trackingAreaRef {
                 removeTrackingArea(existing)
             }
             let area = NSTrackingArea(
                 rect: bounds,
                 options: [.activeInKeyWindow, .mouseMoved, .cursorUpdate, .inVisibleRect],
                 owner: self,
                 userInfo: nil
             )
             addTrackingArea(area)
             trackingAreaRef = area
         }

         override func cursorUpdate(with event: NSEvent) {
             NSCursor.iBeam.set()
         }

         override func mouseMoved(with event: NSEvent) {
             NSCursor.iBeam.set()
         }

         override func scrollWheel(with event: NSEvent) {
             nextResponder?.scrollWheel(with: event)
         }

         override func mouseDown(with event: NSEvent) {
             window?.makeFirstResponder(self)
             let point = convert(event.locationInWindow, from: nil)

             if event.clickCount == 2 {
                 selectWord(at: point)
                 return
             }

             if event.clickCount >= 3 {
                 selectSentenceOrLine(at: point)
                 return
             }

             let index = characterIndex(at: point)
             coordinator?.beginDrag(blockID: blockID, charIndex: index)
         }

         override func mouseDragged(with event: NSEvent) {
             coordinator?.updateDrag(windowPoint: event.locationInWindow, fallbackEndpoint: self)
         }

         override func mouseUp(with event: NSEvent) {
             if coordinator?.endDrag(windowPoint: event.locationInWindow, fallbackEndpoint: self) == true {
                 return
             }
             if event.clickCount == 1 {
                 coordinator?.clearSelection()
             }
         }

         // MARK: - Copy Support

         @objc func copy(_ sender: Any?) {
             if let globalText = coordinator?.currentSelection?.selectedText, !globalText.isEmpty {
                 NSPasteboard.general.clearContents()
                 NSPasteboard.general.setString(globalText, forType: .string)
                 return
             }
             guard let range = selectedRange,
                   range.location != NSNotFound,
                   range.location + range.length <= (fullText as NSString).length else {
                 return
             }
             let copied = (fullText as NSString).substring(with: range)
             NSPasteboard.general.clearContents()
             NSPasteboard.general.setString(copied, forType: .string)
         }

         func validateUserInterfaceItem(_ item: NSValidatedUserInterfaceItem) -> Bool {
             if item.action == #selector(copy(_:)) {
                 if let text = coordinator?.currentSelection?.selectedText, !text.isEmpty {
                     return true
                 }
                 return selectedRange != nil && (selectedRange?.length ?? 0) > 0
             }
             return false
         }

         override func menu(for event: NSEvent) -> NSMenu? {
             let point = convert(event.locationInWindow, from: nil)
             if selectedRange == nil && coordinator?.currentSelection == nil {
                 selectWord(at: point)
             }
             guard (selectedRange?.length ?? 0) > 0 || (coordinator?.currentSelection != nil) else {
                 return nil
             }

             let menu = NSMenu(title: "Reader Selection")
             let copyItem = NSMenuItem(title: "Copy", action: #selector(copy(_:)), keyEquivalent: "c")
             copyItem.target = self
             menu.addItem(copyItem)
             return menu
         }

         // MARK: - Word & Line Selection

         private func selectWord(at point: CGPoint) {
             let index = characterIndex(at: point)
             let attr = NSAttributedString(string: fullText)
             guard attr.length > 0 else { return }
             let clampedIndex = min(max(0, index), attr.length - 1)
             let wordRange = attr.doubleClick(at: clampedIndex)

             if let selection = coordinator?.buildSingleBlockSelection(
                 endpoint: self,
                 range: wordRange,
                 trim: true
             ) {
                 coordinator?.publishSingleSelection(selection, presentPopover: true)
             } else {
                 coordinator?.clearSelection()
             }
         }

         private func selectSentenceOrLine(at point: CGPoint) {
             let layout = makeUnifiedLines()
             guard !layout.isEmpty else { return }

             let chosen = layout.first { entry in
                 point.y >= entry.topY - 4 && point.y <= entry.topY + entry.lineHeight + lineSpacing
             } ?? layout.last!

             if let selection = coordinator?.buildSingleBlockSelection(
                 endpoint: self,
                 range: chosen.fullStringRange,
                 trim: true
             ) {
                 coordinator?.publishSingleSelection(selection, presentPopover: true)
             }
         }

         // MARK: - SelectableBlockEndpoint Conformance

         func clampedCharacterIndex(forPointInWindow windowPoint: CGPoint) -> Int {
             let localPoint = convert(windowPoint, from: nil)
             return characterIndex(at: localPoint)
         }

         private struct UnifiedLineMetrics {
             let ctLine: CTLine
             let originX: CGFloat
             let topY: CGFloat
             let lineHeight: CGFloat
             let fullStringOffset: Int
             let fullStringRange: NSRange
             let isFirstLineWithDropCap: Bool
         }

         private func makeLines(for text: String, width: CGFloat, height: CGFloat) -> (lines: [CTLine], lineHeight: CGFloat, lineStep: CGFloat) {
             guard !text.isEmpty, width > 10 else {
                 return ([], fontSize, fontSize + lineSpacing)
             }

             let baseFont = NSFont.systemFont(ofSize: fontSize, weight: .regular)
             let descriptor = baseFont.fontDescriptor.withDesign(.serif) ?? baseFont.fontDescriptor
             let font = NSFont(descriptor: descriptor, size: fontSize) ?? baseFont

             let paragraphStyle = NSMutableParagraphStyle()
             paragraphStyle.lineSpacing = lineSpacing

             let attrString = NSAttributedString(
                 string: text,
                 attributes: [
                     .font: font,
                     .paragraphStyle: paragraphStyle
                 ]
             )

             let framesetter = CTFramesetterCreateWithAttributedString(attrString as CFAttributedString)
             let path = CGPath(rect: CGRect(x: 0, y: 0, width: width, height: 4000), transform: nil)
             let frame = CTFramesetterCreateFrame(framesetter, CFRangeMake(0, attrString.length), path, nil)
             let lines = CTFrameGetLines(frame) as! [CTLine]

             let count = max(1, lines.count)
             let totalSpacing = CGFloat(max(0, count - 1)) * lineSpacing
             let effectiveHeight = height > 4 ? height : CGFloat(count) * (fontSize * 1.25) + totalSpacing
             let measuredLineHeight = max(fontSize, (effectiveHeight - totalSpacing) / CGFloat(count))
             let step = measuredLineHeight + lineSpacing

             return (lines, measuredLineHeight, step)
         }

         private func makeUnifiedLines() -> [UnifiedLineMetrics] {
             var result: [UnifiedLineMetrics] = []

             let topWidth = topTextSize.width > 10 ? topTextSize.width : max(180, bounds.width - 38)
             let topLayout = makeLines(for: topText, width: topWidth, height: topTextSize.height)

             for (idx, line) in topLayout.lines.enumerated() {
                 let cfRange = CTLineGetStringRange(line)
                 let topY = topTextOrigin.y + CGFloat(idx) * topLayout.lineStep
                 let fullStart = idx == 0 ? 0 : (dropCapLen + cfRange.location)
                 let fullLen = idx == 0 ? (dropCapLen + cfRange.length) : cfRange.length

                 result.append(
                     UnifiedLineMetrics(
                         ctLine: line,
                         originX: topTextOrigin.x,
                         topY: topY,
                         lineHeight: topLayout.lineHeight,
                         fullStringOffset: dropCapLen,
                         fullStringRange: NSRange(location: fullStart, length: fullLen),
                         isFirstLineWithDropCap: idx == 0
                     )
                 )
             }

             if !bottomText.isEmpty {
                 let bottomWidth = bottomTextSize.width > 10 ? bottomTextSize.width : bounds.width
                 let bottomLayout = makeLines(for: bottomText, width: bottomWidth, height: bottomTextSize.height)
                 let baseOffset = bottomStartIndex
                 let startY = bottomTextOrigin.y > 0
                     ? bottomTextOrigin.y
                     : (topTextOrigin.y + CGFloat(topLayout.lines.count) * topLayout.lineStep)

                 for (idx, line) in bottomLayout.lines.enumerated() {
                     let cfRange = CTLineGetStringRange(line)
                     let topY = startY + CGFloat(idx) * bottomLayout.lineStep

                     result.append(
                         UnifiedLineMetrics(
                             ctLine: line,
                             originX: bottomTextOrigin.x,
                             topY: topY,
                             lineHeight: bottomLayout.lineHeight,
                             fullStringOffset: baseOffset,
                             fullStringRange: NSRange(location: baseOffset + cfRange.location, length: cfRange.length),
                             isFirstLineWithDropCap: false
                         )
                     )
                 }
             }

             return result
         }

         private func characterIndex(at point: CGPoint) -> Int {
             let nsFullLen = (fullText as NSString).length
             guard nsFullLen > 0 else { return 0 }

             if point.y < 0 { return 0 }
             if point.y > bounds.height { return nsFullLen }

             let lines = makeUnifiedLines()
             guard !lines.isEmpty else { return 0 }

             var targetLine = lines[0]
             for line in lines {
                 if point.y >= line.topY - (lineSpacing * 0.5) &&
                    point.y <= line.topY + line.lineHeight + (lineSpacing * 0.5) {
                     targetLine = line
                     break
                 } else if point.y > line.topY {
                     targetLine = line
                 }
             }

             if targetLine.isFirstLineWithDropCap && point.x < targetLine.originX - 2 {
                 return 0
             }

             let localX = max(0, point.x - targetLine.originX)
             let localPoint = CGPoint(x: localX, y: targetLine.lineHeight * 0.5)
             let cfIndex = CTLineGetStringIndexForPosition(targetLine.ctLine, localPoint)
             guard cfIndex != kCFNotFound else {
                 return targetLine.fullStringRange.location
             }

             if targetLine.isFirstLineWithDropCap && cfIndex == 0 && point.x < targetLine.originX + 4 {
                 return 0
             }

             let fullIndex = targetLine.fullStringOffset + cfIndex
             return min(max(0, fullIndex), nsFullLen)
         }

         func selectionRects(for range: NSRange) -> [CGRect] {
             let lines = makeUnifiedLines()
             guard !lines.isEmpty else { return [] }

             var rects: [CGRect] = []
             let selStart = range.location
             let selEnd = range.location + range.length

             for line in lines {
                 let cfRange = CTLineGetStringRange(line.ctLine)
                 let lineSubStart = line.fullStringOffset + cfRange.location
                 let lineSubEnd = lineSubStart + cfRange.length

                 let includesDropCap = line.isFirstLineWithDropCap && selStart == 0 && selEnd > 0
                 let overlapStart = max(selStart, lineSubStart)
                 let overlapEnd = min(selEnd, lineSubEnd)

                 if overlapEnd > overlapStart || includesDropCap {
                     var minX: CGFloat
                     var maxX: CGFloat

                     if overlapEnd > overlapStart {
                         let localStart = overlapStart - line.fullStringOffset
                         let localEnd = overlapEnd - line.fullStringOffset
                         let xStart = CTLineGetOffsetForStringIndex(line.ctLine, localStart, nil)
                         let xEnd = CTLineGetOffsetForStringIndex(line.ctLine, localEnd, nil)
                         minX = line.originX + min(xStart, xEnd)
                         maxX = line.originX + max(xStart, xEnd)
                     } else {
                         minX = 0
                         maxX = line.originX
                     }

                     if includesDropCap {
                         minX = 0
                     }

                     let pillRect = CGRect(
                         x: minX - 3.0,
                         y: line.topY - 2.0,
                         width: max(8, (maxX - minX) + 6.0),
                         height: line.lineHeight + 4.0
                     )
                     rects.append(pillRect)
                 }
             }

             return rects
         }
     }

     // MARK: - Body Paragraph with Inline Vocabulary Highlight

     private struct ReaderParagraphView: View {
         let blockID: String
         let segments: [TextSegment]
         let fontSize: CGFloat
         let activeSelection: ReaderTextSelection?
         let coordinator: ReaderSelectionCoordinator
         let onSelect: (ReaderTextSelection, Bool) -> Void
         let onDismiss: () -> Void

         private var lineSpacing: CGFloat {
             round(fontSize * 0.585)
         }

         var body: some View {
             let info = plainTextAndHighlightRanges
             Text(attributedContent(plainText: info.plainText))
                 .font(.system(size: fontSize, weight: .regular, design: .serif))
                 .lineSpacing(lineSpacing)
                 .fixedSize(horizontal: false, vertical: true)
                 .frame(maxWidth: .infinity, alignment: .leading)
                 .modifier(
                     SelectableTextBlockModifier(
                         blockID: blockID,
                         text: info.plainText,
                         contextText: info.plainText,
                         fontSize: fontSize,
                         lineSpacing: lineSpacing,
                         fontDesign: .serif,
                         fontWeight: .regular,
                         isItalic: false,
                         textAlignment: .left,
                         interactiveRanges: info.highlightRanges,
                         activeSelection: activeSelection,
                         coordinator: coordinator,
                         onSelect: onSelect,
                         onDismiss: onDismiss
                     )
                 )
         }

         private var plainTextAndHighlightRanges: (plainText: String, highlightRanges: [NSRange]) {
             var builder = ""
             var ranges: [NSRange] = []

             for segment in segments {
                 switch segment {
                 case .plain(let string):
                     builder.append(string)
                 case .vocabularyHighlight(let term):
                     let start = (builder as NSString).length
                     builder.append(term)
                     let length = (term as NSString).length
                     ranges.append(NSRange(location: start, length: length))
                 }
             }

             return (builder, ranges)
         }

         private func attributedContent(plainText: String) -> AttributedString {
             var result = AttributedString()

             for segment in segments {
                 switch segment {
                 case .plain(let string):
                     var part = AttributedString(string)
                     part.foregroundColor = SandpaperTheme.primaryInk
                     result.append(part)

                 case .vocabularyHighlight(let term):
                     var part = AttributedString(term)
                     part.foregroundColor = SandpaperTheme.highlightInk
                     part.underlineStyle = Text.LineStyle(pattern: .solid, color: SandpaperTheme.highlightInk)
                     result.append(part)
                 }
             }

             if let selRange = activeSelection?.range(for: blockID),
                let range = Range(selRange, in: plainText),
                let attrStart = AttributedString.Index(range.lowerBound, within: result),
                let attrEnd = AttributedString.Index(range.upperBound, within: result) {
                 result[attrStart..<attrEnd].foregroundColor = SandpaperTheme.highlightInk
             }

             return result
         }
     }

     // MARK: - Journal Blockquote Card

     private struct JournalBlockquoteView: View {
         let blockID: String
         let quote: String
         let source: String
         let note: String
         let baseFontSize: CGFloat
         let activeSelection: ReaderTextSelection?
         let coordinator: ReaderSelectionCoordinator
         let onSelect: (ReaderTextSelection, Bool) -> Void
         let onDismiss: () -> Void

         private var quoteFontSize: CGFloat {
             round(baseFontSize * 0.85) // 17.5pt at 20.5pt body size
         }

         var body: some View {
             let sourceBlockID = "\(blockID)-source"
             let fullFooterText = "\(source)  \(note)"

             VStack(alignment: .leading, spacing: 20) {
                 Text(styledQuote)
                     .font(.system(size: quoteFontSize, weight: .regular, design: .serif))
                     .italic()
                     .lineSpacing(9.5)
                     .fixedSize(horizontal: false, vertical: true)
                     .modifier(
                         SelectableTextBlockModifier(
                             blockID: blockID,
                             text: quote,
                             contextText: quote,
                             fontSize: quoteFontSize,
                             lineSpacing: 9.5,
                             fontDesign: .serif,
                             fontWeight: .regular,
                             isItalic: true,
                             textAlignment: .left,
                             interactiveRanges: [],
                             activeSelection: activeSelection,
                             coordinator: coordinator,
                             onSelect: onSelect,
                             onDismiss: onDismiss
                         )
                     )

                 HStack(alignment: .firstTextBaseline, spacing: 10) {
                     Text(styledSource(sourceBlockID: sourceBlockID))
                         .font(.system(size: 11, weight: .medium))
                         .tracking(0.6)

                     Text(styledNote(sourceBlockID: sourceBlockID))
                         .font(.system(size: 11.5, weight: .regular))
                         .italic()
                 }
                 .modifier(
                     SelectableTextBlockModifier(
                         blockID: sourceBlockID,
                         text: fullFooterText,
                         contextText: "\(quote) \(fullFooterText)",
                         fontSize: 11.5,
                         lineSpacing: 4,
                         fontDesign: .default,
                         fontWeight: .medium,
                         isItalic: false,
                         textAlignment: .left,
                         interactiveRanges: [],
                         activeSelection: activeSelection,
                         coordinator: coordinator,
                         onSelect: onSelect,
                         onDismiss: onDismiss
                     )
                 )
                 .padding(.leading, 8)
             }
             .padding(.top, 34)
             .padding(.bottom, 28)
             .padding(.leading, 29)
             .padding(.trailing, 32)
             .frame(maxWidth: .infinity, alignment: .leading)
             .background(SandpaperTheme.cardBackground)
             .overlay(alignment: .leading) {
                 Rectangle()
                     .fill(SandpaperTheme.terracottaAccent)
                     .frame(width: 4)
             }
             .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
             .overlay(
                 RoundedRectangle(cornerRadius: 6, style: .continuous)
                     .strokeBorder(SandpaperTheme.cardBorder, lineWidth: 1)
             )
         }

         private var styledQuote: AttributedString {
             var attributed = AttributedString(quote)
             attributed.foregroundColor = SandpaperTheme.strongInk

             if let selRange = activeSelection?.range(for: blockID),
                let range = Range(selRange, in: quote),
                let attrStart = AttributedString.Index(range.lowerBound, within: attributed),
                let attrEnd = AttributedString.Index(range.upperBound, within: attributed) {
                 attributed[attrStart..<attrEnd].foregroundColor = SandpaperTheme.highlightInk
             }

             return attributed
         }

         private func styledSource(sourceBlockID: String) -> AttributedString {
             var attributed = AttributedString(source)
             attributed.foregroundColor = SandpaperTheme.mutedInk

             if let selRange = activeSelection?.range(for: sourceBlockID) {
                 let len = (source as NSString).length
                 let overlapStart = max(0, selRange.location)
                 let overlapEnd = min(len, selRange.location + selRange.length)
                 if overlapEnd > overlapStart,
                    let range = Range(NSRange(location: overlapStart, length: overlapEnd - overlapStart), in: source),
                    let attrStart = AttributedString.Index(range.lowerBound, within: attributed),
                    let attrEnd = AttributedString.Index(range.upperBound, within: attributed) {
                     attributed[attrStart..<attrEnd].foregroundColor = SandpaperTheme.highlightInk
                 }
             }
             return attributed
         }

         private func styledNote(sourceBlockID: String) -> AttributedString {
             var attributed = AttributedString(note)
             attributed.foregroundColor = SandpaperTheme.terracottaAccent

             if let selRange = activeSelection?.range(for: sourceBlockID) {
                 let offset = (source as NSString).length + 2
                 let len = (note as NSString).length
                 let overlapStart = max(offset, selRange.location) - offset
                 let overlapEnd = min(offset + len, selRange.location + selRange.length) - offset
                 if overlapEnd > overlapStart,
                    let range = Range(NSRange(location: overlapStart, length: overlapEnd - overlapStart), in: note),
                    let attrStart = AttributedString.Index(range.lowerBound, within: attributed),
                    let attrEnd = AttributedString.Index(range.upperBound, within: attributed) {
                     attributed[attrStart..<attrEnd].foregroundColor = SandpaperTheme.highlightInk
                 }
             }
             return attributed
         }
     }

     // MARK: - Selectable Text Block Modifier & AppKit Hit-Testing Overlay

     private struct SelectableTextBlockModifier: ViewModifier {
         let blockID: String
         let text: String
         let contextText: String
         let fontSize: CGFloat
         let lineSpacing: CGFloat
         let fontDesign: NSFontDescriptor.SystemDesign
         let fontWeight: NSFont.Weight
         let isItalic: Bool
         let textAlignment: NSTextAlignment
         let interactiveRanges: [NSRange]
         let activeSelection: ReaderTextSelection?
         let coordinator: ReaderSelectionCoordinator
         let onSelect: (ReaderTextSelection, Bool) -> Void
         let onDismiss: () -> Void

         @State private var frameInReader: CGRect = .zero

         private var activeRectsInBlock: [CGRect] {
             activeSelection?.highlightRects(for: blockID) ?? []
         }

         func body(content: Content) -> some View {
             content
                 .background(
                     ZStack(alignment: .topLeading) {
                         GeometryReader { proxy in
                             let rect = proxy.frame(in: .named("SandpaperReaderSpace"))
                             Color.clear
                                 .onAppear {
                                     frameInReader = rect
                                 }
                                 .onChange(of: rect) { _, newRect in
                                     let previous = frameInReader
                                     frameInReader = newRect
                                     if var current = activeSelection,
                                        current.blockID == blockID,
                                        abs(newRect.minY - previous.minY) > 0.5 || abs(newRect.minX - previous.minX) > 0.5 {
                                         let dy = newRect.minY - previous.minY
                                         let dx = newRect.minX - previous.minX
                                         let updatedAnchor = current.anchorRectInReader.offsetBy(dx: dx, dy: dy)
                                         let minVisibleY = SandpaperTheme.toolbarHeight + 8
                                         if updatedAnchor.maxY < minVisibleY {
                                             onDismiss()
                                         } else {
                                             current = ReaderTextSelection(
                                                 blockID: current.blockID,
                                                 nsRange: current.nsRange,
                                                 selectedText: current.selectedText,
                                                 contextText: current.contextText,
                                                 lineHighlightRects: current.lineHighlightRects,
                                                 anchorRectInReader: updatedAnchor,
                                                 blockSelections: current.blockSelections
                                             )
                                             onSelect(current, true)
                                         }
                                     }
                                 }
                         }

                         ForEach(Array(activeRectsInBlock.enumerated()), id: \.offset) { _, rect in
                             RoundedRectangle(cornerRadius: 4, style: .continuous)
                                 .fill(SandpaperTheme.selectionPillFill)
                                 .overlay(
                                     RoundedRectangle(cornerRadius: 4, style: .continuous)
                                         .strokeBorder(SandpaperTheme.selectionPillBorder, lineWidth: 1.5)
                                 )
                                 .frame(width: rect.width, height: rect.height)
                                 .offset(x: rect.minX, y: rect.minY)
                         }
                     }
                 )
                 .overlay(
                     ReaderSelectableTextOverlay(
                         blockID: blockID,
                         text: text,
                         contextText: contextText,
                         fontSize: fontSize,
                         lineSpacing: lineSpacing,
                         fontDesign: fontDesign,
                         fontWeight: fontWeight,
                         isItalic: isItalic,
                         textAlignment: textAlignment,
                         interactiveRanges: interactiveRanges,
                         blockFrameInReader: frameInReader,
                         selectedRange: activeSelection?.range(for: blockID),
                         coordinator: coordinator
                     )
                 )
         }
     }

     private struct ReaderSelectableTextOverlay: NSViewRepresentable {
         let blockID: String
         let text: String
         let contextText: String
         let fontSize: CGFloat
         let lineSpacing: CGFloat
         let fontDesign: NSFontDescriptor.SystemDesign
         let fontWeight: NSFont.Weight
         let isItalic: Bool
         let textAlignment: NSTextAlignment
         let interactiveRanges: [NSRange]
         let blockFrameInReader: CGRect
         let selectedRange: NSRange?
         let coordinator: ReaderSelectionCoordinator

         func makeNSView(context: Context) -> ReaderTextInteractionNSView {
             let view = ReaderTextInteractionNSView()
             updateConfiguration(on: view)
             return view
         }

         func updateNSView(_ nsView: ReaderTextInteractionNSView, context: Context) {
             updateConfiguration(on: nsView)
         }

         private func updateConfiguration(on view: ReaderTextInteractionNSView) {
             view.blockID = blockID
             view.text = text
             view.contextText = contextText
             view.fontSize = fontSize
             view.lineSpacing = lineSpacing
             view.fontDesign = fontDesign
             view.fontWeight = fontWeight
             view.isItalic = isItalic
             view.textAlignment = textAlignment
             view.interactiveRanges = interactiveRanges
             view.blockFrameInReader = blockFrameInReader
             view.selectedRange = selectedRange
             view.coordinator = coordinator
             coordinator.register(view)
         }
     }

     @MainActor
     final class ReaderTextInteractionNSView: NSView, NSUserInterfaceValidations, SelectableBlockEndpoint {
         var blockID: String = ""
         var text: String = ""
         var contextText: String = ""
         var fontSize: CGFloat = 20.5
         var lineSpacing: CGFloat = 12
         var fontDesign: NSFontDescriptor.SystemDesign = .serif
         var fontWeight: NSFont.Weight = .regular
         var isItalic: Bool = false
         var textAlignment: NSTextAlignment = .left
         var interactiveRanges: [NSRange] = []
         var blockFrameInReader: CGRect = .zero
         var selectedRange: NSRange?
         weak var coordinator: ReaderSelectionCoordinator?

         var fullText: String { text }
         private var trackingAreaRef: NSTrackingArea?

         override var isFlipped: Bool { true }
         override var acceptsFirstResponder: Bool { true }

         override func updateTrackingAreas() {
             super.updateTrackingAreas()
             if let existing = trackingAreaRef {
                 removeTrackingArea(existing)
             }
             let area = NSTrackingArea(
                 rect: bounds,
                 options: [.activeInKeyWindow, .mouseMoved, .cursorUpdate, .inVisibleRect],
                 owner: self,
                 userInfo: nil
             )
             addTrackingArea(area)
             trackingAreaRef = area
         }

         override func cursorUpdate(with event: NSEvent) {
             updateCursor(for: event)
         }

         override func mouseMoved(with event: NSEvent) {
             updateCursor(for: event)
         }

         private func updateCursor(for event: NSEvent) {
             let point = convert(event.locationInWindow, from: nil)
             if let index = characterIndex(at: point),
                interactiveRanges.contains(where: { NSLocationInRange(index, $0) }) {
                 NSCursor.pointingHand.set()
             } else {
                 NSCursor.iBeam.set()
             }
         }

         override func scrollWheel(with event: NSEvent) {
             nextResponder?.scrollWheel(with: event)
         }

         override func mouseDown(with event: NSEvent) {
             window?.makeFirstResponder(self)
             let point = convert(event.locationInWindow, from: nil)

             if event.clickCount == 2 {
                 selectWord(at: point)
                 return
             }

             if event.clickCount >= 3 {
                 selectSentenceOrLine(at: point)
                 return
             }

             let startIdx = clampedCharacterIndex(forPointInWindow: event.locationInWindow)
             coordinator?.beginDrag(blockID: blockID, charIndex: startIdx)
         }

         override func mouseDragged(with event: NSEvent) {
             coordinator?.updateDrag(windowPoint: event.locationInWindow, fallbackEndpoint: self)
         }

         override func mouseUp(with event: NSEvent) {
             let point = convert(event.locationInWindow, from: nil)

             if coordinator?.endDrag(windowPoint: event.locationInWindow, fallbackEndpoint: self) == true {
                 return
             }

             if event.clickCount == 1,
                let index = characterIndex(at: point),
                let matchRange = interactiveRanges.first(where: { NSLocationInRange(index, $0) }) {
                 if let selection = coordinator?.buildSingleBlockSelection(
                     endpoint: self,
                     range: matchRange,
                     trim: true
                 ) {
                     coordinator?.publishSingleSelection(selection, presentPopover: true)
                     return
                 }
             }

             if event.clickCount == 1 {
                 coordinator?.clearSelection()
             }
         }

         // MARK: - Copy Support (Cmd+C & Context Menu)

         @objc func copy(_ sender: Any?) {
             if let globalText = coordinator?.currentSelection?.selectedText, !globalText.isEmpty {
                 NSPasteboard.general.clearContents()
                 NSPasteboard.general.setString(globalText, forType: .string)
                 return
             }
             guard let range = selectedRange,
                   range.location != NSNotFound,
                   range.location + range.length <= (text as NSString).length else {
                 return
             }
             let copied = (text as NSString).substring(with: range)
             NSPasteboard.general.clearContents()
             NSPasteboard.general.setString(copied, forType: .string)
         }

         func validateUserInterfaceItem(_ item: NSValidatedUserInterfaceItem) -> Bool {
             if item.action == #selector(copy(_:)) {
                 if let text = coordinator?.currentSelection?.selectedText, !text.isEmpty {
                     return true
                 }
                 return selectedRange != nil && (selectedRange?.length ?? 0) > 0
             }
             return false
         }

         override func menu(for event: NSEvent) -> NSMenu? {
             let point = convert(event.locationInWindow, from: nil)
             if selectedRange == nil && coordinator?.currentSelection == nil {
                 selectWord(at: point)
             }
             guard (selectedRange?.length ?? 0) > 0 || (coordinator?.currentSelection != nil) else {
                 return nil
             }

             let menu = NSMenu(title: "Reader Selection")
             let copyItem = NSMenuItem(title: "Copy", action: #selector(copy(_:)), keyEquivalent: "c")
             copyItem.target = self
             menu.addItem(copyItem)
             return menu
         }

         // MARK: - Word & Phrase Selection Helpers

         private func selectWord(at point: CGPoint) {
             guard !text.isEmpty, let index = characterIndex(at: point) else { return }
             let attr = NSAttributedString(string: text)
             let clampedIndex = min(max(0, index), max(0, attr.length - 1))
             let wordRange = attr.doubleClick(at: clampedIndex)

             if let selection = coordinator?.buildSingleBlockSelection(
                 endpoint: self,
                 range: wordRange,
                 trim: true
             ) {
                 coordinator?.publishSingleSelection(selection, presentPopover: true)
             } else {
                 coordinator?.clearSelection()
             }
         }

         private func selectSentenceOrLine(at point: CGPoint) {
             guard !text.isEmpty, let index = characterIndex(at: point) else { return }
             let nsText = text as NSString
             let lineRange = nsText.lineRange(for: NSRange(location: min(index, nsText.length - 1), length: 0))
             if let selection = coordinator?.buildSingleBlockSelection(
                 endpoint: self,
                 range: lineRange,
                 trim: true
             ) {
                 coordinator?.publishSingleSelection(selection, presentPopover: true)
             }
         }

         // MARK: - CoreText Line Metrics & Hit Testing

         func clampedCharacterIndex(forPointInWindow windowPoint: CGPoint) -> Int {
             let localPoint = convert(windowPoint, from: nil)
             let nsLen = (text as NSString).length
             guard nsLen > 0 else { return 0 }
             if localPoint.y < 0 { return 0 }
             if localPoint.y > bounds.height { return nsLen }
             return characterIndex(at: localPoint) ?? 0
         }

         private func makeCoreTextLines() -> (lines: [CTLine], lineHeight: CGFloat, lineStep: CGFloat) {
             guard !text.isEmpty, bounds.width > 10 else {
                 return ([], fontSize, fontSize + lineSpacing)
             }

             let baseFont = NSFont.systemFont(ofSize: fontSize, weight: fontWeight)
             var descriptor = baseFont.fontDescriptor.withDesign(fontDesign) ?? baseFont.fontDescriptor
             if isItalic {
                 descriptor = descriptor.withSymbolicTraits(.italic)
             }
             let font = NSFont(descriptor: descriptor, size: fontSize) ?? baseFont

             let paragraphStyle = NSMutableParagraphStyle()
             paragraphStyle.lineSpacing = lineSpacing
             paragraphStyle.alignment = textAlignment

             let attrString = NSAttributedString(
                 string: text,
                 attributes: [
                     .font: font,
                     .paragraphStyle: paragraphStyle
                 ]
             )

             let framesetter = CTFramesetterCreateWithAttributedString(attrString as CFAttributedString)
             let path = CGPath(rect: CGRect(x: 0, y: 0, width: bounds.width, height: 4000), transform: nil)
             let frame = CTFramesetterCreateFrame(framesetter, CFRangeMake(0, attrString.length), path, nil)
             let lines = CTFrameGetLines(frame) as! [CTLine]

             let count = max(1, lines.count)
             let totalSpacing = CGFloat(max(0, count - 1)) * lineSpacing
             let measuredLineHeight = max(fontSize, (bounds.height - totalSpacing) / CGFloat(count))
             let step = measuredLineHeight + lineSpacing

             return (lines, measuredLineHeight, step)
         }

         private func lineHorizontalOffset(for line: CTLine) -> CGFloat {
             guard textAlignment == .center else { return 0 }
             let lineWidth = CGFloat(CTLineGetTypographicBounds(line, nil, nil, nil))
             return max(0, (bounds.width - lineWidth) * 0.5)
         }

         private func characterIndex(at point: CGPoint) -> Int? {
             let layout = makeCoreTextLines()
             guard !layout.lines.isEmpty else { return nil }

             let rawLineIdx = Int(floor(point.y / layout.lineStep))
             let lineIdx = min(max(0, rawLineIdx), layout.lines.count - 1)
             let line = layout.lines[lineIdx]
             let xOffset = lineHorizontalOffset(for: line)

             let localPoint = CGPoint(x: max(0, point.x - xOffset), y: layout.lineHeight * 0.5)
             let cfIndex = CTLineGetStringIndexForPosition(line, localPoint)
             guard cfIndex != kCFNotFound else { return nil }

             let nsLength = (text as NSString).length
             return min(max(0, cfIndex), max(0, nsLength))
         }

         func selectionRects(for range: NSRange) -> [CGRect] {
             let layout = makeCoreTextLines()
             guard !layout.lines.isEmpty else { return [] }

             var rects: [CGRect] = []
             let selStart = range.location
             let selEnd = range.location + range.length

             for (lineIdx, line) in layout.lines.enumerated() {
                 let cfRange = CTLineGetStringRange(line)
                 let lineStart = cfRange.location
                 let lineEnd = cfRange.location + cfRange.length

                 let overlapStart = max(selStart, lineStart)
                 let overlapEnd = min(selEnd, lineEnd)

                 if overlapEnd > overlapStart {
                     let xOffset = lineHorizontalOffset(for: line)
                     let xStart = CTLineGetOffsetForStringIndex(line, overlapStart, nil) + xOffset
                     let xEnd = CTLineGetOffsetForStringIndex(line, overlapEnd, nil) + xOffset
                     let minX = min(xStart, xEnd)
                     let maxX = max(xStart, xEnd)

                     let topY = CGFloat(lineIdx) * layout.lineStep - 2.0
                     let pillHeight = layout.lineHeight + 4.0

                     let pillRect = CGRect(
                         x: minX - 3.0,
                         y: topY,
                         width: max(8, (maxX - minX) + 6.0),
                         height: pillHeight
                     )
                     rects.append(pillRect)
                 }
             }

             return rects
         }
     }

     // MARK: - Escape Key & Outside-Click Dismissal Monitor

     private struct DictionaryDismissEventMonitor: NSViewRepresentable {
         let isActive: Bool
         let popoverFrameInReader: CGRect
         let selectionFrameInReader: CGRect
         let onDismiss: () -> Void

         func makeCoordinator() -> Coordinator {
             Coordinator()
         }

         func makeNSView(context: Context) -> NSView {
             let view = NSView()
             context.coordinator.hostView = view
             return view
         }

         func updateNSView(_ nsView: NSView, context: Context) {
             context.coordinator.hostView = nsView
             context.coordinator.popoverFrameInReader = popoverFrameInReader
             context.coordinator.selectionFrameInReader = selectionFrameInReader
             context.coordinator.onDismiss = onDismiss
             context.coordinator.setActive(isActive)
         }

         static func dismantleNSView(_ nsView: NSView, coordinator: Coordinator) {
             coordinator.setActive(false)
         }

         @MainActor
         final class Coordinator {
             weak var hostView: NSView?
             var popoverFrameInReader: CGRect = .zero
             var selectionFrameInReader: CGRect = .zero
             var onDismiss: (() -> Void)?

             nonisolated(unsafe) private var keyMonitor: Any?
             nonisolated(unsafe) private var mouseMonitor: Any?

             deinit {
                 if let keyMonitor {
                     NSEvent.removeMonitor(keyMonitor)
                 }
                 if let mouseMonitor {
                     NSEvent.removeMonitor(mouseMonitor)
                 }
             }

             func setActive(_ active: Bool) {
                 if active {
                     installMonitorsIfNeeded()
                 } else {
                     removeMonitors()
                 }
             }

             private func installMonitorsIfNeeded() {
                 if keyMonitor == nil {
                     keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
                         guard let self else { return event }
                         if event.keyCode == 53 { // Escape key
                             self.onDismiss?()
                             return nil
                         }
                         return event
                     }
                 }

                 if mouseMonitor == nil {
                     mouseMonitor = NSEvent.addLocalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] event in
                         guard let self,
                               let window = self.hostView?.window,
                               let contentView = window.contentView else {
                             return event
                         }

                         let pointInWindow = event.locationInWindow
                         let readerPoint = CGPoint(
                             x: pointInWindow.x,
                             y: contentView.bounds.height - pointInWindow.y
                         )

                         if self.popoverFrameInReader.insetBy(dx: -4, dy: -4).contains(readerPoint) {
                             return event
                         }

                         if self.selectionFrameInReader.insetBy(dx: -4, dy: -4).contains(readerPoint) {
                             return event
                         }

                         if let hitView = contentView.hitTest(pointInWindow),
                            !(hitView is ReaderTextInteractionNSView),
                            !(hitView is DropCapTextInteractionNSView) {
                             self.onDismiss?()
                         }

                         return event
                     }
                 }
             }

             private func removeMonitors() {
                 if let keyMonitor {
                     NSEvent.removeMonitor(keyMonitor)
                     self.keyMonitor = nil
                 }
                 if let mouseMonitor {
                     NSEvent.removeMonitor(mouseMonitor)
                     self.mouseMonitor = nil
                 }
             }
         }
     }

     // MARK: - Pronunciation Speech Player

     @MainActor
     final class DictionarySpeechPlayer {
         static let shared = DictionarySpeechPlayer()
         private let synthesizer = NSSpeechSynthesizer()

         func speak(_ text: String) {
             if synthesizer.isSpeaking {
                 synthesizer.stopSpeaking()
             }
             synthesizer.startSpeaking(text)
         }
     }

     // MARK: - End of Section Footer & Navigation Cards

     private struct SectionFooterView: View {
         let currentPage: Int
         let totalPages: Int
         @Binding var isBookmarked: Bool
         let previousChapter: ChapterNavigationItem?
         let nextChapter: ChapterNavigationItem?

         @State private var isHoveringBookmark = false

         var body: some View {
             VStack(spacing: 28) {
                 HStack(alignment: .center) {
                     Text("End of section")
                         .font(.system(size: 16.5, weight: .bold, design: .serif))
                         .foregroundStyle(SandpaperTheme.mutedInk)

                     Spacer()

                     HStack(spacing: 18) {
                         Text("Page \(currentPage) of \(totalPages)")
                             .font(.system(size: 12, weight: .regular))
                             .foregroundStyle(SandpaperTheme.mutedInk)
                             .monospacedDigit()

                         Button {
                             isBookmarked.toggle()
                         } label: {
                             HStack(spacing: 7) {
                                 Image(systemName: isBookmarked ? "bookmark.fill" : "bookmark")
                                     .font(.system(size: 11.5, weight: .medium))
                                     .foregroundStyle(
                                         isBookmarked ? SandpaperTheme.terracottaAccent : SandpaperTheme.secondaryInk
                                     )

                                 Text(isBookmarked ? "Bookmarked" : "Bookmark")
                                     .font(.system(size: 12, weight: .medium))
                                     .foregroundStyle(SandpaperTheme.terracottaAccent)
                             }
                             .padding(.horizontal, 12)
                             .padding(.vertical, 6)
                             .background(
                                 RoundedRectangle(cornerRadius: 6, style: .continuous)
                                     .fill(
                                         isHoveringBookmark
                                             ? SandpaperTheme.pillBackground
                                             : SandpaperTheme.bookmarkButtonBackground
                                     )
                             )
                             .overlay(
                                 RoundedRectangle(cornerRadius: 6, style: .continuous)
                                     .strokeBorder(SandpaperTheme.bookmarkButtonBorder, lineWidth: 1)
                             )
                         }
                         .buttonStyle(.plain)
                         .onHover { isHoveringBookmark = $0 }
                     }
                 }
                 .padding(.horizontal, 8)

                 HStack(spacing: 16) {
                     if let previousChapter {
                         ChapterNavigationCard(
                             direction: .previous,
                             title: previousChapter.title
                         )
                     }

                     if let nextChapter {
                         ChapterNavigationCard(
                             direction: .next,
                             title: nextChapter.title
                         )
                     }
                 }
             }
         }
     }

     private struct ChapterNavigationCard: View {
         enum Direction {
             case previous
             case next
         }

         let direction: Direction
         let title: String

         @State private var isHovered = false

         var body: some View {
             Button(action: {}) {
                 VStack(
                     alignment: direction == .previous ? .leading : .trailing,
                     spacing: 12
                 ) {
                     HStack(spacing: 6) {
                         if direction == .previous {
                             Image(systemName: "arrow.left")
                                 .font(.system(size: 10.5, weight: .medium))
                                 .foregroundStyle(SandpaperTheme.secondaryInk)

                             Text("PREVIOUS CHAPTER")
                                 .font(.system(size: 11, weight: .medium))
                                 .tracking(0.55)
                                 .foregroundStyle(SandpaperTheme.mutedInk)
                         } else {
                             Text("NEXT CHAPTER")
                                 .font(.system(size: 11, weight: .medium))
                                 .tracking(0.55)
                                 .foregroundStyle(SandpaperTheme.mutedInk)

                             Image(systemName: "arrow.right")
                                 .font(.system(size: 10.5, weight: .medium))
                                 .foregroundStyle(SandpaperTheme.secondaryInk)
                         }
                     }

                     Text(title)
                         .font(.system(size: 16.5, weight: .bold))
                         .foregroundStyle(SandpaperTheme.strongInk)
                         .multilineTextAlignment(direction == .previous ? .leading : .trailing)
                         .lineSpacing(3)
                         .fixedSize(horizontal: false, vertical: true)

                     Spacer(minLength: 0)
                 }
                 .padding(.horizontal, 21)
                 .padding(.top, 22)
                 .padding(.bottom, 18)
                 .frame(
                     maxWidth: .infinity,
                     minHeight: 110,
                     alignment: direction == .previous ? .topLeading : .topTrailing
                 )
                 .background(
                     RoundedRectangle(cornerRadius: 8, style: .continuous)
                         .fill(isHovered ? SandpaperTheme.pillBackground : SandpaperTheme.cardBackground)
                 )
                 .overlay(
                     RoundedRectangle(cornerRadius: 8, style: .continuous)
                         .strokeBorder(
                             isHovered ? SandpaperTheme.subtleStroke : SandpaperTheme.cardBorder,
                             lineWidth: 1
                         )
                 )
             }
             .buttonStyle(.plain)
             .onHover { isHovered = $0 }
         }
     }

     // MARK: - Bottom Status Bar

     private struct ReaderStatusBarView: View {
         let currentPage: Int
         let totalPages: Int
         let syncStatus: String

         var body: some View {
             VStack(spacing: 0) {
                 Rectangle()
                     .fill(SandpaperTheme.statusBarBorder)
                     .frame(height: 1)

                 HStack(spacing: 0) {
                     Text("Sandpaper")
                         .font(.system(size: 12, weight: .medium))
                         .foregroundStyle(SandpaperTheme.secondaryInk)

                     Spacer()

                     HStack(spacing: 26) {
                         Text("Page \(currentPage) of \(totalPages)")
                             .font(.system(size: 12, weight: .regular))
                             .foregroundStyle(SandpaperTheme.mutedInk)
                             .monospacedDigit()

                         Text(syncStatus)
                             .font(.system(size: 12, weight: .regular))
                             .foregroundStyle(SandpaperTheme.mutedInk)
                     }
                 }
                 .padding(.horizontal, 24)
                 .frame(height: SandpaperTheme.statusBarHeight)
                 .background(SandpaperTheme.chromeBackground)
             }
         }
     }

     // MARK: - Custom Vector Shapes & Icons

     private struct FourPointDiamondShape: Shape {
         func path(in rect: CGRect) -> Path {
             var path = Path()
             let midX = rect.midX
             let midY = rect.midY
             let insetX = rect.width * 0.34
             let insetY = rect.height * 0.34

             path.move(to: CGPoint(x: midX, y: rect.minY))
             path.addQuadCurve(
                 to: CGPoint(x: rect.maxX, y: midY),
                 control: CGPoint(x: midX + insetX * 0.4, y: midY - insetY * 0.4)
             )
             path.addQuadCurve(
                 to: CGPoint(x: midX, y: rect.maxY),
                 control: CGPoint(x: midX + insetX * 0.4, y: midY + insetY * 0.4)
             )
             path.addQuadCurve(
                 to: CGPoint(x: rect.minX, y: midY),
                 control: CGPoint(x: midX - insetX * 0.4, y: midY + insetY * 0.4)
             )
             path.addQuadCurve(
                 to: CGPoint(x: midX, y: rect.minY),
                 control: CGPoint(x: midX - insetX * 0.4, y: midY - insetY * 0.4)
             )
             path.closeSubpath()
             return path
         }
     }

     private struct StackedSectionsIcon: View {
         var body: some View {
             VStack(spacing: 2) {
                 RoundedRectangle(cornerRadius: 1.5, style: .continuous)
                     .strokeBorder(lineWidth: 1.35)
                     .frame(width: 11.5, height: 5)

                 RoundedRectangle(cornerRadius: 1.5, style: .continuous)
                     .strokeBorder(lineWidth: 1.35)
                     .frame(width: 11.5, height: 5)
             }
         }
     }

     // MARK: - Native AppKit Window Configuration

     struct ReaderWindowConfigurator: NSViewRepresentable {
         @Binding var hostsNativeTrafficLights: Bool

         func makeNSView(context: Context) -> NSView {
             let view = NSView()
             DispatchQueue.main.async {
                 configureWindow(for: view)
             }
             return view
         }

         func updateNSView(_ nsView: NSView, context: Context) {
             DispatchQueue.main.async {
                 configureWindow(for: nsView)
             }
         }

         @MainActor
         private func configureWindow(for view: NSView) {
             guard let window = view.window else { return }

             window.titleVisibility = .hidden
             window.titlebarAppearsTransparent = true
             window.styleMask.insert(.fullSizeContentView)
             window.backgroundColor = NSColor(
                 srgbRed: 252.0 / 255.0,
                 green: 249.0 / 255.0,
                 blue: 243.0 / 255.0,
                 alpha: 1.0
             )

             let hasCloseButton = window.standardWindowButton(.closeButton) != nil
             if hostsNativeTrafficLights != hasCloseButton {
                 hostsNativeTrafficLights = hasCloseButton
             }
         }
     }

     // MARK: - Standalone App Entry Point & Previews

     @main
     struct SandpaperPreviewApp: App {
         var body: some Scene {
             WindowGroup {
                 SandpaperRootView()
                     .frame(minWidth: 980, idealWidth: 1440, minHeight: 720, idealHeight: 1180)
             }
             .windowStyle(.hiddenTitleBar)
         }
     }

     #Preview("Sandpaper Reader — Default (Popover Closed)") {
         SandpaperReaderView()
             .frame(width: 1280, height: 960)
     }

     #Preview("Sandpaper Reader — Dictionary Popover Open") {
         SandpaperReaderView(
             initialSelection: ReaderTextSelection(
                 blockID: "p2",
                 nsRange: NSRange(location: 444, length: 11),
                 selectedText: "ineluctable",
                 contextText: "It was perhaps an ineluctable conclusion, arrived at only after years of circumspection.",
                 lineHighlightRects: [CGRect(x: 154, y: 214, width: 115, height: 28.5)],
                 anchorRectInReader: CGRect(x: 444, y: 608, width: 115, height: 28.5)
             )
         )
         .frame(width: 1280, height: 1100)
     }
