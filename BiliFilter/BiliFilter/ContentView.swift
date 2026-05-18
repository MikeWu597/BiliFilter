import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var themeManager: ThemeManager

    var body: some View {
        ZStack {
            themeManager.backgroundColor
                .ignoresSafeArea()

            AppNavigation()
        }
    }
}

#Preview {
    ContentView()
        .environmentObject(ThemeManager.shared)
}
