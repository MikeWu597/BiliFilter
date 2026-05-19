import SwiftUI
import Combine

// MARK: - 个人中心 (iOS原生List样式)
struct ProfileScreen: View {
    @StateObject private var viewModel = ProfileViewModel()

    var body: some View {
        NavigationStack {
            List {
                // 用户头部
                Section {
                    HStack(spacing: 14) {
                        BiliAvatar(url: viewModel.face, size: 60)
                        VStack(alignment: .leading, spacing: 4) {
                            if viewModel.isLoggedIn {
                                Text(viewModel.userName)
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
                        Image(systemName: "chevron.right")
                            .font(.caption).foregroundColor(Color(.systemGray3))
                    }
                    .padding(.vertical, 4)
                }

                // 内容管理
                Section {
                    NavigationLink(destination: HistoryScreen()) {
                        Label("历史记录", systemImage: "clock.fill").foregroundColor(iOSTeal)
                    }
                    NavigationLink(destination: FavoriteScreen()) {
                        Label("我的收藏", systemImage: "star.fill").foregroundColor(.yellow)
                    }
                    NavigationLink(destination: WatchLaterScreen()) {
                        Label("稍后再看", systemImage: "clock.badge").foregroundColor(iOSLightBlue)
                    }
                    NavigationLink(destination: DownloadScreen()) {
                        Label("下载管理", systemImage: "arrow.down.circle.fill").foregroundColor(.green)
                    }
                }

                // 消息
                Section {
                    NavigationLink(destination: InboxScreen()) {
                        Label("消息中心", systemImage: "envelope.fill").foregroundColor(.blue)
                    }
                }

                // 系统
                Section {
                    NavigationLink(destination: SettingsScreen()) {
                        Label("设置", systemImage: "gearshape.fill").foregroundColor(.gray)
                    }
                    Button {
                        if let url = URL(string: "https://github.com/jay3-yy/BiliPai") {
                            UIApplication.shared.open(url)
                        }
                    } label: {
                        HStack {
                            Label("关于 BiliPai", systemImage: "info.circle.fill")
                                .foregroundColor(.gray)
                            Spacer()
                            Image(systemName: "arrow.up.forward")
                                .font(.caption).foregroundColor(Color(.systemGray3))
                        }
                    }
                }
            }
            .navigationTitle("我的")
        }
        .task { await viewModel.loadProfile() }
    }
}

// MARK: - 稍后再看
struct WatchLaterScreen: View {
    var body: some View {
        ContentUnavailableView("稍后再看", systemImage: "clock.badge", description: Text("登录后查看稍后再看列表"))
            .navigationTitle("稍后再看")
    }
}

@MainActor
final class ProfileViewModel: ObservableObject {
    @Published var isLoggedIn = false
    @Published var userName = ""
    @Published var face = ""
    @Published var level: Int?

    func loadProfile() async {
        isLoggedIn = TokenManager.shared.isLoggedIn
        guard isLoggedIn else { return }
        do {
            let response: BiliApiResponse<NavData> = try await ApiClient.shared.request(.navInfo)
            if response.isSuccess, let data = response.data {
                userName = data.uname ?? ""
                face = data.face ?? ""
                level = data.level_info?.current_level
            }
        } catch {}
    }
}

#Preview {
    ProfileScreen()
}
