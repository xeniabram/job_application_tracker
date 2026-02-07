import SwiftUI
import EventKit
import Observation // Required for @Observable

// MARK: - Calendar Manager
@MainActor
@Observable class CalendarManager {
    static let shared = CalendarManager()
    private let eventStore = EKEventStore()
    
    var hasAccess = false
    // Added back to store search results for the PickerSheet
    var events: [EKEvent] = []
    
    let calendarChangedPublisher = NotificationCenter.default.publisher(for: .EKEventStoreChanged)
    
    func requestAccess() async -> Bool {
        do {
            hasAccess = try await eventStore.requestFullAccessToEvents()
            return hasAccess
        } catch {
            hasAccess = false
            return false
        }
    }
    
    // MISSING METHOD RESTORED: Fetches events for a date range
    func fetchEvents(from startDate: Date, to endDate: Date) {
        guard hasAccess else { return }
        
        let calendars = eventStore.calendars(for: .event)
        let predicate = eventStore.predicateForEvents(withStart: startDate, end: endDate, calendars: calendars)
        
        // Update the observable property to refresh the Picker UI
        self.events = eventStore.events(matching: predicate).sorted { $0.startDate < $1.startDate }
    }
    
    func getEventData(identifier: String) -> CalendarEventData? {
        guard let event = eventStore.event(withIdentifier: identifier) else { return nil }
        return CalendarEventData(
            id: event.eventIdentifier,
            title: event.title ?? "Untitled Event",
            startDate: event.startDate,
            endDate: event.endDate,
            location: event.location ?? "",
            meetLink: event.url?.absoluteString,
            calendarNotes: event.notes
        )
    }
    
    func openEventInCalendar(identifier: String) {
        if let url = URL(string: "ical://vcs/eventid=\(identifier)") {
            NSWorkspace.shared.open(url)
        }
    }
    
    func createEvent(title: String, startDate: Date, duration: TimeInterval, location: String, notes: String, url: String?) -> String? {
        guard hasAccess else { return nil }
        let event = EKEvent(eventStore: eventStore)
        event.title = title
        event.startDate = startDate
        event.endDate = startDate.addingTimeInterval(duration)
        event.location = location.isEmpty ? nil : location
        event.notes = notes.isEmpty ? nil : notes
        
        if let urlString = url, !urlString.isEmpty, let eventURL = URL(string: urlString) {
            event.url = eventURL
        }
        
        event.calendar = eventStore.defaultCalendarForNewEvents
        
        do {
            try eventStore.save(event, span: .thisEvent)
            return event.eventIdentifier
        } catch {
            return nil
        }
    }

    // Standard helper for EventKit updates
    func updateEvent(identifier: String, title: String, startDate: Date, duration: TimeInterval, location: String, notes: String, url: String?) -> Bool {
        guard hasAccess, let event = eventStore.event(withIdentifier: identifier) else { return false }
        event.title = title
        event.startDate = startDate
        event.endDate = startDate.addingTimeInterval(duration)
        event.location = location.isEmpty ? nil : location
        event.notes = notes.isEmpty ? nil : notes
        if let urlString = url, let u = URL(string: urlString) { event.url = u }
        
        do {
            try eventStore.save(event, span: .thisEvent)
            return true
        } catch {
            return false
        }
    }
    func deleteEvent(identifier: String) -> Bool {
            guard hasAccess, let event = eventStore.event(withIdentifier: identifier) else { return false }
            
            do {
                // Span .thisEvent ensures we only delete this specific instance
                // rather than an entire recurring series
                try eventStore.remove(event, span: .thisEvent)
                return true
            } catch {
                print("Failed to delete calendar event: \(error.localizedDescription)")
                return false
            }
        }
}

// MARK: - Calendar Event Picker Sheet
struct CalendarEventPickerSheet: View {
    @Environment(\.dismiss) private var dismiss
    
    // Aligned with modern @Observable: No @StateObject wrapper needed
    private var calendarManager = CalendarManager.shared
    
    let application: ApplicationItem
    let onEventSelected: (EKEvent) -> Void
    
    init(application: ApplicationItem, onEventSelected: @escaping (EKEvent) -> Void) {
        self.application = application
        self.onEventSelected = onEventSelected
    }
    
    @State private var startDate = Date()
    @State private var endDate = Date().addingTimeInterval(30 * 24 * 60 * 60) // 30 days
    @State private var isLoading = true
    @State private var accessDenied = false
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                if accessDenied {
                    ContentUnavailableView(
                        "Calendar Access Denied",
                        systemImage: "calendar.badge.exclamationmark",
                        description: Text("Please enable calendar access in System Settings.")
                    )
                } else if isLoading {
                    ProgressView("Requesting Calendar Access...")
                        .padding()
                } else if calendarManager.events.isEmpty {
                    ContentUnavailableView(
                        "No Events Found",
                        systemImage: "calendar",
                        description: Text("No events found in this date range.")
                    )
                } else {
                    List {
                        Section {
                            DatePicker("From", selection: $startDate, displayedComponents: .date)
                            DatePicker("To", selection: $endDate, displayedComponents: .date)
                            
                            Button("Refresh") {
                                calendarManager.fetchEvents(from: startDate, to: endDate)
                            }
                            .buttonStyle(.bordered)
                        } header: {
                            Text("Date Range")
                        }
                        
                        Section {
                            ForEach(calendarManager.events, id: \.eventIdentifier) { event in
                                Button {
                                    onEventSelected(event)
                                    dismiss()
                                } label: {
                                    EventRow(event: event)
                                }
                                .buttonStyle(.plain)
                            }
                        } header: {
                            Text("Select an Event (\(calendarManager.events.count))")
                        }
                    }
                }
            }
            .navigationTitle("Import from Calendar")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            .task {
                // Shared manager handles permission state across the app
                let granted = await calendarManager.requestAccess()
                isLoading = false
                
                if granted {
                    calendarManager.fetchEvents(from: startDate, to: endDate)
                } else {
                    accessDenied = true
                }
            }
            .onChange(of: startDate) { _, _ in
                calendarManager.fetchEvents(from: startDate, to: endDate)
            }
            .onChange(of: endDate) { _, _ in
                calendarManager.fetchEvents(from: startDate, to: endDate)
            }
        }
        .frame(width: 600, height: 500)
    }
}

// MARK: - Event Row
struct EventRow: View {
    let event: EKEvent
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(event.title ?? "Untitled Event")
                .font(.headline)
            
            HStack {
                Label(
                    event.startDate.formatted(date: .abbreviated, time: .shortened),
                    systemImage: "clock"
                )
                .font(.subheadline)
                .foregroundStyle(.secondary)
                
                if let location = event.location, !location.isEmpty {
                    Label(location, systemImage: "mappin")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
            
            if let notes = event.notes, !notes.isEmpty {
                Text(notes)
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .lineLimit(2)
            }
        }
        .padding(.vertical, 4)
    }
}
