import SwiftData
import SwiftUI

#if os(macOS)
class AppDelegate: NSObject, NSApplicationDelegate {
    func application(_ application: NSApplication, open urls: [URL]) {
        guard let url = urls.first else { return }
        Task { @MainActor in
            await SwiftDiscourseHubApp.authCoordinator.handleCallback(url: url)
        }
    }
}
#endif

@main
struct SwiftDiscourseHubApp: App {
    @MainActor static let toastManager = ToastManager()
    @MainActor static let authCoordinator = AuthCoordinator()
    @MainActor static let sharedAPIClient = DiscourseAPIClient(
        credentialProvider: AuthCoordinatorCredentialProvider(coordinator: authCoordinator)
    )

    #if os(macOS)
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    #endif

    var body: some Scene {
        WindowGroup {
            ContentView()
                .overlay { ToastOverlay() }
                .environment(Self.toastManager)
                .environment(Self.authCoordinator)
                .environment(\.apiClient, Self.sharedAPIClient)
                #if os(iOS)
                .onOpenURL { url in
                    Task { await Self.authCoordinator.handleCallback(url: url) }
                }
                #endif
        }
        #if os(macOS)
        .handlesExternalEvents(matching: [])
        #endif
        .modelContainer(for: DiscourseSite.self)
        #if os(macOS)
        .windowStyle(.titleBar)
        .windowToolbarStyle(.unified)
        #endif
    }
}
