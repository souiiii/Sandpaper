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
