# Local inference and discovery evaluation

The Qwen3-8B Q4_K_M baseline was run on the 16 GB M4 Mac mini on 6 November 2026.
See the [measured results](../evaluations/qwen3-8b-m4-2026-11-06/summary.md).
The subsequent [Gemma 3 12B comparison](../evaluations/gemma3-12b-vs-qwen3-m4-2026-11-06/summary.md)
records the same cases and focused repeats; it did not justify replacing Qwen.
Local execution works, but linguistic accuracy and automatic discovery remain
insufficiently reliable for a finished reader. Automated HTTP tests still use a
loopback fixture; the evaluation reports contain actual model generations.

## Resources

For the initial baseline, manually download
[Qwen3-8B-Q4_K_M.gguf](https://huggingface.co/Qwen/Qwen3-8B-GGUF/blob/main/Qwen3-8B-Q4_K_M.gguf)
from the official Qwen repository (about 5.03 GB). Keep it outside this checkout.
This is an evaluation baseline, not a claim that it is the best model for the app.

Install a native Apple Silicon `llama-server`. The integration targets the
[llama.cpp v0.9.0 server API](https://github.com/ggml-org/llama.cpp/blob/v0.9.0/tools/server/README.md).
Its release points to the b12110 binary build; use the macOS arm64 build from
[the official release](https://github.com/ggml-org/llama.cpp/releases/tag/b12110).
Keep its accompanying libraries alongside the executable. Alternatively, build
the pinned v0.9.0 source. Nothing in Sandpaper installs or downloads these files.

For the Gemma comparison, use `gemma-3-12b-it-Q4_K_M.gguf` from
[ggml-org's original IT quantization](https://huggingface.co/ggml-org/gemma-3-12b-it-GGUF/tree/ec0cbabd8dbff316f659876a50202295c3c4a314),
not the separate QAT variant. The file is 7,300,574,976 bytes; its SHA-256 is
`7bb69bff3f48a7b642355d64a90e481182a7794707b3133890646b1efa778ff5`.
Use the same server command below with that model path, omitting
`--chat-template-kwargs '{"enable_thinking":false}'`, and pass `--chat-format gemma3`
to the evaluation runner. In backend code, use `LlamaServerConfiguration(chatFormat: .gemma3)`.
Gemma's instructions are merged into its initial user turn; the embedded GGUF
template supplies the native delimiters. Both token budgeting and generation use
the same messages. Qwen's default configuration remains unchanged.

Lexical datasets are not required to run this baseline. Their import and lookup
are a subsequent increment. Until they exist, explanations carry model-interpretation
provenance and the adapter rejects etymology sections.

## Start one local worker

Replace the two paths below with your installed executable and model file:

```sh
/path/to/llama-server \
  --model /path/to/Qwen3-8B-Q4_K_M.gguf \
  --alias sandpaper-local \
  --host 127.0.0.1 --port 8087 \
  --ctx-size 4096 --parallel 1 \
  --n-gpu-layers 99 --batch-size 512 --ubatch-size 128 \
  --cache-type-k q8_0 --cache-type-v q8_0 --flash-attn on \
  --cache-ram 0 --no-context-shift --no-webui \
  --jinja --chat-template-kwargs '{"enable_thinking":false}'
```

These are the settings used in the retained evaluation. The Q8 KV buffer measured
306 MiB. They do not guarantee comfortable memory pressure with other apps open,
and a 4096-token context may require shorter passages. `--cache-ram 0` avoids the server's large additional
prompt-cache allowance. One slot prevents concurrent model generations. The app
client can cancel its request to release work. Server process supervision and
hard recovery from an unresponsive worker are not implemented yet; for now the
server is started and stopped manually.

Inference uses only `127.0.0.1`, bypasses configured proxies, refuses HTTP
redirects, and has no cloud fallback. There is no remote URL setting. The server
must report the expected alias and one slot. Keep it in single-model mode;
model-router auto-loading is outside this integration.

## Run the evaluation

From the repository root:

```sh
swift run sandpaper-evaluate --output /tmp/sandpaper-evaluation.json
```

Use a release build for timings and include the additional literary, contemporary,
ambiguity, and page-length cases:

```sh
swift run -c release sandpaper-evaluate --extended --output /tmp/sandpaper-evaluation.json
# Optional focused repeat:
swift run -c release sandpaper-evaluate --case known-word-new-sense --repeat 3 --output /tmp/sandpaper-repeat.json
```

The six cases include the three supplied passages, a known literal expression
used figuratively, an ordinary sentence, and a known idiom. The report contains
candidate assessments, suppression decisions, real explanations, token usage,
and elapsed time including the engine's availability/template/tokenizer checks.
`firstContentSeconds` measures first JSON content. The runner's `firstMeaningSeconds`
measures the first nonempty readable preview, not the completed answer. Its wall-time
fields include the coordinator's availability checks; engine metrics do not. UI
rendering delay is not measured. Completed cases are checkpointed to the requested
output path. The runtime model identity hashes alias/path, not weight contents;
retain the model filename and checksum when comparing different weight files.

Inspect the responses against each case's `reviewFocus`. This runner does not
pretend to assign a linguistic quality score. It records physical RAM capacity,
not peak model memory or swap. Check memory pressure with the browser and VS Code
open during real reading trials. An error in any case produces exit code 1 while
preserving the partial report. Setup/argument failures produce exit code 2.

## Backend use

```swift
let configuration = try LlamaServerConfiguration()
let engine = LlamaLocalEngine(configuration: configuration)
let analysis = AnalysisCoordinator(engine: engine)
let report = try await analysis.discover(request)
// Render only report.highlights. report.assessments also includes suppression reasons.
```

`DiscoveryAssessment` separates meaning, interpretation confidence, learning value,
learning signals, and a possible match to a supplied sense memory. Ordinal ratings
are uncalibrated model judgments. `DiscoveryPolicy` separately decides highlight
eligibility, applies familiarity/repetition rules, and resolves overlapping spans.
There is no minimum selection count and no uncommon-word threshold.

Pass relevant `KnownSense` records with meaning descriptions, not just opaque IDs.
`DocumentLibrary.discoveryMemories(for:)` retrieves matching stored expressions
under an input budget. Automated lemma/phrase retrieval and vocabulary-level
estimation are still pending. A clear same-expression/same-sense match may
establish familiarity; uncertainty or absent meaning descriptions leave familiarity
unknown. Invented memory IDs are rejected. Include explicitly recorded prior-explanation keys in
`previouslyExplainedSenseKeys` to suppress repeat senses independently of familiarity.
Automatic recording of unsaved explanations is not implemented yet.

Freshly saved senses need an app-assigned key (for example a UUID) or a verified
lexical sense ID. The model may only return memory keys it was given. Do not use
newly generated prose as a supposedly stable lexical identifier.

Oversized prompts fail explicitly instead of silently dropping context. Generated
quotes must match the source exactly; the model supplies a quote occurrence, not
an invented UTF-16 offset. Streaming meaning text is provisional until the final
structured response validates; discard it on failure. Truncation and incomplete
streams are errors, not successful explanations. Superseded UI tasks must still
ignore cancellation. Do not save an explanation until the final call succeeds.

Past-context retrieval, document-type classification, full response caching,
follow-up conversations, and lexical fact grounding are subsequent increments.
