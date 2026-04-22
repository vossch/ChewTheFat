# Data Model: Downward Trajectory — iOS Health Coach App

**Branch**: `001-ios-health-coach-app` | **Date**: 2026-04-20
**Source**: spec.md Key Entities + research.md decisions

---

## Overview

Two distinct storage layers with a strict read/write boundary:

| Layer | Technology | Purpose |
|-------|-----------|---------|
| User Data | SwiftData (`@Model` over SQLite) | Mutable user records: profile, goals, sessions, messages & widgets, weight logs, **food catalog (FoodEntry / Serving) for every food the user has ever logged or manually entered**, food logs. |
| Food Reference (RAG) | GRDB (read-only SQLite) | USDA FoodData Central + Open Food Facts. **Used only as retrieval sources by the food-search RAG tool — never read by display or logging code, never written to at runtime.** |

**Core boundary**: the reference GRDB databases never back a user-visible row. When the
user logs a food retrieved from either reference source, the RAG tool promotes the
chosen `food_entry` + `serving` rows into the SwiftData store (creating a `FoodEntry` +
`Serving` pair if one does not already exist) and every downstream read (LoggedFood,
Meal Card, macro totals, history search) goes through SwiftData. This keeps historical
logs immutable across reference-DB updates and makes the user's personal food catalog
first-class, queryable, and searchable by the RAG tool.

**Naming convention** (to avoid confusion): SwiftData model types are PascalCase
(`FoodEntry`, `Serving`); GRDB reference tables are snake_case (`food_entry`,
`serving`). They are distinct schemas.

**Schema evolution**: additive changes ride SwiftData's automatic (lightweight)
migration. Breaking changes are expressed as a new `VersionedSchema` with a
`MigrationStage.custom(...)` entry in the app's `MigrationPlan` (see research.md §7).
Attribute tables below describe logical shape, not `@Attribute` placement — treat
them as canonical for required, unique, and default-value semantics.

---

## SwiftData Models (User Data)

### UserProfile

Singleton (one record per install).

| Attribute | Type | Constraints |
|-----------|------|-------------|
| `id` | UUID | Primary key, auto-generated |
| `age` | Int16 | 1–120 |
| `heightCm` | Double | Stored in cm; displayed per unit pref |
| `sex` | String | `"male"` \| `"female"` |
| `preferredUnits` | String | `"metric"` \| `"imperial"` |
| `activityLevel` | String | `"sedentary"` \| `"light"` \| `"moderate"` \| `"heavy"` |
| `createdAt` | Date | Set once on first save |
| `eulaAcceptedAt` | Date | Required before any data is collected |

### UserGoals

Singleton; updated whenever goals change.

| Attribute | Type | Constraints |
|-----------|------|-------------|
| `id` | UUID | Primary key |
| `method` | String | `"automatic"` \| `"manual"` |
| `weeklyChangeKg` | Double | Negative = loss; range −0.7 to +0.45 kg/wk |
| `calorieTarget` | Int32 | kcal/day; calculated or manually set |
| `calorieIsManual` | Bool | If true, auto-recalc is suppressed |
| `proteinTargetG` | Double | grams/day |
| `carbsTargetG` | Double | grams/day |
| `fatTargetG` | Double | grams/day |
| `macrosAreManual` | Bool | If true, macro targets are not auto-recalculated |
| `updatedAt` | Date | Stamped on each save |

### Session

A conversation session (a chat thread).

| Attribute | Type | Constraints |
|-----------|------|-------------|
| `id` | UUID | Primary key |
| `name` | String | Auto-generated or user-edited |
| `createdAt` | Date | |
| `lastMessageAt` | Date | Updated on each new message |
| `context` | String? | Optional pre-loaded context |

**Relationships**:
- `messages` → [Message] (one-to-many, cascade delete)

### Message

A single entry in a chat session. A message MAY carry text, MAY carry one or more
widgets (rendered inline in display order), or both.

| Attribute | Type | Constraints |
|-----------|------|-------------|
| `id` | UUID | Primary key |
| `createdAt` | Date | |
| `author` | String | `"user"` \| `"bot"` |
| `textContent` | String? | Plain text; nil if the message is widgets-only |

**Relationships**:
- `session` → Session (many-to-one)
- `widgets` → [MessageWidget] (one-to-many, ordered by `order`, cascade delete)
- `loggedFood` → LoggedFood? (optional link; set when message triggered a food log)
- `weightEntry` → WeightEntry? (optional link; set when message triggered a weight log)

### MessageWidget

An individual interactive widget attached to a `Message`. Multiple `MessageWidget`
rows per `Message` are supported so the agent can emit compound responses (e.g., a
`mealCard` immediately followed by a `macroChart` summarising the impact).

| Attribute | Type | Constraints |
|-----------|------|-------------|
| `id` | UUID | Primary key |
| `order` | Int16 | 0-based display order within the parent message; MUST be unique per `message` |
| `type` | String | `"mealCard"` \| `"macroChart"` \| `"weightGraph"` \| `"quickLog"` (extensible, but each value MUST match a renderer registered in `WidgetRenderer`) |
| `payload` | Data | JSON-encoded widget data, validated against the type's schema |

**Relationships**:
- `message` → Message (many-to-one, required; cascade-deleted with the message)

### FoodEntry

Canonical SwiftData record for a food the user has logged or manually entered. Created
on first reference — either promoted from a RAG source on first log, or created
directly when the user enters a food manually. Subsequent logs of the same food reuse
the existing `FoodEntry`.

| Attribute | Type | Constraints |
|-----------|------|-------------|
| `id` | UUID | Primary key |
| `name` | String | Canonical display name |
| `detail` | String? | Brand, descriptor, preparation style, etc. |
| `source` | String | `"usda"` \| `"offs"` \| `"manual"` \| `"web"` |
| `sourceRefId` | String? | Opaque ID from the originating RAG source (USDA FDC ID, Open Food Facts barcode, web search result key); nil when `source == "manual"` |
| `createdAt` | Date | When the entry was first persisted to SwiftData |
| `lastLoggedAt` | Date | Updated on every `LoggedFood` write — enables recency-weighted RAG ranking |
| `logCount` | Int32 | Incremented on every `LoggedFood` write — enables frequency-weighted RAG ranking |
| `searchTokens` | String | Derived at write time from `name` + `detail` (lower-cased, whitespace-normalised). Indexed; queried by `UserHistorySource` via `#Predicate` `.contains`. Not displayed. |

**Relationships**:
- `servings` → [Serving] (one-to-many, cascade delete)
- `loggedFoods` → [LoggedFood] (one-to-many, cascade delete)

**Uniqueness**: when `sourceRefId` is non-nil, `(source, sourceRefId)` MUST be unique.
This prevents duplicate Core Data rows being created for the same reference-DB food.

**Full-text search**: SwiftData does not expose FTS5 virtual tables directly. For v1,
`FoodEntry` carries a derived `searchTokens: String` attribute (lower-cased, whitespace-
split concatenation of `name` + `detail`) that `UserHistorySource` matches via a
`#Predicate` `.contains` query. Personal catalogs are small enough (sub-thousands of
entries for typical users) that this is adequate. If catalog size grows beyond that
budget, a supplementary GRDB FTS5 index MAY be added over the same SQLite file — this
is deferred as premature optimisation in v1.

### Serving

A named measurement with per-serving nutrition for a specific `FoodEntry`. When a food
is promoted from a RAG source, every serving row for that food_entry in the reference
DB is copied into SwiftData as a `Serving`. When the user enters a food manually, the
user defines at least one `Serving`.

| Attribute | Type | Constraints |
|-----------|------|-------------|
| `id` | UUID | Primary key |
| `measurementName` | String | e.g., `"1 Cup"`, `"100g"`, `"1 large"` |
| `calories` | Double | kcal |
| `proteinG` | Double | grams |
| `carbsG` | Double | grams |
| `fatG` | Double | grams |
| `fiberG` | Double | grams |

**Relationships**:
- `foodEntry` → FoodEntry (many-to-one, required)
- `loggedFoods` → [LoggedFood] (one-to-many)

### LoggedFood

A food item logged by the user for a meal. Holds only the log-specific facts (when,
which meal slot, how much); all nutrition data lives on the referenced `Serving` so
historical logs remain accurate without denormalisation.

| Attribute | Type | Constraints |
|-----------|------|-------------|
| `id` | UUID | Primary key |
| `date` | Date | Normalised to start of day for grouping |
| `meal` | String | `"breakfast"` \| `"lunch"` \| `"dinner"` \| `"snack"` |
| `quantity` | Double | Multiplier applied to the selected serving; MUST be > 0 |

**Relationships**:
- `foodEntry` → FoodEntry (many-to-one, required)
- `serving` → Serving (many-to-one, required)
- `message` → Message? (optional back-link)

**Invariants**:
- `serving.foodEntry == foodEntry` (referential integrity enforced in the repository)
- Computed totals = `quantity × serving.{calories, proteinG, carbsG, fatG, fiberG}`.
- Because `Serving` rows are SwiftData-owned, a reference-DB update cannot retroactively
  mutate any historical log's nutrition. If a user wants the latest reference values
  for a food they've previously logged, they re-pick the food (which creates or
  updates the SwiftData `Serving` set).

### WeightEntry

| Attribute | Type | Constraints |
|-----------|------|-------------|
| `id` | UUID | Primary key |
| `date` | Date | Date of measurement (normalised to start of day) |
| `weightKg` | Double | Stored in kg; displayed per unit pref; must be > 0 |

**Relationships**:
- `message` → Message? (back-link)

### DailySummary

Agent-generated summary for a given day; used as compressed context.

| Attribute | Type | Constraints |
|-----------|------|-------------|
| `id` | UUID | Primary key |
| `date` | Date | The day this summary covers |
| `content` | String | Agent-generated natural language summary |
| `generatedAt` | Date | |

### Memory

Persistent coaching facts the agent retains across sessions.

| Attribute | Type | Constraints |
|-----------|------|-------------|
| `id` | UUID | Primary key |
| `createdAt` | Date | |
| `content` | String | Free-text fact (e.g., "User dislikes dairy") |
| `category` | String? | Optional tag (e.g., `"preference"`, `"health"`) |

### Trends (Singleton)

Pre-aggregated trend data for chart performance.

| Attribute | Type | Constraints |
|-----------|------|-------------|
| `id` | UUID | Primary key (single row) |
| `updatedAt` | Date | Stamped when recomputed |
| `weightRangeStart` | Date | Earliest date in weight log |
| `weightRangeEnd` | Date | Latest date in weight log |
| `weightTrendPayload` | Data | JSON array of `{date, weight, goalLine}` points |
| `macroRangeStart` | Date | Earliest date in food log |
| `macroRangeEnd` | Date | Latest date in food log |
| `macroTrendPayload` | Data | JSON array of `{date, calories, protein, carbs, fat}` |

**Recomputation trigger**: After any `LoggedFood` or `WeightEntry` write, the
`TrendsUpdater` service marks `Trends` stale; a background task recomputes on next
app foreground event.

---

## Food Reference DB Schema (GRDB — Read-Only RAG Sources)

Two separate SQLite files shipped bundled with the app: `usda.sqlite` and `offs.sqlite`.
Both expose the same schema so queries can be unified behind a single
`ReferenceFoodSource` protocol. **These files are read-only, are not migrated at
runtime, and are consumed exclusively by the food-search RAG tool — no display, log,
or repository code may read from them directly.**

### food_entry

| Column | Type | Notes |
|--------|------|-------|
| `id` | TEXT | Source-specific ID (e.g., USDA FDC ID or OFFs barcode) |
| `name` | TEXT | Canonical name |
| `description` | TEXT | Additional detail or brand info |
| `source` | TEXT | `"usda"` \| `"offs"` |

### serving

| Column | Type | Notes |
|--------|------|-------|
| `id` | INTEGER | Auto-increment primary key |
| `food_entry_id` | TEXT | Foreign key → food_entry.id |
| `measurement_name` | TEXT | e.g., `"1 Cup"`, `"100g"`, `"1 oz"` |
| `calories` | REAL | kcal |
| `protein_g` | REAL | grams |
| `carbs_g` | REAL | grams |
| `fat_g` | REAL | grams |
| `fiber_g` | REAL | grams |

### food_fts (FTS5 virtual table)

Indexes `food_entry.name` + `food_entry.description` for full-text search.
Pre-built at database preparation time (not at runtime).

| Column | Notes |
|--------|-------|
| `rowid` | Maps to `food_entry.rowid` |
| `name` | Tokenised for search |
| `description` | Tokenised for search |

**Query pattern**:
```sql
SELECT fe.id, fe.name, fe.source, s.measurement_name, s.calories, ...
FROM food_fts
JOIN food_entry fe ON food_fts.rowid = fe.rowid
JOIN serving s ON s.food_entry_id = fe.id
WHERE food_fts MATCH 'egg*'
ORDER BY rank
LIMIT 20;
```

---

## Food Search (RAG) Sources

`FoodSearchRAG` orchestrates retrieval across four sources in the following precedence
order. Results are merged and ranked before being presented as Meal Card candidates.

| # | Source | Backing store | Notes |
|---|--------|---------------|-------|
| 1 | `UserHistorySource` | **SwiftData (`FoodEntry`)** | User's personal catalog — every food ever logged or manually entered. Ranking combines `#Predicate` match on `searchTokens`, `logCount`, and recency (`lastLoggedAt`). Highest precedence because historical logs are the best predictor of what the user is trying to log now. |
| 2 | `USDAFoodSource` | `usda.sqlite` (GRDB, read-only) | Generic ingredient / whole-food reference. |
| 3 | `OpenFoodFactsSource` | `offs.sqlite` (GRDB, read-only) | Branded / packaged foods. |
| 4 | `WebSearchFallback` | Network (opt-in, per FR-014) | Only engaged when the first three return no usable candidate AND the user has opted in to web fallback. |

### Promotion from RAG to SwiftData

When the user selects a candidate from source 2, 3, or 4 and confirms the log:

1. `FoodEntry` lookup by `(source, sourceRefId)` via `#Predicate`.
2. If found, reuse it and bump `logCount` + `lastLoggedAt`.
3. If not found, create a new `FoodEntry` and copy every matching `serving` row from
   the reference DB into SwiftData as `Serving` records under it.
4. Create the `LoggedFood` row referencing the `FoodEntry` and the specific `Serving`
   the user chose.

After this first log, the food is fully resident in SwiftData and `UserHistorySource`
will surface it at the top of future searches for similar queries — even if the user
is offline or the reference DB is updated.

Manual entries (`source = "manual"`) follow the same flow but skip steps 1–3 for
reference-DB lookup: the user supplies `name`, `detail`, and at least one `Serving`
directly.

---

## Key Validation Rules

| Entity | Rule |
|--------|------|
| UserProfile | `eulaAcceptedAt` MUST be non-nil before any logging |
| UserGoals | `weeklyChangeKg` MUST be in [−0.7, +0.45] kg/wk |
| WeightEntry | `weightKg` MUST be > 0 and < 500 |
| LoggedFood | `quantity` MUST be > 0 |
| LoggedFood | `meal` MUST be one of the four valid slot strings |
| LoggedFood | `serving.foodEntry == foodEntry` (referential integrity) |
| FoodEntry | `(source, sourceRefId)` MUST be unique when `sourceRefId` is non-nil |
| FoodEntry | When `source != "manual"`, `sourceRefId` MUST be non-nil |
| FoodEntry | MUST have at least one related `Serving` before any `LoggedFood` may reference it |
| Message | `author` MUST be `"user"` or `"bot"` |
| Message | At least one of `textContent` (non-empty) or `widgets` (non-empty) MUST be present |
| MessageWidget | `type` MUST match a renderer registered in `WidgetRenderer` |
| MessageWidget | `(message, order)` MUST be unique |

---

## Entity Relationship Summary

```
UserProfile (1) ──── (1) UserGoals
Session (1) ─────── (*) Message
Message (1) ─────── (*) MessageWidget          (ordered, cascade delete)
Message (0..1) ──── (0..1) LoggedFood
Message (0..1) ──── (0..1) WeightEntry
FoodEntry (1) ───── (*) Serving                (cascade delete)
FoodEntry (1) ───── (*) LoggedFood
Serving   (1) ───── (*) LoggedFood
```

All food-related relationships are **internal to SwiftData**. Reference GRDB databases
are not joined against SwiftData at query time — reference data is either consumed
transiently by the RAG tool or promoted into SwiftData via `FoodEntry`/`Serving`
records (see "Promotion from RAG to SwiftData" above).
