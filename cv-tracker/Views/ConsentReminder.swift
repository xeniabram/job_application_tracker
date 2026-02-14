
import SwiftUI
import SwiftData

struct ConsentReminderSheet: View {
    @Environment(\.dismiss) var dismiss
    @Bindable var item: ApplicationItem
    var onSuccess: (() -> Void)?
    
    @State private var selectedWeeks: Int
    @State private var actionDetails: String = ""

    init(item: ApplicationItem, onSuccess: (() -> Void)? = nil) {
        self.item = item
        self.onSuccess = onSuccess
        _selectedWeeks = State(initialValue: item.consentInterval > 0 ? item.consentInterval : 4)
    }

    var body: some View {
        VStack(spacing: 20) {
            Text("Consent Action Required").font(.headline)
            
            Form {
                Section("Action Details") {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("What needs to be done?")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        
                        TextEditor(text: $actionDetails)
                            .font(.body)
                            .frame(height: 100)
                            .padding(6)
                            .scrollContentBackground(.hidden)
                            .background(Color(NSColor.textBackgroundColor))
                            .cornerRadius(4)
                            .overlay(RoundedRectangle(cornerRadius: 4).stroke(Color.gray.opacity(0.2)))
                        
                        Text("Default: Action on personal data consents needed")
                            .font(.caption2)
                            .italic()
                            .foregroundStyle(.tertiary)
                    }
                }
                
                Section {
                    Picker("Remind me in:", selection: $selectedWeeks) {
                        Text("1 Week").tag(1)
                        Text("2 Weeks").tag(2)
                        Text("1 Month").tag(4)
                        Text("3 Months").tag(12)
                    }
                }
            }
            .formStyle(.grouped)

            HStack {
                Button("Cancel", role: .cancel) { dismiss() }
                Spacer()
                Button(item.consentActionRequired ? "Update Reminder" : "Create Reminder") {
                    let finalTitle = actionDetails.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                        ? "Action on personal data consents needed"
                        : actionDetails
                    
                    item.consentActionRequired = true
                    item.consentInterval = selectedWeeks
                    
                    Task {
                        await ReminderManager.shared.scheduleReminder(for: item, customTitle: finalTitle)
                        dismiss()
                        onSuccess?()
                    }
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .padding()
        .frame(width: 450, height: 450)
    }
}
