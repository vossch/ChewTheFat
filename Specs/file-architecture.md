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
│   │   │       ├── GoalProgressContextSource.swift  // Collected/missing checklist for current goal's contract
│   │   │       ├── MemoryContextSource.swift
│   │   │       ├── KnowledgeContextSource.swift
│   │   │       └── ProfileContextSource.swift
│   │   │
│   │   ├── Model/
│   │   │   ├── ModelClientProtocol.swift
│   │   │   ├── MLXModelClient.swift                 // Apple MLX-Swift (mlx-swift-lm)
│   │   │   ├── StubModelClient.swift                // Test / pre-bootstrap stand-in
│   │   │   ├── ModelBootstrapper.swift              // First-launch HF Hub fetch (constitution 1.1.0)
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
│   │   │   ├── FoodSearchRAG.swift                 // Orchestrates across four sources
│   │   │   ├── LookupKnowledgeTool.swift
│   │   │   └── Sources/
│   │   │       ├── UserHistorySource.swift         // #1: Core Data FoodEntry catalog
│   │   │       ├── USDAFoodSource.swift            // #2: usda.sqlite, read-only
│   │   │       ├── OpenFoodFactsSource.swift       // #3: offs.sqlite, read-only
│   │   │       └── WebSearchFallback.swift         // #4: opt-in, network
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
│   │   ├── SwiftData/
│   │   │   ├── ChewTheFatSchema.swift               // VersionedSchema chain + MigrationPlan
│   │   │   ├── ModelContainerProvider.swift         // Builds the app's single ModelContainer
│   │   │   └── ModelContextFactory.swift            // viewContext + background ModelActor helpers
│   │   │
│   │   ├── Models/                                  // @Model types (SwiftData)
│   │   │   ├── Session.swift
│   │   │   ├── Message.swift
│   │   │   ├── MessageWidget.swift                  // Ordered widgets per message (1..N)
│   │   │   ├── FoodEntry.swift                      // User's food catalog (promoted/manual)
│   │   │   ├── Serving.swift                        // Servings, owned by FoodEntry
│   │   │   ├── LoggedFood.swift                     // References FoodEntry + Serving
│   │   │   ├── WeightEntry.swift
│   │   │   ├── UserGoal.swift
│   │   │   ├── UserProfile.swift
│   │   │   ├── DailySummary.swift
│   │   │   └── Trends.swift
│   │   │
│   │   ├── Repositories/                            // Domain-typed façades over SwiftData
│   │   │   ├── SessionRepository.swift
│   │   │   ├── FoodLogRepository.swift
│   │   │   ├── WeightLogRepository.swift
│   │   │   ├── GoalRepository.swift
│   │   │   ├── ProfileRepository.swift
│   │   │   └── MemoryRepository.swift
│   │   │
│   │   └── LocalDatabases/                          // Read-only GRDB wrappers (RAG only)
│   │       ├── OpenFoodFactsDB.swift
│   │       ├── USDAFoodDB.swift
│   │       └── DatabaseMigrator.swift               // No-op at runtime; build-time prep only
│   │
│   ├── Domain/
│   │   ├── SessionGoal.swift                       // .onboarding, .logMeal, .logWeight, .userInsights, etc.
│   │   ├── SessionGoalContract.swift               // Required-fields contract per SessionGoal (FR-028)
│   │   ├── SessionGoalEvaluator.swift              // Evaluates a contract against SwiftData → (satisfied, collected, missing)
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
│   │   ├── Dashboard/                              // US7: Home Dashboard (FR-018)
│   │   │   ├── DashboardView.swift                 // Trajectory + Today + meals + chips + history
│   │   │   ├── DashboardViewModel.swift            // Aggregates repo data; reacts live to SwiftData
│   │   │   ├── TodayPanelView.swift                // Calories-left headline + macro bars + meals list
│   │   │   ├── ChatHistoryListView.swift           // Prior sessions; opens via SessionStateManager
│   │   │   └── DashboardNavChipsView.swift         // Goals / Profile / Settings entry points
│   │   │
│   │   ├── Widgets/                                // Dual-use: chat (payload-driven) + dashboard (live)
│   │   │   ├── WidgetRenderer.swift                // Dispatches WidgetIntent to views
│   │   │   ├── MealCard/
│   │   │   │   ├── MealCardView.swift
│   │   │   │   └── MealCardViewModel.swift         // .snapshot(payload:) + .live(repo:) factories
│   │   │   ├── WeightGraph/
│   │   │   │   ├── WeightGraphView.swift           // Used inline in chat AND as Dashboard Trajectory
│   │   │   │   └── WeightGraphViewModel.swift
│   │   │   └── MacroChart/
│   │   │       ├── MacroChartView.swift
│   │   │       └── MacroChartViewModel.swift
│   │   │
│   │   ├── Onboarding/
│   │   │   ├── OnboardingCoordinator.swift
│   │   │   ├── EULAView.swift
│   │   │   ├── ModelBootstrapView.swift             // First-launch model fetch progress UI
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

**Repositories wrap SwiftData.** The rest of the app talks to repositories, not to `ModelContext` directly. Makes testing and future migration (or framework swap) tractable, and gives a single seam for the Domain-typed return contracts.

**Knowledge files live in Resources/ as bundled markdown.** For v1, ship them in the app bundle. Later, you can move them to the documents directory and allow user/remote updates without changing the loading code.

**UI widgets are dual-use.** Each widget has its own subfolder with view + viewmodel pair. Widgets are shared between the chat thread (driven by a `MessageWidget.payload` of **references** into SwiftData — `loggedFoodIds`, `date`, `dateRange` — not denormalised nutrition) and the Dashboard (driven by live repository reads). A user edit to an underlying log is reflected in every surface that presents it. `WidgetRenderer` is the dispatcher the Orchestrator's output flows through for the chat path; the Dashboard instantiates the same views with a `.live(repo:)` factory.

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
