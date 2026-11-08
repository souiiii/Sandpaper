import SwiftUI
import AppKit
import Observation

// MARK: - Personal Lexicon Models

enum LexiconCategoryFilter: String, CaseIterable, Identifiable, Sendable {
    case allExpressions = "All Expressions"
    case nuancedSenses = "Nuanced Senses"
    case idiomsAndPhrasing = "Idioms & Phrasing"
    case archaicAndClassical = "Archaic & Classical"

    var id: String { rawValue }
}

enum LexiconViewMode: String, CaseIterable, Identifiable, Sendable {
    case splitView = "Split View"
    case catalog = "Catalog"

    var id: String { rawValue }
}

enum LexiconSortOrder: String, CaseIterable, Identifiable, Sendable {
    case recentlyEncountered = "Recently Encountered"
    case alphabetical = "Alphabetical (A–Z)"
    case byBook = "By Book Title"

    var id: String { rawValue }
}

struct LexiconParallelSense: Identifiable, Equatable, Sendable {
    let id: String
    let workAndAuthor: String
    let sectionLabel: String
    let quote: String
    let commentary: String
}

struct LexiconEntry: Identifiable, Equatable, Sendable {
    let id: String
    let expression: String
    let shortPartOfSpeech: String
    let phonetic: String
    let grammaticalTags: [String]
    let category: LexiconCategoryFilter
    let shortDefinition: String
    let fullDefinition: String
    let etymology: String?
    let bookID: String
    let bookTitle: String
    let author: String
    let chapterLabel: String
    let sourcePassage: String
    let encounteredRelative: String
    let sortRank: Int
    var marginalNote: String
    let parallelSenses: [LexiconParallelSense]

    /// Contextual identity combining the expression, book, and specific source passage
    /// so identical words saved from different contexts remain separate entries.
    static func makeContextualID(
        expression: String,
        bookID: String,
        sourcePassage: String
    ) -> String {
        let normExpr = expression.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let normBook = bookID.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let normPassage = String(
            sourcePassage.trimmingCharacters(in: .whitespacesAndNewlines).lowercased().prefix(80)
        )
        return "\(normExpr)::\(normBook)::\(normPassage)"
    }
}

// MARK: - Shared In-Memory Vocabulary Store

@Observable
@MainActor
final class SandpaperVocabularyStore {
    var entries: [LexiconEntry]
    let baselineTotalSavedCount: Int = 84
    let baselineBookCount: Int = 6
    private let initialEntryCount: Int

    init(entries: [LexiconEntry] = SandpaperVocabularyStore.defaultMockEntries) {
        self.entries = entries
        self.initialEntryCount = entries.count
    }

    var displayedTotalCount: Int {
        max(entries.count, baselineTotalSavedCount + (entries.count - initialEntryCount))
    }

    func containsContextualEntry(
        expression: String,
        bookID: String,
        sourcePassage: String
    ) -> Bool {
        let contextualID = LexiconEntry.makeContextualID(
            expression: expression,
            bookID: bookID,
            sourcePassage: sourcePassage
        )
        return entries.contains { $0.id == contextualID }
    }

    func toggleContextualEntry(
        dictionaryEntry: DictionaryEntry,
        selectedText: String,
        sourcePassage: String,
        chapter: BookChapter,
        bookID: String
    ) {
        let cleanPassage = sourcePassage
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "“", with: "")
            .replacingOccurrences(of: "”", with: "")

        let contextualID = LexiconEntry.makeContextualID(
            expression: dictionaryEntry.expression,
            bookID: bookID,
            sourcePassage: cleanPassage
        )

        if let existingIndex = entries.firstIndex(where: { $0.id == contextualID }) {
            entries.remove(at: existingIndex)
            return
        }

        let isPhrase = dictionaryEntry.expression.contains(" ")
        let shortPOS: String = {
            let lower = dictionaryEntry.partOfSpeech.lowercased()
            if lower.contains("adjective") { return "adj." }
            if lower.contains("noun") { return "n." }
            if lower.contains("phrase") { return "phrasing" }
            if lower.contains("idiom") { return "idiom" }
            return "expr."
        }()

        let tags: [String] = {
            let raw = dictionaryEntry.partOfSpeech
            if let parenIndex = raw.firstIndex(of: "(") {
                let first = String(raw[..<parenIndex]).trimmingCharacters(in: .whitespaces)
                let second = String(raw[parenIndex...])
                    .replacingOccurrences(of: "(", with: "")
                    .replacingOccurrences(of: ")", with: "")
                    .replacingOccurrences(of: "/", with: " / ")
                    .trimmingCharacters(in: .whitespaces)
                return [first, second].filter { !$0.isEmpty }
            }
            return [raw]
        }()

        let fullDef: String = {
            if let closing = dictionaryEntry.emphasizedClosing, !closing.isEmpty {
                return "\(dictionaryEntry.definition) \(closing)"
            }
            return dictionaryEntry.definition
        }()

        let newEntry = LexiconEntry(
            id: contextualID,
            expression: dictionaryEntry.expression,
            shortPartOfSpeech: shortPOS,
            phonetic: dictionaryEntry.phonetic,
            grammaticalTags: tags,
            category: isPhrase ? .idiomsAndPhrasing : .nuancedSenses,
            shortDefinition: fullDef,
            fullDefinition: fullDef,
            etymology: "Saved from contextual lookup in \(chapter.bookTitle) (\(chapter.chapterLabel)).",
            bookID: bookID,
            bookTitle: chapter.bookTitle,
            author: chapter.author,
            chapterLabel: chapter.chapterLabel,
            sourcePassage: cleanPassage.isEmpty ? selectedText : cleanPassage,
            encounteredRelative: "Just now",
            sortRank: (entries.map(\.sortRank).min() ?? 1) - 1,
            marginalNote: "Captured while reading \(chapter.chapterLabel) at \(chapter.locationTitle). The expression anchors the narrator's measured tone in this passage.",
            parallelSenses: []
        )

        entries.insert(newEntry, at: 0)
    }

    func removeEntry(withID id: String) {
        entries.removeAll { $0.id == id }
    }

    func updateNote(for id: String, newNote: String) {
        guard let idx = entries.firstIndex(where: { $0.id == id }) else { return }
        entries[idx].marginalNote = newNote
    }

    var libraryPreviewItems: [LibraryVocabularyPreviewItem] {
        entries.prefix(2).map { entry in
            LibraryVocabularyPreviewItem(
                id: entry.id,
                word: entry.expression,
                partOfSpeech: entry.shortPartOfSpeech,
                bookTitle: entry.bookTitle,
                definition: entry.shortDefinition
            )
        }
    }
}

// MARK: - Default Mock Lexicon Entries (Matching Reference Screenshot)

extension SandpaperVocabularyStore {
    static let defaultMockEntries: [LexiconEntry] = [
        LexiconEntry(
            id: LexiconEntry.makeContextualID(
                expression: "ineluctable",
                bookID: "remains-of-the-day",
                sourcePassage: "It was perhaps an ineluctable conclusion, arrived at only after years of circumspection, that Miss Kenton's letter had carried beneath its cordial domestic pleasantries a note of unmistakable despondency."
            ),
            expression: "ineluctable",
            shortPartOfSpeech: "adj.",
            phonetic: "[ˌɪn.ɪˈlʌk.tə.bəl]",
            grammaticalTags: ["adjective", "formal / literary"],
            category: .archaicAndClassical,
            shortDefinition: "Unable to be avoided, evaded, or resisted; inescapable.",
            fullDefinition: "Unable to be avoided, evaded, or resisted; inescapable.",
            etymology: "Etymology: Latin ineluctābilis (in- 'not' + eluctari 'to struggle out of')",
            bookID: "remains-of-the-day",
            bookTitle: "The Remains of the Day",
            author: "Kazuo Ishiguro",
            chapterLabel: "Day Three: Evening",
            sourcePassage: "It was perhaps an ineluctable conclusion, arrived at only after years of circumspection, that Miss Kenton's letter had carried beneath its cordial domestic pleasantries a note of unmistakable despondency.",
            encounteredRelative: "2d ago",
            sortRank: 1,
            marginalNote: "Stevens consistently leans on Latinate, formalist adjectives like 'ineluctable' and 'unseemly' whenever he is on the precipice of acknowledging profound personal regret. Notice how elevating his grief into an abstract cosmic decree shields him from the agony of voluntary complicity.",
            parallelSenses: [
                LexiconParallelSense(
                    id: "ulysses-proteus",
                    workAndAuthor: "Ulysses · James Joyce",
                    sectionLabel: "Proteus Episode",
                    quote: "\"Ineluctable modality of the visible: at least that if no more, thought through my eyes. Signatures of all things I am here to read...\"",
                    commentary: "Used here in an epistemological/perceptual sense: the unavoidable nature of visual reality pressing on human consciousness."
                )
            ]
        ),
        LexiconEntry(
            id: LexiconEntry.makeContextualID(
                expression: "the course one's life took",
                bookID: "remains-of-the-day",
                sourcePassage: "What is the point of worrying oneself so much about what one could or could not have done to control the course one's life took?"
            ),
            expression: "the course one's life took",
            shortPartOfSpeech: "idiom",
            phonetic: "[ðə kɔːs wʌnz laɪf tʊk]",
            grammaticalTags: ["idiom", "reflective / impersonal"],
            category: .idiomsAndPhrasing,
            shortDefinition: "Passive fatalism; framing one's biography as an unsteered river.",
            fullDefinition: "Passive fatalism; framing one's biography as an unsteered river rather than a sequence of deliberate moral choices.",
            etymology: "Idiomatic English construction pairing 'course' (Latin cursus, 'running,流') with an impersonal possessive.",
            bookID: "remains-of-the-day",
            bookTitle: "The Remains of the Day",
            author: "Kazuo Ishiguro",
            chapterLabel: "Day Six: Evening",
            sourcePassage: "What is the point of worrying oneself so much about what one could or could not have done to control the course one's life took?",
            encounteredRelative: "3d ago",
            sortRank: 2,
            marginalNote: "By shifting from 'the choices I made' to 'the course one's life took', Stevens casts himself as a passenger rather than the author of his own decades at Darlington Hall.",
            parallelSenses: [
                LexiconParallelSense(
                    id: "middlemarch-river",
                    workAndAuthor: "Middlemarch · George Eliot",
                    sectionLabel: "Finale",
                    quote: "\"Her full nature, like that river of which Cyrus broke the strength, spent itself in channels which had no great name on the earth.\"",
                    commentary: "Uses the same fluvial metaphor of a life's channel being diverted by surrounding social constraints."
                )
            ]
        ),
        LexiconEntry(
            id: LexiconEntry.makeContextualID(
                expression: "punctilious",
                bookID: "the-peregrine",
                sourcePassage: "With punctilious precision the falcon circled the winter stubble, measuring every hedge-shadow before the stoop."
            ),
            expression: "punctilious",
            shortPartOfSpeech: "adj.",
            phonetic: "[pʌŋkˈtɪl.i.əs]",
            grammaticalTags: ["adjective", "formal"],
            category: .nuancedSenses,
            shortDefinition: "Showing meticulous attention to formal etiquette or code of conduct.",
            fullDefinition: "Showing meticulous attention to minute details, formal etiquette, or exactness of conduct.",
            etymology: "Etymology: Early 17th century from Italian puntiglioso, from puntiglio 'fine point' (diminutive of Latin punctum).",
            bookID: "the-peregrine",
            bookTitle: "The Peregrine",
            author: "J.A. Baker",
            chapterLabel: "Spring: 14 March",
            sourcePassage: "With punctilious precision the falcon circled the winter stubble, measuring every hedge-shadow before the stoop.",
            encounteredRelative: "5d ago",
            sortRank: 3,
            marginalNote: "Baker applies a word normally reserved for courtly manners to an avian predator, giving the hawk's hunting ritual an almost aristocratic severity.",
            parallelSenses: [
                LexiconParallelSense(
                    id: "remains-punctilious",
                    workAndAuthor: "The Remains of the Day · Kazuo Ishiguro",
                    sectionLabel: "Day Two: Morning",
                    quote: "\"My father was always the most punctilious of men in inspecting the silver before a great dinner.\"",
                    commentary: "Used in its classic domestic sense of unwavering adherence to ceremonial standards."
                )
            ]
        ),
        LexiconEntry(
            id: LexiconEntry.makeContextualID(
                expression: "circumscription",
                bookID: "middlemarch",
                sourcePassage: "She felt the stifling circumscription of provincial opinion closing around her ardent plans before they had scarce begun."
            ),
            expression: "circumscription",
            shortPartOfSpeech: "n.",
            phonetic: "[ˌsɜː.kəmˈskrɪp.ʃən]",
            grammaticalTags: ["noun", "literary / philosophical"],
            category: .archaicAndClassical,
            shortDefinition: "The act of enclosing within bounds; moral and behavioral restriction.",
            fullDefinition: "The action of drawing a line around or enclosing within narrow bounds; moral, intellectual, and social restriction.",
            etymology: "Etymology: Latin circumscriptio, from circumscribere (circum 'around' + scribere 'to draw or write').",
            bookID: "middlemarch",
            bookTitle: "Middlemarch",
            author: "George Eliot",
            chapterLabel: "Book I: Miss Brooke",
            sourcePassage: "She felt the stifling circumscription of provincial opinion closing around her ardent plans before they had scarce begun.",
            encounteredRelative: "1w ago",
            sortRank: 4,
            marginalNote: "One of Eliot's central geometric metaphors: the contrast between Dorothea's expansive moral horizon and the tight circle drawn around women's vocation in Tipton.",
            parallelSenses: [
                LexiconParallelSense(
                    id: "othello-circumscription",
                    workAndAuthor: "Othello · William Shakespeare",
                    sectionLabel: "Act I, Scene 2",
                    quote: "\"But that I love the gentle Desdemona, I would not my unhoused free condition put into circumscription and confine...\"",
                    commentary: "Emphasizes the surrender of unbounded personal liberty to domestic and civic boundaries."
                )
            ]
        ),
        LexiconEntry(
            id: LexiconEntry.makeContextualID(
                expression: "meiosis",
                bookID: "notes-of-a-native-son",
                sourcePassage: "To speak of that summer's bitterness as mere unrest is an exercise in defensive meiosis."
            ),
            expression: "meiosis",
            shortPartOfSpeech: "n.",
            phonetic: "[maɪˈəʊ.sɪs]",
            grammaticalTags: ["noun", "rhetoric / classical"],
            category: .archaicAndClassical,
            shortDefinition: "Rhetorical understatement; something presented as less significant than it is.",
            fullDefinition: "A figure of speech employing deliberate understatement, presenting something grave or momentous as less significant than it truly is.",
            etymology: "Etymology: Greek meiōsis 'lessening', from meioun 'to diminish' (from meiōn 'less').",
            bookID: "notes-of-a-native-son",
            bookTitle: "Notes of a Native Son",
            author: "James Baldwin",
            chapterLabel: "Autobiographical Notes",
            sourcePassage: "To speak of that summer's bitterness as mere unrest is an exercise in defensive meiosis.",
            encounteredRelative: "1w ago",
            sortRank: 5,
            marginalNote: "Baldwin diagnoses how polite American prose uses rhetorical diminution to dull the moral shock of racial violence.",
            parallelSenses: []
        ),
        LexiconEntry(
            id: LexiconEntry.makeContextualID(
                expression: "unvarnished weight",
                bookID: "remains-of-the-day",
                sourcePassage: "He was, of course, a stranger; yet his simple words carried with them a peculiar, unvarnished weight."
            ),
            expression: "unvarnished weight",
            shortPartOfSpeech: "phrasing",
            phonetic: "[ʌnˈvɑː.nɪʃt weɪt]",
            grammaticalTags: ["phrasing", "idiomatic / tactile"],
            category: .idiomsAndPhrasing,
            shortDefinition: "Direct, sincere impact unsoftened by social flattery or ornamentation.",
            fullDefinition: "Direct, candid emotional gravity unsoftened by formal polish, social flattery, or rhetorical ornamentation.",
            etymology: "Metaphorical pairing of 'unvarnished' (plain wood without gloss) and physical mass ('weight').",
            bookID: "remains-of-the-day",
            bookTitle: "The Remains of the Day",
            author: "Kazuo Ishiguro",
            chapterLabel: "Day Six: Evening",
            sourcePassage: "He was, of course, a stranger; yet his simple words carried with them a peculiar, unvarnished weight.",
            encounteredRelative: "2w ago",
            sortRank: 6,
            marginalNote: "Because Stevens has spent his entire career varnishing every utterance in professional deference, a retired butler's plainspoken remark on Weymouth Pier strikes him with physical force.",
            parallelSenses: []
        )
    ]
}

// MARK: - Personal Lexicon Main View

struct SandpaperPersonalLexiconView: View {
    @Bindable var store: SandpaperVocabularyStore
    var initialSelectedEntryID: String? = nil
    var onNavigateToLibrary: (@MainActor () -> Void)?
    var onNavigateToReader: (@MainActor (LibraryBook?) -> Void)?
    var onImportBook: (@MainActor () -> Void)?

    @State private var searchText: String = ""
    @State private var selectedCategory: LexiconCategoryFilter = .allExpressions
    @State private var viewMode: LexiconViewMode = .splitView
    @State private var sortOrder: LexiconSortOrder = .recentlyEncountered
    @State private var selectedEntryID: String?
    @State private var hostsNativeTrafficLights: Bool = false

    // Editing & Action Feedback State
    @State private var isEditingNote: Bool = false
    @State private var draftNoteText: String = ""
    @State private var didCopyCitation: Bool = false
    @State private var didExportCommonplace: Bool = false
    @State private var isShowingCrossReferenceToast: Bool = false

    private var filteredEntries: [LexiconEntry] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()

        let filtered = store.entries.filter { entry in
            let matchesCategory: Bool = {
                switch selectedCategory {
                case .allExpressions:
                    return true
                case .nuancedSenses, .idiomsAndPhrasing, .archaicAndClassical:
                    return entry.category == selectedCategory
                }
            }()

            guard matchesCategory else { return false }
            guard !query.isEmpty else { return true }

            return entry.expression.lowercased().contains(query)
                || entry.shortDefinition.lowercased().contains(query)
                || entry.bookTitle.lowercased().contains(query)
                || entry.author.lowercased().contains(query)
                || entry.sourcePassage.lowercased().contains(query)
        }

        return filtered.sorted { a, b in
            switch sortOrder {
            case .recentlyEncountered:
                return a.sortRank < b.sortRank
            case .alphabetical:
                return a.expression.localizedCaseInsensitiveCompare(b.expression) == .orderedAscending
            case .byBook:
                let cmp = a.bookTitle.localizedCaseInsensitiveCompare(b.bookTitle)
                if cmp == .orderedSame {
                    return a.sortRank < b.sortRank
                }
                return cmp == .orderedAscending
            }
        }
    }

    private var activeEntry: LexiconEntry? {
        if let selectedEntryID,
           let match = filteredEntries.first(where: { $0.id == selectedEntryID }) {
            return match
        }
        return filteredEntries.first
    }

    var body: some View {
        VStack(spacing: 0) {
            // 1. Top Application Navigation Bar
            LexiconTopToolbar(
                showsCustomTrafficLights: !hostsNativeTrafficLights,
                onNavigateToLibrary: { onNavigateToLibrary?() },
                onNavigateToReader: { onNavigateToReader?(nil) },
                onImportBook: { onImportBook?() }
            )

            // 2. Personal Lexicon Header & Filter Bar
            LexiconHeaderSectionView(
                totalSavedCount: store.displayedTotalCount,
                bookCount: store.baselineBookCount,
                searchText: $searchText,
                selectedCategory: $selectedCategory,
                viewMode: $viewMode,
                sortOrder: $sortOrder
            )

            // 3. Main Content Area (Split View or Catalog Grid)
            if filteredEntries.isEmpty {
                LexiconEmptyStateView(
                    searchText: searchText,
                    selectedCategory: selectedCategory,
                    onReset: {
                        searchText = ""
                        selectedCategory = .allExpressions
                    }
                )
            } else if viewMode == .catalog {
                LexiconCatalogGridView(
                    entries: filteredEntries,
                    selectedEntryID: activeEntry?.id,
                    onSelectEntry: { entry in
                        selectedEntryID = entry.id
                        withAnimation(.easeOut(duration: 0.16)) {
                            viewMode = .splitView
                        }
                    },
                    onShowInReader: { entry in
                        openBookInReader(for: entry)
                    }
                )
            } else {
                // Default Split View (Matches Reference Screenshot)
                HStack(spacing: 0) {
                    // Left Sidebar: Encountered Lexemes List
                    LexiconSidebarListView(
                        entries: filteredEntries,
                        totalSavedCount: store.displayedTotalCount,
                        selectedEntryID: activeEntry?.id,
                        onSelectEntry: { entry in
                            isEditingNote = false
                            selectedEntryID = entry.id
                        }
                    )

                    // Right Pane: Detailed Lexicon Entry Inspector
                    if let entry = activeEntry {
                        LexiconDetailPaneView(
                            entry: entry,
                            isEditingNote: $isEditingNote,
                            draftNoteText: $draftNoteText,
                            didCopyCitation: didCopyCitation,
                            didExportCommonplace: didExportCommonplace,
                            isShowingCrossReferenceToast: isShowingCrossReferenceToast,
                            onPronounce: {
                                DictionarySpeechPlayer.shared.speak(entry.expression)
                            },
                            onShowInReader: {
                                openBookInReader(for: entry)
                            },
                            onBeginEditNote: {
                                draftNoteText = entry.marginalNote
                                isEditingNote = true
                            },
                            onSaveEditedNote: {
                                store.updateNote(for: entry.id, newNote: draftNoteText)
                                isEditingNote = false
                            },
                            onTriggerCrossReference: {
                                withAnimation(.easeOut(duration: 0.15)) {
                                    isShowingCrossReferenceToast = true
                                }
                                DispatchQueue.main.asyncAfter(deadline: .now() + 1.8) {
                                    withAnimation(.easeOut(duration: 0.15)) {
                                        isShowingCrossReferenceToast = false
                                    }
                                }
                            },
                            onCopyCitation: {
                                copyCitation(for: entry)
                            },
                            onExportCommonplace: {
                                exportToCommonplace(for: entry)
                            },
                            onRemoveWord: {
                                removeEntryAndAdvanceSelection(entry)
                            }
                        )
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .background(SandpaperTheme.canvasBackground)
        .background(
            ReaderWindowConfigurator(hostsNativeTrafficLights: $hostsNativeTrafficLights)
        )
        .ignoresSafeArea(.container, edges: .top)
        .onAppear {
            if let initialSelectedEntryID {
                selectedEntryID = initialSelectedEntryID
            } else if selectedEntryID == nil {
                selectedEntryID = store.entries.first?.id
            }
        }
    }

    private func openBookInReader(for entry: LexiconEntry) {
        let matchedBook = MockLibraryData.allUniqueBooks.first {
            $0.id == entry.bookID || $0.title.caseInsensitiveCompare(entry.bookTitle) == .orderedSame
        } ?? MockLibraryData.readingDeskBooks.first
        onNavigateToReader?(matchedBook)
    }

    private func copyCitation(for entry: LexiconEntry) {
        let citation = "“\(entry.sourcePassage)” — \(entry.author), \(entry.bookTitle) (\(entry.chapterLabel)). Headword: \(entry.expression) (\(entry.shortPartOfSpeech)) — \(entry.fullDefinition)"
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(citation, forType: .string)
        didCopyCitation = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            didCopyCitation = false
        }
    }

    private func exportToCommonplace(for entry: LexiconEntry) {
        let markdown = """
        # \(entry.expression) (\(entry.shortPartOfSpeech))
        \(entry.phonetic) — \(entry.fullDefinition)

        > "\(entry.sourcePassage)"
        > — \(entry.bookTitle) · \(entry.author) (\(entry.chapterLabel))

        **Marginal Note:** \(entry.marginalNote)
        """
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(markdown, forType: .string)
        didExportCommonplace = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            didExportCommonplace = false
        }
    }

    private func removeEntryAndAdvanceSelection(_ entry: LexiconEntry) {
        let currentList = filteredEntries
        let nextSelectionID: String? = {
            guard let idx = currentList.firstIndex(where: { $0.id == entry.id }) else {
                return currentList.first?.id
            }
            if idx + 1 < currentList.count {
                return currentList[idx + 1].id
            } else if idx - 1 >= 0 {
                return currentList[idx - 1].id
            }
            return nil
        }()

        withAnimation(.easeOut(duration: 0.16)) {
            store.removeEntry(withID: entry.id)
            selectedEntryID = nextSelectionID
            isEditingNote = false
        }
    }
}

// MARK: - 1. Top Navigation Toolbar

private struct LexiconTopToolbar: View {
    let showsCustomTrafficLights: Bool
    let onNavigateToLibrary: () -> Void
    let onNavigateToReader: () -> Void
    let onImportBook: () -> Void

    @State private var isHoveringLibrary = false
    @State private var isHoveringReader = false
    @State private var isHoveringMarginalia = false
    @State private var isHoveringImport = false
    @State private var isHoveringGear = false

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 0) {
                // Traffic Lights
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
                    .padding(.trailing, 18)
                } else {
                    Spacer()
                        .frame(width: 72)
                }

                // Vertical Divider
                Rectangle()
                    .fill(SandpaperTheme.toolbarDivider)
                    .frame(width: 1, height: 18)
                    .padding(.trailing, 14)

                // Brand Identity
                Button(action: onNavigateToLibrary) {
                    HStack(spacing: 8) {
                        Image(systemName: "book")
                            .font(.system(size: 13.5, weight: .semibold))
                            .foregroundStyle(SandpaperTheme.terracottaAccent)

                        Text("Sandpaper")
                            .font(.system(size: 16.5, weight: .bold, design: .serif))
                            .foregroundStyle(SandpaperTheme.primaryInk)
                    }
                }
                .buttonStyle(.plain)

                // Top Section Navigation Pills: Library | Reader | Vocabulary | Marginalia
                HStack(spacing: 4) {
                    Button(action: onNavigateToLibrary) {
                        Text("Library")
                            .font(.system(size: 12.5, weight: .medium))
                            .foregroundStyle(SandpaperTheme.secondaryInk)
                            .padding(.horizontal, 12)
                            .frame(height: 27)
                            .background(
                                RoundedRectangle(cornerRadius: 5, style: .continuous)
                                    .fill(isHoveringLibrary ? SandpaperTheme.subtleStroke.opacity(0.2) : .clear)
                            )
                    }
                    .buttonStyle(.plain)
                    .onHover { isHoveringLibrary = $0 }

                    Button(action: onNavigateToReader) {
                        Text("Reader")
                            .font(.system(size: 12.5, weight: .medium))
                            .foregroundStyle(SandpaperTheme.secondaryInk)
                            .padding(.horizontal, 12)
                            .frame(height: 27)
                            .background(
                                RoundedRectangle(cornerRadius: 5, style: .continuous)
                                    .fill(isHoveringReader ? SandpaperTheme.subtleStroke.opacity(0.2) : .clear)
                            )
                    }
                    .buttonStyle(.plain)
                    .onHover { isHoveringReader = $0 }

                    // Active Tab: Vocabulary
                    Text("Vocabulary")
                        .font(.system(size: 12.5, weight: .semibold))
                        .foregroundStyle(SandpaperTheme.terracottaAccent)
                        .padding(.horizontal, 12)
                        .frame(height: 27)
                        .background(
                            RoundedRectangle(cornerRadius: 5, style: .continuous)
                                .fill(Color(hex: 0xEFE1D8))
                        )

                    Button(action: {}) {
                        Text("Marginalia")
                            .font(.system(size: 12.5, weight: .medium))
                            .foregroundStyle(SandpaperTheme.secondaryInk)
                            .padding(.horizontal, 12)
                            .frame(height: 27)
                            .background(
                                RoundedRectangle(cornerRadius: 5, style: .continuous)
                                    .fill(isHoveringMarginalia ? SandpaperTheme.subtleStroke.opacity(0.2) : .clear)
                            )
                    }
                    .buttonStyle(.plain)
                    .onHover { isHoveringMarginalia = $0 }
                }
                .padding(3)
                .background(
                    RoundedRectangle(cornerRadius: 7, style: .continuous)
                        .fill(Color(hex: 0xF5EFE7))
                        .overlay(
                            RoundedRectangle(cornerRadius: 7, style: .continuous)
                                .strokeBorder(Color(hex: 0xEAE1D7), lineWidth: 1)
                        )
                )
                .padding(.leading, 22)

                Spacer()

                // Right Cluster: Outlined Import Book Button + Settings Gear + User Avatar
                HStack(spacing: 14) {
                    Button(action: onImportBook) {
                        HStack(spacing: 7) {
                            Image(systemName: "square.and.arrow.up")
                                .font(.system(size: 11.5, weight: .medium))
                                .foregroundStyle(SandpaperTheme.strongInk)

                            Text("Import Book")
                                .font(.system(size: 12.5, weight: .medium))
                                .foregroundStyle(SandpaperTheme.strongInk)
                        }
                        .padding(.horizontal, 13)
                        .frame(height: 31)
                        .background(
                            RoundedRectangle(cornerRadius: 6, style: .continuous)
                                .fill(isHoveringImport ? SandpaperTheme.pillBackground : Color(hex: 0xFAF6F0))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 6, style: .continuous)
                                .strokeBorder(Color(hex: 0xDFD5CA), lineWidth: 1)
                        )
                    }
                    .buttonStyle(.plain)
                    .onHover { isHoveringImport = $0 }

                    Button(action: {}) {
                        Image(systemName: "gearshape")
                            .font(.system(size: 13.5, weight: .medium))
                            .foregroundStyle(SandpaperTheme.secondaryInk)
                            .frame(width: 28, height: 28)
                            .background(
                                RoundedRectangle(cornerRadius: 5, style: .continuous)
                                    .fill(isHoveringGear ? SandpaperTheme.subtleStroke.opacity(0.22) : .clear)
                            )
                    }
                    .buttonStyle(.plain)
                    .onHover { isHoveringGear = $0 }

                    Button(action: {}) {
                        ZStack {
                            Circle()
                                .fill(SandpaperTheme.pillBackground)
                                .frame(width: 31, height: 31)
                                .overlay(
                                    Circle()
                                        .strokeBorder(SandpaperTheme.subtleStroke, lineWidth: 1)
                                )

                            Image(systemName: "person")
                                .font(.system(size: 12.5, weight: .medium))
                                .foregroundStyle(SandpaperTheme.secondaryInk)
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 24)
            .frame(height: 54)
            .background(SandpaperTheme.chromeBackground)

            Rectangle()
                .fill(SandpaperTheme.toolbarDivider)
                .frame(height: 1)
        }
    }
}

// MARK: - 2. Header Band (Title, Search, Split/Catalog Toggle, Sort & Filter Pills)

private struct LexiconHeaderSectionView: View {
    let totalSavedCount: Int
    let bookCount: Int
    @Binding var searchText: String
    @Binding var selectedCategory: LexiconCategoryFilter
    @Binding var viewMode: LexiconViewMode
    @Binding var sortOrder: LexiconSortOrder

    @State private var isHoveringSort = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: 18) {
                // Upper Row: Title & Subtitle on Left + Search, View Mode & Sort on Right
                HStack(alignment: .bottom, spacing: 20) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Personal Lexicon")
                            .font(.system(size: 35, weight: .regular, design: .serif))
                            .foregroundStyle(SandpaperTheme.primaryInk)

                        Text("\(totalSavedCount) saved expressions across \(bookCount) books")
                            .font(.system(size: 13.5, weight: .regular))
                            .foregroundStyle(SandpaperTheme.mutedInk)
                    }

                    Spacer()

                    // Search Field + Split/Catalog Segmented Control + Sort Dropdown
                    HStack(spacing: 12) {
                        // Search Vocabulary Field
                        HStack(spacing: 8) {
                            Image(systemName: "magnifyingglass")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundStyle(SandpaperTheme.mutedInk)

                            TextField("Search vocabulary", text: $searchText)
                                .textFieldStyle(.plain)
                                .font(.system(size: 12.5, weight: .regular))
                                .foregroundStyle(SandpaperTheme.primaryInk)

                            if !searchText.isEmpty {
                                Button {
                                    searchText = ""
                                } label: {
                                    Image(systemName: "xmark.circle.fill")
                                        .font(.system(size: 11.5))
                                        .foregroundStyle(SandpaperTheme.mutedInk)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.horizontal, 12)
                        .frame(width: 265, height: 32)
                        .background(
                            RoundedRectangle(cornerRadius: 6, style: .continuous)
                                .fill(Color(hex: 0xF5EFE7))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 6, style: .continuous)
                                .strokeBorder(Color(hex: 0xE5DDD2), lineWidth: 1)
                        )
                        .padding(.trailing, 32)

                        // Split View | Catalog Switcher
                        HStack(spacing: 2) {
                            ForEach(LexiconViewMode.allCases) { mode in
                                let isSelected = viewMode == mode
                                Button {
                                    withAnimation(.easeOut(duration: 0.14)) {
                                        viewMode = mode
                                    }
                                } label: {
                                    HStack(spacing: 6) {
                                        Image(
                                            systemName: mode == .splitView
                                                ? "rectangle.split.2x1"
                                                : "square.grid.2x2"
                                        )
                                        .font(.system(size: 11, weight: .medium))
                                        .foregroundStyle(
                                            isSelected ? SandpaperTheme.terracottaAccent : SandpaperTheme.secondaryInk
                                        )

                                        Text(mode.rawValue)
                                            .font(.system(size: 12, weight: isSelected ? .semibold : .medium))
                                            .foregroundStyle(
                                                isSelected ? SandpaperTheme.primaryInk : SandpaperTheme.secondaryInk
                                            )
                                    }
                                    .padding(.horizontal, 11)
                                    .frame(height: 27)
                                    .background(
                                        RoundedRectangle(cornerRadius: 5, style: .continuous)
                                            .fill(isSelected ? SandpaperTheme.canvasBackground : .clear)
                                            .shadow(
                                                color: isSelected ? Color.black.opacity(0.04) : .clear,
                                                radius: 1.5,
                                                x: 0,
                                                y: 1
                                            )
                                    )
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(2.5)
                        .background(
                            RoundedRectangle(cornerRadius: 6, style: .continuous)
                                .fill(Color(hex: 0xF3ECE3))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 6, style: .continuous)
                                .strokeBorder(Color(hex: 0xE5DDD2), lineWidth: 1)
                        )

                        // Sort Dropdown ("Recently Encountered")
                        Menu {
                            ForEach(LexiconSortOrder.allCases) { order in
                                Button {
                                    sortOrder = order
                                } label: {
                                    if sortOrder == order {
                                        Label(order.rawValue, systemImage: "checkmark")
                                    } else {
                                        Text(order.rawValue)
                                    }
                                }
                            }
                        } label: {
                            HStack(spacing: 8) {
                                Image(systemName: "line.3.horizontal.decrease")
                                    .font(.system(size: 11, weight: .medium))
                                    .foregroundStyle(SandpaperTheme.secondaryInk)

                                Text(sortOrder.rawValue)
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundStyle(SandpaperTheme.strongInk)

                                Image(systemName: "chevron.down")
                                    .font(.system(size: 9, weight: .semibold))
                                    .foregroundStyle(SandpaperTheme.secondaryInk)
                            }
                            .padding(.horizontal, 12)
                            .frame(height: 32)
                            .background(
                                RoundedRectangle(cornerRadius: 6, style: .continuous)
                                    .fill(isHoveringSort ? SandpaperTheme.pillBackground : Color(hex: 0xFAF6F0))
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 6, style: .continuous)
                                    .strokeBorder(Color(hex: 0xE4DBD0), lineWidth: 1)
                            )
                        }
                        .menuStyle(.borderlessButton)
                        .menuIndicator(.hidden)
                        .fixedSize()
                        .onHover { isHoveringSort = $0 }
                    }
                }

                // Lower Row: Filter Category Pills
                HStack(spacing: 8) {
                    ForEach(LexiconCategoryFilter.allCases) { category in
                        LexiconFilterPill(
                            category: category,
                            badgeCount: category == .allExpressions ? totalSavedCount : nil,
                            isSelected: selectedCategory == category
                        ) {
                            selectedCategory = category
                        }
                    }
                }
            }
            .padding(.horizontal, 38)
            .padding(.top, 24)
            .padding(.bottom, 16)
            .background(Color(hex: 0xFAF6EF))

            Rectangle()
                .fill(SandpaperTheme.statusBarBorder)
                .frame(height: 1)
        }
    }
}

private struct LexiconFilterPill: View {
    let category: LexiconCategoryFilter
    let badgeCount: Int?
    let isSelected: Bool
    let action: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 7) {
                Text(category.rawValue)
                    .font(.system(size: 12.5, weight: isSelected ? .semibold : .medium))
                    .foregroundStyle(isSelected ? .white : SandpaperTheme.secondaryInk)

                if let badgeCount {
                    Text("\(badgeCount)")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(isSelected ? .white : SandpaperTheme.secondaryInk)
                        .padding(.horizontal, 6.5)
                        .padding(.vertical, 1.5)
                        .background(
                            Capsule(style: .continuous)
                                .fill(
                                    isSelected
                                        ? Color.white.opacity(0.22)
                                        : SandpaperTheme.subtleStroke.opacity(0.35)
                                )
                        )
                }
            }
            .padding(.horizontal, 14)
            .frame(height: 30)
            .background(
                Capsule(style: .continuous)
                    .fill(
                        isSelected
                            ? SandpaperTheme.popoverPrimaryButton
                            : (isHovered ? SandpaperTheme.pillBackground : Color(hex: 0xFAF6F0))
                    )
            )
            .overlay(
                Capsule(style: .continuous)
                    .strokeBorder(
                        isSelected ? .clear : Color(hex: 0xE5DDD2),
                        lineWidth: 1
                    )
            )
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
    }
}

// MARK: - 3. Left Sidebar ("ENCOUNTERED LEXEMES")

private struct LexiconSidebarListView: View {
    let entries: [LexiconEntry]
    let totalSavedCount: Int
    let selectedEntryID: String?
    let onSelectEntry: (LexiconEntry) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Sidebar Kicker Bar
            HStack {
                Text("ENCOUNTERED LEXEMES")
                    .font(.system(size: 10.5, weight: .semibold))
                    .tracking(0.75)
                    .foregroundStyle(SandpaperTheme.mutedInk)

                Spacer()

                Text("\(entries.count) of \(totalSavedCount)")
                    .font(.system(size: 11.5, weight: .regular))
                    .foregroundStyle(SandpaperTheme.mutedInk)
                    .monospacedDigit()
            }
            .padding(.horizontal, 22)
            .frame(height: 42)
            .background(Color(hex: 0xFAF6EF))

            Rectangle()
                .fill(SandpaperTheme.statusBarBorder)
                .frame(height: 1)

            // Scrollable Lexeme Rows
            ScrollView(.vertical) {
                LazyVStack(spacing: 0) {
                    ForEach(entries) { entry in
                        LexiconSidebarRowView(
                            entry: entry,
                            isSelected: entry.id == selectedEntryID,
                            onSelect: { onSelectEntry(entry) }
                        )
                    }
                }
            }
            .background(Color(hex: 0xFAF6EF))
        }
        .frame(width: 324)
        .overlay(alignment: .trailing) {
            Rectangle()
                .fill(SandpaperTheme.statusBarBorder)
                .frame(width: 1)
        }
    }
}

private struct LexiconSidebarRowView: View {
    let entry: LexiconEntry
    let isSelected: Bool
    let onSelect: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(action: onSelect) {
            VStack(alignment: .leading, spacing: 0) {
                VStack(alignment: .leading, spacing: 8) {
                    // Row Header: Expression + POS + Relative Timestamp
                    HStack(alignment: .firstTextBaseline, spacing: 6) {
                        Text(entry.expression)
                            .font(.system(size: 16.5, weight: .medium, design: .serif))
                            .foregroundStyle(SandpaperTheme.primaryInk)
                            .lineLimit(1)

                        Text(entry.shortPartOfSpeech)
                            .font(.system(size: 12.5, weight: .regular, design: .serif))
                            .italic()
                            .foregroundStyle(
                                isSelected ? SandpaperTheme.terracottaAccent : SandpaperTheme.mutedInk
                            )

                        Spacer()

                        Text(entry.encounteredRelative)
                            .font(.system(size: 11.5, weight: .regular))
                            .foregroundStyle(SandpaperTheme.mutedInk)
                    }

                    // Short Definition
                    Text(entry.shortDefinition)
                        .font(.system(size: 13.5, weight: .regular, design: .serif))
                        .lineSpacing(3.5)
                        .foregroundStyle(SandpaperTheme.strongInk)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)

                    // Source Book & Author
                    Text("\(entry.bookTitle) · \(entry.author)")
                        .font(.system(size: 11.5, weight: .regular))
                        .foregroundStyle(SandpaperTheme.mutedInk)
                        .lineLimit(1)
                        .padding(.top, 2)
                }
                .padding(.horizontal, 22)
                .padding(.vertical, 17)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    isSelected
                        ? Color(hex: 0xF5EFE6)
                        : (isHovered ? Color(hex: 0xF7F2EA) : Color(hex: 0xFCF9F3))
                )
                .overlay(alignment: .leading) {
                    if isSelected {
                        Rectangle()
                            .fill(SandpaperTheme.terracottaAccent)
                            .frame(width: 3.5)
                    }
                }

                Rectangle()
                    .fill(SandpaperTheme.statusBarBorder)
                    .frame(height: 1)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
    }
}

// MARK: - 4. Right Detail Pane (Selected Lexeme Inspector)

private struct LexiconDetailPaneView: View {
    let entry: LexiconEntry
    @Binding var isEditingNote: Bool
    @Binding var draftNoteText: String
    let didCopyCitation: Bool
    let didExportCommonplace: Bool
    let isShowingCrossReferenceToast: Bool
    let onPronounce: () -> Void
    let onShowInReader: () -> Void
    let onBeginEditNote: () -> Void
    let onSaveEditedNote: () -> Void
    let onTriggerCrossReference: () -> Void
    let onCopyCitation: () -> Void
    let onExportCommonplace: () -> Void
    let onRemoveWord: () -> Void

    @State private var isHoveringSpeaker = false
    @State private var isSpeaking = false
    @State private var isHoveringShowInReader = false
    @State private var isHoveringEditNote = false
    @State private var isHoveringCrossRef = false
    @State private var isHoveringCopyCitation = false
    @State private var isHoveringExport = false
    @State private var isHoveringRemove = false

    var body: some View {
        ScrollView(.vertical) {
            VStack(alignment: .leading, spacing: 0) {
                // 1. Headword & Speaker Button
                HStack(alignment: .center, spacing: 14) {
                    Text(entry.expression)
                        .font(.system(size: 40, weight: .regular, design: .serif))
                        .foregroundStyle(SandpaperTheme.primaryInk)

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
                    .padding(.top, 4)
                }

                // 2. Phonetic Transcription
                Text(entry.phonetic)
                    .font(.system(size: 13.5, weight: .regular))
                    .foregroundStyle(SandpaperTheme.mutedInk)
                    .padding(.top, 10)

                // 3. Grammatical & Register Tag Pills
                HStack(spacing: 8) {
                    ForEach(entry.grammaticalTags, id: \.self) { tag in
                        Text(tag)
                            .font(.system(size: 11.5, weight: .medium))
                            .foregroundStyle(SandpaperTheme.secondaryInk)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 4)
                            .background(
                                RoundedRectangle(cornerRadius: 4, style: .continuous)
                                    .fill(Color(hex: 0xF5EFE7))
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 4, style: .continuous)
                                    .strokeBorder(Color(hex: 0xE8DFD5), lineWidth: 1)
                            )
                    }
                }
                .padding(.top, 10)

                // 4. Primary Definition & Etymology
                Text(entry.fullDefinition)
                    .font(.system(size: 17.5, weight: .regular, design: .serif))
                    .lineSpacing(5)
                    .foregroundStyle(SandpaperTheme.primaryInk)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 18)

                if let etymology = entry.etymology, !etymology.isEmpty {
                    Text(etymology)
                        .font(.system(size: 13.5, weight: .regular, design: .serif))
                        .foregroundStyle(SandpaperTheme.mutedInk)
                        .padding(.top, 10)
                }

                // 5. EXCERPTED SOURCE PASSAGE Section
                VStack(alignment: .leading, spacing: 10) {
                    HStack(alignment: .firstTextBaseline) {
                        Text("EXCERPTED SOURCE PASSAGE")
                            .font(.system(size: 10.5, weight: .semibold))
                            .tracking(0.75)
                            .foregroundStyle(SandpaperTheme.mutedInk)

                        Spacer()

                        Text(entry.chapterLabel)
                            .font(.system(size: 12, weight: .regular))
                            .foregroundStyle(SandpaperTheme.mutedInk)
                    }

                    VStack(alignment: .leading, spacing: 20) {
                        HStack(alignment: .top, spacing: 16) {
                            Rectangle()
                                .fill(SandpaperTheme.terracottaAccent.opacity(0.65))
                                .frame(width: 2)

                            Text(highlightedPassageString(for: entry))
                                .font(.system(size: 17.5, weight: .regular, design: .serif))
                                .italic()
                                .lineSpacing(8)
                                .fixedSize(horizontal: false, vertical: true)
                        }

                        HStack(alignment: .center) {
                            HStack(spacing: 7) {
                                Image(systemName: "book")
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundStyle(SandpaperTheme.secondaryInk)

                                Text("\(entry.bookTitle) · \(entry.author)")
                                    .font(.system(size: 12.5, weight: .regular))
                                    .foregroundStyle(SandpaperTheme.secondaryInk)
                            }

                            Spacer()

                            Button(action: onShowInReader) {
                                HStack(spacing: 7) {
                                    Text("Show in Reader")
                                        .font(.system(size: 12.5, weight: .medium))
                                        .foregroundStyle(.white)

                                    Image(systemName: "arrow.right")
                                        .font(.system(size: 11, weight: .semibold))
                                        .foregroundStyle(.white)
                                }
                                .padding(.horizontal, 15)
                                .frame(height: 31)
                                .background(
                                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                                        .fill(
                                            isHoveringShowInReader
                                                ? SandpaperTheme.popoverPrimaryButtonHover
                                                : SandpaperTheme.popoverPrimaryButton
                                        )
                                )
                            }
                            .buttonStyle(.plain)
                            .onHover { isHoveringShowInReader = $0 }
                        }
                    }
                    .padding(22)
                    .background(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .fill(SandpaperTheme.cardBackground)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .strokeBorder(SandpaperTheme.cardBorder, lineWidth: 1)
                    )
                }
                .padding(.top, 36)

                // 6. Reader's Marginal Note Card
                VStack(alignment: .leading, spacing: 16) {
                    HStack(alignment: .center) {
                        HStack(spacing: 8) {
                            Image(systemName: "pencil")
                                .font(.system(size: 13.5, weight: .medium))
                                .foregroundStyle(SandpaperTheme.secondaryInk)

                            Text("Reader's Marginal Note")
                                .font(.system(size: 16.5, weight: .medium, design: .serif))
                                .foregroundStyle(SandpaperTheme.primaryInk)
                        }

                        Spacer()

                        HStack(spacing: 8) {
                            if isEditingNote {
                                Button("Cancel") {
                                    isEditingNote = false
                                }
                                .buttonStyle(.plain)
                                .font(.system(size: 12, weight: .medium))
                                .foregroundStyle(SandpaperTheme.mutedInk)
                                .padding(.horizontal, 10)
                                .frame(height: 28)

                                Button(action: onSaveEditedNote) {
                                    Text("Save Note")
                                        .font(.system(size: 12, weight: .semibold))
                                        .foregroundStyle(.white)
                                        .padding(.horizontal, 12)
                                        .frame(height: 28)
                                        .background(
                                            RoundedRectangle(cornerRadius: 5, style: .continuous)
                                                .fill(SandpaperTheme.popoverPrimaryButton)
                                        )
                                }
                                .buttonStyle(.plain)
                            } else {
                                Button(action: onBeginEditNote) {
                                    HStack(spacing: 6) {
                                        Image(systemName: "pencil")
                                            .font(.system(size: 11, weight: .medium))
                                        Text("Edit Note")
                                            .font(.system(size: 12, weight: .medium))
                                    }
                                    .foregroundStyle(SandpaperTheme.secondaryInk)
                                    .padding(.horizontal, 11)
                                    .frame(height: 28)
                                    .background(
                                        RoundedRectangle(cornerRadius: 5, style: .continuous)
                                            .fill(
                                                isHoveringEditNote
                                                    ? SandpaperTheme.pillBackground
                                                    : SandpaperTheme.canvasBackground
                                            )
                                    )
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 5, style: .continuous)
                                            .strokeBorder(Color(hex: 0xE5DDD2), lineWidth: 1)
                                    )
                                }
                                .buttonStyle(.plain)
                                .onHover { isHoveringEditNote = $0 }

                                Button(action: onTriggerCrossReference) {
                                    HStack(spacing: 6) {
                                        Image(systemName: "link")
                                            .font(.system(size: 11, weight: .medium))
                                        Text(isShowingCrossReferenceToast ? "Linked Folio" : "Cross-Reference")
                                            .font(.system(size: 12, weight: .medium))
                                    }
                                    .foregroundStyle(SandpaperTheme.secondaryInk)
                                    .padding(.horizontal, 11)
                                    .frame(height: 28)
                                    .background(
                                        RoundedRectangle(cornerRadius: 5, style: .continuous)
                                            .fill(
                                                isHoveringCrossRef
                                                    ? SandpaperTheme.pillBackground
                                                    : SandpaperTheme.canvasBackground
                                            )
                                    )
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 5, style: .continuous)
                                            .strokeBorder(Color(hex: 0xE5DDD2), lineWidth: 1)
                                    )
                                }
                                .buttonStyle(.plain)
                                .onHover { isHoveringCrossRef = $0 }
                            }
                        }
                    }

                    if isEditingNote {
                        TextEditor(text: $draftNoteText)
                            .font(.system(size: 14, weight: .regular, design: .serif))
                            .foregroundStyle(SandpaperTheme.primaryInk)
                            .scrollContentBackground(.hidden)
                            .padding(10)
                            .frame(minHeight: 84)
                            .background(
                                RoundedRectangle(cornerRadius: 6, style: .continuous)
                                    .fill(SandpaperTheme.canvasBackground)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                                            .strokeBorder(SandpaperTheme.subtleStroke, lineWidth: 1)
                                    )
                            )
                    } else {
                        HStack(alignment: .top, spacing: 14) {
                            Rectangle()
                                .fill(SandpaperTheme.subtleStroke)
                                .frame(width: 2)

                            Text("\"\(entry.marginalNote)\"")
                                .font(.system(size: 14.5, weight: .regular, design: .serif))
                                .italic()
                                .lineSpacing(6)
                                .foregroundStyle(SandpaperTheme.secondaryInk)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }
                .padding(22)
                .background(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(SandpaperTheme.cardBackground)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .strokeBorder(SandpaperTheme.cardBorder, lineWidth: 1)
                )
                .padding(.top, 26)

                // 7. PARALLEL SENSES ACROSS OTHER FOLIOS Section
                if !entry.parallelSenses.isEmpty {
                    VStack(alignment: .leading, spacing: 10) {
                        HStack(alignment: .firstTextBaseline) {
                            Text("PARALLEL SENSES ACROSS OTHER FOLIOS")
                                .font(.system(size: 10.5, weight: .semibold))
                                .tracking(0.75)
                                .foregroundStyle(SandpaperTheme.mutedInk)

                            Spacer()

                            Text(
                                entry.parallelSenses.count == 1
                                    ? "1 other instance"
                                    : "\(entry.parallelSenses.count) other instances"
                            )
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(SandpaperTheme.terracottaAccent)
                        }

                        ForEach(entry.parallelSenses) { sense in
                            VStack(alignment: .leading, spacing: 12) {
                                HStack(alignment: .firstTextBaseline) {
                                    Text(sense.workAndAuthor)
                                        .font(.system(size: 13, weight: .semibold))
                                        .foregroundStyle(SandpaperTheme.primaryInk)

                                    Spacer()

                                    Text(sense.sectionLabel)
                                        .font(.system(size: 12, weight: .regular))
                                        .foregroundStyle(SandpaperTheme.mutedInk)
                                }

                                Text(sense.quote)
                                    .font(.system(size: 15.5, weight: .regular, design: .serif))
                                    .italic()
                                    .lineSpacing(5.5)
                                    .foregroundStyle(SandpaperTheme.primaryInk)
                                    .fixedSize(horizontal: false, vertical: true)

                                Text(sense.commentary)
                                    .font(.system(size: 13, weight: .regular, design: .serif))
                                    .lineSpacing(4)
                                    .foregroundStyle(SandpaperTheme.secondaryInk)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                            .padding(22)
                            .background(
                                RoundedRectangle(cornerRadius: 8, style: .continuous)
                                    .fill(SandpaperTheme.cardBackground)
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 8, style: .continuous)
                                    .strokeBorder(SandpaperTheme.cardBorder, lineWidth: 1)
                            )
                        }
                    }
                    .padding(.top, 28)
                }

                // 8. Bottom Action Row: Copy Citation, Export to Commonplace, Remove word
                HStack(spacing: 12) {
                    Button(action: onCopyCitation) {
                        HStack(spacing: 7) {
                            Image(systemName: didCopyCitation ? "checkmark" : "doc.on.doc")
                                .font(.system(size: 11.5, weight: .medium))
                            Text(didCopyCitation ? "Copied Citation" : "Copy Citation")
                                .font(.system(size: 12.5, weight: .medium))
                        }
                        .foregroundStyle(SandpaperTheme.strongInk)
                        .padding(.horizontal, 14)
                        .frame(height: 32)
                        .background(
                            RoundedRectangle(cornerRadius: 6, style: .continuous)
                                .fill(
                                    isHoveringCopyCitation
                                        ? SandpaperTheme.pillBackground
                                        : Color(hex: 0xFAF6F0)
                                )
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 6, style: .continuous)
                                .strokeBorder(Color(hex: 0xE2D8CE), lineWidth: 1)
                        )
                    }
                    .buttonStyle(.plain)
                    .onHover { isHoveringCopyCitation = $0 }

                    Button(action: onExportCommonplace) {
                        HStack(spacing: 7) {
                            Image(
                                systemName: didExportCommonplace
                                    ? "checkmark"
                                    : "square.and.arrow.up"
                            )
                            .font(.system(size: 11.5, weight: .medium))

                            Text(
                                didExportCommonplace
                                    ? "Exported to Pasteboard"
                                    : "Export to Commonplace"
                            )
                            .font(.system(size: 12.5, weight: .medium))
                        }
                        .foregroundStyle(SandpaperTheme.strongInk)
                        .padding(.horizontal, 14)
                        .frame(height: 32)
                        .background(
                            RoundedRectangle(cornerRadius: 6, style: .continuous)
                                .fill(
                                    isHoveringExport
                                        ? SandpaperTheme.pillBackground
                                        : Color(hex: 0xFAF6F0)
                                )
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 6, style: .continuous)
                                .strokeBorder(Color(hex: 0xE2D8CE), lineWidth: 1)
                        )
                    }
                    .buttonStyle(.plain)
                    .onHover { isHoveringExport = $0 }

                    Spacer()

                    Button(action: onRemoveWord) {
                        HStack(spacing: 7) {
                            Image(systemName: "trash")
                                .font(.system(size: 11.5, weight: .medium))
                            Text("Remove word")
                                .font(.system(size: 12.5, weight: .medium))
                        }
                        .foregroundStyle(
                            isHoveringRemove
                                ? SandpaperTheme.highlightInk
                                : SandpaperTheme.secondaryInk
                        )
                        .padding(.horizontal, 14)
                        .frame(height: 32)
                        .background(
                            RoundedRectangle(cornerRadius: 6, style: .continuous)
                                .fill(
                                    isHoveringRemove
                                        ? SandpaperTheme.selectionPillFill
                                        : Color(hex: 0xFAF6F0)
                                )
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 6, style: .continuous)
                                .strokeBorder(Color(hex: 0xE2D8CE), lineWidth: 1)
                        )
                    }
                    .buttonStyle(.plain)
                    .onHover { isHoveringRemove = $0 }
                }
                .padding(.top, 26)
            }
            .frame(maxWidth: 740, alignment: .leading)
            .padding(.horizontal, 56)
            .padding(.top, 38)
            .padding(.bottom, 56)
            .frame(maxWidth: .infinity)
        }
        .background(SandpaperTheme.canvasBackground)
    }

    private func highlightedPassageString(for entry: LexiconEntry) -> AttributedString {
        let quoted = "\"\(entry.sourcePassage)\""
        var attributed = AttributedString(quoted)
        attributed.foregroundColor = SandpaperTheme.primaryInk

        if let range = quoted.range(of: entry.expression, options: [.caseInsensitive]),
           let attrStart = AttributedString.Index(range.lowerBound, within: attributed),
           let attrEnd = AttributedString.Index(range.upperBound, within: attributed) {
            attributed[attrStart..<attrEnd].foregroundColor = SandpaperTheme.terracottaAccent
        }

        return attributed
    }
}

// MARK: - 5. Catalog Grid Mode & Empty State

private struct LexiconCatalogGridView: View {
    let entries: [LexiconEntry]
    let selectedEntryID: String?
    let onSelectEntry: (LexiconEntry) -> Void
    let onShowInReader: (LexiconEntry) -> Void

    var body: some View {
        ScrollView(.vertical) {
            LazyVGrid(
                columns: [
                    GridItem(.adaptive(minimum: 320, maximum: 440), spacing: 20, alignment: .top)
                ],
                spacing: 20
            ) {
                ForEach(entries) { entry in
                    VStack(alignment: .leading, spacing: 12) {
                        HStack(alignment: .firstTextBaseline) {
                            Text(entry.expression)
                                .font(.system(size: 20, weight: .medium, design: .serif))
                                .foregroundStyle(SandpaperTheme.primaryInk)

                            Text(entry.shortPartOfSpeech)
                                .font(.system(size: 13, weight: .regular, design: .serif))
                                .italic()
                                .foregroundStyle(SandpaperTheme.terracottaAccent)

                            Spacer()

                            Text(entry.encounteredRelative)
                                .font(.system(size: 11.5, weight: .regular))
                                .foregroundStyle(SandpaperTheme.mutedInk)
                        }

                        Text(entry.fullDefinition)
                            .font(.system(size: 14, weight: .regular, design: .serif))
                            .lineSpacing(4)
                            .foregroundStyle(SandpaperTheme.strongInk)
                            .lineLimit(3)

                        Text("\"\(entry.sourcePassage)\"")
                            .font(.system(size: 13, weight: .regular, design: .serif))
                            .italic()
                            .foregroundStyle(SandpaperTheme.mutedInk)
                            .lineLimit(2)

                        HStack {
                            Text("\(entry.bookTitle) · \(entry.author)")
                                .font(.system(size: 11.5, weight: .medium))
                                .foregroundStyle(SandpaperTheme.secondaryInk)

                            Spacer()

                            Button("Inspect") {
                                onSelectEntry(entry)
                            }
                            .buttonStyle(.plain)
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(SandpaperTheme.terracottaAccent)

                            Text("·")
                                .foregroundStyle(SandpaperTheme.subtleStroke)

                            Button("Reader →") {
                                onShowInReader(entry)
                            }
                            .buttonStyle(.plain)
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(SandpaperTheme.secondaryInk)
                        }
                        .padding(.top, 4)
                    }
                    .padding(20)
                    .background(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .fill(SandpaperTheme.cardBackground)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .strokeBorder(
                                entry.id == selectedEntryID
                                    ? SandpaperTheme.terracottaAccent
                                    : SandpaperTheme.cardBorder,
                                lineWidth: 1
                            )
                    )
                }
            }
            .padding(36)
        }
        .background(SandpaperTheme.canvasBackground)
    }
}

private struct LexiconEmptyStateView: View {
    let searchText: String
    let selectedCategory: LexiconCategoryFilter
    let onReset: () -> Void

    var body: some View {
        VStack(spacing: 14) {
            Text("Aᵃ")
                .font(.system(size: 32, weight: .regular, design: .serif))
                .foregroundStyle(SandpaperTheme.terracottaAccent)

            Text(
                searchText.isEmpty
                    ? "No expressions in \(selectedCategory.rawValue)"
                    : "No saved expressions matching “\(searchText)”"
            )
            .font(.system(size: 20, weight: .regular, design: .serif))
            .foregroundStyle(SandpaperTheme.primaryInk)

            Text("Select words or phrases in the Reader and choose “Save to Vocabulary” to build your personal lexicon.")
                .font(.system(size: 13.5, weight: .regular, design: .serif))
                .foregroundStyle(SandpaperTheme.mutedInk)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 420)

            if !searchText.isEmpty || selectedCategory != .allExpressions {
                Button(action: onReset) {
                    Text("Show All Expressions")
                        .font(.system(size: 12.5, weight: .medium))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 14)
                        .frame(height: 31)
                        .background(
                            RoundedRectangle(cornerRadius: 6, style: .continuous)
                                .fill(SandpaperTheme.popoverPrimaryButton)
                        )
                }
                .buttonStyle(.plain)
                .padding(.top, 4)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(SandpaperTheme.canvasBackground)
    }
}

// MARK: - Preview

#Preview("Sandpaper — Personal Lexicon") {
    SandpaperPersonalLexiconView(
        store: SandpaperVocabularyStore()
    )
    .frame(width: 1360, height: 1140)
}
