# Research: Downward Trajectory — iOS Health Coach App

**Branch**: `001-ios-health-coach-app` | **Date**: 2026-04-20
**Phase**: 0 — Resolves all NEEDS CLARIFICATION items from Technical Context

---

## 1. On-Device LLM Framework

**Decision**: Apple MLX-Swift via the `ml-explore/mlx-swift-lm` SPM package
(`MLXLLM` + `MLXLMCommon`).

**Rationale**:
- First-class Apple-Silicon Metal acceleration, maintained by Apple's MLX team.
  Production-quality on iOS 26 (the constitution's minimum target) — past the
  early-version concerns that made llama.cpp the safer pick a year ago.
- `mlx-swift-lm` ships a clean, dedicated SPM surface (the prior
  `mlx-swift-examples` repo bundled experimental tooling alongside the library;
  the dedicated package drops the noise).
- Native streaming via `ChatSession.respond(to:)` satisfies SC-002a (first token
  ≤ 3 s, full response ≤ 15 s) on A15+ devices.
- Tokenizer + downloader integration is provided through `huggingface/swift-huggingface`
  + `huggingface/swift-transformers` via the `MLXHuggingFace` integration package,
  which composes directly with the model bootstrap path described under
  "Model delivery" below.

**Recommended model**: an `mlx-community` 4-bit quantised checkpoint targeting
1B–3B parameters — the README's `LLMRegistry.gemma3_1B_qat_4bit` is a reasonable
default. Final selection is validated empirically in M2 against SC-002a on an
A15+ device before TestFlight submission.

**Alternatives considered**:
- **llama.cpp (ggerganov) via Swift bindings (GGUF)**: was the prior decision.
  As of 2026-04 the upstream `llama.cpp` repository no longer ships a
  `Package.swift` at its root; the documented SPM route 404s. Community wrappers
  exist but add a maintenance dependency we'd own. MLX-Swift is the lower-risk
  default now that iOS 26 is our floor.
- **Apple Foundation Models (WWDC 2025)**: Apple's first-party on-device models;
  not customisable for health-coaching system prompts; limited tool-calling
  surface. Revisit for future model-switching once the API matures.

**Model delivery** *(amended 2026-04-22 — supersedes the earlier same-day
"bundled via Git LFS" decision)*:
- The model is **fetched on first launch from a public model registry**
  (Hugging Face Hub) via `huggingface/swift-huggingface` + `swift-transformers`,
  integrated through `MLXHuggingFace`. The pinned model identifier is held in
  Swift code (single source of truth), not user-editable.
- **Bootstrap flow**:
  1. App launch with no cached model → static SwiftUI welcome + EULA screen
     (no LLM required, no network used).
  2. EULA acceptance → `ModelBootstrapView` shows explicit progress UI
     (download bytes, throughput, cancel-and-retry-later) and invokes the
     downloader. No user data is transmitted — the request payload is the
     pinned model identifier only.
  3. On completion the weights are written to `Application Support/Models/`
     with `URLResourceKey.isExcludedFromBackupKey = true`; the conversational
     onboarding turn begins.
  4. Subsequent launches read from cache and never re-fetch unless the pinned
     model identifier changes in a new app build.
- **Rationale for fetch-over-bundle**:
  - **Install size**: a 4-bit quantised ~1B model is ~700 MB; a 3B variant is
    ~2 GB. Bundling pushes the .ipa close to the App Store cellular cap and
    forces every install through Apple's WiFi-only prompt on cellular.
  - **Update cadence**: model identifier changes can ship without a full App
    Store review cycle (the bootstrap re-fetches when the pinned id changes).
  - **No developer-run server required**: Hugging Face Hub serves public weights
    over HTTPS; we hold no infrastructure or billing relationship.
- **Trade-offs accepted**:
  - **First-launch network requirement**: the app cannot complete onboarding
    offline. This is the explicit constitution-amended carve-out (1.1.0 §I).
  - **Bootstrap progress UI**: a one-screen progress view with retry/cancel must
    be implemented and tested.
  - **Cache failure modes**: corrupt cache, mid-download interruption, and
    storage-full conditions need explicit handling — `ModelBootstrapper` owns
    that surface.
- **Prior decisions** *(superseded)*: the original 2026-04-20 plan fetched from a
  developer-run CDN; the 2026-04-22 morning revision flipped to bundled-via-Git LFS.
  Both are retained here only as historical context. The 1.1.0 amendment makes
  the public-registry fetch authoritative.

---

## 2. SQLite Access Library for Food Reference Databases

**Decision**: GRDB.swift

**Rationale**:
- Type-safe Swift API; Codable-compatible record types reduce boilerplate.
- Built-in FTS5 (full-text search) extension is critical for fast food name search
  across USDA and Open Food Facts tables (SC-003: results in ≤ 2s).
- Excellent performance on read-heavy workloads; no write lock contention since
  food reference DBs are read-only.
- Actively maintained; widely used in iOS apps with SQLite.

**Alternatives considered**:
- SQLite.swift: Good, but lacks built-in FTS5 helpers; more boilerplate for
  complex queries.
- Raw SQLite3 C API: Maximum control, but type safety and maintenance cost
  are prohibitive.

---

## 3. Food Reference Database Curation & Bundling

**Decision**: Bundle curated subsets of both databases in the app.

**USDA FoodData Central**:
- Use the "Foundation Foods" + "SR Legacy" datasets (~120 MB combined after SQLite
  conversion). These cover ~350k foods with reliable macro data.
- Exclude "Survey (FNDDS)" and "Experimental" datasets (low coverage, large size).
- Bundle directly in the app's `Resources/` folder; accessed read-only at runtime.

**Open Food Facts**:
- The full OFFs dump exceeds 2 GB; use a curated subset filtered to records with
  complete macro fields (calories, protein, carbs, fat) → ~80 MB after filtering.
- Separate SQLite file; GRDB opens both DBs in a DatabasePool for parallel reads.

**FTS5 virtual tables** are pre-built at database preparation time (build-time script)
so the app does not need to build indexes at runtime.

**Web search fallback**: When both local DBs miss a query, and the user has enabled
the opt-in setting, the app performs a structured web search for nutritional data.
The agent presents the result for manual confirmation before logging. This is the
only network operation in the app.

---

## 3a. Food Storage Boundary (Reference ↔ SwiftData)

**Decision**: The bundled `usda.sqlite` and `offs.sqlite` are **read-only RAG
sources** only. Any food the user logs (or manually enters) is promoted into
SwiftData as a `FoodEntry` + `Serving` pair; every subsequent read comes from
SwiftData.

**Rationale**:
- **Historical integrity**: if a reference DB is refreshed in a later app version, a
  user's prior macro totals must not shift. Copying the serving rows into SwiftData at
  log time freezes the nutrition values for that log.
- **RAG recency signal**: storing the user's catalog in SwiftData gives the RAG tool
  a first-class source ranked by `logCount` + `lastLoggedAt`. Returning foods surface
  above generic reference hits, which is the dominant logging pattern ("I ate the
  same breakfast again").
- **Uniform display path**: UI code reads only from SwiftData repositories. No join
  between GRDB and SwiftData is needed at render time, simplifying threading and
  removing a class of cross-store consistency bugs.
- **Manual-entry symmetry**: user-authored foods use the exact same `FoodEntry` /
  `Serving` models as promoted foods, with `source = "manual"`. One code path for
  both.

**Mechanism**:
- RAG retrieval order: `UserHistorySource` (SwiftData) → `USDAFoodSource` (GRDB) →
  `OpenFoodFactsSource` (GRDB) → `WebSearchFallback` (opt-in network).
- Deduplication on promotion: `(source, sourceRefId)` is unique in SwiftData — a
  second log of the same reference food reuses the existing `FoodEntry`, bumps
  `logCount` and `lastLoggedAt`, and does not re-copy the servings.

**Alternatives considered**:
- Keep reference DBs as the source of truth and store only an ID in `LoggedFood`:
  rejected because reference-DB updates could silently alter historical logs, and the
  UI would need cross-store joins at every render.
- Denormalise per-serving macros onto `LoggedFood`: rejected as schema debt — it
  bloats the log table, prevents users from editing the serving definition of a food
  they own, and makes the RAG history source harder to implement.

---

## 4. Orchestrator & Streaming Architecture

**Decision**: Custom Swift orchestrator wrapping llama.cpp streaming with tool-call
interception before UI delivery.

**Flow**:
```
User message
  → ContextManager (builds prompt with session history + memory + tool schemas)
  → Orchestrator.run()
      → llama.cpp stream (tokens arrive via AsyncStream<String>)
      → ToolCallParser (stateful; buffers between <tool_call> … </tool_call> tags)
          → on tool call detected: pause text stream, execute tool, resume
          → tool result → WidgetFactory → SwiftUI Widget (inserted as chat message)
      → text tokens → ChatViewModel (published to UI as they arrive)
  → Session log updated in Core Data
```

**Why tag-based tool calls** (not JSON function-calling schema):
- Smaller open models reliably produce tag-delimited tool calls when fine-tuned for it
  or prompted carefully; pure JSON function-calling is less reliable at 3B scale.
- Tag-based parsing is simpler to implement in Swift and has no regex backtracking risk.

**Tool call format** (embedded in system prompt schema, invisible to user):
```
<tool_call>
{"tool": "log_food", "params": {"items": [...], "meal": "Breakfast"}}
</tool_call>
```

**Widget injection**: When the orchestrator resolves a tool result that includes a
visual payload (Meal Card, Macro Chart, Weight Graph), it inserts a `WidgetMessage`
into the `ChatViewModel`'s message list rather than text. The `ChatView` renders
`WidgetMessage` as a native SwiftUI view, not as bubble text.

---

## 5. Context Manager Strategy

**Decision**: Sliding window + summarisation, managed by `ContextManager`.

**Rationale**: On-device models have limited context windows (typically 4k–8k tokens).
The `ContextManager`:
- Maintains the full session in Core Data.
- Feeds the model only the last N messages that fit within the context budget.
- When session history exceeds the budget, the agent is prompted to produce a
  `DailySummary` which replaces older messages in the context window.
- Agent `Memories` (persistent facts about the user: preferences, coaching notes)
  are always included in the system prompt preamble regardless of window size.

---

## 6. Scheduled Jobs

**Decision**: iOS `BGTaskScheduler` (Background Task framework).

**Rationale**:
- `BGAppRefreshTask` for periodic check-ins (e.g., "Have you logged breakfast?").
- On trigger, the app wakes in background, checks whether the relevant meal slot
  has been logged today, and if not, fires a local `UNUserNotificationCenter`
  notification that deep-links back into the chat with a pre-seeded prompt.
- No network required; all data checks are against Core Data.

---

## 7. SwiftData Schema & Migration Strategy

**Decision**: User data is persisted with SwiftData. The app owns a single
`ModelContainer` built from a `VersionedSchema` chain and a `MigrationPlan`.
Additive or lightweight schema changes (new attribute, relaxed constraint, renamed
property with `@Attribute(originalName:)`) ride SwiftData's automatic inference.
Breaking changes are expressed as a new `VersionedSchema` with an explicit
`MigrationStage.custom(...)` that runs a `willMigrate` / `didMigrate` pair.

**Why SwiftData (not Core Data)**:
- iOS 26.0+ baseline (constitution 1.0.1) puts us past every early-SwiftData issue
  — three full OS versions after SwiftData's introduction.
- `@Model` types match the project's Swift-first concurrency defaults
  (`SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor`) and compose cleanly with
  `ModelActor` for background work.
- Apple is investing in SwiftData; Core Data is maintenance-only. Staying on the
  actively-invested stack reduces long-tail platform-drift risk.
- The scaffold already uses SwiftData; flipping to Core Data would be throwaway
  work.

**Trade-offs accepted**:
- **No native FTS5.** SwiftData exposes no FTS5 virtual-table surface. `FoodEntry`
  keeps a `searchTokens: String` derived attribute; `UserHistorySource` queries it
  via `#Predicate` with `.contains`. Adequate for personal catalog sizes; a
  supplementary GRDB FTS5 index over the same SQLite file is the documented escape
  hatch if needed later.
- **Less expressive migrations.** `MigrationPlan` does not cover every transform
  `NSMappingModel` does. For anything pathological we fall back to pulling rows
  into a background context, transforming in Swift, and writing into the new
  schema — still simpler than Core Data for typical shape changes.

**Process for breaking changes**:
1. Define the new `VersionedSchema` alongside the prior one; both compile into the
   app so migration code can reference both schemas' types.
2. Add a `MigrationStage.custom(fromVersion:toVersion:willMigrate:didMigrate:)` to
   `MigrationPlan` that transforms data as needed.
3. Unit-test the migration end-to-end against fixtures of every previously-shipped
   schema version; block release if any path fails.

**Failure policy**: on migration error the app MUST surface a recoverable error
dialog and MUST NOT wipe the store. The pre-migration store file is snapshotted
before the `ModelContainer` is opened; on failure the app boots against the
snapshot and prompts the user to retry (or contact support with an exportable
diagnostic bundle — export itself is post-v1).

---

## 8. Design Token Implementation

**Decision**: `DesignTokens.swift` as a `enum`-namespaced constants file.

```swift
enum Spacing {
    static let xs: CGFloat = 4
    static let sm: CGFloat = 8
    static let md: CGFloat = 16
    static let lg: CGFloat = 24
    static let xl: CGFloat = 32
}

enum Radius {
    static let card: CGFloat = 12
    static let button: CGFloat = 8
    static let pill: CGFloat = 20
}
```

Colors are defined as `Color("colorName")` referencing `Assets.xcassets` named
color sets with Light / Dark appearance variants. No hex literals in Swift source.

All SF Symbol usage goes through a centralised `AppIcon` enum:
```swift
enum AppIcon {
    static let chat = "bubble.left.and.bubble.right"
    static let weight = "scalemass"
    static let food = "fork.knife"
    // ...
}
```

---

## 9. Xcode Project Structure Decision

**Decision**: Single Xcode target (no SPM multi-package monorepo) with feature-folder
organisation inside the main app target. Test targets are separate.

**Rationale**: The app is a single deployable unit with no reusable library surface.
Adding SPM packages for internal code would add unnecessary complexity (Constitution
Principle: simplicity; no over-engineering).
