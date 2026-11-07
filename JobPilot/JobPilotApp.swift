import SwiftUI
import SwiftData

@main
struct JobPilotApp: App {
    var body: some Scene {
        WindowGroup {
            RootView()
        }
        .modelContainer(for: [Vacancy.self, StageEvent.self, Contact.self, FollowUp.self, Interview.self])
    }
}
