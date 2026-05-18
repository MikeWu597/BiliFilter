import SwiftUI
import Combine

// MARK: - 消息中心
struct InboxScreen: View {
    @StateObject private var viewModel = InboxViewModel()
    @EnvironmentObject private var themeManager: ThemeManager

    var body: some View {
        NavigationStack {
            Group {
                if viewModel.isLoading {
                    ProgressView().tint(themeManager.accentColor)
                } else if !TokenManager.shared.isLoggedIn {
                    ContentUnavailableView("请先登录", systemImage: "person.circle", description: Text("登录后可查看消息"))
                } else {
                    List {
                        Section {
                            InboxRow(icon: "arrowshape.turn.up.left.fill", title: "回复我的", color: iOSBlue, count: viewModel.replyCount)
                            InboxRow(icon: "at", title: "@我的", color: iOSOrange, count: viewModel.atCount)
                            InboxRow(icon: "heart.fill", title: "赞我的", color: iOSPink, count: viewModel.likeCount)
                        }
                        Section {
                            InboxRow(icon: "envelope.fill", title: "私信", color: iOSGreen, count: 0)
                            InboxRow(icon: "bell.fill", title: "系统通知", color: iOSPurple, count: viewModel.sysCount)
                        }
                    }
                }
            }
            .navigationTitle("消息")
            .background(themeManager.backgroundColor)
        }
        .task { await viewModel.loadCounts() }
    }
}

struct InboxRow: View {
    let icon: String
    let title: String
    let color: Color
    let count: Int
    @EnvironmentObject private var themeManager: ThemeManager

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.body)
                .foregroundColor(color)
                .frame(width: 28)
            Text(title)
                .font(.body)
                .foregroundColor(themeManager.primaryTextColor)
            Spacer()
            if count > 0 {
                Text("\(count)")
                    .font(.caption)
                    .foregroundColor(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .background(Color.red)
                    .cornerRadius(10)
            }
            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundColor(themeManager.tertiaryTextColor)
        }
    }
}

@MainActor
final class InboxViewModel: ObservableObject {
    @Published var replyCount = 0
    @Published var atCount = 0
    @Published var likeCount = 0
    @Published var sysCount = 0
    @Published var isLoading = false

    func loadCounts() async {
        guard TokenManager.shared.mid > 0 else { return }
        isLoading = true
        defer { isLoading = false }
        do {
            let response: BiliApiResponse<NavStatData> = try await ApiClient.shared.request(.navStat)
            if response.isSuccess, let data = response.data {
                replyCount = data.reply ?? 0
                atCount = data.at ?? 0
                likeCount = data.like ?? 0
            }
        } catch {}
    }
}

struct NavStatData: Codable {
    let reply: Int?
    let at: Int?
    let like: Int?
    let system: Int?
    enum CodingKeys: String, CodingKey {
        case reply, at, like
        case system = "sys_msg"
    }
}

struct NavStatResponse: Codable {
    let code: Int?
    let data: NavStatData?
    enum CodingKeys: String, CodingKey { case code, data }
}

#Preview {
    InboxScreen().environmentObject(ThemeManager.shared)
}
