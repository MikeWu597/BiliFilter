import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var themeManager: ThemeManager

    var body: some View {
        AppNavigation()
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(themeManager.backgroundColor.ignoresSafeArea())
    }
}

#Preview {
    ContentView()
        .environmentObject(ThemeManager.shared)
}
