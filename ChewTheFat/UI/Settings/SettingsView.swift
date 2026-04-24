import SwiftUI

/// Settings root (US6). Hosts the units toggle, web-search fallback toggle,
/// and navigation links to the dedicated Profile / Goals editors. Switching
/// units here re-renders the app without mutating stored canonical values
/// (see `UnitFormatter`).
@MainActor
struct SettingsView: View {
    let environment: AppEnvironment
    @Bindable var preferences: AppPreferences
    @State private var preferredUnits: PreferredUnitSystem = .metric

    var body: some View {
        Form {
            Section("Units") {
                Picker("Preferred units", selection: $preferredUnits) {
                    ForEach(PreferredUnitSystem.allCases, id: \.self) { system in
                        Text(system.displayName).tag(system)
                    }
                }
                .pickerStyle(.segmented)
                .onChange(of: preferredUnits) { _, newValue in
                    persistUnits(newValue)
                }
            }

            Section("Profile & goals") {
                NavigationLink("Profile") {
                    ProfileEditView(viewModel: ProfileEditViewModel(profile: environment.profile))
                }
                NavigationLink("Goals") {
                    GoalsEditView(viewModel: GoalsEditViewModel(
                        goals: environment.goals,
                        profile: environment.profile
                    ))
                }
            }

            Section(
                header: Text("Food search"),
                footer: Text(
                    "When the local food databases don't have a match, let the model query the web. Off by default; enables only for the single fallback."
                )
            ) {
                Toggle("Web search fallback", isOn: $preferences.webSearchFallbackEnabled)
            }
        }
        .navigationTitle("Settings")
        .navigationBarTitleDisplayMode(.inline)
        .task { loadUnits() }
    }

    private func loadUnits() {
        let stored = (try? environment.profile.current())?.preferredUnits
        self.preferredUnits = PreferredUnitSystem(storedValue: stored)
    }

    private func persistUnits(_ system: PreferredUnitSystem) {
        let repo = environment.profile
        let profile: UserProfile
        do {
            if let existing = try repo.current() {
                profile = existing
            } else {
                profile = UserProfile(
                    age: 0,
                    heightCm: 0,
                    sex: "",
                    preferredUnits: system.rawValue,
                    activityLevel: ""
                )
            }
            profile.preferredUnits = system.rawValue
            try repo.save(profile)
        } catch {
            // Silent fall-through — Form is a fire-and-forget toggle; a
            // persistence failure here just means the picker snaps back on
            // next load. Nothing to surface to the user beyond the UI.
        }
    }
}
