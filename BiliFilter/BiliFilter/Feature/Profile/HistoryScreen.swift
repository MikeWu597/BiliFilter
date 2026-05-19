import SwiftUI
import Combine

struct HistoryScreen: View {
    @StateObject private var viewModel = HistoryViewModel()
    var body: some View {
        List {
            ForEach(viewModel.items) { item in
                HStack(spacing: 12) {
                    BiliCover(url: item.cover).frame(width: 120, height: 72)
                    VStack(alignment: .leading, spacing: 4) {
                        Text(item.title ?? "").font(.subheadline).lineLimit(2)
                        Text(item.author_name ?? "").font(.caption).foregroundColor(.secondary)
                        if let p = item.progress, let d = item.duration, d > 0 {
                            ProgressView(value: Double(p), total: Double(d)).tint(.accentColor)
                        }
                    }
                }
            }
            .onDelete { _ in }
        }
        .navigationTitle("历史记录")
        .task { await viewModel.loadHistory() }
    }
}

@MainActor final class HistoryViewModel: ObservableObject {
    @Published var items: [HistoryItem] = []; @Published var isLoading = false
    func loadHistory() async {
        guard TokenManager.shared.mid > 0 else { return }
        isLoading = true; defer { isLoading = false }
        do {
            let r: BiliApiResponse<HistoryData> = try await ApiClient.shared.request(.historyList(ps: 30, max: nil, viewAt: nil, business: nil))
            if r.isSuccess { items = r.data?.list ?? [] }
        } catch {}
    }
}
#Preview { HistoryScreen() }
