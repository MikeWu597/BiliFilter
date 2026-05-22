import SwiftUI
import Combine

// MARK: - 个人中心
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
            }
            .navigationTitle("我的")
        }
        .task { await viewModel.loadProfile() }
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
