//
//  AddEventSheet.swift
//  cv-tracker
//
//  Created by Ksenia Pravdina on 07/02/2026.
//

import SwiftUI
import SwiftData
import EventKit

// MARK: - Add Event Sheet

/// A modal sheet for creating new interview/meeting events and linking them to a job application.
///
/// This view provides two ways to create events:
/// 1. **Import from Calendar**: Link an existing calendar event to the application
/// 2. **Create New**: Manually enter event details, which creates both a calendar event and a timeline item
///
/// The view automatically syncs with the system calendar using EventKit and stores
/// app-specific preparation notes using SwiftData.
///
/// - Note: Calendar access must be granted for this view to function properly.
struct AddEventSheet: View {
    
    // MARK: - Environment
    
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    
    // MARK: - Properties
    
    /// The job application to which the new event will be linked
    let application: ApplicationItem
    
    // MARK: - State
    
    /// The event title (e.g., "Phone Screen with HR")
    @State private var title = ""
    
    /// The start date and time for the event
    @State private var date = Date()
    
    /// The end date and time for the event (default: 1 hour after start)
    @State private var endDate = Date().addingTimeInterval(3600)
    
    /// Physical location of the event (optional)
    @State private var location = ""
    
    /// Virtual meeting link (e.g., Zoom, Teams URL)
    @State private var meetLink = ""
    
    /// Internal preparation notes stored only in the app (not synced to calendar)
    @State private var preparationNotes = ""
    
    /// Controls whether the calendar event picker sheet is presented
    @State private var showingCalendarPicker = false
    
    /// Controls the success toast visibility after saving
    @State private var showToast = false
    
    // MARK: - Focus State
    
    @FocusState private var focusedField: Bool
    
    // MARK: - Dependencies
    
    private let calendarManager = CalendarManager.shared
    
    // MARK: - Initialization
    
    /// Creates a new event sheet for a specific job application
    /// - Parameter application: The job application to link the event to
    init(application: ApplicationItem) {
        self.application = application
    }
    
    // MARK: - Body
    
    var body: some View {
        ZStack(alignment: .topTrailing) {
            NavigationStack {
                Form {
                    importSection
                    eventDetailsSection
                    logisticsSection
                    preparationNotesSection
                }
                .formStyle(.grouped)
                .navigationTitle("Add Event")
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        cancelButton
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        saveButton
                    }
                }
            }
            
            if showToast {
                successToast
            }
        }
        .frame(width: 500, height: 600)
        .sheet(isPresented: $showingCalendarPicker) {
            CalendarEventPickerSheet(application: application) { event in
                importEvent(event)
            }
        }
    }
    
    // MARK: - View Components
    
    /// Section for importing existing calendar events
    private var importSection: some View {
        Section("Import") {
            Button {
                showingCalendarPicker = true
            } label: {
                Label("Import from Calendar", systemImage: "calendar.badge.plus")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
        }
    }
    
    /// Section for basic event details (title, date, end time)
    private var eventDetailsSection: some View {
        Section("Event Details") {
            TextField("Title", text: $title)
                .focused($focusedField)
            
            DatePicker("Start", selection: $date)
                .onChange(of: date) { oldValue, newValue in
                    // If start date changes, adjust end date to maintain the same duration
                    let duration = endDate.timeIntervalSince(oldValue)
                    endDate = newValue.addingTimeInterval(duration)
                }
            
            DatePicker("End", selection: $endDate)
            
            // Show calculated duration as helper text
            Text("Duration: \(formattedDuration)")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
    
    /// Section for event logistics (location, meeting link)
    private var logisticsSection: some View {
        Section("Logistics") {
            LocationSearchField(location: $location, autoFocus: false)
            TextField("Meeting Link", text: $meetLink)
        }
    }
    
    /// Section for internal preparation notes
    private var preparationNotesSection: some View {
        Section {
            TextEditor(text: $preparationNotes)
                .frame(height: 80)
        } header: {
            Text("Internal Prep Notes")
        } footer: {
            Text("These notes are only visible in the app, not in your calendar.")
                .font(.caption)
        }
    }
    
    /// Cancel button in the toolbar
    private var cancelButton: some View {
        Button("Cancel") {
            dismiss()
        }
    }
    
    /// Save button in the toolbar (disabled when title is empty)
    private var saveButton: some View {
        Button("Save") {
            Task { await saveEvent() }
        }
        .disabled(title.isEmpty)
    }
    
    /// Success toast notification
    private var successToast: some View {
        ToastView(message: "Event Synced with Reminders!", icon: "checkmark.circle.fill")
            .padding()
            .transition(.move(edge: .top).combined(with: .opacity))
    }
    
    // MARK: - Private Methods
    
    /// Saves a new event to both the system calendar and the app's SwiftData store
    ///
    /// This method performs the following steps:
    /// 1. Creates a calendar event using EventKit
    /// 2. Creates a timeline item in SwiftData linked to the calendar event
    /// 3. Associates the timeline item with the current application
    /// 4. Tracks which reminders were added by the app (for later removal)
    /// 5. Shows a success toast and dismisses the sheet
    ///
    /// - Note: If calendar access is denied or the event creation fails, the method returns early
    private func saveEvent() async {
        // Calculate duration from start and end dates
        let duration = endDate.timeIntervalSince(date)
        
        // Validate that end date is after start date
        guard duration > 0 else {
            // TODO: Show error alert when end date is before start date
            return
        }
        
        // Create the system calendar event first
        guard let result = calendarManager.createEvent(
            title: title,
            startDate: date,
            duration: duration,
            location: location,
            notes: formatNotesForCalendar(),
            url: meetLink
        ) else {
            // TODO: Show error alert when calendar access is denied or creation fails
            return
        }
        
        // Create the SwiftData timeline item linked to the calendar event
        let newItem = TimelineItem(
            calendarEventID: result.eventID,
            preparationNotes: preparationNotes
        )
        // Store which reminders were added by the app
        newItem.appAddedReminderOffsets = result.addedReminderOffsets
        newItem.application = application
        modelContext.insert(newItem)
        
        // Show success feedback
        await showSuccessAndDismiss()
    }
    
    /// Imports an existing calendar event and links it to the current application
    ///
    /// This method creates a timeline item that references an existing calendar event
    /// without modifying the original event. It also adds automatic reminders and tracks
    /// which reminders were added by the app (excluding pre-existing user reminders).
    ///
    /// - Parameter event: The EventKit event to import
    private func importEvent(_ event: EKEvent) {
        // Add reminders to the imported event and get which ones were actually added
        let addedOffsets = calendarManager.addRemindersToEvent(identifier: event.eventIdentifier)
        
        // Create timeline item
        let newItem = TimelineItem(
            calendarEventID: event.eventIdentifier,
            preparationNotes: event.notes ?? ""
        )
        // Store which reminders were added by the app for later removal if unlinked
        newItem.appAddedReminderOffsets = addedOffsets
        newItem.application = application
        modelContext.insert(newItem)
        
        // Show success feedback before dismissing
        Task {
            await showSuccessAndDismiss()
        }
    }
    
    /// Formats the preparation notes for inclusion in the calendar event
    ///
    /// This adds a prefix to distinguish app-specific notes from other calendar notes
    ///
    /// - Returns: Formatted notes string for the calendar event
    private func formatNotesForCalendar() -> String {
        guard !preparationNotes.isEmpty else { return "" }
        return "Job Tracker Prep: \(preparationNotes)"
    }
    
    /// Shows the success toast and dismisses the sheet after a brief delay
    private func showSuccessAndDismiss() async {
        withAnimation {
            showToast = true
        }
        
        try? await Task.sleep(for: .seconds(1))
        dismiss()
    }
    
    // MARK: - Helper Properties
    
    /// Computed duration formatted as a human-readable string
    private var formattedDuration: String {
        let duration = endDate.timeIntervalSince(date)
        
        // Handle negative duration
        guard duration > 0 else {
            return "Invalid (end before start)"
        }
        
        let hours = Int(duration) / 3600
        let minutes = (Int(duration) % 3600) / 60
        
        if hours > 0 && minutes > 0 {
            return "\(hours)h \(minutes)m"
        } else if hours > 0 {
            return "\(hours)h"
        } else if minutes > 0 {
            return "\(minutes)m"
        } else {
            return "Less than 1 minute"
        }
    }
}
// MARK: - Preview

#Preview("Add Event Sheet") {
    @Previewable @State var showSheet = true
    
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: ApplicationItem.self, configurations: config)
    
    let application = ApplicationItem(
        companyName: "Apple",
        position: "Software Engineer"
    )
    container.mainContext.insert(application)
    
    return Text("Preview Content")
        .sheet(isPresented: $showSheet) {
            AddEventSheet(application: application)
                .modelContainer(container)
        }
}

