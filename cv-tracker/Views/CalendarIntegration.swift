//
//  CalendarIntegration.swift
//  cv-tracker
//
//  Created by Ksenia Pravdina on 07/02/2026.
//

import SwiftUI
import EventKit
import Combine

// MARK: - Calendar Manager
@MainActor
class CalendarManager: ObservableObject {
    private let eventStore = EKEventStore()
    @Published var hasAccess = false
    @Published var events: [EKEvent] = []
    
    func requestAccess() async -> Bool {
        do {
            hasAccess = try await eventStore.requestFullAccessToEvents()
            return hasAccess
        } catch {
            print("Calendar access error: \(error.localizedDescription)")
            hasAccess = false
            return false
        }
    }
    
    func fetchEvents(from startDate: Date, to endDate: Date) {
        guard hasAccess else { return }
        
        let calendars = eventStore.calendars(for: .event)
        let predicate = eventStore.predicateForEvents(withStart: startDate, end: endDate, calendars: calendars)
        
        let fetchedEvents = eventStore.events(matching: predicate)
        
        self.events = fetchedEvents.sorted { $0.startDate < $1.startDate }
    }
    
    func getEvent(withIdentifier identifier: String) -> EKEvent? {
        return eventStore.event(withIdentifier: identifier)
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
        
        // Use the default calendar
        event.calendar = eventStore.defaultCalendarForNewEvents
        
        do {
            try eventStore.save(event, span: .thisEvent)
            return event.eventIdentifier
        } catch {
            print("Failed to create calendar event: \(error.localizedDescription)")
            return nil
        }
    }
    
    func updateEvent(identifier: String, title: String, startDate: Date, duration: TimeInterval, location: String, notes: String, url: String?) -> Bool {
        guard hasAccess, let event = getEvent(withIdentifier: identifier) else { return false }
        
        event.title = title
        event.startDate = startDate
        event.endDate = startDate.addingTimeInterval(duration)
        event.location = location.isEmpty ? nil : location
        event.notes = notes.isEmpty ? nil : notes
        
        if let urlString = url, !urlString.isEmpty, let eventURL = URL(string: urlString) {
            event.url = eventURL
        } else {
            event.url = nil
        }
        
        do {
            try eventStore.save(event, span: .thisEvent)
            return true
        } catch {
            print("Failed to update calendar event: \(error.localizedDescription)")
            return false
        }
    }
    
    func deleteEvent(identifier: String) -> Bool {
        guard hasAccess, let event = getEvent(withIdentifier: identifier) else { return false }
        
        do {
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
    @StateObject private var calendarManager = CalendarManager()
    
    let application: ApplicationItem
    let onEventSelected: (EKEvent) -> Void
    
    @State private var startDate = Date()
    @State private var endDate = Date().addingTimeInterval(30 * 24 * 60 * 60) // 30 days from now
    @State private var isLoading = true
    @State private var accessDenied = false
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                if accessDenied {
                    ContentUnavailableView(
                        "Calendar Access Denied",
                        systemImage: "calendar.badge.exclamationmark",
                        description: Text("Please enable calendar access in System Settings to import events.")
                    )
                } else if isLoading {
                    ProgressView("Requesting Calendar Access...")
                        .padding()
                } else if calendarManager.events.isEmpty {
                    ContentUnavailableView(
                        "No Events Found",
                        systemImage: "calendar",
                        description: Text("No calendar events found in the selected date range.")
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
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
            .task {
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
