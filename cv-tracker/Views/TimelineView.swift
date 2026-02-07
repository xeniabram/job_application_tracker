import SwiftUI
import SwiftData
import MapKit

// MARK: - Timeline Section
struct TimelineSection: View {
    var application: ApplicationItem
    @State private var showingAddEvent = false

    var body: some View {
        Section(header: timelineHeader) {
            if let events = application.timeline?.sorted(by: { $0.date < $1.date }), !events.isEmpty {
                ForEach(events) { event in
                    TimelineRow(event: event, isLast: event == events.last)
                }
            } else {
                Text("No events scheduled yet").foregroundStyle(.secondary)
                    .padding(.leading, 20)
            }
        }
        .sheet(isPresented: $showingAddEvent) {
            AddEventSheet(application: application)
        }
    }

    private var timelineHeader: some View {
        HStack {
            Label("Timeline", systemImage: "clock.fill")
            Spacer()
            Button(action: { showingAddEvent = true }) {
                Image(systemName: "plus.circle.fill")
                    .imageScale(.large)
                    .foregroundStyle(.blue)
            }
            .buttonStyle(.plain)
        }
    }
}

// MARK: - Timeline Row
struct TimelineRow: View {
    let event: TimelineItem
    let isLast: Bool

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            // Vertical Line Logic
            VStack(spacing: 0) {
                Circle()
                    .fill(event.date > Date() ? .blue : .gray)
                    .frame(width: 10, height: 10)
                
                if !isLast {
                    Rectangle()
                        .fill(.gray.opacity(0.3))
                        .frame(width: 2)
                        .padding(.vertical, 2)
                }
            }
            .frame(width: 20)

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(event.title).bold()
                    Spacer()
                    Text(event.date.formatted(date: .abbreviated, time: .shortened))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                
                if !event.location.isEmpty {
                    Label(event.location, systemImage: "mappin.and.ellipse")
                        .font(.caption)
                        .foregroundStyle(.blue)
                }

                if !event.preparationNotes.isEmpty {
                    Text(event.preparationNotes)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .padding(8)
                        .background(Color.gray.opacity(0.05))
                        .cornerRadius(6)
                }
            }
            .padding(.bottom, isLast ? 0 : 12)
        }
    }
}

// MARK: - Add Event Sheet
struct AddEventSheet: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) var dismiss
    
    var application: ApplicationItem
    
    @State private var title = ""
    @State private var date = Date()
    @State private var location = ""
    @State private var meetLink = ""
    @State private var preparationNotes = ""

    var body: some View {
        NavigationStack {
            Form {
                Section("Event Details") {
                    TextField("Title (e.g., Technical Interview)", text: $title)
                    DatePicker("Date & Time", selection: $date)
                }
                
                Section("Logistics") {
                    // Custom Searchable Address Field
                    AddressSearchField(address: $location)
                    
                    TextField("Meeting Link", text: $meetLink)
                        .textFieldStyle(.roundedBorder)
                }
                
                Section("Preparation Intelligence") {
                    TextEditor(text: $preparationNotes)
                        .frame(minHeight: 120)
                        .font(.system(.body, design: .monospaced))
                }
            }
            .formStyle(.grouped) // Restores the high-quality macOS look
            .navigationTitle("Add Timeline Event")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { saveEvent() }
                        .buttonStyle(.borderedProminent)
                        .disabled(title.isEmpty)
                }
            }
        }
        .frame(width: 500, height: 600)
    }
    
    private func saveEvent() {
        let newEvent = TimelineItem(
            title: title,
            date: date,
            location: location,
            meetLink: meetLink,
            preparationNotes: preparationNotes
        )
        newEvent.application = application
        modelContext.insert(newEvent)
        dismiss()
    }
}

// MARK: - Address Search Helper
struct AddressSearchField: View {
    @Binding var address: String
    @State private var searchText = ""
    @State private var results: [MKMapItem] = []
    
    var body: some View {
        VStack {
            HStack {
                Image(systemName: "magnifyingglass")
                TextField("Search Location...", text: $address)
                    .onSubmit { searchAddress() }
            }
            
            if !results.isEmpty {
                ScrollView {
                    ForEach(results, id: \.self) { item in
                        Button {
                            address = item.placemark.title ?? ""
                            results = []
                        } label: {
                            VStack(alignment: .leading) {
                                Text(item.name ?? "Unknown").bold()
                                Text(item.placemark.title ?? "").font(.caption).foregroundStyle(.secondary)
                            }
                            .padding(.vertical, 4)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .buttonStyle(.plain)
                        Divider()
                    }
                }
                .frame(maxHeight: 120)
            }
        }
    }

    private func searchAddress() {
        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = address
        let search = MKLocalSearch(request: request)
        search.start { response, _ in
            self.results = response?.mapItems ?? []
        }
    }
}
