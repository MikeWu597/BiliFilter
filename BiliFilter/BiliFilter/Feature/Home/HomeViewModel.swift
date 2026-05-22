import SwiftUI
import Combine

// MARK: - 首页ViewModel
@MainActor
final class HomeViewModel: ObservableObject {
    @Published var feedItems: [RecommendItem] = []
    @Published var isLoading = false
    @Published var isRefreshing = false
    @Published var errorMessage: String?

    private let repository = VideoRepository.shared
    private var freshIdx = 1
    private var refreshTask: Task<Void, Never>?

    func loadFeed() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            freshIdx = 1
            let items = try await repository.fetchRecommendFeed(freshIdx: freshIdx)
            self.feedItems = items
        } catch {
            self.errorMessage = error.localizedDescription
        }
    }

    func refreshFeed() {
        guard !isRefreshing else { return }
        isRefreshing = true
        freshIdx += 1
        let idx = freshIdx
        refreshTask?.cancel()
        refreshTask = Task { [weak self] in
            guard let self else { return }
            do {
                print("[Home] refreshFeed freshIdx=\(idx)")
                let items = try await self.repository.fetchRecommendFeed(freshIdx: idx)
                print("[Home] refreshFeed got \(items.count) items")
                if !items.isEmpty {
                    await MainActor.run { self.feedItems = items }
                }
            } catch {
                print("[Home] refreshFeed ERROR: \(error)")
            }
            await MainActor.run { self.isRefreshing = false }
        }
    }
}
