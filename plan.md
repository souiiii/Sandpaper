Required functionality

1. Document management and reading

Support importing and reading PDF, EPUB, TXT, and Markdown documents initially. Design extensible format adapters for future DOCX, HTML, and other formats.

Provide a polished document library, efficient navigation, full-text search where supported, bookmarks, reading progress, and persistent reading preferences.

Reopening a document should restore the user's reading position and relevant interface state.

Handle large documents without unnecessarily loading, parsing, rendering, or analyzing all pages simultaneously.

2. Intelligent text selection

Selecting a word, phrase, sentence, or clause should provide immediate access to an AI-powered explanation.

The explanation interface must support two interchangeable modes:

A floating dialog positioned appropriately near the selected text.

A docked side panel that preserves the reading workspace.

Switching modes must preserve the selection, generated explanation, scroll position, and other relevant state.

The analysis toolkit should support:

Dictionary definitions.

Meaning in the selected context.

Implied or figurative meaning.

Tone, register, connotation, and rhetorical purpose.

Etymology where verifiable.

Natural usage examples and collocations.

Synonyms, antonyms, and subtle semantic distinctions.

Practical vocabulary relevance.

User notes, saving, regeneration, and further questions.

Use structured AI responses. Combine the language model with local lexical resources where appropriate.

Distinguish verifiable dictionary facts from model-generated interpretation. Never fabricate citations or pretend uncertain etymologies are established facts.

Prefer concise explanations by default, with optional progressive detail.

3. Automatic vocabulary discovery

Implement an optional background feature that identifies interesting words, expressions, and clauses.

Discovery must be intelligent, contextual, selective, and aware of the user's existing vocabulary knowledge.

Do not simply highlight uncommon words. Consider usefulness, difficulty, nuance, idiomatic value, context, and prior familiarity.

Scanning must be incremental and navigation-aware.

For example, if a document contains 1,200 pages and the user opens page 487, do not scan all 1,200 pages. Start with visible content around page 487.

Introduce debouncing, cancellation, cache reuse, bounded inference queues, and resource-aware scheduling.

The user must be able to enable or disable scanning, control its sensitivity, and distinguish AI-suggested highlights from manually saved items.

Background scanning must not interfere with foreground text-selection explanations.

4. Vocabulary library

Users must be able to save words, phrases, and clauses of interest (WOIs).

Separate normalized vocabulary expressions from their occurrences in individual documents.

Preserve the source document, original context, reliable source anchor, generated explanation, personal notes, familiarity state, and timestamps.

Clicking a saved occurrence must navigate back to its source passage whenever that passage can still be located.

Repeated occurrences of an expression must not unnecessarily create duplicate vocabulary entries.

Support searching, filtering, editing, deleting, and exporting saved vocabulary.

Prepare the data model for future spaced repetition and personalized learning.

5. Editing and annotations

Provide reliable editing appropriate to each file format.

Support full text editing for appropriate plain-text formats, with undo/redo, save, and Save As.

For PDFs, distinguish annotations from modification of original PDF text. Do not promise capabilities the underlying library cannot reliably provide.

For EPUB and other complex formats, establish realistic editing boundaries.

Use non-destructive operations, safe writes, and change detection. Preserve or intelligently repair saved WOI references after edits.

6. Trash and recovery

Implement document removal with a recoverable trash system.

Distinguish documents copied into managed application storage from documents merely linked to external file locations.

Removing a linked document from the library must not unexpectedly delete the original file.

Restoring a document should restore its associated annotations, vocabulary occurrences, metadata, and reading state.

Permanent deletion must be explicit and predictable.

7. Local AI infrastructure

Implement an abstraction around local model inference rather than coupling application logic directly to one particular model.

Support streaming, timeouts, cancellation, retries where appropriate, model availability checks, and clear error states.

Respect the hardware limitations of a 16 GB unified-memory system.

Avoid unbounded context windows and unnecessary concurrent inference jobs.

Use caching and structured outputs to improve speed and consistency.

Treat document contents as untrusted input, never as instructions for the application or agent to execute.

The application must never silently upload private documents to a remote service.

8. Interface and experience

Design a premium, coherent, minimalist desktop interface with excellent typography, spacing, hierarchy, transitions, and accessibility.

The interface should be elegant but restrained. Avoid visual clutter, unnecessary dashboards, intrusive animations, and oversized controls.

Support light and dark themes, keyboard navigation, readable typography, configurable reading settings, and sensible empty/loading/error states.

Maintain a consistent component system and interaction language throughout the application.

Design the reader, explanation interface, document library, vocabulary library, settings, and trash as a unified product.

9. Reliability and testing

Test at the unit, integration, and end-to-end levels.

Pay particular attention to document rendering, text selection, precise source anchoring, large documents, interrupted AI generation, model failures, document modifications, recovery workflows, and data integrity.

Include realistic test fixtures and reproducible performance measurements.

All critical persistence and destructive operations must be covered by tests.

Engineering principles

Use clean, modular, typed interfaces and explicit module boundaries.

Avoid monolithic files and tightly coupled components.

Prefer established libraries over unnecessary custom implementations.

Document important architectural decisions and their trade-offs.

Never silently replace required functionality with mock data or non-functional UI.

Make limitations explicit rather than hiding them.

Keep generated code maintainable and understandable.

Require relevant tests for every completed feature.

Avoid adding unrelated features or dependencies.

Maintain a consistent product design system.

Do not sacrifice data integrity to meet an arbitrary development milestone.
