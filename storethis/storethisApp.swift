import SwiftUI

@main
struct storethisApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        Settings {
            SettingsView(authService: appDelegate.authService, profileManager: appDelegate.profileManager)
        }
    }
}
