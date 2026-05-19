import SwiftUI
import Combine

// MARK: - 动态页
struct DynamicScreen: View {
    @StateObject private var viewModel = DynamicViewModel()

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                if viewModel.isLoading && viewModel.items.isEmpty {
                    Spacer(); ProgressView(); Spacer()
                } else if viewModel.items.isEmpty {
                    Spacer()
                    ContentUnavailableView("暂无动态", systemImage: "rectangle.3.group", description: Text("登录后可查看关注动态"))
                    Spacer()
                } else {
                    ScrollView {
                        LazyVStack(spacing: 8) {
                            ForEach(viewModel.items) { item in DynamicCard(item: item) }
                        }.padding(12)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .refreshable { await viewModel.loadDynamics() }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .navigationTitle("动态")
        }
        .task { await viewModel.loadDynamics() }
    }
}

@MainActor
final class DynamicViewModel: ObservableObject {
    @Published var items: [DynamicItem] = []
    @Published var isLoading = false

    func loadDynamics() async {
        isLoading = true
        defer { isLoading = false }
        do {
            let response: BiliApiResponse<DynamicFeedData> = try await ApiClient.shared.request(.dynamicList(page: 1))
            if response.isSuccess { items = response.data?.items ?? [] }
        } catch {}
    }
}

// Models elided for brevity - same as before
struct DynamicItem: Identifiable, Codable {
    var id: String { id_str ?? UUID().uuidString }
    let id_str: String?; let type: String?; let modules: DynamicModules?
    enum CodingKeys: String, CodingKey { case id_str, type, modules }
}
struct DynamicModules: Codable {
    let module_author: DynamicAuthor?; let module_dynamic: DynamicContent?; let module_stat: DynamicStat?
    enum CodingKeys: String, CodingKey { case module_author, module_dynamic, module_stat }
}
struct DynamicAuthor: Codable {
    let name: String?; let face: String?; let mid: Int64?; let pub_time: String?
    enum CodingKeys: String, CodingKey { case name, face, mid, pub_time }
}
struct DynamicContent: Codable {
    let desc: DynamicDesc?; let major: DynamicMajor?
    enum CodingKeys: String, CodingKey { case desc, major }
}
struct DynamicDesc: Codable { let text: String? }
struct DynamicMajor: Codable {
    let type: String?; let archive: DynamicArchive?; let draw: DynamicDraw?; let live_rcmd: DynamicLive?
    enum CodingKeys: String, CodingKey { case type, archive, draw, live_rcmd }
}
struct DynamicArchive: Codable {
    let title: String?; let cover: String?; let bvid: String?; let play: Int?; let danmaku: Int?; let duration_text: String?
    enum CodingKeys: String, CodingKey { case title, cover, bvid, play, danmaku, duration_text }
}
struct DynamicDraw: Codable { let items: [DrawItem]? }
struct DrawItem: Codable { let src: String?; let width: Int?; let height: Int? }
struct DynamicLive: Codable { let content: String? }
struct DynamicStat: Codable {
    let like: DynamicCount?; let comment: DynamicCount?; let forward: DynamicCount?
    enum CodingKeys: String, CodingKey { case like, comment, forward }
}
struct DynamicCount: Codable { let count: Int? }
struct DynamicFeedData: Codable { let items: [DynamicItem]?; let has_more: Bool? }

struct DynamicCard: View {
    let item: DynamicItem
    @EnvironmentObject private var themeManager: ThemeManager

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            if let author = item.modules?.module_author {
                HStack(spacing: 8) {
                    BiliAvatar(url: author.face, size: 36)
                    VStack(alignment: .leading) {
                        Text(author.name ?? "")
                            .font(.subheadline).fontWeight(.medium)
                        if let time = author.pub_time {
                            Text(time).font(.caption2).foregroundColor(.secondary)
                        }
                    }
                    Spacer()
                }
            }
            if let text = item.modules?.module_dynamic?.desc?.text {
                Text(text).font(.subheadline).lineLimit(6)
            }
            if let major = item.modules?.module_dynamic?.major {
                switch major.type {
                case "MAJOR_TYPE_ARCHIVE":
                    if let archive = major.archive { videoCardFromArchive(archive) }
                case "MAJOR_TYPE_DRAW":
                    if let drawItems = major.draw?.items { drawGrid(drawItems) }
                case "MAJOR_TYPE_LIVE_RCMD":
                    if let live = major.live_rcmd {
                        Text(live.content ?? "直播中")
                            .font(.subheadline).foregroundColor(iOSCoral)
                            .padding(12).frame(maxWidth: .infinity)
                            .background(iOSCoral.opacity(0.1)).cornerRadius(8)
                    }
                default: EmptyView()
                }
            }
            if let stat = item.modules?.module_stat {
                HStack(spacing: 24) {
                    Label("\(stat.like?.count ?? 0)", systemImage: "hand.thumbsup")
                    Label("\(stat.comment?.count ?? 0)", systemImage: "text.bubble")
                    Label("\(stat.forward?.count ?? 0)", systemImage: "arrowshape.turn.up.right")
                }.font(.caption).foregroundColor(.secondary)
            }
        }
        .padding(14).background(Color(.systemBackground)).cornerRadius(12)
    }

    func videoCardFromArchive(_ archive: DynamicArchive) -> some View {
        HStack(spacing: 12) {
            BiliCover(url: archive.cover)
                .frame(width: 120, height: 72)
            VStack(alignment: .leading, spacing: 4) {
                Text(archive.title ?? "").font(.subheadline).lineLimit(2)
                HStack(spacing: 12) {
                    Label("\(archive.play ?? 0)", systemImage: "play.fill")
                    Label("\(archive.danmaku ?? 0)", systemImage: "text.bubble")
                }.font(.caption2).foregroundColor(.secondary)
            }
        }
        .padding(10).background(Color(.systemGray6)).cornerRadius(8)
    }

    func drawGrid(_ items: [DrawItem]) -> some View {
        let cols = items.count == 1 ? 1 : items.count == 2 ? 2 : 3
        return LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 4), count: cols), spacing: 4) {
            ForEach(Array(items.enumerated()), id: \.offset) { _, item in
                BiliCover(url: item.src, aspectRatio: 1)
            }
        }
    }
}
#Preview { DynamicScreen().environmentObject(ThemeManager.shared) }
