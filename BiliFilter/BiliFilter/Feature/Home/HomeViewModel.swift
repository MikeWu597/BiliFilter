import SwiftUI
import Combine

// MARK: - 首页分类
enum HomeCategory: String, CaseIterable, Identifiable {
    case recommend = "推荐"
    case hot = "热门"
    case anime = "番剧"
    case live = "直播"

    var id: String { rawValue }

    var rid: Int? {
        switch self {
        case .recommend: return nil
        case .hot: return nil
        case .anime: return 13
        case .live: return nil
        }
    }
}

// MARK: - 首页ViewModel
@MainActor
final class HomeViewModel: ObservableObject {
    @Published var feedItems: [RecommendItem] = []
    @Published var isLoading = false
    @Published var isRefreshing = false
    @Published var hasMoreData = true
    @Published var errorMessage: String?
    @Published var selectedCategory: HomeCategory = .recommend
    @Published var categoryVideos: [VideoItem] = []

    private let repository = VideoRepository.shared
    private var currentPage = 1

    func loadFeed() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            let items = try await repository.fetchRecommendFeed()
            self.feedItems = items
            self.currentPage = 1
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
            self.currentPage = 1
            self.hasMoreData = true
        } catch {
            self.errorMessage = error.localizedDescription
        }
    }

    func loadCategoryVideos() async {
        guard selectedCategory != .recommend else { return }
        isLoading = true
        defer { isLoading = false }

        do {
            switch selectedCategory {
            case .hot:
                let data = try await repository.fetchPopularVideos(pn: currentPage)
                if let list = data?.list {
                    if currentPage == 1 {
                        categoryVideos = list
                    } else {
                        categoryVideos.append(contentsOf: list)
                    }
                    hasMoreData = !list.isEmpty
                    currentPage += 1
                }
            case .anime, .live:
                break
            default:
                break
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func switchCategory(_ category: HomeCategory) {
        selectedCategory = category
        if category == .recommend {
            Task { await refreshFeed() }
        } else {
            currentPage = 1
            categoryVideos = []
            Task { await loadCategoryVideos() }
        }
    }

    func filteredFeedItems() -> [RecommendItem] {
        feedItems.filter { item in
            item.goto == "av" && !item.bvid.isEmpty
        }
    }
}
