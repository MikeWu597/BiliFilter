import SwiftUI
import Combine

struct FavoriteScreen: View {
    @StateObject private var viewModel = FavoriteViewModel()
    var body: some View {
        Group {
            if viewModel.isLoading { ProgressView() }
            else if viewModel.folders.isEmpty {
                ContentUnavailableView("暂无收藏", systemImage: "star", description: Text("登录后查看"))
            } else {
                List(viewModel.folders) { folder in
                    HStack(spacing: 12) {
                        BiliCover(url: folder.cover, aspectRatio: 1).frame(width: 48, height: 48)
                        VStack(alignment: .leading, spacing: 4) {
                            Text(folder.title ?? "").font(.subheadline)
                            Text("\(folder.media_count ?? 0)个内容").font(.caption).foregroundColor(.secondary)
                        }
                    }
                }
            }
        }
        .navigationTitle("我的收藏")
        .task { await viewModel.loadFolders() }
    }
}

@MainActor final class FavoriteViewModel: ObservableObject {
    @Published var folders: [FavFolder] = []; @Published var isLoading = false
    func loadFolders() async {
        let mid = TokenManager.shared.mid
        guard mid > 0 else { return }
        isLoading = true; defer { isLoading = false }
        do {
            let r: BiliApiResponse<FavFolderData> = try await ApiClient.shared.request(.favFolders(mid: mid))
            if r.isSuccess { folders = r.data?.list ?? [] }
        } catch {}
    }
}
#Preview { FavoriteScreen() }
