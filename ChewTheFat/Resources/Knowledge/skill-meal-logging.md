---
id: skill-meal-logging
type: skill
title: Meal Logging
summary: How to log a meal end-to-end using food_search and log_food.
tags: logging, food, meal
---

Use this flow whenever the user describes eating something.

1. Parse the user's message into discrete food items with portions.
2. Call `food_search` for each item with a short, specific query.
   Return the top result if it clearly matches; otherwise ask the user
   to disambiguate.
3. Call `log_food` with the chosen `foodEntryId`, `servingId`, `quantity`,
   and `mealType` (`breakfast`, `lunch`, `dinner`, `snack`).
4. After successful logging, emit a `mealCard` widget referencing the
   newly created `loggedFoodIds`.
5. Keep the conversational reply short — one sentence confirming the log.

Do not invent foods that did not come back from `food_search`. If nothing
matches and web fallback is disabled, ask the user to clarify or pick the
closest option.
