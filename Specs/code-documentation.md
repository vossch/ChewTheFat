# Code Documentation: ChewTheFat — iOS Agentic Food Logging App

**Status**: Forward-looking design doc. No production code exists yet; the repo is
still the Xcode 26 SwiftUI + SwiftData template. This file describes the **intended**
shape of each major type as derived from `file-architecture.md`, `data-model.md`,
and `spec.md`. Keep it in sync when the real code lands.

**Persistence**: User data lives in SwiftData; the bundled `usda.sqlite` and
`offs.sqlite` are read-only GRDB sources consumed only by the RAG tool. See
`data-model.md` Overview and constitution §Technology Stack.

**Conventions**:
- Swift-ish pseudocode signatures. `async` / `throws` annotations are indicative.
- Default actor isolation is `@MainActor` per the project's Swift build settings;
  types that run off the main actor are explicitly flagged `nonisolated` or `actor`.
- Protocol suffix: `…Protocol` indicates a dependency seam (DI-friendly); the
  concrete type drops the suffix.
- **Source of truth for persistence fields** is `data-model.md`. This doc describes
  the Swift types that *wrap* those records, not the schema itself.

---

## Top-Level Map

```
┌──────────┐   ┌──────────────────────────────────┐   ┌───────────┐
│   UI     │ → │             Agent                │ → │   Data    │
│ (Views + │   │  Orchestrator → Tools → Model    │   │ (SwiftD + │
│ ViewMdls)│   │  ↑ ContextManager  ↓ Memory      │   │   GRDB)   │
└──────────┘   └──────────────────────────────────┘   └───────────┘
      │                     │                                ▲
      ▼                     ▼                                │
  Domain types (pure Swift) ◀──── Repositories wrap SwiftData
```

- **UI** only talks to its ViewModels and to Domain types.
- **Agent** is the brain: orchestrator + tools + model + context + memory.
- **Tools** are the agent's side-effects, split into Retrieval (read) and Action (write).
- **Data** is repositories over SwiftData, plus read-only GRDB RAG sources.
- **Domain** is pure Swift glue — no SwiftData, no SwiftUI — so the agent and tools
  stay unit-testable.

---

## `App/`

### `ChewTheFatApp`

**Role**: `@main` entry point and composition root.

**Responsibilities**:
- Constructs the `AppEnvironment` (DI container) exactly once for the process.
- Installs the SwiftData `ModelContainer`, the GRDB `DatabasePool` for reference DBs,
  the on-device model client, and the scheduled-job runner.
- Bootstraps the root scene with the `AppEnvironment` injected into the SwiftUI
  environment, including `.modelContainer(...)` on the root scene.

**Key functions**:
- `init()` — wires `ModelContainerProvider`, `ModelClient`, `AppEnvironment`,
  `AppDelegate` (via `@UIApplicationDelegateAdaptor`).
- `var body: some Scene` — root scene; chooses onboarding vs chat based on
  `UserProfile.eulaAcceptedAt`.

**Depends on**: `AppEnvironment`, `AppDelegate`, `ModelContainerProvider`, top-level
UI entry points (`ChatView`, `OnboardingCoordinator`).
**Used by**: the Swift runtime.

---

### `AppDelegate`

**Role**: Holds iOS lifecycle hooks that `App` / `Scene` cannot express.

**Responsibilities**:
- Registers `BGTaskScheduler` identifiers on launch.
- Routes background-task launches to `ScheduledJobRunner`.
- Forwards app-foreground / app-background transitions to `TrendsGenerator` (so
  stale trend blobs can be recomputed).

**Key functions**:
- `application(_:didFinishLaunchingWithOptions:) -> Bool`
- `application(_:handleEventsForBackgroundURLSession:completionHandler:)`
  (only used if the opt-in web fallback is enabled).

**Depends on**: `ScheduledJobRunner`, `TrendsGenerator`.
**Used by**: `ChewTheFatApp`.

---

### `AppEnvironment`

**Role**: Central DI container. A single struct that holds protocol-typed references
to every long-lived collaborator, passed down the view tree via SwiftUI's environment.

**Responsibilities**:
- Groups repositories, the orchestrator, the knowledge graph, formatters, and the
  scheduler so views/view-models can take narrow dependencies from a single point.
- Builds a test double variant (`AppEnvironment.preview` and `.testing`) that swaps
  every dependency for an in-memory stub.

**Key properties**:
- `profile: ProfileRepositoryProtocol`
- `goals: GoalRepositoryProtocol`
- `sessions: SessionRepositoryProtocol`
- `foodLog: FoodLogRepositoryProtocol`
- `weightLog: WeightLogRepositoryProtocol`
- `memory: MemoryRepositoryProtocol`
- `orchestrator: OrchestratorProtocol`
- `knowledge: KnowledgeGraphProtocol`
- `scheduler: ScheduledJobRunnerProtocol`

**Depends on**: every protocol in the list above.
**Used by**: `ChewTheFatApp` (constructs one), all view models (pull only what they
need via initialiser injection).

---

## `Agent/Orchestrator/`

### `OrchestratorProtocol` / `Orchestrator`

**Role**: Single coordinator that turns a user utterance into a fully persisted agent
reply (text + ordered widgets + any tool side-effects).

**Responsibilities**:
- Owns the "turn" lifecycle: receive a user message, assemble context, stream model
  tokens, intercept tool calls, promote widget intents, persist the resulting
  `Message` (+ `MessageWidget` rows), emit UI events.
- Hides internal reasoning and raw tool calls from the UI (constitution Principle IV;
  FR-003b).
- Enforces the streaming latency budget (SC-002a: first token ≤ 3 s; full ≤ 15 s).

**Key functions**:
```swift
protocol OrchestratorProtocol {
    func handle(userMessage: String, in session: Session) -> AsyncStream<TurnEvent>
    func cancelActiveTurn()
}
```

`TurnEvent` cases cover: `.userMessagePersisted`, `.typingStarted`, `.textToken(String)`,
`.widgetIntent(WidgetIntent)`, `.toolInvoked(ToolIdentifier)` (log-only), `.completed(Message)`,
`.failed(Error)`.

**Depends on**: `ContextManager`, `ModelClient`, `ToolCallDispatcher`,
`WidgetIntentResolver`, `SessionStateManager`, `SessionRepository`, `MemoryWriter`.
**Used by**: `ChatViewModel` (primary), `OnboardingCoordinator` (runs the onboarding
turn-by-turn through the same orchestrator), `ScheduledJobRunner` (for proactive
coach messages).

---

### `TurnHandler`

**Role**: Stateful driver for a single turn. Pure logic — no UI, no direct SwiftData.

**Responsibilities**:
- Maintains a state machine: `idle → contextAssembling → streaming → toolExecuting →
  resumingStream → finalizing → done`.
- Buffers streamed tokens, identifies `<tool_call>` / `<widget>` tags via the model
  protocol, pauses the text stream while tools run, resumes after.
- Caps total elapsed time at the SC-002a budget and surfaces a timeout as
  `TurnEvent.failed(.timeout)` so the UI can retry.

**Key functions**:
- `run(turn: TurnRequest) -> AsyncThrowingStream<TurnEvent, Error>`
- `interruptForToolCall(_ call: ToolCall) async throws -> ToolResult`

**Depends on**: `ModelClient`, `ToolCallDispatcher`, `StreamingHandler`.
**Used by**: `Orchestrator`.

---

### `ToolCallDispatcher`

**Role**: Routes a parsed `ToolCall` to the correct `Tool` implementation and returns
a structured `ToolResult`.

**Responsibilities**:
- Holds the registry of all tools keyed by `ToolIdentifier`.
- Validates arguments against the tool's `ToolSchema` before invoking it.
- Normalises tool errors into `ToolError` so the orchestrator can either retry or
  feed the error back into the model prompt for recovery.

**Key functions**:
- `register(_ tool: any ToolProtocol)`
- `dispatch(_ call: ToolCall) async throws -> ToolResult`

**Depends on**: every concrete tool through `ToolProtocol`.
**Used by**: `TurnHandler`.

---

### `WidgetIntentResolver`

**Role**: Decodes agent output (either a structured tag in the stream or a tool
result) into one or more `WidgetIntent` domain values, which the `WidgetRenderer`
later turns into native views.

**Responsibilities**:
- Validates widget payloads against the shared widget schema (the same schema the
  model is prompted with — single source of truth per constitution Principle IV).
- Handles *compound* messages: one model output may yield N `WidgetIntent`s that
  must retain their emission order.

**Key functions**:
- `resolve(_ raw: RawWidgetBlob) throws -> [WidgetIntent]`

**Depends on**: `Domain/WidgetIntent`.
**Used by**: `TurnHandler`, `Orchestrator`.

---

### `SessionStateManager`

**Role**: In-memory mirror of the currently-open `Session` and its pending turn.

**Responsibilities**:
- Caches the current session's `Message` list (most recent N) so the ChatView can
  render without a SwiftData round-trip per token.
- Publishes updates via Combine/AsyncStream for the ChatViewModel to consume.
- Coordinates "start new session" vs "resume existing session" transitions without
  losing in-flight turns.

**Depends on**: `SessionRepository`.
**Used by**: `Orchestrator`, `ChatViewModel`.

---

## `Agent/ContextManager/`

### `ContextManagerProtocol` / `ContextManager`

**Role**: Assembles the prompt context for a single turn from multiple sources,
respecting a token budget.

**Responsibilities**:
- Queries every registered `ContextSource` for its contribution(s).
- Runs `ContextAssembler` to order contributions by priority and drop/truncate when
  the budget is exceeded.
- Returns a `ModelRequest`-ready prompt plus a manifest of which sources made it in
  (used for testing and debugging).

**Key functions**:
```swift
protocol ContextManagerProtocol {
    func buildContext(for turn: TurnRequest) async -> AssembledContext
}
```

**Depends on**: all `ContextSource` implementations; `ContextBudget`, `ContextAssembler`.
**Used by**: `Orchestrator`.

---

### `ContextAssembler`

**Role**: Deterministic merge of context contributions.

**Responsibilities**:
- Priority-ordered interleaving (e.g., system prompt → profile → active goal →
  selected knowledge → recent session messages → current user turn).
- Truncation strategy: drop low-priority first, then oldest session messages, then
  soft-shorten knowledge snippets.

**Key functions**:
- `assemble(_ contributions: [ContextContribution], budget: ContextBudget) -> AssembledContext`

**Depends on**: `ContextBudget`.
**Used by**: `ContextManager`.

---

### `ContextBudget`

**Role**: Token accounting primitives.

**Responsibilities**:
- Tokenises Swift strings with a llama-compatible tokenizer to estimate size.
- Exposes `remaining(after:)` and `fits(_:)` helpers.

**Depends on**: `ModelClient`'s tokenizer (re-exported).
**Used by**: `ContextAssembler`, `ContextManager`.

---

### `ContextSourceProtocol` + concrete sources

**Role**: A pluggable contributor to the prompt. Each one answers the question
"what do you want to add for this turn?"

**Concrete implementations**:

| Source | Pulls from | Contributes |
|--------|-----------|-------------|
| `SessionContextSource` | `SessionRepository`, `SessionStateManager` | Recent messages (text and widget summaries), session goal. |
| `GoalContextSource` | `GoalRepository` | Current daily calorie + macro targets, weekly-change rate, projected goal date. |
| `ProfileContextSource` | `ProfileRepository` | Age (derived from birth year), height, sex, activity level, preferred units. |
| `MemoryContextSource` | `MemoryRepository`, `DailySummaryRepository` | Agent-authored facts and recent daily summaries, recency-ranked. |
| `KnowledgeContextSource` | `KnowledgeGraph`, `KnowledgeSelector` | Markdown snippets relevant to the session goal and current topic. |

**Key functions**:
```swift
protocol ContextSourceProtocol {
    var priority: ContextPriority { get }
    func contribute(for turn: TurnRequest) async -> [ContextContribution]
}
```

**Used by**: `ContextManager` (registered in order at `AppEnvironment` construction).

---

## `Agent/Model/`

### `ModelClientProtocol` / `ModelClient`

**Role**: Narrow wrapper around the chosen on-device LLM runtime (llama.cpp or
Apple MLX — decision deferred to the implementation plan).

**Responsibilities**:
- Loads the model once at process start; exposes `generate` as an `AsyncStream<String>`
  of tokens.
- Injects the agent's tool schemas at the system-prompt level.
- Enforces cancellation (turn cancel = stream cancel, not just ignore).

**Key functions**:
```swift
protocol ModelClientProtocol {
    func generate(_ request: ModelRequest) -> AsyncThrowingStream<String, Error>
    func tokenize(_ text: String) -> [Int]        // used by ContextBudget
    func cancel()
}
```

**Depends on**: a vendored llama.cpp / MLX Swift binding (out of tree).
**Used by**: `TurnHandler`, `ContextBudget`.

---

### `ModelRequest` / `ModelResponse`

**Role**: DTOs between the orchestrator and the runtime.

- `ModelRequest` carries: assembled prompt, tool schemas, sampling parameters.
- `ModelResponse` is effectively a terminal summary of the streaming turn (finish
  reason, total tokens, wall-clock time) — used for telemetry, not UI rendering.

**Used by**: `ModelClient`, `TurnHandler`.

---

### `StreamingHandler`

**Role**: Token-to-chunk parser that converts raw model tokens into semantically
meaningful chunks: `.text(String)`, `.toolCall(ToolCall)`, `.widgetBlob(RawWidgetBlob)`.

**Responsibilities**:
- Streaming state machine that tracks whether the current tokens are inside a tool
  or widget tag.
- Emits partial text chunks as soon as safe to render (no unclosed tag in progress).

**Used by**: `TurnHandler`.

---

### `ToolSchema`

**Role**: Compile-time description of every tool available to the model.

**Responsibilities**:
- One `ToolSchema` per concrete tool, produced via a single helper that reads a
  `ToolProtocol` conformance and emits the JSON schema the model is prompted with.
- Guarantees the model's known tool list cannot drift from the dispatcher's registry
  (both are derived from the same source).

**Used by**: `ModelClient` (prompt injection), `ToolCallDispatcher` (validation).

---

## `Agent/Memory/`

### `MemoryWriter`

**Role**: Post-turn / post-session hook that persists long-lived coaching facts.

**Responsibilities**:
- Runs after `.completed` turns; decides via `MemoryTrigger` whether the turn is
  memory-worthy.
- Writes `Memory` records, optionally tagged with a category.

**Key functions**:
- `consider(turn: CompletedTurn) async`
- `writeExplicit(_ content: String, category: String?) async`

**Depends on**: `MemoryRepository`, `MemoryTrigger`.
**Used by**: `Orchestrator`.

---

### `DailySummaryGenerator`

**Role**: Produces agent-generated natural-language summaries of a completed day's
logs.

**Responsibilities**:
- Runs as a scheduled job (typically end-of-day, configurable).
- Reads the day's `LoggedFood`, `WeightEntry`, and recent session turns; prompts the
  model for a summary; writes a `DailySummary` row.

**Depends on**: `FoodLogRepository`, `WeightLogRepository`, `SessionRepository`,
`ModelClient`, `MemoryRepository` (for persistence).
**Used by**: `ScheduledJobRunner`.

---

### `TrendsGenerator`

**Role**: Recomputes the singleton `Trends` pre-aggregation blob used by charts.

**Responsibilities**:
- Marks `Trends` stale on any `LoggedFood` / `WeightEntry` write (via repository hook).
- On foreground transition (from `AppDelegate`), if stale, recomputes the weight and
  macro trend payloads and stores them back on `Trends`.

**Key functions**:
- `markStale()`
- `recomputeIfNeeded() async`

**Depends on**: `FoodLogRepository`, `WeightLogRepository`, SwiftData `ModelContext`.
**Used by**: `AppDelegate`, repositories (as a hook on write).

---

### `MemoryTrigger`

**Role**: Heuristic + rule-based classifier deciding whether a turn's content should
produce a `Memory` record.

**Responsibilities**:
- Cheap local rules (e.g., user stated a preference explicitly, goal change, dietary
  restriction mentioned).
- Optional "ask the model" gate for borderline cases.

**Used by**: `MemoryWriter`.

---

## `Agent/Scheduling/`

### `ScheduledJobRunner`

**Role**: BGTaskScheduler integration plus the per-job execution harness.

**Responsibilities**:
- Registers identifiers for `DailySummaryGenerator`, `SessionTrigger` (proactive
  coach prompts), and `TrendsGenerator` refresh.
- Runs each job inside a bounded time budget imposed by iOS; reschedules on
  completion.

**Key functions**:
- `register()`
- `handle(_ task: BGTask) async`
- `scheduleNext(for: JobIdentifier, at: Date)`

**Depends on**: `DailySummaryGenerator`, `SessionTrigger`, `TrendsGenerator`.
**Used by**: `AppDelegate`.

---

### `SessionTrigger`

**Role**: Drives proactive coach prompts (FR-012) — e.g., "have you logged breakfast?"

**Responsibilities**:
- Reads user notification preferences from `ProfileRepository` / settings.
- Consults `SessionConflictPolicy` to decide suppress / queue / interrupt.
- Enqueues a new turn on the orchestrator with a canned system prompt that instructs
  the model to compose the nudge and optionally a quick-log widget.

**Depends on**: `ProfileRepository`, `FoodLogRepository`, `Orchestrator`,
`SessionConflictPolicy`.
**Used by**: `ScheduledJobRunner`.

---

### `SessionConflictPolicy`

**Role**: Pure-logic decision for overlapping triggers.

**Responsibilities**:
- Answers `suppress | queue | interrupt` given a pending proactive prompt and the
  user's current state (already logged that slot? actively chatting? DND window?).

**Used by**: `SessionTrigger`.

---

## `Tools/`

### `ToolProtocol` / `ToolResult` / `ToolError`

```swift
protocol ToolProtocol {
    static var identifier: ToolIdentifier { get }
    static var schema: ToolSchema { get }
    func invoke(_ arguments: ToolArguments) async throws -> ToolResult
}
```

- `ToolResult`: structured success payload; usually JSON-serialisable for the model
  to observe in its next step.
- `ToolError`: typed error; categories include `invalidArguments`, `notFound`,
  `policyDenied`, `transient`, `permanent`.

**Used by**: `ToolCallDispatcher` (registers by `identifier`), every concrete tool.

---

### `Tools/Retrieval/`

#### `FoodSearchTool`

**Role**: The model-facing tool that searches for foods. Thin wrapper that delegates
to `FoodSearchRAG` and marshals results into `ToolResult`.

**Depends on**: `FoodSearchRAG`.
**Used by**: `ToolCallDispatcher`.

#### `FoodSearchRAG`

**Role**: Orchestrates food retrieval across four sources in precedence order per
FR-004 and `data-model.md` § "Food Search (RAG) Sources".

**Responsibilities**:
- Queries `UserHistorySource` first (SwiftData `FoodEntry`); ranked by match × `logCount`
  × recency.
- Falls through to `USDAFoodSource`, then `OpenFoodFactsSource`.
- Engages `WebSearchFallback` only when prior sources miss *and* the user has
  opted in.
- Merges results with deduplication on `(source, sourceRefId)` so a food the user has
  previously logged never appears twice.

**Key functions**:
- `search(_ query: String, limit: Int) async -> [FoodSearchCandidate]`

**Depends on**: `UserHistorySource`, `USDAFoodSource`, `OpenFoodFactsSource`,
`WebSearchFallback`.
**Used by**: `FoodSearchTool`, indirectly the Meal Card UI via the orchestrator.

#### `LookupKnowledgeTool`

**Role**: Fetches relevant knowledge-base snippets on demand during a turn.

**Depends on**: `KnowledgeGraph`, `KnowledgeSelector`.

#### Retrieval Sources

| Source | Backing store | Notes |
|--------|---------------|-------|
| `UserHistorySource` | SwiftData `FoodEntry` | `#Predicate` over `searchTokens`; ranks by match × `logCount` × recency (`lastLoggedAt`). No network. |
| `USDAFoodSource` | `usda.sqlite` (GRDB) | Read-only. Opens a shared `DatabasePool`. No writes. |
| `OpenFoodFactsSource` | `offs.sqlite` (GRDB) | Same as above. |
| `WebSearchFallback` | HTTPClient | Opt-in per `Settings`. Single network path in the whole app. |

Each source conforms to a common `FoodSearchSourceProtocol` with `search(_:limit:) async throws -> [FoodSearchCandidate]`.

**Used by**: `FoodSearchRAG`.

---

### `Tools/Action/`

All action tools share the same shape: validate arguments → run a repository
mutation → return a success payload the model can reference in its next step.

#### `LogFoodTool`

**Role**: Persists a meal log. Drives the promotion of a RAG hit into SwiftData
(FR-004a).

**Responsibilities**:
- Looks up or creates a `FoodEntry` by `(source, sourceRefId)`.
- On first log from a reference source, copies all reference `serving` rows into
  SwiftData `Serving` records under the new `FoodEntry`.
- Writes a `LoggedFood` referencing the specific `Serving` the user chose, with
  `quantity` and `meal`.
- Bumps `FoodEntry.logCount` and `lastLoggedAt`; updates `searchTokens` if the
  canonical name/detail changed; marks `Trends` stale.

**Depends on**: `FoodLogRepository`, `TrendsGenerator`.

#### `LogWeightTool`

**Role**: Persists a `WeightEntry` (start-of-day date, weight in kg).

**Responsibilities**: validation (0 < weight < 500); mark `Trends` stale.
**Depends on**: `WeightLogRepository`, `TrendsGenerator`.

#### `SetGoalsTool`

**Role**: Applies goal changes from either the chat surface or the dedicated Goals
editor screen.

**Responsibilities**:
- Accepts either `Auto` inputs (weekly change rate, activity level, ideal weight) or
  `Manual` inputs (calorie target + macro percentage triple that MUST sum to 100%).
- Recomputes derived targets in Auto mode; stores manual flags in Manual mode.
- Recomputes the projected goal-achievement date.

**Depends on**: `GoalRepository`, `ProfileRepository` (read-only).

#### `SetProfileInfoTool`

**Role**: Applies profile edits (birth year, height, biological sex, activity level,
preferred units).

**Responsibilities**:
- Validates field ranges per `data-model.md` § UserProfile.
- Triggers goal recomputation in Auto mode when inputs that affect calorie maths
  change.

**Depends on**: `ProfileRepository`, `GoalRepository`.

---

## `Knowledge/`

### `KnowledgeGraph` / `KnowledgeGraphProtocol`

**Role**: In-memory index of bundled coaching markdown files.

**Responsibilities**:
- Loaded once at app start via `KnowledgeGraphLoader`.
- Exposes typed accessors for goal-specific, skill-specific, and reference knowledge.

**Depends on**: `KnowledgeGraphLoader`, `KnowledgeIndex`.
**Used by**: `KnowledgeContextSource`, `LookupKnowledgeTool`, `KnowledgeSelector`.

### `KnowledgeGraphLoader`

**Role**: Reads `Knowledge/Resources/*.md` (bundled) into memory-resident `KnowledgeFile` structs.

### `KnowledgeIndex`

**Role**: Parses the top-level `Index.md` that declares which files exist and how
they're categorised.

### `KnowledgeFile`

**Role**: Single parsed markdown file with front-matter (type, tags, priority).

### `KnowledgeType`

**Role**: Enum with cases `.goal`, `.skill`, `.reference`. Determines which selector
strategy applies and how the file is surfaced.

### `KnowledgeSelector`

**Role**: Decides which subset of knowledge to include for a given turn / session
goal, given the context budget.

**Used by**: `KnowledgeContextSource`, `LookupKnowledgeTool`.

---

## `Data/SwiftData/`

### `ChewTheFatSchema`

**Role**: `VersionedSchema` chain that declares every `@Model` type the app has ever
shipped, plus the app's `MigrationPlan`.

**Responsibilities**:
- Single source of truth for "what models exist in version N". Each shipped app
  version gets its own `VersionedSchema` enum namespace.
- `MigrationPlan.stages` enumerates every transition between adjacent schema
  versions (either `.lightweight` or `.custom(fromVersion:toVersion:willMigrate:
  didMigrate:)`).

**Used by**: `ModelContainerProvider`.

### `ModelContainerProvider`

**Role**: Builds the app's single `ModelContainer` (plus an in-memory variant for
previews and tests).

**Responsibilities**:
- Constructs the container with the current `Schema` and `MigrationPlan`.
- Snapshots the store file before opening so a migration failure can be recovered
  without data loss (research.md §7).
- Exposes the main-actor `ModelContext` via `.modelContainer(...)` on the root scene
  and hands out `ModelActor`-backed background contexts for heavy reads/writes.

**Depends on**: `SwiftData` framework, `ChewTheFatSchema`.
**Used by**: `ChewTheFatApp`, every repository.

### `ModelContextFactory`

**Role**: Thin convenience over `ModelContainerProvider` with helpers for common
patterns: create a background `ModelActor` bound to the app's container, perform
and save within a task, observe changes for `TrendsGenerator`. No business logic.

**Used by**: every repository, `TrendsGenerator`.

---

## `Data/Models/` (SwiftData `@Model` types)

Shapes, constraints, and relationships are defined in **`data-model.md`**. This doc
does not duplicate field lists. Each file declares a single `@Model` class with
typed stored properties and typed relationships.

**One-line roles**:

- `UserProfile.swift` — singleton profile record.
- `UserGoal.swift` — singleton goals record (note: `UserGoal` singular in file
  names, conceptual `UserGoals` in spec).
- `Session.swift` — a chat thread; owns ordered messages.
- `Message.swift` — one entry in a session; owns ordered `MessageWidget`s.
- `MessageWidget.swift` — one widget attached to a message (see `WidgetRenderer`).
  Its `payload` stores **references** into SwiftData (`loggedFoodIds`, `date`,
  `dateRange`), not dense snapshots, so widgets stay consistent with later edits.
- `FoodEntry.swift` — user's food catalog row (RAG-promoted or manual). Carries
  `searchTokens` for `#Predicate`-based history search.
- `Serving.swift` — a measurement under a `FoodEntry`.
- `LoggedFood.swift` — a meal-log row referencing a `FoodEntry` + `Serving`.
- `WeightEntry.swift` — a single weigh-in.
- `DailySummary.swift` — agent-authored daily digest.
- `Trends.swift` — singleton pre-aggregation blob for charts.
- *(If the `Memory` entity is modelled, it lives here as `Memory.swift`.)*

These classes are **never** exposed to the UI directly. Views consume Domain types
returned from repositories.

---

## `Data/Repositories/`

All repositories are MainActor-friendly façades over SwiftData. Every read returns
a Domain type (not a `@Model` instance). Every write accepts a Domain type and is
idempotent where possible. Long-running queries are performed inside a `ModelActor`
and their Domain-type results are returned to the main actor.

### `SessionRepositoryProtocol` / `SessionRepository`

**Responsibilities**:
- CRUD on `Session`; paginated message fetch; append-message; start-new-session.
- Emits change notifications the `SessionStateManager` subscribes to.

**Key functions**:
```swift
func recent(_ limit: Int) async -> [SessionSummary]
func messages(for session: Session.ID, pageBefore: Date?) async -> [Message]
func append(message: Message, widgets: [MessageWidget], to: Session.ID) async throws
func create(named: String?) async -> Session
```

**Used by**: `Orchestrator`, `ChatViewModel`, `DashboardViewModel`.

### `FoodLogRepositoryProtocol` / `FoodLogRepository`

**Responsibilities**:
- Writes and queries `LoggedFood` (with its mandatory `FoodEntry` + `Serving` refs).
- Encapsulates the "promote a reference-DB hit into SwiftData" transaction.
- Exposes the history/search hook for `UserHistorySource`.

**Key functions**:
```swift
func log(_ request: LogFoodRequest) async throws -> LoggedFood
func entries(on date: Date) async -> [LoggedFood]
func entriesByMeal(on date: Date) async -> [MealType: [LoggedFood]]
func searchCatalog(_ query: String, limit: Int) async -> [FoodSearchCandidate]
func upsertFoodEntry(_ spec: FoodEntrySpec, servings: [ServingSpec]) async throws -> FoodEntry
```

**Used by**: `LogFoodTool`, `UserHistorySource`, `ChatViewModel`, `DashboardViewModel`.

### `WeightLogRepositoryProtocol` / `WeightLogRepository`

**Responsibilities**: CRUD on `WeightEntry`; range queries for the Trajectory chart.

**Used by**: `LogWeightTool`, `DashboardViewModel`, `TrendsGenerator`.

### `GoalRepositoryProtocol` / `GoalRepository`

**Responsibilities**:
- CRUD on the singleton `UserGoals`.
- Derivation helpers: projected goal date, default macro grams from percentages and
  calorie target.

**Used by**: `SetGoalsTool`, `GoalsEditView`, `DashboardViewModel`.

### `ProfileRepositoryProtocol` / `ProfileRepository`

**Responsibilities**:
- CRUD on the singleton `UserProfile`.
- `eulaAcceptedAt` gating: writes fail until EULA accepted (FR-011).
- Age derivation from birth year (FR-026).

**Used by**: `SetProfileInfoTool`, `ProfileEditView`, Onboarding views,
`ProfileContextSource`.

### `MemoryRepositoryProtocol` / `MemoryRepository`

**Responsibilities**: CRUD on `Memory` and `DailySummary`.

**Used by**: `MemoryWriter`, `DailySummaryGenerator`, `MemoryContextSource`.

---

## `Data/LocalDatabases/`

### `USDAFoodDB`

**Role**: Read-only GRDB wrapper over bundled `usda.sqlite`.

**Responsibilities**:
- Opens a `DatabasePool`.
- Exposes query helpers: `matches(_ query: String, limit: Int) async -> [ReferenceFood]`.
- Never writes; opens the file with `.readOnly` configuration.

**Used by**: `USDAFoodSource`.

### `OpenFoodFactsDB`

**Role**: Same as USDA, backed by `offs.sqlite`.

**Used by**: `OpenFoodFactsSource`.

### `DatabaseMigrator`

**Role**: No-op at runtime for the reference DBs (they're immutable); present so
the build-time database preparation pipeline has a single canonical migration spec.

---

## `Domain/`

All types here are plain Swift values. **No imports** of SwiftData, SwiftUI, or
GRDB. This is the seam that lets the agent and tools be tested without spinning up a
persistence stack or rendering a view.

- `SessionGoal` — enum: `.logMeal`, `.logWeight`, `.userInsights`, etc. Drives
  `KnowledgeSelector` and agent prompt hints.
- `WidgetIntent` — tagged enum: `.mealCard(MealCardPayload)`,
  `.weightGraph(WeightGraphPayload)`, `.macroChart(MacroChartPayload)`,
  `.quickLog(QuickLogPayload)`. Produced by `WidgetIntentResolver`, consumed by
  `WidgetRenderer`.
- `NutritionFacts` — struct of macros (calories + g of protein/carbs/fat/fiber).
  Used for Meal Card totals and macro summaries.
- `MealType` — enum: `.breakfast`, `.lunch`, `.dinner`, `.snack`.
- `ActivityLevel` — enum: `.sedentary`, `.light`, `.moderate`, `.heavy`.
- `WeeklyChangeTarget` — value wrapper enforcing the constitution range
  [−0.7, +0.45] kg/week.
- `FoodSource` — enum: `.usda`, `.openFoodFacts`, `.web`, `.manual`. Mirrors
  `FoodEntry.source`.

---

## `UI/Chat/`

### `ChatView`

**Role**: The primary user-facing surface. A SwiftUI view hosting a message list,
an input bar, and the overlay for the hamburger menu / dashboard affordance.

**Depends on**: `ChatViewModel`, `MessageListView`, `ChatInputBar`,
`SuggestedRepliesView`.

### `ChatViewModel`

**Role**: Feeds `ChatView` off `Orchestrator.TurnEvent` streams.

**Responsibilities**:
- Submits user messages, tracks the typing indicator state, appends streamed
  tokens to an in-memory message buffer, hands widget intents to `WidgetRenderer`.
- Persists user-confirmed widget actions by calling the relevant Action tool
  indirectly via the orchestrator.

**Depends on**: `OrchestratorProtocol`, `SessionRepository`, `SessionStateManager`,
`WidgetRenderer`.
**Used by**: `ChatView`.

### `MessageListView` / `MessageBubble`

**Role**: Renders message history. `MessageBubble` draws text; widget-carrying
messages delegate to `WidgetRenderer`.

### `ChatInputBar`

**Role**: Text field + send button. Mic and camera icons from the Figma are
**deferred to post-v1** (per the 2026-04-21 clarification); if rendered for visual
parity with the design, they MUST be disabled and accept no input. Emits submit
events to `ChatViewModel`.

### `SuggestedRepliesView`

**Role**: Renders contextual quick-reply chips (e.g., "Lose weight" / "Maintain" /
"Gain weight" in onboarding). Emits tap events that the `ChatViewModel` treats as
if the user had typed the text.

---

## `UI/Widgets/`

Widgets are **dual-use**: the same view types render both in the chat thread (via
`WidgetRenderer` + `WidgetIntent`) and on the Dashboard (via live repository
queries). Each widget ViewModel exposes two factory entry points so the same view
can be driven from either side without branching at the view layer.

**Widget data binding contract** (resolves the 2026-04-21 "live vs snapshot"
clarification):
- **Chat path**: `MessageWidget.payload` carries **references** into SwiftData —
  e.g., `MealCardPayload.loggedFoodIds`, `MacroChartPayload.date`,
  `WeightGraphPayload.dateRange`. The ViewModel's `.snapshot(payload:)` factory
  resolves those references against the store at render time. If the user edits an
  underlying log, every chat widget that references it reflects the edit on next
  render.
- **Dashboard path**: the ViewModel's `.live(repo:)` factory binds the view to a
  repository observation (SwiftData change tokens). The Dashboard reacts
  immediately to writes without needing a `MessageWidget` to mediate.

Payloads deliberately do NOT contain denormalised nutrition, macro totals, or
computed chart series — those are derived at render time from SwiftData so there
is a single source of truth across surfaces.

### `WidgetRenderer`

**Role**: Dispatch function from a `WidgetIntent` to the correct SwiftUI widget view
using the chat path (`.snapshot(payload:)` factory).

**Responsibilities**:
- One case per intent type.
- Holds no mutable state; stateless pure view-builder.
- The registry here must match the set of widget types accepted by
  `WidgetIntentResolver` — one source of truth, validated at startup.

**Depends on**: `MealCardView`, `WeightGraphView`, `MacroChartView`, and the
forthcoming `QuickLogView`.
**Used by**: `MessageListView` (for each `MessageWidget` on a bot message, in
`order`). The Dashboard bypasses this file and instantiates the same widget views
directly with `.live(repo:)`.

### Meal Card (`MealCardView` / `MealCardViewModel`)

**Role**: Renders a logged-meal suggestion with a slot header, per-item rows
(quantity + serving dropdown + food name + kcal), and inline Protein/Carbs/Fat
progress bars.

**Responsibilities** (ViewModel):
- `.snapshot(payload:)` — chat path; resolves `loggedFoodIds` against
  `FoodLogRepository` at render time. Holds a mutable local copy of the resolved
  items so per-row edits update totals instantly.
- `.live(meal:date:repo:)` — dashboard path; observes the repo for changes to that
  date + meal slot.
- On confirm, builds a `LogFoodRequest` and submits through the orchestrator
  (chat path) or directly through `FoodLogRepository` (dashboard path).

**Depends on**: `NutritionFacts`, `FoodLogRepository` (indirectly via orchestrator
on the chat path; directly on the dashboard path), design-token components.

### Weight Graph (`WeightGraphView` / `WeightGraphViewModel`)

**Role**: Chart of logged weights with goal trajectory line. Used **both** inline
in chat (`.snapshot(payload: WeightGraphPayload)` where the payload is a
`dateRange`) and as the Dashboard's Trajectory panel (`.live(repo:)`).

**Responsibilities**:
- Reads the pre-computed `Trends.weightTrendPayload` when available and fresh;
  falls back to a live fetch via `WeightLogRepository`.
- Draws past (solid fill) and projected (faded fill) regions.
- Respects Reduce Motion for fill/line animations (Principle VI).

**Depends on**: Swift Charts, `WeightLogRepository`, `GoalRepository`.

### Macro Chart (`MacroChartView` / `MacroChartViewModel`)

**Role**: Today's-calories headline + per-macro progress bars + macro overage
emphasis. Used both as an in-chat widget (payload = a `date`) and inside the
Dashboard's Today panel (live repo binding).

**Depends on**: `FoodLogRepository`, `GoalRepository`.

---

## `UI/Dashboard/`

The Home Dashboard is a separate screen (US7, FR-018) reachable from the chat
surface. It is **not** a chat widget; it has its own scene-level view hierarchy
and navigates to the dedicated Goals / Profile / Settings editors. All data
bindings here are **live**: the Dashboard reacts to underlying SwiftData writes
without user refresh.

### `DashboardView`

**Role**: Top-level Dashboard screen. Composes the Trajectory panel (a live-bound
`WeightGraphView`), the `TodayPanelView`, `DashboardNavChipsView`, and the
`ChatHistoryListView`.

**Responsibilities**:
- Layout and scroll management only. No data fetching; all data comes from
  `DashboardViewModel`.
- Empty states per spec edge cases: no weight history → Trajectory prompts to log
  first weight; no prior sessions → Chat history section hidden.

**Depends on**: `DashboardViewModel`, `WeightGraphView` (via `.live(repo:)`),
`TodayPanelView`, `DashboardNavChipsView`, `ChatHistoryListView`.

### `DashboardViewModel`

**Role**: Aggregates data from multiple repositories into a single observable
object the view binds to. Owns the change-observation subscriptions so the
individual widgets don't each need their own.

**Responsibilities**:
- Subscribes to `WeightLogRepository`, `FoodLogRepository`, `GoalRepository`, and
  `SessionRepository` change streams.
- Derives the Today panel inputs (remaining-calories, per-macro totals, today's
  meals grouped by slot).
- Formats the projected goal-achievement date from current weight + ideal weight +
  weekly-change rate.

**Depends on**: `WeightLogRepository`, `FoodLogRepository`, `GoalRepository`,
`SessionRepository`, `NutritionFormatter`, `WeightFormatter`.

### `TodayPanelView`

**Role**: Renders the "N Calories left" headline, per-macro progress bars
(Protein / Carbs / Fat, each labelled "consumed/target g"), and today's meal
entries grouped by slot with the slot's total calories on the right.

**Responsibilities**:
- Re-uses `MacroChartView.live(repo:)` for the macro progress bars — same
  component as the chat surface.
- Visually distinguishes an exceeded macro (Principle III token for warning
  state; no hex literal).

**Depends on**: `MacroChartView`, `FoodLogRepository`, `GoalRepository`.

### `DashboardNavChipsView`

**Role**: Renders the Goals / Profile / Settings entry chips. Tap pushes the
corresponding dedicated editor (`GoalsEditView`, `ProfileEditView`,
`SettingsView`).

### `ChatHistoryListView`

**Role**: List of prior sessions (name + relative-date stamp of last message,
ordered most-recent first). Tap opens the session via `SessionStateManager`.
Hidden when there are no prior sessions (per edge case).

**Depends on**: `SessionRepository`, `SessionStateManager`.

---

## `UI/Onboarding/`

### `OnboardingCoordinator`

**Role**: Drives the first-run onboarding flow, which lives **inside** the chat
thread (FR-010, US1). Not a separate wizard — just a specialised coordinator that
enqueues system-authored prompts in the orchestrator with a scripted ordering.

**Responsibilities**:
- Tracks which onboarding steps are complete (units, sex/age/height, EULA, goals).
- Resumes mid-flow on relaunch (US1 scenario 6).

**Depends on**: `Orchestrator`, `ProfileRepository`, `GoalRepository`.

### `EULAView` / `ProfileSetupView` / `GoalSetupView`

**Role**: Widget views surfaced as `MessageWidget`s during onboarding (the EULA is a
special inline widget; profile/goal setup is driven by suggested-reply chips and
free-text entry). They are *not* full-screen modals — they render inline in the chat
thread.

---

## `UI/Settings/`

### `SettingsView`

**Role**: Dedicated Settings editor (US6 scenario 5, FR-024). Units toggle,
notifications schedule, height edit.

### `ProfileEditView`

**Role**: Dedicated Profile editor (birth year, height, biological sex). Reachable
from Dashboard nav chip.

### `GoalsEditView`

**Role**: Dedicated Goals editor with `Auto | Manual` toggle, activity-level and
weekly-change dropdowns, ideal-weight entry, manual macro percentage sliders (must
sum to 100%).

**Depends on**: `GoalRepository`, `ProfileRepository`.

---

## `UI/Shared/DesignSystem/`

### `Colors`

**Role**: Typed accessors for named `Assets.xcassets` color entries (Principle III).
Layer of indirection so Swift code never hard-codes hex; colour values live in the
asset catalog and update automatically for Dark Mode.

### `Typography`

**Role**: Dynamic Type-aware font styles. All text styles flow through here so
FR-016a Dynamic Type support is uniform.

### `Spacing`

**Role**: The canonical `DesignTokens.swift` — constants for spacing, padding, corner
radii, font sizes. Magic numbers are prohibited anywhere else in the code base
(Principle III).

### Shared Components (`PrimaryButton`, `Card`, `ValueRow`)

**Role**: SwiftUI components composed exclusively of `Colors` + `Spacing` +
`Typography` tokens, giving visually uniform primitives for all feature surfaces.

---

## `Services/`

### `Logger`

**Role**: Thin wrapper around `os.Logger` with subsystem/category conventions so
log output can be filtered in Console.app.

### `AnalyticsClient`

**Role**: Local-only telemetry sink. Per constitution Principle I, no event leaves
the device. This type exists so instrumentation calls have a consistent API (even
if the initial implementation just writes to a local ring buffer or no-ops).

### `HTTPClient`

**Role**: URLSession wrapper used **only** by `WebSearchFallback` (the single
permitted network path).

### `NetworkReachability`

**Role**: Observer for connectivity. Used to disable the web-search fallback UI
when offline.

### `Keychain`

**Role**: Secure storage primitive. Not expected to hold much in v1 (no server
credentials), but exists for any future API key the user may add.

### `APIKeyProvider`

**Role**: Resolves API keys for optional services (e.g., a web search provider) from
`Keychain`. Fails closed if absent.

---

## `Utilities/`

### Extensions (`Date+Extensions`, `String+Extensions`, `Decimal+Locale`)

**Role**: Focused helpers; each extension file holds a small, well-named API
surface. No dumping-ground helpers.

### Formatters

- `NutritionFormatter` — localised rendering of calories, grams, and macro percentages.
- `WeightFormatter` — metric/imperial display with the user's preferred units,
  respecting canonical kg storage.

**Used by**: widgets, Dashboard, Goals editor.

### `AsyncDebouncer`

**Role**: Small concurrency primitive used in the `ChatInputBar` and
`FoodSearchRAG` to coalesce rapid user input into a single query.

---

## Cross-Cutting Notes

### Actor / concurrency model

- Project default is `@MainActor` (Swift build setting
  `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor`).
- Types that do heavy work off the main actor must be explicitly `nonisolated` or
  implemented as Swift `actor`s. Candidates: `ModelClient`, `FoodSearchRAG`,
  `TrendsGenerator`, `DailySummaryGenerator`, `USDAFoodDB`, `OpenFoodFactsDB`.
- The `Orchestrator` itself stays on the main actor; it hands heavy work to
  collaborators and marshals results back through `AsyncStream`.

### Error taxonomy

- Tool errors go through `ToolError`.
- Repository errors go through a small `RepositoryError` enum (not documented in
  detail here).
- Turn-level errors surface as `TurnEvent.failed(Error)` with the underlying
  category preserved so UI can offer a contextual retry.

### Threading invariants

- SwiftData's main `ModelContext` stays on the main actor. Heavy reads and batched
  writes run inside a `ModelActor` and return Domain-typed values to the main
  actor.
- All reference-DB reads go through GRDB `DatabasePool` (its concurrency story is
  well-suited to a read-only store and keeps reference access off SwiftData's
  context entirely).
- UI code must never cross the GRDB / SwiftData boundary directly — only the RAG
  tool does so, and only by copying rows into SwiftData (FR-004a).

### "Used by" quick-index

| Consumer | Primary dependencies |
|----------|----------------------|
| `ChatViewModel` | `Orchestrator`, `SessionRepository`, `WidgetRenderer` |
| `DashboardViewModel` | `WeightLogRepository`, `FoodLogRepository`, `GoalRepository`, `SessionRepository`, `WeightGraphView.live(repo:)`, `MacroChartView.live(repo:)` |
| `OnboardingCoordinator` | `Orchestrator`, `ProfileRepository`, `GoalRepository` |
| `Orchestrator` | `ContextManager`, `ModelClient`, `ToolCallDispatcher`, `SessionRepository`, `MemoryWriter` |
| `FoodSearchRAG` | `UserHistorySource`, `USDAFoodSource`, `OpenFoodFactsSource`, `WebSearchFallback` |
| `LogFoodTool` | `FoodLogRepository`, `TrendsGenerator` |
| `ScheduledJobRunner` | `DailySummaryGenerator`, `SessionTrigger`, `TrendsGenerator` |
