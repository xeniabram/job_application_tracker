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
    var location: String
    var meetLink: String
    var preparationNotes: String
    
    // Relationship back to the parent application
    var application: ApplicationItem?

    init(
        title: String = "",
        date: Date = .now,
        location: String = "",
        meetLink: String = "",
        preparationNotes: String = ""
    ) {
        self.title = title
        self.date = date
        self.location = location
        self.meetLink = meetLink
        self.preparationNotes = preparationNotes
    }
}
