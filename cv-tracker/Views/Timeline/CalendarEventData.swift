//
//  CalendarEventData.swift
//  cv-tracker
//
//  Created by Ksenia Pravdina on 07/02/2026.
//

import Foundation

/// A simple, ephemeral data structure to hold live info from the system Calendar
struct CalendarEventData {
    let id: String
    let title: String
    let startDate: Date
    let endDate: Date
    let location: String
    let meetLink: String?
    let calendarNotes: String?
    
    /// Calculated property to help with UI layout or durations
    var duration: TimeInterval {
        endDate.timeIntervalSince(startDate)
    }
}
