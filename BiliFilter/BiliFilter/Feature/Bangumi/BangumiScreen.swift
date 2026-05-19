import SwiftUI
import Combine

struct BangumiScreen: View {
    @StateObject private var viewModel = BangumiViewModel()
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                Picker("类型", selection: $viewModel.selectedType) {
                    Text("番剧").tag(1); Text("国创").tag(4); Text("电影").tag(2)
                }.pickerStyle(.segmented).padding()
                if viewModel.isLoading { Spacer(); ProgressView(); Spacer() }
                else {
                    ScrollView {
                        LazyVStack(spacing: 16) {
                            ForEach(viewModel.seasons) { season in BangumiCard(season: season) }
                        }.padding(12)
                    }.refreshable { await viewModel.loadSeasons() }
                }
            }
            .navigationTitle("番剧")
        }
        .task { await viewModel.loadSeasons() }
    }
}

@MainActor final class BangumiViewModel: ObservableObject {
    @Published var seasons: [BangumiSeason] = []
    @Published var selectedType: Int = 1; @Published var isLoading = false
    func loadSeasons() async {
        isLoading = true; defer { isLoading = false }
        do {
            let videos = try await VideoRepository.shared.fetchRegionVideos(rid: selectedType == 1 ? 13 : 167, pn: 1, ps: 30)
            seasons = videos.map { BangumiSeason(id: $0.id, title: $0.title, cover: $0.pic, desc: $0.desc ?? "", stat: $0.stat) }
        } catch {}
    }
}

struct BangumiSeason: Identifiable {
    let id: Int64; let title: String; let cover: String; let desc: String; let stat: StatInfo?
}

struct BangumiCard: View {
    let season: BangumiSeason
    var body: some View {
        HStack(spacing: 12) {
            BiliCover(url: season.cover).frame(width: 120, height: 160)
            VStack(alignment: .leading, spacing: 8) {
                Text(season.title).font(.headline).lineLimit(2)
                Text(season.desc).font(.caption).foregroundColor(.secondary).lineLimit(2)
                if let stat = season.stat {
                    HStack(spacing: 12) {
                        Label("\(stat.viewCount)", systemImage: "play.fill")
                        Label("\(stat.danmakuCount)", systemImage: "text.bubble")
                    }.font(.caption).foregroundColor(.secondary)
                }
                Spacer()
            }.padding(.vertical, 4)
        }
        .padding(12).background(Color(.systemBackground)).cornerRadius(12)
    }
}
#Preview { BangumiScreen().environmentObject(ThemeManager.shared) }
