import SwiftUI
import SwiftData

struct ApplicationDetailView: View {
    @Bindable var item: ApplicationItem
    @Environment(\.modelContext) private var modelContext
    
    @State private var showingDeleteAlert = false
    @State private var isEditingNotes = false
    @State private var showingConsentSheet = false
    @State private var editingField: EditingField? = nil
    @State private var editCompanyName = ""
    @State private var editPosition = ""
    @State private var editConsentsText = ""
    @FocusState private var isFocused: Bool
    @FocusState private var isConsentsFocused: Bool
    
    enum EditingField {
        case companyName, position
    }

    var body: some View {
        Form {
            // 1. Core Info
            Section("General Info") {
                // Company Name
                if editingField == .companyName {
                    HStack {
                        TextField("Company", text: $editCompanyName)
                            .textFieldStyle(.roundedBorder)
                            .focused($isFocused)
                            .onSubmit {
                                item.companyName = editCompanyName
                                editingField = nil
                            }
                        
                        Button("Save") {
                            item.companyName = editCompanyName
                            editingField = nil
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.small)
                        .keyboardShortcut(.return, modifiers: [])
                        
                        Button("Cancel") {
                            editingField = nil
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                        .keyboardShortcut(.cancelAction)
                    }
                    .onAppear {
                        isFocused = true
                    }
                } else {
                    HStack {
                        Text("Company")
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text(item.companyName.isEmpty ? "Add company name" : item.companyName)
                            .foregroundStyle(item.companyName.isEmpty ? .tertiary : .primary)
                    }
                    .contentShape(Rectangle())
                    .onTapGesture(count: 2) {
                        editCompanyName = item.companyName
                        editingField = .companyName
                    }
                }
                
                // Position
                if editingField == .position {
                    HStack {
                        TextField("Position", text: $editPosition)
                            .textFieldStyle(.roundedBorder)
                            .focused($isFocused)
                            .onSubmit {
                                item.position = editPosition
                                editingField = nil
                            }
                        
                        Button("Save") {
                            item.position = editPosition
                            editingField = nil
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.small)
                        .keyboardShortcut(.return, modifiers: [])
                        
                        Button("Cancel") {
                            editingField = nil
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                        .keyboardShortcut(.cancelAction)
                    }
                    .onAppear {
                        isFocused = true
                    }
                } else {
                    HStack {
                        Text("Position")
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text(item.position.isEmpty ? "Add position" : item.position)
                            .foregroundStyle(item.position.isEmpty ? .tertiary : .primary)
                    }
                    .contentShape(Rectangle())
                    .onTapGesture(count: 2) {
                        editPosition = item.position
                        editingField = .position
                    }
                }
                
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
        Text("Consents")
    }
    
    @ViewBuilder
    private var consentContent: some View {
        if isEditingNotes {
            VStack(alignment: .leading, spacing: 4) {
                ZStack(alignment: .topLeading) {
                    TextEditor(text: $editConsentsText)
                        .frame(minHeight: 200)
                        .font(.body)
                        .focused($isConsentsFocused)
                        .padding(4)
                }
                .background(Color(NSColor.textBackgroundColor))
                .cornerRadius(6)
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(Color.gray.opacity(0.2), lineWidth: 1)
                )
                
                HStack {
                    Button("Save") {
                        item.consentsText = editConsentsText
                        isEditingNotes = false
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
                    
                    Button("Cancel") {
                        isEditingNotes = false
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .keyboardShortcut(.cancelAction)
                }
            }
            .onAppear {
                isConsentsFocused = true
            }
            .onKeyPress(.return, phases: .down) { press in
                if press.modifiers.contains(.command) {
                    item.consentsText = editConsentsText
                    isEditingNotes = false
                    return .handled
                }
                return .ignored
            }
        } else {
            VStack(alignment: .leading, spacing: 12) {
                if item.consentsText.isEmpty {
                    Text("*No notes provided*")
                        .font(.body)
                        .foregroundStyle(.tertiary)
                        .frame(maxWidth: .infinity, minHeight: 180, alignment: .topLeading)
                        .padding(8)
                        .background(Color(NSColor.controlBackgroundColor).opacity(0.5))
                        .cornerRadius(6)
                        .contentShape(Rectangle())
                        .onTapGesture(count: 2) {
                            editConsentsText = item.consentsText
                            isEditingNotes = true
                        }
                } else {
                    VStack(alignment: .leading, spacing: 0) {
                        ClickableTextView(text: item.consentsText)
                            .font(.body)
                            .foregroundStyle(.primary)
                            .padding(8)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .frame(maxWidth: .infinity, minHeight: 180, alignment: .topLeading)
                    .background(Color(NSColor.controlBackgroundColor).opacity(0.5))
                    .cornerRadius(6)
                    .contentShape(Rectangle())
                    .onTapGesture(count: 2) {
                        editConsentsText = item.consentsText
                        isEditingNotes = true
                    }
                }

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
