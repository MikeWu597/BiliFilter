import SwiftUI

@main
struct BiliFilterApp: App {
    @StateObject private var themeManager = ThemeManager.shared

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(themeManager)
                .preferredColorScheme(themeManager.themeMode == .followSystem ? nil :
                    themeManager.themeMode == .dark ? .dark : .light)
                .tint(themeManager.accentColor)
                .onReceive(NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)) { _ in
                    themeManager.loadFromStorage()
                }
        }
    }
}
