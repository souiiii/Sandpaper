# Explicit local explanations

The reader and dictionary work without AI. `LlamaLocalEngine` connects only to
127.0.0.1; it never downloads models, launches a worker, follows redirects, or
falls back to a cloud service. `ReaderSession` makes no availability or inference
requests when opening, navigating, selecting text, looking up definitions or saving
vocabulary. Only its explicit `explain` operation requests generation.

Use the existing llama.cpp b12110 macOS arm64 worker, with accompanying libraries,
and a manually supplied GGUF outside the repository. Gemma 3 12B IT Q4_K_M remains
available under `/private/tmp/sandpaper-ai-validation/`; the rejected Qwen model
weights were removed. The retained Gemma file SHA-256 is
`7bb69bff3f48a7b642355d64a90e481182a7794707b3133890646b1efa778ff5`.
Model interpretations remain fallible and are never presented as dictionary facts.

Start a worker explicitly when explanations are wanted:

```sh
/path/to/llama-server \
  --model /path/to/gemma-3-12b-it-Q4_K_M.gguf \
  --alias sandpaper-local --host 127.0.0.1 --port 8087 \
  --ctx-size 4096 --parallel 1 --n-gpu-layers 99 \
  --batch-size 512 --ubatch-size 128 \
  --cache-type-k q8_0 --cache-type-v q8_0 --flash-attn on \
  --cache-ram 0 --no-context-shift --no-webui --jinja \
  --sleep-idle-seconds 30
```

The idle-sleep setting releases worker model resources when unused. Do not start
this process merely because the reader opened a book. Application-owned process
installation/supervision is outside this package; stop a manually started worker
when finished. No worker is required for the core reading workflow.

```swift
let engine = LlamaLocalEngine(
    configuration: try LlamaServerConfiguration(chatFormat: .gemma3)
)
let reader = ReaderSession(library: library, engine: engine)
// After the user explicitly asks for an explanation:
let answer = try await reader.explain(selectionID: selection.id) { provisional in
    // Display provisional interpretation; do not persist it yet.
}
```

Generation has bounded input/output, timeout and cancellation. New selection
requests cancel/drain the previous request before using the single inference
slot. Token-budget overflow, absent models and incomplete generation are explicit
errors. Source text is untrusted input, not instructions. No etymology is promoted
to a sourced fact by the model.

## Measured backend validation (M4, 16 GiB)

[Recorded outputs, timings, sources and review](backend-validation.json) cover
19 original passages plus five new checks. These are small, unblinded developer
checks, not an accuracy certification. AI answers were generated anew; llama.cpp
reused shared prompt/KV prefixes. Model startup is excluded below.

| Configuration | Requests | Median complete answer | Median first readable text |
| --- | ---: | ---: | ---: |
| Original prompt | 19 | 5.69 s | 1.54 s |
| Concise paragraph, no dictionary | 19 | 4.20 s | 1.55 s |
| Same paragraph prompt with dictionary excerpts | 19 | 4.77 s | 1.63 s |
| Final calibrated paragraph, no dictionary | 48 (24 × 2) | 3.33 s | 1.40 s |

Final responses ranged from 2.20–6.38 s (nearest-rank p95 5.29 s). The first,
uncached-prompt answer took 6.18 s after the worker became ready; that worker took
10.69 s to load. Startup varied with OS cache state. Other apps stayed open, so
these timings are observations rather than isolated estimates of each change.

Correct final interpretations included wealth, withheld endorsement, language
corrupting thought, sarcasm, literal gunpowder/ice, qualified praise and restive.
The shorter format eliminated repetitive notes and the baseline's invented
unlocking action and seal-origin explanation. Important errors persisted in both
final runs: a literal cat was treated as a secret; telescope/duck ambiguities were
resolved with unjustified certainty; “wanting” became “absent.” Some literary
answers remained shallow or overstated sincerity and intent. Stable answers are
not necessarily correct answers. The transport is reliable; Gemma's linguistic
judgment is not reliable enough to treat as authority.

Optional `dictionaryAssistance: true` passes at most two bounded verbatim excerpts;
returned `dictionaryEvidence` is attached by the adapter, separate from generated
interpretation. Older saved explanations remain decodable. Dictionary evidence
helped “fell through” and “wanting” but introduced an unlocking/unlatching claim
for “opened,” and did not fix the literal cat. Assistance therefore defaults off.
Large articles, incomplete excerpts and missing modern slang remain limitations;
this is not automatic sense resolution or a sourced etymology service.

Real-document checks passed for Gutenberg's Wilde EPUB/TXT, a 13-page research PDF
and ZIPFoundation's Markdown README: every resource parsed, all 12 EPUB navigation
items resolved, native PDF selection matched canonical offsets, and dictionary
meanings, AI answers, notes, bookmarks and progress persisted. A separate process
reopened all four libraries and returned to the exact saved ranges (131 ms total).
Without AI, reading every resource took 6–295 ms per sample; saving meaning,
bookmark and progress together took 0.6–1.1 ms. The complete non-AI test command
peaked at 119 MiB RSS, including test/tooling overhead; this is not a GUI app measurement.
These samples do not establish compatibility with every publication or large-library scale.

A real mid-stream cancellation cleared selection in 0.022 ms and reached the
caller in 2.21 ms; server logs confirmed cancellation and the next explanation
completed in 2.98 s. One cold dictionary miss during generation took 492 ms;
a separate idle probe took 28 ms for that exact miss. Ordinary first-pass lookups
were usually a few milliseconds, with cached calls faster. These observations
show contention can still affect lookup latency; they do not isolate its cause.

The worker reported 7,378 MiB Metal allocations (6,956 model, 361 context, 61
compute). Final-run peak server RSS was 4.97 GiB; file mapping and unified GPU
memory mean RSS/private footprint alone understate model cost. System pressure was
mostly warning during these runs, with brief critical pressure in the baseline.
System swap grew 0.50 GiB in the final run and 2.09 GiB in the baseline; other apps
contribute, so this cannot all be attributed to the worker. This configuration is
usable for occasional explicit requests, but is not certified comfortable under
all 16 GiB workloads. All benchmark workers were stopped afterward.

The ordinary release suite passed 53 checks; four live tests are opt-in and skipped
by default. `LiveValidationTests` uses `SANDPAPER_LIVE_MODE=ai`, `documents`,
`workflow`, `restore` or `cancel`, `SANDPAPER_LIVE_OUTPUT`, and (when relevant)
`SANDPAPER_LIVE_PORT`, `SANDPAPER_LIVE_ASSETS`, `SANDPAPER_LIVE_LIBRARY`.
The JSON artifact retains asset URLs/hashes and actual outputs. No test downloads
assets or starts a model implicitly. Image-only OCR, fixed-layout EPUB, publisher
CSS fidelity, standalone web articles, document editing and worker supervision
remain outside the implemented backend. No frontend views or styling changed.
