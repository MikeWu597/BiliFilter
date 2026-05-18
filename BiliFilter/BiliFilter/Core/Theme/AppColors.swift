import SwiftUI

// MARK: - B站品牌色
let BiliPink = Color(hex: 0xFA7298)
let BiliPinkDim = Color(hex: 0xE6688C)
let BiliPinkLight = Color(hex: 0xFFEBF0)

// MARK: - iOS系统色
let iOSBlue = Color(hex: 0x007AFF)
let iOSPink = Color(hex: 0xFF2D55)
let iOSYellow = Color(hex: 0xFFD60A)
let iOSOrange = Color(hex: 0xFFFF9500)
let iOSGreen = Color(hex: 0x34C759)
let iOSTeal = Color(hex: 0x5AC8FA)
let iOSPurple = Color(hex: 0xAF52DE)
let iOSRed = Color(hex: 0xFFFF3B30)
let iOSCoral = Color(hex: 0xFFFF6B6B)
let iOSLightBlue = Color(hex: 0xFF64D2FF)

// MARK: - iOS灰度色阶
let iOSSystemGray = Color(hex: 0x8E8E93)
let iOSSystemGray2 = Color(hex: 0xAEAEB2)
let iOSSystemGray3 = Color(hex: 0xC7C7CC)
let iOSSystemGray4 = Color(hex: 0xD1D1D6)
let iOSSystemGray5 = Color(hex: 0xE5E5EA)
let iOSSystemGray6 = Color(hex: 0xF2F2F7)

// MARK: - 深色模式灰度
let iOSSystemGrayDark = Color(hex: 0x8E8E93)
let iOSSystemGray2Dark = Color(hex: 0x636366)
let iOSSystemGray3Dark = Color(hex: 0x48484A)
let iOSSystemGray4Dark = Color(hex: 0x3A3A3C)
let iOSSystemGray5Dark = Color(hex: 0x2C2C2E)
let iOSSystemGray6Dark = Color(hex: 0x1C1C1E)

// MARK: - 背景色
let BiliBackground = Color(hex: 0xF1F2F3)
let SurfaceCard = Color.white

// MARK: - 文字颜色
let TextPrimary = Color(hex: 0x18191C)
let TextSecondary = Color(hex: 0x61666D)
let TextTertiary = Color(hex: 0x9499A0)

// MARK: - 深色模式
let DarkBackground = Color(hex: 0x0D0D0D)
let DarkSurface = Color(hex: 0x1A1A1A)
let DarkSurfaceVariant = Color(hex: 0x262626)
let DarkSurfaceElevated = Color(hex: 0x2D2D2D)
let BiliPinkDark = Color(hex: 0xFFFF85A2)
let TextPrimaryDark = Color(hex: 0xE8E8E8)
let TextSecondaryDark = Color(hex: 0xB0B0B0)
let TextTertiaryDark = Color(hex: 0x707070)

// MARK: - 操作按钮色 (深色)
let ActionLikeDark = Color(hex: 0xFFFF85A2)
let ActionCoinDark = Color(hex: 0xFFFFCA28)
let ActionFavoriteDark = Color(hex: 0xFFFFD54F)
let ActionShareDark = Color(hex: 0xFF64B5F6)
let ActionCommentDark = Color(hex: 0xFF4DD0E1)

// MARK: - 预设主题色
let ThemeColors: [Color] = [
    Color(hex: 0x007AFF), // 0: 经典蓝
    Color(hex: 0xFA7298), // 1: 樱花粉
    Color(hex: 0x00A1D6), // 2: 天空蓝
    Color(hex: 0x34C759), // 3: 薄荷绿
    Color(hex: 0xAF52DE), // 4: 梦幻紫
    Color(hex: 0xFF5722), // 5: 活力橙
    Color(hex: 0x607D8B), // 6: 静谧蓝灰
    Color(hex: 0xFFFF6B6B), // 7: 珊瑚红
    Color(hex: 0x5856D6), // 8: 靛蓝
    Color(hex: 0x00BFA5), // 9: 翡翠青
    Color(hex: 0xF44336), // 10: 炽焰红
    Color(hex: 0xE91E63), // 11: 绯樱粉
    Color(hex: 0x9C27B0), // 12: 星云紫
    Color(hex: 0x673AB7), // 13: 暮影紫
    Color(hex: 0x3F51B5), // 14: 靛空蓝
    Color(hex: 0x2196F3), // 15: 晴空蓝
    Color(hex: 0x00BCD4), // 16: 极光青
    Color(hex: 0x009688), // 17: 海沫绿
    Color(hex: 0x4CAF50), // 18: 新叶绿
    Color(hex: 0xFFFFEB3B), // 19: 日光黄
    Color(hex: 0xFFFFC107), // 20: 琥珀金
    Color(hex: 0xFFFF9800), // 21: 暖阳橙
    Color(hex: 0x795548), // 22: 可可棕
    Color(hex: 0x607D8F), // 23: 雾霭蓝灰
    Color(hex: 0xFFFF9CA8), // 24: 晨曦粉
]

let ThemeColorNames: [String] = [
    "经典蓝", "樱花粉", "天空蓝", "薄荷绿", "梦幻紫",
    "活力橙", "静谧蓝灰", "珊瑚红", "靛蓝", "翡翠青",
    "炽焰红", "绯樱粉", "星云紫", "暮影紫", "靛空蓝",
    "晴空蓝", "极光青", "海沫绿", "新叶绿", "日光黄",
    "琥珀金", "暖阳橙", "可可棕", "雾霭蓝灰", "晨曦粉"
]

// MARK: - Color Hex Extension
extension Color {
    init(hex: UInt, alpha: Double = 1.0) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255.0,
            green: Double((hex >> 8) & 0xFF) / 255.0,
            blue: Double(hex & 0xFF) / 255.0,
            opacity: alpha
        )
    }
}
