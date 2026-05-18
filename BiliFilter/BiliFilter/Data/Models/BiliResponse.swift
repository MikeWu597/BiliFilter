import Foundation

// MARK: - 通用B站API响应
struct BiliApiResponse<T: Codable>: Codable {
    let code: Int
    let message: String
    let data: T?
    var isSuccess: Bool { code == 0 }
    var errorMessage: String { message }
}

struct EmptyData: Codable {}

// MARK: - 视频基础模型
struct VideoItem: Codable, Identifiable {
    let id: Int64
    let bvid: String
    let aid: Int64?
    let title: String
    let pic: String
    let duration: Int
    let pubdate: Int64?
    let owner: OwnerInfo?
    let stat: StatInfo?
    let cid: Int64?
    let desc: String?
    let short_link: String?

    var durationText: String { formatSeconds(duration) }

    enum CodingKeys: String, CodingKey {
        case id, bvid, aid, title, pic, duration, pubdate, owner, stat, cid, desc, short_link
    }

    init(id: Int64 = 0, bvid: String = "", aid: Int64? = nil, title: String, pic: String, duration: Int = 0, pubdate: Int64? = nil, owner: OwnerInfo? = nil, stat: StatInfo? = nil, cid: Int64? = nil, desc: String? = nil, short_link: String? = nil) {
        self.id = id
        self.bvid = bvid
        self.aid = aid
        self.title = title
        self.pic = pic
        self.duration = duration
        self.pubdate = pubdate
        self.owner = owner
        self.stat = stat
        self.cid = cid
        self.desc = desc
        self.short_link = short_link
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeIfPresent(Int64.self, forKey: .id) ?? 0
        bvid = try container.decodeIfPresent(String.self, forKey: .bvid) ?? ""
        aid = try container.decodeIfPresent(Int64.self, forKey: .aid)
        title = try container.decodeIfPresent(String.self, forKey: .title) ?? ""
        pic = try container.decodeIfPresent(String.self, forKey: .pic) ?? ""
        duration = try container.decodeIfPresent(Int.self, forKey: .duration) ?? 0
        pubdate = try container.decodeIfPresent(Int64.self, forKey: .pubdate)
        owner = try container.decodeIfPresent(OwnerInfo.self, forKey: .owner)
        stat = try container.decodeIfPresent(StatInfo.self, forKey: .stat)
        cid = try container.decodeIfPresent(Int64.self, forKey: .cid)
        desc = try container.decodeIfPresent(String.self, forKey: .desc)
        short_link = try container.decodeIfPresent(String.self, forKey: .short_link)
    }
}

func formatSeconds(_ seconds: Int) -> String {
    guard seconds > 0 else { return "0:00" }
    let h = seconds / 3600
    let m = (seconds % 3600) / 60
    let s = seconds % 60
    if h > 0 { return String(format: "%d:%02d:%02d", h, m, s) }
    return String(format: "%d:%02d", m, s)
}

func formatCount(_ count: Int) -> String {
    if count >= 10000 { return String(format: "%.1f万", Double(count) / 10000.0) }
    return String(count)
}

// MARK: - UP主信息
struct OwnerInfo: Codable {
    let mid: Int64
    let name: String
    let face: String
    enum CodingKeys: String, CodingKey { case mid, name, face }
}

// MARK: - 统计数据
struct StatInfo: Codable {
    let view: Int?
    let danmaku: Int?
    let reply: Int?
    let favorite: Int?
    let coin: Int?
    let share: Int?
    let like: Int?
    var viewCount: Int { view ?? 0 }
    var danmakuCount: Int { danmaku ?? 0 }
    var replyCount: Int { reply ?? 0 }
    var likeCount: Int { like ?? 0 }
    enum CodingKeys: String, CodingKey { case view, danmaku, reply, favorite, coin, share, like }
}

// MARK: - 推荐响应 (B站实际返回格式)
struct RecommendResponse: Codable {
    let code: Int
    let message: String?
    let data: RecommendData?
}

struct RecommendData: Codable {
    let item: [RecommendItem]?
    let business_card: BusinessCard?
}

struct RecommendItem: Codable {
    let id: Int
    let bvid: String
    let cid: Int
    let goto: String?
    let uri: String?
    let pic: String?
    let title: String?
    let duration: Int
    let pubdate: Int64?
    let owner: OwnerInfo?
    let stat: StatInfo?
    let rcmd_reason: RcmdReason?
    let args: RecommendArgs?
    let three_point: ThreePoint?
}

struct RcmdReason: Codable {
    let content: String?
    enum CodingKeys: String, CodingKey { case content }
}

struct RecommendArgs: Codable {
    let up_id: Int64?
    let up_name: String?
    let aid: Int64?
    let rid: Int?
    let rname: String?
    let tid: Int?
    let tname: String?
    let cover: String?
    let aid_v2: Int64?
}

struct ThreePoint: Codable {
    let dislike_reasons: [DislikeReason]?
    let feedbacks: [FeedbackItem]?
}

struct DislikeReason: Codable {
    let id: Int
    let name: String
}

struct FeedbackItem: Codable {
    let id: Int
    let name: String
}

struct BusinessCard: Codable {}

// MARK: - 导航信息
struct NavResponse: Codable {
    let code: Int
    let message: String?
    let data: NavData?
}

struct NavData: Codable {
    let isLogin: Bool?
    let mid: Int64?
    let uname: String?
    let face: String?
    let money: Double?
    let wallet: WalleInfo?
    let pendant: PendantInfo?
    let level_info: LevelInfo?
    enum CodingKeys: String, CodingKey { case isLogin, mid, uname, face, money, wallet, pendant, level_info }
}

struct WalleInfo: Codable {
    let bcoin_balance: Int?
    let coupon_balance: Int?
}

struct PendantInfo: Codable {
    let pid: Int
    let name: String?
    let image: String?
}

struct LevelInfo: Codable {
    let current_level: Int?
    let current_exp: Int?
}

// MARK: - 空间
struct SpaceResponse: Codable {
    let code: Int
    let message: String?
    let data: SpaceData?
}

struct SpaceData: Codable {
    let mid: Int64?
    let name: String?
    let sex: String?
    let face: String?
    let sign: String?
    let level: Int?
    let fans: Int?
    let friend: Int?
    let attention: Int?
    enum CodingKeys: String, CodingKey { case mid, name, sex, face, sign, level, fans, friend, attention }
}

// MARK: - 热门
struct PopularData: Codable {
    let list: [VideoItem]?
    let num: Int?
    enum CodingKeys: String, CodingKey { case list, num }
}

struct DynamicRegionData: Codable {
    let archives: [VideoItem]?
    enum CodingKeys: String, CodingKey { case archives }
}

// MARK: - 搜索
struct SearchResponse: Codable {
    let code: Int
    let message: String?
    let data: SearchData?
}

struct SearchData: Codable {
    let result: [SearchResultItem]?
    let numResults: Int?
    let numPages: Int?
    enum CodingKeys: String, CodingKey { case result, numResults, numPages }
}

struct SearchResultItem: Codable {
    let type: String?
    let id: Int64?
    let bvid: String?
    let aid: Int64?
    let title: String?
    let author: String?
    let mid: Int64?
    let pic: String?
    let duration: String?
    let pubdate: Int64?
    let play: Int?
    let danmaku: Int?
    enum CodingKeys: String, CodingKey { case type, id, bvid, aid, title, author, mid, pic, duration, pubdate, play, danmaku }
}

// MARK: - 历史
struct HistoryResponse: Codable {
    let code: Int
    let message: String?
    let data: HistoryData?
}

struct HistoryData: Codable {
    let cursor: HistoryCursor?
    let list: [HistoryItem]?
}

struct HistoryCursor: Codable {
    let max: Int64?
    let view_at: Int64?
    let ps: Int?
    let has_more: Bool?
}

struct HistoryItem: Codable, Identifiable {
    var id: Int64 { oid ?? 0 }
    let oid: Int64?
    let epid: Int64?
    let bvid: String?
    let title: String?
    let cover: String?
    let author_name: String?
    let author_mid: Int64?
    let duration: Int?
    let progress: Int?
    let view_at: Int64?
    let badge: String?
    let business: String?
    let cid: Int64?
    enum CodingKeys: String, CodingKey { case oid, epid, bvid, title, cover, author_name, author_mid, duration, progress, view_at, badge, business, cid }
}

// MARK: - 收藏
struct FavFolderResponse: Codable {
    let code: Int
    let message: String?
    let data: FavFolderData?
}

struct FavFolderData: Codable {
    let list: [FavFolder]?
    let count: Int?
}

struct FavFolder: Codable, Identifiable {
    var id: Int64 { media_id ?? 0 }
    let media_id: Int64?
    let title: String?
    let cover: String?
    let intro: String?
    let media_count: Int?
    let fav_count: Int?
    let mid: Int64?
}
