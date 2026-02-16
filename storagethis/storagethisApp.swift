import SwiftUI

@main
struct storagethisApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        Settings {
            SettingsView(authService: appDelegate.authService)
        }
    }
}
