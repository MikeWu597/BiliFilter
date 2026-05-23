import SwiftUI
import Combine

// MARK: - 空间视频模型（字段与B站API一致）
struct SpaceVideoData: Codable {
    let list: SpaceVideoList?
    let page: SpacePage?
}
struct SpaceVideoList: Codable {
    let vlist: [SpaceVideoItem]?
}
struct SpacePage: Codable {
    let pn: Int?
    let ps: Int?
    let count: Int?
}
struct SpaceVideoItem: Codable {
    let aid: Int64
    let bvid: String
    let title: String?
    let pic: String?
    let play: Int?
    let comment: Int?
    let length: String?
    let created: Int64?
    let author: String?
    let mid: Int64?
    var duration: Int {
        guard let len = length else { return 0 }
        let parts = len.components(separatedBy: ":")
        if parts.count == 2, let m = Int(parts[0]), let s = Int(parts[1]) { return m * 60 + s }
        return Int(len) ?? 0
    }
    func toVideoItem() -> VideoItem {
        VideoItem(id: aid, bvid: bvid, title: title ?? "", pic: pic ?? "", duration: duration, pubdate: created, owner: OwnerInfo(mid: mid ?? 0, name: author ?? "", face: ""), stat: StatInfo(view: play, danmaku: comment, reply: nil, favorite: nil, coin: nil, share: nil, like: nil), cid: nil)
    }
}

// MARK: - 空间信息模型
struct SpaceUserInfo: Codable {
    let mid: Int64?
    let name: String?
    let sex: String?
    let face: String?
    let sign: String?
    let level: Int?
    let fans: Int?
    let friend: Int?
    let attention: Int?
}
// MARK: - 用户空间页
struct SpaceScreen: View {
    let mid: Int64
    @StateObject private var viewModel = SpaceViewModel()
    @EnvironmentObject private var themeManager: ThemeManager

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                headerSection
                videoGridSection
            }
        }
        .background(themeManager.backgroundColor.ignoresSafeArea())
        .navigationTitle(viewModel.userName.isEmpty ? "用户空间" : viewModel.userName)
        .navigationBarTitleDisplayMode(.inline)
        .task { await viewModel.load(mid: mid) }
    }

    private var headerSection: some View {
        VStack(spacing: 12) {
            BiliAvatar(url: viewModel.face, size: 72)
            VStack(spacing: 4) {
                Text(viewModel.userName.isEmpty ? "加载中..." : viewModel.userName)
                    .font(.title3).fontWeight(.bold)
                if let level = viewModel.level {
                    Text("Lv\(level)")
                        .font(.caption).foregroundColor(.white)
                        .padding(.horizontal, 8).padding(.vertical, 2)
                        .background(Color.orange).cornerRadius(8)
                }
            }
            HStack(spacing: 24) {
                VStack { Text(formatCount(viewModel.following)).font(.headline); Text("关注").font(.caption2).foregroundColor(.secondary) }
                VStack { Text(formatCount(viewModel.followers)).font(.headline); Text("粉丝").font(.caption2).foregroundColor(.secondary) }
            }
            if !viewModel.sign.isEmpty {
                Text(viewModel.sign)
                    .font(.subheadline).foregroundColor(.secondary)
                    .lineLimit(3).padding(.horizontal, 24)
            }
        }
        .padding(.vertical, 20)
        .frame(maxWidth: .infinity)
        .background(themeManager.backgroundColor)
    }

    private var videoGridSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("投稿").font(.headline).padding(.horizontal, 16).padding(.top, 8)
            if viewModel.isLoading && viewModel.videos.isEmpty {
                HStack { Spacer(); ProgressView(); Spacer() }.padding(.vertical, 40)
            } else if !viewModel.videos.isEmpty {
                LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 16) {
                    ForEach(viewModel.videos) { video in
                        let reason = FilterSettings.shared.checkVideo(duration: video.duration, title: video.title)
                        VideoCardView(
                            coverUrl: video.pic,
                            title: video.title,
                            upName: video.owner?.name ?? "",
                            playCount: video.stat?.viewCount ?? 0,
                            danmakuCount: video.stat?.danmakuCount ?? 0,
                            duration: video.duration,
                            bvid: video.bvid.isEmpty ? nil : video.bvid,
                            cid: video.cid,
                            filterReason: reason,
                            ownerMid: video.owner?.mid
                        )
                    }
                }
                .padding(.horizontal, 12)
                if viewModel.hasMore {
                    HStack { Spacer(); ProgressView().scaleEffect(0.8); Spacer() }
                        .padding(.vertical, 16)
                        .onAppear { Task { await viewModel.loadMore() } }
                }
            } else if let err = viewModel.errorMsg {
                Button { Task { await viewModel.load(mid: mid) } } label: {
                    Label(err, systemImage: "arrow.clockwise").font(.caption).foregroundColor(.secondary)
                }.padding(.vertical, 40).frame(maxWidth: .infinity)
            }
        }
    }
}

// MARK: - 用户空间ViewModel
@MainActor
final class SpaceViewModel: ObservableObject {
    @Published var userName = ""
    @Published var face = ""
    @Published var level: Int?
    @Published var sign = ""
    @Published var following = 0
    @Published var followers = 0
    @Published var videos: [VideoItem] = []
    @Published var isLoading = false
    @Published var hasMore = true
    @Published var errorMsg: String?

    private var mid: Int64 = 0
    private var page = 1

    func load(mid: Int64) async {
        self.mid = mid
        isLoading = true
        errorMsg = nil
        await withTaskGroup(of: Void.self) { group in
            group.addTask { await self.loadSpaceInfo() }
            group.addTask { await self.loadVideos() }
        }
        isLoading = false
    }

    private func loadSpaceInfo() async {
        do {
            let resp: BiliApiResponse<SpaceUserInfo> = try await ApiClient.shared.request(.spaceInfo(mid: mid), needsWbi: true)
            print("[Space] info code=\(resp.code)")
            if resp.isSuccess, let data = resp.data {
                print("[Space] raw: name=\(data.name ?? "nil") face=\(data.face?.prefix(30) ?? "nil") level=\(data.level ?? -1)")
                userName = data.name ?? ""
                face = data.face ?? ""
                level = data.level
                sign = data.sign ?? ""
            }
        } catch {
            print("[Space] info error: \(error)")
        }
        // 单独获取关注/粉丝数
        do {
            let url = URL(string: "https://api.bilibili.com/x/relation/stat?vmid=\(mid)")!
            var req = URLRequest(url: url)
            req.setValue("Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36", forHTTPHeaderField: "User-Agent")
            let (data, _) = try await URLSession.shared.data(for: req)
            if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
               let d = json["data"] as? [String: Any] {
                following = d["following"] as? Int ?? 0
                followers = d["follower"] as? Int ?? 0
                print("[Space] relation following=\(following) followers=\(followers)")
            }
        } catch {
            print("[Space] relation error: \(error)")
        }
    }

    private func loadVideos() async {
        page = 1
        do {
            let resp: BiliApiResponse<SpaceVideoData> = try await ApiClient.shared.request(.spaceVideos(mid: mid, pn: page, ps: 30), needsWbi: true)
            print("[Space] videos code=\(resp.code)")
            if resp.isSuccess, let data = resp.data {
                let items = data.list?.vlist ?? []
                print("[Space] got \(items.count) videos, pageCount=\(data.page?.count ?? 0)")
                videos = items.map { $0.toVideoItem() }
                hasMore = items.count >= 30
            }
        } catch {
            print("[Space] videos error: \(error)")
        }
    }

    func loadMore() async {
        guard hasMore else { return }
        page += 1
        do {
            let resp: BiliApiResponse<SpaceVideoData> = try await ApiClient.shared.request(.spaceVideos(mid: mid, pn: page, ps: 30), needsWbi: true)
            if resp.isSuccess, let data = resp.data {
                let items = data.list?.vlist ?? []
                videos.append(contentsOf: items.map { $0.toVideoItem() })
                hasMore = items.count >= 30
            }
        } catch {
            print("[Space] loadMore error: \(error)")
        }
    }
}
