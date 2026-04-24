import SwiftUI

/// Profile editor (US6). Mirrors the fields the agent collects during
/// onboarding: birth year, height, sex, units, activity level. The user can
/// switch units without altering the stored canonical value — the display
/// string re-renders, storage stays in cm.
@MainActor
struct ProfileEditView: View {
    @Bindable var viewModel: ProfileEditViewModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        Form {
            Section("Units") {
                Picker("Units", selection: $viewModel.preferredUnits) {
                    ForEach(PreferredUnitSystem.allCases, id: \.self) { system in
                        Text(system.displayName).tag(system)
                    }
                }
                .pickerStyle(.segmented)
            }

            Section("About you") {
                Picker("Birth year", selection: $viewModel.birthYear) {
                    ForEach(Array(viewModel.birthYearRange), id: \.self) { year in
                        Text(verbatim: "\(year)").tag(year)
                    }
                }
                Picker("Sex", selection: $viewModel.sex) {
                    ForEach(viewModel.sexOptions, id: \.self) { value in
                        Text(value.capitalized).tag(value)
                    }
                }
                TextField(heightPlaceholder, text: $viewModel.heightInput)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
            }

            Section("Activity") {
                Picker("Activity level", selection: $viewModel.activityLevel) {
                    ForEach(ActivityLevel.allCases, id: \.self) { level in
                        Text(level.displayName).tag(level)
                    }
                }
            }

            if let message = viewModel.errorMessage {
                Section {
                    Label(message, systemImage: AppIcon.warning)
                        .foregroundStyle(AppColor.error)
                }
            }
        }
        .navigationTitle("Profile")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Save") {
                    if viewModel.save() { dismiss() }
                }
            }
        }
        .task { viewModel.load() }
    }

    private var heightPlaceholder: String {
        viewModel.preferredUnits == .imperial ? "Height (e.g. 5'11\")" : "Height (e.g. 180 cm)"
    }
}
