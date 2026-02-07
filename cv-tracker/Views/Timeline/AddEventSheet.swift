//
//  AddEventSheet.swift
//  cv-tracker
//
//  Created by Ksenia Pravdina on 07/02/2026.
//
import SwiftUI
import SwiftData
import MapKit
import Combine
import EventKit

struct AddEventSheet: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    
    var application: ApplicationItem
    
    init(application: ApplicationItem) {
        self.application = application
    }
    
    @State private var title = ""
    @State private var date = Date()
    @State private var duration: TimeInterval = 3600
    @State private var location = ""
    @State private var meetLink = ""
    @State private var preparationNotes = ""
    @State private var showingCalendarPicker = false
    private var calendarManager = CalendarManager.shared
    @FocusState private var focusedField: Bool
    @State private var showToast = false
    
    var body: some View {
        ZStack(alignment: .topTrailing) {
            NavigationStack {
                Form {
                    Section("Import") {
                        Button { 
                            showingCalendarPicker = true 
                        } label: {
                            Label("Import from Calendar", systemImage: "calendar.badge.plus").frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.bordered)
                    }
                    
                    Section("Event Details") {
                        TextField("Title", text: $title).focused($focusedField)
                        DatePicker("Start Date & Time", selection: $date)
                        Picker("Duration", selection: $duration) {
                            Text("30 min").tag(TimeInterval(1800))
                            Text("1 hour").tag(TimeInterval(3600))
                            Text("2 hours").tag(TimeInterval(7200))
                        }
                    }
                    
                    Section("Logistics") {
                        LocationSearchField(location: $location, autoFocus: false)
                        TextField("Meeting Link", text: $meetLink)
                    }
                    
                    Section("Internal Prep Notes") {
                        TextEditor(text: $preparationNotes).frame(height: 80)
                    }
                }
                .formStyle(.grouped)
                .navigationTitle("Add Event")
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Save") { 
                            Task { await saveEvent() } 
                        }
                        .disabled(title.isEmpty)
                    }
                }
            }
            
            if showToast {
                ToastView(message: "Event Synced!", icon: "checkmark.circle.fill")
                    .padding()
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .frame(width: 500, height: 600)
        .sheet(isPresented: $showingCalendarPicker) {
            CalendarEventPickerSheet(application: application) { event in
                importEvent(event)
            }
        }
    }
    
    private func saveEvent() async {
        // 1. Create the system calendar event first
        guard let calendarEventID = calendarManager.createEvent(
            title: title, 
            startDate: date, 
            duration: duration, 
            location: location,
            notes: "Job Tracker Prep: \(preparationNotes)", 
            url: meetLink
        ) else {
            // Handle error: Calendar access might be denied
            return
        }
        
        // 2. Create the SwiftData link
        let newItem = TimelineItem(calendarEventID: calendarEventID, preparationNotes: preparationNotes)
        newItem.application = application
        modelContext.insert(newItem)
        
        // Show success and dismiss
        withAnimation { showToast = true }
        try? await Task.sleep(for: .seconds(1))
        dismiss()
    }
    
    private func importEvent(_ event: EKEvent) {
        // Link existing event to this application
        let newItem = TimelineItem(
            calendarEventID: event.eventIdentifier, 
            preparationNotes: event.notes ?? ""
        )
        newItem.application = application
        modelContext.insert(newItem)
        dismiss()
    }
}
