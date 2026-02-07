import SwiftUI
import SwiftData

struct ContentView: View {
    @Query private var applications: [ApplicationItem]
    @Environment(\.modelContext) private var modelContext
    
    @State private var selectedItem: ApplicationItem?
    @State private var searchText = ""
    
    // Filtering and Sorting State
    @State private var selectedStatus: ApplicationStatus? = nil
    @State private var sortOrder = SortDescriptor(\ApplicationItem.dateApplied, order: .reverse)
    
    @State private var itemToDelete: ApplicationItem?
    @State private var showingDeleteConfirmation = false
    @State private var showingAddDialog = false
    @State private var newCompanyName = ""
    @State private var newPosition = ""
    @State private var newDate = Date()

    // 1. Updated Computed Property for Search, Filter, and Sort
    var filteredApplications: [ApplicationItem] {
        let result = applications.filter { item in
            let matchesSearch = searchText.isEmpty ||
                                item.companyName.localizedCaseInsensitiveContains(searchText) ||
                                item.position.localizedCaseInsensitiveContains(searchText)
            
            let matchesStatus = selectedStatus == nil || item.status == selectedStatus
            
            return matchesSearch && matchesStatus
        }
        
        // Apply manual sorting since @Query is static
        return result.sorted(using: sortOrder)
    }

    var body: some View {
        NavigationSplitView {
            List(filteredApplications, selection: $selectedItem) { item in
                NavigationLink(value: item) {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Circle()
                                .fill(colorForStatus(item.status))
                                .frame(width: 8, height: 8)
                            Text(item.companyName).font(.headline)
                            Spacer()
                            Button(role: .destructive) {
                                itemToDelete = item
                                showingDeleteConfirmation = true
                            } label: {
                                Image(systemName: "trash").foregroundStyle(.secondary)
                            }
                            .buttonStyle(.plain)
                        }
                        
                        Text(item.position).font(.subheadline).foregroundStyle(.secondary)
                        
                        HStack {
                            Picker("", selection: Bindable(item).status) {
                                ForEach(ApplicationStatus.allCases, id: \.self) { status in
                                    Text(status.rawValue).tag(status as ApplicationStatus?)
                                }
                            }
                            .labelsHidden()
                            .controlSize(.small)
                            .frame(width: 100)
                            
                            Spacer()
                            
                            if let _ = item.cvUrl {
                                Button {
                                    FileUtils.openFile(url: item.cvUrl, bookmark: item.cvBookmark)
                                } label: {
                                    Image(systemName: "doc.text.fill")
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
            .navigationTitle("Job Tracker")
            .listStyle(.sidebar)
            .searchable(text: $searchText, placement: .sidebar, prompt: "Search...")
            .toolbar {
                // 2. Add Filter and Sort Menus to Toolbar
                ToolbarItemGroup {
                    // Filter Menu
                    Menu {
                        Button("All Statuses") { selectedStatus = nil }
                        Divider()
                        ForEach(ApplicationStatus.allCases, id: \.self) { status in
                            Button(status.rawValue) { selectedStatus = status }
                        }
                    } label: {
                        Label("Filter", systemImage: selectedStatus == nil ? "line.3.horizontal.decrease.circle" : "line.3.horizontal.decrease.circle.fill")
                    }
                    
                    // Sort Menu
                    Menu {
                        Button("Newest First") {
                            sortOrder = SortDescriptor(\ApplicationItem.dateApplied, order: .reverse)
                        }
                        Button("Oldest First") {
                            sortOrder = SortDescriptor(\ApplicationItem.dateApplied, order: .forward)
                        }
                        Button("Company (A-Z)") {
                            sortOrder = SortDescriptor(\ApplicationItem.companyName, order: .forward)
                        }
                    } label: {
                        Label("Sort", systemImage: "arrow.up.arrow.down")
                    }
                    
                    Button(action: { showingAddDialog = true }) {
                        Label("Add", systemImage: "plus")
                    }
                }
            }
            .confirmationDialog("Delete Application?", isPresented: $showingDeleteConfirmation, titleVisibility: .visible) {
                Button("Delete \(itemToDelete?.companyName ?? "")", role: .destructive) {
                    if let item = itemToDelete { deleteItem(item) }
                }
                Button("Cancel", role: .cancel) { itemToDelete = nil }
            }
        } detail: {
            if let item = selectedItem {
                ApplicationDetailView(item: item)
            } else {
                ContentUnavailableView("Select an Application", systemImage: "briefcase")
            }
        }
        .frame(minWidth: 900, minHeight: 600)
        .sheet(isPresented: $showingAddDialog) {
            addDialogContent
        }
    }

    // Logic helpers
    private func deleteItem(_ item: ApplicationItem) {
        if selectedItem?.id == item.id { selectedItem = nil }
        modelContext.delete(item)
        itemToDelete = nil
    }
    
    var addDialogContent: some View {
        VStack(spacing: 15) {
            Text("New Job Application").font(.headline)
            Form {
                TextField("Company Name", text: $newCompanyName)
                TextField("Position", text: $newPosition)
                DatePicker("Date Applied", selection: $newDate, displayedComponents: .date)
            }
            .formStyle(.grouped)
            HStack {
                Button("Cancel") { resetAndClose() }
                Spacer()
                Button("Save") { saveNewApplication() }.buttonStyle(.borderedProminent)
            }
        }
        .padding().frame(width: 400, height: 300)
    }

    func saveNewApplication() {
        let newItem = ApplicationItem(companyName: newCompanyName, position: newPosition, date: newDate)
        modelContext.insert(newItem)
        resetAndClose()
    }
    
    func resetAndClose() {
        newCompanyName = ""; newPosition = ""; newDate = Date(); showingAddDialog = false
    }

    func colorForStatus(_ status: ApplicationStatus?) -> Color {
        switch status {
        case .applied, .none: return .blue
        case .interviewing: return .orange
        case .offer: return .green
        case .rejected: return .red
        case .archived: return .gray
        }
    }
}
