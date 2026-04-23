
# Downward Trajectory Constitution

## Core Principles

### I. Local-First Architecture

All computation, storage, and model inference MUST run entirely on-device. The USDA food
reference database, Open Food Facts database (both SQLite), the LLM weights once cached,
and all user data MUST be stored locally. **User-data egress is PROHIBITED**: no
user-authored content, log entries, profile fields, conversation transcripts, or
inference outputs MAY be transmitted off-device under any circumstance.

Network access is restricted to two narrowly scoped paths, each isolated from core data
pipelines:

1. **First-launch model bootstrap.** The on-device LLM weights MAY be fetched from a
   public model registry (e.g., Hugging Face Hub) on first launch. The bootstrap MUST
   occur **after EULA acceptance and before any user-data collection**, MUST be
   surfaced with explicit progress UI in the onboarding flow, MUST cache the weights
   locally for fully offline use thereafter, and MUST NOT re-fetch on subsequent
   launches unless the app updates the pinned model identifier. The bootstrap
   transmits no user data — only the public model identifier.
2. **Opt-in web-search food fallback** (Principle V) — off by default, user-toggled in
   Settings, isolated to a single retrieval source.

Any additional network feature MUST be added to this list via the Amendment Procedure
with explicit justification.

**Rationale**: Privacy is non-negotiable for health data; the user-data egress
prohibition is absolute. Inference must run on-device for latency (SC-002a) and
offline reliability after setup. The first-launch bootstrap exception is justified by
the App Store install-size cost of shipping a multi-hundred-megabyte model bundled,
the cellular-install friction it would impose on every install, and the operational
benefit of being able to revise the pinned model without a full app release. Bundling
the model would have honoured the principle more strictly but at a UX and
distribution cost the project judges higher than a single, transparent, post-EULA
fetch.

### II. Native Components First

SwiftUI and UIKit native components MUST be used before any custom alternative is built.
A custom component is only permissible when the native equivalent demonstrably cannot
meet a documented UX requirement. Custom components MUST conform to the design token
system defined in Principle III and MUST support Dynamic Type and accessibility features
(VoiceOver, Reduce Motion) at the same level as native equivalents.

**Rationale**: Native components receive OS-level accessibility, performance, and
appearance updates for free. Custom components multiply maintenance burden.

### III. Design System Discipline

The design system MUST be the single source of truth for visual expression:

- **Colors**: ALL color values MUST be defined as named color sets in `Assets.xcassets`.
  Hard-coded hex or RGB values in Swift source are PROHIBITED.
- **Spacing & Sizing**: ALL spacing, padding, corner radius, and font-size values MUST be
  defined as constants in a dedicated Swift token file (e.g., `DesignTokens.swift`). Magic
  numbers for layout are PROHIBITED.
- **Icons**: ONLY SF Symbols (iOS system font icons) MAY be used. No third-party icon
  libraries, bundled SVGs, or raster icon assets are permitted.

**Rationale**: A strict token-based design system enables consistent theming (including
Dark Mode and Dynamic Type), makes design changes atomic, and avoids visual drift across
features developed over time.

### IV. Conversational Agent Interface

The primary user-facing interaction layer MUST be a chat interface backed by the local
health coach LLM agent. The agent MAY send two content types in the conversation:

1. **Text messages** — natural language coaching, explanations, and prompts.
2. **Interactive widgets** — structured UI components (e.g., quick-log cards, progress
   summaries, confirmation dialogs) rendered inline within the chat thread.

Widget types MUST be defined in a shared schema so both the agent output parser and the
rendering layer agree on structure. The agent MUST NOT require network access (see
Principle I). Widget interactions that mutate data MUST go through the same data layer
used by manual logging flows.

**Rationale**: A conversational interface lowers the cognitive barrier to logging and
coaching. Widgets allow structured data capture without leaving the conversation context.

### V. Frictionless Logging & Macro Tracking

Food logging and weight logging MUST be completable in the fewest possible taps.
Specifically:

- Food search MUST query the local USDA and Open Food Facts SQLite databases; results
  MUST appear without network access.
- Macro totals (calories, protein, carbohydrates, fat) MUST be derived automatically from
  logged food entries using nutrient data from the reference databases.
- Weight entries MUST be loggable from the chat interface via a widget and from a
  dedicated logging screen.
- No logging action MUST require more than three taps from the home/chat screen.

**Rationale**: Logging compliance drops sharply with friction. The app's value is
predicated on consistent, complete data entry.

### VI. Beautiful Progress Visualization

All charts and progress views MUST meet a high aesthetic standard:

- Charts MUST use the design token color palette (Principle III) and MUST support Dark
  Mode.
- Charts MUST be built with Swift Charts (native) unless a specific visualization type is
  demonstrably impossible with Swift Charts, in which case a custom renderer MUST still
  adhere to the token system.
- Trend lines, goal markers, and macro breakdowns MUST be legible at standard and
  accessibility text sizes.
- Animations in charts MUST respect the Reduce Motion accessibility setting.

**Rationale**: Visual progress feedback is a primary motivational driver. Charts that are
beautiful and readable increase engagement and reinforce healthy behaviors.

## Technology Stack

- **Language**: Swift 5.9+
- **UI Framework**: SwiftUI (primary), UIKit (when SwiftUI is insufficient)
- **On-Device LLM**: Apple MLX-Swift via the `mlx-swift-lm` package (`MLXLLM` +
  `MLXLMCommon` SPM products). Inference runs entirely on-device using
  Metal-accelerated kernels on Apple Silicon.
- **Model Acquisition**: Weights are fetched on first launch from a public model
  registry (Hugging Face Hub, via `huggingface/swift-huggingface` and
  `huggingface/swift-transformers`, integrated through `MLXHuggingFace`). The
  bootstrap is gated behind EULA acceptance, surfaced with explicit progress UI,
  cached in `Application Support/Models/`, excluded from iCloud backup, and is
  the only network-acquired binary asset in the app.
- **User Data Persistence**: SwiftData (`@Model` types over SQLite). Lightweight schema
  changes ride Apple's automatic inference; breaking changes use `VersionedSchema` +
  `MigrationPlan`.
- **Food Reference Data**: SQLite (USDA FoodData Central + Open Food Facts), accessed via
  GRDB. Read-only; consumed only by the food-search RAG tool (see spec FR-004 / FR-004a).
- **Charts**: Swift Charts (Apple native framework)
- **Minimum Deployment Target**: iOS 26.0+ (enables mature SwiftData, latest SwiftUI
  APIs, and Swift Charts)
- **Design Tokens**: `DesignTokens.swift` in the main app target
- **Color Assets**: `Assets.xcassets` color set entries; semantic naming required
  (e.g., `colorBackgroundPrimary`, not `colorGray100`)

## Development Workflow

- **Testing**: XCTest for unit and integration tests; UI tests via XCUITest where
  appropriate. Tests for data-layer and agent-parsing code are REQUIRED. UI snapshot
  tests are RECOMMENDED for components that render design tokens.
- **Linting**: SwiftLint MUST be configured and enforced in CI (or pre-commit hooks).
  No SwiftLint violations with severity `error` may be merged.
- **Branching**: Feature branches follow the naming convention established by the Spec Kit
  git extension. `main` MUST remain releasable at all times.
- **Complexity Justification**: Any deviation from Principles I–VI MUST be documented in
  the feature plan's Complexity Tracking table with an explicit rationale and rejected
  simpler alternative.

## Governance

This constitution supersedes all other practices, conventions, and verbal agreements for
the Downward Trajectory project. All feature specifications and implementation plans MUST
include a Constitution Check section verifying compliance with Principles I–VI before
implementation begins.

**Amendment Procedure**:
1. Propose the amendment with rationale in a dedicated branch.
2. Update this file, increment the version per the semantic versioning policy below, and
   update `LAST_AMENDED_DATE`.
3. Propagate changes to affected templates and runtime guidance docs.
4. Merge only after self-review of the Sync Impact Report embedded in this file.

**Versioning Policy**:
- MAJOR: Principle removal, redefinition that breaks existing features, or technology
  stack replacement.
- MINOR: New principle, new mandatory section, or materially expanded guidance.
- PATCH: Clarifications, wording fixes, non-semantic refinements.

**Compliance**: All pull requests MUST be reviewed against this constitution. Violations
MUST be resolved before merge, or formally justified in the Complexity Tracking table.

**Version**: 1.1.0 | **Ratified**: 2026-04-20 | **Last Amended**: 2026-04-22

**Amendment history**:
- 1.1.0 (2026-04-22) — MINOR. Principle I expanded to permit a single, narrowly
  scoped first-launch network path: fetching public LLM weights from a public
  model registry (Hugging Face Hub) after EULA acceptance and before any
  user-data collection. The user-data egress prohibition is unchanged and
  restated as absolute. Technology Stack finalized the LLM choice as Apple
  MLX-Swift via `mlx-swift-lm` (replacing the open `MLX or llama.cpp` choice)
  and added a `Model Acquisition` entry describing the bootstrap path, cache
  location, and backup-exclusion requirement. Supersedes the 2026-04-22
  bundled-via-LFS decision recorded earlier the same day in `research.md §1`
  and `spec.md §Clarifications`.
- 1.0.1 (2026-04-21) — PATCH. Raised minimum deployment target from iOS 17.0+ to
  iOS 26.0+. Explicitly adopted SwiftData for user-data persistence (the prior
  version was silent on persistence framework). GRDB reaffirmed as the read-only
  access path for bundled USDA / Open Food Facts SQLite reference files. No
  principle added, removed, or redefined.

---

## Sync Impact Report — 1.1.0 (2026-04-22)

**Trigger**: First-run UX of bundling a ~700 MB MLX-quantised LLM in the .ipa was
judged worse than a transparent post-EULA fetch from a public registry. The strict
local-first reading of Principle I needed an explicit, narrow carve-out so the change
is auditable rather than implicit.

**Principle changes**:
- Principle I — added the two-path network whitelist (model bootstrap + opt-in
  web-search fallback) and restated the user-data egress prohibition as absolute.
  Rationale paragraph extended to acknowledge the bundling trade-off.

**Technology Stack changes**:
- LLM choice finalized: `mlx-swift-lm` (`MLXLLM`, `MLXLMCommon`).
- New `Model Acquisition` entry describing the Hugging Face Hub bootstrap, cache
  path, and backup-exclusion requirement.

**Files propagated** (companion edits in this commit):
- `Specs/research.md §1` — superseded the 2026-04-22 bundled-LFS decision; replaced
  with HF Hub fetch. LLM framework decision updated to MLX-Swift; llama.cpp moved
  to alternatives.
- `Specs/spec.md` — FR-001 carve-out added; new `Session 2026-04-22 (Model
  Acquisition)` clarification added; `Assumptions` updated to describe the HF Hub
  fetch.
- `Specs/implementation-plan.md` — D2/D3 updated; M0 LFS scope reduced; M2 step 1
  rewritten for MLX deps; M4 gains a model-bootstrap step.
- `Specs/code-documentation.md` — `ModelClient` parenthetical narrowed to MLX;
  new `ModelBootstrapper` entry under `Agent/Model/`; `AppEnvironment` gains a
  `modelBootstrapper` reference.
- `Specs/file-architecture.md` — `Agent/Model/ModelBootstrapper.swift` and
  `UI/Onboarding/ModelBootstrapView.swift` added to the tree.
- `CLAUDE.md` — constitution version reference updated.

**Files NOT requiring changes**:
- `Specs/data-model.md` — schema unchanged; the bootstrap state lives in app
  preferences, not SwiftData.

**Self-review checklist**:
- [x] User-data egress prohibition still absolute.
- [x] Bootstrap network path is narrow, gated, and auditable in code.
- [x] No other principle weakened.
- [x] Versioning policy applied correctly (MINOR — materially expanded guidance,
      no principle removed or redefined).
- [x] Every cross-reference in companion specs updated in the same commit.
