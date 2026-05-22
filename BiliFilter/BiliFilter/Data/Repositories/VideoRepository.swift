import Foundation

actor VideoRepository {
    static let shared = VideoRepository()
    private let api = ApiClient.shared
    private let guestApi = ApiClient.guest

    private var wbiImgKey: String = ""
    private var wbiSubKey: String = ""
    private var wbiKeysTimestamp: Int64 = 0
    private let wbiCacheDurationMs: Int64 = 30 * 60 * 1000

    // MARK: - 首页推荐

    func fetchRecommendFeed() async throws -> [RecommendItem] {
        let (imgKey, subKey) = try await getWbiKeys()
        let params: [String: String] = [
            "ps": "30", "fresh_type": "3", "fresh_idx": "1",
            "fresh_idx_1h": "1", "brush": "0", "feed_version": String(Int64(Date().timeIntervalSince1970 * 1000)), "y_num": "1"
        ]
        let signedParams = WbiSign.sign(params: params, imgKey: imgKey, subKey: subKey)
        let response: BiliApiResponse<RecommendData> = try await api.request(.recommendFeed(params: signedParams), needsWbi: false)
        guard response.isSuccess, let data = response.data else {
            throw ApiError.biliError(code: response.code, message: response.message)
        }
        return data.item ?? []
    }

    // MARK: - 视频详情

    func fetchVideoInfo(bvid: String) async throws -> ViewInfo? {
        let resp: BiliApiResponse<ViewInfo> = try await api.request(.videoInfo(bvid: bvid))
        guard resp.isSuccess else { throw ApiError.biliError(code: resp.code, message: resp.message) }
        return resp.data
    }

    // MARK: - 播放地址 (iOS AVPlayer优先策略: DURL直接URL > DASH)

    func fetchPlayUrl(bvid: String, cid: Int64, qn: Int = 80) async throws -> PlayUrlData? {
        // fnval=4049 = 4048(DASH/HLS/Dolby/8K/AV1) + 1(MP4直链), 确保durl有值
        for q in [qn, 80, 64, 32, 16] {
            if let data = try? await fetchPlayUrlWbi(bvid: bvid, cid: cid, qn: q, fnval: 4049),
               data.durl?.isEmpty == false || data.dash?.video?.isEmpty == false {
                return data
            }
        }
        // 旧版API兜底: fnval=1 纯MP4
        for q in [80, 64, 32] {
            if let data = try? await fetchPlayUrlLegacy(bvid: bvid, cid: cid, qn: q) {
                return data
            }
        }
        return nil
    }

    private func fetchPlayUrlWbi(bvid: String, cid: Int64, qn: Int, fnval: Int = 80) async throws -> PlayUrlData? {
        let (imgKey, subKey) = try await getWbiKeys()
        var params: [String: String] = [
            "bvid": bvid, "cid": String(cid), "qn": String(qn),
            "fnval": String(fnval), "fnver": "0", "fourk": "1",
            "voice_balance": "1", "gaia_source": "pre-load",
            "isGaiaAvoided": "true", "web_location": "1315873"
        ]
        let signed = WbiSign.sign(params: params, imgKey: imgKey, subKey: subKey)
        let resp: BiliApiResponse<PlayUrlData> = try await api.request(.playUrl(params: signed), needsWbi: false)
        guard resp.isSuccess, let data = resp.data else { return nil }
        return data
    }

    func fetchPlayUrlLegacy(bvid: String, cid: Int64, qn: Int) async throws -> PlayUrlData? {
        let resp: BiliApiResponse<PlayUrlData> = try await guestApi.request(
            .playUrlLegacy(bvid: bvid, cid: cid, qn: qn, fnval: 1, platform: "html5", highQuality: qn >= 64 ? 1 : 0)
        )
        guard resp.isSuccess, let data = resp.data else { return nil }
        return data
    }

    // MARK: - WBI Keys (对齐BiliPai: 从getNavInfo提取wbi_img)

    private func getWbiKeys() async throws -> (String, String) {
        let now = Int64(Date().timeIntervalSince1970 * 1000)
        if !wbiImgKey.isEmpty && !wbiSubKey.isEmpty && (now - wbiKeysTimestamp) < wbiCacheDurationMs {
            print("[Repo] using cached WBI keys")
            return (wbiImgKey, wbiSubKey)
        }
        if let cachedImg = UserDefaults.standard.string(forKey: "wbi_img_key"),
           let cachedSub = UserDefaults.standard.string(forKey: "wbi_sub_key"),
           !cachedImg.isEmpty, !cachedSub.isEmpty {
            wbiImgKey = cachedImg; wbiSubKey = cachedSub; wbiKeysTimestamp = now
            print("[Repo] using stored WBI keys")
            return (wbiImgKey, wbiSubKey)
        }
        print("[Repo] fetching WBI keys from nav...")
        let resp: BiliApiResponse<NavWbiData> = try await api.request(.navInfo)
        print("[Repo] nav response code=\(resp.code), hasWbi=\(resp.data?.wbi_img != nil)")
        guard resp.isSuccess, let wbiImg = resp.data?.wbi_img else {
            throw ApiError.invalidResponse
        }
        let imgKey = wbiImg.img_url.components(separatedBy: "/").last?.components(separatedBy: ".").first ?? ""
        let subKey = wbiImg.sub_url.components(separatedBy: "/").last?.components(separatedBy: ".").first ?? ""
        print("[Repo] WBI imgKey=\(imgKey.prefix(8))... subKey=\(subKey.prefix(8))...")
        UserDefaults.standard.set(imgKey, forKey: "wbi_img_key")
        UserDefaults.standard.set(subKey, forKey: "wbi_sub_key")
        wbiImgKey = imgKey; wbiSubKey = subKey; wbiKeysTimestamp = now
        return (imgKey, subKey)
    }

    func fetchRegionVideos(rid: Int, pn: Int = 1, ps: Int = 30) async throws -> [VideoItem] {
        let r: BiliApiResponse<DynamicRegionData> = try await api.request(.regionVideos(rid: rid, pn: pn, ps: ps))
        guard r.isSuccess else { throw ApiError.biliError(code: r.code, message: r.message) }
        return r.data?.archives ?? []
    }

    func fetchPopularVideos(pn: Int = 1, ps: Int = 20) async throws -> PopularData? {
        let r: BiliApiResponse<PopularData> = try await api.request(.popularVideos(pn: pn, ps: ps))
        guard r.isSuccess else { throw ApiError.biliError(code: r.code, message: r.message) }
        return r.data
    }

    // MARK: - 评论

    func fetchReplies(oid: Int64, mode: Int = 2, pn: Int = 1, ps: Int = 20, next: Int? = nil) async throws -> ReplyData? {
        let endpoint = BiliAPI.replyList(oid: oid, type: 1, mode: mode, pn: pn, ps: ps, next: next)
        print("[Reply] fetchReplies pn=\(pn) next=\(next.map(String.init) ?? "nil") url=\(endpoint.url?.absoluteString ?? "nil")")
        let resp: BiliApiResponse<ReplyData> = try await api.request(
            endpoint,
            needsWbi: true
        )
        guard resp.isSuccess else { throw ApiError.biliError(code: resp.code, message: resp.message) }
        return resp.data
    }

    func fetchSubReplies(oid: Int64, rootRpid: Int64, pn: Int = 1, ps: Int = 20) async throws -> ReplyData? {
        let resp: BiliApiResponse<ReplyData> = try await api.request(
            .replyReply(rootRpid: rootRpid, oid: oid, type: 1, pn: pn, ps: ps),
            needsWbi: true
        )
        guard resp.isSuccess else { throw ApiError.biliError(code: resp.code, message: resp.message) }
        return resp.data
    }
}

struct DynamicRegionData: Codable { let archives: [VideoItem]? }
struct PopularData: Codable { let list: [VideoItem]?; let num: Int? }

// 从nav接口获取wbi_img的模型
struct NavWbiData: Codable {
    let wbi_img: WbiImgInfo?
    enum CodingKeys: String, CodingKey { case wbi_img }
}
struct WbiImgInfo: Codable {
    let img_url: String; let sub_url: String
    enum CodingKeys: String, CodingKey { case img_url, sub_url }
}

// 从nav接口获取wbi_img的模型在文件末尾
// 播放/视频详情模型 (被PlayerViewModel引用)

struct ViewInfo: Codable {
    let bvid: String?; let aid: Int64?; let title: String?; let pic: String?; let desc: String?
    let duration: Int?; let owner: OwnerInfo?; let stat: StatInfo?; let cid: Int64?
    let pages: [PageItem]?; let pubdate: Int64?
    enum CodingKeys: String, CodingKey { case bvid, aid, title, pic, desc, duration, owner, stat, cid, pages, pubdate }
}
struct PageItem: Codable, Identifiable {
    var id: Int64 { cid ?? 0 }; let cid: Int64?; let page: Int?; let part: String?; let duration: Int?
    enum CodingKeys: String, CodingKey { case cid, page, part, duration }
}
struct PlayUrlData: Codable {
    let accept_description: [String]?; let accept_format: String?; let accept_quality: [Int]?
    let dash: DashInfo?; let durl: [DurlInfo]?; let format: String?; let quality: Int?
    enum CodingKeys: String, CodingKey { case accept_description, accept_format, accept_quality, dash, durl, format, quality }
}
struct DashInfo: Codable {
    let video: [DashStream]?; let audio: [DashStream]?; let duration: Int?
    enum CodingKeys: String, CodingKey { case video, audio, duration }
}
struct DashStream: Codable {
    let id: Int?; let baseUrl: String?; let backupUrl: [String]?; let bandwidth: Int?
    let mimeType: String?; let codecs: String?; let width: Int?; let height: Int?; let frameRate: String?
    enum CodingKeys: String, CodingKey { case id, baseUrl, backupUrl, bandwidth, mimeType, codecs, width, height, frameRate }
}
struct DurlInfo: Codable {
    let url: String?; let backup_url: [String]?; let size: Int64?; let length: Int?
    enum CodingKeys: String, CodingKey { case url, backup_url, size, length }
}
