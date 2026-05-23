import SwiftUI
import Combine

// MARK: - UID过滤设置
final class UIDFilterSettings: ObservableObject {
    static let shared = UIDFilterSettings()
    private let defaults = UserDefaults.standard

    @Published var maxUIDLength: Int {
        didSet { defaults.set(maxUIDLength, forKey: "uid_max_len") }
    }
    @Published var enabled: Bool {
        didSet { defaults.set(enabled, forKey: "uid_enabled") }
    }

    private init() {
        maxUIDLength = defaults.object(forKey: "uid_max_len") as? Int ?? 12
        enabled = defaults.object(forKey: "uid_enabled") as? Bool ?? false
    }

    func check(mid: Int64) -> String? {
        guard enabled else { return nil }
        let len = String(mid).count
        if len > maxUIDLength {
            return "UID过长(\(len)>\(maxUIDLength))"
        }
        return nil
    }
}

// MARK: - UID过滤设置页面
struct UIDFilterSettingsView: View {
    @StateObject private var settings = UIDFilterSettings.shared
    @EnvironmentObject private var themeManager: ThemeManager

    var body: some View {
        Form {
            Section {
                Toggle("启用UID长度过滤", isOn: $settings.enabled)
                if settings.enabled {
                    HStack {
                        Text("UID最长")
                        Slider(value: .init(get: { Double(settings.maxUIDLength) }, set: { settings.maxUIDLength = Int($0) }), in: 5...20, step: 1)
                        Text("\(settings.maxUIDLength)位").font(.caption).foregroundColor(.secondary).frame(width: 40)
                    }
                }
            } header: {
                Text("UID长度限制")
            } footer: {
                Text("屏蔽UID超过设定长度的用户。Ubi\u{00B7}包括评论用户、UP主等")
            }
        }
        .navigationTitle("用户过滤")
        .navigationBarTitleDisplayMode(.inline)
        .tint(themeManager.accentColor)
    }
}
