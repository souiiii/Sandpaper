import SwiftUI
import AppKit
import UniformTypeIdentifiers

// MARK: - Library Models & Mock Data

enum LibraryFilterCategory: String, CaseIterable, Identifiable, Sendable {
    case allTitles = "All Titles"
    case currentlyReading = "Currently Reading"
    case finished = "Finished"
    case literature = "Literature"
    case essays = "Essays"
    case nonfiction = "Nonfiction"

    var id: String { rawValue }
}

enum LibraryViewMode: String, CaseIterable, Identifiable, Sendable {
    case covers = "Covers"
    case shelf = "Shelf"
    case list = "List"

    var id: String { rawValue }
}

enum LibraryGridSubMode: String, Sendable {
    case grid
    case compactList
}

enum LibrarySortOrder: String, CaseIterable, Identifiable, Sendable {
    case recentlyRead = "Recently Read"
    case titleAZ = "Title (A–Z)"
    case authorAZ = "Author (A–Z)"
    case progress = "Reading Progress"

    var id: String { rawValue }
}

enum BookFormatBadge: String, Sendable {
    case epub = "EPUB"
    case pdf = "PDF"
    case txt = "TXT"
    case md = "MD"
    case web = "WEB"
}

enum BookCoverArtStyle: Sendable, Equatable {
    case remainsOfTheDay
    case slouchingTowardsBethlehem
    case thePeregrine
    case middlemarch
    case aRoomOfOnesOwn
    case mobyDick
    case oldPatagonianExpress
    case notesOfANativeSon
    case onPhotography
}

struct LibraryBook: Identifiable, Sendable, Equatable {
    let id: String
    let title: String
    let author: String
    let genreTag: String
    let filterGroup: LibraryFilterCategory
    let format: BookFormatBadge
    let coverStyle: BookCoverArtStyle
    let isOnReadingDesk: Bool
    let isCurrentlyReading: Bool
    let isFinished: Bool
    let lastReadRelative: String
    let lastOpenedSortRank: Int
    let currentSectionLabel: String
    let progressLabelLeft: String
    let progressFraction: Double
    let totalPages: Int
    let gridMetadataLine: String
    let sampleChapter: BookChapter

    static func == (lhs: LibraryBook, rhs: LibraryBook) -> Bool {
        lhs.id == rhs.id
    }
}

struct LibraryVocabularyPreviewItem: Identifiable, Sendable {
    let id: String
    let word: String
    let partOfSpeech: String
    let bookTitle: String
    let definition: String
}

struct LibraryMarginaliaPreviewItem: Identifiable, Sendable {
    let id: String
    let quote: String
    let citation: String
    let annotationType: String
}

// MARK: - Mock Library Repository

enum MockLibraryData {
    static let totalCollectionCount: Int = 14

    static let readingDeskBooks: [LibraryBook] = [
        LibraryBook(
            id: "remains-of-the-day",
            title: "The Remains of the Day",
            author: "Kazuo Ishiguro",
            genreTag: "Historical Novel",
            filterGroup: .literature,
            format: .epub,
            coverStyle: .remainsOfTheDay,
            isOnReadingDesk: true,
            isCurrentlyReading: true,
            isFinished: false,
            lastReadRelative: "2h ago",
            lastOpenedSortRank: 1,
            currentSectionLabel: "Day Three, Evening: Chapter 5",
            progressLabelLeft: "Ch. 5",
            progressFraction: 0.64,
            totalPages: 258,
            gridMetadataLine: "Chapter 5 · 64%",
            sampleChapter: .remainsOfTheDaySample
        ),
        LibraryBook(
            id: "slouching-towards-bethlehem",
            title: "Slouching Towards Bethlehem",
            author: "Joan Didion",
            genreTag: "Essays",
            filterGroup: .essays,
            format: .epub,
            coverStyle: .slouchingTowardsBethlehem,
            isOnReadingDesk: true,
            isCurrentlyReading: true,
            isFinished: false,
            lastReadRelative: "Yesterday",
            lastOpenedSortRank: 2,
            currentSectionLabel: "Goodbye to All That",
            progressLabelLeft: "Part II",
            progressFraction: 0.38,
            totalPages: 238,
            gridMetadataLine: "Part II · 38%",
            sampleChapter: BookChapter.mockChapter(
                id: "didion-part-2",
                bookTitle: "Slouching Towards Bethlehem",
                author: "Joan Didion",
                partLabel: "PART TWO · PERSONALS",
                chapterLabel: "Goodbye to All That",
                locationTitle: "New York, 1967",
                subtitle: "Notes on Leaving Manhattan",
                currentPage: 91,
                totalPages: 238,
                progress: 0.38,
                dropCap: "I",
                remainder: "t is easy to see the beginnings of things, and harder to see the ends. I can remember now, with a clarity that makes the nerves in the back of my neck constrict, when New York began for me, but I cannot lay my finger upon the moment it ended, can never cut through the ambiguities and second starts and broken resolves to the exact place on the page where the heroine is no longer as optimistic as she once was."
            )
        ),
        LibraryBook(
            id: "the-peregrine",
            title: "The Peregrine",
            author: "J.A. Baker",
            genreTag: "Natural History",
            filterGroup: .nonfiction,
            format: .epub,
            coverStyle: .thePeregrine,
            isOnReadingDesk: true,
            isCurrentlyReading: true,
            isFinished: false,
            lastReadRelative: "3d ago",
            lastOpenedSortRank: 3,
            currentSectionLabel: "Spring: 14 March",
            progressLabelLeft: "Spring",
            progressFraction: 0.12,
            totalPages: 191,
            gridMetadataLine: "Spring · 12%",
            sampleChapter: BookChapter.mockChapter(
                id: "peregrine-spring",
                bookTitle: "The Peregrine",
                author: "J.A. Baker",
                partLabel: "DIARY OF A WINTER",
                chapterLabel: "Spring: 14 March",
                locationTitle: "The Essex Coast",
                subtitle: "Pursuit Across the Estuaries",
                currentPage: 24,
                totalPages: 191,
                progress: 0.12,
                dropCap: "E",
                remainder: "ast of my home, the long ridge of high groundudinates into a shallow valley that winds down to the tidal creeks. In the clear frosty light of early March, the ploughed earth gleams like dark pewter, and high above the saltings the tiercel hangs anchored against the north-east wind."
            )
        )
    ]

    static let catalogBooks: [LibraryBook] = [
        LibraryBook(
            id: "middlemarch",
            title: "Middlemarch",
            author: "George Eliot",
            genreTag: "Literature",
            filterGroup: .literature,
            format: .epub,
            coverStyle: .middlemarch,
            isOnReadingDesk: false,
            isCurrentlyReading: false,
            isFinished: false,
            lastReadRelative: "1w ago",
            lastOpenedSortRank: 4,
            currentSectionLabel: "Book I: Miss Brooke",
            progressLabelLeft: "Book I",
            progressFraction: 0.0,
            totalPages: 848,
            gridMetadataLine: "848 pp",
            sampleChapter: BookChapter.mockChapter(
                id: "middlemarch-ch1",
                bookTitle: "Middlemarch",
                author: "George Eliot",
                partLabel: "BOOK ONE",
                chapterLabel: "Chapter I — Miss Brooke",
                locationTitle: "Tipton Grange",
                subtitle: "A Study of Provincial Life",
                currentPage: 12,
                totalPages: 848,
                progress: 0.02,
                dropCap: "M",
                remainder: "iss Brooke had that kind of beauty which seems to be thrown into relief by poor dress. Her hand and wrist were so finely formed that she could wear sleeves not less bare of style than those in which the Blessed Virgin appeared to Italian painters; and her profile as well as her stature and bearing seemed to gain the more dignity from her plain garments."
            )
        ),
        LibraryBook(
            id: "a-room-of-ones-own",
            title: "A Room of One’s Own",
            author: "Virginia Woolf",
            genreTag: "Essays",
            filterGroup: .essays,
            format: .pdf,
            coverStyle: .aRoomOfOnesOwn,
            isOnReadingDesk: false,
            isCurrentlyReading: false,
            isFinished: true,
            lastReadRelative: "2w ago",
            lastOpenedSortRank: 5,
            currentSectionLabel: "Chapter Six",
            progressLabelLeft: "Finished",
            progressFraction: 1.0,
            totalPages: 112,
            gridMetadataLine: "Finished · 112 pp",
            sampleChapter: BookChapter.mockChapter(
                id: "woolf-ch1",
                bookTitle: "A Room of One’s Own",
                author: "Virginia Woolf",
                partLabel: "CHAPTER ONE",
                chapterLabel: "Oxbridge, October",
                locationTitle: "By the Riverbank",
                subtitle: "Women and Fiction",
                currentPage: 112,
                totalPages: 112,
                progress: 1.0,
                dropCap: "B",
                remainder: "ut, you may say, we asked you to speak about women and fiction—what has that got to do with a room of one’s own? I will try to explain. When you asked me to speak about women and fiction I sat down on the banks of a river and began to wonder what the words meant."
            )
        ),
        LibraryBook(
            id: "moby-dick",
            title: "Moby-Dick",
            author: "Herman Melville",
            genreTag: "Literature",
            filterGroup: .literature,
            format: .epub,
            coverStyle: .mobyDick,
            isOnReadingDesk: false,
            isCurrentlyReading: false,
            isFinished: false,
            lastReadRelative: "5d ago",
            lastOpenedSortRank: 6,
            currentSectionLabel: "Chapter 14: Nantucket",
            progressLabelLeft: "Chapter 14",
            progressFraction: 0.15,
            totalPages: 635,
            gridMetadataLine: "Chapter 14 · 15%",
            sampleChapter: BookChapter.mockChapter(
                id: "moby-dick-ch14",
                bookTitle: "Moby-Dick",
                author: "Herman Melville",
                partLabel: "CHAPTER XIV",
                chapterLabel: "Nantucket",
                locationTitle: "Nantucket Island",
                subtitle: "The Whaleman’s Haven",
                currentPage: 95,
                totalPages: 635,
                progress: 0.15,
                dropCap: "N",
                remainder: "antucket! Take out your map and look at it. See what a real corner of the world it occupies; how it stands there, away off shore, more lonely than the Eddystone lighthouse. Look at it—a mere hillock, and elbow of sand; all beach, without a background."
            )
        ),
        LibraryBook(
            id: "old-patagonian-express",
            title: "The Old Patagonian Express",
            author: "Paul Theroux",
            genreTag: "Nonfiction",
            filterGroup: .nonfiction,
            format: .epub,
            coverStyle: .oldPatagonianExpress,
            isOnReadingDesk: false,
            isCurrentlyReading: false,
            isFinished: false,
            lastReadRelative: "3w ago",
            lastOpenedSortRank: 7,
            currentSectionLabel: "Chapter 1: Boston",
            progressLabelLeft: "Ch. 1",
            progressFraction: 0.0,
            totalPages: 432,
            gridMetadataLine: "432 pp",
            sampleChapter: BookChapter.mockChapter(
                id: "patagonian-ch1",
                bookTitle: "The Old Patagonian Express",
                author: "Paul Theroux",
                partLabel: "PART ONE",
                chapterLabel: "Departure from South Station",
                locationTitle: "Boston to Patagonia",
                subtitle: "By Train Through the Americas",
                currentPage: 1,
                totalPages: 432,
                progress: 0.02,
                dropCap: "A",
                remainder: "t first I thought of going to the station and buying a ticket to the end of the line, wherever that might be. On a train, distance is measured in time and landscape rather than miles, and the winter snow along the platforms of Massachusetts already promised a long southward passage."
            )
        ),
        LibraryBook(
            id: "notes-of-a-native-son",
            title: "Notes of a Native Son",
            author: "James Baldwin",
            genreTag: "Essays",
            filterGroup: .essays,
            format: .epub,
            coverStyle: .notesOfANativeSon,
            isOnReadingDesk: false,
            isCurrentlyReading: false,
            isFinished: true,
            lastReadRelative: "1m ago",
            lastOpenedSortRank: 8,
            currentSectionLabel: "Autobiographical Notes",
            progressLabelLeft: "Finished",
            progressFraction: 1.0,
            totalPages: 176,
            gridMetadataLine: "Finished · 176 pp",
            sampleChapter: BookChapter.mockChapter(
                id: "baldwin-notes",
                bookTitle: "Notes of a Native Son",
                author: "James Baldwin",
                partLabel: "PART TWO",
                chapterLabel: "Notes of a Native Son",
                locationTitle: "Harlem, July 1943",
                subtitle: "Inheritance and Memory",
                currentPage: 176,
                totalPages: 176,
                progress: 1.0,
                dropCap: "O",
                remainder: "n the 29th of July, in 1943, my father died. On the same day, a few hours later, his last child was born. Over a month before this, while all our energies were concentrated in waiting for these events, there had been, in Detroit, one of the bloodiest race riots of the century."
            )
        ),
        LibraryBook(
            id: "on-photography",
            title: "On Photography",
            author: "Susan Sontag",
            genreTag: "Essays",
            filterGroup: .nonfiction,
            format: .pdf,
            coverStyle: .onPhotography,
            isOnReadingDesk: false,
            isCurrentlyReading: false,
            isFinished: false,
            lastReadRelative: "4d ago",
            lastOpenedSortRank: 9,
            currentSectionLabel: "Essay IV",
            progressLabelLeft: "Essay IV",
            progressFraction: 0.52,
            totalPages: 207,
            gridMetadataLine: "Essay IV · 52%",
            sampleChapter: BookChapter.mockChapter(
                id: "sontag-essay-4",
                bookTitle: "On Photography",
                author: "Susan Sontag",
                partLabel: "ESSAY FOUR",
                chapterLabel: "The Heroism of Vision",
                locationTitle: "In Plato’s Cave",
                subtitle: "Reflections on the Photographic Image",
                currentPage: 108,
                totalPages: 207,
                progress: 0.52,
                dropCap: "H",
                remainder: "umankind lingers unregenerately in Plato’s cave, still reveling, its age-old habit, in mere images of the truth. But being educated by photographs is not like being educated by older, more artisanal images. For one thing, there are a great many more images around, claiming our attention."
            )
        )
    ]

    static var allUniqueBooks: [LibraryBook] {
        readingDeskBooks + catalogBooks
    }

    static let vocabularyPreviewItems: [LibraryVocabularyPreviewItem] = [
        LibraryVocabularyPreviewItem(
            id: "vocab-ineluctable",
            word: "ineluctable",
            partOfSpeech: "adj.",
            bookTitle: "The Remains of the Day",
            definition: "Unable to be resisted or avoided; inescapable in its natural course."
        ),
        LibraryVocabularyPreviewItem(
            id: "vocab-punctilious",
            word: "punctilious",
            partOfSpeech: "adj.",
            bookTitle: "The Peregrine",
            definition: "Showing marked attention to minute details and rigorous propriety."
        )
    ]

    static let recentMarginalia: LibraryMarginaliaPreviewItem = LibraryMarginaliaPreviewItem(
        id: "marginalia-1",
        quote: "“What is the point of worrying oneself so much about what one could or could not have done to control the course one’s life took?”",
        citation: "The Remains of the Day · p. 244",
        annotationType: "Pencil annotation"
    )
}

extension BookChapter {
    static func mockChapter(
        id: String,
        bookTitle: String,
        author: String,
        partLabel: String,
        chapterLabel: String,
        locationTitle: String,
        subtitle: String,
        currentPage: Int,
        totalPages: Int,
        progress: Double,
        dropCap: String,
        remainder: String
    ) -> BookChapter {
        BookChapter(
            id: id,
            bookTitle: bookTitle,
            author: author,
            partLabel: partLabel,
            chapterLabel: chapterLabel,
            locationTitle: locationTitle,
            subtitle: subtitle,
            currentPage: currentPage,
            totalPages: totalPages,
            progress: progress,
            syncStatus: "Saved",
            blocks: [
                .dropCapParagraph(id: "p1", dropCap: dropCap, remainderText: remainder),
                .paragraph(
                    id: "p2",
                    segments: [
                        .plain("The afternoon light moved quietly across the page, inviting the kind of unhurried reflection and close attention to language for which this edition was prepared. Every margin and cadence of prose remains poised for careful reading.")
                    ]
                )
            ],
            previousChapter: ChapterNavigationItem(title: "Previous Section"),
            nextChapter: ChapterNavigationItem(title: "Next Section"),
            availableChapters: [chapterLabel]
        )
    }
}

// MARK: - Root Navigation Container (Library <-> Reader <-> Personal Lexicon)

enum SandpaperActiveScreen: Equatable {
    case library
    case reader(LibraryBook)
    case vocabulary(initialEntryID: String? = nil)
}

struct SandpaperRootView: View {
    @State private var activeScreen: SandpaperActiveScreen = .library
    @State private var lastOpenedBook: LibraryBook = MockLibraryData.readingDeskBooks[0]
    @State private var vocabularyStore = SandpaperVocabularyStore()

    var body: some View {
        ZStack {
            switch activeScreen {
            case .library:
                SandpaperLibraryView(
                    onOpenBook: { book in
                        lastOpenedBook = book
                        withAnimation(.easeInOut(duration: 0.18)) {
                            activeScreen = .reader(book)
                        }
                    },
                    vocabularyStore: vocabularyStore,
                    onOpenVocabulary: { initialID in
                        withAnimation(.easeInOut(duration: 0.18)) {
                            activeScreen = .vocabulary(initialEntryID: initialID)
                        }
                    }
                )
                .transition(.opacity)

            case .reader(let book):
                SandpaperReaderView(
                    chapter: book.sampleChapter,
                    bookID: book.id,
                    vocabularyStore: vocabularyStore,
                    onBackToLibrary: {
                        withAnimation(.easeInOut(duration: 0.18)) {
                            activeScreen = .library
                        }
                    }
                )
                .transition(.opacity)

            case .vocabulary(let initialEntryID):
                SandpaperPersonalLexiconView(
                    store: vocabularyStore,
                    initialSelectedEntryID: initialEntryID,
                    onNavigateToLibrary: {
                        withAnimation(.easeInOut(duration: 0.18)) {
                            activeScreen = .library
                        }
                    },
                    onNavigateToReader: { targetBook in
                        let destinationBook = targetBook ?? lastOpenedBook
                        lastOpenedBook = destinationBook
                        withAnimation(.easeInOut(duration: 0.18)) {
                            activeScreen = .reader(destinationBook)
                        }
                    }
                )
                .transition(.opacity)
            }
        }
    }
}
// MARK: - Library Screen View

struct SandpaperLibraryView: View {
    var onOpenBook: (@MainActor (LibraryBook) -> Void)?
    var onImportFiles: (@MainActor ([URL]) -> Void)?
    var onImportWebArticleURL: (@MainActor (URL) -> Void)?
    
    var vocabularyStore: SandpaperVocabularyStore? = nil
    var onOpenVocabulary: (@MainActor (String?) -> Void)? = nil

    @State private var searchText: String = ""
    @State private var selectedCategory: LibraryFilterCategory = .allTitles
    @State private var selectedViewMode: LibraryViewMode = .covers
    @State private var gridSubMode: LibraryGridSubMode = .grid
    @State private var sortOrder: LibrarySortOrder = .recentlyRead
    @State private var hostsNativeTrafficLights: Bool = false

    // Import Sheet & File Importer States
    @State private var isShowingFileImporter: Bool = false
    @State private var isShowingWebURLSheet: Bool = false
    @State private var webArticleURLString: String = ""
    @State private var importFeedbackBanner: String? = nil

    private var filteredDeskBooks: [LibraryBook] {
        filterAndSort(MockLibraryData.readingDeskBooks)
    }

    private var filteredCatalogBooks: [LibraryBook] {
        let base: [LibraryBook]
        switch selectedCategory {
        case .allTitles:
            base = MockLibraryData.catalogBooks
        case .currentlyReading:
            base = MockLibraryData.readingDeskBooks
        case .finished:
            base = MockLibraryData.allUniqueBooks.filter { $0.isFinished }
        case .literature, .essays, .nonfiction:
            base = MockLibraryData.allUniqueBooks.filter { $0.filterGroup == selectedCategory }
        }
        return filterAndSort(base)
    }

    private var showsReadingDeskSection: Bool {
        if !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return !filteredDeskBooks.isEmpty
        }
        return selectedCategory == .allTitles || selectedCategory == .currentlyReading
    }

    var body: some View {
        VStack(spacing: 0) {
            // 1. Primary Top Toolbar
            LibraryPrimaryToolbar(
                searchText: $searchText,
                selectedViewMode: $selectedViewMode,
                sortOrder: $sortOrder,
                showsCustomTrafficLights: !hostsNativeTrafficLights,
                onSelectImportLocalFiles: {
                    isShowingFileImporter = true
                },
                onSelectImportWebURL: {
                    webArticleURLString = ""
                    isShowingWebURLSheet = true
                }
            )

            // 2. Secondary Filter & Quick-Links Bar
            LibrarySecondaryFilterBar(
                selectedCategory: $selectedCategory,
                onOpenVocabulary: {
                    onOpenVocabulary?(nil)
                }
            )

            // 3. Main Scrollable Library Content
            ScrollView(.vertical) {
                VStack(alignment: .leading, spacing: 0) {
                    // Optional non-intrusive feedback banner when an import callback is triggered
                    if let banner = importFeedbackBanner {
                        HStack(spacing: 10) {
                            Image(systemName: "Tray.and.arrow.down")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundStyle(SandpaperTheme.terracottaAccent)
                            Text(banner)
                                .font(.system(size: 12.5, weight: .medium))
                                .foregroundStyle(SandpaperTheme.secondaryInk)
                            Spacer()
                            Button {
                                withAnimation(.easeOut(duration: 0.15)) {
                                    importFeedbackBanner = nil
                                }
                            } label: {
                                Image(systemName: "xmark")
                                    .font(.system(size: 10, weight: .semibold))
                                    .foregroundStyle(SandpaperTheme.mutedInk)
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 9)
                        .background(
                            RoundedRectangle(cornerRadius: 7, style: .continuous)
                                .fill(SandpaperTheme.cardBackground)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 7, style: .continuous)
                                        .strokeBorder(SandpaperTheme.subtleStroke, lineWidth: 1)
                                )
                        )
                        .padding(.top, 20)
                    }

                    // Page Header ("Personal Library")
                    LibraryHeroHeaderView(
                        totalVolumes: MockLibraryData.totalCollectionCount,
                        deskCount: MockLibraryData.readingDeskBooks.count
                    )
                    .padding(.top, 30)

                    // Empty Search / Filter State if nothing matches
                    if filteredDeskBooks.isEmpty && filteredCatalogBooks.isEmpty {
                        LibraryEmptyStateView(
                            searchText: searchText,
                            selectedCategory: selectedCategory,
                            onResetFilters: {
                                searchText = ""
                                selectedCategory = .allTitles
                            },
                            onImportBook: {
                                isShowingFileImporter = true
                            }
                        )
                        .padding(.top, 48)
                        .padding(.bottom, 64)
                    } else {
                        // Section A: "On your reading desk"
                        if showsReadingDeskSection && !filteredDeskBooks.isEmpty {
                            ReadingDeskSectionView(
                                books: filteredDeskBooks,
                                onResumeBook: { book in
                                    onOpenBook?(book)
                                }
                            )
                            .padding(.top, 26)
                        }

                        // Section B: "All books" Catalog
                        if !filteredCatalogBooks.isEmpty {
                            AllBooksCatalogSectionView(
                                sectionTitle: selectedCategory == .allTitles ? "All books" : selectedCategory.rawValue,
                                books: filteredCatalogBooks,
                                displayedVolumeCount: selectedCategory == .allTitles && searchText.isEmpty
                                    ? 8
                                    : filteredCatalogBooks.count,
                                topViewMode: selectedViewMode,
                                gridSubMode: $gridSubMode,
                                onSelectBook: { book in
                                    onOpenBook?(book)
                                }
                            )
                            .padding(.top, 40)
                        }

                        // Section C: Bottom Split Preview (Vocabulary & Recent Marginalia)
                        LibraryBottomPreviewsSectionView(
                            vocabularyItems: vocabularyStore?.libraryPreviewItems
                                ?? MockLibraryData.vocabularyPreviewItems,
                            marginaliaItem: MockLibraryData.recentMarginalia,
                            onSelectBookTitle: { bookTitle in
                                if let match = MockLibraryData.allUniqueBooks.first(
                                    where: { $0.title == bookTitle }
                                ) {
                                    onOpenBook?(match)
                                }
                            },
                            onOpenVocabulary: onOpenVocabulary
                        )
                        .padding(.top, 38)
                        .padding(.bottom, 48)
                    }
                }
                .padding(.horizontal, 36)
                .frame(maxWidth: 1460)
                .frame(maxWidth: .infinity)
            }
            .background(SandpaperTheme.canvasBackground)
        }
        .background(SandpaperTheme.canvasBackground)
        .background(
            ReaderWindowConfigurator(hostsNativeTrafficLights: $hostsNativeTrafficLights)
        )
        .ignoresSafeArea(.container, edges: .top)
        .fileImporter(
            isPresented: $isShowingFileImporter,
            allowedContentTypes: [
                .epub,
                .pdf,
                .plainText,
                UTType(filenameExtension: "md") ?? .plainText
            ],
            allowsMultipleSelection: true
        ) { result in
            if case .success(let urls) = result, !urls.isEmpty {
                onImportFiles?(urls)
                let names = urls.map(\.lastPathComponent).joined(separator: ", ")
                withAnimation(.easeOut(duration: 0.18)) {
                    importFeedbackBanner = "Passed \(names) to Sandpaper import pipeline."
                }
            }
        }
        .sheet(isPresented: $isShowingWebURLSheet) {
            ImportWebArticleSheet(
                urlString: $webArticleURLString,
                onCancel: {
                    isShowingWebURLSheet = false
                },
                onSubmit: { url in
                    isShowingWebURLSheet = false
                    onImportWebArticleURL?(url)
                    withAnimation(.easeOut(duration: 0.18)) {
                        importFeedbackBanner = "Passed \(url.absoluteString) to Sandpaper article importer."
                    }
                }
            )
        }
    }

    private func filterAndSort(_ books: [LibraryBook]) -> [LibraryBook] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let matching = books.filter { book in
            guard !query.isEmpty else { return true }
            return book.title.lowercased().contains(query)
                || book.author.lowercased().contains(query)
                || book.genreTag.lowercased().contains(query)
                || book.currentSectionLabel.lowercased().contains(query)
        }

        return matching.sorted { a, b in
            switch sortOrder {
            case .recentlyRead:
                return a.lastOpenedSortRank < b.lastOpenedSortRank
            case .titleAZ:
                return a.title.localizedCaseInsensitiveCompare(b.title) == .orderedAscending
            case .authorAZ:
                return a.author.localizedCaseInsensitiveCompare(b.author) == .orderedAscending
            case .progress:
                return a.progressFraction > b.progressFraction
            }
        }
    }
}

// MARK: - 1. Primary Top Toolbar

private struct LibraryPrimaryToolbar: View {
    @Binding var searchText: String
    @Binding var selectedViewMode: LibraryViewMode
    @Binding var sortOrder: LibrarySortOrder
    let showsCustomTrafficLights: Bool
    let onSelectImportLocalFiles: () -> Void
    let onSelectImportWebURL: () -> Void

    @State private var isHoveringImport = false
    @State private var isHoveringSort = false

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

                // Brand Identity: Open Book Icon + "Sandpaper" + "LIBRARY" Badge
                HStack(spacing: 8) {
                    Image(systemName: "book")
                        .font(.system(size: 13.5, weight: .semibold))
                        .foregroundStyle(SandpaperTheme.terracottaAccent)

                    Text("Sandpaper")
                        .font(.system(size: 16.5, weight: .bold, design: .serif))
                        .foregroundStyle(SandpaperTheme.primaryInk)

                    Text("LIBRARY")
                        .font(.system(size: 9.5, weight: .semibold))
                        .tracking(0.8)
                        .foregroundStyle(SandpaperTheme.mutedInk)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 3)
                        .background(
                            RoundedRectangle(cornerRadius: 4, style: .continuous)
                                .fill(Color(hex: 0xEFE8DF))
                        )
                }

                Spacer(minLength: 28)

                // Search Bar Field
                HStack(spacing: 8) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(SandpaperTheme.mutedInk)

                    TextField("Search library", text: $searchText)
                        .textFieldStyle(.plain)
                        .font(.system(size: 13, weight: .regular))
                        .foregroundStyle(SandpaperTheme.primaryInk)

                    if !searchText.isEmpty {
                        Button {
                            searchText = ""
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 12))
                                .foregroundStyle(SandpaperTheme.mutedInk)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 12)
                .frame(minWidth: 260, idealWidth: 380, maxWidth: 420)
                .frame(height: 32)
                .background(
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(Color(hex: 0xF3ECE3))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .strokeBorder(Color(hex: 0xE6DDD3), lineWidth: 1)
                )

                Spacer(minLength: 24)

                // Right Controls Cluster
                HStack(spacing: 12) {
                    // Segmented View Mode Switcher: Covers | Shelf | List
                    HStack(spacing: 2) {
                        ForEach(LibraryViewMode.allCases) { mode in
                            let isSelected = selectedViewMode == mode
                            Button {
                                withAnimation(.easeOut(duration: 0.14)) {
                                    selectedViewMode = mode
                                }
                            } label: {
                                HStack(spacing: 5.5) {
                                    viewModeIcon(for: mode)
                                        .font(.system(size: 11, weight: .medium))
                                        .foregroundStyle(
                                            isSelected ? SandpaperTheme.primaryInk : SandpaperTheme.secondaryInk
                                        )

                                    Text(mode.rawValue)
                                        .font(.system(size: 12, weight: isSelected ? .semibold : .medium))
                                        .foregroundStyle(
                                            isSelected ? SandpaperTheme.primaryInk : SandpaperTheme.secondaryInk
                                        )
                                }
                                .padding(.horizontal, 10)
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
                        RoundedRectangle(cornerRadius: 7, style: .continuous)
                            .fill(Color(hex: 0xF2EBE2))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 7, style: .continuous)
                            .strokeBorder(Color(hex: 0xE5DBD0), lineWidth: 1)
                    )

                    // Sort Menu ("Recently Read v")
                    Menu {
                        ForEach(LibrarySortOrder.allCases) { order in
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
                            Text(sortOrder.rawValue)
                                .font(.system(size: 12, weight: .medium))
                                .foregroundStyle(SandpaperTheme.strongInk)

                            Image(systemName: "chevron.down")
                                .font(.system(size: 9.5, weight: .semibold))
                                .foregroundStyle(SandpaperTheme.secondaryInk)
                        }
                        .padding(.horizontal, 12)
                        .frame(height: 32)
                        .background(
                            RoundedRectangle(cornerRadius: 6, style: .continuous)
                                .fill(isHoveringSort ? SandpaperTheme.pillBackground : Color(hex: 0xF7F1E9))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 6, style: .continuous)
                                .strokeBorder(Color(hex: 0xE2D7CC), lineWidth: 1)
                        )
                    }
                    .menuStyle(.borderlessButton)
                    .menuIndicator(.hidden)
                    .fixedSize()
                    .onHover { isHoveringSort = $0 }

                    // Primary Terracotta "Import Book" Menu/Button
                    Menu {
                        Button {
                            onSelectImportLocalFiles()
                        } label: {
                            Label("Import Local File (EPUB, PDF, TXT, Markdown)…", systemImage: "doc.badge.plus")
                        }

                        Button {
                            onSelectImportWebURL()
                        } label: {
                            Label("Add Webpage or Article URL…", systemImage: "link.badge.plus")
                        }
                    } label: {
                        HStack(spacing: 7) {
                            Image(systemName: "square.and.arrow.up")
                                .font(.system(size: 11.5, weight: .semibold))
                                .foregroundStyle(.white)

                            Text("Import Book")
                                .font(.system(size: 12.5, weight: .semibold))
                                .foregroundStyle(.white)
                        }
                        .padding(.horizontal, 14)
                        .frame(height: 32)
                        .background(
                            RoundedRectangle(cornerRadius: 6, style: .continuous)
                                .fill(
                                    isHoveringImport
                                        ? SandpaperTheme.popoverPrimaryButtonHover
                                        : SandpaperTheme.popoverPrimaryButton
                                )
                        )
                    } primaryAction: {
                        onSelectImportLocalFiles()
                    }
                    .menuStyle(.borderlessButton)
                    .menuIndicator(.hidden)
                    .fixedSize()
                    .onHover { isHoveringImport = $0 }

                    // User Profile Circle
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
            }
            .padding(.horizontal, 24)
            .frame(height: 54)
            .background(SandpaperTheme.chromeBackground)

            Rectangle()
                .fill(SandpaperTheme.toolbarDivider)
                .frame(height: 1)
        }
    }

    @ViewBuilder
    private func viewModeIcon(for mode: LibraryViewMode) -> some View {
        switch mode {
        case .covers:
            Image(systemName: "square.grid.2x2")
        case .shelf:
            Image(systemName: "books.vertical")
        case .list:
            Image(systemName: "list.bullet")
        }
    }
}

// MARK: - 2. Secondary Filter & Navigation Bar

private struct LibrarySecondaryFilterBar: View {
    @Binding var selectedCategory: LibraryFilterCategory
    var onOpenVocabulary: (() -> Void)? = nil

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 8) {
                // Status Filters
                FilterPillButton(
                    title: "All Titles (14)",
                    systemImage: "book",
                    isSelected: selectedCategory == .allTitles
                ) {
                    selectedCategory = .allTitles
                }

                FilterPillButton(
                    title: "Currently Reading (3)",
                    systemImage: "book.pages",
                    isSelected: selectedCategory == .currentlyReading
                ) {
                    selectedCategory = .currentlyReading
                }

                FilterPillButton(
                    title: "Finished (2)",
                    systemImage: "checkmark",
                    isSelected: selectedCategory == .finished
                ) {
                    selectedCategory = .finished
                }

                // Vertical Divider
                Rectangle()
                    .fill(SandpaperTheme.toolbarDivider)
                    .frame(width: 1, height: 16)
                    .padding(.horizontal, 6)

                // Collection / Genre Filters
                FilterPillButton(
                    title: "Literature",
                    systemImage: "folder",
                    isSelected: selectedCategory == .literature
                ) {
                    selectedCategory = .literature
                }

                FilterPillButton(
                    title: "Essays",
                    systemImage: "doc.text",
                    isSelected: selectedCategory == .essays
                ) {
                    selectedCategory = .essays
                }

                FilterPillButton(
                    title: "Nonfiction",
                    systemImage: "book.closed",
                    isSelected: selectedCategory == .nonfiction
                ) {
                    selectedCategory = .nonfiction
                }

                Spacer()

                // Right Quick Links (Vocabulary & Marginalia & Notes)
                HStack(spacing: 22) {
                    Button(action: { onOpenVocabulary?() }) {
                        HStack(spacing: 6) {
                            Text("Aᵃ")
                                .font(.system(size: 12.5, weight: .bold, design: .serif))
                                .foregroundStyle(SandpaperTheme.terracottaAccent)

                            Text("Vocabulary")
                                .font(.system(size: 12.5, weight: .medium))
                                .foregroundStyle(SandpaperTheme.terracottaAccent)
                        }
                    }
                    .buttonStyle(.plain)

                    Button(action: {}) {
                        HStack(spacing: 6) {
                            Image(systemName: "pencil")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundStyle(SandpaperTheme.secondaryInk)

                            Text("Marginalia & Notes")
                                .font(.system(size: 12.5, weight: .medium))
                                .foregroundStyle(SandpaperTheme.secondaryInk)
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 28)
            .frame(height: 44)
            .background(Color(hex: 0xFBF7F0))

            Rectangle()
                .fill(SandpaperTheme.statusBarBorder)
                .frame(height: 1)
        }
    }
}

private struct FilterPillButton: View {
    let title: String
    let systemImage: String
    let isSelected: Bool
    let action: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6.5) {
                Image(systemName: systemImage)
                    .font(.system(size: 11, weight: isSelected ? .semibold : .medium))
                    .foregroundStyle(isSelected ? .white : SandpaperTheme.secondaryInk)

                Text(title)
                    .font(.system(size: 12.5, weight: isSelected ? .semibold : .medium))
                    .foregroundStyle(isSelected ? .white : SandpaperTheme.secondaryInk)
            }
            .padding(.horizontal, 12)
            .frame(height: 27)
            .background(
                Capsule(style: .continuous)
                    .fill(
                        isSelected
                            ? SandpaperTheme.popoverPrimaryButton
                            : (isHovered ? SandpaperTheme.subtleStroke.opacity(0.22) : .clear)
                    )
            )
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
    }
}

// MARK: - 3. Hero Header ("Personal Library")

private struct LibraryHeroHeaderView: View {
    let totalVolumes: Int
    let deskCount: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Personal Library")
                .font(.system(size: 35, weight: .regular, design: .serif))
                .foregroundStyle(SandpaperTheme.primaryInk)

            HStack(spacing: 8) {
                Text("\(totalVolumes) volumes in your collection")
                    .font(.system(size: 14.5, weight: .regular, design: .serif))
                    .foregroundStyle(SandpaperTheme.mutedInk)

                Circle()
                    .fill(SandpaperTheme.subtleStroke)
                    .frame(width: 4, height: 4)

                Text("\(deskCount) open on your reading desk")
                    .font(.system(size: 14.5, weight: .regular, design: .serif))
                    .foregroundStyle(SandpaperTheme.mutedInk)
            }
        }
    }
}

// MARK: - 4. "On your reading desk" Section

private struct ReadingDeskSectionView: View {
    let books: [LibraryBook]
    let onResumeBook: (LibraryBook) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            // Section Header Row
            HStack(alignment: .center) {
                Text("On your reading desk")
                    .font(.system(size: 20, weight: .medium, design: .serif))
                    .foregroundStyle(SandpaperTheme.primaryInk)

                Spacer()

                HStack(spacing: 14) {
                    Button(action: {}) {
                        Image(systemName: "arrow.left")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(SandpaperTheme.secondaryInk)
                    }
                    .buttonStyle(.plain)

                    Button(action: {}) {
                        Image(systemName: "arrow.right")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(SandpaperTheme.secondaryInk)
                    }
                    .buttonStyle(.plain)
                }
            }

            Rectangle()
                .fill(SandpaperTheme.statusBarBorder)
                .frame(height: 1)

            // 3-Column Reading Desk Cards
            LazyVGrid(
                columns: [
                    GridItem(.flexible(minimum: 290), spacing: 22),
                    GridItem(.flexible(minimum: 290), spacing: 22),
                    GridItem(.flexible(minimum: 290), spacing: 22)
                ],
                spacing: 22
            ) {
                ForEach(books) { book in
                    ReadingDeskCardView(
                        book: book,
                        onResume: { onResumeBook(book) }
                    )
                }
            }
            .padding(.top, 4)
        }
    }
}

private struct ReadingDeskCardView: View {
    let book: LibraryBook
    let onResume: () -> Void

    @State private var isHoveredCard = false
    @State private var isHoveredResume = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Top Row: Book Cover Thumbnail + Metadata
            HStack(alignment: .top, spacing: 18) {
                Button(action: onResume) {
                    BookCoverArtworkView(style: book.coverStyle, formatBadge: nil)
                        .frame(width: 98, height: 144)
                        .shadow(color: Color.black.opacity(0.14), radius: 5, x: 0, y: 3)
                }
                .buttonStyle(.plain)

                VStack(alignment: .leading, spacing: 0) {
                    // Genre & Last Read Timestamp
                    HStack(alignment: .firstTextBaseline) {
                        Text(book.genreTag)
                            .font(.system(size: 11.5, weight: .regular))
                            .foregroundStyle(SandpaperTheme.mutedInk)

                        Spacer()

                        Text(book.lastReadRelative)
                            .font(.system(size: 11.5, weight: .regular))
                            .foregroundStyle(SandpaperTheme.mutedInk)
                    }

                    // Book Title
                    Button(action: onResume) {
                        Text(book.title)
                            .font(.system(size: 19, weight: .medium, design: .serif))
                            .foregroundStyle(SandpaperTheme.primaryInk)
                            .lineLimit(2)
                            .multilineTextAlignment(.leading)
                    }
                    .buttonStyle(.plain)
                    .padding(.top, 6)

                    // Author (Italic Serif)
                    Text(book.author)
                        .font(.system(size: 14, weight: .regular, design: .serif))
                        .italic()
                        .foregroundStyle(SandpaperTheme.mutedInk)
                        .padding(.top, 5)

                    // Current Bookmark / Chapter Position
                    HStack(spacing: 7) {
                        Image(systemName: "bookmark")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(SandpaperTheme.terracottaAccent)

                        Text(book.currentSectionLabel)
                            .font(.system(size: 12.5, weight: .regular))
                            .foregroundStyle(SandpaperTheme.secondaryInk)
                            .lineLimit(1)
                    }
                    .padding(.top, 16)
                }
            }

            // Progress Section
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text(book.progressLabelLeft)
                        .font(.system(size: 11.5, weight: .medium))
                        .foregroundStyle(SandpaperTheme.secondaryInk)

                    Spacer()

                    Text("\(Int(round(book.progressFraction * 100)))% completed")
                        .font(.system(size: 11.5, weight: .medium))
                        .foregroundStyle(SandpaperTheme.secondaryInk)
                        .monospacedDigit()
                }

                GeometryReader { proxy in
                    ZStack(alignment: .leading) {
                        Capsule(style: .continuous)
                            .fill(Color(hex: 0xEAE1D7))

                        Capsule(style: .continuous)
                            .fill(SandpaperTheme.progressFill)
                            .frame(width: max(6, proxy.size.width * book.progressFraction))
                    }
                }
                .frame(height: 3.5)
            }
            .padding(.top, 22)

            // Bottom Action Row: "Resume Reading" Button + Annotation & More Icons
            HStack(spacing: 14) {
                Button(action: onResume) {
                    HStack(spacing: 8) {
                        Image(systemName: "book")
                            .font(.system(size: 11.5, weight: .medium))
                            .foregroundStyle(.white)

                        Text("Resume Reading")
                            .font(.system(size: 12.5, weight: .medium))
                            .foregroundStyle(.white)
                    }
                    .padding(.horizontal, 16)
                    .frame(height: 32)
                    .background(
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .fill(
                                isHoveredResume
                                    ? SandpaperTheme.popoverPrimaryButtonHover
                                    : SandpaperTheme.popoverPrimaryButton
                            )
                    )
                }
                .buttonStyle(.plain)
                .onHover { isHoveredResume = $0 }

                Spacer()

                Button(action: onResume) {
                    Image(systemName: "pencil")
                        .font(.system(size: 12.5, weight: .medium))
                        .foregroundStyle(SandpaperTheme.secondaryInk)
                }
                .buttonStyle(.plain)
                .help("View Notes & Marginalia")

                Menu {
                    Button("Open in Reader", action: onResume)
                    Button("Bookmark Current Position", action: {})
                } label: {
                    Image(systemName: "ellipsis")
                        .font(.system(size: 12.5, weight: .medium))
                        .foregroundStyle(SandpaperTheme.secondaryInk)
                        .frame(width: 22, height: 22)
                }
                .menuStyle(.borderlessButton)
                .menuIndicator(.hidden)
                .fixedSize()
            }
            .padding(.top, 16)
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color(hex: 0xFBF7F0))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .strokeBorder(
                    isHoveredCard ? SandpaperTheme.subtleStroke : Color(hex: 0xECE4DA),
                    lineWidth: 1
                )
        )
        .onHover { isHoveredCard = $0 }
    }
}

// MARK: - 5. "All books" Catalog Section

private struct AllBooksCatalogSectionView: View {
    let sectionTitle: String
    let books: [LibraryBook]
    let displayedVolumeCount: Int
    let topViewMode: LibraryViewMode
    @Binding var gridSubMode: LibraryGridSubMode
    let onSelectBook: (LibraryBook) -> Void

    private var effectiveShowsList: Bool {
        topViewMode == .list || gridSubMode == .compactList
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            // Header Row
            HStack(alignment: .center, spacing: 12) {
                Text(sectionTitle)
                    .font(.system(size: 21, weight: .medium, design: .serif))
                    .foregroundStyle(SandpaperTheme.primaryInk)

                Spacer()

                Text("\(displayedVolumeCount) volumes")
                    .font(.system(size: 12.5, weight: .regular))
                    .foregroundStyle(SandpaperTheme.mutedInk)

                Rectangle()
                    .fill(SandpaperTheme.toolbarDivider)
                    .frame(width: 1, height: 15)

                // Sub-mode Grid / List Icon Toggle
                HStack(spacing: 1) {
                    Button {
                        gridSubMode = .grid
                    } label: {
                        Image(systemName: "square.grid.2x2")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(
                                gridSubMode == .grid ? SandpaperTheme.primaryInk : SandpaperTheme.mutedInk
                            )
                            .frame(width: 25, height: 23)
                            .background(
                                RoundedRectangle(cornerRadius: 4, style: .continuous)
                                    .fill(gridSubMode == .grid ? SandpaperTheme.canvasBackground : .clear)
                            )
                    }
                    .buttonStyle(.plain)

                    Button {
                        gridSubMode = .compactList
                    } label: {
                        Image(systemName: "list.bullet")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(
                                gridSubMode == .compactList ? SandpaperTheme.primaryInk : SandpaperTheme.mutedInk
                            )
                            .frame(width: 25, height: 23)
                            .background(
                                RoundedRectangle(cornerRadius: 4, style: .continuous)
                                    .fill(gridSubMode == .compactList ? SandpaperTheme.canvasBackground : .clear)
                            )
                    }
                    .buttonStyle(.plain)
                }
                .padding(2)
                .background(
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(Color(hex: 0xF2EBE2))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .strokeBorder(Color(hex: 0xE4DBD0), lineWidth: 1)
                )
            }

            Rectangle()
                .fill(SandpaperTheme.statusBarBorder)
                .frame(height: 1)

            if effectiveShowsList {
                // Clean Editorial List Mode
                VStack(spacing: 10) {
                    ForEach(books) { book in
                        CatalogBookListRowView(book: book) {
                            onSelectBook(book)
                        }
                    }
                }
                .padding(.top, 6)
            } else {
                // 6-Column Responsive Book Covers Grid (Matches Reference Screenshot)
                LazyVGrid(
                    columns: [
                        GridItem(.Adaptive(minimum: 185, maximum: 240), spacing: 24, alignment: .top)
                    ],
                    spacing: 28
                ) {
                    ForEach(books) { book in
                        CatalogBookGridItemView(
                            book: book,
                            showsShelfPlank: topViewMode == .shelf,
                            onSelect: { onSelectBook(book) }
                        )
                    }
                }
                .padding(.top, 8)
            }
        }
    }
}

private extension GridItem.Size {
    static func Adaptive(minimum: CGFloat, maximum: CGFloat) -> GridItem.Size {
        .adaptive(minimum: minimum, maximum: maximum)
    }
}

private struct CatalogBookGridItemView: View {
    let book: LibraryBook
    let showsShelfPlank: Bool
    let onSelect: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(action: onSelect) {
            VStack(alignment: .leading, spacing: 0) {
                // Cover Container
                VStack(spacing: 0) {
                    BookCoverArtworkView(
                        style: book.coverStyle,
                        formatBadge: book.format
                    )
                    .aspectRatio(0.68, contentMode: .fit)
                    .scaleEffect(isHovered ? 1.012 : 1.0)
                    .animation(.easeOut(duration: 0.15), value: isHovered)

                    if showsShelfPlank {
                        Rectangle()
                            .fill(Color(hex: 0xDFD3C5))
                            .frame(height: 5)
                            .shadow(color: Color.black.opacity(0.08), radius: 2, x: 0, y: 2)
                    }
                }

                // Book Title (2-line fixed height alignment matching reference)
                Text(book.title)
                    .font(.system(size: 16.5, weight: .medium, design: .serif))
                    .foregroundStyle(SandpaperTheme.primaryInk)
                    .lineSpacing(2)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                    .frame(height: 44, alignment: .topLeading)
                    .padding(.top, 12)

                // Author Name
                Text(book.author)
                    .font(.system(size: 13, weight: .regular, design: .serif))
                    .foregroundStyle(SandpaperTheme.secondaryInk)
                    .lineLimit(1)
                    .padding(.top, 4)

                // Status / Page Count Line
                HStack(spacing: 5) {
                    if book.isFinished {
                        Image(systemName: "checkmark")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(SandpaperTheme.mutedInk)
                    }

                    Text(book.gridMetadataLine)
                        .font(.system(size: 12, weight: .regular))
                        .foregroundStyle(SandpaperTheme.mutedInk)
                        .monospacedDigit()
                }
                .padding(.top, 5)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
    }
}

private struct CatalogBookListRowView: View {
    let book: LibraryBook
    let onSelect: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: 16) {
                BookCoverArtworkView(style: book.coverStyle, formatBadge: nil)
                    .frame(width: 44, height: 64)

                VStack(alignment: .leading, spacing: 4) {
                    Text(book.title)
                        .font(.system(size: 16, weight: .medium, design: .serif))
                        .foregroundStyle(SandpaperTheme.primaryInk)

                    Text(book.author)
                        .font(.system(size: 13, weight: .regular, design: .serif))
                        .italic()
                        .foregroundStyle(SandpaperTheme.mutedInk)
                }

                Spacer()

                Text(book.genreTag)
                    .font(.system(size: 12, weight: .regular))
                    .foregroundStyle(SandpaperTheme.mutedInk)

                Text(book.gridMetadataLine)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(SandpaperTheme.secondaryInk)
                    .monospacedDigit()
                    .frame(width: 120, alignment: .trailing)

                Text(book.format.rawValue)
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(SandpaperTheme.secondaryInk)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 3)
                    .background(
                        RoundedRectangle(cornerRadius: 4, style: .continuous)
                            .fill(SandpaperTheme.pillBackground)
                    )
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(isHovered ? SandpaperTheme.pillBackground : SandpaperTheme.cardBackground)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .strokeBorder(SandpaperTheme.cardBorder, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
    }
}

// MARK: - 6. Bespoke Editorial Book Cover Artwork Renderer

private struct BookCoverArtworkView: View {
    let style: BookCoverArtStyle
    let formatBadge: BookFormatBadge?

    var body: some View {
        GeometryReader { proxy in
            let w = proxy.size.width
            let h = proxy.size.height

            ZStack(alignment: .topTrailing) {
                coverArtBody(width: w, height: h)
                    .frame(width: w, height: h)
                    .clipShape(RoundedRectangle(cornerRadius: 5, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 5, style: .continuous)
                            .strokeBorder(Color.black.opacity(0.08), lineWidth: 0.75)
                    )

                if let badge = formatBadge {
                    Text(badge.rawValue)
                        .font(.system(size: 10, weight: .semibold))
                        .tracking(0.4)
                        .foregroundStyle(.white.opacity(0.95))
                        .padding(.horizontal, 7)
                        .padding(.vertical, 3.5)
                        .background(
                            RoundedRectangle(cornerRadius: 4, style: .continuous)
                                .fill(Color(hex: 0x262422, opacity: 0.82))
                        )
                        .padding(.top, 9)
                        .padding(.trailing, 9)
                }
            }
        }
    }

    @ViewBuilder
    private func coverArtBody(width: CGFloat, height: CGFloat) -> some View {
        switch style {
        case .remainsOfTheDay:
            // Warm sunlit table with dark leather-bound volume
            ZStack {
                LinearGradient(
                    colors: [Color(hex: 0xD8CCB8), Color(hex: 0x8F7960), Color(hex: 0x3A2C22)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )

                // Hardcover book block
                RoundedRectangle(cornerRadius: 3, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [Color(hex: 0x3D251B), Color(hex: 0x24140E)],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(width: width * 0.74, height: height * 0.78)
                    .shadow(color: .black.opacity(0.45), radius: 6, x: 3, y: 4)
                    .overlay(
                        VStack(spacing: height * 0.03) {
                            Text("KAZUO\nISHIGURO")
                                .font(.system(size: max(6, width * 0.065), weight: .semibold, design: .serif))
                                .multilineTextAlignment(.center)
                                .foregroundStyle(Color(hex: 0xDFC39D))

                            Rectangle()
                                .fill(Color(hex: 0xC89D6C).opacity(0.6))
                                .frame(width: width * 0.35, height: 0.8)

                            Text("THE\nREMAINS\nOF THE DAY")
                                .font(.system(size: max(7, width * 0.08), weight: .bold, design: .serif))
                                .multilineTextAlignment(.center)
                                .foregroundStyle(Color(hex: 0xEAD4B4))
                        }
                        .padding(6)
                    )
            }

        case .slouchingTowardsBethlehem:
            // Light cream vintage paperback on linen surface
            ZStack {
                LinearGradient(
                    colors: [Color(hex: 0xDCDAD3), Color(hex: 0x9E9B93)],
                    startPoint: .top,
                    endPoint: .bottom
                )

                RoundedRectangle(cornerRadius: 2, style: .continuous)
                    .fill(Color(hex: 0xEFECE4))
                    .frame(width: width * 0.72, height: height * 0.76)
                    .shadow(color: .black.opacity(0.28), radius: 5, x: 2, y: 3)
                    .overlay(
                        VStack(spacing: height * 0.025) {
                            Text("SLOUCHING\nTOWARDS\nBETHLEHEM")
                                .font(.system(size: max(6, width * 0.068), weight: .bold, design: .serif))
                                .multilineTextAlignment(.center)
                                .foregroundStyle(Color(hex: 0x2C2926))

                            Circle()
                                .strokeBorder(Color(hex: 0x8A5A46), lineWidth: 1)
                                .frame(width: width * 0.18, height: width * 0.18)

                            Text("JOAN DIDION")
                                .font(.system(size: max(5.5, width * 0.058), weight: .medium, design: .serif))
                                .foregroundStyle(Color(hex: 0x5A524B))
                        }
                        .padding(6)
                    )
            }

        case .thePeregrine:
            // Deep forest green cloth edition with gold hawk silhouette
            ZStack {
                LinearGradient(
                    colors: [Color(hex: 0x454A3E), Color(hex: 0x1D221A)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )

                RoundedRectangle(cornerRadius: 3, style: .continuous)
                    .fill(Color(hex: 0x1B3124))
                    .frame(width: width * 0.76, height: height * 0.80)
                    .shadow(color: .black.opacity(0.45), radius: 5, x: 2, y: 3)
                    .overlay(
                        RoundedRectangle(cornerRadius: 2, style: .continuous)
                            .strokeBorder(Color(hex: 0xB89B67).opacity(0.45), lineWidth: 0.8)
                            .padding(5)
                    )
                    .overlay(
                        VStack(spacing: height * 0.03) {
                            Image(systemName: "bird.fill")
                                .font(.system(size: max(12, width * 0.16)))
                                .foregroundStyle(Color(hex: 0xC5A66E))

                            Text("THE\nPEREGRINE")
                                .font(.system(size: max(6.5, width * 0.072), weight: .bold, design: .serif))
                                .multilineTextAlignment(.center)
                                .foregroundStyle(Color(hex: 0xDEC492))

                            Text("J. A. BAKER")
                                .font(.system(size: max(5.5, width * 0.055), weight: .medium, design: .serif))
                                .foregroundStyle(Color(hex: 0xB89B67))
                        }
                    )
            }

        case .middlemarch:
            // Antiquarian green cloth hardcover with gilt border
            ZStack {
                LinearGradient(
                    colors: [Color(hex: 0xEDE7DC), Color(hex: 0x8A6345)],
                    startPoint: .top,
                    endPoint: .bottom
                )

                RoundedRectangle(cornerRadius: 3, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [Color(hex: 0x4B5746), Color(hex: 0x354031)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: width * 0.84, height: height * 0.80)
                    .shadow(color: .black.opacity(0.35), radius: 6, x: 0, y: 4)
                    .overlay(
                        RoundedRectangle(cornerRadius: 2, style: .continuous)
                            .strokeBorder(Color(hex: 0xC6A96E).opacity(0.65), lineWidth: 1.2)
                            .padding(8)
                    )
                    .overlay(
                        VStack(spacing: 6) {
                            Text("MIDDLEMARCH")
                                .font(.system(size: max(9, width * 0.082), weight: .bold, design: .serif))
                                .tracking(0.8)
                                .foregroundStyle(Color(hex: 0xDFC286))

                            Text("BY\nGEORGE ELIOT")
                                .font(.system(size: max(7, width * 0.055), weight: .medium, design: .serif))
                                .multilineTextAlignment(.center)
                                .foregroundStyle(Color(hex: 0xC9AC74))
                        }
                    )
            }

        case .aRoomOfOnesOwn:
            // Hogarth Press / classic cream edition with painterly window vignette
            ZStack {
                Color(hex: 0xE7E2D8)

                RoundedRectangle(cornerRadius: 3, style: .continuous)
                    .fill(Color(hex: 0xF3EEE4))
                    .frame(width: width * 0.82, height: height * 0.84)
                    .shadow(color: .black.opacity(0.16), radius: 5, x: 0, y: 3)
                    .overlay(
                        VStack(spacing: height * 0.022) {
                            Text("VIRGINIA WOOLF")
                                .font(.system(size: max(7.5, width * 0.058), weight: .semibold, design: .serif))
                                .tracking(0.8)
                                .foregroundStyle(Color(hex: 0x2F2A25))

                            // Illustrated arch window motif
                            ZStack {
                                RoundedRectangle(cornerRadius: 4, style: .continuous)
                                    .fill(
                                        LinearGradient(
                                            colors: [Color(hex: 0x8CA6B5), Color(hex: 0xD69B72), Color(hex: 0x6D7F65)],
                                            startPoint: .top,
                                            endPoint: .bottom
                                        )
                                    )
                                    .frame(width: width * 0.44, height: height * 0.34)

                                RoundedRectangle(cornerRadius: 4, style: .continuous)
                                    .strokeBorder(Color(hex: 0x4A3F37), lineWidth: 1)
                                    .frame(width: width * 0.44, height: height * 0.34)
                            }

                            Text("A ROOM\nOF ONE’S\nOWN")
                                .font(.system(size: max(9, width * 0.075), weight: .bold, design: .serif))
                                .multilineTextAlignment(.center)
                                .foregroundStyle(Color(hex: 0x221E1B))

                            Text("HOGARTH PRESS\nLONDON")
                                .font(.system(size: max(5.5, width * 0.038), weight: .medium))
                                .multilineTextAlignment(.center)
                                .foregroundStyle(Color(hex: 0x6E655C))
                        }
                        .padding(.vertical, 10)
                    )
            }

        case .mobyDick:
            // Deep navy cloth cover with silver/white engraved whale woodcut
            ZStack {
                LinearGradient(
                    colors: [Color(hex: 0xD5CFC4), Color(hex: 0x47392E)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )

                RoundedRectangle(cornerRadius: 3, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [Color(hex: 0x1C2D42), Color(hex: 0x0F1A28)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .frame(width: width * 0.86, height: height * 0.84)
                    .shadow(color: .black.opacity(0.45), radius: 6, x: 2, y: 4)
                    .overlay(
                        RoundedRectangle(cornerRadius: 2, style: .continuous)
                            .strokeBorder(Color(hex: 0x9FB1C7).opacity(0.5), lineWidth: 1)
                            .padding(7)
                    )
                    .overlay(
                        VStack(spacing: height * 0.03) {
                            Image(systemName: "water.waves")
                                .font(.system(size: max(18, width * 0.16), weight: .light))
                                .foregroundStyle(Color(hex: 0xC5D4E6))

                            Text("MOBY-DICK")
                                .font(.system(size: max(10, width * 0.085), weight: .bold, design: .serif))
                                .tracking(1.2)
                                .foregroundStyle(Color(hex: 0xE2ECF7))

                            Text("HERMAN MELVILLE")
                                .font(.system(size: max(6.5, width * 0.05), weight: .medium, design: .serif))
                                .foregroundStyle(Color(hex: 0x9FB1C7))
                        }
                    )
            }

        case .oldPatagonianExpress:
            // Warm ochre vintage travel edition with locomotive illustration
            ZStack {
                Color(hex: 0xECE7DF)

                RoundedRectangle(cornerRadius: 3, style: .continuous)
                    .fill(Color(hex: 0xDFB074))
                    .frame(width: width * 0.78, height: height * 0.82)
                    .shadow(color: .black.opacity(0.22), radius: 5, x: 0, y: 3)
                    .overlay(
                        RoundedRectangle(cornerRadius: 2, style: .continuous)
                            .strokeBorder(Color(hex: 0x5C3D24).opacity(0.55), lineWidth: 1)
                            .padding(6)
                    )
                    .overlay(
                        VStack(spacing: height * 0.02) {
                            Text("PAUL THEROUX\nTHE OLD\nPATAGONIAN\nEXPRESS")
                                .font(.system(size: max(7.5, width * 0.064), weight: .bold, design: .serif))
                                .multilineTextAlignment(.center)
                                .foregroundStyle(Color(hex: 0x2B1D12))

                            RoundedRectangle(cornerRadius: 3, style: .continuous)
                                .fill(
                                    LinearGradient(
                                        colors: [Color(hex: 0x7BA09E), Color(hex: 0x3D4B41)],
                                        startPoint: .top,
                                        endPoint: .bottom
                                    )
                                )
                                .frame(width: width * 0.44, height: height * 0.25)
                                .overlay(
                                    Image(systemName: "tram.fill")
                                        .font(.system(size: max(14, width * 0.11)))
                                        .foregroundStyle(Color(hex: 0xF3DEC0))
                                )

                            Text("BY TRAIN THROUGH\nTHE AMERICAS")
                                .font(.system(size: max(5.5, width * 0.042), weight: .semibold))
                                .multilineTextAlignment(.center)
                                .foregroundStyle(Color(hex: 0x3E2A1B))
                        }
                        .padding(8)
                    )
            }

        case .notesOfANativeSon:
            // Beacon Press dark charcoal/brown typographic cover with bold gold lettering
            ZStack {
                Color(hex: 0xE2DDD5)

                RoundedRectangle(cornerRadius: 3, style: .continuous)
                    .fill(Color(hex: 0x231F1D))
                    .frame(width: width * 0.82, height: height * 0.84)
                    .shadow(color: .black.opacity(0.32), radius: 5, x: 0, y: 3)
                    .overlay(
                        VStack(spacing: height * 0.022) {
                            Text("BEACON PRESS")
                                .font(.system(size: max(5.5, width * 0.04), weight: .semibold))
                                .tracking(1.0)
                                .foregroundStyle(Color(hex: 0x9E9284))

                            Text("NOTES\nOF A\nNATIVE\nSON")
                                .font(.system(size: max(11, width * 0.105), weight: .bold, design: .serif))
                                .multilineTextAlignment(.center)
                                .lineSpacing(1)
                                .foregroundStyle(Color(hex: 0xC9975B))

                            Text("BY\nJAMES BALDWIN")
                                .font(.system(size: max(6.5, width * 0.055), weight: .semibold, design: .serif))
                                .multilineTextAlignment(.center)
                                .foregroundStyle(Color(hex: 0xD8C3A5))
                        }
                        .padding(10)
                    )
            }

        case .onPhotography:
            // Picador / classic monochrome framed cover with aperture motif
            ZStack {
                Color(hex: 0xE7E4DF)

                RoundedRectangle(cornerRadius: 3, style: .continuous)
                    .fill(Color(hex: 0xF5F3EF))
                    .frame(width: width * 0.82, height: height * 0.84)
                    .shadow(color: .black.opacity(0.18), radius: 5, x: 0, y: 3)
                    .overlay(
                        RoundedRectangle(cornerRadius: 2, style: .continuous)
                            .strokeBorder(Color(hex: 0x22201E), lineWidth: 1.2)
                            .padding(9)
                    )
                    .overlay(
                        VStack(spacing: height * 0.022) {
                            Text("SUSAN SONTAG\nON\nPHOTOGRAPHY")
                                .font(.system(size: max(7.5, width * 0.062), weight: .bold))
                                .multilineTextAlignment(.center)
                                .foregroundStyle(Color(hex: 0x181715))

                            ZStack {
                                Rectangle()
                                    .fill(Color(hex: 0x181715))
                                    .frame(width: width * 0.28, height: width * 0.28)

                                Image(systemName: "camera.aperture")
                                    .font(.system(size: max(14, width * 0.16), weight: .regular))
                                    .foregroundStyle(Color(hex: 0xF5F3EF))
                            }

                            Text("ESSAYS")
                                .font(.system(size: max(6.5, width * 0.05), weight: .semibold))
                                .tracking(1.1)
                                .foregroundStyle(Color(hex: 0x181715))
                                .padding(.horizontal, 8)
                                .padding(.vertical, 2)
                                .overlay(
                                    Rectangle()
                                        .strokeBorder(Color(hex: 0x181715), lineWidth: 0.8)
                                )

                            Text("PICADOR")
                                .font(.system(size: max(5.5, width * 0.038), weight: .medium))
                                .tracking(0.9)
                                .foregroundStyle(Color(hex: 0x55504B))
                        }
                        .padding(14)
                    )
            }
        }
    }
}

// MARK: - 7. Bottom Split Previews (Vocabulary & Recent Marginalia)

private struct LibraryBottomPreviewsSectionView: View {
    let vocabularyItems: [LibraryVocabularyPreviewItem]
    let marginaliaItem: LibraryMarginaliaPreviewItem
    let onSelectBookTitle: (String) -> Void
    var onOpenVocabulary: ((String?) -> Void)? = nil

    var body: some View {
        VStack(spacing: 24) {
            Rectangle()
                .fill(SandpaperTheme.statusBarBorder)
                .frame(height: 1)

            HStack(alignment: .top, spacing: 28) {
                // Left Column: Vocabulary Preview
                VStack(alignment: .leading, spacing: 14) {
                    HStack(alignment: .firstTextBaseline) {
                        HStack(spacing: 8) {
                            Text("Aᵃ")
                                .font(.system(size: 14, weight: .bold, design: .serif))
                                .foregroundStyle(SandpaperTheme.secondaryInk)

                            Text("Vocabulary")
                                .font(.system(size: 18.5, weight: .medium, design: .serif))
                                .foregroundStyle(SandpaperTheme.primaryInk)
                        }

                        Spacer()

                        Button(action: { onOpenVocabulary?(nil) }) {
                            Text("View Vocabulary")
                                .font(.system(size: 12.5, weight: .medium))
                                .foregroundStyle(SandpaperTheme.terracottaAccent)
                        }
                        .buttonStyle(.plain)
                    }

                    VStack(spacing: 12) {
                        ForEach(vocabularyItems) { item in
                            VocabularyPreviewCard(
                                item: item,
                                onTapBook: {
                                    onOpenVocabulary?(item.id)
                                }
                            )
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .topLeading)

                // Right Column: Recent Marginalia Preview
                VStack(alignment: .leading, spacing: 14) {
                    HStack(alignment: .firstTextBaseline) {
                        HStack(spacing: 8) {
                            Image(systemName: "pencil")
                                .font(.system(size: 13.5, weight: .medium))
                                .foregroundStyle(SandpaperTheme.secondaryInk)

                            Text("Recent Marginalia")
                                .font(.system(size: 18.5, weight: .medium, design: .serif))
                                .foregroundStyle(SandpaperTheme.primaryInk)
                        }

                        Spacer()

                        Button(action: {}) {
                            Text("All Notes")
                                .font(.system(size: 12.5, weight: .medium))
                                .foregroundStyle(SandpaperTheme.terracottaAccent)
                        }
                        .buttonStyle(.plain)
                    }

                    MarginaliaPreviewCard(
                        item: marginaliaItem,
                        onTapCard: {
                            onSelectBookTitle("The Remains of the Day")
                        }
                    )
                }
                .frame(maxWidth: .infinity, alignment: .topLeading)
            }
        }
    }
}

private struct VocabularyPreviewCard: View {
    let item: LibraryVocabularyPreviewItem
    let onTapBook: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(action: onTapBook) {
            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .firstTextBaseline) {
                    HStack(alignment: .firstTextBaseline, spacing: 6) {
                        Text(item.word)
                            .font(.system(size: 16.5, weight: .medium, design: .serif))
                            .foregroundStyle(SandpaperTheme.primaryInk)

                        Text(item.partOfSpeech)
                            .font(.system(size: 12.5, weight: .regular, design: .serif))
                            .italic()
                            .foregroundStyle(SandpaperTheme.mutedInk)
                    }

                    Spacer()

                    Text(item.bookTitle)
                        .font(.system(size: 12, weight: .regular))
                        .foregroundStyle(SandpaperTheme.mutedInk)
                }

                Text(item.definition)
                    .font(.system(size: 14, weight: .regular, design: .serif))
                    .foregroundStyle(SandpaperTheme.strongInk)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(isHovered ? SandpaperTheme.pillBackground : Color(hex: 0xFBF7F0))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .strokeBorder(Color(hex: 0xECE4DA), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
    }
}

private struct MarginaliaPreviewCard: View {
    let item: LibraryMarginaliaPreviewItem
    let onTapCard: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(action: onTapCard) {
            VStack(alignment: .leading, spacing: 0) {
                // Quoted Passage with Terracotta Left Rule
                HStack(alignment: .top, spacing: 14) {
                    Rectangle()
                        .fill(SandpaperTheme.terracottaAccent.opacity(0.65))
                        .frame(width: 2)

                    Text(item.quote)
                        .font(.system(size: 16, weight: .regular, design: .serif))
                        .italic()
                        .lineSpacing(6)
                        .foregroundStyle(SandpaperTheme.strongInk)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.top, 4)

                Spacer(minLength: 28)

                // Footer Metadata
                HStack(alignment: .firstTextBaseline) {
                    Text(item.citation)
                        .font(.system(size: 12.5, weight: .regular, design: .serif))
                        .italic()
                        .foregroundStyle(SandpaperTheme.secondaryInk)

                    Spacer()

                    Text(item.annotationType)
                        .font(.system(size: 12, weight: .regular))
                        .foregroundStyle(SandpaperTheme.mutedInk)
                }
            }
            .padding(.horizontal, 22)
            .padding(.vertical, 22)
            .frame(maxWidth: .infinity, minHeight: 166, alignment: .topLeading)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(isHovered ? SandpaperTheme.pillBackground : Color(hex: 0xFBF7F0))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .strokeBorder(Color(hex: 0xECE4DA), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
    }
}

// MARK: - 8. Empty Library / Empty Filter State

private struct LibraryEmptyStateView: View {
    let searchText: String
    let selectedCategory: LibraryFilterCategory
    let onResetFilters: () -> Void
    let onImportBook: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "books.vertical")
                .font(.system(size: 32, weight: .light))
                .foregroundStyle(SandpaperTheme.terracottaAccent.opacity(0.8))

            Text(emptyTitle)
                .font(.system(size: 22, weight: .regular, design: .serif))
                .foregroundStyle(SandpaperTheme.primaryInk)

            Text(emptySubtitle)
                .font(.system(size: 14, weight: .regular, design: .serif))
                .foregroundStyle(SandpaperTheme.mutedInk)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 420)

            HStack(spacing: 12) {
                if !searchText.isEmpty || selectedCategory != .allTitles {
                    Button(action: onResetFilters) {
                        Text("Show All Titles")
                            .font(.system(size: 12.5, weight: .medium))
                            .foregroundStyle(SandpaperTheme.secondaryInk)
                            .padding(.horizontal, 14)
                            .frame(height: 32)
                            .background(
                                RoundedRectangle(cornerRadius: 6, style: .continuous)
                                    .fill(SandpaperTheme.cardBackground)
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 6, style: .continuous)
                                    .strokeBorder(SandpaperTheme.subtleStroke, lineWidth: 1)
                            )
                    }
                    .buttonStyle(.plain)
                }

                Button(action: onImportBook) {
                    HStack(spacing: 7) {
                        Image(systemName: "square.and.arrow.up")
                            .font(.system(size: 11.5, weight: .semibold))
                        Text("Import Book")
                            .font(.system(size: 12.5, weight: .semibold))
                    }
                    .foregroundStyle(.white)
                    .padding(.horizontal, 14)
                    .frame(height: 32)
                    .background(
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .fill(SandpaperTheme.popoverPrimaryButton)
                    )
                }
                .buttonStyle(.plain)
            }
            .padding(.top, 6)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 64)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color(hex: 0xFBF7F0))
                .overlay(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .strokeBorder(Color(hex: 0xECE4DA), lineWidth: 1)
                )
        )
    }

    private var emptyTitle: String {
        if !searchText.isEmpty {
            return "No volumes matching “\(searchText)”"
        }
        return "No volumes in \(selectedCategory.rawValue)"
    }

    private var emptySubtitle: String {
        if !searchText.isEmpty {
            return "Try searching by another title, author, or section, or clear your search filter."
        }
        return "Import an EPUB, PDF, Markdown, plain text file, or web article to begin reading."
    }
}

// MARK: - 9. Minimal Native Webpage URL Import Sheet

private struct ImportWebArticleSheet: View {
    @Binding var urlString: String
    let onCancel: () -> Void
    let onSubmit: (URL) -> Void

    private var parsedURL: URL? {
        let trimmed = urlString.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty,
              let url = URL(string: trimmed),
              let scheme = url.scheme?.lowercased(),
              scheme == "https" || scheme == "http" else {
            return nil
        }
        return url
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack {
                Text("Add Webpage or Article")
                    .font(.system(size: 20, weight: .medium, design: .serif))
                    .foregroundStyle(SandpaperTheme.primaryInk)

                Spacer()

                Button(action: onCancel) {
                    Image(systemName: "xmark")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(SandpaperTheme.mutedInk)
                }
                .buttonStyle(.plain)
            }

            Text("Enter the URL of an essay or long-form article to hand off to Sandpaper’s reader extraction pipeline.")
                .font(.system(size: 13, weight: .regular))
                .foregroundStyle(SandpaperTheme.mutedInk)
                .fixedSize(horizontal: false, vertical: true)

            TextField("https://example.com/essay", text: $urlString)
                .textFieldStyle(.plain)
                .font(.system(size: 13.5, weight: .regular))
                .foregroundStyle(SandpaperTheme.primaryInk)
                .padding(.horizontal, 12)
                .frame(height: 34)
                .background(
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(SandpaperTheme.canvasBackground)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .strokeBorder(SandpaperTheme.subtleStroke, lineWidth: 1)
                )

            HStack {
                Spacer()

                Button("Cancel", action: onCancel)
                    .buttonStyle(.plain)
                    .font(.system(size: 12.5, weight: .medium))
                    .foregroundStyle(SandpaperTheme.secondaryInk)
                    .padding(.horizontal, 12)
                    .frame(height: 30)

                Button {
                    if let url = parsedURL {
                        onSubmit(url)
                    }
                } label: {
                    Text("Add to Library")
                        .font(.system(size: 12.5, weight: .semibold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 14)
                        .frame(height: 30)
                        .background(
                            RoundedRectangle(cornerRadius: 6, style: .continuous)
                                .fill(
                                    parsedURL != nil
                                        ? SandpaperTheme.popoverPrimaryButton
                                        : SandpaperTheme.subtleStroke
                                )
                        )
                }
                .buttonStyle(.plain)
                .disabled(parsedURL == nil)
            }
        }
        .padding(24)
        .frame(width: 440)
        .background(SandpaperTheme.chromeBackground)
    }
}

// MARK: - Previews

#Preview("Sandpaper — Personal Library (Main Entry)") {
    SandpaperRootView()
        .frame(width: 1440, height: 1180)
}
