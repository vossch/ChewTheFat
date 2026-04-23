# Implementation Plan: ChewTheFat — iOS Agentic Food Logging App

**Branch**: `001-ios-health-coach-app` | **Created**: 2026-04-22
**Inputs**: `constitution.md`, `spec.md`, `data-model.md`, `file-architecture.md`,
`research.md`, `code-documentation.md`

This plan turns the specs into a milestone-by-milestone build order. It records
the decisions made during planning, the open items that are deliberately
deferred, and the "done when" acceptance for each milestone.

---

## Captured decisions

| # | Area | Decision |
|---|------|----------|
| D1 | Sequencing | Hybrid: `M0`–`M2` are horizontal foundation (design system, data, RAG, agent harness). `M3`+ are vertical slices organised by user story. |
| D2 | LLM integration timing | Real `MLXModelClient` (Apple MLX-Swift via `mlx-swift-lm`) lands in `M2`. A `StubModelClient` is retained for unit and UI tests only. |
| D3 | Model delivery | **Fetched on first launch** from Hugging Face Hub via `huggingface/swift-huggingface` + `swift-transformers` (integrated through `MLXHuggingFace`). Cached in `Application Support/Models/`, excluded from iCloud backup. Bootstrap is gated behind EULA acceptance and runs as the first onboarding step before any user-data collection. Ratified via constitution amendment 1.1.0 (2026-04-22). See `research.md §1`. |
| D4 | Reference DB preparation | In-repo Python pipeline under `Tools/db-prep/` emits `usda.sqlite` + `offs.sqlite` with pre-built FTS5 tables. Outputs tracked via Git LFS. |
| D5 | Onboarding drive model | `SessionGoalContract` (Swift) declares required fields per goal; `skill-onboarding.md` (markdown playbook) declares the suggested conversational flow. The model drives the dialogue; the contract enforces completion. See FR-028 and `spec.md §Clarifications 2026-04-22`. |
| D6 | Off-goal policy | Soft redirect: the orchestrator injects a system-level note into the current session prompting the model to guide the user back. No UI-level hard block. |
| D7 | Progress reminder mechanism | A new `GoalProgressContextSource` re-derives the collected/missing field checklist from SwiftData fresh on every turn and prepends it to the prompt. The model is never relying on conversation memory for required-field state. |
| D8 | Quality gates | `ChewTheFatTests` target and `SwiftLint` added in `M0`. A local pre-commit SwiftLint hook gates style until the repo has a remote; GitHub Actions CI is added at that point. |

---

## Deliberately deferred (not blocking this plan)

| Area | Status |
|------|--------|
| Specific MLX model id (default `mlx-community/gemma-3-1b-it-qat-4bit` per `mlx-swift-lm` README; alternatives in the `mlx-community` 1B–3B 4-bit class) | Validated empirically in `M2` against SC-002a on an A15+ device; pick whichever hits the latency budget with better quality. |
| `WebSearchFallback` provider and API key handling | Ships as a no-op stub in `M1`; real provider selection is post-v1. |
| Voice dictation, camera, barcode scanning, HealthKit, data export | All deferred to post-v1 per `spec.md §Assumptions` and FR-022. |

---

## Redlines applied to existing specs

This plan amends the following docs (see commits that accompany this file):

- `research.md §1 "Model delivery"` — initially switched from CDN-download to bundled-in-`Resources/` via Git LFS; subsequently superseded the same day by the Hugging Face Hub fetch on first launch (constitution 1.1.0).
- `spec.md` — added **FR-028** (SessionGoal contract enforcement) and `Session 2026-04-22` clarification entries for the onboarding, model-delivery, and Model Acquisition decisions; FR-001 widened to allow the bootstrap carve-out.
- `code-documentation.md` — added `SessionGoalContract`, `SessionGoalEvaluator`, `GoalProgressContextSource`; updated `SessionStateManager` responsibilities to include the soft-redirect behaviour. Constitution 1.1.0 follow-on: `ModelClient` narrowed to MLX-Swift; new `ModelBootstrapper` entry under `Agent/Model/`; `AppEnvironment` gains a `modelBootstrapper` reference.
- `file-architecture.md` — added `Domain/SessionGoalContract.swift`, `Domain/SessionGoalEvaluator.swift`, `Agent/ContextManager/Sources/GoalProgressContextSource.swift`. Constitution 1.1.0 follow-on: added `Agent/Model/ModelBootstrapper.swift` and `UI/Onboarding/ModelBootstrapView.swift`.
- `CLAUDE.md` — added to the authoritative specs list; constitution version reference bumped to 1.1.0.
- `constitution.md` — amended to **1.1.0 (2026-04-22)**: Principle I gains a narrow first-launch model-bootstrap carve-out; Technology Stack finalises the LLM choice as Apple MLX-Swift via `mlx-swift-lm` and adds a Model Acquisition entry. User-data egress prohibition restated as absolute.

---

## Milestones

### M0 — Foundation *(no user-visible features)*

**Scope**: clear the scaffold, stand up the design system, persistence stack, domain layer, repositories, DI container, and the quality gates.

1. Bump `SWIFT_VERSION` → 5.9+ in the Xcode project.
2. Delete `ChewTheFat/Item.swift` and `ChewTheFat/ContentView.swift` (template scaffolding).
3. Initialise Git LFS. `.gitattributes` tracks `ChewTheFat/Resources/*.sqlite`. *(Model weights are no longer bundled — fetched at runtime per constitution 1.1.0; no `*.gguf` / `*.safetensors` LFS pattern needed.)*
4. Add `ChewTheFatTests` target to the Xcode project.
5. Add `SwiftLint` as an SPM build tool plugin. Author `.swiftlint.yml` with:
   - Custom `no_hex_colours_in_swift` rule (Principle III — colours must come from Assets.xcassets).
   - Heuristic `no_magic_layout_numbers` rule (flags `.padding(<literal>)`, `.frame(width: <literal>)`, etc. outside `DesignSystem/`).
   - Local pre-commit hook that runs `swiftlint --strict`.
6. Materialise the folder tree in `file-architecture.md`. Use `.keep` placeholder files so the `PBXFileSystemSynchronizedRootGroup` picks the structure up without hand-edited `project.pbxproj` entries.
7. `UI/Shared/DesignSystem/`: `Spacing.swift`, `Typography.swift`, `Colors.swift`, `AppIcon.swift`.
8. `Assets.xcassets`: named colour sets for the Figma palette (Light + Dark appearance variants) — semantic names only.
9. `Data/SwiftData/`: `ChewTheFatSchema` (`VersionedSchemaV1`), `ModelContainerProvider` (main + `.inMemory`), `ModelContextFactory`.
10. `Data/Models/`: one file per `@Model` type from `data-model.md`.
11. `Data/Repositories/`: every protocol + SwiftData-backed implementation. In-memory round-trip tests per repository.
12. `Domain/`: every type from `file-architecture.md §Domain/`, **including** `SessionGoalContract.swift` and `SessionGoalEvaluator.swift`. `SessionGoal` gains the `.onboarding` case.
13. `App/`: `AppEnvironment` DI container (main + `.preview` + `.testing` variants), `AppDelegate` stub (no background tasks wired), `ChewTheFatApp` routes to onboarding vs. chat based on `UserProfile.eulaAcceptedAt`.

**Done when:**
- `xcodebuild -scheme ChewTheFat build test` passes on a clean checkout.
- No references to the template `Item` type remain.
- Every `@Model` round-trips through its repository in a test.
- `swiftlint --strict` reports zero violations.

---

### M1 — Reference data + RAG plumbing

**Scope**: prepare the read-only food reference databases, wire the four RAG sources, implement the SwiftData promotion path for logged foods.

1. `Tools/db-prep/prepare.py` — downloads USDA FDC Foundation + SR Legacy, OFFs dump; filters to the curated subsets per `research.md §3`; emits `usda.sqlite` + `offs.sqlite` with pre-built `food_fts` FTS5 virtual tables.
2. `Makefile` target `db-refresh` wrapping the Python script.
3. CI-style pre-commit check that fails if `ChewTheFat/Resources/usda.sqlite` is missing the expected FTS5 table.
4. `Data/LocalDatabases/USDAFoodDB.swift`, `OpenFoodFactsDB.swift` — `GRDB.DatabasePool(.readOnly)` wrappers, returning `ReferenceFood` value types.
5. `Tools/Retrieval/Sources/`:
   - `UserHistorySource` — `#Predicate` over `FoodEntry.searchTokens`, ranked `match × logCount × recency(lastLoggedAt)`.
   - `USDAFoodSource`, `OpenFoodFactsSource` — FTS5 `MATCH` queries joined to `serving`.
   - `WebSearchFallback` — no-op stub returning `[]`.
6. `Tools/Retrieval/FoodSearchRAG.swift` — four-source merge + dedup by `(source, sourceRefId)`.
7. `FoodLogRepository.upsertFoodEntry` — the FR-004a promotion transaction (lookup-or-create `FoodEntry`, copy reference servings on first log).
8. Tests: RAG merge ordering, promotion idempotency (second log reuses the existing `FoodEntry`), `UserHistorySource` ranking outranks reference hits on repeat queries.

**Done when:**
- A fixture test seeds `FoodEntry` rows, queries reference DBs, and asserts that a repeat query surfaces the user's prior log above new reference hits.
- Promotion of an OFFs hit creates a `FoodEntry` + `[Serving]` in SwiftData with `(source, sourceRefId)` uniqueness enforced.

---

### M2 — Agent harness with real llama.cpp

**Scope**: wire a runnable on-device model, the orchestrator, context assembly, tool dispatch, session state management, and the onboarding playbook.

1. Add SPM dependencies for the MLX stack: `ml-explore/mlx-swift-lm` (products `MLXLLM`, `MLXLMCommon`, `MLXHuggingFace`), `huggingface/swift-huggingface`, `huggingface/swift-transformers`. Pin a default model identifier in code (default candidate: `mlx-community/gemma-3-1b-it-qat-4bit`); validate empirically against SC-002a on an A15+ device before locking it.
2. `Agent/Model/`:
   - `ModelClientProtocol`, `ModelRequest`, `ModelResponse`.
   - `MLXModelClient` (`nonisolated final class`); wraps `LLMModelFactory.shared.loadContainer(...)` + `ChatSession`; streams tokens via `AsyncThrowingStream<ModelStreamEvent, Error>`; exposes a tokenizer hook for `ContextBudget`.
   - `ModelBootstrapper` (`actor`) — owns the first-launch fetch from Hugging Face Hub via `MLXHuggingFace`; surfaces progress through an `AsyncStream<BootstrapProgress>`; writes weights to `Application Support/Models/<modelId>/` with `URLResourceKey.isExcludedFromBackupKey = true`; idempotent on subsequent launches (no-ops when cache matches the pinned identifier). Surfaces `ModelBootstrapError.network`, `.diskFull`, `.cancelled` for the onboarding UI.
   - `StreamingHandler` — tag-based state machine converting raw tokens into `.text(String)`, `.toolCall(ToolCall)`, `.widgetBlob(RawWidgetBlob)` chunks.
   - `StubModelClient` — deterministic fixture driver for tests; also stands in when the bootstrap has not yet completed.
   - `ToolSchema` — generated from `ToolProtocol` conformances so the model prompt and dispatcher share one source of truth.
3. `Agent/ContextManager/`:
   - `ContextManager`, `ContextAssembler`, `ContextBudget` (uses `LlamaModelClient.tokenize`), `ContextSourceProtocol`.
   - Six concrete sources: `SessionContextSource`, `ProfileContextSource`, `GoalContextSource`, `MemoryContextSource`, `KnowledgeContextSource`, **`GoalProgressContextSource`**.
4. `Agent/Orchestrator/`:
   - `Orchestrator` + `OrchestratorProtocol`.
   - `TurnHandler` state machine (`idle → contextAssembling → streaming → toolExecuting → resumingStream → finalizing → done`).
   - `ToolCallDispatcher` with `ToolIdentifier`-keyed registry.
   - `WidgetIntentResolver` with schema validation.
   - `SessionStateManager` — including the contract-enforcing `startSession(goal:)` that issues a soft-redirect system note when the current contract is unsatisfied.
5. `Tools/`:
   - `ToolProtocol`, `ToolResult`, `ToolError`.
   - All four Action tools (`LogFoodTool`, `LogWeightTool`, `SetGoalsTool`, `SetProfileInfoTool`) + `FoodSearchTool` + `LookupKnowledgeTool`.
6. `Knowledge/`:
   - `KnowledgeGraph`, `KnowledgeGraphLoader`, `KnowledgeIndex`, `KnowledgeFile`, `KnowledgeType`, `KnowledgeSelector`.
   - First content authored: `Index.md`, `skill-onboarding.md` (full onboarding playbook — suggested question order, chip options, height ambiguity handling, goal-recommendation phrasing), plus placeholders `goal-weight-loss.md`, `goal-muscle-gain.md`, `goal-maintenance.md`, `skill-meal-logging.md`, `skill-weight-tracking.md`, `reference-macronutrients.md`.
7. Wire `AppDelegate.application(_:didFinishLaunchingWithOptions:)` to warm the model during launch **only if** the bootstrap has completed (`ModelBootstrapper.isReady`); otherwise defer warm-up to the post-bootstrap onboarding kickoff.
8. Latency validation: an XCTest harness that sends a canned user turn and asserts first-token ≤ 3 s on an A15+ device.

**Done when:**
- An end-to-end test feeds "I weigh 185 lbs today" through the orchestrator and observes `LogWeightTool` being dispatched with valid arguments.
- A `.onboarding` session rejects a transition to `.logWeight` until its contract is satisfied, and emits a system-level note instead.
- The `GoalProgressContextSource` is confirmed to inject an up-to-date checklist by an assertion on `AssembledContext`.
- First-token latency meets SC-002a on a real A15+ device.

---

### M3 — Chat UI + inline widgets *(first demo-able build — US2 + US4)*

**Scope**: the primary chat surface and the three core widgets; widgets are dual-use from day one.

1. `UI/Chat/`: `ChatView`, `ChatViewModel`, `MessageListView`, `MessageBubble`, `ChatInputBar` (mic + camera rendered disabled per FR-022), `SuggestedRepliesView`.
2. `UI/Widgets/WidgetRenderer.swift`.
3. `UI/Widgets/MealCard/`: `MealCardView` + `MealCardViewModel` with both `.snapshot(payload:)` and `.live(meal:date:repo:)` factories.
4. `UI/Widgets/MacroChart/`: Swift Charts-based, respects Reduce Motion, composed entirely of design tokens.
5. `UI/Widgets/WeightGraph/`: Swift Charts-based, solid-filled past + faded projected regions.
6. Widget payload contract — `MessageWidget.payload` stores references (`loggedFoodIds`, `date`, `dateRange`); views resolve references at render time via repositories.
7. Typing-indicator state plumbed via `Orchestrator.TurnEvent` (FR-027, SC-002a).

**Done when:**
- Describing "3 eggs, 1 slice turkey bacon, grapefruit" yields a Meal Card; user confirmation persists `LoggedFood` rows.
- Asking "how am I doing?" renders a live-bound Macro Chart.
- Editing an underlying `LoggedFood` in the store re-renders any widget that references it.

---

### M4 — Onboarding (US1)

**Scope**: first-run flow driven by the playbook, enforced by the contract.

1. `UI/Onboarding/OnboardingCoordinator` — orchestrates the three-phase first-run flow: (a) **EULA** (static SwiftUI, no LLM, no network), (b) **Model bootstrap** (`ModelBootstrapView` — only runs if `ModelBootstrapper.isReady` is false; surfaces download progress, cancel/retry, and disk/network error states), (c) **Conversational onboarding** (lives inside the chat thread; seeds `session.goal = .onboarding` and enqueues a system-authored kickoff turn). Phases (a)–(b) gate (c); phase (b) is skipped when the cache already contains the pinned model. Resume-on-relaunch preserves whichever phase the user left off in.
2. `UI/Onboarding/EULAView`, `ModelBootstrapView`, `ProfileSetupView`, `GoalSetupView` — `ModelBootstrapView` is a static SwiftUI progress screen bound to `ModelBootstrapper`'s `AsyncStream<BootstrapProgress>`; the profile/goal setup views remain inline widgets emitted by the model via widget-intent tool calls once the bootstrap is complete.
3. Height-parsing path: `SetProfileInfoTool` accepts a `heightInput: String`, delegates to a small Swift parser for `5' 11"`, `5-11`, `5 ft 11 in`, `180 cm`; invalid input returns a typed error the model surfaces conversationally.
4. Projected goal-achievement date math in `GoalRepository`.
5. Resume-on-relaunch is free: `session.goal = .onboarding` persists; `GoalProgressContextSource` re-derives missing fields on next launch.

**Done when:**
- A fresh install walks from launch to chat surface in under 3 minutes (SC-001) on a reference broadband connection, including the first-launch model bootstrap.
- Killing the app mid-flow — including mid-bootstrap — resumes in place; a partially-downloaded model is either resumed from its byte offset or safely discarded and re-fetched with no user data collected in the meantime.
- Typing "log my weight" mid-onboarding produces a model-authored redirect, not a UI-level block.

---

### M5 — Dashboard (US7) + dedicated editors (US6)

**Scope**: the home Dashboard surface and the three dedicated editors (Goals / Profile / Settings) reachable from it.

1. `UI/Dashboard/DashboardView` + `DashboardViewModel` subscribing to `WeightLog`/`FoodLog`/`Goal`/`SessionRepository` change streams.
2. `TodayPanelView`, `DashboardNavChipsView`, `ChatHistoryListView`.
3. Trajectory panel = `WeightGraphView.live(repo:)`; Today macro bars = `MacroChartView.live(repo:)`.
4. `UI/Settings/SettingsView`, `ProfileEditView`, `GoalsEditView` — including the Auto/Manual toggle and percentage sliders with the sum-to-100 auto-rebalance invariant.
5. Empty states per spec edge cases (no weight history → Trajectory prompts to log first weight; no prior sessions → Chat history hidden).

**Done when:**
- Editing a `LoggedFood` from the chat surface updates the Dashboard Today panel live, without refresh.
- Switching unit systems in Settings re-renders all weight / height / macro values without altering stored canonical values.

---

### M6 — Weight logging (US3) + multi-session browsing (US8)

**Scope**: finish the second core log type and the session-history navigation.

1. Inline `WeightLogWidget` for the chat surface; dedicated logging surface reachable from Dashboard.
2. Coaching-feedback heuristic for anomalous weight deltas (threshold in `GoalRepository`; model prompt hint surfaced when crossed).
3. Multi-session UX: "start new session" gesture in chat; deep-link from Dashboard chat history; messages always scoped to exactly one session.

**Done when:**
- Logging two weights on consecutive days updates the Trajectory chart.
- Starting a new session from Dashboard correctly routes subsequent messages to the new session.
- A significantly divergent weight triggers coaching feedback per US3 scenario 3.

---

### M7 — Proactive prompts (US5) + memory + trends

**Scope**: scheduled coach prompts and the agent's long-term memory / summary infrastructure.

1. `Agent/Scheduling/ScheduledJobRunner` — `BGTaskScheduler` identifiers registered via `AppDelegate`.
2. `SessionTrigger`, `SessionConflictPolicy` (suppress / queue / interrupt decisions).
3. `MemoryWriter`, `MemoryTrigger` (cheap heuristics + optional model gate on borderline turns).
4. `DailySummaryGenerator` (end-of-day scheduled job).
5. `TrendsGenerator` — repository hooks mark `Trends` stale on writes; foreground recompute.
6. Notification preferences plumbed through `SettingsView` (FR-024).

**Done when:**
- A configured breakfast prompt fires a coach message with a quick-log widget.
- The same prompt is suppressed (or acknowledges) when breakfast is already logged.
- `Trends` is recomputed on foreground after a new log.

---

### M8 — Quality gate

**Scope**: fill test coverage to constitution bar, wire CI, validate latency and accessibility on real devices.

1. Fill any XCTest / XCUITest coverage gaps in the data, agent-parsing, and widget layers.
2. Snapshot tests for core widgets to guard design-token drift.
3. GitHub Actions CI: `xcodebuild test` + `swiftlint --strict`, triggered on PRs to `main`. Block merges on any `error`-severity lint.
4. Real-device validation pass: SC-002a (first-token ≤ 3 s, full ≤ 15 s), SC-003 (food search ≤ 2 s), SC-007 (chart animations ≤ 500 ms, Reduce Motion suppresses).
5. Accessibility audit: VoiceOver through every widget, Dynamic Type at Accessibility sizes, Reduce Motion across charts.

**Done when:**
- CI green, SwiftLint clean.
- Latency SCs pass on a reference A15 iPhone.
- Every widget is fully usable at AX5 Dynamic Type with VoiceOver.

---

## Entry point

The smallest first PR is `M0` steps 1–5: bump Swift version, delete scaffold files, initialise Git LFS, add the `ChewTheFatTests` target, and wire SwiftLint. That change touches no architecture but gates every later milestone.

## Sync impact

Edits applied alongside this plan:

- `Specs/research.md §1` — Model delivery initially flipped to bundled via LFS, then the same day superseded by Hugging Face Hub fetch on first launch; LLM framework decision updated from llama.cpp to MLX-Swift via `mlx-swift-lm`.
- `Specs/spec.md` — FR-028 added; `Session 2026-04-22` clarifications recorded, including the Model Acquisition follow-up; FR-001 widened for the bootstrap carve-out; Assumptions updated to describe the HF Hub fetch.
- `Specs/code-documentation.md` — `SessionGoalContract`, `SessionGoalEvaluator`, `GoalProgressContextSource` added; `SessionStateManager` responsibilities expanded. Constitution 1.1.0 follow-on: `ModelClient` narrowed to MLX-Swift; new `ModelBootstrapper` section; `AppEnvironment` gains a `modelBootstrapper` reference.
- `Specs/file-architecture.md` — three new files added to the tree, plus `Agent/Model/ModelBootstrapper.swift` and `UI/Onboarding/ModelBootstrapView.swift`.
- `CLAUDE.md` — authoritative specs list updated; constitution version reference bumped to 1.1.0.
- `Specs/constitution.md` — **amended to 1.1.0 (2026-04-22)**: Principle I gains the first-launch model-bootstrap carve-out; Technology Stack finalises Apple MLX-Swift and adds a Model Acquisition entry; Sync Impact Report embedded in the file.
