# Qwen3-8B local evaluation — 6 November 2026

**Decision: local execution works; this baseline is not reliable enough for automatic discovery or authoritative linguistic explanations.** Keep it as an experimental baseline while resolving the quality problems before expanding features.

Observed on the actual Mac mini: Apple M4, 10 CPU cores, 16 GiB unified memory, macOS 27.2. Zen, VS Code and Codex remained open. The official 5,027,783,488-byte Q4_K_M file and llama.cpp b12110 archive passed their published SHA-256 checks. Metal offloaded all 37/37 layers. Thinking was disabled, matching the existing adapter; reasoning-enabled quality was not tested.

The suite contains the six existing cases plus ten additional cases: short verified Wilde (1895), Woolf (1925), and Orwell (1946) excerpts, explicitly constructed contemporary/slang/ambiguity cases, and 220-word literary and 198-word ordinary pages. Five sessions produced 63 paired evaluations / 126 attempted generations, including three repeats of three controls. This is a small diagnostic suite with human review, not a calibrated accuracy benchmark.

The same 16 passages were compared using the same 4,096-token context, Q8 K/V cache, Metal flash attention, one slot, temperature 0.2 and release runner. Sampling was not explicitly seeded. The retained revision is `reading-analysis-3`.

| Observed metric | Original prompts | Retained prompts |
|---|---:|---:|
| Median first nonempty answer preview | 1.78 s | 2.61 s |
| Median complete explanation | 7.97 s | 5.64 s |
| Explanation p90 / maximum | 11.80 / 14.44 s | 9.36 / 10.17 s |
| Median discovery completion or failure | 12.89 s | 10.99 s |
| Validated discovery / explanation results | 15/16 / 16/16 | 15/16 / 16/16 |

Wall times include the adapter/coordinator checks and actual generation, but not GUI rendering. First preview is not a completed or validated answer. The ordinary-page control timed out after 45.49 s originally; the retained revision failed output validation after 27.44 s. Successful serialization does not establish linguistic correctness. Retained-run decoding measured a median 19.90 tokens/s. First model startup took 12.18 s; subsequent starts took 3.60–6.13 s, under different filesystem-cache and background-memory conditions.

Memory observations:

- The initial 8,192-token F16-cache run began at warning pressure, briefly reached critical pressure during startup, and stayed at warning during inference. System swap usage rose from 2.20 to a 5.48 GiB peak; cumulative swap-outs increased 3.95 GiB.
- The lean configuration's actual KV buffer was 306 MiB. llama.cpp reported 4,807 MiB of GPU buffers and about 342 MiB on the host: roughly 5.0 GiB of reported allocations. Private process footprint was about 0.47 GiB and excludes mapped weights; it is not total model memory.
- Warning pressure still occurred in the retained 16-case run. The later warm repeat session stayed at normal pressure and recorded zero additional swap-outs. Existing swap, application activity and filesystem caching varied between sessions, so global swap changes cannot be attributed solely to the model or used to claim a controlled RAM improvement. Frame smoothness and perceived reading comfort were not measured.

Concrete linguistic findings:

- **Useful successes:** contextual explanations recognized the failed agreement, deficient manners, withheld endorsement, Woolf's demanding-work idiom, and sarcastic contemporary approval. The core meaning was often better than the optional explanatory notes.
- **A measured improvement:** the original model wrongly matched figurative “fig leaf” to the known literal-leaf sense and invented a definition involving fig skin. The retained prompts kept the figurative sense eligible in all 3 repeat checks and removed that invented literal detail. Literal and figurative meanings are distinct in [Cambridge's entry](https://dictionary.cambridge.org/dictionary/english/fig-leaf).
- **Personalization remains incomplete:** the known “fall through” sense was suppressed in 3/3 repeats, but ordinary “put the book on the table” was unnecessarily highlighted in 1/3. Model-assigned learning value is inconsistent even with a fluent-reader instruction.
- **Discovery misses:** it repeatedly omitted “fell through” from the two-idiom passage. The mixed literary page yielded only “keep his powder dry,” missing independent opportunities such as “show her hand,” “studied indifference,” and “without turning a hair.” Many returned spans were whole sentences. No minimum quota was introduced to conceal this weakness.
- **Idiom precision remains weak:** explanations framed keeping one's powder dry mainly as neutrality/reserve rather than clearly retaining readiness for later action. That is a misleadingly narrow gloss, even though the context involves strategic restraint. Compare [Cambridge's definition](https://dictionary.cambridge.org/dictionary/english/keep-powder-dry).
- **Uncertainty is mishandled:** the telescope sentence was given the definite instrument reading, ignoring that the man could have the telescope. The slang case also confused who was being accused and sometimes asserted bad-faith intent beyond the supplied evidence. This is not trustworthy implied-meaning analysis.

Retained changes are limited to fluent-reader calibration, sense-match contrast examples, concise explanations, and evaluation instrumentation (additional cases, repeat selection, wall/preview timing and checkpointing). A source-first output experiment improved some spans but increased validation failures to 3/16 and was reverted. All 49 backend regression tests pass; those tests verify software behavior, not language quality. No frontend styling or unrelated functionality changed.

The next quality decision should address semantic reliability and lexical grounding, rather than hide errors behind a higher highlight threshold. No claims about etymology, full-book context, personalized level estimation, or reasoning-enabled inference are established by these runs.

Evidence: [measurements and verified asset identities](measurements.json), [actual responses and fixture texts](responses.json). Response anchors retain exact UTF-16 source ranges; redundant quote/context strings are omitted from the archive. Full unmodified reports, memory samples, logs, native sampler and session script remain under `/private/tmp/sandpaper-ai-validation/`. The verified runtime and weights are there too; no manual installation was needed. Owned workers were stopped after each session.
