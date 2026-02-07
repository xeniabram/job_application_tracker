//
//  TimelineRow.swift
//  cv-tracker
//
//  Created by Ksenia Pravdina on 07/02/2026.
//
import SwiftUI
import SwiftData
import MapKit
import Combine
import EventKit

// MARK: - Timeline Row
struct TimelineRow: View {
    let event: TimelineItem
    let isLast: Bool
    
    init(event: TimelineItem, isLast: Bool) {
        self.event = event
        self.isLast = isLast
    }
    
    @State private var editingField: EditingField? = nil
    @Environment(\.modelContext) private var modelContext
    @FocusState private var isFocused: Bool
    
    // Updated to use the shared manager and observable data
    private var calendarManager = CalendarManager.shared
    @State private var eventData: CalendarEventData?
    @State private var isLoading = true
    
    @State private var editTitle = ""
    @State private var editDate = Date()
    @State private var editLocation = ""
    @State private var editMeetLink = ""
    @State private var editPreparationNotes = ""
    @State private var showingDatePicker = false
    @State private var dateString = ""
    @State private var timeString = ""
    @State private var showingDeleteOptions = false // Controls the dialog visibility
    @State private var isDeleting = false
    
    enum EditingField {
        case title, date, location, meetLink, notes
    }
    
    var body: some View {
        if isDeleting {
            EmptyView() // Prevents the view from rendering broken fallback states
        } else {
            HStack(alignment: .top, spacing: 12) {
                // Timeline indicator
                VStack(spacing: 0) {
                    Circle()
                        .fill((eventData?.startDate ?? .now) > .now ? Color.blue : Color.gray)
                        .frame(width: 10, height: 10)
                    
                    if !isLast {
                        Rectangle()
                            .fill(Color.gray.opacity(0.3))
                            .frame(width: 2)
                    }
                }
                .frame(width: 20)
                
                // Event content
                VStack(alignment: .leading, spacing: 8) {
                    if let data = eventData {
                        renderLiveContent(data)
                    } else if isLoading {
                        ProgressView().controlSize(.small)
                    } else {
                        renderFallbackContent()
                    }
                }
            }
            .padding(.vertical, 12)
            .contextMenu {
                Button("Open in Calendar") {
                    calendarManager.openEventInCalendar(identifier: event.calendarEventID)
                }
                Button("Delete", role: .destructive) {
                    showingDeleteOptions = true // Trigger the confirmation flow
                }        }
            .task {
                await loadData()
            }
            // ADD THIS: Force a re-fetch of eventData when the system notifies of a change
            .onReceive(calendarManager.calendarChangedPublisher) { _ in
                Task {
                    await loadData()
                }
            }
            .confirmationDialog(
                "Are you sure you want to permanently delete this event from both CV Tracker and your calendar?",
                isPresented: $showingDeleteOptions,
                titleVisibility: .visible
            ) {
                // Option 1: Full Delete (Calendar + App)
                Button("Delete Everywhere", role: .destructive) {
                    performDeletion(deleteFromCalendar: true) //
                }
                
                // Option 2: App Only (Unlink)
                Button("Unlink and Delete in App Only") {
                    performDeletion(deleteFromCalendar: false) //
                }
                
                Button("Cancel", role: .cancel) { }
            }
        }
    }
    
    @ViewBuilder
    private func renderLiveContent(_ data: CalendarEventData) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            // Title
            if editingField == .title {
                HStack {
                    TextField("Title", text: $editTitle)
                        .textFieldStyle(.roundedBorder)
                        .font(.body.bold())
                        .focused($isFocused)
                        .onSubmit { saveTitle() }
                    
                    Button("Save") { saveTitle() }.buttonStyle(.borderedProminent).controlSize(.small)
                    Button("Cancel") { editingField = nil }.buttonStyle(.bordered).controlSize(.small)
                }
            } else {
                HStack(spacing: 6) {
                    Text(data.title).font(.title3.bold())
                    Image(systemName: "calendar.badge.checkmark").font(.caption).foregroundStyle(.green)
                }
                .contentShape(Rectangle())
                .onTapGesture(count: 2) {
                    editTitle = data.title
                    editingField = .title
                }
            }
            
            // Date
            Text(data.startDate.formatted(date: .abbreviated, time: .shortened))
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .onTapGesture(count: 2) {
                    editDate = data.startDate
                    dateString = formatDate(data.startDate)
                    timeString = formatTime(data.startDate)
                    showingDatePicker = true
                }
                .popover(isPresented: $showingDatePicker) {
                    DateTimePickerView(date: $editDate, dateString: $dateString, timeString: $timeString, onSave: { saveDate() }, onCancel: { showingDatePicker = false })
                }
            
            // Location
            renderLocationSection(currentLocation: data.location)
            
            // Preparation Notes (Stored in SwiftData)
            renderNotesSection()
        }
    }
    
    @ViewBuilder
    private func renderFallbackContent() -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Event Link Broken").font(.headline).foregroundStyle(.red)
            Text("This event was removed from your system calendar.").font(.caption).foregroundStyle(.secondary)
            Button("Remove Link") { modelContext.delete(event) }.buttonStyle(.bordered).controlSize(.small)
        }
    }
    
    @ViewBuilder
    private func renderLocationSection(currentLocation: String) -> some View {
        if editingField == .location {
            LocationSearchField(location: $editLocation, onSave: { saveLocation() })
        } else {
            Label(currentLocation.isEmpty ? "Add location" : currentLocation, systemImage: "mappin.and.ellipse")
                .font(.subheadline)
                .foregroundStyle(currentLocation.isEmpty ? .tertiary : .secondary)
                .onTapGesture(count: 2) {
                    editLocation = currentLocation
                    editingField = .location
                }
        }
    }
    
    @ViewBuilder
    private func renderNotesSection() -> some View {
        VStack(alignment: .leading, spacing: 4) {
            if editingField == .notes {
                // MARK: - Editing Mode
                VStack(alignment: .leading) {
                    TextEditor(text: $editPreparationNotes)
                        .frame(minHeight: 100)
                        .padding(4)
                        .background(Color(nsColor: .textBackgroundColor))
                        .cornerRadius(4)
                        .focused($isFocused)
                    
                    HStack {
                        Button("Save") { saveNotes() }
                            .buttonStyle(.borderedProminent)
                            .controlSize(.small)
                        Button("Cancel") { editingField = nil }
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                    }
                }
                .frame(maxWidth: 500) // Limits editor width for readability
            } else {
                // MARK: - Read-Only Mode
                VStack(alignment: .leading) {
                    if event.preparationNotes.isEmpty {
                        Text("Double-click to add preparation notes...")
                            .italic()
                            .font(.subheadline)
                            .foregroundStyle(.tertiary)
                    } else {
                        ClickableTextView(text: event.preparationNotes)
                            .font(.subheadline)
                    }
                }
                .padding(12) // Inner padding for better text breathing room
                .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                .background(Color(nsColor: .controlBackgroundColor).opacity(0.3))
                .cornerRadius(8)
                .contentShape(Rectangle()) // Ensures the entire area is double-clickable
                .onTapGesture(count: 2) {
                    editPreparationNotes = event.preparationNotes
                    editingField = .notes
                }
                // Use GeometryReader only for the width calculation to avoid "sticking"
                .overlay(
                    GeometryReader { geo in
                        Color.clear.onAppear {
                            // This identifies the parent width if needed,
                            // but usually a fixed ratio is better:
                        }
                    }
                )
                // Fixes your specific request: 70% width and bottom spacing
                .frame(maxWidth: NSScreen.main?.visibleFrame.width ?? 800 * 0.7, alignment: .leading)
            }
        }
        .padding(.top, 6)    // Adds space between the location and notes
        .padding(.bottom, 8) // Adds space at the bottom of the row
    }
    
    private func loadData() async {
            _ = await calendarManager.requestAccess()
        let data = calendarManager.getEventData(identifier: event.calendarEventID)
            // Update state on the main thread
            await MainActor.run {
                self.eventData = data
                self.isLoading = false
            }
        }

    private func saveTitle() {
            if let data = eventData {
                // Push update to system calendar
                _ = calendarManager.updateEvent(
                    identifier: event.calendarEventID,
                    title: editTitle,
                    startDate: data.startDate,
                    duration: data.duration,
                    location: data.location,
                    notes: event.preparationNotes,
                    url: data.meetLink
                )
            }
            editingField = nil
        }

        private func saveDate() {
            if let data = eventData {
                // Update the system calendar
                _ = calendarManager.updateEvent(
                    identifier: event.calendarEventID,
                    title: data.title,
                    startDate: editDate,
                    duration: data.duration,
                    location: data.location,
                    notes: event.preparationNotes,
                    url: data.meetLink
                )
                // Trigger a local refresh
                Task { await loadData() }
            }
            showingDatePicker = false
        }

        private func saveLocation() {
            if let data = eventData {
                _ = calendarManager.updateEvent(
                    identifier: event.calendarEventID,
                    title: data.title,
                    startDate: data.startDate,
                    duration: data.duration,
                    location: editLocation,
                    notes: event.preparationNotes,
                    url: data.meetLink
                )
            }
            editingField = nil
        }

    private func saveNotes() {
        event.preparationNotes = editPreparationNotes
        editingField = nil
    }

    private func performDeletion(deleteFromCalendar: Bool) {
        // 1. Start the UI disappearance first to avoid the "red text" glitch
        withAnimation {
            isDeleting = true
        }
        
        // 2. Conditionally delete from the system calendar
        if deleteFromCalendar {
            _ = calendarManager.deleteEvent(identifier: event.calendarEventID)
        }
        
        // 3. Always remove from the App database
        modelContext.delete(event)
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter(); formatter.dateFormat = "MM/dd/yyyy"; return formatter.string(from: date)
    }
    
    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter(); formatter.dateFormat = "HH:mm"; return formatter.string(from: date)
    }
}
