import Foundation
import Combine
import SwiftUI

// MARK: - 数据模型
struct WatchedVideo: Codable, Identifiable, Equatable {
    var id: String { bvid }
    let bvid: String
    let title: String
    let coverUrl: String
    let watchedAt: Date
}

// MARK: - 观看历史管理器
@MainActor
final class WatchHistoryManager: ObservableObject {
    static let shared = WatchHistoryManager()

    private let defaults = UserDefaults.standard
    private let storageKey = "watch_history"
    private let maxCount = 1000

    @Published private(set) var videos: [WatchedVideo] = []

    private init() {
        load()
    }

    // MARK: - 加载/保存
    private func load() {
        guard let data = defaults.data(forKey: storageKey),
              let decoded = try? JSONDecoder().decode([WatchedVideo].self, from: data) else {
            return
        }
        videos = decoded.sorted { $0.watchedAt > $1.watchedAt }
    }

    private func save() {
        guard let data = try? JSONEncoder().encode(videos) else { return }
        defaults.set(data, forKey: storageKey)
    }

    // MARK: - 添加记录
    func add(bvid: String, title: String, coverUrl: String) {
        guard !bvid.isEmpty else { return }

        // 移除已存在的相同 bvid
        videos.removeAll { $0.bvid == bvid }

        // 添加新记录到开头
        let video = WatchedVideo(
            bvid: bvid,
            title: title,
            coverUrl: coverUrl,
            watchedAt: Date()
        )
        videos.insert(video, at: 0)

        // 限制最大数量
        if videos.count > maxCount {
            videos = Array(videos.prefix(maxCount))
        }

        save()
    }

    // MARK: - 删除记录
    func remove(at offsets: IndexSet) {
        videos.remove(atOffsets: offsets)
        save()
    }

    func remove(bvid: String) {
        videos.removeAll { $0.bvid == bvid }
        save()
    }

    // MARK: - 清空
    func clear() {
        videos.removeAll()
        save()
    }

    // MARK: - 查询
    func contains(bvid: String) -> Bool {
        videos.contains { $0.bvid == bvid }
    }

    // MARK: - 搜索
    func search(keyword: String) -> [WatchedVideo] {
        guard !keyword.trimmingCharacters(in: .whitespaces).isEmpty else {
            return videos
        }
        let lowercased = keyword.lowercased()
        return videos.filter { $0.title.lowercased().contains(lowercased) }
    }

    // MARK: - 导入/导出
    var allVideos: [WatchedVideo] { videos }

    func importVideos(_ newVideos: [WatchedVideo]) {
        var merged = videos
        let existingBvids = Set(videos.map(\.bvid))

        for video in newVideos {
            if !existingBvids.contains(video.bvid) {
                merged.append(video)
            }
        }

        videos = merged.sorted { $0.watchedAt > $1.watchedAt }
        if videos.count > maxCount {
            videos = Array(videos.prefix(maxCount))
        }
        save()
    }
}
