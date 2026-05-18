import SwiftUI

// MARK: - 设置主页
struct SettingsScreen: View {
    @EnvironmentObject private var themeManager: ThemeManager

    var body: some View {
        NavigationStack {
            List {
                // 外观
                Section {
                    NavigationLink { AppearanceSettingsScreen() } label: {
                        SettingsRow(icon: "paintpalette.fill", title: "外观设置", color: iOSBlue)
                    }
                    NavigationLink { PlaybackSettingsScreen() } label: {
                        SettingsRow(icon: "play.rectangle.fill", title: "播放设置", color: iOSGreen)
                    }
                    NavigationLink { DanmakuSettingsScreen() } label: {
                        SettingsRow(icon: "list.bullet.rectangle.fill", title: "弹幕设置", color: iOSOrange)
                    }
                } header: {
                    Text("显示与播放")
                }

                // 数据
                Section {
                    SettingsRow(icon: "arrow.down.circle.fill", title: "下载管理", color: iOSGreen)
                    NavigationLink { CacheSettingsScreen() } label: {
                        SettingsRow(icon: "trash.fill", title: "缓存清理", color: iOSRed)
                    }
                } header: {
                    Text("数据管理")
                }

                // 关于
                Section {
                    SettingsRow(icon: "lock.shield.fill", title: "权限管理", color: iOSSystemGray)
                    SettingsRow(icon: "app.badge.fill", title: "图标设置", color: iOSPurple)
                    SettingsRow(icon: "sparkles", title: "动画设置", color: iOSOrange)
                    NavigationLink { AboutSettingsScreen() } label: {
                        SettingsRow(icon: "info.circle.fill", title: "关于 BiliPai", color: iOSSystemGray)
                    }
                } header: {
                    Text("其他")
                }
            }
            .navigationTitle("设置")
            .background(themeManager.backgroundColor)
        }
    }
}

struct SettingsRow: View {
    let icon: String
    let title: String
    let color: Color
    @EnvironmentObject private var themeManager: ThemeManager

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.body)
                .foregroundColor(color)
                .frame(width: 24)
            Text(title)
                .font(.body)
                .foregroundColor(themeManager.primaryTextColor)
        }
    }
}

// MARK: - 外观设置
struct AppearanceSettingsScreen: View {
    @EnvironmentObject private var themeManager: ThemeManager

    var body: some View {
        List {
            Section {
                Picker("主题模式", selection: $themeManager.themeMode) {
                    ForEach(AppThemeMode.allCases, id: \.rawValue) { mode in
                        Text(mode.displayName).tag(mode)
                    }
                }
                .onChange(of: themeManager.themeMode) { _ in themeManager.save() }
            } header: { Text("主题") }

            Section {
                Picker("UI风格", selection: $themeManager.uiPreset) {
                    ForEach(UiPreset.allCases, id: \.rawValue) { preset in
                        Text(preset.displayName).tag(preset)
                    }
                }
                .onChange(of: themeManager.uiPreset) { _ in themeManager.save() }

                Toggle("动态取色", isOn: $themeManager.dynamicColorEnabled)
                    .onChange(of: themeManager.dynamicColorEnabled) { _ in themeManager.save() }
                Toggle("AMOLED纯黑", isOn: $themeManager.amoledDarkTheme)
                    .onChange(of: themeManager.amoledDarkTheme) { _ in themeManager.save() }
            } header: { Text("外观") }

            Section {
                Picker("字号", selection: $themeManager.fontSizePreset) {
                    ForEach(AppFontSizePreset.allCases, id: \.rawValue) { preset in
                        Text(presetName(preset)).tag(preset)
                    }
                }
                .onChange(of: themeManager.fontSizePreset) { _ in themeManager.save() }
            } header: { Text("字体") }

            Section {
                ForEach(0..<min(ThemeColors.count, ThemeColorNames.count), id: \.self) { idx in
                    Button {
                        themeManager.themeColorIndex = idx
                        themeManager.save()
                    } label: {
                        HStack {
                            Circle().fill(ThemeColors[idx]).frame(width: 24, height: 24)
                            Text(ThemeColorNames[idx])
                                .foregroundColor(themeManager.primaryTextColor)
                            Spacer()
                            if themeManager.themeColorIndex == idx {
                                Image(systemName: "checkmark")
                                    .foregroundColor(themeManager.accentColor)
                            }
                        }
                    }
                }
            } header: { Text("主题色") }
        }
        .navigationTitle("外观设置")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func presetName(_ preset: AppFontSizePreset) -> String {
        switch preset {
        case .small: return "小"
        case .default: return "标准"
        case .large: return "大"
        }
    }
}

// MARK: - 播放设置
struct PlaybackSettingsScreen: View {
    @State private var defaultQuality = UserDefaultsStore.shared.defaultPlaybackQuality
    @State private var defaultSpeed = UserDefaultsStore.shared.defaultPlaybackSpeed
    @State private var stopOnExit = UserDefaultsStore.shared.stopPlaybackOnExit
    @State private var bgPlayback = UserDefaultsStore.shared.backgroundPlaybackEnabled
    @State private var pipEnabled = UserDefaultsStore.shared.pipEnabled

    @EnvironmentObject private var themeManager: ThemeManager

    var body: some View {
        List {
            Section {
                Picker("默认画质", selection: $defaultQuality) {
                    Text("4K超清").tag(120)
                    Text("1080P60").tag(116)
                    Text("1080P").tag(80)
                    Text("720P").tag(64)
                    Text("480P").tag(32)
                }
                .onChange(of: defaultQuality) { UserDefaultsStore.shared.defaultPlaybackQuality = $0 }

                Picker("默认倍速", selection: $defaultSpeed) {
                    Text("0.5x").tag(0.5)
                    Text("0.75x").tag(0.75)
                    Text("1.0x").tag(1.0)
                    Text("1.25x").tag(1.25)
                    Text("1.5x").tag(1.5)
                    Text("2.0x").tag(2.0)
                }
                .onChange(of: defaultSpeed) { UserDefaultsStore.shared.defaultPlaybackSpeed = $0 }
            } header: { Text("播放") }

            Section {
                Toggle("退出时停止播放", isOn: $stopOnExit).onChange(of: stopOnExit) { UserDefaultsStore.shared.stopPlaybackOnExit = $0 }
                Toggle("后台播放", isOn: $bgPlayback).onChange(of: bgPlayback) { UserDefaultsStore.shared.backgroundPlaybackEnabled = $0 }
                Toggle("画中画", isOn: $pipEnabled).onChange(of: pipEnabled) { UserDefaultsStore.shared.pipEnabled = $0 }
            } header: { Text("行为") }
        }
        .navigationTitle("播放设置")
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - 弹幕设置
struct DanmakuSettingsScreen: View {
    @State private var danmakuEnabled = UserDefaultsStore.shared.danmakuEnabled
    @State private var danmakuAlpha = UserDefaultsStore.shared.danmakuAlpha
    @State private var danmakuFontScale = UserDefaultsStore.shared.danmakuFontScale
    @EnvironmentObject private var themeManager: ThemeManager

    var body: some View {
        List {
            Section {
                Toggle("弹幕开关", isOn: $danmakuEnabled)
                    .onChange(of: danmakuEnabled) { UserDefaultsStore.shared.danmakuEnabled = $0 }
            } header: { Text("基本") }

            Section {
                VStack(alignment: .leading) {
                    Text("不透明度: \(String(format: "%.0f%%", danmakuAlpha * 100))")
                    Slider(value: $danmakuAlpha, in: 0.1...1.0)
                        .onChange(of: danmakuAlpha) { UserDefaultsStore.shared.danmakuAlpha = $0 }
                }
                VStack(alignment: .leading) {
                    Text("字体缩放: \(String(format: "%.1f", danmakuFontScale))")
                    Slider(value: $danmakuFontScale, in: 0.5...1.5)
                        .onChange(of: danmakuFontScale) { UserDefaultsStore.shared.danmakuFontScale = $0 }
                }
            } header: { Text("显示") }
        }
        .navigationTitle("弹幕设置")
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - 缓存清理
struct CacheSettingsScreen: View {
    @EnvironmentObject private var themeManager: ThemeManager
    @State private var cacheSize = "计算中..."
    @State private var showAlert = false

    var body: some View {
        List {
            Section {
                HStack {
                    Text("缓存大小")
                    Spacer()
                    Text(cacheSize).foregroundColor(.gray)
                }
                Button("清除缓存") { showAlert = true }
                    .foregroundColor(.red)
            }
        }
        .navigationTitle("缓存清理")
        .alert("确认清除", isPresented: $showAlert) {
            Button("取消", role: .cancel) {}
            Button("清除", role: .destructive) { clearCache() }
        }
        .task { calculateSize() }
    }

    private func calculateSize() {
        let cachesURL = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first
        guard let path = cachesURL?.path else { return }
        let size = directorySize(path)
        cacheSize = ByteCountFormatter.string(fromByteCount: size, countStyle: .file)
    }

    private func directorySize(_ path: String) -> Int64 {
        let fm = FileManager.default
        guard let files = try? fm.contentsOfDirectory(atPath: path) else { return 0 }
        return files.reduce(0) { total, file in
            let fullPath = (path as NSString).appendingPathComponent(file)
            guard let attrs = try? fm.attributesOfItem(atPath: fullPath),
                  let size = attrs[.size] as? Int64 else { return total }
            return total + size
        }
    }

    private func clearCache() {
        let cachesURL = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first
        try? cachesURL.flatMap { try FileManager.default.removeItem(at: $0) }
        cacheSize = "0 bytes"
    }
}

// MARK: - 关于
struct AboutSettingsScreen: View {
    @EnvironmentObject private var themeManager: ThemeManager

    var body: some View {
        List {
            Section {
                HStack {
                    Text("版本")
                    Spacer()
                    Text("1.0.0").foregroundColor(.gray)
                }
                HStack {
                    Text("构建号")
                    Spacer()
                    Text("1").foregroundColor(.gray)
                }
            } header: { Text("版本信息") }

            Section {
                Text("BiliPai - 第三方Bilibili客户端")
                    .font(.subheadline)
                Text("基于B站公开API，仅供学习交流使用")
                    .font(.caption)
                    .foregroundColor(.gray)
            } header: { Text("说明") }
        }
        .navigationTitle("关于")
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    SettingsScreen().environmentObject(ThemeManager.shared)
}
