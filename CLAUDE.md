# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project

**ChewTheFat** (codename "Downward Trajectory") — iOS agentic food-logging & health-coach app. An on-device LLM drives a chat interface; the user logs meals and weight through natural language, and the agent renders interactive widgets (Meal Card, Macro Chart, Weight Graph) inline.

The current repo is still the fresh Xcode 26 SwiftUI + SwiftData template — the real architecture described below (`Specs/file-architecture.md`) has not been built yet. Bundle id `com.PixelKinetics.ChewTheFat`. iPhone only, v1.

**Authoritative specs** live in `Specs/`:
- `constitution.md` — six non-negotiable principles (read first)
- `spec.md` — user stories, functional requirements, success criteria
- `data-model.md` — Core Data entities + GRDB food-reference schema
- `file-architecture.md` — target Xcode project layout
- `research.md` — technology decisions

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
- `Data/` — `CoreData/` (stack + `.xcdatamodeld`), `Models/` (NSManagedObject subclasses), `Repositories/` (the only things outside `Data/` that touch Core Data), `LocalDatabases/` (GRDB wrappers around `usda.sqlite` and `offs.sqlite`).
- `Domain/` — pure Swift types shared across layers: `SessionGoal`, `WidgetIntent`, `NutritionFacts`, `MealType`, `ActivityLevel`, `FoodSource`. **No Core Data or SwiftUI imports** — this is what makes the agent unit-testable without a persistence stack.
- `UI/` — `Chat/`, `Widgets/` (each widget has its own folder with View + ViewModel; `WidgetRenderer` dispatches `WidgetIntent` to views), `Onboarding/`, `Settings/`, `Shared/DesignSystem/`.
- `Services/`, `Utilities/`, `Resources/`.

Deliberately absent: `Managers/`, `Helpers/`, `Protocols/`, `ViewModels/`, `Constants/`. Protocols sit next to their primary implementation (e.g. `OrchestratorProtocol.swift` in `Orchestrator/`). ViewModels sit next to their Views.

### Dataflow invariants

- UI code talks to **repositories**, never to `NSManagedObjectContext` directly.
- `Message` rows carry either `textContent`, a `widgetType` + JSON `widgetPayload`, or both. A widget-only message has `textContent = nil`.
- `LoggedFood` **snapshots** per-serving macros at log time — reference DB updates must never mutate historical logs.
- `Trends` is a singleton pre-aggregated blob; writes to `LoggedFood` / `WeightEntry` mark it stale, a background task recomputes on next foreground.

### Agent latency budget (SC-002a)

Streaming is mandatory. First token ≤ 3s, full response ≤ 15s.

## Known scaffold ↔ spec discrepancies

The current Xcode template disagrees with the constitution in several places. When you build the real architecture, reconcile these:

- **Persistence**: scaffold uses **SwiftData** (`@Model Item` + `ModelContainer` in `ChewTheFatApp.swift`). The spec and `data-model.md` mandate **Core Data** with automatic lightweight migration (FR-017). The `Item` model and the SwiftData container must be replaced.
- **Deployment target**: project is `IPHONEOS_DEPLOYMENT_TARGET = 26.4`. Constitution says **iOS 17.0+** minimum. Lower the target before shipping.
- **Swift version**: project is `SWIFT_VERSION = 5.0`. Constitution says **Swift 5.9+**.
- Main-actor isolation is on by default (`SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor`, `SWIFT_APPROACHABLE_CONCURRENCY = YES`). Agent/tool code that does heavy work must be explicitly `nonisolated` or moved to an actor.

## Xcode project quirks

- The `ChewTheFat` group is a `PBXFileSystemSynchronizedRootGroup`. Any `.swift` file dropped under `ChewTheFat/` is automatically part of the target — **do not hand-edit `project.pbxproj` to add sources.**
- SwiftUI `#Preview`s should use in-memory stores (template pattern: `.modelContainer(for: Item.self, inMemory: true)`). Translate this to an in-memory `NSPersistentContainer` when migrating to Core Data.

## Amendments

Before changing anything in `Specs/constitution.md`, follow its Amendment Procedure (propose on a branch, bump the semver version + `Last Amended` date, propagate to affected docs/templates, self-review the Sync Impact Report). The constitution is at version 1.0.0 (ratified 2026-04-20).
