# Gemma 3 12B IT versus Qwen3-8B — 6 November 2026

**Recommendation: do not replace Qwen with Gemma for Sandpaper.** Gemma runs locally on this M4, but is slower and delivers fewer required learning points. Neither configuration is reliable enough for trusted automatic discovery. Qwen with thinking disabled remains the preferable experimental baseline; its weights remain deleted as requested.

The actual Gemma Q4_K_M file passed SHA-256 verification. This is ggml-org's original Google instruction-tuned model, not QAT. The release Swift runner used llama.cpp b12110, Metal (49/49 layers), 4,096-token context, Q8 K/V cache, flash attention, one slot, temperature 0.2, 45-second timeout, and unchanged `reading-analysis-3` instructions. Gemma's instructions were merged into its first user turn; its embedded template supplied native delimiters. JSON schema enforcement and source/memory validation remained enabled.

Gemma completed the same 16 cases, then two additional runs of seven controls/failure cases: **30 paired evaluations / 60 attempted generations**. Qwen results below are the retained historical 16-case run, with existing three-run controls. Background applications, filesystem caches and system memory state were not controlled across models. No explicit sampling seed was set. Qwen reasoning was not tested because its weights were removed; they were not downloaded again.

| Main 16-case measurement | Qwen3-8B, thinking off | Gemma 3 12B IT |
|---|---:|---:|
| Median first readable preview | 2.61 s | 4.15 s |
| Median complete explanation | 5.64 s | 8.32 s |
| Complete explanation p90 / maximum | 9.36 / 10.17 s | 10.19 / 11.50 s |
| Median discovery completion or failure | 10.99 s | 14.34 s |
| Valid discovery / explanation | 15/16 / 16/16 | 11/16 / 16/16 |
| Median decoding speed | 19.90 tokens/s | 12.64 tokens/s |
| Useful eligible highlights / all eligible | 10/13 (77%) | 9/9 (100%) |
| Required learning points delivered | 10/20 (50%) | 7/20 (35%) |
| Manual explanation judgments: sound / partial / incorrect | 10 / 4 / 2 | 8 / 6 / 2 |

Quality judgments follow a [rubric frozen before Gemma generation](rubric.json), not an automated or calibrated benchmark. Precision is conditional on delivered highlights: failed generations deliver nothing and do not enter its denominator. Their missed learning points still count against recall. Gemma's nine accepted highlights include two useful related/ambiguity observations outside the required targets; this small, selective sample does not establish superior general precision. Signal labels and learning rationales sometimes remain inaccurate even when a core highlight is useful. Whole-sentence overlap earns at most one primary target. See the per-case [Qwen](qwen-review.json) and [Gemma](gemma-review.json) judgments.

Actual outputs illustrate the trade-offs:

- **Idioms:** Gemma highlighted only “fell through”; Qwen highlighted only “back at square one.” Gemma repeated its omission in all three observations. Neither covered both independent idioms.
- **Literary understatement:** Gemma selected “manners were rather wanting” and explained “His behavior was noticeably deficient in the qualities expected of a person of his social standing.” It missed the wealth expression. Qwen's discovery focused on “considerable means,” with an overbroad sentence anchor.
- **Known spelling, new sense:** Gemma kept figurative “fig leaf” eligible in 3/3 observations. Its meaning, “a shallow and inadequate attempt to conceal a lack of concern,” was useful. All three explanations nevertheless added unsourced biblical-origin material under `relatedExpression`, against the instructions. Qwen's retained responses avoided that detail.
- **Ambiguity:** Gemma's discovery recognized multiple interpretations in two observations and failed validation in one. All three explanations conflated the readings: “the instrument the man was holding or using; it specifies how she observed him.” Qwen also chose an unsupported instrument reading.
- **Contemporary English:** Gemma correctly explained sarcastic “Love that for us,” but discovery failed validation. It missed “sealioning” in 3/3 observations, selecting “just asking questions” instead. One repeat asserted that the speaker “feigned neutrality while attempting to derail a discussion”; the passage establishes an accusation, not intent.
- **Page coverage and restraint:** mixed-page discovery failed in 3/3 Gemma observations, missing all six required opportunities. Qwen delivered only “keep his powder dry.” Gemma suppressed ordinary-prose highlights in 3/3, but every window explanation invented unlocking. The known-idiom control failed discovery validation in 3/3, so correct personalized suppression was not demonstrated.

A [separate reconstructed raw diagnostic](raw-diagnostic.json) returned valid JSON with `quote: "fall through"` for the passage “The agreement fell through.” Exact-source validation correctly rejects that dictionary-form substitution. This diagnostic is excluded from benchmark measurements and does not establish the cause of every original failure. No fuzzy quote repair or weakened validation was introduced.

Gemma's main run and repeats stayed at **normal system memory pressure**, with **zero additional system swap-outs**. llama.cpp reported about **7.21 GiB of GPU buffers**, versus Qwen's 4.69 GiB, plus respective host model mappings of 787.5 and about 342 MiB. These are runtime allocations/mappings, not a single measurement of total application RAM. Gemma's observed peak RSS was 7.00 GiB in the main run and 7.90 GiB in repeats; private footprint was 1.27 / 1.15 GiB and excludes file-backed weights. Qwen's earlier main run included warning pressure; its later repeats were normal with zero additional swap-outs. Different background memory states prevent attributing that difference to the models. Reading smoothness was not measured.

The focused engineering change is the Gemma chat-format option, shared by template budgeting and generation, plus explicit evaluation reporting of format/timeout. All 50 backend tests pass. No frontend or unrelated architecture changed. The evidence supports keeping Gemma available for experiments, not making it the default or treating more parameters as a solution to discovery coverage, uncertainty, or lexical grounding.

Evidence: [measurements and asset identity](measurements.json), [actual 16-case outputs](gemma3-expanded-lean.json), [actual repeat outputs](gemma3-repeat-checks.json), [repeat review](repeat-review.json), and [historical Qwen evidence](../qwen3-8b-m4-2026-11-06/summary.md). Full server logs and half-second native memory samples remain in `/private/tmp/sandpaper-ai-validation/`. All evaluation-owned workers were stopped.
