# Local explanation evaluation

This directory is a manual, opt-in experiment, outside the reader backend. It never downloads a model. It requires the existing macOS arm64 llama.cpp b12110 worker and a verified GGUF in temporary storage. Run outside the filesystem sandbox to obtain real Metal/process/memory/dictionary measurements.

Read [PROTOCOL.md](PROTOCOL.md) before running. The frozen suite and prompt hashes live in [docs/model-evaluation](../../docs/model-evaluation). `freeze_suite.py` documents how the suite was composed; do not regenerate or edit it after inspecting final responses.

The [scoring erratum](../../docs/model-evaluation/errata.json) excludes a3 from quality comparisons because its wording compromised the intended ambiguity. Original inputs, outputs and superseded ratings are retained. `review.py` and `export.py` preserve this exclusion; timing/resource records still cover the original sequences.

Compile the small native measurement helpers:

```sh
mkdir -p /private/tmp/sandpaper-model-eval /private/tmp/sandpaper-ai-validation
clang tools/model_eval/memory-sample.c -o /private/tmp/sandpaper-ai-validation/memory-sample
swiftc -module-cache-path /private/tmp/sandpaper-model-eval/swift-module-cache tools/model_eval/dictionary.swift -o /private/tmp/sandpaper-model-eval/dictionary
```

Example explicit run (unique name required):

```sh
python3 tools/model_eval/run.py --model /path/to/verified.gguf --name qwen-q4 --thinking
```

Use `--gemma3` only for Gemma 3, `--thinking` only for architectures with native thinking, `--quant-subset` for the Llama quantization comparison, and `--smoke` for development cases only. Keep one worker and one temporary candidate file. Every server is stopped in `finally`, including failed runs. An existing worker causes refusal rather than a second model load.

`results.jsonl` retains actual final answers, completion status, timings, prompt hashes and reasoning length/hash. It excludes reasoning text. Local raw dictionary excerpts are lexical candidates, never a contextual answer key. Shared artifacts omit dictionary article text and retain hashes/lengths. `server.log` includes the actual architecture and buffer allocations. `summarize.py` reports telemetry and latency only; it does not judge linguistic quality.

The first-readable clock starts immediately before the streaming completion HTTP request and waits for at least 12 decoded meaning characters. It excludes preflight template/token counting and model startup. JSON punctuation and native thought output do not count. Timings include the small concurrent dictionary probe workload, but no Swift build or test suite is run during measurement. Model runs are sequential under real background apps, not a laboratory-isolated speed ranking.
