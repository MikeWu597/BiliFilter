import SwiftUI
import Combine

@MainActor
final class SearchViewModel: ObservableObject {
    @Published var query: String = ""
    @Published var suggestions: [String] = []
    @Published var hotSearches: [String] = []
    @Published var results: [SearchResultItem] = []
    @Published var isLoading = false
    @Published var currentPage = 1
    @Published var hasMoreResults = false

    private let api = ApiClient.shared
    private let defaults = UserDefaults.standard
    private let historyKey = "search_history"

    var searchHistory: [String] {
        defaults.stringArray(forKey: historyKey) ?? []
    }

    func addToHistory(_ term: String) {
        var history = searchHistory
        history.removeAll { $0 == term }
        history.insert(term, at: 0)
        if history.count > 20 { history = Array(history.prefix(20)) }
        defaults.set(history, forKey: historyKey)
    }

    func clearHistory() {
        defaults.removeObject(forKey: historyKey)
    }

    func loadHotSearches() async {
        do {
            let response: BiliApiResponse<HotSearchData> = try await api.request(.searchHot, needsWbi: true)
            if response.isSuccess {
                hotSearches = response.data?.trending?.list?.compactMap { $0.show_name ?? $0.keyword } ?? []
            }
        } catch {}
    }

    func search() async {
        guard !query.isEmpty else { return }
        isLoading = true
        currentPage = 1
        addToHistory(query)
        do {
            let response: BiliApiResponse<SearchData> = try await api.request(
                .search(keyword: query, page: 1, pageSize: 20),
                needsWbi: true
            )
            results = response.data?.result ?? []
            hasMoreResults = (response.data?.numPages ?? 0) > 1
        } catch {}
        isLoading = false
    }

    func loadMore() async {
        guard !isLoading, hasMoreResults else { return }
        isLoading = true
        currentPage += 1
        do {
            let response: BiliApiResponse<SearchData> = try await api.request(
                .search(keyword: query, page: currentPage, pageSize: 20),
                needsWbi: true
            )
            results += response.data?.result ?? []
            hasMoreResults = (response.data?.numPages ?? 0) > currentPage
        } catch {}
        isLoading = false
    }
}

struct HotSearchData: Codable {
    let trending: TrendingData?
    enum CodingKeys: String, CodingKey { case trending }
}

struct TrendingData: Codable {
    let list: [TrendingItem]?
    enum CodingKeys: String, CodingKey { case list }
}

struct TrendingItem: Codable {
    let show_name: String?
    let keyword: String?
    enum CodingKeys: String, CodingKey { case show_name, keyword }
}
