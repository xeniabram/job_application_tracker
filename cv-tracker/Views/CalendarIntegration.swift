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
        guard let event = eventStore.event(withIdentifier: identifier) else {
            // Open Calendar app using modern API
            let calendarURL = URL(fileURLWithPath: "/System/Applications/Calendar.app")
            NSWorkspace.shared.openApplication(at: calendarURL, configuration: NSWorkspace.OpenConfiguration())
            return
        }
        
        // Create a temporary .ics file and open it
        // This will open Calendar and show the event
        let tempDirectory = FileManager.default.temporaryDirectory
        let icsURL = tempDirectory.appendingPathComponent("event_\(identifier).ics")
        
        do {
            // Create ICS content manually
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "yyyyMMdd'T'HHmmss"
            dateFormatter.timeZone = TimeZone.current
            
            let startDate = dateFormatter.string(from: event.startDate)
            let endDate = dateFormatter.string(from: event.endDate)
            
            let icsContent = """
            BEGIN:VCALENDAR
            VERSION:2.0
            PRODID:-//CV Tracker//Event//EN
            BEGIN:VEVENT
            UID:\(identifier)
            DTSTAMP:\(startDate)
            DTSTART:\(startDate)
            DTEND:\(endDate)
            SUMMARY:\(event.title ?? "Event")
            END:VEVENT
            END:VCALENDAR
            """
            
            try icsContent.write(to: icsURL, atomically: true, encoding: .utf8)
            
            // Open the ICS file with Calendar
            NSWorkspace.shared.open(icsURL)
            
            // Clean up the temp file after a delay
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                try? FileManager.default.removeItem(at: icsURL)
            }
        } catch {
            print("Failed to create ICS file: \(error)")
            // Fallback to just opening Calendar using modern API
            let calendarURL = URL(fileURLWithPath: "/System/Applications/Calendar.app")
            NSWorkspace.shared.openApplication(at: calendarURL, configuration: NSWorkspace.OpenConfiguration())
        }
    }
    
    func createEvent(title: String, startDate: Date, duration: TimeInterval, location: String, notes: String, url: String?) -> (eventID: String, addedReminderOffsets: [TimeInterval])? {
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
        
        // Add automatic reminders and track which ones were added
        let addedOffsets = addAutomaticReminders(to: event, existingOffsets: [])
        
        do {
            try eventStore.save(event, span: .thisEvent)
            return (event.eventIdentifier, addedOffsets)
        } catch {
            return nil
        }
    }
    
    /// Adds reminders to an existing event in the calendar
    /// - Parameter identifier: The event identifier
    /// - Returns: Array of reminder offsets that were actually added (excludes pre-existing reminders)
    func addRemindersToEvent(identifier: String) -> [TimeInterval] {
        guard hasAccess, let event = eventStore.event(withIdentifier: identifier) else { return [] }
        
        // Get existing reminder offsets before adding new ones
        let existingOffsets = getExistingReminderOffsets(from: event)
        
        // Add automatic reminders and get which ones were added
        let addedOffsets = addAutomaticReminders(to: event, existingOffsets: existingOffsets)
        
        do {
            try eventStore.save(event, span: .thisEvent)
            return addedOffsets
        } catch {
            print("Failed to add reminders: \(error.localizedDescription)")
            return []
        }
    }
    
    /// Removes specific reminders from an event based on their offsets
    /// - Parameters:
    ///   - identifier: The event identifier
    ///   - offsets: Array of reminder offsets to remove
    /// - Returns: True if reminders were removed successfully
    func removeReminders(from identifier: String, offsets: [TimeInterval]) -> Bool {
        guard hasAccess, let event = eventStore.event(withIdentifier: identifier) else { return false }
        guard !offsets.isEmpty else { return true }
        
        // Filter out alarms that match the offsets we want to remove
        if let existingAlarms = event.alarms {
            let remainingAlarms = existingAlarms.filter { alarm in
                guard let offset = alarm.relativeOffset as TimeInterval? else { return true }
                // Keep alarms that don't match any of the offsets to remove
                return !offsets.contains(where: { abs($0 - offset) < 1.0 }) // 1 second tolerance
            }
            event.alarms = remainingAlarms
        }
        
        do {
            try eventStore.save(event, span: .thisEvent)
            return true
        } catch {
            print("Failed to remove reminders: \(error.localizedDescription)")
            return false
        }
    }
    
    /// Gets the existing reminder offsets from an event
    /// - Parameter event: The event to check
    /// - Returns: Array of existing reminder offsets
    private func getExistingReminderOffsets(from event: EKEvent) -> Set<TimeInterval> {
        guard let alarms = event.alarms else { return [] }
        
        var offsets = Set<TimeInterval>()
        for alarm in alarms {
            if let offset = alarm.relativeOffset as TimeInterval? {
                offsets.insert(offset)
            }
        }
        return offsets
    }
    
    /// Adds automatic reminders to an event (3 days, 1 day, 30 minutes before)
    /// - Parameters:
    ///   - event: The event to add reminders to
    ///   - existingOffsets: Set of offsets that already exist on the event
    /// - Returns: Array of offsets that were actually added
    private func addAutomaticReminders(to event: EKEvent, existingOffsets: Set<TimeInterval> = []) -> [TimeInterval] {
        var newAlarms: [EKAlarm] = []
        var addedOffsets: [TimeInterval] = []
        
        // Get existing alarms or create empty array
        var allAlarms = event.alarms ?? []
        
        // 3 days before (only if event is more than 3 days away)
        let threeDaysInSeconds: TimeInterval = -3 * 24 * 60 * 60
        if event.startDate.timeIntervalSinceNow > abs(threeDaysInSeconds) {
            if !existingOffsets.contains(threeDaysInSeconds) {
                newAlarms.append(EKAlarm(relativeOffset: threeDaysInSeconds))
                addedOffsets.append(threeDaysInSeconds)
            }
        }
        
        // 1 day before (only if event is more than 1 day away)
        let oneDayInSeconds: TimeInterval = -24 * 60 * 60
        if event.startDate.timeIntervalSinceNow > abs(oneDayInSeconds) {
            if !existingOffsets.contains(oneDayInSeconds) {
                newAlarms.append(EKAlarm(relativeOffset: oneDayInSeconds))
                addedOffsets.append(oneDayInSeconds)
            }
        }
        
        // 30 minutes before (always add if event is in the future)
        let thirtyMinutesInSeconds: TimeInterval = -30 * 60
        if event.startDate.timeIntervalSinceNow > 0 {
            if !existingOffsets.contains(thirtyMinutesInSeconds) {
                newAlarms.append(EKAlarm(relativeOffset: thirtyMinutesInSeconds))
                addedOffsets.append(thirtyMinutesInSeconds)
            }
        }
        
        // Append new alarms to existing ones (preserving user's reminders)
        allAlarms.append(contentsOf: newAlarms)
        event.alarms = allAlarms
        
        return addedOffsets
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
