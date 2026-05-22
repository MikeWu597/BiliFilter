import SwiftUI
import AVFoundation
import Combine
import Compression

enum PlayerState: Equatable {
    case idle, loading, ready, playing, paused, buffering
    case error(String)
}

@MainActor
final class PlayerViewModel: ObservableObject {
    @Published var playerState: PlayerState = .idle
    @Published var currentTime: Double = 0
    @Published var duration: Double = 0
    @Published var isPlaying = false
    @Published var volume: Float = 1.0
    @Published var brightness: CGFloat = UIScreen.main.brightness
    @Published var playbackSpeed: Float = 1.0
    @Published var showControls = true
    @Published var isFullscreen = false
    @Published var currentQuality: Int = 80
    @Published var danmakuEnabled = true
    @Published var danmakuAlpha: Double = 0.8
    @Published var danmakuFontScale: Double = 1.0
    @Published var videoInfo: ViewInfo?
    @Published var relatedVideos: [VideoItem] = []
    @Published var pages: [PageItem] = []
    @Published var availableQualities: [Int] = []
    @Published var currentPage: Int = 0
    @Published var danmakuItems: [DanmakuItem] = []
    @Published var replyItems: [ReplyItem] = []
    @Published var isLoadingReplies = false
    @Published var replyErrorMessage: String?
    @Published var errorMessage: String?
    // 子回复（楼中楼）
    @Published var expandedReplies: [Int64: [ReplyItem]] = [:]
    @Published var loadingSubReplies: Set<Int64> = []

    private var replyCursor: ReplyCursor?
    private var replyPage = 1
    var hasMoreReplies: Bool {
        guard let cursor = replyCursor else { return false }
        return cursor.next > 0 && replyPage < 50
    }

    var player: AVPlayer?
    private var timeObserver: Any?
    private var statusObserver: NSKeyValueObservation?

    let bvid: String; let cid: Int64; let aid: Int64

    init(bvid: String, cid: Int64 = 0, aid: Int64 = 0) {
        self.bvid = bvid; self.cid = cid; self.aid = aid
    }

    private let repo = VideoRepository.shared

    private let videoHeaders: [String: String] = [
        "User-Agent": "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36",
        "Referer": "https://www.bilibili.com",
    ]

    func loadVideo() async {
        playerState = .loading
        // 配置音频会话: 播放模式(忽略静音开关)、后台播放
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .moviePlayback)
            try AVAudioSession.sharedInstance().setActive(true)
        } catch { print("[Player] audio session error: \(error)") }
        print("[Player] loadVideo bvid=\(bvid) cid=\(cid)")

        // 1. 获取视频信息
        let info: ViewInfo?
        do {
            info = try await repo.fetchVideoInfo(bvid: bvid)
        } catch {
            print("[Player] fetchVideoInfo error: \(error)")
            playerState = .error("视频信息加载失败: \(error.localizedDescription)")
            return
        }
        guard let info = info else {
            print("[Player] fetchVideoInfo returned nil")
            playerState = .error("视频信息为空")
            return
        }
        videoInfo = info
        pages = info.pages ?? []
        let realCid = cid > 0 ? cid : (info.cid ?? 0)
        print("[Player] videoInfo ok, title=\(info.title ?? "?"), cid=\(realCid)")

        // 加载弹幕
        Task { await loadDanmaku(cid: realCid) }
        // 加载评论
        Task { await loadReplies() }

        // 2. 获取播放地址
        do {
            guard let data = try await repo.fetchPlayUrl(bvid: bvid, cid: realCid, qn: currentQuality) else {
                print("[Player] fetchPlayUrl returned nil")
                playerState = .error("获取播放地址失败")
                return
            }
            availableQualities = data.accept_quality ?? []
            print("[Player] playUrl ok, quality=\(data.quality ?? 0), durl=\(data.durl?.count ?? 0), dashV=\(data.dash?.video?.count ?? 0), dashA=\(data.dash?.audio?.count ?? 0)")

            // 3. 开始播放 — durl直链(MP4/FLV)优先, DASH降级
            if let durlList = data.durl, let url = extractPlayableUrl(from: durlList) {
                startPlayback(url: url)
                print("[Player] playing durl")
            } else if let dash = data.dash {
                startDashPlayback(dash: dash)
                if let dur = dash.duration { duration = Double(dur) }
            } else {
                playerState = .error("无可播放的视频流")
            }
        } catch {
            print("[Player] fetchPlayUrl error: \(error)")
            playerState = .error("播放地址获取失败: \(error.localizedDescription)")
        }
    }

    private func extractPlayableUrl(from durl: [DurlInfo]) -> URL? {
        for item in durl {
            for raw in [item.url, item.backup_url?.first].compactMap({ $0 }) {
                let fixed = raw.hasPrefix("http") ? raw : "https:\(raw)"
                if let url = URL(string: fixed) { return url }
            }
        }
        return nil
    }

    private func startPlayback(url: URL) {
        print("[Player] startPlayback url=\(url.absoluteString.prefix(80))...")
        let asset = AVURLAsset(url: url, options: ["AVURLAssetHTTPHeaderFieldsKey": videoHeaders])
        let item = AVPlayerItem(asset: asset)
        let p = AVPlayer(playerItem: item)
        p.automaticallyWaitsToMinimizeStalling = false
        player = p

        statusObserver?.invalidate()
        statusObserver = item.observe(\.status, options: [.new, .initial]) { [weak self] item, _ in
            Task { @MainActor in
                switch item.status {
                case .readyToPlay:
                    print("[Player] item readyToPlay, duration=\(item.duration.seconds)")
                    self?.playerState = .playing
                case .failed:
                    let msg = item.error?.localizedDescription ?? "未知错误"
                    print("[Player] item failed: \(msg)")
                    self?.playerState = .error("播放失败: \(msg)")
                default: break
                }
            }
        }
        addTimeObserver()
        p.play()
        isPlaying = true
        print("[Player] play() called")
    }

    private func startDashPlayback(dash: DashInfo) {
        guard let videoStream = dash.video?.first,
              let videoUrl = URL(string: fixUrl(videoStream.baseUrl)) else {
            playerState = .error("DASH视频流不可用"); return
        }
        let audioUrl: URL? = dash.audio?.first.flatMap { URL(string: fixUrl($0.baseUrl)) }

        let videoAsset = AVURLAsset(url: videoUrl, options: ["AVURLAssetHTTPHeaderFieldsKey": videoHeaders])

        guard let audioUrl = audioUrl else {
            // 无独立音轨, 直接播视频
            startPlayback(url: videoUrl)
            return
        }

        let audioAsset = AVURLAsset(url: audioUrl, options: ["AVURLAssetHTTPHeaderFieldsKey": videoHeaders])
        let composition = AVMutableComposition()

        Task {
            do {
                // 加载轨道
                let videoTracks = try await videoAsset.loadTracks(withMediaType: .video)
                let audioTracks = try await audioAsset.loadTracks(withMediaType: .audio)
                let videoDuration = try await videoAsset.load(.duration)

                guard let vTrack = videoTracks.first else {
                    playerState = .error("DASH无视频轨"); return
                }
                let compVideoTrack = composition.addMutableTrack(withMediaType: .video, preferredTrackID: kCMPersistentTrackID_Invalid)
                try compVideoTrack?.insertTimeRange(CMTimeRange(start: .zero, duration: videoDuration), of: vTrack, at: .zero)

                if let aTrack = audioTracks.first {
                    let compAudioTrack = composition.addMutableTrack(withMediaType: .audio, preferredTrackID: kCMPersistentTrackID_Invalid)
                    try compAudioTrack?.insertTimeRange(CMTimeRange(start: .zero, duration: videoDuration), of: aTrack, at: .zero)
                }

                let item = AVPlayerItem(asset: composition)
                let p = AVPlayer(playerItem: item)
                p.automaticallyWaitsToMinimizeStalling = false
                self.player = p

                self.statusObserver?.invalidate()
                self.statusObserver = item.observe(\.status, options: [.new, .initial]) { [weak self] item, _ in
                    Task { @MainActor in
                        switch item.status {
                        case .readyToPlay: self?.playerState = .playing
                        case .failed: self?.playerState = .error(item.error?.localizedDescription ?? "DASH播放失败")
                        default: break
                        }
                    }
                }
                addTimeObserver()
                p.play()
                isPlaying = true
                print("[Player] DASH playback started (video+audio merged)")
            } catch {
                print("[Player] DASH composition failed: \(error), trying video-only...")
                startPlayback(url: videoUrl)
            }
        }
    }

    private func fixUrl(_ raw: String?) -> String {
        guard let raw else { return "" }
        return raw.hasPrefix("http") ? raw : "https:\(raw)"
    }

    private func addTimeObserver() {
        timeObserver = player?.addPeriodicTimeObserver(forInterval: CMTime(seconds: 0.5, preferredTimescale: 600), queue: .main) { [weak self] time in
            self?.currentTime = time.seconds
            if let d = self?.player?.currentItem?.duration.seconds, d.isFinite, d > 0 { self?.duration = d }
        }
    }

    func togglePlay() {
        guard let p = player else { return }
        if p.rate > 0 { p.pause(); isPlaying = false } else { p.play(); isPlaying = true }
    }
    func seek(to time: Double) { player?.seek(to: CMTime(seconds: time, preferredTimescale: 600)) }
    func seekForward(_ s: Double = 10) { seek(to: min(currentTime + s, duration)) }
    func seekBackward(_ s: Double = 10) { seek(to: max(currentTime - s, 0)) }
    func setSpeed(_ s: Float) { playbackSpeed = s; player?.rate = s }
    func setVolume(_ v: Float) { volume = v; player?.volume = v }
    func setBrightness(_ b: CGFloat) { brightness = b; UIScreen.main.brightness = b }
    func toggleFullscreen() { isFullscreen.toggle() }
    func setQuality(_ qn: Int) { currentQuality = qn; Task { await loadVideo() } }
    func switchPage(_ i: Int) {
        guard i < pages.count else { return }
        currentPage = i; Task { await loadVideo() }
    }
    private func loadDanmaku(cid: Int64) async {
        guard cid > 0 else { return }
        do {
            let data = try await fetchDanmakuRaw(cid: cid)
            if let xml = String(data: data, encoding: .utf8) {
                danmakuItems = DanmakuParser.parse(xml: xml)
            } else if data.count > 0 {
                danmakuItems = DanmakuParser.parseProto(data: data)
            }
            print("[Player] loaded \(danmakuItems.count) danmaku items")
        } catch {
            print("[Player] danmaku error: \(error)")
        }
    }

    func loadReplies() async {
        let oid = videoInfo?.aid ?? aid
        guard oid > 0, !isLoadingReplies else { return }
        isLoadingReplies = true
        replyErrorMessage = nil
        do {
        replyPage = 1
            let data = try await repo.fetchReplies(oid: oid, pn: replyPage)
            replyItems = data?.replies ?? []
            replyCursor = data?.cursor
            print("[Reply] INIT page=\(replyPage) loaded=\(replyItems.count) allCount=\(data?.cursor?.allCount ?? -1) isEnd=\(data?.cursor?.isEnd) next=\(data?.cursor?.next)")
        } catch {
            replyErrorMessage = error.localizedDescription
            print("[Player] reply error: \(error)")
        }
        isLoadingReplies = false
    }

    func loadMoreReplies() async {
        guard hasMoreReplies, !isLoadingReplies else {
            print("[Reply] loadMoreReplies SKIP hasMore=\(hasMoreReplies) loading=\(isLoadingReplies)")
            return
        }
        let oid = videoInfo?.aid ?? aid
        guard oid > 0 else { return }
        isLoadingReplies = true
        do {
        replyPage += 1
            print("[Reply] loadMoreReplies START page=\(replyPage) currentCount=\(replyItems.count)")
            let data = try await repo.fetchReplies(oid: oid, pn: replyPage)
            let newItems = data?.replies ?? []
            let existingIds = Set(replyItems.map(\.rpid))
            let uniqueItems = newItems.filter { !existingIds.contains($0.rpid) }
            if uniqueItems.isEmpty {
                replyCursor = nil
                print("[Reply] loadMoreReplies STOP: all \(newItems.count) items already loaded")
            } else {
                replyItems.append(contentsOf: uniqueItems)
                replyCursor = data?.cursor
                print("[Reply] loadMoreReplies DONE page=\(replyPage) got=\(uniqueItems.count) new, \(newItems.count - uniqueItems.count) dup, total=\(replyItems.count) isEnd=\(data?.cursor?.isEnd) next=\(data?.cursor?.next)")
            }
        } catch {
            print("[Reply] loadMoreReplies ERROR: \(error)")
        }
        isLoadingReplies = false
    }

    func toggleSubReplies(for rpid: Int64) {
        if expandedReplies[rpid] != nil {
            expandedReplies[rpid] = nil
        } else {
            Task { await loadSubReplies(for: rpid) }
        }
    }

    private func loadSubReplies(for rpid: Int64) async {
        guard !loadingSubReplies.contains(rpid) else { return }
        let oid = videoInfo?.aid ?? aid
        guard oid > 0 else { return }
        loadingSubReplies.insert(rpid)
        do {
            let data = try await repo.fetchSubReplies(oid: oid, rootRpid: rpid)
            expandedReplies[rpid] = data?.replies ?? []
        } catch {
            print("[Player] loadSubReplies error: \(error)")
        }
        loadingSubReplies.remove(rpid)
    }

    private func fetchDanmakuRaw(cid: Int64) async throws -> Data {
        let urlStr = "https://api.bilibili.com/x/v1/dm/list.so?oid=\(cid)"
        guard let url = URL(string: urlStr) else { throw ApiError.invalidURL }
        var req = URLRequest(url: url)
        req.setValue("Mozilla/5.0", forHTTPHeaderField: "User-Agent")
        req.setValue("https://www.bilibili.com", forHTTPHeaderField: "Referer")
        let (data, _) = try await URLSession.shared.data(for: req)

        // 检查是否需要解压
        if let firstByte = data.first, firstByte != 0x3C { // 不以 '<' 开头 = 压缩数据
            var stream = InputStream(data: data)
            // 跳过可能的前导字节
            return try decompressDeflate(data)
        }
        return data
    }

    private func decompressDeflate(_ data: Data) throws -> Data {
        // 跳过zlib头(2字节CMF+FLG), 处理raw deflate
        let src = data.count > 2 ? data.subdata(in: 2..<data.count) : data
        let bufferSize = src.count * 5
        var result = Data(count: bufferSize)
        let actualSize = result.withUnsafeMutableBytes { dest in
            src.withUnsafeBytes { source in
                compression_decode_buffer(
                    dest.baseAddress!.assumingMemoryBound(to: UInt8.self), bufferSize,
                    source.baseAddress!.assumingMemoryBound(to: UInt8.self), src.count,
                    nil, COMPRESSION_ZLIB
                )
            }
        }
        guard actualSize > 0 else { return data } // 解压失败返回原始数据
        result.count = actualSize
        return result
    }

    func cleanup() {
        player?.pause(); statusObserver?.invalidate()
        if let o = timeObserver { player?.removeTimeObserver(o) }
        player = nil; timeObserver = nil
        try? AVAudioSession.sharedInstance().setActive(false)
    }
}
