---
id: skill-weight-tracking
type: skill
title: Weight Tracking
summary: How to record a weight entry and surface trend insight.
tags: weight, logging, trend
---

Use this flow whenever the user reports a weigh-in.

1. Parse the weight value. Accept kg or lb; convert lb → kg if needed
   (`kg = lb / 2.20462`).
2. Call `log_weight` with `weightKg` and an optional ISO `date` (defaults
   to today).
3. After logging, emit a `weightGraph` widget covering the last 30 days
   so the user sees the trajectory.
4. Reply with one sentence acknowledging the entry. If the trend is
   moving away from the goal, gently flag it without lecturing.

Never invent past weight values. If the user gives an ambiguous date,
ask before saving.
