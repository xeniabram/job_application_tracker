//
//  TimelineItem.swift
//  cv-tracker
//
//  Created by Ksenia Pravdina on 07/02/2026.
//

import Foundation
import SwiftData

@Model
final class TimelineItem {
    var title: String
    var date: Date
    var duration: TimeInterval // in seconds, default 1 hour
    var location: String
    var meetLink: String
    var preparationNotes: String
    
    // Calendar integration
    var calendarEventID: String?
    
    // Relationship back to the parent application
    var application: ApplicationItem?

    init(
        title: String = "",
        date: Date = .now,
        duration: TimeInterval = 3600, // 1 hour default
        location: String = "",
        meetLink: String = "",
        preparationNotes: String = "",
        calendarEventID: String? = nil
    ) {
        self.title = title
        self.date = date
        self.duration = duration
        self.location = location
        self.meetLink = meetLink
        self.preparationNotes = preparationNotes
        self.calendarEventID = calendarEventID
    }
}
