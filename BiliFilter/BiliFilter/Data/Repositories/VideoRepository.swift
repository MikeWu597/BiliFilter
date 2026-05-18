import Foundation

// MARK: - 视频仓库
actor VideoRepository {
    static let shared = VideoRepository()

    private let api = ApiClient.shared

    // MARK: - 首页推荐 (Web端)
    func fetchRecommendFeed() async throws -> [RecommendItem] {
        let feedParams: [String: String] = [
            "fresh_type": "3",
            "version": "1",
            "ps": "30",
            "fresh_idx_1h": "1",
            "fresh_idx": "1",
            "brush": "0",
        ]
        let apiCall = BiliAPI.recommendFeed(params: feedParams)
        let response: BiliApiResponse<RecommendData> = try await api.request(apiCall, needsWbi: true)
        guard response.isSuccess, let data = response.data else {
            throw ApiError.biliError(code: response.code, message: response.message)
        }
        return data.item ?? []
    }

    // MARK: - 视频详情
    func fetchVideoInfo(bvid: String) async throws -> VideoDetailData? {
        let response: BiliApiResponse<VideoDetailData> = try await api.request(.videoInfo(bvid: bvid))
        guard response.isSuccess else {
            throw ApiError.biliError(code: response.code, message: response.message)
        }
        return response.data
    }

    // MARK: - 播放地址
    func fetchPlayUrl(bvid: String, cid: Int64, qn: Int = 112) async throws -> PlayUrlData? {
        let response: BiliApiResponse<PlayUrlData> = try await api.request(
            .playUrl(bvid: bvid, cid: cid, qn: qn, fnval: 4048),
            needsWbi: true
        )
        guard response.isSuccess else {
            throw ApiError.biliError(code: response.code, message: response.message)
        }
        return response.data
    }

    // MARK: - 相关视频
    func fetchRelatedVideos(bvid: String) async throws -> [VideoItem] {
        let response: BiliApiResponse<[VideoItem]> = try await api.request(.relatedVideos(bvid: bvid))
        guard response.isSuccess else {
            throw ApiError.biliError(code: response.code, message: response.message)
        }
        return response.data ?? []
    }

    // MARK: - 热门视频
    func fetchPopularVideos(pn: Int = 1, ps: Int = 20) async throws -> PopularData? {
        let response: BiliApiResponse<PopularData> = try await api.request(.popularVideos(pn: pn, ps: ps))
        guard response.isSuccess else {
            throw ApiError.biliError(code: response.code, message: response.message)
        }
        return response.data
    }

    // MARK: - 分区视频
    func fetchRegionVideos(rid: Int, pn: Int = 1, ps: Int = 30) async throws -> [VideoItem] {
        let response: BiliApiResponse<DynamicRegionData> = try await api.request(.regionVideos(rid: rid, pn: pn, ps: ps))
        guard response.isSuccess, let data = response.data else {
            throw ApiError.biliError(code: response.code, message: response.message)
        }
        return data.archives ?? []
    }
}

// MARK: - 视频详情数据模型
struct VideoDetailData: Codable {
    let View: ViewInfo?
    let Related: [VideoItem]?
    let Card: CardInfo?
    let Tags: [TagInfo]?

    enum CodingKeys: String, CodingKey {
        case View, Related, Card, Tags
    }
}

struct ViewInfo: Codable {
    let bvid: String?
    let aid: Int64?
    let title: String?
    let pic: String?
    let desc: String?
    let duration: Int?
    let owner: OwnerInfo?
    let stat: StatInfo?
    let cid: Int64?
    let pages: [PageItem]?
    let pubdate: Int64?
    let rights: RightsInfo?
    let ugc_season: UgcSeason?

    enum CodingKeys: String, CodingKey {
        case bvid, aid, title, pic, desc, duration, owner, stat, cid, pages, pubdate, rights, ugc_season
    }
}

struct PageItem: Codable, Identifiable {
    var id: Int64 { cid ?? 0 }
    let cid: Int64?
    let page: Int?
    let part: String?
    let duration: Int?

    enum CodingKeys: String, CodingKey {
        case cid, page, part, duration
    }
}

struct RightsInfo: Codable {
    let download: Int?
    let movie: Int?
    let pay: Int?
    let hd5: Int?
    let no_reprint: Int?

    enum CodingKeys: String, CodingKey {
        case download, movie, pay, hd5, no_reprint
    }
}

struct UgcSeason: Codable {
    let id: Int64?
    let title: String?
    let cover: String?
}

struct CardInfo: Codable {
    let card: CardDetail?
    let follower: Int?
    let archive_count: Int?

    enum CodingKeys: String, CodingKey {
        case card, follower, archive_count
    }
}

struct CardDetail: Codable {
    let mid: String?
    let name: String?
    let face: String?
}

struct TagInfo: Codable, Identifiable {
    var id: Int { tag_id ?? 0 }
    let tag_id: Int?
    let tag_name: String?

    enum CodingKeys: String, CodingKey {
        case tag_id, tag_name
    }
}

// MARK: - 播放地址数据
struct PlayUrlData: Codable {
    let accept_description: [String]?
    let accept_format: String?
    let accept_quality: [Int]?
    let dash: DashInfo?
    let durl: [DurlInfo]?
    let format: String?
    let quality: Int?

    enum CodingKeys: String, CodingKey {
        case accept_description, accept_format, accept_quality, dash, durl, format, quality
    }
}

struct DashInfo: Codable {
    let video: [DashStream]?
    let audio: [DashStream]?
    let duration: Int?

    enum CodingKeys: String, CodingKey {
        case video, audio, duration
    }
}

struct DashStream: Codable {
    let id: Int?
    let baseUrl: String?
    let backupUrl: [String]?
    let bandwidth: Int?
    let mimeType: String?
    let codecs: String?
    let width: Int?
    let height: Int?
    let frameRate: String?

    enum CodingKeys: String, CodingKey {
        case id, baseUrl, backupUrl, bandwidth, mimeType, codecs, width, height, frameRate
    }
}

struct DurlInfo: Codable {
    let url: String?
    let backup_url: [String]?
    let size: Int64?
    let length: Int?

    enum CodingKeys: String, CodingKey {
        case url, backup_url, size, length
    }
}

// PopularData 和 DynamicRegionData 已移至 BiliResponse.swift
