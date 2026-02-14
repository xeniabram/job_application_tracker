import Foundation
import SwiftData

@Model
final class TimelineItem {
    var calendarEventID: String // The anchor to the system calendar
    var preparationNotes: String // App-specific data
    var application: ApplicationItem?
    
    /// Stores the reminder offsets (in seconds) that were added by the app.
    /// Only stores reminders that didn't already exist in the calendar.
    /// Used to selectively remove app-added reminders when unlinking.
    var appAddedReminderOffsets: [TimeInterval] = []
    
    init(calendarEventID: String, preparationNotes: String = "") {
        self.calendarEventID = calendarEventID
        self.preparationNotes = preparationNotes
    }
}
