import SwiftUI
import Combine

// MARK: - 收藏列表
struct FavoriteScreen: View {
    @StateObject private var viewModel = FavoriteViewModel()
    @EnvironmentObject private var themeManager: ThemeManager

    var body: some View {
        NavigationStack {
            Group {
                if viewModel.isLoading {
                    ProgressView().tint(themeManager.accentColor)
                } else if viewModel.folders.isEmpty {
                    ContentUnavailableView("暂无收藏", systemImage: "star", description: Text("登录后查看收藏内容"))
                } else {
                    List(viewModel.folders) { folder in
                        HStack(spacing: 12) {
                            AsyncImage(url: URL(string: folder.cover ?? "")) { phase in
                                switch phase {
                                case .success(let img): img.resizable().scaledToFill()
                                default: Rectangle().fill(themeManager.surfaceColor)
                                }
                            }
                            .frame(width: 48, height: 48)
                            .cornerRadius(6)

                            VStack(alignment: .leading, spacing: 4) {
                                Text(folder.title ?? "")
                                    .font(.subheadline)
                                    .foregroundColor(themeManager.primaryTextColor)
                                Text("\(folder.media_count ?? 0)个内容")
                                    .font(.caption)
                                    .foregroundColor(themeManager.secondaryTextColor)
                            }
                            Spacer()
                            Image(systemName: "chevron.right").foregroundColor(.gray)
                        }
                        .padding(.vertical, 4)
                    }
                }
            }
            .navigationTitle("我的收藏")
            .background(themeManager.backgroundColor)
        }
        .task { await viewModel.loadFolders() }
    }
}

@MainActor
final class FavoriteViewModel: ObservableObject {
    @Published var folders: [FavFolder] = []
    @Published var isLoading = false

    func loadFolders() async {
        let mid = TokenManager.shared.mid
        guard mid > 0 else { return }
        isLoading = true
        defer { isLoading = false }
        do {
            let response: BiliApiResponse<FavFolderData> = try await ApiClient.shared.request(.favFolders(mid: mid))
            if response.isSuccess {
                folders = response.data?.list ?? []
            }
        } catch {}
    }
}

#Preview {
    FavoriteScreen().environmentObject(ThemeManager.shared)
}
