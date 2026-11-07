# Sandpaper local model decision — 7 November 2026

**No-go for the stated standard of excellent, dependable local English explanations.** Gemma 4 12B QAT Q4_0 with the existing short paragraph prompt is the best tested fallback for contextual glosses. It improves several concrete failures, but its remaining errors and shallow literary explanations do not justify proceeding with the UI on the assumption that interpretation quality is solved. No production model or prompt migration was made.

The recommended fallback configuration is one model, one explicit explanation call, native Gemma 4 chat formatting, thinking disabled, the current `selection-explanation-3` prompt, and dictionary assistance off by default. Reject the tested adaptive prompt as a default and reject the tested native-thinking mode for this workload. A contrastive instruction sometimes improves an individual literary answer, but does not reliably repair interpretation errors. This recommendation identifies the strongest fallback; it does not qualify it as the excellent explanation engine the product needs.

The work ran on this Apple M4 Mac mini with 16 GB unified RAM, macOS 27.2, with existing Zen, Visual Studio Code and Codex processes left running. No background apps were closed to make a model fit. Only one worker ran at a time. At most one newly downloaded candidate file was retained alongside the existing Gemma 3 baseline. All new candidate weights are now deleted, all benchmark workers are stopped, and about 21 GiB is free. The retained baseline file was not deleted.

The frozen evaluation contains **28 newly authored passages, four verified literary excerpts, eight known regressions and six development cases**. The new material covers vocabulary, idioms, irony, literary wording, literal idioms, unresolved and resolved ambiguity, evidential limits, and internet English. The literary excerpts are James (1881), Conrad (1899), Wharton (1905) and Joyce (1914), verified against downloaded Gutenberg texts. Published excerpts may have appeared in training; the original passages were composed and frozen before candidate inference. New passages are independent of the old regression passages, though familiar expressions and grammatical patterns can recur. Neither answer keys nor case categories were sent to the models. Prompts were not revised against the final set.

Quality was reviewed from every recorded final answer by this agent, unblinded, against the frozen expectations. Correctness, depth, faithfulness, clarity and serious errors were scored separately. These are case-review counts on short, deliberately difficult passages, not a representative error-rate estimate or an independent human evaluation. Minor overreach can leave the selected sense correct while failing the grounded-answer column. Literary depth is partly a judgment call; the actual answers and review notes remain available.

The candidate identities, availability, specifications and templates were verified. The existing Gemma 3 baseline was reused, and its current file hash was reconfirmed after its run:

| Candidate | Verified model specification | Tested weights | Template / thinking |
| --- | --- | --- | --- |
| [Gemma 3 12B IT](https://huggingface.co/google/gemma-3-12b-it) | Dense 12B; advertised 128K context | Retained ggml-org Q4_K_M, 7.30 GB | Gemma user/model roles; instructions merged into first user turn; no native thinking toggle |
| [Qwen3.5-9B](https://huggingface.co/Qwen/Qwen3.5-9B) | 9B language model; hybrid DeltaNet/attention; advertised 262,144 context | Unsloth Q4_K_M, 5.68 GB | Explicit `enable_thinking` false/true; native template |
| [Llama 3.1 8B Instruct](https://huggingface.co/meta-llama/Llama-3.1-8B-Instruct) | Dense 8B; advertised 128K context | Bartowski Q4_K_M 4.92 GB and Q6_K 6.60 GB | Official header/EOT format with automatic BOS handling; no native thinking toggle |
| [Gemma 4 12B QAT](https://huggingface.co/google/gemma-4-12B-it-qat-q4_0-gguf) | 11.95B unified dense model; advertised 256K context; configurable thinking | Official Google QAT Q4_0, 6.98 GB | Native system/user/model and thought-channel template; embedded template exactly matched Google’s current file |

Only **4,096 context tokens** were configured and tested; advertised windows are not hardware capacity claims. All model-file SHA-256 values matched the pinned download manifests. Qwen’s embedded template differs from current upstream in a tool-call loop and its default thinking choice; neither changes these text-only requests because both thinking states are explicitly supplied. Llama Q4 and Q6 have identical template hashes. [Exact files, revisions and hashes](model-evaluation/models.json), [source verification](model-evaluation/sources.json) and [prompt hashes](model-evaluation/prompt-manifest.json) are retained.

Every main comparison used llama.cpp b12110 / `cd959bae9`, Metal, one slot, 4K context, 512/128 batch/ubatch, q8_0 KV, flash attention, temperature 0.2 and seed 42. The same schema and request harness were used across models, with only the model-required chat-role treatment differing. The production v3 system instructions were compared with one fixed adaptive-depth variant. This is a common inference harness, not an end-to-end Swift reader or UI benchmark. Model comparisons hold prompting constant within each table row; comparisons across prompt rows measure a separate prompt change.

**Scoring erratum:** final QA found that case `a3` inserts **the** before “visiting relatives,” compromising the classic bare-form ambiguity that the key intended. The ordinary visitors reading cannot fairly be marked wrong. Determiner-plus-verbal-ing constructions have additional constraints and attested exceptions ([Grimm and McNally](https://www.sas.rochester.edu/lin/sgrimm/publications/GrimmMcNallyWCCFL2015.pdf)); this was not a clean binary test. I withdrew its ratings from every quality comparison instead of changing the passage or rerunning models. The original key, outputs and superseded ratings remain in the [erratum audit](model-evaluation/errata.json). Thus 31 main cases, eight new difficult cases and 15 paired-quantization cases are scored below. Performance measurements retain the original complete sequences.

The corrected main quality results are:

| Tested configuration | Prompt | Correct sense /31 | Correct, grounded, clear /31 | Serious errors /31 |
| --- | --- | ---: | ---: | ---: |
| Gemma 3 12B Q4_K_M | Current short | 24 | 22 | 3 |
| Gemma 3 12B Q4_K_M | Adaptive depth | 23 | 13 | 6 |
| Qwen3.5-9B Q4_K_M | Current short | 23 | 20 | 2 |
| Qwen3.5-9B Q4_K_M | Adaptive depth | 22 | 16 | 5 |
| Llama 3.1 8B Q6_K | Current short | 23 | 21 | 3 |
| Llama 3.1 8B Q6_K | Adaptive depth | 23 | 19 | 4 |
| Gemma 4 12B QAT Q4_0 | Current short | 26 | 24 | 1 |
| Gemma 4 12B QAT Q4_0 | Adaptive depth | 23 | 19 | 3 |

Gemma 4’s short prompt led this test, but **26/31 correct selected senses, one serious error and limited literary analysis fall short of the frozen gate**: at least 30/32, no serious new errors, calibrated ambiguity, and useful literary depth on every literary case. Even awarding full credit for the excluded case would give Gemma 4 only 27/32, below the original gate. The small differences between the other three models do not establish a meaningful overall quality ranking. Adding room for six sentences did not reliably produce adaptive insight; it often produced unsupported detail or an overly generic gloss.

Known regressions were counted separately:

| Tested configuration | Current short, correct /8 | Adaptive, correct /8 |
| --- | ---: | ---: |
| Gemma 3 12B Q4_K_M | 3 | 3 |
| Qwen3.5-9B Q4_K_M | 5 | 5 |
| Llama 3.1 8B Q6_K | 3 | 3 |
| Gemma 4 12B QAT Q4_0 | 5 | 6 |

Concrete improvements and remaining failures explain the recommendation better than the counts alone:

- **Literal cat:** Gemma 4 and Qwen explained a physical cat leaving a bag and running under a sofa. Gemma 3 still called it secret revelation under both prompts. Llama also retained the secret reading. This is a controlled model difference, not just a comparison with an old historical output.
- **Wanting:** Gemma 4 and Llama explained deficiency or insufficiency. Gemma 3 and Qwen repeatedly asserted that the explanation was absent or nonexistent. Dictionary evidence did not reliably repair that assertion.
- **Modern internet English:** Gemma 4 correctly interpreted “I am deceased” under a funny video as laughter hyperbole, and recognized the predetermined personal-growth framing of “canon event.” Gemma 3’s adaptive “a choice” answer invented a postal service promoting an interface; the source was a critical social-media post. Qwen and Llama correctly recognized the criticism in that case.
- **Hunters:** Every model’s fast configurations missed the unresolved agent/patient reading of “the shooting of the hunters.” Qwen and Gemma 4 still fixed the hunters as victims under native thinking. This is a substantive compositional-English failure. The visiting-relatives case is excluded, as explained above; earlier claims that it demonstrated a model failure are withdrawn.
- **Telescope and duck:** All fast configurations confidently chose one reading of the unresolved telescope and duck regressions. Qwen thinking recovered the telescope alternatives, but still rejected the lowering-head reading of “her duck” and added unsupported claims about the bird. Gemma 4’s corresponding thinking regressions were not completed before the session limit.
- **Faithfulness:** Gemma 3’s adaptive bucket explanation invented hurried work and a lack of reverence after a funeral. Llama’s adaptive figures explanation dropped the allegation qualifier and said the numbers were altered. Giving a model more space increased the opportunities for this kind of overreach.
- **Literary depth:** Gemma 4’s ordinary Conrad answer offered “aesthetically or morally unappealing”; the adaptive answer simply repeated “is not a pretty thing.” Neither explained the force of the understatement adequately. A useful exception was the contrastive snowflake answer: flakes “catch or miss the lamplight,” producing flicker and a shifting light/shadow texture in sleepy perception. That was grounded, richer analysis in about 12 seconds, but the same strategy did not generalize across the difficult cases.

The reasoning comparison uses the **same eight scorable new difficult cases** for every row below; the flawed visiting-relatives case and three additional known regressions are excluded from this table. “Contrastive” means adding one instruction to compare plausible readings against textual evidence before giving the final answer. Native thinking changes the thinking control and token allowance while preserving the adaptive prompt. No second model call or separate classifier is proposed for ordinary explanations.

| Tested configuration | Adaptive fast, correct /8 | Contrastive fast, correct /8 | Native thinking, correct /8 | Native first / complete |
| --- | ---: | ---: | ---: | ---: |
| Gemma 3 12B Q4_K_M | 5 | 3 | Not supported | — |
| Qwen3.5-9B Q4_K_M | 5 | 4 | 5 | 32.68 / 34.97 s |
| Llama 3.1 8B Q6_K | 5 | 6 | Not supported | — |
| Gemma 4 12B QAT Q4_0 | 2 | 4 | 3 | 45.27 / 47.07 s |

Qwen’s native thinking fixed some individual errors, including the telescope regression, but did not improve the count of correct new difficult-case senses over adaptive fast mode. Gemma 4 thinking improved adaptive fast mode from 2/8 to 3/8, but remained below the current short prompt’s 4/8. It often returned only generic labels: after 47 seconds, the brave-selection answer was only “Jo’s verbal reaction to Ren’s act of contradicting the chair.” Its hunters answer remained wrong despite completing with 390 total completion tokens, so that failure was not caused by exhausting the 512-token reasoning allowance. The tested thinking configurations do not justify their delay. Longer, untested reasoning budgets are not ruled out in principle; they were not pursued.

Native thinking was capped at 512 reasoning tokens and 1,024 total tokens, with a 90-second request limit. The first Qwen diagnostic used an ignored `reasoning_budget` key and consumed 1,024 tokens without a final answer in 61.17 seconds. That tail was stopped. The completed 80 fast main answers were retained, and only the scheduled extras were resumed with the source-verified [`reasoning_budget_tokens`](https://github.com/ggml-org/llama.cpp/blob/cd959bae9/tools/server/server-common.cpp) control. This correction changed no passages, prompts or sampling settings. The primary thinking results above use the corrected run. The small dictionary helper was also aligned with the reader’s existing lemma/excerpt behavior before any dictionary ablation; its 0.6-second compilation occurred during the first Qwen run. No backend build or test suite ran during model measurements.

The preset 15-minute Gemma 4 session cap triggered after both complete main-prompt runs and all nine planned new difficult thinking cases (eight retained after the scoring audit). Shutdown completed at 15 minutes 30 seconds. One cat-regression thinking request was cancelled without a final answer; the remaining two contrastive regressions, other thinking regressions and seven dictionary/control requests were not run. The cancelled request is retained but excluded from semantic comparisons. No additional round was started to improve the result.

Loaded-worker latency medians are below. “First” means at least 12 decoded explanation characters, excluding JSON punctuation and thought output; it is measured from the streaming completion POST. Startup, template/token preflight and future GUI rendering are excluded.

| Tested configuration | Current short: first / complete | Adaptive: first / complete | Same-prompt short: first / complete |
| --- | ---: | ---: | ---: |
| Gemma 3 12B Q4_K_M | 4.34 / 5.64 s | 3.40 / 9.51 s | 1.56 / 3.67 s |
| Qwen3.5-9B Q4_K_M | 2.95 / 4.11 s | 2.00 / 4.78 s | 0.67 / 2.32 s |
| Llama 3.1 8B Q6_K | 2.34 / 3.12 s | 1.71 / 3.45 s | 0.63 / 1.64 s |
| Gemma 4 12B QAT Q4_0 | 4.44 / 5.87 s | 3.23 / 6.15 s | 1.33 / 4.00 s |

These latency statistics retain all 32 original main passages, including the quality-excluded case. Main prompts were interleaved to reduce order effects, which also mixes prefix-cache states. The final column is a post-hoc subset of existing requests immediately preceded by the same prompt format: 15 cases per short configuration, not an extra benchmark. It better illustrates repeated stable-prompt use, but is not a latency guarantee. The model runs were sequential under changing OS/cache conditions. Observed model startup ranged from about 1 to 10.6 seconds; the first smoke loads were Qwen 4.05 s, Llama Q4 1.02 s, Llama Q6 7.60 s, Gemma 4 9.10 s, and Gemma 3’s measured main load 10.60 s. File and shader caches were not controlled for a cold-start ranking.

The isolated quantization comparison used the same 16 cases in the same single-prompt sequence, separately from Llama Q6’s interleaved main run:

| Same 16-case sequence, 15 scored | Correct senses /15 | Serious errors /15 | First / complete median | Model file |
| --- | ---: | ---: | ---: | ---: |
| Llama Q4_K_M | 10 | 3 | 0.54 / 1.38 s | 4.92 GB |
| Llama Q6_K | 11 | 3 | 0.63 / 1.79 s | 6.60 GB |

Q6 improved the snowflake answer from “describing the color” to an actual explanation of reflected light and contrast. After excluding the flawed case, it retained the same three serious failures among the 15 scorable cases. This is a small, concrete benefit for 1.67 GB more weights and longer generation; it does not make Llama meet the advanced-reader standard. Q8 and higher-precision Qwen configurations were not tested, and no quality claim is made for them.

Memory and responsiveness observations were (RSS peaks cover all sessions for that candidate; probe p95 uses its main run, or the Q4 subset):

| Tested configuration | Reported Metal buffers | Peak server RSS | Pressure observed | Peak system swap growth | Main probe p95 |
| --- | ---: | ---: | --- | ---: | ---: |
| Gemma 3 12B Q4_K_M | 7,379 MiB | 5.60 GiB | normal + warning | 1.11 GiB | 51 ms |
| Qwen3.5-9B Q4_K_M | 5,031 MiB | 5.72 GiB | normal | 0.00 GiB | 50 ms |
| Llama 3.1 8B Q4_K_M, 16-case run | 4,724 MiB | 5.03 GiB | normal | 0.00 GiB | 50 ms |
| Llama 3.1 8B Q6_K | 6,193 MiB | 5.90 GiB | normal | 0.00 GiB | 50 ms |
| Gemma 4 12B QAT Q4_0 | 6,960 MiB | 5.46 GiB | normal + warning | 0.03 GiB | 51 ms |

Metal figures sum the actual reported mapped model, KV/recurrent, rotation and compute buffers; repeated equal-sized per-layer Gemma 4 buffers were preserved, not deduplicated. Metal buffers, RSS and private footprint overlap on unified memory and **must not be added**. RSS alone understates some GPU/file-mapped costs. No sustained critical pressure occurred. Gemma 3 and Gemma 4 were predominantly at warning pressure; Qwen and both Llama quantizations stayed normal in their measured sessions. Gemma 4’s low incremental swap growth is not proof of greater headroom: it started with about 3.52 GiB of system swap already in use, versus 2.77 GiB before Gemma 3. Run order, prior compression and other apps matter.

The responsiveness probe repeatedly launched a small native macOS dictionary lookup during inference. Its p95 includes process startup and was about 50–60 ms in the main/paired measurements; every probe in those measurements completed. During the initial Qwen development smoke check, nine probes failed because the helper binary was not ready; those bootstrap records are retained and excluded from this comparison. This measures a small concurrent native operation, not browser interaction, typing latency or future UI frame pacing. Raw pressure, swap, compressor, RSS and probe samples are retained in compressed telemetry alongside command lines and background-process snapshots.

Dictionary assistance was evaluated on the same fixed lexical/literal cases for Gemma 3, Qwen and Llama Q6. There were five actual retrieved-evidence cases and one phrase miss per model, plus a development control. Evidence mirrored the existing bounded macOS lookup/lemma/excerpt behavior and included multiple possible senses rather than a handpicked answer. The phrase “economical with the truth” returned no article, so its assisted request was a no-evidence control. Dictionary assistance helped some definitions and kept the bucket literal, but did not fix Gemma 3/Llama’s cat reading or consistently resolve wanting. Gemma 3 also reversed a dictionary usage-history detail and added an irrelevant origin account to sanguine. Keep assistance optional and default-off. Gemma 4’s ablation was unmeasured because of the session cap; no benefit is claimed for it. Shared artifacts retain evidence hashes and lengths, not full dictionary articles.

Output validity was not used as a quality grade. Two Gemma 3 contrastive answers contained only “The phrase”; one Gemma 4 adaptive answer appended escaped `"notes": [` syntax inside the meaning. These were valid JSON but unusable or corrupted explanations. The annotations distinguish output-format/empty-answer defects, serious semantic errors, and administrative cancellation. Whether constrained decoding contributed to these format defects was not isolated, and they are not presented as proof of a model’s intrinsic English ability.

The investigation ended with **467 recorded answers/attempts** across the fixed cases and configurations, including development checks and two incomplete recorded attempts; 16 preliminary ratings belonging to the flawed case are withdrawn, and the administrative cancellation is annotated separately and excluded from model-quality comparisons. One additional Qwen request was interrupted during the control correction before a result row was written. This is not 467 independent passages. There was one fixed prompt comparison, one fixed contrast instruction, the native-mode checks, and the paired quantization control; there was no search through prompts against the final set.

The existing release suite passed **57 reported tests in 10 suites**. Its opt-in live-work bodies were not enabled; the actual model work was performed by the separate explicit benchmark harness. Swift production sources, UI, automatic highlighting and backend architecture were not changed. The frozen suite/prompt hashes still match, every recorded attempt has a review or explicit scoring exclusion, new GGUF files are removed, and no llama-server process remains.

Reproduce or inspect the work through the [protocol and harness](../tools/model_eval/README.md), [frozen suite](model-evaluation/suite.json), [aggregate metrics](model-evaluation/summary.json), [review annotations](model-evaluation/reviews), [Gemma 4 actual answers](model-evaluation/gemma4-qat.json), and [environment/test verification](model-evaluation/environment-and-verification.json). The tested approaches can supply useful local glosses and occasional richer analysis. They cannot currently deliver the consistently accurate, insightful explanations required by the stated product goal.
