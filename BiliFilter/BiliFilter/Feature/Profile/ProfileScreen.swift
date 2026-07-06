import SwiftUI
import Combine
import UniformTypeIdentifiers

// MARK: - 个人中心
struct ProfileScreen: View {
    @State private var showImporter = false

    var body: some View {
        NavigationStack {
            List {
                Section {
                    NavigationLink(destination: FilterSettingsView()) {
                        Label("视频过滤", systemImage: "line.3.horizontal.decrease.circle.fill")
                            .foregroundColor(.orange)
                    }
                    NavigationLink(destination: CommentFilterSettingsView()) {
                        Label("评论区过滤", systemImage: "text.bubble.fill")
                            .foregroundColor(.blue)
                    }
                    NavigationLink(destination: UIDFilterSettingsView()) {
                        Label("用户过滤", systemImage: "person.fill.xmark")
                            .foregroundColor(.pink)
                    }
                    NavigationLink(destination: DanmakuFilterSettingsView()) {
                        Label("弹幕过滤", systemImage: "rectangle.stack.fill")
                            .foregroundColor(.green)
                    }
                }

                Section {
                    NavigationLink(destination: WatchHistoryScreen()) {
                        Label("观看历史", systemImage: "clock.fill")
                            .foregroundColor(.purple)
                    }
                    NavigationLink(destination: UserTagsView()) {
                        Label("用户标记", systemImage: "tag.fill")
                            .foregroundColor(.orange)
                    }
                    NavigationLink(destination: VideoTagsView()) {
                        Label("视频标记", systemImage: "bookmark.fill")
                            .foregroundColor(.blue)
                    }
                }

                Section {
                    Button { Task { await performExport() } } label: {
                        Label("导出数据", systemImage: "square.and.arrow.up")
                    }
                    Button { showImporter = true } label: {
                        Label("导入数据", systemImage: "square.and.arrow.down")
                    }
                }
            }
            .navigationTitle("我的")
        }
        .fileImporter(isPresented: $showImporter, allowedContentTypes: [.zip]) { result in
            if case .success(let url) = result {
                Task { await performImport(from: url) }
            }
        }
    }

    private func performExport() async {
        do {
            let zipURL = try await DataPortManager.exportData()
            let controller = UIActivityViewController(activityItems: [zipURL], applicationActivities: nil)
            if let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
               let root = scene.windows.first?.rootViewController {
                root.present(controller, animated: true)
            }
        } catch {
            print("[Export] error: \(error)")
        }
    }

    private func performImport(from url: URL) async {
        do {
            try await DataPortManager.importData(from: url)
        } catch {
            print("[Import] error: \(error)")
        }
    }
}

#Preview {
    ProfileScreen()
}
