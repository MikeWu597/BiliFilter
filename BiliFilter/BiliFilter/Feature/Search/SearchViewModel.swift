import SwiftUI
import Combine

@MainActor
final class SearchViewModel: ObservableObject {
    @Published var query: String = ""
    @Published var results: [SearchResultItem] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var currentPage = 1
    @Published var hasMoreResults = false

    private let api = ApiClient.shared

    func search() async {
        guard !query.trimmingCharacters(in: .whitespaces).isEmpty else { return }
        let keyword = query.trimmingCharacters(in: .whitespaces)
        print("[SearchVM] 🔍 searching keyword='\(keyword)'")
        isLoading = true
        errorMessage = nil
        currentPage = 1

        do {
            let response: BiliApiResponse<SearchData> = try await api.request(
                .search(keyword: keyword, page: 1, pageSize: 20),
                needsWbi: true
            )
            print("[SearchVM] 📦 response code=\(response.code) message='\(response.message)'")
            print("[SearchVM] 📦 data.result count=\(response.data?.result?.count ?? -1) numResults=\(response.data?.numResults ?? -1) numPages=\(response.data?.numPages ?? -1)")

            if response.isSuccess, let data = response.data {
                results = data.result ?? []
                hasMoreResults = (data.numPages ?? 0) > 1 && !results.isEmpty
                print("[SearchVM] ✅ got \(results.count) results, hasMore=\(hasMoreResults)")
                if results.isEmpty {
                    errorMessage = "未找到结果"
                }
            } else {
                let msg = response.message.isEmpty ? "搜索失败 (code: \(response.code))" : response.message
                print("[SearchVM] ❌ api error: \(msg)")
                errorMessage = msg
            }
        } catch {
            print("[SearchVM] ❌ exception: \(error)")
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    func loadMore() async {
        guard !isLoading, hasMoreResults else { return }
        isLoading = true
        currentPage += 1
        let page = currentPage
        let keyword = query.trimmingCharacters(in: .whitespaces)
        print("[SearchVM] 🔍 loadMore page=\(page) keyword='\(keyword)'")

        do {
            let response: BiliApiResponse<SearchData> = try await api.request(
                .search(keyword: keyword, page: page, pageSize: 20),
                needsWbi: true
            )
            print("[SearchVM] 📦 loadMore code=\(response.code) count=\(response.data?.result?.count ?? -1)")

            if response.isSuccess, let data = response.data {
                let newResults = data.result ?? []
                let existingIds = Set(results.compactMap { $0.bvid })
                let unique = newResults.filter { item in
                    guard let bvid = item.bvid else { return false }
                    return !existingIds.contains(bvid)
                }
                results.append(contentsOf: unique)
                hasMoreResults = (data.numPages ?? 0) > page && !newResults.isEmpty
                print("[SearchVM] ✅ loadMore added \(unique.count) unique, total=\(results.count)")
            }
        } catch {
            print("[SearchVM] ❌ loadMore error: \(error)")
        }
        isLoading = false
    }
}
