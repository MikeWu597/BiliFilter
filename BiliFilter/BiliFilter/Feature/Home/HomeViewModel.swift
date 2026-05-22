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

    func loadFeed() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            let items = try await repository.fetchRecommendFeed()
            self.feedItems = items
        } catch {
            self.errorMessage = error.localizedDescription
        }
    }

    func refreshFeed() async {
        isRefreshing = true
        defer { isRefreshing = false }

        do {
            let items = try await repository.fetchRecommendFeed()
            self.feedItems = items
        } catch {
            self.errorMessage = error.localizedDescription
        }
    }
}
