import SwiftUI

@main
struct BiliFilterApp: App {
    @StateObject private var themeManager = ThemeManager.shared
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

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

final class AppDelegate: NSObject, UIApplicationDelegate {
    static var isFullscreen = false

    func application(_ application: UIApplication,
                     supportedInterfaceOrientationsFor window: UIWindow?) -> UIInterfaceOrientationMask {
        return AppDelegate.isFullscreen ? .allButUpsideDown : .portrait
    }
}
