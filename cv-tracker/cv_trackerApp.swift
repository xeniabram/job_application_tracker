import SwiftUI
import SwiftData

@main
struct cv_trackerApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        // Simplified way to register your specific model
        .modelContainer(for: ApplicationItem.self)
    }
}
