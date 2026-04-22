# Data Model: Downward Trajectory — iOS Health Coach App

**Branch**: `001-ios-health-coach-app` | **Date**: 2026-04-20
**Source**: spec.md Key Entities + research.md decisions

---

## Overview

Two distinct storage layers:

| Layer | Technology | Purpose |
|-------|-----------|---------|
| User Data | Core Data (SQLite) | Mutable user records: profile, goals, logs, sessions |
| Food Reference | GRDB (read-only SQLite) | USDA + Open Food Facts food/nutrient data |

---

## Core Data Entities (User Data)

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

A single entry in a chat session.

| Attribute | Type | Constraints |
|-----------|------|-------------|
| `id` | UUID | Primary key |
| `createdAt` | Date | |
| `author` | String | `"user"` \| `"bot"` |
| `textContent` | String? | Plain text; nil if message is widget-only |
| `widgetType` | String? | `"mealCard"` \| `"macroChart"` \| `"weightGraph"` \| `"quickLog"` \| nil |
| `widgetPayload` | Data? | JSON-encoded widget data blob |

**Relationships**:
- `session` → Session (many-to-one)
- `loggedFood` → LoggedFood? (optional link; set when message triggered a food log)
- `weightEntry` → WeightEntry? (optional link; set when message triggered a weight log)

### LoggedFood

A food item logged by the user for a meal.

| Attribute | Type | Constraints |
|-----------|------|-------------|
| `id` | UUID | Primary key |
| `date` | Date | Normalised to start of day for grouping |
| `meal` | String | `"breakfast"` \| `"lunch"` \| `"dinner"` \| `"snack"` |
| `quantity` | Double | Multiplier applied to selected serving |
| `foodEntryId` | String | External ID in food reference DB (USDA or OFFs) |
| `foodSource` | String | `"usda"` \| `"offs"` \| `"manual"` |
| `foodName` | String | Denormalised for display without DB join |
| `servingName` | String | e.g., "1 Cup", "100g" |
| `caloriesPerServing` | Double | Snapshot from reference DB at log time |
| `proteinPerServing` | Double | grams |
| `carbsPerServing` | Double | grams |
| `fatPerServing` | Double | grams |
| `fiberPerServing` | Double | grams |

**Note**: Macro values are snapshotted at log time to avoid drift if the reference DB
is updated. Computed totals = `quantity × *PerServing`.

**Relationships**:
- `message` → Message? (back-link)

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

## Food Reference DB Schema (GRDB — Read-Only)

Two separate SQLite files: `usda.sqlite` and `offs.sqlite`.
Both expose the same schema so queries can be unified via a `FoodRepository` protocol.

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

## Key Validation Rules

| Entity | Rule |
|--------|------|
| UserProfile | `eulaAcceptedAt` MUST be non-nil before any logging |
| UserGoals | `weeklyChangeKg` MUST be in [−0.7, +0.45] kg/wk |
| WeightEntry | `weightKg` MUST be > 0 and < 500 |
| LoggedFood | `quantity` MUST be > 0 |
| LoggedFood | `meal` MUST be one of the four valid slot strings |
| Message | `author` MUST be `"user"` or `"bot"` |
| Message | At least one of `textContent` or `widgetPayload` MUST be non-nil |

---

## Entity Relationship Summary

```
UserProfile (1) ──── (1) UserGoals
Session (1) ─────── (*) Message
Message (0..1) ──── (0..1) LoggedFood
Message (0..1) ──── (0..1) WeightEntry
LoggedFood (*) ──── (1) [FoodEntry in reference DB — not a Core Data relationship]
```
