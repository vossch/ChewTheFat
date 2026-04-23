# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project

**ChewTheFat** (codename "Downward Trajectory") — iOS agentic food-logging & health-coach app. An on-device LLM drives a chat interface; the user logs meals and weight through natural language, and the agent renders interactive widgets (Meal Card, Macro Chart, Weight Graph) inline.

The current repo is still the fresh Xcode 26 SwiftUI + SwiftData template — the real architecture described below (`Specs/file-architecture.md`) has not been built yet. Bundle id `com.PixelKinetics.ChewTheFat`. iPhone only, v1.

**Authoritative specs** live in `Specs/`:
- `constitution.md` — six non-negotiable principles (read first)
- `spec.md` — user stories, functional requirements, success criteria
- `data-model.md` — SwiftData models + GRDB food-reference schema
- `file-architecture.md` — target Xcode project layout
- `research.md` — technology decisions
- `code-documentation.md` — per-module responsibilities and collaborators
- `implementation-plan.md` — milestone sequencing, captured decisions, per-milestone deliverables

## Build / Run

Open `ChewTheFat.xcodeproj` in Xcode and run, or from the CLI:

```bash
xcodebuild -project ChewTheFat.xcodeproj -scheme ChewTheFat \
  -destination 'platform=iOS Simulator,name=iPhone 16' build
xcodebuild -project ChewTheFat.xcodeproj -scheme ChewTheFat clean
```

No tests exist yet. When a test target is added, run with `-destination ... test` and a single test via `-only-testing:ChewTheFatTests/ClassName/testMethod`. The constitution requires XCTest + XCUITest and SwiftLint enforced in CI; neither is wired up yet.

## Constitution — hard rules (from `Specs/constitution.md`)

These supersede any other convention. Violating them requires an explicit Complexity Tracking entry in a feature plan.

1. **Local-first.** All compute, storage, and LLM inference run on-device. No user data or inference leaves the device. The only permitted network feature is the **opt-in** web-search food fallback; it must be isolated from core pipelines.
2. **Native components first.** Use SwiftUI/UIKit before building anything custom. Custom components must meet the same a11y bar as native (VoiceOver, Dynamic Type, Reduce Motion).
3. **Design system discipline.**
   - Colors: named entries in `Assets.xcassets` with semantic names (`colorBackgroundPrimary`, not `colorGray100`). **Hard-coded hex/RGB in Swift is prohibited.**
   - Spacing/sizing/corner radius/font size: constants in `DesignTokens.swift`. **Magic numbers in layout are prohibited.**
   - Icons: **SF Symbols only** — no third-party icon libs, no bundled SVG/raster icons.
4. **Conversational agent is the primary UI.** Chat messages + structured widgets. Widget types are a shared schema; the **orchestrator must intercept widget payloads before they reach the chat view** and render native components. **Tool calls and internal reasoning must never be shown to the user.**
5. **Frictionless logging.** Food search hits local USDA + Open Food Facts SQLite. Macros auto-derive from logged entries. No logging action exceeds **three taps** from the chat screen.
6. **Beautiful charts.** Swift Charts (native) only, unless impossible. All charts use design tokens, support Dark Mode and Dynamic Type, and suppress animation under Reduce Motion.

## Architecture (target, per `Specs/file-architecture.md`)

Layered by concern, not by type. Top-level folders under `ChewTheFat/`:

- `App/` — entry point, AppDelegate (BGTaskScheduler), dependency container.
- `Agent/` — the agent harness, the biggest module. Subfolders:
  - `Orchestrator/` — central coordinator; owns `TurnHandler`, `ToolCallDispatcher`, `WidgetIntentResolver`, `SessionStateManager`.
  - `ContextManager/` — prompt assembly with token budgeting; pluggable `ContextSource` contributors (session, goal, memory, knowledge, profile).
  - `Model/` — `ModelClient` (llama.cpp / MLX), streaming, tool schema.
  - `Memory/` — post-session summarizer, daily summary, trends generator.
  - `Scheduling/` — BGTaskScheduler-driven proactive coach prompts.
- `Tools/` — split by side-effect:
  - `Retrieval/` (read): food search over OFFs/USDA/web fallback, knowledge lookup.
  - `Action/` (write): log food, log weight, set goals, set profile.
- `Knowledge/` — markdown goal/skill/reference files bundled in `Resources/`, loaded through `KnowledgeGraph` + `KnowledgeSelector`.
- `Data/` — `SwiftData/` (schema + `ModelContainerProvider` + `ModelContextFactory`), `Models/` (`@Model` types, one file each), `Repositories/` (the only things outside `Data/` that touch `ModelContext`), `LocalDatabases/` (read-only GRDB wrappers around `usda.sqlite` and `offs.sqlite`).
- `Domain/` — pure Swift types shared across layers: `SessionGoal`, `WidgetIntent`, `NutritionFacts`, `MealType`, `ActivityLevel`, `FoodSource`. **No SwiftData or SwiftUI imports** — this is what makes the agent unit-testable without a persistence stack.
- `UI/` — `Chat/`, `Dashboard/` (US7 home screen — Trajectory / Today / meals list / chat history / nav chips), `Widgets/` (each widget has its own folder with View + ViewModel; `WidgetRenderer` dispatches `WidgetIntent` to views for the chat path, the Dashboard instantiates the same widget views with a `.live(repo:)` factory), `Onboarding/`, `Settings/`, `Shared/DesignSystem/`.
- `Services/`, `Utilities/`, `Resources/`.

Deliberately absent: `Managers/`, `Helpers/`, `Protocols/`, `ViewModels/`, `Constants/`. Protocols sit next to their primary implementation (e.g. `OrchestratorProtocol.swift` in `Orchestrator/`). ViewModels sit next to their Views.

### Dataflow invariants

- UI code talks to **repositories**, never to `ModelContext` directly.
- `Message` rows carry optional `textContent` and an ordered 1..N relation to `MessageWidget` rows. A widgets-only message has `textContent = nil`; every `MessageWidget` has a `type` (must match a `WidgetRenderer` entry) and a JSON `payload`.
- **Widget payloads carry references, not snapshots.** `MessageWidget.payload` stores `loggedFoodIds`, `date`, `dateRange` etc. — the widget view resolves them against SwiftData at render time. Dashboard widgets skip the payload entirely and bind live to repositories. A user edit to an underlying log is reflected on every surface that presents it.
- **Storage boundary**: the bundled `usda.sqlite` and `offs.sqlite` are **read-only RAG sources**. Only `FoodSearchRAG` and its retrieval Sources touch them. Display, logging, and repository code must go through SwiftData.
- **Promotion rule**: on first log of a food from USDA / OFF / web, the RAG tool creates a SwiftData `FoodEntry` (or reuses one via `(source, sourceRefId)` uniqueness) and copies its servings into SwiftData `Serving` rows. `LoggedFood` then references those SwiftData rows — the reference DBs are never joined at read time. A reference-DB update can never retroactively mutate a historical log.
- **RAG precedence**: `FoodSearchRAG` queries four sources in order — (1) `UserHistorySource` over SwiftData `FoodEntry` (matches `searchTokens` via `#Predicate`), (2) `USDAFoodSource`, (3) `OpenFoodFactsSource`, (4) `WebSearchFallback` (opt-in). History is ranked by match × `logCount` × recency so returning foods surface first.
- `Trends` is a singleton pre-aggregated blob; writes to `LoggedFood` / `WeightEntry` mark it stale, a background task recomputes on next foreground.

### Agent latency budget (SC-002a)

Streaming is mandatory. First token ≤ 3s, full response ≤ 15s.

## Known scaffold ↔ spec state

The scaffold is now **aligned** with the constitution on persistence and deployment target (see constitution 1.0.1 amendment 2026-04-21). The remaining scaffold work is subtractive, not contentious:

- **Scaffold SwiftData model** (`@Model Item`) is a placeholder — replace with the real `@Model` types per `Specs/data-model.md` and a `ChewTheFatSchema` / `ModelContainerProvider` pair.
- **Swift version**: project is `SWIFT_VERSION = 5.0`. Bump to 5.9+ (required by modern SwiftUI + SwiftData idioms in use).
- Main-actor isolation is on by default (`SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor`, `SWIFT_APPROACHABLE_CONCURRENCY = YES`). Agent/tool code that does heavy work must be explicitly `nonisolated` or moved to an actor / `ModelActor`.

## Xcode project quirks

- The `ChewTheFat` group is a `PBXFileSystemSynchronizedRootGroup`. Any `.swift` file dropped under `ChewTheFat/` is automatically part of the target — **do not hand-edit `project.pbxproj` to add sources.**
- SwiftUI `#Preview`s use in-memory stores: `.modelContainer(for: <Model>.self, inMemory: true)`. Keep this pattern once the real `@Model` types land.

## Amendments

Before changing anything in `Specs/constitution.md`, follow its Amendment Procedure (propose on a branch, bump the semver version + `Last Amended` date, propagate to affected docs/templates, self-review the Sync Impact Report). The constitution is at version **1.1.0** (last amended 2026-04-22 — Principle I carve-out for first-launch model bootstrap from a public registry; Technology Stack finalises Apple MLX-Swift via `mlx-swift-lm`).
