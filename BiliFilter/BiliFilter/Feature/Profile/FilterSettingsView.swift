import SwiftUI
import Combine

// MARK: - 首页出现次数追踪
final class AppearCountTracker {
    static let shared = AppearCountTracker()
    private let defaults = UserDefaults.standard
    private let key = "appear_counts"

    private var counts: [String: Int] = [:]

    private init() {
        if let data = defaults.data(forKey: key),
           let saved = try? JSONDecoder().decode([String: Int].self, from: data) {
            counts = saved
        }
    }

    private func save() {
        if let data = try? JSONEncoder().encode(counts) {
            defaults.set(data, forKey: key)
        }
    }

    /// 记录视频在首页出现，返回出现次数
    func recordAppear(bvid: String) -> Int {
        let count = (counts[bvid] ?? 0) + 1
        counts[bvid] = count
        // 定期清理：保留最近10000条，防止无限增长
        if counts.count > 10000 {
            let sorted = counts.sorted { $0.value > $1.value }
            counts = sorted.prefix(5000).reduce(into: [:]) { $0[$1.key] = $1.value }
        }
        save()
        return count
    }

    func getCount(for bvid: String) -> Int {
        counts[bvid] ?? 0
    }

    func reset() {
        counts.removeAll()
        save()
    }

    /// 导入/导出用
    var rawCounts: [String: Int] { counts }
    func importCounts(_ data: [String: Int]) {
        counts = data
        save()
    }
}

// MARK: - 视频过滤设置
final class FilterSettings: ObservableObject {
    static let shared = FilterSettings()
    private let defaults = UserDefaults.standard

    // 时长过滤
    @Published var durationMin: Double {
        didSet { defaults.set(durationMin, forKey: "filter_duration_min") }
    }
    @Published var durationMax: Double {
        didSet { defaults.set(durationMax, forKey: "filter_duration_max") }
    }
    @Published var durationEnabled: Bool {
        didSet { defaults.set(durationEnabled, forKey: "filter_duration_enabled") }
    }

    // 标题字数过滤
    @Published var titleMin: Int {
        didSet { defaults.set(titleMin, forKey: "filter_title_min") }
    }
    @Published var titleMax: Int {
        didSet { defaults.set(titleMax, forKey: "filter_title_max") }
    }
    @Published var titleEnabled: Bool {
        didSet { defaults.set(titleEnabled, forKey: "filter_title_enabled") }
    }

    // 标题关键词过滤
    @Published var keywordFilterEnabled: Bool {
        didSet { defaults.set(keywordFilterEnabled, forKey: "filter_keyword_enabled") }
    }
    @Published var titleKeywords: [String] {
        didSet { defaults.set(titleKeywords.joined(separator: "\n"), forKey: "filter_title_keywords") }
    }

    // 首页出现次数过滤
    @Published var appearCountEnabled: Bool {
        didSet { defaults.set(appearCountEnabled, forKey: "filter_appear_enabled") }
    }
    @Published var maxAppearCount: Int {
        didSet { defaults.set(maxAppearCount, forKey: "filter_appear_max") }
    }

    // 标记用户/视频过滤
    @Published var taggedUserFilterEnabled: Bool {
        didSet { defaults.set(taggedUserFilterEnabled, forKey: "filter_tagged_user") }
    }
    @Published var taggedVideoFilterEnabled: Bool {
        didSet { defaults.set(taggedVideoFilterEnabled, forKey: "filter_tagged_video") }
    }

    private init() {
        durationMin = defaults.object(forKey: "filter_duration_min") as? Double ?? 0
        durationMax = defaults.object(forKey: "filter_duration_max") as? Double ?? 3600
        durationEnabled = defaults.object(forKey: "filter_duration_enabled") as? Bool ?? false
        titleMin = defaults.object(forKey: "filter_title_min") as? Int ?? 0
        titleMax = defaults.object(forKey: "filter_title_max") as? Int ?? 100
        titleEnabled = defaults.object(forKey: "filter_title_enabled") as? Bool ?? false
        keywordFilterEnabled = defaults.object(forKey: "filter_keyword_enabled") as? Bool ?? false
        let kw = defaults.string(forKey: "filter_title_keywords") ?? ""
        titleKeywords = kw.isEmpty ? [] : kw.components(separatedBy: "\n")
        appearCountEnabled = defaults.object(forKey: "filter_appear_enabled") as? Bool ?? false
        maxAppearCount = defaults.object(forKey: "filter_appear_max") as? Int ?? 3
        taggedUserFilterEnabled = defaults.object(forKey: "filter_tagged_user") as? Bool ?? false
        taggedVideoFilterEnabled = defaults.object(forKey: "filter_tagged_video") as? Bool ?? false
    }

    func checkVideo(duration: Int, title: String, ownerMid: Int64?, ownerName: String = "", bvid: String = "", coverUrl: String = "", recordAppear: Bool = true) -> String? {
        // 0. 标记用户过滤（不记录日志）
        if taggedUserFilterEnabled, let mid = ownerMid {
            let tags = UserTagManager.shared.tagsForUser(mid: mid)
            if !tags.isEmpty {
                return "标记用户「\(tags.first!.name)」\(tags.count > 1 ? "等\(tags.count)个标记" : "")"
            }
        }
        // 0. 标记视频过滤（不记录日志）
        if taggedVideoFilterEnabled, !bvid.isEmpty {
            let tags = VideoTagManager.shared.tags.filter { $0.bvids.contains(bvid) }
            if !tags.isEmpty {
                return "标记视频「\(tags.first!.name)」\(tags.count > 1 ? "等\(tags.count)个标记" : "")"
            }
        }

        // 1. UID过滤
        if let mid = ownerMid, let reason = UIDFilterSettings.shared.check(mid: mid) {
            FilteredLog.shared.logUID(mid: mid, uname: ownerName, level: nil, sign: "", reason: reason)
            return reason
        }

        // 2. 时长过滤
        if durationEnabled {
            let d = Double(duration)
            if d < durationMin {
                let reason = "时长过短(< \(Int(durationMin))s)"
                FilteredLog.shared.logVideo(bvid: bvid, title: title, duration: duration, ownerName: ownerName, ownerMid: ownerMid ?? 0, coverUrl: coverUrl, reason: reason)
                return reason
            }
            if d > durationMax {
                let reason = "时长过长(> \(Int(durationMax))s)"
                FilteredLog.shared.logVideo(bvid: bvid, title: title, duration: duration, ownerName: ownerName, ownerMid: ownerMid ?? 0, coverUrl: coverUrl, reason: reason)
                return reason
            }
        }

        // 3. 标题字数过滤
        if titleEnabled {
            let c = title.count
            if c < titleMin {
                let reason = "标题过短(< \(titleMin)字)"
                FilteredLog.shared.logVideo(bvid: bvid, title: title, duration: duration, ownerName: ownerName, ownerMid: ownerMid ?? 0, coverUrl: coverUrl, reason: reason)
                return reason
            }
            if c > titleMax {
                let reason = "标题过长(> \(titleMax)字)"
                FilteredLog.shared.logVideo(bvid: bvid, title: title, duration: duration, ownerName: ownerName, ownerMid: ownerMid ?? 0, coverUrl: coverUrl, reason: reason)
                return reason
            }
        }

        // 4. 标题关键词过滤
        if keywordFilterEnabled {
            for kw in titleKeywords where !kw.isEmpty {
                if title.localizedCaseInsensitiveContains(kw) {
                    let reason = "标题关键词「\(kw)」"
                    FilteredLog.shared.logVideo(bvid: bvid, title: title, duration: duration, ownerName: ownerName, ownerMid: ownerMid ?? 0, coverUrl: coverUrl, reason: reason)
                    return reason
                }
            }
        }

        // 5. 首页出现次数过滤（仅在首页记录，搜索不计入）
        if appearCountEnabled, !bvid.isEmpty {
            let count = recordAppear
                ? AppearCountTracker.shared.recordAppear(bvid: bvid)
                : AppearCountTracker.shared.getCount(for: bvid)
            if count > maxAppearCount {
                let reason = "首页出现\(count)次(> \(maxAppearCount))"
                FilteredLog.shared.logVideo(bvid: bvid, title: title, duration: duration, ownerName: ownerName, ownerMid: ownerMid ?? 0, coverUrl: coverUrl, reason: reason)
                return reason
            }
        }

        return nil
    }
}

// MARK: - 视频过滤设置页面
struct FilterSettingsView: View {
    @StateObject private var settings = FilterSettings.shared
    @EnvironmentObject private var themeManager: ThemeManager
    @State private var newKeyword = ""

    var body: some View {
        Form {
            // 时长过滤
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
            } header: { Text("视频时长限制") }
              footer: { Text("屏蔽时长不在范围内的视频") }

            // 标题字数过滤
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
            } header: { Text("标题长度限制") }
              footer: { Text("屏蔽标题字数不在范围内的视频") }

            // 标题关键词过滤
            Section {
                Toggle("启用标题关键词过滤", isOn: $settings.keywordFilterEnabled)
                if settings.keywordFilterEnabled {
                    HStack {
                        TextField("输入关键词", text: $newKeyword)
                            .textFieldStyle(.roundedBorder)
                        Button("添加") {
                            let kw = newKeyword.trimmingCharacters(in: .whitespaces)
                            if !kw.isEmpty, !settings.titleKeywords.contains(kw) {
                                settings.titleKeywords.append(kw)
                            }
                            newKeyword = ""
                        }
                        .font(.caption)
                        .disabled(newKeyword.trimmingCharacters(in: .whitespaces).isEmpty)
                    }
                    if !settings.titleKeywords.isEmpty {
                        ForEach(settings.titleKeywords.indices, id: \.self) { i in
                            HStack {
                                Text(settings.titleKeywords[i]).font(.caption)
                                Spacer()
                                Button { settings.titleKeywords.remove(at: i) } label: {
                                    Image(systemName: "xmark.circle.fill").foregroundColor(.secondary)
                                }
                            }
                        }
                    }
                }
            } header: { Text("标题关键词") }
              footer: { Text("模糊匹配，标题包含任一关键词即屏蔽。过滤时自动记录到日志") }

            // 首页出现次数过滤
            Section {
                Toggle("启用首页出现次数过滤", isOn: $settings.appearCountEnabled)
                if settings.appearCountEnabled {
                    HStack {
                        Text("最多出现")
                        Slider(value: .init(get: { Double(settings.maxAppearCount) }, set: { settings.maxAppearCount = Int($0) }), in: 1...20, step: 1)
                        Text("\(settings.maxAppearCount)次").font(.caption).foregroundColor(.secondary).frame(width: 40)
                    }
                    if settings.appearCountEnabled {
                        Button("重置出现次数") {
                            AppearCountTracker.shared.reset()
                        }
                        .font(.caption)
                        .foregroundColor(.red)
                    }
                }
            } header: { Text("首页出现次数") }
              footer: { Text("同一视频（相同bvid）在首页出现超过设定次数后自动屏蔽。点击重置可清空所有计数") }

        }
        .navigationTitle("视频过滤")
        .navigationBarTitleDisplayMode(.inline)
        .tint(themeManager.accentColor)
    }
}
