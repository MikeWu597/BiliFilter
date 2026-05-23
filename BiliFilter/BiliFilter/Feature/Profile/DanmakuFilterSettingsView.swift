import SwiftUI
import Combine

// MARK: - 弹幕过滤设置
final class DanmakuFilterSettings: ObservableObject {
    static let shared = DanmakuFilterSettings()
    private let defaults = UserDefaults.standard

    @Published var keywords: [String] {
        didSet { defaults.set(keywords.joined(separator: "\n"), forKey: "dmf_keywords") }
    }
    @Published var enabled: Bool {
        didSet { defaults.set(enabled, forKey: "dmf_enabled") }
    }

    private init() {
        let kw = defaults.string(forKey: "dmf_keywords") ?? ""
        keywords = kw.isEmpty ? [] : kw.components(separatedBy: "\n")
        enabled = defaults.object(forKey: "dmf_enabled") as? Bool ?? false
    }

    func shouldFilter(content: String) -> Bool {
        guard enabled else { return false }
        for kw in keywords where !kw.isEmpty {
            if content.localizedCaseInsensitiveContains(kw) { return true }
        }
        return false
    }
}

struct DanmakuFilterSettingsView: View {
    @StateObject private var settings = DanmakuFilterSettings.shared
    @EnvironmentObject private var themeManager: ThemeManager
    @State private var newKeyword = ""

    var body: some View {
        Form {
            Section {
                Toggle("启用弹幕关键词过滤", isOn: $settings.enabled)
                if settings.enabled {
                    HStack {
                        TextField("输入关键词", text: $newKeyword)
                            .textFieldStyle(.roundedBorder)
                        Button("添加") {
                            let kw = newKeyword.trimmingCharacters(in: .whitespaces)
                            if !kw.isEmpty, !settings.keywords.contains(kw) {
                                settings.keywords.append(kw)
                            }
                            newKeyword = ""
                        }
                        .font(.caption)
                        .disabled(newKeyword.trimmingCharacters(in: .whitespaces).isEmpty)
                    }
                    ForEach(settings.keywords.indices, id: \.self) { i in
                        HStack {
                            Text(settings.keywords[i]).font(.caption)
                            Spacer()
                            Button { settings.keywords.remove(at: i) } label: {
                                Image(systemName: "xmark.circle.fill").foregroundColor(.secondary)
                            }
                        }
                    }
                }
            } footer: {
                Text("模糊匹配，弹幕内容包含任一关键词即屏蔽")
            }
        }
        .navigationTitle("弹幕过滤")
        .navigationBarTitleDisplayMode(.inline)
        .tint(themeManager.accentColor)
    }
}
