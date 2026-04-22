# ChewTheFat iOS — Xcode Project Architecture

```
ChewTheFat/
├── ChewTheFat.xcodeproj
├── ChewTheFat/
│   │
│   ├── App/
│   │   ├── ChewTheFatApp.swift                    // @main entry point
│   │   ├── AppDelegate.swift                       // Scheduled jobs, background tasks
│   │   ├── AppEnvironment.swift                    // Dependency container
│   │   └── Info.plist
│   │
│   ├── Agent/
│   │   ├── Orchestrator/
│   │   │   ├── Orchestrator.swift                  // Central coordinator
│   │   │   ├── OrchestratorProtocol.swift
│   │   │   ├── TurnHandler.swift                   // Single conversation turn lifecycle
│   │   │   ├── ToolCallDispatcher.swift            // Routes tool calls to implementations
│   │   │   ├── WidgetIntentResolver.swift          // Decodes model output into WidgetIntent
│   │   │   └── SessionStateManager.swift           // In-memory current session state
│   │   │
│   │   ├── ContextManager/
│   │   │   ├── ContextManager.swift                // Assembles prompt context
│   │   │   ├── ContextAssembler.swift              // Composes context pieces with priority
│   │   │   ├── ContextBudget.swift                 // Token budgeting & truncation
│   │   │   ├── ContextSource.swift                 // Protocol for context contributors
│   │   │   └── Sources/
│   │   │       ├── SessionContextSource.swift
│   │   │       ├── GoalContextSource.swift
│   │   │       ├── MemoryContextSource.swift
│   │   │       ├── KnowledgeContextSource.swift
│   │   │       └── ProfileContextSource.swift
│   │   │
│   │   ├── Model/
│   │   │   ├── ModelClient.swift                   // Llama
│   │   │   ├── ModelRequest.swift
│   │   │   ├── ModelResponse.swift
│   │   │   ├── StreamingHandler.swift
│   │   │   └── ToolSchema.swift                    // Tool definitions for the model
│   │   │
│   │   ├── Memory/
│   │   │   ├── MemoryWriter.swift                  // Post-session summarization hook
│   │   │   ├── DailySummaryGenerator.swift
│   │   │   ├── TrendsGenerator.swift
│   │   │   └── MemoryTrigger.swift                 // Decides when to write memory
│   │   │
│   │   └── Scheduling/
│   │       ├── ScheduledJobRunner.swift            // BGTaskScheduler integration
│   │       ├── SessionTrigger.swift                // e.g. "ask about breakfast"
│   │       └── SessionConflictPolicy.swift         // Suppress/queue/interrupt logic
│   │
│   ├── Tools/
│   │   ├── ToolProtocol.swift                      // Base protocol for all tools
│   │   ├── ToolResult.swift
│   │   ├── ToolError.swift
│   │   │
│   │   ├── Retrieval/
│   │   │   ├── FoodSearchTool.swift
│   │   │   ├── FoodSearchRAG.swift                 // Orchestrates across three sources
│   │   │   ├── LookupKnowledgeTool.swift
│   │   │   └── Sources/
│   │   │       ├── OpenFoodFactsSource.swift
│   │   │       ├── USDAFoodSource.swift
│   │   │       └── WebSearchFallback.swift
│   │   │
│   │   └── Action/
│   │       ├── LogFoodTool.swift
│   │       ├── LogWeightTool.swift
│   │       ├── SetGoalsTool.swift
│   │       └── SetProfileInfoTool.swift
│   │
│   ├── Knowledge/
│   │   ├── KnowledgeGraph.swift                    // Main interface
│   │   ├── KnowledgeGraphLoader.swift              // Reads markdown files from bundle/docs
│   │   ├── KnowledgeIndex.swift                    // Parses Index.md
│   │   ├── KnowledgeFile.swift                     // Single .md file representation
│   │   ├── KnowledgeType.swift                     // .goal, .skill, .reference
│   │   ├── KnowledgeSelector.swift                 // Picks relevant knowledge per session
│   │   └── Resources/
│   │       ├── Index.md
│   │       ├── goal-weight-loss.md
│   │       ├── goal-muscle-gain.md
│   │       ├── goal-maintenance.md
│   │       ├── skill-meal-logging.md
│   │       ├── skill-weight-tracking.md
│   │       ├── skill-onboarding.md
│   │       └── reference-macronutrients.md
│   │
│   ├── Data/
│   │   ├── CoreData/
│   │   │   ├── ChewTheFat.xcdatamodeld
│   │   │   ├── PersistenceController.swift
│   │   │   └── CoreDataStack.swift
│   │   │
│   │   ├── Models/
│   │   │   ├── Session+CoreDataClass.swift
│   │   │   ├── Message+CoreDataClass.swift
│   │   │   ├── FoodEntry+CoreDataClass.swift
│   │   │   ├── Serving+CoreDataClass.swift
│   │   │   ├── LoggedFood+CoreDataClass.swift
│   │   │   ├── WeightEntry+CoreDataClass.swift
│   │   │   ├── UserGoal+CoreDataClass.swift
│   │   │   ├── UserProfile+CoreDataClass.swift
│   │   │   ├── DailySummary+CoreDataClass.swift
│   │   │   └── Trends+CoreDataClass.swift
│   │   │
│   │   ├── Repositories/
│   │   │   ├── SessionRepository.swift
│   │   │   ├── FoodLogRepository.swift
│   │   │   ├── WeightLogRepository.swift
│   │   │   ├── GoalRepository.swift
│   │   │   ├── ProfileRepository.swift
│   │   │   └── MemoryRepository.swift
│   │   │
│   │   └── LocalDatabases/
│   │       ├── OpenFoodFactsDB.swift               // SQLite wrapper
│   │       ├── USDAFoodDB.swift
│   │       └── DatabaseMigrator.swift
│   │
│   ├── Domain/
│   │   ├── SessionGoal.swift                       // .logMeal, .logWeight, .userInsights, etc.
│   │   ├── WidgetIntent.swift                      // .mealCard, .weightGraph, .macroChart
│   │   ├── NutritionFacts.swift
│   │   ├── MealType.swift                          // .breakfast, .lunch, .dinner, .snack
│   │   ├── ActivityLevel.swift
│   │   ├── WeeklyChangeTarget.swift
│   │   └── FoodSource.swift                        // .openFoodFacts, .usda, .web, .userEntered
│   │
│   ├── UI/
│   │   ├── Chat/
│   │   │   ├── ChatView.swift                      // Main chat surface
│   │   │   ├── ChatViewModel.swift
│   │   │   ├── MessageBubble.swift
│   │   │   ├── MessageListView.swift
│   │   │   ├── ChatInputBar.swift
│   │   │   └── SuggestedRepliesView.swift
│   │   │
│   │   ├── Widgets/
│   │   │   ├── WidgetRenderer.swift                // Dispatches WidgetIntent to views
│   │   │   ├── MealCard/
│   │   │   │   ├── MealCardView.swift
│   │   │   │   └── MealCardViewModel.swift
│   │   │   ├── WeightGraph/
│   │   │   │   ├── WeightGraphView.swift
│   │   │   │   └── WeightGraphViewModel.swift
│   │   │   └── MacroChart/
│   │   │       ├── MacroChartView.swift
│   │   │       └── MacroChartViewModel.swift
│   │   │
│   │   ├── Onboarding/
│   │   │   ├── OnboardingCoordinator.swift
│   │   │   ├── EULAView.swift
│   │   │   ├── ProfileSetupView.swift
│   │   │   └── GoalSetupView.swift
│   │   │
│   │   ├── Settings/
│   │   │   ├── SettingsView.swift
│   │   │   ├── ProfileEditView.swift
│   │   │   └── GoalsEditView.swift
│   │   │
│   │   └── Shared/
│   │       ├── DesignSystem/
│   │       │   ├── Colors.swift
│   │       │   ├── Typography.swift
│   │       │   ├── Spacing.swift
│   │       │   └── Components/
│   │       │       ├── PrimaryButton.swift
│   │       │       ├── Card.swift
│   │       │       └── ValueRow.swift
│   │       └── Modifiers/
│   │           └── ViewModifiers.swift
│   │
│   ├── Services/
│   │   ├── Logging/
│   │   │   ├── Logger.swift
│   │   │   └── AnalyticsClient.swift
│   │   ├── Networking/
│   │   │   ├── HTTPClient.swift
│   │   │   └── NetworkReachability.swift
│   │   └── Security/
│   │       ├── Keychain.swift
│   │       └── APIKeyProvider.swift
│   │
│   ├── Utilities/
│   │   ├── Extensions/
│   │   │   ├── Date+Extensions.swift
│   │   │   ├── String+Extensions.swift
│   │   │   └── Decimal+Locale.swift
│   │   ├── Formatters/
│   │   │   ├── NutritionFormatter.swift
│   │   │   └── WeightFormatter.swift
│   │   └── Concurrency/
│   │       └── AsyncDebouncer.swift
│   │
│   └── Resources/
│       ├── Assets.xcassets
│       ├── Localizable.xcstrings
│       └── LaunchScreen.storyboard
│
└── Packages/                                       // Optional: extract to SPM later
    └── (future modularization targets)
```

## Organizing Principles

**Layered by concern, not by type.** Folders map to architectural roles from the diagram (Agent, Tools, Knowledge, Data, UI) rather than grouping all ViewModels or all Models together. This mirrors how you'll navigate while working on a feature.

**Agent is the biggest module and deserves internal structure.** Orchestrator, ContextManager, Model, Memory, and Scheduling are all sub-concerns of the agent harness. Each gets its own subfolder so the Orchestrator folder isn't a dumping ground.

**Tools are split by read vs. write.** Retrieval (FoodSearch, LookupKnowledge) and Action (Log*, Set*) are separate folders, matching the feedback about Tools doing two unrelated jobs.

**Domain layer sits between Data and UI.** Pure Swift types like `SessionGoal`, `WidgetIntent`, `MealType` live here with no Core Data or SwiftUI dependencies. This is what lets you unit test the agent without standing up a persistence stack.

**Repositories wrap Core Data.** The rest of the app talks to repositories, not to `NSManagedObjectContext` directly. Makes testing and future migration away from Core Data tractable.

**Knowledge files live in Resources/ as bundled markdown.** For v1, ship them in the app bundle. Later, you can move them to the documents directory and allow user/remote updates without changing the loading code.

**UI widgets have their own subfolders with view + viewmodel pairs.** Each widget is self-contained. WidgetRenderer is the dispatcher the Orchestrator's output flows through.

**Tests mirror the source tree.** One-to-one folder structure between `ChewTheFat/`
## Future Modularization

The `Packages/` folder is a placeholder. Once the app stabilizes, consider extracting:

- `ChewTheFatAgent` — everything in Agent/, Tools/, Knowledge/, Domain/
- `ChewTheFatData` — Data/ and repositories
- `ChewTheFatUI` — the design system and shared components

This forces dependency discipline (the Agent package can't accidentally import SwiftUI) and speeds up incremental builds. Don't do it on day one — SPM modularization is a tax you pay for structure you don't need yet.

## A Few Things I Deliberately Did Not Include

- **No `Managers/` or `Helpers/` folders.** These are almost always architectural smells. Every file here has a specific role expressed in its name.
- **No separate `Protocols/` folder.** Protocols live next to their primary implementation — `OrchestratorProtocol.swift` sits in `Orchestrator/`.
- **No `ViewModels/` megafolder.** ViewModels live with their views. A feature is a cohesive unit.
- **No `Constants/` folder.** Design tokens go in `DesignSystem/`, everything else is either in a config file or a domain enum.
