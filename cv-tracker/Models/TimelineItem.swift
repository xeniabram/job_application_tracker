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
    var calendarEventID: String // The anchor to the system calendar
    var preparationNotes: String // App-specific data
    var application: ApplicationItem?
    
    init(calendarEventID: String, preparationNotes: String = "") {
        self.calendarEventID = calendarEventID
        self.preparationNotes = preparationNotes
    }
}
