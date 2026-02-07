import SwiftUI
import SwiftData

struct ApplicationDetailView: View {
    @Bindable var item: ApplicationItem
    @Environment(\.modelContext) private var modelContext
    
    @State private var showingDeleteAlert = false
    @State private var isEditingNotes = false
    @State private var showingConsentSheet = false

    var body: some View {
        Form {
            // 1. Core Info
            Section("General Info") {
                TextField("Company", text: $item.companyName)
                TextField("Position", text: $item.position)
                DatePicker("Date Applied", selection: $item.dateApplied, displayedComponents: .date)
                
                Picker("Status", selection: $item.status) {
                    ForEach(ApplicationStatus.allCases, id: \.self) { status in
                        Text(status.rawValue).tag(status as ApplicationStatus?)
                    }
                }
            }

            // 2. Document Management
            Section("CV") {
                cvSection
            }
            
            // 3. Timeline management
            TimelineSection(application: item)
            
            // 4. Privacy & Consents
            Section(header: consentHeader) {
                consentContent
            }
            
            // 4. Danger Zone
            Section {
                deleteButton
            }
        }
        .formStyle(.grouped)
        .navigationTitle(item.companyName.isEmpty ? "Details" : item.companyName)
        // This works even if the sheet is in another file!
        .sheet(isPresented: $showingConsentSheet) {
            ConsentReminderSheet(item: item)
        }
        .alert("Delete Application", isPresented: $showingDeleteAlert) {
            Button("Delete", role: .destructive) { modelContext.delete(item) }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("Are you sure?")
        }
    }
}

// MARK: - Extracted UI Components
extension ApplicationDetailView {
    
    private var cvSection: some View {
        HStack {
            if let cvName = item.cvUrl?.lastPathComponent {
                Label(cvName, systemImage: "doc.text").foregroundStyle(.secondary)
                Spacer()
                Button("Open") { FileUtils.openFile(url: item.cvUrl, bookmark: item.cvBookmark) }
            } else {
                Text("No CV attached").foregroundStyle(.secondary)
            }
            Button(item.cvUrl == nil ? "Attach" : "Replace") {
                if let result = FileUtils.selectFile() {
                    item.cvUrl = result.url
                    item.cvBookmark = result.bookmark
                }
            }
        }
    }
    
    private var consentHeader: some View {
        HStack {
            Text("Consents")
            Spacer()
            Button(isEditingNotes ? "Done" : "Edit") { isEditingNotes.toggle() }
                .buttonStyle(.link)
        }
    }
    
    @ViewBuilder
    private var consentContent: some View {
        if isEditingNotes {
            LinkEnabledEditor(text: $item.consentsText)
                .frame(minHeight: 200)
                .padding(4)
                .background(Color(NSColor.textBackgroundColor))
                .cornerRadius(6)
        } else {
            VStack(alignment: .leading, spacing: 12) {
                Text(.init(item.consentsText.isEmpty ? "*No notes provided*" : item.consentsText))
                    .frame(minHeight: 180, alignment: .topLeading)
                    .padding(8)
                    .background(Color(NSColor.controlBackgroundColor).opacity(0.5))
                    .cornerRadius(6)
                    .onTapGesture(count: 2) { isEditingNotes = true }

                if item.consentActionRequired {
                    HStack {
                        VStack(alignment: .leading) {
                            Label("Reminder Active", systemImage: "bell.badge.fill").foregroundStyle(.green)
                            Text("Due in \(item.consentInterval) weeks").font(.caption).foregroundStyle(.secondary)
                        }
                        Spacer()
                        Button("Complete") {
                            item.consentActionRequired = false
                            item.reminderID = nil
                        }.controlSize(.small)
                        Button("Edit") { showingConsentSheet = true }.controlSize(.small)
                    }
                } else {
                    Button(action: { showingConsentSheet = true }) {
                        Label("Setup Consent Withdrawal Reminder", systemImage: "bell").frame(maxWidth: .infinity)
                    }.buttonStyle(.bordered)
                }
            }
        }
    }
    
    private var deleteButton: some View {
        Button(role: .destructive) { showingDeleteAlert = true } label: {
            HStack { Spacer(); Label("Delete Application", systemImage: "trash"); Spacer() }
        }
        .buttonStyle(.bordered)
        .tint(.red)
    }
}
