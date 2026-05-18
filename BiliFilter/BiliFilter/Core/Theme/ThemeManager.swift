import SwiftUI
import Combine

// MARK: - 主题模式
enum AppThemeMode: Int, CaseIterable {
    case followSystem = 0
    case light = 1
    case dark = 2

    var displayName: String {
        switch self {
        case .followSystem: return "跟随系统"
        case .light: return "浅色"
        case .dark: return "深色"
        }
    }
}

// MARK: - UI预设
enum UiPreset: Int, CaseIterable {
    case ios = 0
    case material = 1
    case miuix = 2

    var displayName: String {
        switch self {
        case .ios: return "iOS"
        case .material: return "Material"
        case .miuix: return "Miuix"
        }
    }
}

// MARK: - 字体大小预设
enum AppFontSizePreset: Int, CaseIterable {
    case small = 0
    case `default` = 1
    case large = 2

    var scaleFactor: Double {
        switch self {
        case .small: return 0.85
        case .default: return 1.0
        case .large: return 1.15
        }
    }
}

// MARK: - ThemeManager
@MainActor
final class ThemeManager: ObservableObject {
    static let shared = ThemeManager()

    @Published var themeMode: AppThemeMode = .followSystem
    @Published var uiPreset: UiPreset = .ios
    @Published var themeColorIndex: Int = 0
    @Published var dynamicColorEnabled: Bool = true
    @Published var amoledDarkTheme: Bool = false
    @Published var fontSizePreset: AppFontSizePreset = .default

    private let defaults = UserDefaults.standard

    private init() {
        loadFromStorage()
    }

    var accentColor: Color {
        ThemeColors[safe: themeColorIndex] ?? iOSBlue
    }

    var isDarkMode: Bool {
        switch themeMode {
        case .followSystem:
            return UITraitCollection.current.userInterfaceStyle == .dark
        case .light:
            return false
        case .dark:
            return true
        }
    }

    var backgroundColor: Color {
        isDarkMode ? DarkBackground : BiliBackground
    }

    var surfaceColor: Color {
        isDarkMode ? DarkSurface : SurfaceCard
    }

    var primaryTextColor: Color {
        isDarkMode ? TextPrimaryDark : TextPrimary
    }

    var secondaryTextColor: Color {
        isDarkMode ? TextSecondaryDark : TextSecondary
    }

    var tertiaryTextColor: Color {
        isDarkMode ? TextTertiaryDark : TextTertiary
    }

    var systemGrayBackground: Color {
        isDarkMode ? iOSSystemGray6Dark : iOSSystemGray6
    }

    func loadFromStorage() {
        themeMode = AppThemeMode(rawValue: defaults.integer(forKey: "theme_mode")) ?? .followSystem
        uiPreset = UiPreset(rawValue: defaults.integer(forKey: "ui_preset")) ?? .ios
        themeColorIndex = defaults.integer(forKey: "theme_color_index")
        dynamicColorEnabled = defaults.object(forKey: "dynamic_color_enabled") as? Bool ?? true
        amoledDarkTheme = defaults.bool(forKey: "amoled_dark_theme")
        let fontSizeRaw = defaults.integer(forKey: "font_size_preset")
        fontSizePreset = AppFontSizePreset(rawValue: fontSizeRaw == 0 ? 1 : fontSizeRaw) ?? .default
    }

    func save() {
        defaults.set(themeMode.rawValue, forKey: "theme_mode")
        defaults.set(uiPreset.rawValue, forKey: "ui_preset")
        defaults.set(themeColorIndex, forKey: "theme_color_index")
        defaults.set(dynamicColorEnabled, forKey: "dynamic_color_enabled")
        defaults.set(amoledDarkTheme, forKey: "amoled_dark_theme")
        defaults.set(fontSizePreset.rawValue, forKey: "font_size_preset")
    }
}

extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
