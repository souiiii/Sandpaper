# Sandpaper backend

Native Swift 6 backend for a personal macOS reader, targeting an M4 Mac with
16 GB unified memory. The frontend is developed separately in SwiftUI/AppKit.
No frontend views or styling live in this package.

## Current increment

- Managed, streaming file imports with SHA-256 deduplication. Originals stay untouched.
- SQLite migrations, persistent reading state, vocabulary senses and source occurrences.
- Recoverable document trash that retains associated state and managed files.
- UTF-16 source anchors with quotation/context recovery and explicit ambiguity.
- A debounced, cancellable analysis coordinator with foreground priority and at
  most one running engine operation. Optional explanation sections carry their basis.
- Discovery assessments separate contextual sense, intrinsic learning value,
  explicit familiarity and highlight eligibility, retaining suppression reasons.
- A loopback-only llama.cpp adapter with streaming, token-budget checks, cancellation,
  bounded response parsing, and an executable evaluation runner.

**No model weights or lexical dataset are installed yet.** The default engine
reports `modelNotConfigured`. The implemented `LlamaLocalEngine` needs a manually
started local worker; see [local inference setup](docs/local-inference.md). File import
recognizes PDF, EPUB, TXT, Markdown, and HTML, but format parsing/rendering, OCR,
web fetching, indexing, editing, and permanent deletion are subsequent
increments. This is a backend foundation, not a finished reader.

## Build

Use a Swift 6.1+ macOS toolchain:

```sh
swift test
```

The current Command Line Tools 6.4 host requires its bundled test macro directory
to be supplied explicitly (this is not a runtime dependency):

```sh
swift test -Xswiftc -plugin-path -Xswiftc "$(dirname "$(xcrun --find swiftc)")/../lib/swift/host/plugins/testing"
```

The sole external dependency is GRDB, pinned in `Package.swift` and
`Package.resolved`. Dependency resolution needs internet on the first build;
inference runtime requests are restricted to IPv4 loopback. HTTP integration tests
bind ephemeral loopback ports and need local socket access.

## Frontend contract

Create one `DocumentLibrary` per library directory in Application Support.
Keep model files outside the source checkout. Import with `importDocument(from:)`;
use the returned document ID/revision when constructing passages and anchors.
All library calls cross an actor boundary. Do not modify files returned by
`contentURL(for:)`; revision-aware editing will have its own API.

For a visible passage, supply `AnalysisPassage` with canonical source text,
its resource, and its UTF-16 offset within that resource. Submit it through
`AnalysisCoordinator.discover`. A newer viewport supersedes previous discovery.
`foregroundBusy` means to retry background discovery after the foreground request
finishes. Ignore `CancellationError` for superseded navigation. Keep the same
coordinator when switching between floating and docked explanation views.
Discovery now returns a `DiscoveryReport`: render only `highlights`, while
`assessments` retains known, low-value, uncertain, repeated, and overlapping
candidates for evaluation. See the inference guide for the updated sense-memory contract.

Resources are `.text` for TXT/Markdown, `.pdfPage(index:)` with a zero-based index,
`.epub(path:)` for a package resource, and `.article` for an imported article.
Screen page numbers are presentation state, never a source identity. Text
extraction must preserve a mapping from displayed selections to canonical source
text; offsets into Markdown markup or raw EPUB HTML are not interchangeable with
rendered text offsets. This mapping must be implemented with the format adapters.

Build an anchor using `passage.anchor(for:)` with an `NSRange` in the supplied
passage. Save it alongside reading state or a vocabulary occurrence. Resolve
against the same resource's complete canonical text. `.ambiguous` and `.missing`
must remain explicit; never jump to an arbitrary match.

Vocabulary identity is a normalized expression **and a meaning key**. Store
familiarity per sense; later saves preserve familiarity and notes. Provide only
relevant familiarity records to discovery. Do not equate ignored suggestions
with known vocabulary. Saving the same occurrence from different viewport sizes
does not duplicate it. A trashed document's occurrences remain stored and can be
queried with `includingTrash: true`.

## Product decisions for subsequent increments

- English from approximately 1880 onward, including contemporary informal usage.
  Explanations assume a fluent reader and discuss grammar only when useful.
- Discovery is the central feature. Rank by contextual learning value and personal
  familiarity, with no minimum quota. Suppress repeat senses, retain novel uses.
- Local inference only; manually supplied models and lexical data. Internet is
  optional for explicit article import or resource updates. No document upload.
- Conservative spoiler handling for narrative/uncertain documents, broader context
  for reference material, with a per-document override. Past-context retrieval and
  spoiler enforcement are not implemented in this increment.
- Printed-page OCR must tolerate imperfect scans; handwriting is outside scope.
- Edit owned TXT/Markdown; later support small text corrections in ordinary
  reflowable EPUBs. Preserve layout where possible and report unsupported structures.
  PDF editing means annotations, not rewriting original PDF text.
- Benchmark local-model discovery and explanations with `sandpaper-evaluate`
  before choosing the final model. The initial baseline download is documented above.

Import installs a fully written file before committing its database row. An app
interruption can leave unreferenced staging/content files; automatic orphan cleanup
and power-loss fault testing are not implemented yet. No permanent-delete API is
exposed in this increment.
