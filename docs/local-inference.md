# Local inference and discovery evaluation

The adapter and policy are implemented. Real linguistic quality and M4 resource
usage still require evaluation with installed weights. The automated HTTP tests
use a loopback fixture, not a real language model.

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
  --ctx-size 8192 --parallel 1 \
  --n-gpu-layers 99 --batch-size 512 --ubatch-size 128 \
  --cache-ram 0 --no-context-shift --no-webui \
  --jinja --chat-template-kwargs '{"enable_thinking":false}'
```

The context and batch sizes are conservative starting settings, not measured
performance guarantees. `--cache-ram 0` avoids the server's large additional
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

The six cases include the three supplied passages, a known literal expression
used figuratively, an ordinary sentence, and a known idiom. The report contains
candidate assessments, suppression decisions, real explanations, token usage,
and elapsed time including the engine's availability/template/tokenizer checks.
`firstContentSeconds` measures first JSON content, not necessarily the first
readable meaning. The coordinator's separate availability check and UI delay are
not included. The runtime model identity hashes alias/path, not weight contents;
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
