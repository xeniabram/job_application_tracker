import SwiftUI
import SwiftData
import MapKit
import Combine
import EventKit

// MARK: - Timeline Section
struct TimelineSection: View {
    var application: ApplicationItem
    @State private var showingAddEvent = false
    @Environment(\.modelContext) private var modelContext
    
    var body: some View {
        Section {
            if let events = application.timeline?.sorted(by: { $0.date < $1.date }), !events.isEmpty {
                ForEach(events) { event in
                    TimelineRow(event: event, isLast: event == events.last)
                }
            } else {
                Text("No events yet")
                    .foregroundStyle(.secondary)
            }
        } header: {
            HStack {
                Label("Timeline", systemImage: "timer")
                Spacer()
                
                Button {
                    showingAddEvent = true
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .imageScale(.large)
                }
                .buttonStyle(.plain)
                .help("Add Event")
            }
        }
        .sheet(isPresented: $showingAddEvent) {
            AddEventSheet(application: application)
        }
    }
}

// MARK: - Timeline Row
struct TimelineRow: View {
    let event: TimelineItem
    let isLast: Bool
    @State private var editingField: EditingField? = nil
    @Environment(\.modelContext) private var modelContext
    @FocusState private var isFocused: Bool
    @StateObject private var calendarManager = CalendarManager()
    
    @State private var editTitle = ""
    @State private var editDate = Date()
    @State private var editLocation = ""
    @State private var editMeetLink = ""
    @State private var editPreparationNotes = ""
    @State private var showingDatePicker = false
    @State private var dateString = ""
    @State private var timeString = ""
    
    enum EditingField {
        case title, date, location, meetLink, notes
    }
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            // Timeline indicator
            VStack(spacing: 0) {
                Circle()
                    .fill(event.date > .now ? Color.blue : Color.gray)
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
                // Title
                if editingField == .title {
                    HStack {
                        TextField("Title", text: $editTitle)
                            .textFieldStyle(.roundedBorder)
                            .font(.body.bold())
                            .focused($isFocused)
                            .onSubmit {
                                saveTitle()
                            }
                        
                        Button("Save") {
                            saveTitle()
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.small)
                        .keyboardShortcut(.return, modifiers: [])
                        
                        Button("Cancel") {
                            editingField = nil
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                        .keyboardShortcut(.cancelAction)
                    }
                    .onAppear {
                        isFocused = true
                    }
                } else {
                    HStack(spacing: 6) {
                        Text(event.title)
                            .font(.title3.bold())
                        
                        if event.calendarEventID != nil {
                            Image(systemName: "calendar.badge.checkmark")
                                .font(.caption)
                                .foregroundStyle(.green)
                                .help("Synced with Calendar")
                        }
                        
                        Spacer()
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .contentShape(Rectangle())
                    .onTapGesture(count: 2) {
                        editTitle = event.title
                        editingField = .title
                    }
                }
                
                // Date
                Text(event.date.formatted(date: .abbreviated, time: .shortened))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .contentShape(Rectangle())
                    .onTapGesture(count: 2) {
                        editDate = event.date
                        dateString = formatDate(event.date)
                        timeString = formatTime(event.date)
                        showingDatePicker = true
                    }
                    .popover(isPresented: $showingDatePicker) {
                        DateTimePickerView(
                            date: $editDate,
                            dateString: $dateString,
                            timeString: $timeString,
                            onSave: {
                                saveDate()
                                showingDatePicker = false
                            },
                            onCancel: {
                                editDate = event.date
                                showingDatePicker = false
                            }
                        )
                    }
                
                // Location
                if editingField == .location {
                    VStack(alignment: .leading, spacing: 4) {
                        LocationSearchField(location: $editLocation, onSave: {
                            saveLocation()
                        })
                        
                        HStack {
                            Button("Save") {
                                saveLocation()
                            }
                            .buttonStyle(.borderedProminent)
                            .controlSize(.small)
                            .keyboardShortcut(.return, modifiers: [])
                            
                            Button("Cancel") {
                                editingField = nil
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                            .keyboardShortcut(.cancelAction)
                        }
                    }
                } else {
                    Label(event.location.isEmpty ? "Add location" : event.location, systemImage: "mappin.and.ellipse")
                        .font(.subheadline)
                        .foregroundStyle(event.location.isEmpty ? .tertiary : .secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .contentShape(Rectangle())
                        .onTapGesture(count: 2) {
                            editLocation = event.location
                            editingField = .location
                        }
                }
                
                // Meeting Link
                if editingField == .meetLink {
                    VStack(alignment: .leading, spacing: 4) {
                        TextField("Meeting Link", text: $editMeetLink)
                            .textFieldStyle(.roundedBorder)
                            .focused($isFocused)
                            .onSubmit {
                                saveMeetLink()
                            }
                        
                        HStack {
                            Button("Save") {
                                saveMeetLink()
                            }
                            .buttonStyle(.borderedProminent)
                            .controlSize(.small)
                            .keyboardShortcut(.return, modifiers: [])
                            
                            Button("Cancel") {
                                editingField = nil
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                            .keyboardShortcut(.cancelAction)
                        }
                    }
                    .onAppear {
                        isFocused = true
                    }
                } else {
                    if event.meetLink.isEmpty {
                        Label("Add meeting link", systemImage: "video")
                            .font(.subheadline)
                            .foregroundStyle(.tertiary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .contentShape(Rectangle())
                            .onTapGesture(count: 2) {
                                editMeetLink = event.meetLink
                                editingField = .meetLink
                            }
                    } else {
                        HStack(alignment: .top) {
                            Link(destination: URL(string: event.meetLink) ?? URL(string: "https://")!) {
                                Label(event.meetLink, systemImage: "video")
                                    .font(.subheadline)
                                    .foregroundStyle(.blue)
                            }
                            .buttonStyle(.plain)
                            
                            Spacer()
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .contentShape(Rectangle())
                        .onTapGesture(count: 2) {
                            editMeetLink = event.meetLink
                            editingField = .meetLink
                        }
                    }
                }
                
                // Preparation Notes
                if editingField == .notes {
                    VStack(alignment: .leading, spacing: 4) {
                        ZStack(alignment: .topLeading) {
                            TextEditor(text: $editPreparationNotes)
                                .frame(minHeight: 80)
                                .font(.subheadline)
                                .focused($isFocused)
                                .padding(4)
                        }
                        .background(Color(nsColor: .textBackgroundColor))
                        .cornerRadius(4)
                        .overlay(
                            RoundedRectangle(cornerRadius: 4)
                                .stroke(Color.gray.opacity(0.2), lineWidth: 1)
                        )
                        
                        HStack {
                            Button("Save") {
                                saveNotes()
                            }
                            .buttonStyle(.borderedProminent)
                            .controlSize(.small)
                            
                            Button("Cancel") {
                                editingField = nil
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                            .keyboardShortcut(.cancelAction)
                        }
                    }
                    .onAppear {
                        isFocused = true
                    }
                    .onKeyPress(.return, phases: .down) { press in
                        if press.modifiers.contains(.command) {
                            saveNotes()
                            return .handled
                        }
                        return .ignored
                    }
                } else {
                    if event.preparationNotes.isEmpty {
                        Text("Add your notes here...")
                            .font(.subheadline)
                            .foregroundStyle(.tertiary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .contentShape(Rectangle())
                            .onTapGesture(count: 2) {
                                editPreparationNotes = event.preparationNotes
                                editingField = .notes
                            }
                    } else {
                        VStack(alignment: .leading, spacing: 0) {
                            ClickableTextView(text: event.preparationNotes)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                                .padding(8)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .background(Color(nsColor: .controlBackgroundColor).opacity(0.3))
                        .cornerRadius(6)
                        .contentShape(Rectangle())
                        .onTapGesture(count: 2) {
                            editPreparationNotes = event.preparationNotes
                            editingField = .notes
                        }
                    }
                }
            }
        }
        .padding(.vertical, 12)
        .contextMenu {
            Button("Delete", role: .destructive) {
                deleteEvent()
            }
        }
        .task {
            // Request calendar access once when row appears (only if event is synced)
            if event.calendarEventID != nil {
                _ = await calendarManager.requestAccess()
            }
        }
    }
    
    // MARK: - Calendar Sync Methods
    private func saveTitle() {
        event.title = editTitle
        syncToCalendar()
        editingField = nil
    }
    
    private func saveDate() {
        event.date = editDate
        syncToCalendar()
    }
    
    private func saveLocation() {
        event.location = editLocation
        syncToCalendar()
        editingField = nil
    }
    
    private func saveMeetLink() {
        event.meetLink = editMeetLink
        syncToCalendar()
        editingField = nil
    }
    
    private func saveNotes() {
        event.preparationNotes = editPreparationNotes
        syncToCalendar()
        editingField = nil
    }
    
    private func syncToCalendar() {
        guard let calendarEventID = event.calendarEventID else { return }
        
        Task {
            let success = calendarManager.updateEvent(
                identifier: calendarEventID,
                title: event.title,
                startDate: event.date,
                duration: event.duration,
                location: event.location,
                notes: event.preparationNotes,
                url: event.meetLink.isEmpty ? nil : event.meetLink
            )
            
            if !success {
                print("Failed to update calendar event")
            }
        }
    }
    
    private func deleteEvent() {
        // Delete from calendar if it exists
        if let calendarEventID = event.calendarEventID {
            Task {
                _ = calendarManager.deleteEvent(identifier: calendarEventID)
            }
        }
        
        // Delete from SwiftData
        modelContext.delete(event)
    }
    
    // Helper functions for date/time formatting
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MM/dd/yyyy"
        return formatter.string(from: date)
    }
    
    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: date)
    }
}

// MARK: - Date Time Picker View
struct DateTimePickerView: View {
    @Binding var date: Date
    @Binding var dateString: String
    @Binding var timeString: String
    let onSave: () -> Void
    let onCancel: () -> Void
    
    @FocusState private var focusedField: Field?
    @State private var calendarDate: Date
    
    enum Field {
        case date, time
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
            // Header with visual polish
            VStack(spacing: 8) {
                HStack {
                    Image(systemName: "calendar")
                        .foregroundStyle(.blue)
                        .font(.title2)
                    Text("Select Date & Time")
                        .font(.system(size: 15, weight: .semibold))
                    Spacer()
                }
                .padding(.horizontal, 20)
                .padding(.top, 16)
            }
            
            Divider()
                .padding(.top, 12)
            
            // Manual input fields with macOS styling (moved above calendar)
            VStack(spacing: 12) {
                // Date input
                HStack(spacing: 8) {
                    Image(systemName: "calendar.badge.clock")
                        .foregroundStyle(.secondary)
                        .font(.system(size: 13))
                        .frame(width: 20)
                    
                    TextField("MM/DD/YYYY", text: $dateString)
                        .textFieldStyle(.plain)
                        .font(.system(size: 13, weight: .regular, design: .monospaced))
                        .focused($focusedField, equals: .date)
                        .onSubmit {
                            updateDateFromString()
                            focusedField = .time
                        }
                        .onChange(of: dateString) { _, _ in
                            updateDateFromString()
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 7)
                        .background(Color(nsColor: .textBackgroundColor))
                        .cornerRadius(6)
                        .overlay(
                            RoundedRectangle(cornerRadius: 6)
                                .strokeBorder(focusedField == .date ? Color.accentColor : Color(nsColor: .separatorColor), lineWidth: focusedField == .date ? 2 : 0.5)
                        )
                        .shadow(color: focusedField == .date ? Color.accentColor.opacity(0.3) : .clear, radius: 3, x: 0, y: 0)
                }
                
                // Time input
                HStack(spacing: 8) {
                    Image(systemName: "clock")
                        .foregroundStyle(.secondary)
                        .font(.system(size: 13))
                        .frame(width: 20)
                    
                    TextField("HH:MM", text: $timeString)
                        .textFieldStyle(.plain)
                        .font(.system(size: 13, weight: .regular, design: .monospaced))
                        .focused($focusedField, equals: .time)
                        .onSubmit {
                            updateTimeFromString()
                            applyAndSave()
                        }
                        .onChange(of: timeString) { _, _ in
                            updateTimeFromString()
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 7)
                        .background(Color(nsColor: .textBackgroundColor))
                        .cornerRadius(6)
                        .overlay(
                            RoundedRectangle(cornerRadius: 6)
                                .strokeBorder(focusedField == .time ? Color.accentColor : Color(nsColor: .separatorColor), lineWidth: focusedField == .time ? 2 : 0.5)
                        )
                        .shadow(color: focusedField == .time ? Color.accentColor.opacity(0.3) : .clear, radius: 3, x: 0, y: 0)
                }
                
                // Helper text
                HStack(spacing: 4) {
                    Image(systemName: "info.circle")
                        .font(.system(size: 10))
                        .foregroundStyle(.tertiary)
                    Text("Use ↑↓ arrows to navigate, Enter to save")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(.horizontal, 20)
            .padding(.top, 16)
            .padding(.bottom, 12)
            .onKeyPress(.upArrow) {
                if focusedField == .time {
                    focusedField = .date
                    return .handled
                }
                return .ignored
            }
            .onKeyPress(.downArrow) {
                if focusedField == .date {
                    focusedField = .time
                    return .handled
                }
                return .ignored
            }
            .onAppear {
                // Auto-focus date field on appear
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    focusedField = .date
                }
            }
            
            Divider()
            
            // Calendar with enhanced styling
            ZStack {
                // Background for calendar
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color(nsColor: .controlBackgroundColor).opacity(0.5))
                    .padding(.horizontal, 16)
                
                DatePicker("", selection: $calendarDate, displayedComponents: .date)
                    .datePickerStyle(.graphical)
                    .labelsHidden()
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .onChange(of: calendarDate) { _, newValue in
                        let calendar = Calendar.current
                        let timeComponents = calendar.dateComponents([.hour, .minute], from: date)
                        var components = calendar.dateComponents([.year, .month, .day], from: newValue)
                        components.hour = timeComponents.hour
                        components.minute = timeComponents.minute
                        
                        if let combined = calendar.date(from: components) {
                            date = combined
                            let formatter = DateFormatter()
                            formatter.dateFormat = "MM/dd/yyyy"
                            dateString = formatter.string(from: combined)
                        }
                    }
            }
            .padding(.top, 8)
            .padding(.bottom, 16)
            
            Divider()
            
            // Action buttons with macOS styling
            HStack(spacing: 12) {
                Button("Cancel") {
                    onCancel()
                }
                .buttonStyle(.borderless)
                .foregroundStyle(.secondary)
                .keyboardShortcut(.cancelAction)
                
                Spacer()
                
                Button("Apply") {
                    applyAndSave()
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 14)
            .background(Color(nsColor: .controlBackgroundColor).opacity(0.5))
        }
        .frame(width: 340)
        .background(Color(nsColor: .windowBackgroundColor))
    }
    
    private func applyAndSave() {
        updateDateFromString()
        updateTimeFromString()
        onSave()
    }
    
    private func updateDateFromString() {
        let formatter = DateFormatter()
        formatter.dateFormat = "MM/dd/yyyy"
        
        if let newDate = formatter.date(from: dateString) {
            let calendar = Calendar.current
            let timeComponents = calendar.dateComponents([.hour, .minute], from: date)
            var components = calendar.dateComponents([.year, .month, .day], from: newDate)
            components.hour = timeComponents.hour
            components.minute = timeComponents.minute
            
            if let combined = calendar.date(from: components) {
                date = combined
                calendarDate = combined
            }
        }
    }
    
    private func updateTimeFromString() {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        
        if let timeDate = formatter.date(from: timeString) {
            let calendar = Calendar.current
            let timeComponents = calendar.dateComponents([.hour, .minute], from: timeDate)
            var components = calendar.dateComponents([.year, .month, .day], from: date)
            components.hour = timeComponents.hour
            components.minute = timeComponents.minute
            
            if let combined = calendar.date(from: components) {
                date = combined
            }
        }
    }
}

// MARK: - Add Event Sheet
struct AddEventSheet: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    
    var application: ApplicationItem
    
    @State private var title = ""
    @State private var date = Date()
    @State private var duration: TimeInterval = 3600 // 1 hour default
    @State private var location = ""
    @State private var meetLink = ""
    @State private var preparationNotes = ""
    @State private var showingCalendarPicker = false
    @StateObject private var calendarManager = CalendarManager()
    @State private var calendarAccessRequested = false
    @FocusState private var focusedField: Field?
    @State private var showToast = false
    
    enum Field {
        case title
    }
    
    var body: some View {
        ZStack(alignment: .topTrailing) {
            NavigationStack {
                ScrollView {
                    VStack(spacing: 0) {
                        // Import section
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Or import existing event")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .padding(.horizontal, 20)
                                .padding(.top, 8)
                            
                            Button {
                                showingCalendarPicker = true
                            } label: {
                                Label("Import from Calendar", systemImage: "calendar.badge.plus")
                                    .frame(maxWidth: .infinity, alignment: .center)
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.large)
                            .padding(.horizontal, 20)
                            .padding(.bottom, 16)
                        }
                        
                        Divider()
                        
                        // Form content
                        Form {
                            Section("Event Details") {
                                TextField("Title", text: $title)
                                    .focused($focusedField, equals: .title)
                                DatePicker("Start Date & Time", selection: $date)
                                
                                HStack {
                                    Text("Duration")
                                    Spacer()
                                    Picker("Duration", selection: $duration) {
                                        Text("15 min").tag(TimeInterval(15 * 60))
                                        Text("30 min").tag(TimeInterval(30 * 60))
                                        Text("45 min").tag(TimeInterval(45 * 60))
                                        Text("1 hour").tag(TimeInterval(60 * 60))
                                        Text("1.5 hours").tag(TimeInterval(90 * 60))
                                        Text("2 hours").tag(TimeInterval(120 * 60))
                                        Text("3 hours").tag(TimeInterval(180 * 60))
                                    }
                                    .labelsHidden()
                                }
                            }
                            
                            Section("Logistics") {
                                LocationSearchField(location: $location, autoFocus: false)
                                TextField("Meeting Link", text: $meetLink)
                            }
                            
                            Section("Notes") {
                                TextEditor(text: $preparationNotes)
                                    .frame(height: 80)
                            }
                        }
                        .formStyle(.grouped)
                    }
                }
                .navigationTitle("Add Event")
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel") {
                            dismiss()
                        }
                    }
                    
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Save") {
                            Task {
                                await saveEvent()
                            }
                        }
                        .disabled(title.isEmpty)
                    }
                }
                .onAppear {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        focusedField = .title
                    }
                }
                .task {
                    if !calendarAccessRequested {
                        _ = await calendarManager.requestAccess()
                        calendarAccessRequested = true
                    }
                }
            }
            .frame(minHeight: 400, maxHeight: 650)
            .sheet(isPresented: $showingCalendarPicker) {
                CalendarEventPickerSheet(application: application) { event in
                    importEvent(event)
                    dismiss()
                }
            }
            
            // Toast notification
            if showToast {
                ToastView(message: "Event added to Calendar!", icon: "checkmark.circle.fill")
                    .padding(16)
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .zIndex(1)
            }
        }
    }
    
    private func saveEvent() async {
        // Create calendar event first
        let calendarEventID = calendarManager.createEvent(
            title: title,
            startDate: date,
            duration: duration,
            location: location,
            notes: preparationNotes,
            url: meetLink.isEmpty ? nil : meetLink
        )
        
        // Create timeline item
        let newEvent = TimelineItem(
            title: title,
            date: date,
            duration: duration,
            location: location,
            meetLink: meetLink,
            preparationNotes: preparationNotes,
            calendarEventID: calendarEventID
        )
        newEvent.application = application
        modelContext.insert(newEvent)
        
        // Show toast if calendar event was created
        if calendarEventID != nil {
            withAnimation(.spring(response: 0.3)) {
                showToast = true
            }
            
            try? await Task.sleep(for: .seconds(2))
            
            withAnimation(.spring(response: 0.3)) {
                showToast = false
            }
            
            try? await Task.sleep(for: .seconds(0.3))
        }
        
        dismiss()
    }
    
    private func importEvent(_ event: EKEvent) {
        let eventDuration = event.endDate.timeIntervalSince(event.startDate)
        let newEvent = TimelineItem(
            title: event.title ?? "Untitled Event",
            date: event.startDate,
            duration: eventDuration,
            location: event.location ?? "",
            meetLink: event.url?.absoluteString ?? "",
            preparationNotes: event.notes ?? "",
            calendarEventID: event.eventIdentifier
        )
        newEvent.application = application
        modelContext.insert(newEvent)
    }
}

// MARK: - Toast View
// MARK: - Clickable Text View
struct ClickableTextView: View {
    let text: String
    
    var body: some View {
        Text(attributedText)
            .textSelection(.enabled)
    }
    
    private var attributedText: AttributedString {
        var attributedString = AttributedString(text)
        
        // Simple URL detection regex
        let pattern = "(https?://[^\\s]+)"
        if let regex = try? NSRegularExpression(pattern: pattern, options: []) {
            let nsString = text as NSString
            let matches = regex.matches(in: text, options: [], range: NSRange(location: 0, length: nsString.length))
            
            for match in matches.reversed() {
                if let range = Range(match.range, in: text) {
                    let urlString = String(text[range])
                    if let url = URL(string: urlString) {
                        let startIndex = attributedString.index(attributedString.startIndex, offsetByCharacters: match.range.location)
                        let endIndex = attributedString.index(startIndex, offsetByCharacters: match.range.length)
                        attributedString[startIndex..<endIndex].link = url
                        attributedString[startIndex..<endIndex].foregroundColor = .blue
                        attributedString[startIndex..<endIndex].underlineStyle = .single
                    }
                }
            }
        }
        
        return attributedString
    }
}

// MARK: - Location Search Field
struct LocationSearchField: View {
    @Binding var location: String
    var onSave: (() -> Void)? = nil
    var autoFocus: Bool = true
    @StateObject private var searchCompleter = LocationSearchCompleter()
    @State private var selectedIndex: Int = -1
    @FocusState private var isFocused: Bool
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            TextField("Location", text: $location, prompt: Text("Search for a location..."))
                .textFieldStyle(.roundedBorder)
                .focused($isFocused)
                .onChange(of: location) { oldValue, newValue in
                    searchCompleter.searchQuery = newValue
                    selectedIndex = -1
                }
                .onSubmit {
                    if selectedIndex >= 0 && selectedIndex < searchCompleter.results.count {
                        selectLocation(searchCompleter.results[selectedIndex])
                    } else if !location.isEmpty {
                        onSave?()
                    }
                }
                .onKeyPress(.upArrow) {
                    if !searchCompleter.results.isEmpty {
                        selectedIndex = max(-1, selectedIndex - 1)
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
                .onAppear {
                    if autoFocus {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                            isFocused = true
                        }
                    }
                }
            
            // Search results dropdown
            if !searchCompleter.results.isEmpty {
                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        ForEach(Array(searchCompleter.results.enumerated()), id: \.offset) { index, result in
                            Button {
                                selectLocation(result)
                            } label: {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(result.title)
                                        .font(.body)
                                        .foregroundStyle(.primary)
                                    
                                    Text(result.subtitle)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 8)
                            }
                            .buttonStyle(.plain)
                            .background(
                                selectedIndex == index ? Color.accentColor.opacity(0.2) : Color.clear
                            )
                            .contentShape(Rectangle())
                            
                            if index < searchCompleter.results.count - 1 {
                                Divider()
                            }
                        }
                    }
                }
                .frame(maxHeight: 300)
                .background(Color(nsColor: .controlBackgroundColor))
                .cornerRadius(6)
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                )
                .shadow(color: .black.opacity(0.1), radius: 4, y: 2)
                .padding(.horizontal, 4)
            }
        }
    }
    
    private func selectLocation(_ result: MKLocalSearchCompletion) {
        location = "\(result.title), \(result.subtitle)"
        searchCompleter.searchQuery = ""
        selectedIndex = -1
        onSave?()
    }
}

// MARK: - Location Search Completer
class LocationSearchCompleter: NSObject, ObservableObject {
    @Published var results: [MKLocalSearchCompletion] = []
    
    private let completer: MKLocalSearchCompleter
    
    var searchQuery: String = "" {
        didSet {
            if searchQuery.count > 2 {
                completer.queryFragment = searchQuery
            } else {
                results = []
            }
        }
    }
    
    override init() {
        completer = MKLocalSearchCompleter()
        super.init()
        completer.delegate = self
        completer.resultTypes = .address
    }
}

extension LocationSearchCompleter: MKLocalSearchCompleterDelegate {
    func completerDidUpdateResults(_ completer: MKLocalSearchCompleter) {
        DispatchQueue.main.async {
            self.results = completer.results
        }
    }
    
    func completer(_ completer: MKLocalSearchCompleter, didFailWithError error: Error) {
        DispatchQueue.main.async {
            print("Location search error: \(error.localizedDescription)")
            self.results = []
        }
    }
}
