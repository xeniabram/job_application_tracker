import SwiftUI
import SwiftData
import MapKit
import Combine
import EventKit

// MARK: - Timeline Section
struct TimelineSection: View {
    var application: ApplicationItem
    @State private var showingAddEvent = false
    @State private var showPastEvents = false
    @State private var filteredEvents: [TimelineItem] = [] // The list actually shown
    @State private var allSortedEvents: [TimelineItem] = [] // Cached sorted list
    @State private var isLoading = true // Prevents "No events" flash
    
    @Environment(\.modelContext) private var modelContext
    
    var body: some View {
        Section {
            if isLoading {
                ProgressView()
                    .frame(maxWidth: .infinity)
                    .padding()
            } else if !filteredEvents.isEmpty {
                // Events remain naturally left-aligned here
                ForEach(filteredEvents) { event in
                    TimelineRow(event: event, isLast: event == filteredEvents.last)
                }
            } else {
                // ONLY the empty state is centered
                HStack {
                    Spacer()
                    emptyStateView
                    Spacer()
                }
                .padding(.vertical, 20)
            }
        } header: {
            timelineHeader
        }
        .sheet(isPresented: $showingAddEvent) {
            AddEventSheet(application: application)
        }
        // Re-run filter whenever the toggle or the timeline changes
        .task(id: showPastEvents) { await updateDisplay() }
        .task(id: application.timeline) { await updateDisplay() }
        .onReceive(CalendarManager.shared.calendarChangedPublisher) { _ in
            Task { await updateDisplay() }
        }
    }

    @MainActor
    private func updateDisplay() async {
        guard let timeline = application.timeline else {
            isLoading = false
            return
        }
        
        // 1. Sort everything first
        let sorted = timeline.sorted { itemA, itemB in
            let dateA = CalendarManager.shared.getEventData(identifier: itemA.calendarEventID)?.startDate ?? .distantPast
            let dateB = CalendarManager.shared.getEventData(identifier: itemB.calendarEventID)?.startDate ?? .distantPast
            return dateA < dateB
        }
        
        // 2. Apply the filter based on the toggle
        let now = Date()
        let filtered = sorted.filter { item in
            if showPastEvents { return true }
            let eventDate = CalendarManager.shared.getEventData(identifier: item.calendarEventID)?.startDate ?? .distantPast
            return eventDate >= now // Only show future events
        }
        
        withAnimation(.spring()) {
            self.filteredEvents = filtered
            self.isLoading = false
        }
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 12) {
            // Condition 1: The database is actually empty
            if allSortedEvents.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "calendar.badge.plus")
                        .font(.system(size: 32))
                        .foregroundStyle(.secondary)
                    Text("No Events Linked")
                        .font(.headline)
                    Text("Add an event to start tracking your timeline.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
            // Condition 2: Events exist, but they are all in the past
            else {
                VStack(spacing: 8) {
                    Image(systemName: "calendar.badge.clock")
                        .font(.system(size: 32))
                        .foregroundStyle(.secondary)
                    Text("No Upcoming Events")
                        .font(.headline)
                    Text("You have past events. Toggle 'Show Past' to see them.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    
                    Button("Show Past Events") {
                        withAnimation { showPastEvents = true }
                    }
                    .buttonStyle(.link)
                    .font(.subheadline)
                }
            }
        }
        .multilineTextAlignment(.center)
        .padding(.vertical, 30)
    }
    
    private var timelineHeader: some View {
        HStack {
            Label("Timeline", systemImage: "timer")
            Spacer()
            Toggle("Show Past", isOn: $showPastEvents)
                .toggleStyle(.checkbox)
                .font(.caption)
            Button { showingAddEvent = true } label: {
                Image(systemName: "plus.circle.fill").imageScale(.large)
            }.buttonStyle(.plain)
        }
    }
}
// MARK: - Clickable Text View
struct ClickableTextView: View {
    let text: String
    var body: some View {
        Text(LocalizedStringKey(text)).textSelection(.enabled)
    }
}

