
# Downward Trajectory Constitution

## Core Principles

### I. Local-First Architecture

All computation, storage, and model inference MUST run entirely on-device. The LLM, USDA
food reference database, Open Food Facts database (both SQLite), and all user data MUST
be stored locally and MUST NOT be transmitted to any external server or third-party service.
Network access is NOT permitted for core app functionality; any future optional network
feature MUST be explicitly justified, opt-in, and isolated from core data pipelines.

**Rationale**: Privacy is non-negotiable for health data. On-device operation also ensures
the app works without connectivity and eliminates latency from round-trip API calls.

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
- **On-Device LLM**: Apple MLX or llama.cpp via Swift bindings (decision to be finalized
  in first feature plan)
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

**Version**: 1.0.1 | **Ratified**: 2026-04-20 | **Last Amended**: 2026-04-21

**Amendment history**:
- 1.0.1 (2026-04-21) — PATCH. Raised minimum deployment target from iOS 17.0+ to
  iOS 26.0+. Explicitly adopted SwiftData for user-data persistence (the prior
  version was silent on persistence framework). GRDB reaffirmed as the read-only
  access path for bundled USDA / Open Food Facts SQLite reference files. No
  principle added, removed, or redefined.
