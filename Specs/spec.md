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
imperial), filling in their profile (age, height, sex), setting a weight-change goal
(weekly rate and method), and optionally setting macro targets. After completing setup,
the user lands on the main chat screen ready to start logging.

**Why this priority**: Without a complete profile the app cannot calculate calorie or
macro targets. All downstream value depends on this flow being smooth and completable.

**Independent Test**: A brand-new install with no existing data can be walked through
onboarding from launch to the main chat screen, resulting in a persisted user profile
and goals record.

**Acceptance Scenarios**:

1. **Given** the app is freshly installed with no data, **When** the user opens the app,
   **Then** the health coach initiates the onboarding flow with a welcome message and
   asks the user to choose their preferred units (metric/imperial) via interactive widgets.
2. **Given** the user has chosen units and provided age, height, and sex,
   **When** they confirm their profile, **Then** the app automatically calculates a
   recommended daily calorie target and macro split and presents them for approval.
3. **Given** the user accepts or adjusts their goals, **When** they complete onboarding,
   **Then** their profile, goals, and preferences are persisted locally and they are
   taken to the main chat screen.
4. **Given** the user abandons onboarding mid-flow, **When** they reopen the app,
   **Then** the onboarding resumes from where they left off.

---

### User Story 2 — Log a Meal via Chat (Priority: P1)

The user types (or speaks) a description of what they ate into the chat interface. The
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
   turkey bacon, grapefruit"), **When** the agent processes the input, **Then** a Meal
   Card widget appears in the chat listing each food item, its quantity, serving unit,
   and calorie contribution.
2. **Given** a Meal Card is displayed, **When** the user taps a serving unit or quantity,
   **Then** they can adjust it inline and the calorie/macro totals update immediately.
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

---

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: The app MUST operate entirely on-device; no user data, food logs, weight
  logs, or LLM inference MUST be transmitted to any external server.
- **FR-002**: The app MUST provide a conversational chat interface as the primary
  interaction surface for logging, coaching, and progress review.
- **FR-003**: The health coach agent MUST support rendering the following interactive
  widget types inline within the chat: Meal Card, Macro Chart, Weight Graph, and
  quick-log / confirmation dialogs.
- **FR-003a**: The orchestration layer MUST intercept widget payloads produced by the
  agent before they are streamed to the chat UI; widgets MUST be rendered as native
  interactive components, not as raw text or JSON.
- **FR-003b**: Tool calls and internal agent reasoning MUST NOT be displayed to the user
  in the chat interface; only finalized text messages and rendered widgets are visible.
- **FR-004**: The app MUST support food search against local USDA FoodData Central and
  Open Food Facts SQLite databases without requiring network access.
- **FR-005**: The app MUST automatically calculate macro totals (calories, protein,
  carbohydrates, fat, fiber) from logged food entries using data from the reference
  databases.
- **FR-006**: The app MUST support logging weight entries with a date, accessible from
  the chat interface via a widget and from a dedicated logging surface.
- **FR-007**: The app MUST persist all user data (profile, goals, food logs, weight logs,
  session logs, memories) locally using Core Data.
- **FR-008**: The app MUST support a user profile containing: age, height, sex, preferred
  units (metric/imperial), and activity level.
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
- **FR-017**: The local data store MUST support automatic lightweight migration across
  app versions wherever the schema change permits it. Breaking schema changes MUST use
  manual mapping migrations. User data MUST NOT be silently destroyed or reset during
  any app update.

### Key Entities

- **UserProfile**: Age, height, sex, preferred units (metric/imperial), activity level.
- **UserGoals**: Weight-change method, weekly target, macro targets (protein/carbs/fat),
  calorie target, all calculated or manual.
- **Session**: Conversation session with name, creation date, last message date, and
  session goal.
- **Message**: DateTime, author (User/Bot), content (text and/or widget references),
  optional linked food log ID, optional linked weight log ID.
- **FoodEntry**: Name, description, data source(s) (USDA / Open Food Facts).
- **Serving**: Associated FoodEntry, measurement name (e.g., "1 Cup"), calories,
  protein (g), carbs (g), fat (g), fiber (g).
- **LoggedFood**: FoodEntry reference, date, quantity, meal slot, selected serving.
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

## Assumptions

- The LLM model file (Apple MLX or llama.cpp compatible) is bundled with the app or
  downloaded on first launch before onboarding begins; the specific model is to be
  determined in the implementation plan.
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
- Barcode scanning and photo-based food recognition are not included in the initial
  version (voice input via system dictation is allowed as it uses on-device processing).
- Data export (CSV, JSON, HealthKit) is out of scope for the initial version.
