import SwiftUI
import Combine

// MARK: - 个人中心
struct ProfileScreen: View {
    @StateObject private var viewModel = ProfileViewModel()

    var body: some View {
        NavigationStack {
            List {
                Section {
                    HStack(spacing: 14) {
                        BiliAvatar(url: viewModel.face, size: 60)
                        VStack(alignment: .leading, spacing: 4) {
                            if viewModel.isLoggedIn {
                                Text(viewModel.userName.isEmpty ? "用户\(viewModel.mid)" : viewModel.userName)
                                    .font(.title3).fontWeight(.semibold)
                                if let level = viewModel.level {
                                    Text("LV\(level)")
                                        .font(.caption).foregroundColor(.white)
                                        .padding(.horizontal, 8).padding(.vertical, 2)
                                        .background(Color.accentColor).cornerRadius(8)
                                }
                            } else {
                                NavigationLink(destination: LoginScreen()) {
                                    Text("点击登录")
                                        .font(.headline)
                                }
                            }
                        }
                        Spacer()
                        if viewModel.isLoggedIn {
                            Image(systemName: "chevron.right")
                                .font(.caption).foregroundColor(Color(.systemGray3))
                        }
                    }
                    .padding(.vertical, 4)
                }

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
                    NavigationLink(destination: UserTagsView()) {
                        Label("用户标记", systemImage: "tag.fill")
                            .foregroundColor(.orange)
                    }
                    NavigationLink(destination: VideoTagsView()) {
                        Label("视频标记", systemImage: "bookmark.fill")
                            .foregroundColor(.blue)
                    }
                }
            }
            .navigationTitle("我的")
        }
        .task { await viewModel.loadProfile() }
        .onReceive(TokenManager.shared.$isLoggedIn) { loggedIn in
            if loggedIn { Task { await viewModel.loadProfile() } }
        }
    }
}

@MainActor
final class ProfileViewModel: ObservableObject {
    @Published var isLoggedIn = false
    @Published var userName = ""
    @Published var face = ""
    @Published var level: Int?
    @Published var mid: Int64 = 0

    func loadProfile() async {
        isLoggedIn = TokenManager.shared.isLoggedIn
        mid = TokenManager.shared.mid
        let sess = TokenManager.shared.sessdata ?? "nil"
        print("[Profile] loadProfile isLoggedIn=\(isLoggedIn) mid=\(mid) sessdata=\(sess.prefix(10))...")
        guard isLoggedIn else { return }
        do {
            var req = URLRequest(url: URL(string: "https://api.bilibili.com/x/web-interface/nav")!)
            req.setValue("Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36", forHTTPHeaderField: "User-Agent")
            req.setValue("https://www.bilibili.com", forHTTPHeaderField: "Referer")
            if let s = TokenManager.shared.sessdata, !s.isEmpty {
                req.setValue("SESSDATA=\(s); buvid3=\(TokenManager.shared.buvid3)", forHTTPHeaderField: "Cookie")
            }
            let (data, _) = try await URLSession.shared.data(for: req)
            // 用JSONSerialization手动解析，避开Codable的类型严格校验
            if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
               let dataDict = json["data"] as? [String: Any] {
                userName = dataDict["uname"] as? String ?? ""
                face = (dataDict["face"] as? String) ?? ""
                if let li = dataDict["level_info"] as? [String: Any] {
                    level = li["current_level"] as? Int
                }
                print("[Profile] JSON parsed: uname='\(userName)' face='\(face.prefix(30))...' level=\(level ?? -1)")
            } else {
                print("[Profile] JSON parse failed")
            }
        } catch {
            print("[Profile] navInfo error: \(error)")
        }
    }
}

#Preview {
    ProfileScreen()
}
