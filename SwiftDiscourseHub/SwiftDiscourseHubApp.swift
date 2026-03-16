import SwiftUI
import SwiftData

@main
struct SwiftDiscourseHubApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(for: DiscourseSite.self)
    }
}
