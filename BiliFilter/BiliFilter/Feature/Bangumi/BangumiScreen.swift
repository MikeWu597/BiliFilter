import SwiftUI
import Combine

// MARK: - 番剧主页
struct BangumiScreen: View {
    @StateObject private var viewModel = BangumiViewModel()
    @EnvironmentObject private var themeManager: ThemeManager

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // 类型切换
                Picker("类型", selection: $viewModel.selectedType) {
                    Text("番剧").tag(1)
                    Text("国创").tag(4)
                    Text("电影").tag(2)
                    Text("纪录片").tag(3)
                }
                .pickerStyle(.segmented)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)

                if viewModel.isLoading {
                    Spacer()
                    ProgressView().tint(themeManager.accentColor)
                    Spacer()
                } else {
                    ScrollView {
                        LazyVStack(spacing: 16) {
                            ForEach(viewModel.seasons) { season in
                                BangumiCard(season: season)
                            }
                        }
                        .padding(12)
                    }
                    .refreshable { await viewModel.loadSeasons() }
                }
            }
            .background(themeManager.backgroundColor)
            .navigationTitle("番剧")
        }
        .task { await viewModel.loadSeasons() }
    }
}

// MARK: - 番剧ViewModel
@MainActor
final class BangumiViewModel: ObservableObject {
    @Published var seasons: [BangumiSeason] = []
    @Published var selectedType: Int = 1
    @Published var isLoading = false

    func loadSeasons() async {
        isLoading = true
        defer { isLoading = false }
        // 番剧列表通过分区接口获取
        do {
            let repo = VideoRepository.shared
            let videos = try await repo.fetchRegionVideos(rid: selectedType == 1 ? 13 : 167, pn: 1, ps: 30)
            seasons = videos.map { video in
                BangumiSeason(id: video.id, title: video.title, cover: video.pic, desc: video.desc ?? "", stat: video.stat)
            }
        } catch {}
    }
}

struct BangumiSeason: Identifiable {
    let id: Int64
    let title: String
    let cover: String
    let desc: String
    let stat: StatInfo?
}

struct BangumiCard: View {
    let season: BangumiSeason
    @EnvironmentObject private var themeManager: ThemeManager

    var body: some View {
        HStack(spacing: 12) {
            AsyncImage(url: URL(string: season.cover)) { phase in
                switch phase {
                case .success(let img): img.resizable().scaledToFill()
                default: Rectangle().fill(themeManager.surfaceColor)
                }
            }
            .frame(width: 120, height: 160)
            .clipShape(RoundedRectangle(cornerRadius: 8))

            VStack(alignment: .leading, spacing: 8) {
                Text(season.title)
                    .font(.headline)
                    .foregroundColor(themeManager.primaryTextColor)
                    .lineLimit(2)
                Text(season.desc)
                    .font(.caption)
                    .foregroundColor(themeManager.secondaryTextColor)
                    .lineLimit(2)
                if let stat = season.stat {
                    HStack(spacing: 12) {
                        Label("\(stat.viewCount)", systemImage: "play.fill")
                        Label("\(stat.danmakuCount)", systemImage: "text.bubble")
                    }
                    .font(.caption)
                    .foregroundColor(themeManager.tertiaryTextColor)
                }
                Spacer()
            }
            .padding(.vertical, 4)
        }
        .padding(12)
        .background(themeManager.surfaceColor)
        .cornerRadius(12)
    }
}

#Preview {
    BangumiScreen().environmentObject(ThemeManager.shared)
}
