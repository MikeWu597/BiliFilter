import SwiftUI
import Combine

// MARK: - 评论区过滤设置
final class CommentFilterSettings: ObservableObject {
    static let shared = CommentFilterSettings()
    private let defaults = UserDefaults.standard

    // 等级过滤：多选 Lv0-Lv6，存为逗号分隔字符串 "0,1,2"
    private static let allLevels = (0...6).map { $0 }
    @Published var selectedLevels: Set<Int> {
        didSet {
            defaults.set(selectedLevels.sorted().map(String.init).joined(separator: ","), forKey: "cf_levels")
        }
    }
    @Published var levelFilterEnabled: Bool {
        didSet { defaults.set(levelFilterEnabled, forKey: "cf_level_enabled") }
    }

    // 关键词过滤
    @Published var keywords: [String] {
        didSet { defaults.set(keywords.joined(separator: "\n"), forKey: "cf_keywords") }
    }
    @Published var keywordFilterEnabled: Bool {
        didSet { defaults.set(keywordFilterEnabled, forKey: "cf_keyword_enabled") }
    }

    // 用户名过滤
    @Published var nameKeywords: [String] {
        didSet { defaults.set(nameKeywords.joined(separator: "\n"), forKey: "cf_name_keywords") }
    }
    @Published var nameFilterEnabled: Bool {
        didSet { defaults.set(nameFilterEnabled, forKey: "cf_name_enabled") }
    }

    // 评论长度过滤
    @Published var lengthMin: Int {
        didSet { defaults.set(lengthMin, forKey: "cf_length_min") }
    }
    @Published var lengthMax: Int {
        didSet { defaults.set(lengthMax, forKey: "cf_length_max") }
    }
    @Published var lengthFilterEnabled: Bool {
        didSet { defaults.set(lengthFilterEnabled, forKey: "cf_length_enabled") }
    }

    private init() {
        let savedLevels = defaults.string(forKey: "cf_levels") ?? ""
        selectedLevels = Set(savedLevels.split(separator: ",").compactMap { Int($0) })
        levelFilterEnabled = defaults.object(forKey: "cf_level_enabled") as? Bool ?? false

        let kw = defaults.string(forKey: "cf_keywords") ?? ""
        keywords = kw.isEmpty ? [] : kw.components(separatedBy: "\n")
        keywordFilterEnabled = defaults.object(forKey: "cf_keyword_enabled") as? Bool ?? false

        let nk = defaults.string(forKey: "cf_name_keywords") ?? ""
        nameKeywords = nk.isEmpty ? [] : nk.components(separatedBy: "\n")
        nameFilterEnabled = defaults.object(forKey: "cf_name_enabled") as? Bool ?? false

        lengthMin = defaults.object(forKey: "cf_length_min") as? Int ?? 0
        lengthMax = defaults.object(forKey: "cf_length_max") as? Int ?? 10000
        lengthFilterEnabled = defaults.object(forKey: "cf_length_enabled") as? Bool ?? false
    }

    /// 返回屏蔽原因，nil表示不屏蔽
    func checkReply(content: String, username: String, level: Int?) -> String? {
        if levelFilterEnabled, let lv = level {
            if !selectedLevels.contains(lv) { return "用户等级 Lv\(lv) 已过滤" }
        }
        if keywordFilterEnabled {
            for kw in keywords where !kw.isEmpty {
                if content.localizedCaseInsensitiveContains(kw) { return "关键词「\(kw)」" }
            }
        }
        if nameFilterEnabled {
            for nk in nameKeywords where !nk.isEmpty {
                if username.localizedCaseInsensitiveContains(nk) { return "用户名「\(nk)」" }
            }
        }
        if lengthFilterEnabled {
            let c = content.count
            if c < lengthMin { return "内容过短(\(c)字)" }
            if c > lengthMax { return "内容过长(\(c)字)" }
        }
        return nil
    }
}

// MARK: - 评论区过滤设置页面
struct CommentFilterSettingsView: View {
    @StateObject private var settings = CommentFilterSettings.shared
    @EnvironmentObject private var themeManager: ThemeManager
    @State private var newKeyword = ""
    @State private var newNameKeyword = ""

    private let allLevels = (0...6).map { $0 }

    var body: some View {
        Form {
            // 等级过滤
            Section {
                Toggle("启用等级过滤", isOn: $settings.levelFilterEnabled)
                if settings.levelFilterEnabled {
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 4), spacing: 8) {
                        ForEach(allLevels, id: \.self) { lv in
                            Button {
                                if settings.selectedLevels.contains(lv) {
                                    settings.selectedLevels.remove(lv)
                                } else {
                                    settings.selectedLevels.insert(lv)
                                }
                            } label: {
                                Text("Lv\(lv)")
                                    .font(.caption).fontWeight(.medium)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 8)
                                    .background(settings.selectedLevels.contains(lv) ? themeManager.accentColor : Color(.systemGray5))
                                    .foregroundColor(settings.selectedLevels.contains(lv) ? .white : .primary)
                                    .cornerRadius(8)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            } header: {
                Text("按用户等级")
            } footer: {
                Text("只显示选中等级的评论，未选中的将被屏蔽")
            }

            // 关键词过滤
            Section {
                Toggle("启用关键词过滤", isOn: $settings.keywordFilterEnabled)
                if settings.keywordFilterEnabled {
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
                    if !settings.keywords.isEmpty {
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
                }
            } header: {
                Text("按关键词")
            } footer: {
                Text("模糊匹配，评论内容包含任一关键词即屏蔽")
            }

            // 用户名过滤
            Section {
                Toggle("启用用户名过滤", isOn: $settings.nameFilterEnabled)
                if settings.nameFilterEnabled {
                    HStack {
                        TextField("输入用户名关键词", text: $newNameKeyword)
                            .textFieldStyle(.roundedBorder)
                        Button("添加") {
                            let nk = newNameKeyword.trimmingCharacters(in: .whitespaces)
                            if !nk.isEmpty, !settings.nameKeywords.contains(nk) {
                                settings.nameKeywords.append(nk)
                            }
                            newNameKeyword = ""
                        }
                        .font(.caption)
                        .disabled(newNameKeyword.trimmingCharacters(in: .whitespaces).isEmpty)
                    }
                    if !settings.nameKeywords.isEmpty {
                        ForEach(settings.nameKeywords.indices, id: \.self) { i in
                            HStack {
                                Text(settings.nameKeywords[i]).font(.caption)
                                Spacer()
                                Button { settings.nameKeywords.remove(at: i) } label: {
                                    Image(systemName: "xmark.circle.fill").foregroundColor(.secondary)
                                }
                            }
                        }
                    }
                }
            } header: {
                Text("按用户名")
            } footer: {
                Text("模糊匹配，用户名包含任一关键词即屏蔽")
            }

            // 评论长度过滤
            Section {
                Toggle("启用长度过滤", isOn: $settings.lengthFilterEnabled)
                if settings.lengthFilterEnabled {
                    HStack {
                        Text("最短")
                        Slider(value: .init(get: { Double(settings.lengthMin) }, set: { settings.lengthMin = Int($0) }), in: 0...500, step: 10)
                        Text("\(settings.lengthMin)字").font(.caption).foregroundColor(.secondary).frame(width: 50)
                    }
                    HStack {
                        Text("最长")
                        Slider(value: .init(get: { Double(settings.lengthMax) }, set: { settings.lengthMax = Int($0) }), in: 50...5000, step: 50)
                        Text("\(settings.lengthMax)字").font(.caption).foregroundColor(.secondary).frame(width: 50)
                    }
                }
            } header: {
                Text("按评论长度")
            } footer: {
                Text("屏蔽长度不在范围内的评论")
            }
        }
        .navigationTitle("评论区过滤")
        .navigationBarTitleDisplayMode(.inline)
        .tint(themeManager.accentColor)
    }
}
