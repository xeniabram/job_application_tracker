//
//  ReminderManager.swift
//  cv-tracker
//
//  Created by Ksenia Pravdina on 06/02/2026.
//

import Foundation
import EventKit

@MainActor
class ReminderManager {
    static let shared = ReminderManager()
    private let eventStore = EKEventStore()
    
    // Request permission to access Reminders
    func requestAccess() async -> Bool {
        do {
            // Modern macOS 14+ permission request
            if #available(macOS 14.0, *) {
                return try await eventStore.requestFullAccessToReminders()
            } else {
                // Fallback for older macOS versions
                return try await withCheckedThrowingContinuation { continuation in
                    eventStore.requestAccess(to: .reminder) { granted, error in
                        if let error = error {
                            continuation.resume(throwing: error)
                        } else {
                            continuation.resume(returning: granted)
                        }
                    }
                }
            }
        } catch {
            print("Access denied: \(error.localizedDescription)")
            return false
        }
    }
    
    // Update the function signature to accept customTitle
    func scheduleReminder(for item: ApplicationItem, customTitle: String) async {
        let granted = await requestAccess()
        guard granted else { return }
        
        // Remove existing if it exists
        if let oldID = item.reminderID, let oldReminder = eventStore.calendarItem(withIdentifier: oldID) as? EKReminder {
            try? eventStore.remove(oldReminder, commit: true)
        }
        
        let reminder = EKReminder(eventStore: eventStore)
        
        // USE THE CUSTOM TITLE HERE
        reminder.title = "\(customTitle): \(item.companyName)"
        
        reminder.calendar = eventStore.defaultCalendarForNewReminders()
        
        let calendar = Calendar.current
        var dateComponents = DateComponents()
        
        switch item.consentInterval {
        case 1: dateComponents.weekOfYear = 1
        case 2: dateComponents.weekOfYear = 2
        case 4: dateComponents.month = 1
        case 12: dateComponents.month = 3
        default: return
        }
        
        if let dueDate = calendar.date(byAdding: dateComponents, to: .now) {
            reminder.dueDateComponents = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: dueDate)
            let alarm = EKAlarm(absoluteDate: dueDate)
            reminder.addAlarm(alarm)
        }
        
        reminder.notes = "Check details for \(item.position) in Job Tracker."
        
        do {
            try eventStore.save(reminder, commit: true)
            item.reminderID = reminder.calendarItemIdentifier
        } catch {
            print("Failed to save: \(error.localizedDescription)")
        }
    }
}
