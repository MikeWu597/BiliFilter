import SwiftUI
import Combine

// MARK: - 视频过滤设置
final class FilterSettings: ObservableObject {
    static let shared = FilterSettings()
    private let defaults = UserDefaults.standard

    @Published var durationMin: Double {
        didSet { defaults.set(durationMin, forKey: "filter_duration_min") }
    }
    @Published var durationMax: Double {
        didSet { defaults.set(durationMax, forKey: "filter_duration_max") }
    }
    @Published var durationEnabled: Bool {
        didSet { defaults.set(durationEnabled, forKey: "filter_duration_enabled") }
    }

    @Published var titleMin: Int {
        didSet { defaults.set(titleMin, forKey: "filter_title_min") }
    }
    @Published var titleMax: Int {
        didSet { defaults.set(titleMax, forKey: "filter_title_max") }
    }
    @Published var titleEnabled: Bool {
        didSet { defaults.set(titleEnabled, forKey: "filter_title_enabled") }
    }

    private init() {
        durationMin = defaults.object(forKey: "filter_duration_min") as? Double ?? 0
        durationMax = defaults.object(forKey: "filter_duration_max") as? Double ?? 3600
        durationEnabled = defaults.object(forKey: "filter_duration_enabled") as? Bool ?? false
        titleMin = defaults.object(forKey: "filter_title_min") as? Int ?? 0
        titleMax = defaults.object(forKey: "filter_title_max") as? Int ?? 100
        titleEnabled = defaults.object(forKey: "filter_title_enabled") as? Bool ?? false
    }

    func checkVideo(duration: Int, title: String) -> String? {
        if durationEnabled {
            let d = Double(duration)
            if d < durationMin { return "时长过短(< \(Int(durationMin))s)" }
            if d > durationMax { return "时长过长(> \(Int(durationMax))s)" }
        }
        if titleEnabled {
            let c = title.count
            if c < titleMin { return "标题过短(< \(titleMin)字)" }
            if c > titleMax { return "标题过长(> \(titleMax)字)" }
        }
        return nil
    }
}

// MARK: - 视频过滤设置页面
struct FilterSettingsView: View {
    @StateObject private var settings = FilterSettings.shared
    @EnvironmentObject private var themeManager: ThemeManager

    var body: some View {
        Form {
            Section {
                Toggle("启用时长过滤", isOn: $settings.durationEnabled)
                if settings.durationEnabled {
                    HStack {
                        Text("最短")
                        Slider(value: $settings.durationMin, in: 0...1800, step: 30)
                        Text("\(Int(settings.durationMin))s").font(.caption).foregroundColor(.secondary).frame(width: 50)
                    }
                    HStack {
                        Text("最长")
                        Slider(value: $settings.durationMax, in: 60...7200, step: 60)
                        Text("\(Int(settings.durationMax))s").font(.caption).foregroundColor(.secondary).frame(width: 50)
                    }
                }
            } header: {
                Text("视频时长限制")
            } footer: {
                Text("屏蔽时长不在范围内的视频")
            }

            Section {
                Toggle("启用标题字数过滤", isOn: $settings.titleEnabled)
                if settings.titleEnabled {
                    HStack {
                        Text("最少")
                        Slider(value: .init(get: { Double(settings.titleMin) }, set: { settings.titleMin = Int($0) }), in: 0...50, step: 1)
                        Text("\(settings.titleMin)字").font(.caption).foregroundColor(.secondary).frame(width: 40)
                    }
                    HStack {
                        Text("最多")
                        Slider(value: .init(get: { Double(settings.titleMax) }, set: { settings.titleMax = Int($0) }), in: 10...200, step: 5)
                        Text("\(settings.titleMax)字").font(.caption).foregroundColor(.secondary).frame(width: 40)
                    }
                }
            } header: {
                Text("标题长度限制")
            } footer: {
                Text("屏蔽标题字数不在范围内的视频")
            }
        }
        .navigationTitle("视频过滤")
        .navigationBarTitleDisplayMode(.inline)
        .tint(themeManager.accentColor)
    }
}
