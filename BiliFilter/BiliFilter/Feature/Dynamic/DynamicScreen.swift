import SwiftUI
import Combine

// MARK: - 动态页
struct DynamicScreen: View {
    @StateObject private var viewModel = DynamicViewModel()
    @EnvironmentObject private var themeManager: ThemeManager

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                if viewModel.isLoading && viewModel.items.isEmpty {
                    Spacer()
                    ProgressView().tint(themeManager.accentColor)
                    Spacer()
                } else if viewModel.items.isEmpty {
                    Spacer()
                    ContentUnavailableView("暂无动态", systemImage: "rectangle.3.group", description: Text("登录后可查看关注动态"))
                    Spacer()
                } else {
                    ScrollView {
                        LazyVStack(spacing: 8) {
                            ForEach(viewModel.items) { item in
                                DynamicCard(item: item)
                            }
                        }
                        .padding(12)
                    }
                    .refreshable { await viewModel.loadDynamics() }
                }
            }
            .background(themeManager.backgroundColor)
            .navigationTitle("动态")
        }
        .task { await viewModel.loadDynamics() }
    }
}

// MARK: - 动态ViewModel
@MainActor
final class DynamicViewModel: ObservableObject {
    @Published var items: [DynamicItem] = []
    @Published var isLoading = false

    func loadDynamics() async {
        isLoading = true
        defer { isLoading = false }
        do {
            let response: BiliApiResponse<DynamicFeedData> = try await ApiClient.shared.request(.dynamicList(page: 1))
            if response.isSuccess {
                items = response.data?.items ?? []
            }
        } catch {}
    }
}

// MARK: - 动态模型
struct DynamicItem: Identifiable, Codable {
    var id: String { id_str ?? UUID().uuidString }
    let id_str: String?
    let type: String?
    let modules: DynamicModules?

    enum CodingKeys: String, CodingKey { case id_str, type, modules }
}

struct DynamicModules: Codable {
    let module_author: DynamicAuthor?
    let module_dynamic: DynamicContent?
    let module_stat: DynamicStat?

    enum CodingKeys: String, CodingKey { case module_author, module_dynamic, module_stat }
}

struct DynamicAuthor: Codable {
    let name: String?
    let face: String?
    let mid: Int64?
    let pub_time: String?
    enum CodingKeys: String, CodingKey { case name, face, mid, pub_time }
}

struct DynamicContent: Codable {
    let desc: DynamicDesc?
    let major: DynamicMajor?
    enum CodingKeys: String, CodingKey { case desc, major }
}

struct DynamicDesc: Codable {
    let text: String?
    enum CodingKeys: String, CodingKey { case text }
}

struct DynamicMajor: Codable {
    let type: String?
    let archive: DynamicArchive?
    let draw: DynamicDraw?
    let live_rcmd: DynamicLive?
    enum CodingKeys: String, CodingKey { case type, archive, draw, live_rcmd }
}

struct DynamicArchive: Codable {
    let title: String?
    let cover: String?
    let bvid: String?
    let play: Int?
    let danmaku: Int?
    let duration_text: String?
    enum CodingKeys: String, CodingKey { case title, cover, bvid, play, danmaku, duration_text }
}

struct DynamicDraw: Codable {
    let items: [DrawItem]?
    enum CodingKeys: String, CodingKey { case items }
}

struct DrawItem: Codable {
    let src: String?
    let width: Int?
    let height: Int?
    enum CodingKeys: String, CodingKey { case src, width, height }
}

struct DynamicLive: Codable {
    let content: String?
    enum CodingKeys: String, CodingKey { case content }
}

struct DynamicStat: Codable {
    let like: DynamicCount?
    let comment: DynamicCount?
    let forward: DynamicCount?
    enum CodingKeys: String, CodingKey { case like, comment, forward }
}

struct DynamicCount: Codable {
    let count: Int?
    enum CodingKeys: String, CodingKey { case count }
}

struct DynamicFeedData: Codable {
    let items: [DynamicItem]?
    let has_more: Bool?
    enum CodingKeys: String, CodingKey { case items, has_more }
}

// MARK: - 动态卡片
struct DynamicCard: View {
    let item: DynamicItem
    @EnvironmentObject private var themeManager: ThemeManager

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // 用户头部
            if let author = item.modules?.module_author {
                HStack(spacing: 8) {
                    AsyncImage(url: URL(string: author.face ?? "")) { phase in
                        switch phase {
                        case .success(let img): img.resizable().scaledToFill()
                        default: Circle().fill(.gray)
                        }
                    }
                    .frame(width: 36, height: 36)
                    .clipShape(Circle())

                    VStack(alignment: .leading) {
                        Text(author.name ?? "")
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(themeManager.primaryTextColor)
                        if let time = author.pub_time {
                            Text(time)
                                .font(.caption2)
                                .foregroundColor(themeManager.tertiaryTextColor)
                        }
                    }
                    Spacer()
                }
            }

            // 内容文字
            if let text = item.modules?.module_dynamic?.desc?.text {
                Text(text)
                    .font(.subheadline)
                    .foregroundColor(themeManager.primaryTextColor)
                    .lineLimit(6)
            }

            // 内容卡片
            if let major = item.modules?.module_dynamic?.major {
                switch major.type {
                case "MAJOR_TYPE_ARCHIVE":
                    if let archive = major.archive {
                        videoCardFromArchive(archive)
                    }
                case "MAJOR_TYPE_DRAW":
                    if let drawItems = major.draw?.items {
                        drawGrid(drawItems)
                    }
                case "MAJOR_TYPE_LIVE_RCMD":
                    if let live = major.live_rcmd {
                        Text(live.content ?? "直播中")
                            .font(.subheadline)
                            .foregroundColor(iOSCoral)
                            .padding(12)
                            .frame(maxWidth: .infinity)
                            .background(iOSCoral.opacity(0.1))
                            .cornerRadius(8)
                    }
                default:
                    EmptyView()
                }
            }

            // 互动栏
            if let stat = item.modules?.module_stat {
                HStack(spacing: 24) {
                    Label("\(stat.like?.count ?? 0)", systemImage: "hand.thumbsup")
                    Label("\(stat.comment?.count ?? 0)", systemImage: "text.bubble")
                    Label("\(stat.forward?.count ?? 0)", systemImage: "arrowshape.turn.up.right")
                }
                .font(.caption)
                .foregroundColor(themeManager.tertiaryTextColor)
            }
        }
        .padding(14)
        .background(themeManager.surfaceColor)
        .cornerRadius(12)
    }

    func videoCardFromArchive(_ archive: DynamicArchive) -> some View {
        HStack(spacing: 12) {
            AsyncImage(url: URL(string: archive.cover ?? "")) { phase in
                switch phase {
                case .success(let img): img.resizable().scaledToFill()
                default: Rectangle().fill(themeManager.surfaceColor)
                }
            }
            .frame(width: 120, height: 72)
            .cornerRadius(6)

            VStack(alignment: .leading, spacing: 4) {
                Text(archive.title ?? "")
                    .font(.subheadline)
                    .foregroundColor(themeManager.primaryTextColor)
                    .lineLimit(2)
                HStack(spacing: 12) {
                    Label("\(archive.play ?? 0)", systemImage: "play.fill")
                    Label("\(archive.danmaku ?? 0)", systemImage: "text.bubble")
                }
                .font(.caption2)
                .foregroundColor(themeManager.secondaryTextColor)
            }
        }
        .padding(10)
        .background(themeManager.backgroundColor)
        .cornerRadius(8)
    }

    func drawGrid(_ items: [DrawItem]) -> some View {
        let columns = items.count == 1 ? 1 : items.count == 2 ? 2 : 3
        return LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 4), count: columns), spacing: 4) {
            ForEach(Array(items.enumerated()), id: \.offset) { _, item in
                AsyncImage(url: URL(string: item.src ?? "")) { phase in
                    switch phase {
                    case .success(let img): img.resizable().scaledToFill()
                    default: Rectangle().fill(themeManager.surfaceColor)
                    }
                }
                .aspectRatio(1, contentMode: .fill)
                .clipShape(RoundedRectangle(cornerRadius: 6))
            }
        }
    }
}

#Preview {
    DynamicScreen().environmentObject(ThemeManager.shared)
}
