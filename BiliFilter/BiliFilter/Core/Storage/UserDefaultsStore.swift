import Foundation

// MARK: - UserDefaults偏好存储封装
final class UserDefaultsStore {
    static let shared = UserDefaultsStore()
    private let defaults = UserDefaults.standard

    private init() {}

    // MARK: - 通用存取
    func get<T>(_ key: String, default defaultValue: T) -> T {
        return defaults.object(forKey: key) as? T ?? defaultValue
    }

    func set<T>(_ value: T, forKey key: String) {
        defaults.set(value, forKey: key)
    }

    func remove(_ key: String) {
        defaults.removeObject(forKey: key)
    }

    // MARK: - 首页设置
    var bottomBarFloating: Bool {
        get { get("bottom_bar_floating", default: true) }
        set { set(newValue, forKey: "bottom_bar_floating") }
    }

    var liquidGlassEnabled: Bool {
        get { get("liquid_glass_enabled", default: true) }
        set { set(newValue, forKey: "liquid_glass_enabled") }
    }

    var topBarBlurEnabled: Bool {
        get { get("top_bar_blur_enabled", default: true) }
        set { set(newValue, forKey: "top_bar_blur_enabled") }
    }

    var homeAutoRefreshEnabled: Bool {
        get { get("home_auto_refresh_enabled", default: true) }
        set { set(newValue, forKey: "home_auto_refresh_enabled") }
    }

    var homeGridColumns: Int {
        get { get("home_grid_columns", default: 2) }
        set { set(newValue, forKey: "home_grid_columns") }
    }

    // MARK: - 播放设置
    var defaultPlaybackQuality: Int {
        get { get("default_playback_quality", default: 112) } // 1080P高码率
        set { set(newValue, forKey: "default_playback_quality") }
    }

    var defaultPlaybackSpeed: Double {
        get { get("default_playback_speed", default: 1.0) }
        set { set(newValue, forKey: "default_playback_speed") }
    }

    var danmakuEnabled: Bool {
        get { get("danmaku_enabled", default: true) }
        set { set(newValue, forKey: "danmaku_enabled") }
    }

    var danmakuAlpha: Double {
        get { get("danmaku_alpha", default: 0.8) }
        set { set(newValue, forKey: "danmaku_alpha") }
    }

    var danmakuFontScale: Double {
        get { get("danmaku_font_scale", default: 1.0) }
        set { set(newValue, forKey: "danmaku_font_scale") }
    }

    var stopPlaybackOnExit: Bool {
        get { get("stop_playback_on_exit", default: false) }
        set { set(newValue, forKey: "stop_playback_on_exit") }
    }

    var backgroundPlaybackEnabled: Bool {
        get { get("background_playback_enabled", default: true) }
        set { set(newValue, forKey: "background_playback_enabled") }
    }

    var pipEnabled: Bool {
        get { get("pip_enabled", default: true) }
        set { set(newValue, forKey: "pip_enabled") }
    }

    // MARK: - 外观设置
    var autoCheckUpdateEnabled: Bool {
        get { get("auto_check_update_enabled", default: true) }
        set { set(newValue, forKey: "auto_check_update_enabled") }
    }

    var privacyModeEnabled: Bool {
        get { get("privacy_mode_enabled", default: false) }
        set { set(newValue, forKey: "privacy_mode_enabled") }
    }

    // MARK: - 插件设置
    var sponsorBlockEnabled: Bool {
        get { get("sponsor_block_enabled", default: true) }
        set { set(newValue, forKey: "sponsor_block_enabled") }
    }

    var adFilterEnabled: Bool {
        get { get("ad_filter_enabled", default: true) }
        set { set(newValue, forKey: "ad_filter_enabled") }
    }

    var eyeProtectionEnabled: Bool {
        get { get("eye_protection_enabled", default: false) }
        set { set(newValue, forKey: "eye_protection_enabled") }
    }

    var todayWatchEnabled: Bool {
        get { get("today_watch_enabled", default: true) }
        set { set(newValue, forKey: "today_watch_enabled") }
    }

    var cdnRegionOptimized: Bool {
        get { get("cdn_region_optimized", default: true) }
        set { set(newValue, forKey: "cdn_region_optimized") }
    }
}
