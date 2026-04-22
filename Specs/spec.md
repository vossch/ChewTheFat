# Feature Specification: ChewTheFat — iOS Agentic Food Logging App

**Feature Branch**: `001-ios-health-coach-app`
**Created**: 2026-04-20
**Status**: Draft
**Input**: User description: "iOS local health coach app with food/weight logging, macro tracking,
chat interface, and progress charts"

---

## User Scenarios & Testing *(mandatory)*

### User Story 1 — First-Time Onboarding (Priority: P1)

A new user opens the app for the first time. The health coach greets them and walks them
through accepting the EULA/Terms of Service, setting their preferred units (metric or
imperial), filling in their profile (birth year, height, sex), selecting a weight-change
intent (lose / maintain / gain) with ideal-weight and activity-level inputs, and
reviewing the computed daily calorie and macro targets. The entire flow is rendered
inside the chat thread using interactive widgets — there is no separate wizard UI.
After completing setup, the user lands on the main chat screen ready to start logging.

**Why this priority**: Without a complete profile the app cannot calculate calorie or
macro targets. All downstream value depends on this flow being smooth and completable.

**Independent Test**: A brand-new install with no existing data can be walked through
onboarding from launch to the main chat screen, resulting in a persisted user profile
and goals record.

**Acceptance Scenarios**:

1. **Given** the app is freshly installed with no data, **When** the user opens the app,
   **Then** the health coach initiates the onboarding flow with a welcome message and
   asks the user to choose their preferred units (metric/imperial) via interactive widgets.
2. **Given** the user has chosen units and provided birth year, height, and biological
   sex, **When** they confirm their profile, **Then** the coach advances to the goals
   step (weight-change intent, ideal weight, activity level).
3. **Given** the user enters height in a free-form format (e.g., `5' 11"`, `5-11`,
   `5 ft 11 in`, or `180 cm`), **When** the agent parses the input, **Then** it
   normalises the value to the stored unit (cm) and echoes the parsed result for
   confirmation; if parsing is ambiguous, the agent asks for clarification.
4. **Given** the user selects a weight-change intent (Lose / Maintain / Gain) and
   provides an ideal weight and activity level, **When** they confirm, **Then** the app
   computes a recommended daily calorie target, macro split, and a projected
   goal-achievement date, and presents them for approval.
5. **Given** the user accepts or adjusts their goals, **When** they complete onboarding,
   **Then** their profile, goals, and preferences are persisted locally and they are
   taken to the main chat screen.
6. **Given** the user abandons onboarding mid-flow, **When** they reopen the app,
   **Then** the onboarding resumes from where they left off.

---

### User Story 2 — Log a Meal via Chat (Priority: P1)

The user types a description of what they ate into the chat interface. The
health coach agent parses the input, searches the local food databases, and presents a
Meal Card widget showing each identified food item with its quantity, serving unit, and
calorie count. The user can adjust quantities and serving sizes inline. The coach shows
remaining daily macros after the meal is confirmed.

**Why this priority**: Food logging is the app's core value. It must work reliably and
with minimal friction every day.

**Independent Test**: A user with an existing profile can describe a meal in natural
language, receive a populated Meal Card widget, adjust one item's serving, confirm the
log, and see updated macro totals — all without leaving the chat screen.

**Acceptance Scenarios**:

1. **Given** the user types a natural-language meal description (e.g., "3 eggs, 1 slice
   turkey bacon, grapefruit"), **When** the agent is processing, **Then** a typing
   indicator is displayed in the chat until the first response token arrives; **Then** a
   Meal Card widget appears containing a meal-slot header (Breakfast/Lunch/Dinner/Snack)
   with total calories, one row per identified item showing quantity, a serving-unit
   dropdown, food name, and per-item calories, plus inline Protein/Carbs/Fat progress
   bars with numeric labels showing the meal's contribution toward daily targets.
2. **Given** a Meal Card is displayed, **When** the user taps the quantity field or the
   serving-unit dropdown on a row, **Then** they can change it inline and the per-item
   and meal total calories/macros update immediately; the inline macro progress bars
   re-render without leaving the chat.
3. **Given** the user confirms the meal, **When** the entry is saved, **Then** the coach
   responds with the updated remaining daily calories and a macro progress summary.
4. **Given** a food item is not found in USDA or Open Food Facts databases,
   **When** a web search fallback is available and enabled, **Then** the agent attempts
   to retrieve nutritional data via web search and presents the result for confirmation;
   if not available, the agent informs the user the item was not found and asks them to
   enter macros manually.
5. **Given** the user assigns a meal to a slot (Breakfast, Lunch, Dinner, Snack),
   **When** the entry is saved, **Then** it is stored with the correct meal slot and date.

---

### User Story 3 — Log Weight via Chat (Priority: P2)

The user tells the health coach their current weight. The agent logs the entry, confirms
it in the chat, and can optionally show a Weight Graph widget displaying recent weight
trend against the user's goal trajectory.

**Why this priority**: Weight logging is the second core data type; it enables progress
tracking and goal assessment.

**Independent Test**: A user with an existing profile can type their weight, have it
logged, and see the weight graph widget reflecting the new entry.

**Acceptance Scenarios**:

1. **Given** the user types their weight (e.g., "I weigh 185 lbs today"), **When** the
   agent processes the message, **Then** a weight entry is created with today's date and
   the agent confirms the log in the chat.
2. **Given** a weight entry is logged, **When** the user asks to see progress,
   **Then** the agent renders a Weight Graph widget in the chat showing the logged weight
   history and the goal trajectory line.
3. **Given** the user logs a weight that significantly diverges from recent trend,
   **When** the entry is saved, **Then** the agent acknowledges the change and offers
   relevant coaching feedback.

---

### User Story 4 — View Daily Macro & Calorie Progress (Priority: P2)

The user can ask the health coach for a progress summary at any time. The agent responds
with a Macro Chart widget showing calories consumed vs. target and per-macro breakdowns
(protein, carbs, fat) with color-coded progress bars for the current day.

**Why this priority**: Visibility into daily progress is a primary motivational driver
for continued logging compliance.

**Independent Test**: A user with at least one logged meal can ask "How am I doing?" and
receive a Macro Chart widget with accurate totals for the current day.

**Acceptance Scenarios**:

1. **Given** the user has logged meals today, **When** they request a progress summary,
   **Then** a Macro Chart widget appears in chat showing total calories consumed vs.
   daily target, and protein/carbs/fat consumed vs. respective targets.
2. **Given** the user has exceeded a macro target, **When** the Macro Chart is rendered,
   **Then** the exceeded macro is visually distinguished (e.g., different color) and the
   agent notes it in its response.
3. **Given** no meals have been logged today, **When** the user requests a summary,
   **Then** the agent encourages the user to log their first meal rather than showing an
   empty chart.

---

### User Story 5 — Scheduled Coaching Prompts (Priority: P3)

The app proactively reminds the user to log meals or weight at configurable times (e.g.,
"Have you logged breakfast yet?"). These scheduled messages appear as new chat messages
from the health coach and may include quick-action widgets.

**Why this priority**: Proactive prompts improve logging compliance without requiring the
user to remember to open the app.

**Independent Test**: With a scheduled job configured for a past time, triggering it
manually results in a new coach message appearing in the chat with a meal-logging widget.

**Acceptance Scenarios**:

1. **Given** a scheduled job is configured for a meal reminder, **When** the scheduled
   time arrives, **Then** a new message from the health coach appears in the chat asking
   the user to log the relevant meal, accompanied by a quick-log widget.
2. **Given** the user has already logged the meal for that slot before the reminder
   fires, **When** the scheduled job triggers, **Then** the reminder is suppressed or
   the coach acknowledges the meal was already logged.

---

### User Story 6 — Manage Goals and Profile (Priority: P3)

The user can ask the health coach to update their profile (weight-change goal, macro
targets, activity level) via the chat interface. The agent confirms the change and
updates the persisted goals record.

**Why this priority**: Users' goals change over time; the ability to update them is
necessary for accurate ongoing tracking.

**Independent Test**: A user with an existing profile can ask the coach to change their
weekly weight-change target, have it updated, and see the new calorie target reflected
in the next macro summary.

**Acceptance Scenarios**:

1. **Given** the user requests a goal change (e.g., "I want to lose 1 lb per week"),
   **When** the agent confirms the change, **Then** the goals record is updated and the
   daily calorie target is recalculated.
2. **Given** the user requests a profile update (e.g., updated height or activity level),
   **When** the agent confirms the change, **Then** the profile record is updated and
   macro targets are recalculated accordingly.
3. **Given** the user opens the dedicated Goals screen from the Dashboard, **When** they
   toggle `Daily Targets` between `Auto` and `Manual`, **Then** in `Auto` mode the
   calorie target is computed from profile + weekly-change rate + activity level and
   macro gram targets are derived from a default split, and in `Manual` mode the user
   can directly enter a calorie number and drag Protein/Carbs/Fat percentage sliders
   (which MUST sum to 100%) that are converted to gram targets.
4. **Given** the user opens the dedicated Profile screen, **When** they edit birth year,
   height, or biological sex, **Then** the profile record is updated and, if `Auto`
   mode is active, the daily calorie target and macro gram targets are recomputed.
5. **Given** the user opens the dedicated Settings screen, **When** they toggle the
   display unit system (kg/cm ↔ lbs/ft), **Then** the preference is persisted and all
   weight, height, and macro values in the app re-render in the selected unit without
   changing the stored canonical values (kg / cm / g).

---

### User Story 7 — Home Dashboard (Priority: P1)

From the chat screen, the user can open a Dashboard surface that summarises their
overall progress at a glance: a weight Trajectory chart (historical actual vs. projected
goal line), a Today panel showing remaining calories and per-macro progress bars, a list
of today's meals with per-meal calorie totals, quick-access chips for Goals / Profile /
Settings, and a Chat history list of prior sessions.

**Why this priority**: Users need a single non-conversational surface to see their
trajectory, today's numbers, and navigate to structured settings. Logging compliance is
reinforced by immediate visibility of remaining daily budget.

**Independent Test**: A user with at least one weight entry, one logged meal, and one
prior chat session can open the Dashboard and see the Trajectory chart, Today summary
(calories remaining + macro bars), today's meals, navigation chips, and the Chat
history list populated correctly.

**Acceptance Scenarios**:

1. **Given** the user has weight history, **When** they open the Dashboard,
   **Then** the Trajectory chart renders: the solid-filled region represents logged
   weight history with a marker at the most recent value, and the faded region
   represents the projected trajectory from the current weight to the ideal weight over
   time, along with axis labels for the time range.
2. **Given** the user has logged meals today, **When** the Today panel renders,
   **Then** it shows "N Calories left" (target minus consumed), Protein/Carbs/Fat
   progress bars labelled "consumed/target g", and a list of today's entries grouped
   by meal slot with the slot's total calories on the right.
3. **Given** a macro has been exceeded, **When** the Today panel renders,
   **Then** the exceeded macro's progress bar is visually distinguished (e.g., amber
   fill) to signal the overage.
4. **Given** the Dashboard is open, **When** the user taps the Goals, Profile, or
   Settings chip, **Then** the corresponding dedicated editor screen opens.
5. **Given** the Dashboard is open, **When** the user dismisses it, **Then** they
   return to the chat surface at the same scroll position they left.

---

### User Story 8 — Browse and Resume Chat Sessions (Priority: P3)

Each conversation is persisted as a named Session. From the Dashboard's Chat history
list, the user can open a prior session to review its messages and continue the
conversation, or start a new session.

**Why this priority**: Multi-session history lets users revisit prior coaching
conversations and keep distinct threads (e.g., "Weight and food logging", "Workout
planning") without one long scroll.

**Independent Test**: A user with two or more persisted sessions can see both listed
under "Chat history" on the Dashboard, open one, and append a new message that is
saved into that session rather than a new one.

**Acceptance Scenarios**:

1. **Given** the user has prior sessions, **When** they open the Dashboard,
   **Then** the Chat history section lists each session by name with a relative-date
   stamp (e.g., "Yesterday") of its last message, ordered most-recent first.
2. **Given** the user taps a session in Chat history, **When** the session opens,
   **Then** the chat surface loads that session's messages in order and any new
   messages the user sends are appended to that session.
3. **Given** the user is in an existing session, **When** they explicitly start a new
   session, **Then** a new Session record is created and subsequent messages are
   attached to it.

---

### Edge Cases

- What happens when the local LLM fails to parse a meal description (hallucination or
  low confidence)? The agent should ask for clarification rather than log incorrect data.
- How does the app handle a day with no logged data when the user views progress?
  The agent provides encouraging feedback and prompts logging.
- What if the user enters a nonsensical weight (e.g., 0 or negative)? The app must
  validate the entry and ask the user to re-enter.
- What if the food databases are not yet downloaded or are corrupt? The app must surface
  a clear error and disable food logging until the issue is resolved.
- What if the user logs multiple entries for the same meal slot? All entries for that
  slot are summed; no deduplication occurs unless the user explicitly removes an entry.
- What if the user enters a height string the agent cannot parse (e.g., "tall")? The
  agent MUST ask for clarification rather than store a null or zero value.
- What if the manual macro percentage sliders are changed such that the sum ≠ 100%?
  The save action MUST be blocked or the sliders MUST auto-rebalance (pinned slider
  plus redistribution across the other two). Gram targets are never persisted from an
  invalid sum.
- What if the Dashboard is opened with no weight history? The Trajectory chart MUST
  render an empty state with a prompt to log the first weight rather than an empty
  axis frame.
- What if the Dashboard is opened with no prior sessions? The Chat history section
  MUST be hidden or render an empty state rather than an empty list frame.

---

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: The app MUST operate entirely on-device; no user data, food logs, weight
  logs, or LLM inference MUST be transmitted to any external server.
- **FR-002**: The app MUST provide a conversational chat interface as the primary
  interaction surface for logging, coaching, and progress review.
- **FR-003**: The health coach agent MUST support rendering the following interactive
  widget types inline within the chat: Meal Card, Macro Chart, Weight Graph, and
  quick-log / confirmation dialogs. A single agent message MAY contain zero or more
  widgets; when multiple widgets are attached, they MUST render in the order specified
  by the agent (e.g., a Meal Card followed by a Macro Chart summarising the impact).
- **FR-003a**: The orchestration layer MUST intercept widget payloads produced by the
  agent before they are streamed to the chat UI; widgets MUST be rendered as native
  interactive components, not as raw text or JSON.
- **FR-003b**: Tool calls and internal agent reasoning MUST NOT be displayed to the user
  in the chat interface; only finalized text messages and rendered widgets are visible.
- **FR-004**: The app MUST support food search via a RAG tool that queries, in
  precedence order: (1) the user's SwiftData `FoodEntry` catalog (foods the user has
  previously logged or manually entered, ranked by query match × log frequency ×
  recency), (2) the local USDA FoodData Central SQLite reference DB, (3) the local
  Open Food Facts SQLite reference DB, and (4) if and only if the user has opted in,
  the web-search fallback (FR-014). Sources (1)–(3) MUST succeed without any network
  access. The bundled USDA and Open Food Facts databases are **read-only reference
  sources** for the RAG tool only; they MUST NOT be read directly by display or
  logging code.
- **FR-004a**: When the user confirms a logged food sourced from USDA, Open Food Facts,
  or the web-search fallback, the app MUST promote the selection into SwiftData by
  creating (or reusing, via `(source, sourceRefId)` uniqueness) a `FoodEntry` record
  and copying the associated servings into SwiftData `Serving` records. All subsequent
  reads (LoggedFood, Meal Card, macro totals, history search) MUST come from
  SwiftData; reference-DB rows MUST NOT be joined against SwiftData at query time.
  This guarantees that a reference-DB update cannot retroactively mutate any historical
  log's nutrition.
- **FR-005**: The app MUST automatically calculate macro totals (calories, protein,
  carbohydrates, fat, fiber) from logged food entries using data from the reference
  databases.
- **FR-006**: The app MUST support logging weight entries with a date, accessible from
  the chat interface via a widget and from a dedicated logging surface.
- **FR-007**: The app MUST persist all user data (profile, goals, food logs, weight logs,
  session logs, memories) locally using SwiftData (`@Model` types over the app's
  `ModelContainer`).
- **FR-008**: The app MUST support a user profile containing: birth year (see FR-026),
  height, biological sex, preferred units (metric/imperial), and activity level.
- **FR-009**: The app MUST support user goals containing: weekly weight-change method
  (manual or automatic), weekly weight-change target, macro targets (calculated or
  manual), calorie target (calculated or manual).
- **FR-010**: The app MUST include a first-run onboarding flow that collects the required
  profile and goal information before allowing food or weight logging.
- **FR-011**: The app MUST accept EULA and Terms of Service acceptance during onboarding
  before any personal data is collected.
- **FR-012**: The app MUST support scheduled jobs that trigger proactive coach messages
  at user-configurable times.
- **FR-013**: Meal log entries MUST be assignable to one of four meal slots: Breakfast,
  Lunch, Dinner, or Snack.
- **FR-014**: The app MUST display a web-search fallback for food items not found in
  either local database, subject to the user enabling this capability.
- **FR-015**: All colors MUST be defined as named entries in the Assets.xcassets color
  set; all spacing and sizing values MUST be defined in a dedicated Swift design token
  file; all icons MUST be sourced from SF Symbols.
- **FR-016**: The app MUST support Dark Mode and respect the user's Reduce Motion
  accessibility setting in all animated chart transitions.
- **FR-016a**: The app MUST support Dynamic Type across all text in the interface,
  including chat messages, widget labels, macro values, food names, and chart
  annotations. No text element MAY use a fixed, non-scalable font size.
- **FR-017**: The local data store MUST support automatic (lightweight) schema migration
  across app versions wherever the change is additive and backwards-compatible. Breaking
  schema changes MUST be expressed as a SwiftData `VersionedSchema` with a custom
  `MigrationStage` in the app's `MigrationPlan`. User data MUST NOT be silently
  destroyed or reset during any app update.
- **FR-018**: The app MUST provide a Dashboard surface, reachable from the chat screen,
  containing: (a) a Trajectory weight chart with a solid-filled historical region, a
  marker at the current weight, and a faded projected region extending to the ideal
  weight; (b) a Today panel with remaining-calories headline, per-macro progress bars,
  and today's meal entries grouped by slot; (c) navigation chips to Goals, Profile, and
  Settings; (d) a Chat history list of prior sessions.
- **FR-019**: The app MUST provide dedicated editor screens for Goals, Profile, and
  Settings reachable from the Dashboard chips, in addition to conversational editing
  via chat (FR-002). Edits made on these screens MUST apply the same validation and
  recomputation as chat-initiated edits.
- **FR-020**: The Goals screen MUST support a `Daily Targets` toggle between `Auto`
  (calorie and macro gram targets derived from profile, weekly-change rate, and
  activity level) and `Manual` (user-entered calorie number and Protein/Carbs/Fat
  percentage sliders that MUST sum to 100% and are converted to gram targets).
- **FR-021**: User goals MUST include an `idealWeight` value entered during onboarding
  and editable on the Goals screen. The app MUST compute and display a projected
  goal-achievement date derived from current weight, ideal weight, and weekly-change
  rate.
- **FR-022**: *(Deferred to post-v1.)* Voice input via the system dictation microphone
  in the chat input bar is out of scope for v1. The microphone icon in the chat input
  bar, if rendered, MUST be hidden or disabled in v1 and MUST NOT accept input.
- **FR-023**: The chat input bar MUST accept free-form height entries during onboarding
  and profile edits (e.g., `5' 11"`, `5-11`, `5 ft 11 in`, `180 cm`) and normalise them
  to cm; unparseable input MUST trigger a clarification prompt (see Edge Cases).
- **FR-024**: The Settings screen MUST allow the user to change the display unit
  system (metric/imperial) without altering stored canonical values, and MUST provide
  a notifications preferences surface that controls the schedule and enablement of the
  proactive coach prompts defined in FR-012.
- **FR-025**: The app MUST support multiple named chat sessions. A session MUST be
  listable from the Dashboard's Chat history, openable to resume with its prior
  messages loaded, and explicitly creatable as a new session. Messages MUST be scoped
  to exactly one session.
- **FR-026**: User profile MUST store birth year rather than a static age; display age
  is derived from birth year and the current date so values remain correct across
  year boundaries without user re-entry.
- **FR-027**: While the agent is processing a user message (after submit, before the
  first streamed token), the chat surface MUST display a typing indicator. The
  indicator MUST be removed as soon as the first response token is rendered (see
  SC-002a).
- **FR-028**: Each `SessionGoal` MUST declare a **completion contract** — a set
  of required facts that MUST exist in SwiftData for the goal to be considered
  satisfied. Contracts are authored as pure Swift predicates (the
  `SessionGoalContract` type is the single source of truth for what a goal
  requires). When the user attempts to start a new session whose goal differs
  from the current session's goal, the orchestrator MUST evaluate the current
  session's contract; if unsatisfied, the goal switch MUST be rejected and the
  orchestrator MUST inject a system-level note into the current session
  prompting the model to redirect the user toward the outstanding fields (a
  **soft redirect** — no UI-level hard block). The conversational flow for
  collecting missing fields is authored separately as a markdown playbook under
  `Knowledge/Resources/` (e.g., `skill-onboarding.md`) and is a **suggestion**
  for the model, not a hard-coded script — question order, phrasing, and
  follow-ups are the model's responsibility. Every prompt assembled during an
  active session MUST include a re-derived checklist of collected versus
  still-missing fields (sourced from a `GoalProgressContextSource`) so the
  model cannot lose track of what remains.

### Key Entities

- **UserProfile**: Birth year (age derived), height, biological sex, preferred units
  (metric/imperial), activity level.
- **UserGoals**: Weight-change method, weekly target, ideal weight, macro targets
  (protein/carbs/fat, stored in grams; manual mode additionally captures the percentage
  split entered by the user), calorie target, projected goal-achievement date (derived,
  not stored), all auto-calculated or manually set.
- **Session**: Conversation session with name, creation date, last message date, and
  session goal.
- **Message**: DateTime, author (User/Bot), optional text content, ordered list of
  zero or more attached widgets, optional linked food log, optional linked weight log.
- **MessageWidget**: Parent message, display order, widget type (`mealCard`,
  `macroChart`, `weightGraph`, `quickLog`), JSON payload. A message may carry
  multiple widgets rendered in order.
- **FoodEntry** (SwiftData, user-owned catalog): Name, optional detail, source
  (`usda` / `offs` / `manual` / `web`), optional source reference ID, created-at,
  last-logged-at, log count. Promoted from a RAG reference source on first log, or
  created directly for manual entries. Reused on subsequent logs via
  `(source, sourceRefId)` uniqueness.
- **Serving** (SwiftData, user-owned): Measurement name (e.g., "1 Cup"), calories,
  protein (g), carbs (g), fat (g), fiber (g). Belongs to a FoodEntry and stores the
  nutrition snapshot used by any LoggedFood that selects it.
- **LoggedFood**: References a FoodEntry and a specific Serving; carries only
  log-specific facts (date, meal slot, quantity multiplier). All nutrition values are
  read from the referenced Serving — no denormalised fields.
- **Reference Food DBs** (GRDB read-only, RAG sources only): USDA FoodData Central
  and Open Food Facts SQLite files. Consumed by the food-search RAG tool; never read
  by display or logging code; never written to at runtime.
- **WeightEntry**: Weight value, date.
- **DailySummary**: Date, summary content (generated by agent).
- **Memories**: Agent-maintained memory entries with date and content.
- **Trends**: Singleton record storing the date range and computed trend data used by
  progress charts.

---

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: A new user can complete the onboarding flow (EULA, units, profile, goals)
  in under 3 minutes from first launch.
- **SC-002**: A user can log a described meal and have macros calculated in under 30
  seconds from submitting the message, with no network access required.
- **SC-002a**: The health coach agent MUST stream its response token-by-token; the first
  token MUST appear within 3 seconds of the user submitting a message; the complete
  response MUST appear within 15 seconds.
- **SC-003**: Food search returns results for common foods in under 2 seconds using only
  local database queries.
- **SC-004**: The daily macro progress chart is accurate: totals displayed in the widget
  match the sum of all logged food entries for the day.
- **SC-005**: The app remains fully functional (logging, coaching, charting) with no
  network connectivity.
- **SC-006**: All interactive widgets are usable with VoiceOver enabled and at all
  Dynamic Type size settings (including Accessibility sizes); no widget interaction
  requires more than 3 taps from the main chat screen.
- **SC-007**: Chart animations complete in under 500ms and are fully suppressed when the
  user has Reduce Motion enabled.
- **SC-008**: The app supports at least 365 days of daily food and weight logging history
  without performance degradation in chart rendering or database queries.

---

## Clarifications

### Session 2026-04-20

- Q: What is the expected agent response latency and streaming behavior? → A: Stream tokens; first token ≤ 3s, full response ≤ 15s. The orchestration layer MUST intercept widget payloads before they reach the chat UI (rendered as native components, not raw output). Tool calls and internal reasoning MUST NOT be shown to the user.
- Q: What data encryption at rest is required for locally stored health data? → A: No explicit app-level encryption requirement; defer to iOS platform defaults (standard file-level protection).
- Q: How should Core Data schema changes be handled across app updates? → A: Automatic lightweight migration wherever possible; manual mapping migrations for breaking changes; user data MUST never be silently destroyed.
- Q: Is Dynamic Type support required? → A: Full Dynamic Type support required across all text in the app, including widget labels and chart annotations.
- Q: Is user data export (food/weight logs) required in the initial version? → A: No export requirement in the initial version; data portability is deferred to a future release.

### Session 2026-04-21 (Design Review)

- Q: The chat input bar shows a camera icon across every screen. What is its intended
  function for v1? → A: **Deferred to post-v1.** Both the mic (voice dictation) and
  camera affordances in the Figma are aspirational; in v1 the camera icon is either
  hidden or rendered as a disabled visual placeholder and performs no action. Photo
  recognition, image attachment, and camera-based logging are out of scope for v1.
- Q: Should profile store birth year or age? → A: **Birth year**, so the derived age
  remains accurate across calendar years without user re-entry.
- Q: How are manual macro targets captured — grams directly, or percentages converted
  to grams? → A: **Percentages via sliders** that MUST sum to 100%, converted to grams
  using the current calorie target (4 kcal/g protein, 4 kcal/g carbs, 9 kcal/g fat).
- Q: Is the Dashboard a separate screen, or a widget rendered inline in chat? → A:
  **Separate screen**, reachable from chat, with its own navigation chips to Goals /
  Profile / Settings. The chat widgets (Meal Card, Macro Chart, Weight Graph) remain
  inline in the conversation and are not the same surface as the Dashboard.
- Q: Dashboard widget data binding — do widgets re-render live from the store, or
  display a snapshot captured at message time? → A: **Live from SwiftData.** The
  Dashboard's Trajectory, Today (macro progress), and today's-meals list all bind
  directly to the repositories and react to subsequent edits. Chat-embedded widgets
  carry **references** (e.g., `loggedFoodIds`, `date`, `dateRange`) in their
  `MessageWidget.payload` — not dense nutrition snapshots — and resolve those
  references against SwiftData at render time. A user edit to an underlying log is
  reflected in every surface that presents it.
- Q: Persistence framework — Core Data or SwiftData? → A: **SwiftData.** With an
  iOS 26.0+ minimum the SwiftData implementation is past its early-version issues,
  matches Apple's current direction, and fits the project's main-actor-by-default
  concurrency model. Trade-off accepted: no native FTS5. The user catalog stays
  small, so `#Predicate` text matching on `FoodEntry.searchTokens` is sufficient;
  a supplementary search index may be introduced later if catalog size demands it.
- Q: Minimum deployment target — iOS 17 (per the original constitution) or iOS 26
  (per the scaffold)? → A: **iOS 26.0+**, ratified via the constitution 1.0.1
  amendment. Lower targets are not supported.

### Session 2026-04-22

- Q: How should onboarding balance model-driven flexibility with enforcement of
  required fields? → A: **Contract-enforced, model-driven.** Each `SessionGoal`
  declares its required fields in Swift (`SessionGoalContract`, the single
  source of truth). Required fields MUST be collected before a new session with
  a different goal may start. The conversational flow, however, is a
  **suggestion** delivered via a markdown playbook under `Knowledge/Resources/`
  (e.g., `skill-onboarding.md`) — not a hard-coded script. The model drives
  question order, phrasing, and follow-ups; every prompt includes a
  re-derived checklist of collected versus missing fields (via a
  `GoalProgressContextSource`) so the model cannot forget what remains. When
  the user tries to switch goals mid-flow, the orchestrator issues a **soft
  redirect** (a system-level note telling the model to guide the user back),
  not a UI-level block. See FR-028.
- Q: Should the on-device model file be bundled in the app binary or downloaded
  from a CDN on first launch? → A: **Bundled**, tracked via Git LFS. Strict
  local-first compliance (first launch — including EULA and onboarding — works
  offline), no download-state machine or gate UI, no CDN infrastructure. The
  ~2 GB GGUF fits comfortably under the App Store bundle size limit. See
  `research.md §1 "Model delivery"` for the full trade-off analysis.

## Assumptions

- The LLM model file (llama.cpp / GGUF format) is **bundled with the app** at
  build time and tracked via Git LFS (see `research.md §1` and
  `implementation-plan.md`). The specific GGUF model (Llama 3.2 3B Instruct
  Q4_K_M vs Phi-3.5 Mini Instruct Q4_K_M) is validated empirically against
  SC-002a during the agent-harness milestone.
- The USDA FoodData Central and Open Food Facts SQLite databases are bundled with the
  app at build time; database update mechanics are out of scope for the initial version.
- Web-search food fallback is an opt-in capability that requires the user to explicitly
  enable it in settings; it is the only network-dependent feature and is not required
  for the app to function.
- The app targets iPhone only (no iPad or macOS Catalyst layout) in the initial version.
- Metric and imperial unit systems are both supported; the choice is made at onboarding
  and can be changed in profile settings.
- The health coach agent is a single-model, single-session orchestrator; multi-model or
  multi-agent topologies are out of scope.
- No HealthKit integration is included in the initial version; weight and food data are
  maintained exclusively in Core Data.
- No app-level encryption of stored data is required; the app relies on iOS platform
  default file protection. No regulated clinical data (HIPAA, GDPR) handling is in scope.
- Barcode scanning is not included in the initial version. Voice dictation via the
  microphone icon is **deferred to post-v1** per the 2026-04-21 clarification; the
  icon is either hidden or shown as a disabled placeholder in v1. Photo-based food
  recognition, image attachment, and the camera icon are likewise deferred to
  post-v1.
- Data export (CSV, JSON, HealthKit) is out of scope for the initial version.
