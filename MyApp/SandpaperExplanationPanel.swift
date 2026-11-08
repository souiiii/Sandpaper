import SwiftUI
import AppKit

// MARK: - Explanation Presentation Mode & Models

enum ExplanationPresentationMode: String, Sendable, Equatable {
    case hidden
    case floatingExpanded
    case sidePanel
}

struct ContextualExplanationEntry: Identifiable, Equatable, Sendable {
    let id: String
    let selectedPassage: String
    let locationMetadata: String
    let chapterSubtitle: String
    let explanationTitle: String
    let explanationBody: String

    init(
        selectedPassage: String,
        locationMetadata: String = "p. 244 · ln 18–22 · § Epilogue",
        chapterSubtitle: String = "Day Six: Evening · Weymouth",
        explanationTitle: String = "Meaning in context",
        explanationBody: String
    ) {
        self.id = selectedPassage.lowercased()
        self.selectedPassage = selectedPassage
        self.locationMetadata = locationMetadata
        self.chapterSubtitle = chapterSubtitle
        self.explanationTitle = explanationTitle
        self.explanationBody = explanationBody
    }
}

// MARK: - Mock Contextual Explanation Provider

enum MockContextualExplanationProvider {
    static func explain(
        selectedText: String,
        contextText: String,
        chapterLabel: String,
        currentPage: Int
    ) -> ContextualExplanationEntry {
        let cleaned = selectedText.trimmingCharacters(in: .whitespacesAndNewlines)
        let lower = cleaned.lowercased()

        // Exact match for the reference screenshot passage
        if lower.contains("worrying oneself")
            || lower.contains("course one’s life took")
            || lower.contains("course one's life took") {
            return ContextualExplanationEntry(
                selectedPassage: "“What is the point of worrying oneself so much about what one could or could not have done to control the course one’s life took?”",
                locationMetadata: "p. 244 · ln 18–22 · § Epilogue",
                chapterSubtitle: "Day Six: Evening · Weymouth",
                explanationBody: "“One” and “oneself” are impersonal pronouns: they turn a personal question into a general reflection. Here, “the course one’s life took” means the way a person’s life unfolded. The sentence asks whether dwelling on past choices can change their outcome."
            )
        }

        if lower == "ineluctable" {
            return ContextualExplanationEntry(
                selectedPassage: "“It was perhaps an ineluctable conclusion, arrived at only after years of circumspection, that Miss Kenton’s letter had carried beneath its cordial domestic pleasantries a note of unmistakable despondency.”",
                locationMetadata: "p. \(currentPage) · ln 11–15 · § Reflection",
                chapterSubtitle: chapterLabel,
                explanationBody: "Here, “ineluctable” suggests a realization Stevens could no longer politely evade. Rather than a sudden discovery, it marks an unavoidable truth that surfaced only after years of guarded retrospection."
            )
        }

        if lower == "dignity" || lower == "‘dignity’" {
            return ContextualExplanationEntry(
                selectedPassage: "“It is precisely this question of ‘dignity’ that has occupied my thoughts for the past hour.”",
                locationMetadata: "p. \(currentPage) · ln 14–18 · § Part IV",
                chapterSubtitle: chapterLabel,
                explanationBody: "Throughout Stevens’s journal, “dignity” denotes complete emotional self-command in professional service—the stoic refusal to let private grief or affection breach one’s public duty."
            )
        }

        if lower == "tranquillity" {
            return ContextualExplanationEntry(
                selectedPassage: "“...one is left with a profound sense of tranquillity that would seem quite foreign to the bustle of Darlington Hall in its heyday.”",
                locationMetadata: "p. \(currentPage) · ln 5–8 · § Opening",
                chapterSubtitle: chapterLabel,
                explanationBody: "The stillness of Mortimer’s Pond contrasts sharply with the rigid domestic choreography of Darlington Hall, allowing Stevens’s closely guarded memories to surface."
            )
        }

        // Fallback for any other selected word, phrase, or multi-line passage
        let passageSource = cleaned.count > 28 ? cleaned : (contextText.isEmpty ? cleaned : contextText)
        let formattedPassage: String
        if passageSource.hasPrefix("“") || passageSource.hasPrefix("\"") {
            formattedPassage = passageSource
        } else {
            formattedPassage = "“\(passageSource)”"
        }

        return ContextualExplanationEntry(
            selectedPassage: formattedPassage,
            locationMetadata: "p. \(currentPage) · ln 18–22 · § Epilogue",
            chapterSubtitle: chapterLabel,
            explanationBody: "“One” and “oneself” are impersonal pronouns: they turn a personal question into a general reflection. Here, “the course one’s life took” means the way a person’s life unfolded. The sentence asks whether dwelling on past choices can change their outcome."
        )
    }
}

// MARK: - Shared Selected Passage Callout Card

struct SelectedPassageCardView: View {
    let passage: String
    let metadata: String
    var showsBookIconInHeader: Bool = false
    var isCompact: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: isCompact ? 10 : 14) {
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                if showsBookIconInHeader {
                    Image(systemName: "book")
                        .font(.system(size: 10.5, weight: .semibold))
                        .foregroundStyle(SandpaperTheme.terracottaAccent)
                }

                Text("SELECTED PASSAGE")
                    .font(.system(size: 10.5, weight: .bold))
                    .tracking(0.8)
                    .foregroundStyle(SandpaperTheme.terracottaAccent)

                Spacer(minLength: 8)

                Text(metadata)
                    .font(.system(size: 11, weight: .regular))
                    .foregroundStyle(SandpaperTheme.mutedInk)
                    .monospacedDigit()
                    .padding(.horizontal, showsBookIconInHeader ? 7 : 0)
                    .padding(.vertical, showsBookIconInHeader ? 2 : 0)
                    .background(
                        RoundedRectangle(cornerRadius: 4, style: .continuous)
                            .fill(showsBookIconInHeader ? Color(hex: 0xEAE2D9) : .clear)
                    )
            }

            Text(passage)
                .font(.system(size: isCompact ? 14 : 15, weight: .regular, design: .serif))
                .italic()
                .lineSpacing(isCompact ? 5.5 : 7)
                .foregroundStyle(SandpaperTheme.primaryInk)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.vertical, isCompact ? 14 : 18)
        .padding(.leading, isCompact ? 16 : 19)
        .padding(.trailing, isCompact ? 14 : 18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(hex: 0xF5EFE8))
        .overlay(alignment: .leading) {
            if !showsBookIconInHeader {
                Rectangle()
                    .fill(SandpaperTheme.terracottaAccent)
                    .frame(width: 3)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .strokeBorder(Color(hex: 0xEAE1D8), lineWidth: 1)
        )
    }
}

// MARK: - Shared Action Buttons Row (Save Note, Copy & Optional Panel Mode Switch)

struct ExplanationActionRowView: View {
    let isNoteSaved: Bool
    let didCopy: Bool
    let onSaveNote: () -> Void
    let onCopy: () -> Void
    var onDockToSidePanel: (() -> Void)? = nil

    @State private var isHoveringSave = false
    @State private var isHoveringCopy = false
    @State private var isHoveringDock = false

    var body: some View {
        HStack(spacing: 8) {
            // Save Note (Terracotta Primary Button)
            Button(action: onSaveNote) {
                HStack(spacing: 6) {
                    Image(systemName: isNoteSaved ? "bookmark.fill" : "bookmark")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.white)

                    Text(isNoteSaved ? "Saved Note" : "Save Note")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.white)
                }
                .padding(.horizontal, 13)
                .frame(height: 30)
                .background(
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(
                            isHoveringSave
                                ? SandpaperTheme.popoverPrimaryButtonHover
                                : SandpaperTheme.popoverPrimaryButton
                        )
                )
            }
            .buttonStyle(.plain)
            .onHover { isHoveringSave = $0 }

            // Copy Button
            Button(action: onCopy) {
                HStack(spacing: 6) {
                    Image(systemName: didCopy ? "checkmark" : "doc.on.doc")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(SandpaperTheme.secondaryInk)

                    Text(didCopy ? "Copied" : "Copy")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(SandpaperTheme.secondaryInk)
                }
                .padding(.horizontal, 12)
                .frame(height: 30)
                .background(
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(
                            isHoveringCopy
                                ? SandpaperTheme.pillBackground
                                : SandpaperTheme.canvasBackground
                        )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .strokeBorder(SandpaperTheme.subtleStroke, lineWidth: 1)
                )
            }
            .buttonStyle(.plain)
            .onHover { isHoveringCopy = $0 }

            Spacer()

            // Optional button in Floating Mode to dock into the Right-Side Panel Mode
            if let onDockToSidePanel {
                Button(action: onDockToSidePanel) {
                    HStack(spacing: 5) {
                        Image(systemName: "sidebar.right")
                            .font(.system(size: 11.5, weight: .medium))
                        Text("Side Panel")
                            .font(.system(size: 11.5, weight: .medium))
                    }
                    .foregroundStyle(SandpaperTheme.secondaryInk)
                    .padding(.horizontal, 10)
                    .frame(height: 30)
                    .background(
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .fill(isHoveringDock ? SandpaperTheme.pillBackground : .clear)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .strokeBorder(SandpaperTheme.subtleStroke.opacity(0.85), lineWidth: 1)
                    )
                }
                .buttonStyle(.plain)
                .help("Open in Right Side Panel")
                .onHover { isHoveringDock = $0 }
            }
        }
    }
}

// MARK: - Stage 1: Downward-Expanding Scrollable Floating Explanation Drawer

struct FloatingExplanationDrawerView: View {
    let explanation: ContextualExplanationEntry
    let isNoteSaved: Bool
    var maxDrawerHeight: CGFloat = 300
    let onSaveNote: () -> Void
    let onDockToSidePanel: () -> Void

    @State private var didCopy = false
    @State private var measuredContentHeight: CGFloat = 260

    private var effectiveHeight: CGFloat {
        min(measuredContentHeight, max(150, maxDrawerHeight))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Static Divider separating the static top portion from the scrollable bottom portion
            Rectangle()
                .fill(SandpaperTheme.toolbarDivider)
                .frame(height: 1)

            // Scrollable Bottom Content
            ScrollView(.vertical, showsIndicators: true) {
                VStack(alignment: .leading, spacing: 14) {
                    SelectedPassageCardView(
                        passage: explanation.selectedPassage,
                        metadata: explanation.locationMetadata,
                        isCompact: true
                    )

                    Text(explanation.explanationTitle)
                        .font(.system(size: 16, weight: .medium, design: .serif))
                        .foregroundStyle(SandpaperTheme.primaryInk)
                        .padding(.top, 2)

                    Text(explanation.explanationBody)
                        .font(.system(size: 13.5, weight: .regular, design: .serif))
                        .lineSpacing(5.5)
                        .foregroundStyle(SandpaperTheme.secondaryInk)
                        .fixedSize(horizontal: false, vertical: true)

                    ExplanationActionRowView(
                        isNoteSaved: isNoteSaved,
                        didCopy: didCopy,
                        onSaveNote: onSaveNote,
                        onCopy: copyExplanationToPasteboard,
                        onDockToSidePanel: onDockToSidePanel
                    )
                    .padding(.top, 4)
                }
                .padding(.horizontal, 21)
                .padding(.top, 16)
                .padding(.bottom, 18)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    GeometryReader { contentProxy in
                        Color.clear
                            .onAppear {
                                if contentProxy.size.height > 0 {
                                    measuredContentHeight = contentProxy.size.height
                                }
                            }
                            .onChange(of: contentProxy.size.height) { _, newHeight in
                                if newHeight > 0 {
                                    measuredContentHeight = newHeight
                                }
                            }
                    }
                )
            }
            .frame(height: effectiveHeight)
            .background(SandpaperTheme.canvasBackground)
        }
    }

    private func copyExplanationToPasteboard() {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(explanation.explanationBody, forType: .string)
        didCopy = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.4) {
            didCopy = false
        }
    }
}

// MARK: - Stage 2: Docked Right-Hand "Explain in Context" Side Panel (Reference Screenshot)

struct ContextualExplanationSidePanelView: View {
    let explanation: ContextualExplanationEntry
    let isNoteSaved: Bool
    let onSaveNote: () -> Void
    let onSwitchToFloating: () -> Void
    let onClose: () -> Void

    @State private var didCopy = false
    @State private var isHoveringClose = false
    @State private var isHoveringFloat = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Top Panel Header
            HStack(alignment: .center, spacing: 12) {
                Image(systemName: "book")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(SandpaperTheme.terracottaAccent)

                VStack(alignment: .leading, spacing: 2.5) {
                    Text("Explain in Context")
                        .font(.system(size: 18, weight: .regular, design: .serif))
                        .foregroundStyle(SandpaperTheme.primaryInk)

                    Text(explanation.chapterSubtitle)
                        .font(.system(size: 11.5, weight: .regular))
                        .foregroundStyle(SandpaperTheme.mutedInk)
                }

                Spacer()

                // Optional toggle back to Floating Popover mode
                Button(action: onSwitchToFloating) {
                    Image(systemName: "pip.exit")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(SandpaperTheme.mutedInk)
                        .frame(width: 24, height: 24)
                        .background(
                            RoundedRectangle(cornerRadius: 5, style: .continuous)
                                .fill(isHoveringFloat ? SandpaperTheme.subtleStroke.opacity(0.22) : .clear)
                        )
                }
                .buttonStyle(.plain)
                .help("Undock to Floating Popover")
                .onHover { isHoveringFloat = $0 }

                // Close Button ("X")
                Button(action: onClose) {
                    Image(systemName: "xmark")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(SandpaperTheme.secondaryInk)
                        .frame(width: 24, height: 24)
                        .background(
                            RoundedRectangle(cornerRadius: 5, style: .continuous)
                                .fill(isHoveringClose ? SandpaperTheme.subtleStroke.opacity(0.22) : .clear)
                        )
                }
                .buttonStyle(.plain)
                .help("Close Panel")
                .onHover { isHoveringClose = $0 }
            }
            .padding(.horizontal, 24)
            .padding(.top, 20)
            .padding(.bottom, 16)

            // Header Divider
            Rectangle()
                .fill(SandpaperTheme.statusBarBorder)
                .frame(height: 1)

            // Panel Content
            ScrollView(.vertical) {
                VStack(alignment: .leading, spacing: 0) {
                    // SELECTED PASSAGE Box
                    SelectedPassageCardView(
                        passage: explanation.selectedPassage,
                        metadata: explanation.locationMetadata,
                        isCompact: false
                    )
                    .padding(.top, 24)

                    // "Meaning in context" Heading
                    Text(explanation.explanationTitle)
                        .font(.system(size: 17, weight: .medium, design: .serif))
                        .foregroundStyle(SandpaperTheme.primaryInk)
                        .padding(.top, 24)

                    // Explanation Body Copy
                    Text(explanation.explanationBody)
                        .font(.system(size: 14.5, weight: .regular, design: .serif))
                        .lineSpacing(7)
                        .foregroundStyle(SandpaperTheme.secondaryInk)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.top, 12)

                    // Action Buttons: Save Note & Copy
                    ExplanationActionRowView(
                        isNoteSaved: isNoteSaved,
                        didCopy: didCopy,
                        onSaveNote: onSaveNote,
                        onCopy: copyExplanationToPasteboard,
                        onDockToSidePanel: nil
                    )
                    .padding(.top, 22)
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 32)
            }
        }
        .frame(width: 396)
        .frame(maxHeight: .infinity, alignment: .top)
        .background(Color(hex: 0xFAF6EF))
        .overlay(alignment: .leading) {
            Rectangle()
                .fill(SandpaperTheme.statusBarBorder)
                .frame(width: 1)
        }
    }

    private func copyExplanationToPasteboard() {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(explanation.explanationBody, forType: .string)
        didCopy = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.4) {
            didCopy = false
        }
    }
}

#Preview("Stage 1 — Floating Popover Expanded Downward") {
    SandpaperReaderView(
        initialSelection: ReaderTextSelection(
            blockID: "p2",
            nsRange: NSRange(location: 444, length: 11),
            selectedText: "ineluctable",
            contextText: "It was perhaps an ineluctable conclusion, arrived at only after years of circumspection.",
            lineHighlightRects: [CGRect(x: 154, y: 214, width: 115, height: 28.5)],
            anchorRectInReader: CGRect(x: 444, y: 520, width: 115, height: 28.5)
        ),
        initialExplanationMode: .floatingExpanded
    )
    .frame(width: 1280, height: 1100)
}

#Preview("Stage 2 — Docked Right-Side Explain in Context Panel") {
    SandpaperReaderView(
        initialExplanationMode: .sidePanel,
        initialExplanation: MockContextualExplanationProvider.explain(
            selectedText: "What is the point of worrying oneself so much about what one could or could not have done to control the course one’s life took?",
            contextText: "",
            chapterLabel: "Day Six: Evening · Weymouth",
            currentPage: 244
        )
    )
    .frame(width: 1440, height: 1100)
}
