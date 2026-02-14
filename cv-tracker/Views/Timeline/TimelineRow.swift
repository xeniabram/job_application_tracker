//
//  TimelineRow.swift
//  cv-tracker
//
//  Created by Ksenia Pravdina on 07/02/2026.
//

import SwiftUI
import SwiftData
import EventKit
import MapKit

// MARK: - Timeline Row

/// A row displaying a single interview/meeting event in the application timeline.
///
/// This view provides:
/// - Real-time synchronization with system calendar events via EventKit
/// - Inline editing of event details (title, date, location, notes)
/// - Visual timeline indicator showing past/future events
/// - Deletion options (remove from calendar or unlink only)
///
/// ## Editing Behavior
/// All fields enter edit mode via double-click. Each field has specific editing behavior:
///
/// - **Title**: Auto-focus text field, Enter to save, Esc to cancel
/// - **Date**: Focus on date field, arrow keys navigate date/time/calendar, Enter on time field saves
/// - **Location**: Auto-focus with MapKit suggestions, arrow keys navigate, Enter to save
/// - **Notes**: Focus at end of text, Cmd+Enter to save, Esc to cancel
///
/// Editing any field while another is being edited will cancel the first edit without saving.
struct TimelineRow: View {
    
    // MARK: - Properties
    
    /// The timeline item representing the event
    let event: TimelineItem
    
    /// Whether this is the last item in the timeline (affects visual connector)
    let isLast: Bool
    
    // MARK: - Environment
    
    @Environment(\.modelContext) private var modelContext
    
    // MARK: - State - Data Loading
    
    /// Live event data fetched from the system calendar
    @State private var eventData: CalendarEventData?
    
    /// Whether the initial data is still loading
    @State private var isLoading = true
    
    /// Whether the item is being deleted (prevents rendering during deletion)
    @State private var isDeleting = false
    
    // MARK: - State - Editing
    
    /// The field currently being edited, if any
    @State private var editingField: EditingField? = nil {
        didSet {
            // When a new field starts editing, ensure focus is set appropriately
            if editingField != oldValue {
                setInitialFocus()
            }
        }
    }
    
    /// Temporary storage for title being edited
    @State private var editTitle = ""
    
    /// Temporary storage for date being edited
    @State private var editDate = Date()
    
    /// Temporary storage for location being edited
    @State private var editLocation = ""
    
    /// Temporary storage for preparation notes being edited
    @State private var editPreparationNotes = ""
    
    /// Controls visibility of the date picker popover
    @State private var showingDatePicker = false
    
    /// String representation of date for text field editing
    @State private var dateString = ""
    
    /// String representation of time for text field editing
    @State private var timeString = ""
    
    /// Controls visibility of the deletion confirmation dialog
    @State private var showingDeleteOptions = false
    
    // MARK: - Focus State
    
    /// Tracks which field has keyboard focus
    @FocusState private var focusedField: FocusableField?
    
    // MARK: - Dependencies
    
    private let calendarManager = CalendarManager.shared
    
    // MARK: - Types
    
    /// Represents a field that can be edited
    enum EditingField: Equatable {
        case title
        case date
        case location
        case notes
    }
    
    /// Represents a field that can receive keyboard focus (only for inline editing)
    enum FocusableField: Hashable {
        case title
    }
    
    // MARK: - Initialization
    
    /// Creates a timeline row for an event
    /// - Parameters:
    ///   - event: The timeline item to display
    ///   - isLast: Whether this is the last item in the timeline
    init(event: TimelineItem, isLast: Bool) {
        self.event = event
        self.isLast = isLast
    }
    
    // MARK: - Body
    
    var body: some View {
        if isDeleting {
            // Prevents rendering broken fallback states during deletion animation
            EmptyView()
        } else {
            mainContent
                .padding(.vertical, 12)
                .contextMenu { contextMenuContent }
                .task { await loadData() }
                .onReceive(calendarManager.calendarChangedPublisher) { _ in
                    Task { await loadData() }
                }
                .confirmationDialog(
                    "Are you sure you want to permanently delete this event from both CV Tracker and your calendar?",
                    isPresented: $showingDeleteOptions,
                    titleVisibility: .visible
                ) {
                    deletionDialogButtons
                }
                .onChange(of: focusedField) { oldValue, newValue in
                    handleFocusChange(from: oldValue, to: newValue)
                }
        }
    }
    
    // MARK: - Main Content
    
    /// The main content layout with timeline indicator and event details
    private var mainContent: some View {
        HStack(alignment: .top, spacing: 12) {
            timelineIndicator
            eventContent
        }
    }
    
    /// Visual timeline indicator (dot and line)
    private var timelineIndicator: some View {
        VStack(spacing: 0) {
            Circle()
                .fill(isUpcomingEvent ? Color.blue : Color.gray)
                .frame(width: 10, height: 10)
            
            if !isLast {
                Rectangle()
                    .fill(Color.gray.opacity(0.3))
                    .frame(width: 2)
            }
        }
        .frame(width: 20)
    }
    
    /// Main event content area
    private var eventContent: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let data = eventData {
                liveEventContent(data)
            } else if isLoading {
                ProgressView().controlSize(.small)
            } else {
                brokenLinkContent
            }
        }
    }
    
    /// Context menu with actions
    @ViewBuilder
    private var contextMenuContent: some View {
        Button("Delete", role: .destructive) {
            showingDeleteOptions = true
        }
    }
    
    /// Buttons for the deletion confirmation dialog
    @ViewBuilder
    private var deletionDialogButtons: some View {
        Button("Delete Everywhere", role: .destructive) {
            performDeletion(deleteFromCalendar: true)
        }
        
        Button("Unlink and Delete in App Only") {
            performDeletion(deleteFromCalendar: false)
        }
        
        Button("Cancel", role: .cancel) { }
    }
    
    // MARK: - Event Content Views
    
    /// Content displayed when event data is successfully loaded
    @ViewBuilder
    private func liveEventContent(_ data: CalendarEventData) -> some View {
        titleSection(data)
        dateSection(data)
        locationSection(data)
        notesSection
    }
    
    /// Content displayed when the calendar event no longer exists
    private var brokenLinkContent: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Event Link Broken")
                .font(.headline)
                .foregroundStyle(.red)
            
            Text("This event was removed from your system calendar.")
                .font(.caption)
                .foregroundStyle(.secondary)
            
            Button("Remove Link") {
                modelContext.delete(event)
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
        }
    }
    
    // MARK: - Field Sections
    
    /// Title section with inline editing
    @ViewBuilder
    private func titleSection(_ data: CalendarEventData) -> some View {
        if editingField == .title {
            HStack {
                TextField("Title", text: $editTitle)
                    .textFieldStyle(.roundedBorder)
                    .font(.body.bold())
                    .focused($focusedField, equals: .title)
                    .onSubmit { saveTitle() }
                
                Button("Save") {
                    saveTitle()
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
                
                Button("Cancel") {
                    cancelEditing()
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
            .onAppear {
                focusedField = .title
            }
        } else {
            HStack(spacing: 6) {
                Text(data.title)
                    .font(.title3.bold())
                
                Image(systemName: "calendar.badge.checkmark")
                    .font(.caption)
                    .foregroundStyle(.green)
            }
            .contentShape(Rectangle())
            .onTapGesture(count: 2) {
                enterEditMode(.title, with: data)
            }
        }
    }
    
    /// Date section with popover picker
    @ViewBuilder
    private func dateSection(_ data: CalendarEventData) -> some View {
        Text(data.startDate.formatted(date: .abbreviated, time: .shortened))
            .font(.subheadline)
            .foregroundStyle(.secondary)
            .onTapGesture(count: 2) {
                enterEditMode(.date, with: data)
                showingDatePicker = true
            }
            .popover(isPresented: $showingDatePicker) {
                EnhancedDateTimePickerView(
                    date: $editDate,
                    dateString: $dateString,
                    timeString: $timeString,
                    onSave: { saveDate() },
                    onCancel: { cancelDateEditing() }
                )
            }
    }
    
    /// Location section with MapKit search
    @ViewBuilder
    private func locationSection(_ data: CalendarEventData) -> some View {
        if editingField == .location {
            EnhancedLocationSearchField(
                location: $editLocation,
                onSave: { saveLocation() },
                onCancel: { cancelEditing() }
            )
        } else {
            Label(
                data.location.isEmpty ? "Add location" : data.location,
                systemImage: "mappin.and.ellipse"
            )
            .font(.subheadline)
            .foregroundStyle(data.location.isEmpty ? .tertiary : .secondary)
            .onTapGesture(count: 2) {
                enterEditMode(.location, with: data)
            }
        }
    }
    
    /// Preparation notes section (stored in SwiftData, not synced to calendar)
    @ViewBuilder
    private var notesSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            if editingField == .notes {
                notesEditingView
            } else {
                notesReadOnlyView
            }
        }
        .padding(.top, 6)
        .padding(.bottom, 8)
    }
    
    /// Notes editing interface
    private var notesEditingView: some View {
        VStack(alignment: .leading) {
            EnhancedTextEditor(
                text: $editPreparationNotes,
                onSave: { saveNotes() },
                onCancel: { cancelEditing() }
            )
            .frame(minHeight: 100)
            .padding(4)
            .background(Color(nsColor: .textBackgroundColor))
            .cornerRadius(4)
            
            HStack {
                Button("Save") {
                    saveNotes()
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
                
                Button("Cancel") {
                    cancelEditing()
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                
                Spacer()
                
                Text("Cmd+Enter to save")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
        }
        .frame(maxWidth: 500)
    }
    
    /// Notes read-only display
    private var notesReadOnlyView: some View {
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
        .padding(12)
        .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
        .background(Color(nsColor: .controlBackgroundColor).opacity(0.3))
        .cornerRadius(8)
        .contentShape(Rectangle())
        .onTapGesture(count: 2) {
            enterEditMode(.notes, with: eventData)
        }
        .frame(maxWidth: screenWidth * 0.7, alignment: .leading)
    }
    
    // MARK: - Data Loading
    
    /// Loads event data from the system calendar
    private func loadData() async {
        _ = await calendarManager.requestAccess()
        let data = calendarManager.getEventData(identifier: event.calendarEventID)
        
        await MainActor.run {
            self.eventData = data
            self.isLoading = false
        }
    }
    
    // MARK: - Edit Mode Management
    
    /// Enters edit mode for a specific field
    /// - Parameters:
    ///   - field: The field to edit
    ///   - data: Current event data (optional, used to populate edit fields)
    private func enterEditMode(_ field: EditingField, with data: CalendarEventData?) {
        // Cancel any existing edit
        if editingField != nil && editingField != field {
            cancelEditing()
        }
        
        // Populate edit fields based on field type
        switch field {
        case .title:
            editTitle = data?.title ?? ""
        case .date:
            editDate = data?.startDate ?? Date()
            dateString = formatDate(editDate)
            timeString = formatTime(editDate)
        case .location:
            editLocation = data?.location ?? ""
        case .notes:
            editPreparationNotes = event.preparationNotes
        }
        
        editingField = field
    }
    
    /// Sets initial focus when entering edit mode
    private func setInitialFocus() {
        guard let field = editingField else { return }
        
        // Only title field uses SwiftUI focus state; others manage focus internally
        if field == .title {
            // Small delay to ensure the field is rendered
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                focusedField = .title
            }
        }
    }
    
    /// Cancels editing without saving changes
    private func cancelEditing() {
        editingField = nil
        focusedField = nil
        showingDatePicker = false
    }
    
    /// Cancels date editing specifically (also closes popover)
    private func cancelDateEditing() {
        editingField = nil
        focusedField = nil
        showingDatePicker = false
    }
    
    /// Handles focus changes to implement "click away to cancel" behavior
    private func handleFocusChange(from oldValue: FocusableField?, to newValue: FocusableField?) {
        // If focus moves away from title field while editing, cancel
        if newValue == nil && editingField == .title {
            // Small delay to allow buttons to be clicked before canceling
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                if focusedField == nil && editingField == .title {
                    cancelEditing()
                }
            }
        }
    }
    
    // MARK: - Save Methods
    
    /// Saves the edited title to the calendar
    private func saveTitle() {
        guard let data = eventData else { return }
        
        _ = calendarManager.updateEvent(
            identifier: event.calendarEventID,
            title: editTitle,
            startDate: data.startDate,
            duration: data.duration,
            location: data.location,
            notes: event.preparationNotes,
            url: data.meetLink
        )
        
        editingField = nil
        Task { await loadData() }
    }
    
    /// Saves the edited date to the calendar
    private func saveDate() {
        guard let data = eventData else { return }
        
        _ = calendarManager.updateEvent(
            identifier: event.calendarEventID,
            title: data.title,
            startDate: editDate,
            duration: data.duration,
            location: data.location,
            notes: event.preparationNotes,
            url: data.meetLink
        )
        
        showingDatePicker = false
        editingField = nil
        Task { await loadData() }
    }
    
    /// Saves the edited location to the calendar
    private func saveLocation() {
        guard let data = eventData else { return }
        
        _ = calendarManager.updateEvent(
            identifier: event.calendarEventID,
            title: data.title,
            startDate: data.startDate,
            duration: data.duration,
            location: editLocation,
            notes: event.preparationNotes,
            url: data.meetLink
        )
        
        editingField = nil
        Task { await loadData() }
    }
    
    /// Saves the edited preparation notes to SwiftData (not synced to calendar)
    private func saveNotes() {
        event.preparationNotes = editPreparationNotes
        editingField = nil
    }
    
    // MARK: - Deletion
    
    /// Performs the deletion with optional calendar removal
    /// - Parameter deleteFromCalendar: Whether to also delete from the system calendar
    private func performDeletion(deleteFromCalendar: Bool) {
        withAnimation {
            isDeleting = true
        }
        
        if deleteFromCalendar {
            _ = calendarManager.deleteEvent(identifier: event.calendarEventID)
        } else {
            // When unlinking (not deleting), remove only the app-added reminders
            if !event.appAddedReminderOffsets.isEmpty {
                _ = calendarManager.removeReminders(
                    from: event.calendarEventID,
                    offsets: event.appAddedReminderOffsets
                )
            }
        }
        
        modelContext.delete(event)
    }
    
    // MARK: - Helper Properties & Methods
    
    /// Whether this event is in the future
    private var isUpcomingEvent: Bool {
        (eventData?.startDate ?? .now) > .now
    }
    
    /// Screen width for layout calculations
    private var screenWidth: CGFloat {
        NSScreen.main?.visibleFrame.width ?? 800
    }
    
    /// Formats a date as MM/dd/yyyy
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MM/dd/yyyy"
        return formatter.string(from: date)
    }
    
    /// Formats a time as HH:mm
    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: date)
    }
}
// MARK: - Enhanced Text Editor

/// A TextEditor with keyboard shortcuts for save (Cmd+Enter) and cancel (Esc)
private struct EnhancedTextEditor: NSViewRepresentable {
    @Binding var text: String
    let onSave: () -> Void
    let onCancel: () -> Void
    
    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSTextView.scrollableTextView()
        let customTextView = CustomTextView()
        
        customTextView.coordinator = context.coordinator
        customTextView.isRichText = false
        customTextView.font = NSFont.systemFont(ofSize: NSFont.systemFontSize(for: .small))
        customTextView.textColor = NSColor.textColor
        customTextView.backgroundColor = NSColor.textBackgroundColor
        customTextView.isAutomaticQuoteSubstitutionEnabled = false
        customTextView.isAutomaticDashSubstitutionEnabled = false
        customTextView.delegate = context.coordinator
        
        // Set initial text and move cursor to end
        customTextView.string = text
        customTextView.setSelectedRange(NSRange(location: text.count, length: 0))
        
        // Replace the default text view with our custom one
        scrollView.documentView = customTextView
        
        // Make the text view the first responder to auto-focus
        DispatchQueue.main.async {
            customTextView.window?.makeFirstResponder(customTextView)
        }
        
        return scrollView
    }
    
    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        guard let textView = scrollView.documentView as? NSTextView else { return }
        if textView.string != text {
            let selectedRange = textView.selectedRange()
            textView.string = text
            textView.setSelectedRange(selectedRange)
        }
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    // Custom NSTextView that intercepts keyboard events
    class CustomTextView: NSTextView {
        weak var coordinator: Coordinator?
        
        override func keyDown(with event: NSEvent) {
            // Check for Cmd+Enter
            if event.modifierFlags.contains(.command) && 
               (event.keyCode == 36 || event.keyCode == 76) { // 36 = Return, 76 = Enter
                coordinator?.parent.onSave()
                return
            }
            
            // Check for Esc
            if event.keyCode == 53 { // 53 = Escape
                coordinator?.parent.onCancel()
                return
            }
            
            // Pass other keys to the default handler
            super.keyDown(with: event)
        }
    }
    
    class Coordinator: NSObject, NSTextViewDelegate {
        let parent: EnhancedTextEditor
        
        init(_ parent: EnhancedTextEditor) {
            self.parent = parent
        }
        
        func textDidChange(_ notification: Notification) {
            guard let textView = notification.object as? NSTextView else { return }
            parent.text = textView.string
        }
    }
}

// MARK: - Enhanced Date Time Picker

/// Enhanced date/time picker with arrow key navigation and Enter to save
private struct EnhancedDateTimePickerView: View {
    @Binding var date: Date
    @Binding var dateString: String
    @Binding var timeString: String
    let onSave: () -> Void
    let onCancel: () -> Void
    
    @State private var calendarDate: Date
    @FocusState private var localFocus: LocalField?
    
    enum LocalField: Hashable {
        case date, time, calendar
    }
    
    init(date: Binding<Date>, dateString: Binding<String>, timeString: Binding<String>, onSave: @escaping () -> Void, onCancel: @escaping () -> Void) {
        self._date = date
        self._dateString = dateString
        self._timeString = timeString
        self.onSave = onSave
        self.onCancel = onCancel
        self._calendarDate = State(initialValue: date.wrappedValue)
    }
    
    var body: some View {
        VStack(spacing: 0) {
            Text("Select Date & Time")
                .font(.headline)
                .padding()
            
            Divider()
            
            VStack(spacing: 12) {
                TextField("MM/DD/YYYY", text: $dateString)
                    .focused($localFocus, equals: .date)
                    .onSubmit { localFocus = .time }
                    .onKeyPress(.downArrow) {
                        localFocus = .time
                        return .handled
                    }
                    .onKeyPress(.escape) {
                        onCancel()
                        return .handled
                    }
                
                TextField("HH:MM", text: $timeString)
                    .focused($localFocus, equals: .time)
                    .onSubmit { applyAndSave() }
                    .onKeyPress(.upArrow) {
                        localFocus = .date
                        return .handled
                    }
                    .onKeyPress(.downArrow) {
                        localFocus = .calendar
                        return .handled
                    }
                    .onKeyPress(.escape) {
                        onCancel()
                        return .handled
                    }
            }
            .padding()
            
            // Wrap DatePicker to make it focusable
            FocusableDatePicker(
                selection: $calendarDate,
                isFocused: localFocus == .calendar,
                onDateChange: { newValue in
                    updateFromCalendar(newValue)
                },
                onUpArrow: {
                    localFocus = .time
                },
                onEscape: {
                    onCancel()
                }
            )
            
            Divider()
            
            HStack {
                Button("Cancel") {
                    onCancel()
                }
                .keyboardShortcut(.cancelAction)
                
                Spacer()
                
                Button("Apply") {
                    applyAndSave()
                }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.defaultAction)
            }
            .padding()
        }
        .frame(width: 300)
        .onAppear {
            localFocus = .date
        }
    }
    
    private func updateFromCalendar(_ newValue: Date) {
        let calendar = Calendar.current
        var components = calendar.dateComponents([.year, .month, .day], from: newValue)
        let timeComponents = calendar.dateComponents([.hour, .minute], from: date)
        components.hour = timeComponents.hour
        components.minute = timeComponents.minute
        
        if let combined = calendar.date(from: components) {
            date = combined
            let formatter = DateFormatter()
            formatter.dateFormat = "MM/dd/yyyy"
            dateString = formatter.string(from: combined)
        }
    }
    
    private func applyAndSave() {
        let formatter = DateFormatter()
        formatter.dateFormat = "MM/dd/yyyy HH:mm"
        if let newDate = formatter.date(from: "\(dateString) \(timeString)") {
            date = newDate
        }
        onSave()
    }
}

// MARK: - Focusable Date Picker

/// A wrapper around DatePicker that can receive keyboard focus and handle arrow keys
private struct FocusableDatePicker: NSViewRepresentable {
    @Binding var selection: Date
    let isFocused: Bool
    let onDateChange: (Date) -> Void
    let onUpArrow: () -> Void
    let onEscape: () -> Void
    
    func makeNSView(context: Context) -> NSDatePicker {
        let datePicker = NSDatePicker()
        datePicker.datePickerStyle = .clockAndCalendar
        datePicker.datePickerElements = .yearMonthDay
        datePicker.dateValue = selection
        datePicker.target = context.coordinator
        datePicker.action = #selector(Coordinator.dateChanged(_:))
        
        // Make it respond to keyboard
        datePicker.setContentHuggingPriority(.defaultHigh, for: .horizontal)
        datePicker.setContentHuggingPriority(.defaultHigh, for: .vertical)
        
        return datePicker
    }
    
    func updateNSView(_ datePicker: NSDatePicker, context: Context) {
        datePicker.dateValue = selection
        context.coordinator.parent = self
        
        // Handle focus
        if isFocused {
            DispatchQueue.main.async {
                datePicker.window?.makeFirstResponder(datePicker)
            }
        }
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject {
        var parent: FocusableDatePicker
        
        init(_ parent: FocusableDatePicker) {
            self.parent = parent
        }
        
        @objc func dateChanged(_ sender: NSDatePicker) {
            parent.selection = sender.dateValue
            parent.onDateChange(sender.dateValue)
        }
    }
}

// MARK: - Enhanced Location Search Field

/// Location search field with arrow key navigation and Enter to save
private struct EnhancedLocationSearchField: View {
    @Binding var location: String
    let onSave: () -> Void
    let onCancel: () -> Void
    
    @StateObject private var searchCompleter = LocationSearchCompleter()
    @State private var selectedIndex: Int = -1
    @FocusState private var isFocused: Bool
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            TextField("Location", text: $location, prompt: Text("Search for a location..."))
                .textFieldStyle(.roundedBorder)
                .focused($isFocused)
                .onChange(of: location) { _, newValue in
                    searchCompleter.searchQuery = newValue
                    selectedIndex = -1
                }
                .onSubmit {
                    if selectedIndex >= 0 && selectedIndex < searchCompleter.results.count {
                        selectResult(at: selectedIndex)
                    } else {
                        onSave()
                    }
                }
                .onKeyPress(.upArrow) {
                    if !searchCompleter.results.isEmpty {
                        selectedIndex = max(0, selectedIndex - 1)
                        return .handled
                    }
                    return .ignored
                }
                .onKeyPress(.downArrow) {
                    if !searchCompleter.results.isEmpty {
                        selectedIndex = min(searchCompleter.results.count - 1, selectedIndex + 1)
                        return .handled
                    }
                    return .ignored
                }
                .onKeyPress(.escape) {
                    onCancel()
                    return .handled
                }
            
            if !searchCompleter.results.isEmpty {
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(Array(searchCompleter.results.enumerated()), id: \.element) { index, result in
                        Button {
                            selectResult(at: index)
                        } label: {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(result.title)
                                    .font(.body)
                                Text(result.subtitle)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            .padding(8)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(index == selectedIndex ? Color.accentColor.opacity(0.2) : Color.clear)
                        }
                        .buttonStyle(.plain)
                        
                        if index < searchCompleter.results.count - 1 {
                            Divider()
                        }
                    }
                }
                .background(Color(nsColor: .controlBackgroundColor))
                .cornerRadius(6)
                .shadow(radius: 2)
            }
        }
        .onAppear {
            isFocused = true
        }
    }
    
    private func selectResult(at index: Int) {
        let result = searchCompleter.results[index]
        location = "\(result.title), \(result.subtitle)"
        searchCompleter.results = []
        onSave()
    }
}

