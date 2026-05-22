import Foundation

// MARK: - B站API端点定义

enum BiliHost {
    static let main = "api.bilibili.com"
    static let app = "app.bilibili.com"
    static let live = "api.live.bilibili.com"
    static let passport = "passport.bilibili.com"
}

// MARK: - 通用B站响应结构
struct BiliResponse<T: Codable>: Codable {
    let code: Int
    let message: String
    let data: T?
}

struct BiliEmptyData: Codable {}

// MARK: - BiliAPI
enum BiliAPI {

    // MARK: 用户/导航
    case navInfo
    case navStat
    case userCard(mid: Int64)
    case ipZone

    // MARK: 首页推荐
    case recommendFeed(params: [String: String])
    case mobileFeed(params: [String: String])
    case popularVideos(pn: Int, ps: Int)
    case rankingVideos(rid: Int, type: String)
    case regionVideos(rid: Int, pn: Int, ps: Int)

    // MARK: 视频播放
    case videoInfo(bvid: String)
    case playUrl(params: [String: String])
    case playUrlLegacy(bvid: String, cid: Int64, qn: Int, fnval: Int, platform: String, highQuality: Int)
    case videoDetail(bvid: String)
    case relatedVideos(bvid: String)
    case danmakuXml(cid: Int64)
    case danmakuProto(cid: Int64, segmentIndex: Int)
    case danmakuView(oid: Int64, pid: Int64)

    // MARK: 评论
    case replyList(oid: Int64, type: Int, sort: Int, pn: Int, ps: Int)
    case replyReply(rootRpid: Int64, oid: Int64, type: Int, pn: Int, ps: Int)
    case emotes

    // MARK: 直播
    case liveAreaList
    case liveList(parentAreaId: Int, areaId: Int, page: Int, pageSize: Int, sortType: String)
    case followedLive(page: Int, pageSize: Int)
    case liveRoomInit(roomId: Int64)
    case liveRoomDetail(roomId: Int64)
    case livePlayUrl(roomId: Int64, qn: Int)
    case danmuInfo(roomId: Int64)
    case danmuInfoWbi(params: [String: String])

    // MARK: 番剧
    case bangumiIndex
    case bangumiDetail(seasonId: Int64)
    case bangumiPlayUrl(seasonId: Int64, epId: Int64)

    // MARK: 搜索
    case search(keyword: String, page: Int, pageSize: Int)
    case searchSuggest(keyword: String)
    case searchHot

    // MARK: 动态
    case dynamicList(page: Int)
    case dynamicDetail(dynamicId: String)

    // MARK: 列表
    case historyList(ps: Int, max: Int64?, viewAt: Int64?, business: String?)
    case favFolders(mid: Int64)
    case favoriteList(mediaId: Int64, pn: Int, ps: Int)
    case watchLaterList

    // MARK: 用户交互
    case likeVideo(bvid: String, csrf: String)
    case coinVideo(bvid: String, count: Int, csrf: String)
    case favVideo(aid: Int64, mediaIds: [Int64], csrf: String)
    case followUser(mid: Int64, csrf: String)
    case addToWatchLater(aid: Int64, csrf: String)

    // MARK: 登录
    case qrCodeUrl
    case qrCodePoll(qrcodeKey: String)
    case refreshToken(refreshToken: String)

    // MARK: UP主空间
    case spaceInfo(mid: Int64)
    case spaceVideos(mid: Int64, pn: Int, ps: Int)
    case spaceDynamic(mid: Int64, pn: Int, ps: Int)

    // MARK: 搜索相关
    case searchTrending

    // MARK: 应用更新
    case appUpdateCheck

    // MARK: WBI密钥
    case navConfig
}

// MARK: - URL构建
extension BiliAPI {
    var baseHost: String {
        switch self {
        case .mobileFeed:
            return BiliHost.app
        case .liveList, .followedLive, .liveAreaList, .liveRoomInit,
                .liveRoomDetail, .livePlayUrl, .danmuInfo, .danmuInfoWbi:
            return BiliHost.live
        case .qrCodeUrl, .qrCodePoll, .refreshToken:
            return BiliHost.passport
        default:
            return BiliHost.main
        }
    }

    var scheme: String { "https" }

    var path: String {
        switch self {
        case .navInfo: return "/x/web-interface/nav"
        case .navStat: return "/x/web-interface/nav/stat"
        case .userCard: return "/x/web-interface/card"
        case .ipZone: return "/x/web-interface/zone"
        case .recommendFeed: return "/x/web-interface/wbi/index/top/feed/rcmd"
        case .mobileFeed: return "/x/v2/feed/index"
        case .popularVideos: return "/x/web-interface/popular"
        case .rankingVideos: return "/x/web-interface/ranking/v2"
        case .regionVideos: return "/x/web-interface/dynamic/region"
        case .videoInfo: return "/x/web-interface/view"
        case .playUrl: return "/x/player/wbi/playurl"
        case .playUrlLegacy: return "/x/player/playurl"
        case .videoDetail: return "/x/web-interface/view/detail"
        case .relatedVideos: return "/x/web-interface/archive/related"
        case .danmakuXml: return "/x/v1/dm/list.so"
        case .danmakuProto: return "/x/v2/dm/web/seg.so"
        case .danmakuView: return "/x/v2/dm/web/view"
        case .replyList: return "/x/v2/reply/wbi/main"
        case .replyReply: return "/x/v2/reply/reply"
        case .emotes: return "/x/web-interface/emote/list"
        case .liveAreaList: return "/room/v1/Area/getList"
        case .liveList: return "/room/v3/area/getRoomList"
        case .followedLive: return "/xlive/web-ucenter/user/following"
        case .liveRoomInit: return "/room/v1/Room/room_init"
        case .liveRoomDetail: return "/xlive/web-room/v1/index/getInfoByRoom"
        case .livePlayUrl: return "/xlive/web-room/v2/index/getRoomPlayInfo"
        case .danmuInfo: return "/xlive/web-room/v1/index/getDanmuInfo"
        case .danmuInfoWbi: return "/xlive/web-room/v1/index/getDanmuInfo"
        case .bangumiIndex: return "/x/web-interface/wbi/index/top/feed/rcmd"
        case .bangumiDetail: return "/pgc/view/web/season"
        case .bangumiPlayUrl: return "/pgc/player/web/v2/playurl"
        case .search: return "/x/web-interface/wbi/search/type"
        case .searchSuggest: return "/x/web-interface/wbi/search/default"
        case .searchHot: return "/x/web-interface/wbi/search/square"
        case .dynamicList: return "/x/polymer/web-dynamic/v1/feed/all"
        case .dynamicDetail: return "/x/polymer/web-dynamic/v1/detail"
        case .historyList: return "/x/web-interface/history/cursor"
        case .favFolders: return "/x/v3/fav/folder/created/list-all"
        case .favoriteList: return "/x/v3/fav/resource/list"
        case .watchLaterList: return "/x/v2/history/toview/web"
        case .likeVideo: return "/x/web-interface/archive/like"
        case .coinVideo: return "/x/web-interface/coin/add"
        case .favVideo: return "/x/v3/fav/resource/deal"
        case .followUser: return "/x/relation/modify"
        case .addToWatchLater: return "/x/v2/history/toview/add"
        case .qrCodeUrl: return "/x/passport-login/web/qrcode/generate"
        case .qrCodePoll: return "/x/passport-login/web/qrcode/poll"
        case .refreshToken: return "/x/passport-login/oauth2/refresh_token"
        case .spaceInfo: return "/x/space/wbi/acc/info"
        case .spaceVideos: return "/x/space/wbi/arc/search"
        case .spaceDynamic: return "/x/space/wbi/arc/search"
        case .searchTrending: return "/x/web-interface/wbi/index/top/feed/rcmd"
        case .appUpdateCheck: return "/x/resource/version"
        case .navConfig: return "/x/web-interface/wbi/index/nav/config"
        }
    }

    var queryItems: [URLQueryItem] {
        switch self {
        case .userCard(let mid):
            return [URLQueryItem(name: "mid", value: String(mid)), URLQueryItem(name: "photo", value: "true")]
        case .navInfo, .navStat, .ipZone, .emotes, .liveAreaList, .searchHot,
                .watchLaterList, .qrCodeUrl, .navConfig, .appUpdateCheck, .bangumiIndex, .searchTrending:
            return []
        case .recommendFeed(let params), .mobileFeed(let params), .danmuInfoWbi(let params):
            return params.map { URLQueryItem(name: $0.key, value: $0.value) }
        case .popularVideos(let pn, let ps):
            return [URLQueryItem(name: "pn", value: String(pn)), URLQueryItem(name: "ps", value: String(ps))]
        case .rankingVideos(let rid, let type):
            return [URLQueryItem(name: "rid", value: String(rid)), URLQueryItem(name: "type", value: type)]
        case .regionVideos(let rid, let pn, let ps):
            return [URLQueryItem(name: "rid", value: String(rid)), URLQueryItem(name: "pn", value: String(pn)), URLQueryItem(name: "ps", value: String(ps))]
        case .videoInfo(let bvid):
            return [URLQueryItem(name: "bvid", value: bvid)]
        case .playUrl(let params):
            return params.map { URLQueryItem(name: $0.key, value: $0.value) }
        case .playUrlLegacy(let bvid, let cid, let qn, let fnval, let platform, let highQuality):
            return [
                URLQueryItem(name: "bvid", value: bvid), URLQueryItem(name: "cid", value: String(cid)),
                URLQueryItem(name: "qn", value: String(qn)), URLQueryItem(name: "fnval", value: String(fnval)),
                URLQueryItem(name: "fnver", value: "0"), URLQueryItem(name: "fourk", value: "1"),
                URLQueryItem(name: "platform", value: platform), URLQueryItem(name: "high_quality", value: String(highQuality)),
            ]
        case .videoDetail(let bvid):
            return [URLQueryItem(name: "bvid", value: bvid)]
        case .relatedVideos(let bvid):
            return [URLQueryItem(name: "bvid", value: bvid)]
        case .danmakuXml(let cid):
            return [URLQueryItem(name: "oid", value: String(cid))]
        case .danmakuProto(let cid, let segmentIndex):
            return [URLQueryItem(name: "oid", value: String(cid)), URLQueryItem(name: "segment_index", value: String(segmentIndex))]
        case .danmakuView(let oid, let pid):
            return [URLQueryItem(name: "oid", value: String(oid)), URLQueryItem(name: "pid", value: String(pid))]
        case .replyList(let oid, let type, let sort, let pn, let ps):
            return [
                URLQueryItem(name: "oid", value: String(oid)), URLQueryItem(name: "type", value: String(type)),
                URLQueryItem(name: "sort", value: String(sort)), URLQueryItem(name: "pn", value: String(pn)),
                URLQueryItem(name: "ps", value: String(ps)),
            ]
        case .replyReply(let rootRpid, let oid, let type, let pn, let ps):
            return [
                URLQueryItem(name: "root", value: String(rootRpid)), URLQueryItem(name: "oid", value: String(oid)),
                URLQueryItem(name: "type", value: String(type)), URLQueryItem(name: "pn", value: String(pn)),
                URLQueryItem(name: "ps", value: String(ps)),
            ]
        case .liveList(let parentAreaId, let areaId, let page, let pageSize, let sortType):
            return [
                URLQueryItem(name: "parent_area_id", value: String(parentAreaId)),
                URLQueryItem(name: "area_id", value: String(areaId)),
                URLQueryItem(name: "page", value: String(page)),
                URLQueryItem(name: "page_size", value: String(pageSize)),
                URLQueryItem(name: "sort_type", value: sortType),
            ]
        case .followedLive(let page, let pageSize):
            return [URLQueryItem(name: "page", value: String(page)), URLQueryItem(name: "page_size", value: String(pageSize))]
        case .liveRoomInit(let roomId):
            return [URLQueryItem(name: "id", value: String(roomId))]
        case .liveRoomDetail(let roomId):
            return [URLQueryItem(name: "room_id", value: String(roomId))]
        case .livePlayUrl(let roomId, let qn):
            return [
                URLQueryItem(name: "room_id", value: String(roomId)),
                URLQueryItem(name: "protocol", value: "0,1"),
                URLQueryItem(name: "format", value: "0,1,2"),
                URLQueryItem(name: "codec", value: "0,1"),
                URLQueryItem(name: "qn", value: String(qn)),
                URLQueryItem(name: "platform", value: "web"),
            ]
        case .danmuInfo(let roomId):
            return [URLQueryItem(name: "id", value: String(roomId)), URLQueryItem(name: "type", value: "0")]
        case .bangumiDetail(let seasonId):
            return [URLQueryItem(name: "season_id", value: String(seasonId))]
        case .bangumiPlayUrl(let seasonId, let epId):
            return [URLQueryItem(name: "season_id", value: String(seasonId)), URLQueryItem(name: "ep_id", value: String(epId))]
        case .search(let keyword, let page, let pageSize):
            return [
                URLQueryItem(name: "keyword", value: keyword), URLQueryItem(name: "page", value: String(page)),
                URLQueryItem(name: "page_size", value: String(pageSize)), URLQueryItem(name: "search_type", value: "video"),
            ]
        case .searchSuggest(let keyword):
            return [URLQueryItem(name: "term", value: keyword)]
        case .dynamicList(let page):
            return [URLQueryItem(name: "page", value: String(page)), URLQueryItem(name: "type", value: "all")]
        case .dynamicDetail(let dynamicId):
            return [URLQueryItem(name: "id", value: dynamicId)]
        case .historyList(let ps, let max, let viewAt, let business):
            var items = [URLQueryItem(name: "ps", value: String(ps))]
            if let max { items.append(URLQueryItem(name: "max", value: String(max))) }
            if let viewAt { items.append(URLQueryItem(name: "view_at", value: String(viewAt))) }
            if let business { items.append(URLQueryItem(name: "business", value: business)) }
            return items
        case .favFolders(let mid):
            return [URLQueryItem(name: "up_mid", value: String(mid))]
        case .favoriteList(let mediaId, let pn, let ps):
            return [
                URLQueryItem(name: "media_id", value: String(mediaId)),
                URLQueryItem(name: "pn", value: String(pn)), URLQueryItem(name: "ps", value: String(ps)),
            ]
        case .spaceInfo(let mid):
            return [URLQueryItem(name: "mid", value: String(mid))]
        case .spaceVideos(let mid, let pn, let ps):
            return [URLQueryItem(name: "mid", value: String(mid)), URLQueryItem(name: "pn", value: String(pn)), URLQueryItem(name: "ps", value: String(ps))]
        case .spaceDynamic(let mid, let pn, let ps):
            return [URLQueryItem(name: "host_mid", value: String(mid)), URLQueryItem(name: "pn", value: String(pn)), URLQueryItem(name: "ps", value: String(ps))]
        case .qrCodePoll(let qrcodeKey):
            return [URLQueryItem(name: "qrcode_key", value: qrcodeKey)]
        case .refreshToken(let refreshToken):
            return [URLQueryItem(name: "refresh_token", value: refreshToken)]
        case .likeVideo, .coinVideo, .favVideo, .followUser, .addToWatchLater:
            return []
        }
    }

    var httpMethod: String {
        switch self {
        case .likeVideo, .coinVideo, .favVideo, .followUser, .addToWatchLater:
            return "POST"
        default:
            return "GET"
        }
    }

    var body: Data? {
        nil // 表单请求由ApiClient单独处理
    }

    var url: URL? {
        var components = URLComponents()
        components.scheme = scheme
        components.host = baseHost
        components.path = path
        if !queryItems.isEmpty {
            components.queryItems = queryItems
        }
        return components.url
    }
}
