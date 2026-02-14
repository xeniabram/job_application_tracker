import SwiftUI
import SwiftData

struct ContentView: View {
    @Query private var applications: [ApplicationItem]
    @Environment(\.modelContext) private var modelContext
    
    @State private var selectedItem: ApplicationItem?
    @State private var searchText = ""
    @State private var columnVisibility: NavigationSplitViewVisibility = .all
    
    // Filtering and Sorting State
    @State private var selectedStatus: ApplicationStatus? = nil
    @State private var sortOrder = SortDescriptor(\ApplicationItem.dateApplied, order: .reverse)
    @State private var showArchived = false // Toggle for showing archived items
    
    @State private var itemToDelete: ApplicationItem?
    @State private var showingDeleteConfirmation = false
    @State private var showingAddDialog = false
    @State private var newCompanyName = ""
    @State private var newPosition = ""
    @State private var newDate = Date()

    // Auto-archive applications after 30 days
    private func autoArchiveOldApplications() {
        let thirtyDaysAgo = Calendar.current.date(byAdding: .day, value: -30, to: Date()) ?? Date()
        
        for application in applications {
            // Only auto-archive if status is still "applied" and it's been 30+ days
            if application.status == .applied && application.dateApplied < thirtyDaysAgo {
                application.status = .archived
            }
        }
    }
    
    // Statistics computed properties
    private var totalApplications: Int {
        applications.count
    }
    
    private var statusCounts: [ApplicationStatus: Int] {
        var counts: [ApplicationStatus: Int] = [:]
        for status in ApplicationStatus.allCases {
            counts[status] = applications.filter { $0.status == status }.count
        }
        return counts
    }

    // Updated Computed Property for Search, Filter, Sort, and Archive visibility
    var filteredApplications: [ApplicationItem] {
        let result = applications.filter { item in
            // 1. Search Filter
            let matchesSearch = searchText.isEmpty ||
                                item.companyName.localizedCaseInsensitiveContains(searchText) ||
                                item.position.localizedCaseInsensitiveContains(searchText)
            
            // 2. Specific Status Picker
            let matchesStatus = selectedStatus == nil || item.status == selectedStatus
            
            // 3. Combined Archive & Rejected Filter
            // If showArchived is true, we show everything.
            // If false, we hide both .archived and .rejected.
            let matchesVisibility = showArchived || (item.status != .archived && item.status != .rejected)
            
            return matchesSearch && matchesStatus && matchesVisibility
        }
        
        return result.sorted(using: sortOrder)
    }

    var body: some View {
        NavigationSplitView(columnVisibility: $columnVisibility) {
            VStack(spacing: 0) {
                // Info bar with statistics
                if totalApplications > 0 {
                    infoBar
                }
                
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
                    ToolbarItemGroup {
                        // Only show these items when sidebar is visible
                        if columnVisibility == .all {
                            // Archive toggle
                            Toggle(isOn: $showArchived) {
                                Label("Show Archived", systemImage: showArchived ? "archivebox.fill" : "archivebox")
                            }
                            .help("Show/hide archived applications")
                            
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
                }
                .confirmationDialog("Delete Application?", isPresented: $showingDeleteConfirmation, titleVisibility: .visible) {
                    Button("Delete \(itemToDelete?.companyName ?? "")", role: .destructive) {
                        if let item = itemToDelete { deleteItem(item) }
                    }
                    Button("Cancel", role: .cancel) { itemToDelete = nil }
                }
            }
            .navigationSplitViewColumnWidth(345)
        } detail: {
            if let item = selectedItem {
                ApplicationDetailView(item: item)
            } else {
                ContentUnavailableView("Select an Application", systemImage: "briefcase")
            }
        }
        .frame(minWidth: 900, minHeight: 600)
        .navigationSplitViewStyle(.balanced)
        .sheet(isPresented: $showingAddDialog) {
            addDialogContent
        }
        .onAppear {
            autoArchiveOldApplications()
        }
        .onChange(of: applications.count) { _, _ in
            autoArchiveOldApplications()
        }
    }

    // Logic helpers
    private func deleteItem(_ item: ApplicationItem) {
        if selectedItem?.id == item.id { selectedItem = nil }
        modelContext.delete(item)
        itemToDelete = nil
    }
    
    // Info bar with statistics
    private var infoBar: some View {
        GeometryReader { geometry in
            
            VStack(spacing: 0) {
                HStack(spacing: 0) {
                    // Left padding
                    Spacer().frame(width: 12)
                    
                    // Total applications
                    HStack(spacing: 4) {
                        Image(systemName: "briefcase.fill")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            Text("\(totalApplications)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                    }
                    
                    // Fixed spacing before divider
                    Spacer().frame(width: 12)
                    
                    Divider()
                        .frame(height: 12)
                    
                    // Fixed spacing after divider
                    Spacer().frame(width: 12)
                    
                    // Status breakdown - collect visible statuses
                    let visibleStatuses = ApplicationStatus.allCases.filter { statusCounts[$0] ?? 0 > 0 }
                    
                    ForEach(Array(visibleStatuses.enumerated()), id: \.element) { index, status in
                      
                        // Full badge with status name
                        HStack(spacing: 4) {
                            Text("\(status.rawValue) \(statusCounts[status] ?? 0)")
                                .font(.caption)
                                .foregroundStyle(.primary)
                        }
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(pastelColorForStatus(status))
                        .cornerRadius(4)
                        
                        
                        // Add flexible spacer between status items (but not after the last one)
                        if index < visibleStatuses.count - 1 {
                            Spacer()
                        }
                    }
                    
                    // Right padding
                    Spacer().frame(width: 12)
                }
                .padding(.vertical, 8)
                
                Divider()
            }
        }
        .frame(height: 32)
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
    
    func pastelColorForStatus(_ status: ApplicationStatus) -> Color {
        switch status {
        case .applied: return Color.blue.opacity(0.2)
        case .interviewing: return Color.orange.opacity(0.2)
        case .offer: return Color.green.opacity(0.2)
        case .rejected: return Color.red.opacity(0.2)
        case .archived: return Color.gray.opacity(0.2)
        }
    }
}
