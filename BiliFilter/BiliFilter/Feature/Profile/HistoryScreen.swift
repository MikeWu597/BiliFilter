import SwiftUI
import Combine

// MARK: - 历史记录
struct HistoryScreen: View {
    @StateObject private var viewModel = HistoryViewModel()
    @EnvironmentObject private var themeManager: ThemeManager

    var body: some View {
        NavigationStack {
            Group {
                if viewModel.isLoading && viewModel.items.isEmpty {
                    ProgressView().tint(themeManager.accentColor)
                } else if viewModel.items.isEmpty {
                    ContentUnavailableView("暂无历史", systemImage: "clock", description: Text("观看记录将显示在这里"))
                } else {
                    List {
                        ForEach(viewModel.items) { item in
                            HStack(spacing: 12) {
                                AsyncImage(url: URL(string: item.cover ?? "")) { phase in
                                    switch phase {
                                    case .success(let img): img.resizable().scaledToFill()
                                    default: Rectangle().fill(themeManager.surfaceColor)
                                    }
                                }
                                .frame(width: 120, height: 72)
                                .cornerRadius(6)

                                VStack(alignment: .leading, spacing: 4) {
                                    Text(item.title ?? "")
                                        .font(.subheadline)
                                        .foregroundColor(themeManager.primaryTextColor)
                                        .lineLimit(2)
                                    Text(item.author_name ?? "")
                                        .font(.caption)
                                        .foregroundColor(themeManager.secondaryTextColor)
                                    if let progress = item.progress, let duration = item.duration, duration > 0 {
                                        ProgressView(value: Double(progress), total: Double(duration))
                                            .tint(themeManager.accentColor)
                                    }
                                }
                            }
                        }
                        .onDelete { indexSet in
                            // 批量删除
                        }
                    }
                }
            }
            .navigationTitle("历史记录")
            .toolbar {
                if !viewModel.items.isEmpty {
                    EditButton()
                }
            }
            .background(themeManager.backgroundColor)
        }
        .task { await viewModel.loadHistory() }
    }
}

@MainActor
final class HistoryViewModel: ObservableObject {
    @Published var items: [HistoryItem] = []
    @Published var isLoading = false

    func loadHistory() async {
        guard TokenManager.shared.mid > 0 else { return }
        isLoading = true
        defer { isLoading = false }
        do {
            let response: BiliApiResponse<HistoryData> = try await ApiClient.shared.request(
                .historyList(ps: 30, max: nil, viewAt: nil, business: nil)
            )
            if response.isSuccess {
                items = response.data?.list ?? []
            }
        } catch {}
    }
}

#Preview {
    HistoryScreen().environmentObject(ThemeManager.shared)
}
