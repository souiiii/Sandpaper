# Sandpaper backend

Native Swift 6 backend for a local macOS reader. The SwiftUI/AppKit frontend is
owned separately; this package contains no views or styling.

## Reading workflow

`DocumentLibrary` manages immutable imported originals, SQLite persistence and
recoverable trash. Create a `ReaderSession` for each reader window:

```swift
let library = try DocumentLibrary(directory: libraryDirectory)
let imported = try await library.importDocument(from: fileURL)
let reader = ReaderSession(library: library)
let book = try await reader.open(documentID: imported.document.id)
let resource = book.resources[0].source
let content = try await reader.content(for: resource)
// Render content.attributedText for reflowable text, or book.fileURL with PDFKit.
let selection = try await reader.select(
    documentID: book.document.id, resource: resource, range: selectedUTF16Range
)
let entries = try await reader.lookup(selectionID: selection.id)
// The user chooses a meaning from the returned article, or writes a personal gloss.
let occurrence = try await reader.save(
    selectionID: selection.id,
    meaning: .dictionary(entryID: entries[0].id, range: chosenDefinitionRange),
    notes: "My note"
)
let destination = try await reader.navigate(to: occurrence)
```

Dictionary results use macOS's installed active dictionaries. They are complete
articles, **not automatically resolved senses**. Empty results remain explicit;
check Dictionary.app's settings for available English dictionaries. Lookup does
not require an AI model or start inference. A selected dictionary excerpt retains
its provider; personal edits and AI interpretations have separate provenance.
After an exact phrase miss, a bounded first-word lemma retry can find inflections
such as “fell through” under “fall through”; `entry.query` identifies the retrieved
headword. Component-word definitions are never substituted for a missing phrase.

Sense identity combines the normalized expression with the chosen meaning key.
Resaving an occurrence does not duplicate it or reset familiarity. Reuse
`.existingSense(id)` to attach another passage or inflected expression to an
existing sense. Personal notes change only when explicitly supplied. Vocabulary
meanings, familiarity, notes and occurrences can be edited or deleted independently.

## Format and location contracts

- TXT: UTF-8 and BOM-marked UTF-16, retaining Unicode and source text.
- Markdown: native Foundation parsing, inline formatting and explicit paragraph
  boundaries. Selection offsets refer to the returned text, not Markdown markup.
- PDF: native PDFKit file rendering; canonical text is loaded one page at a time.
  `PDFSelectionBridge` exposes exact per-page text ranges. Image-only pages support
  resource bookmarks/progress but need OCR for text selection; OCR is not implemented.
- EPUB: ZIPFoundation archive reading, spine order, EPUB 3 navigation/EPUB 2 NCX,
  native text blocks, emphasis, fragments and image asset references. The backend
  never executes scripts, resolves external entities or fetches remote assets.
  Fixed-layout EPUBs are explicitly unsupported. Publisher CSS, media playback and
  full publisher-layout fidelity are not implemented by this native text adapter.

Render the returned canonical text when selecting reflowable content. Anchors use
UTF-16 offsets within a resource, independent of window size and typography.
Resolution can be exact, relocated, ambiguous or missing; never guess a location.
Only two content resources are cached. Individual text files are limited to 16 MiB,
EPUB chapters to 4 MiB, and requested EPUB assets to 20 MiB.

`recordProgress`, `bookmark`, `readingPosition` and `bookmarks` persist positions,
including resources without extractable text. Preferences persist separately and
never change canonical text or source anchors. Trash retains bookmarks and vocabulary.

## Optional explanations

Inject a configured `LlamaLocalEngine` into `ReaderSession`, then call `explain`
**only in response to an explicit user request**. Stream updates are provisional;
only a completed, validated explanation can be saved with `.aiInterpretation()`.
Dictionary lookup and saving remain independent while generation runs. Changing
selection cancels the previous request and rejects stale updates/results.
`explain(dictionaryAssistance: true)` optionally supplies bounded verbatim local
dictionary excerpts. `answer.dictionaryEvidence` retains these separately from
generated prose. Assistance defaults off: a general dictionary sense can bias the
model toward a meaning that does not fit this passage.
Context includes preceding text and the selected sentence; an optional visible
range further bounds following text. Later resources are never prefetched.
See [local inference setup](docs/local-inference.md).

There is no automatic discovery, background inference, predictive preparation,
model downloader or model process launched on document open. Retired experiments,
bulk reports and the obsolete plan were removed from this checkout.

## Verification

```sh
swift test
```

On the current Command Line Tools host, provide its bundled test macro path:

```sh
swift test -Xswiftc -plugin-path -Xswiftc /Library/Developer/CommandLineTools/usr/lib/swift/host/plugins/testing
```

GRDB 7.12.0 handles storage; ZIPFoundation 0.9.20 handles EPUB ZIP containers.
Both dependencies are pinned. Tests cover reading, Unicode selection, dictionary
and vocabulary persistence, migrations, navigation, trash, provenance, cancellation,
and loopback-only inference transport. No frontend styling is modified.
