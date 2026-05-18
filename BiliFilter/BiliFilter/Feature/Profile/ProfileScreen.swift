import SwiftUI
import Combine

// MARK: - 个人中心
struct ProfileScreen: View {
    @StateObject private var viewModel = ProfileViewModel()
    @EnvironmentObject private var themeManager: ThemeManager

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 0) {
                    // 用户头部
                    VStack(spacing: 12) {
                        AsyncImage(url: URL(string: viewModel.face)) { phase in
                            switch phase {
                            case .success(let img): img.resizable().scaledToFill()
                            default: Circle().fill(.gray)
                            }
                        }
                        .frame(width: 72, height: 72)
                        .clipShape(Circle())

                        if viewModel.isLoggedIn {
                            Text(viewModel.userName)
                                .font(.title3)
                                .fontWeight(.bold)
                                .foregroundColor(themeManager.primaryTextColor)
                            if let level = viewModel.level {
                                Text("LV\(level)")
                                    .font(.caption)
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 2)
                                    .background(themeManager.accentColor)
                                    .cornerRadius(8)
                            }
                        } else {
                            NavigationLink(destination: LoginScreen()) {
                                HStack {
                                    Image(systemName: "person.circle")
                                    Text("点击登录")
                                }
                                .font(.headline)
                                .foregroundColor(themeManager.accentColor)
                            }
                        }
                    }
                    .padding(.vertical, 24)
                    .frame(maxWidth: .infinity)
                    .background(themeManager.surfaceColor)

                    // 菜单项
                    LazyVStack(spacing: 0) {
                        ProfileMenuItem(icon: "clock.fill", title: "历史记录", color: iOSTeal)
                        ProfileMenuItem(icon: "star.fill", title: "我的收藏", color: iOSYellow)
                        ProfileMenuItem(icon: "clock.badge", title: "稍后再看", color: iOSLightBlue)
                        ProfileMenuItem(icon: "arrow.down.circle.fill", title: "下载管理", color: iOSGreen)
                    }
                    .padding(.top, 16)

                    LazyVStack(spacing: 0) {
                        ProfileMenuItem(icon: "gearshape.fill", title: "设置", color: .gray)
                        ProfileMenuItem(icon: "questionmark.circle.fill", title: "帮助与反馈", color: .gray)
                        ProfileMenuItem(icon: "info.circle.fill", title: "关于", color: .gray)
                    }
                    .padding(.top, 16)
                }
            }
            .background(themeManager.backgroundColor)
            .navigationTitle("我的")
            .navigationBarTitleDisplayMode(.inline)
        }
        .task { await viewModel.loadProfile() }
    }
}

struct ProfileMenuItem: View {
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
            Spacer()
            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundColor(themeManager.tertiaryTextColor)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(themeManager.surfaceColor)
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
    ProfileScreen().environmentObject(ThemeManager.shared)
}
