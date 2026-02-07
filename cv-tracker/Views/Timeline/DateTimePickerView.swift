//
//  DateTimePickerView.swift
//  cv-tracker
//
//  Created by Ksenia Pravdina on 07/02/2026.
//

import SwiftUI
import SwiftData
import MapKit
import Combine
import EventKit

// MARK: - Date Time Picker View
struct DateTimePickerView: View {
    @Binding var date: Date
    @Binding var dateString: String
    @Binding var timeString: String
    let onSave: () -> Void
    let onCancel: () -> Void
    
    @FocusState private var focusedField: Field?
    @State private var calendarDate: Date
    
    enum Field { case date, time }
    
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
            Text("Select Date & Time").font(.headline).padding()
            Divider()
            VStack(spacing: 12) {
                TextField("MM/DD/YYYY", text: $dateString).focused($focusedField, equals: .date)
                TextField("HH:MM", text: $timeString).focused($focusedField, equals: .time)
            }
            .padding()
            DatePicker("", selection: $calendarDate, displayedComponents: .date)
                .datePickerStyle(.graphical)
                .onChange(of: calendarDate) { _, newValue in
                    updateFromCalendar(newValue)
                }
            Divider()
            HStack {
                Button("Cancel") { onCancel() }
                Spacer()
                Button("Apply") { applyAndSave() }.buttonStyle(.borderedProminent)
            }.padding()
        }
        .frame(width: 300)
    }
    
    private func updateFromCalendar(_ newValue: Date) {
        let calendar = Calendar.current
        var components = calendar.dateComponents([.year, .month, .day], from: newValue)
        let timeComponents = calendar.dateComponents([.hour, .minute], from: date)
        components.hour = timeComponents.hour
        components.minute = timeComponents.minute
        if let combined = calendar.date(from: components) {
            date = combined
            let formatter = DateFormatter(); formatter.dateFormat = "MM/dd/yyyy"
            dateString = formatter.string(from: combined)
        }
    }

    private func applyAndSave() {
        let formatter = DateFormatter(); formatter.dateFormat = "MM/dd/yyyy HH:mm"
        if let newDate = formatter.date(from: "\(dateString) \(timeString)") {
            date = newDate
        }
        onSave()
    }
}
