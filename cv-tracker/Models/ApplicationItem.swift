import Foundation
import SwiftData

// 0. Application status enum
enum ApplicationStatus: String, Codable, CaseIterable {
    case applied = "Applied"
    case interviewing = "Interviewing"
    case offer = "Offer"
    case rejected = "Rejected"
    case archived = "Archived"
}

// 1. The Data Model
@Model
final class ApplicationItem {
    var id: UUID
    var dateApplied: Date
    var companyName: String
    var position: String
    var status: ApplicationStatus
    
    var cvUrl: URL?
    var cvBookmark: Data?
    
    var consentsText: String
    var consentActionRequired: Bool
    var consentInterval: Int
    var reminderID: String?
    
    @Relationship(deleteRule: .cascade) var timeline: [TimelineItem]? = []
    
    
    
    init(companyName: String = "", position: String = "", date: Date = Date()) {
        self.id = UUID()
        self.companyName = companyName
        self.position = position
        self.dateApplied = date
        self.status = .applied
        self.consentsText = ""
        self.consentActionRequired = false
        self.consentInterval = 0
        self.reminderID = nil
    }
}
