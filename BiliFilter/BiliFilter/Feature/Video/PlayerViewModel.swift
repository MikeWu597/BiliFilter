import SwiftUI
import AVFoundation
import Combine

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
    @Published var errorMessage: String?

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
        let cid = cid > 0 ? cid : (info.cid ?? 0)
        print("[Player] videoInfo ok, title=\(info.title ?? "?"), cid=\(cid)")

        // 2. 获取播放地址
        do {
            guard let data = try await repo.fetchPlayUrl(bvid: bvid, cid: cid, qn: currentQuality) else {
                print("[Player] fetchPlayUrl returned nil")
                playerState = .error("获取播放地址失败")
                return
            }
            availableQualities = data.accept_quality ?? []
            print("[Player] playUrl ok, quality=\(data.quality ?? 0), durl=\(data.durl?.count ?? 0), dash=\(data.dash?.video?.count ?? 0)")

            // 3. 开始播放 — durl直链(MP4/FLV)优先, DASH降级
            if let durlList = data.durl, let url = extractPlayableUrl(from: durlList) {
                startPlayback(url: url)
                print("[Player] playing durl")
            } else if let dash = data.dash,
                      let raw = dash.video?.first?.baseUrl ?? dash.video?.first?.backupUrl?.first,
                      let url = URL(string: raw.hasPrefix("http") ? raw : "https:\(raw)") {
                startPlayback(url: url)
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
    func cleanup() {
        player?.pause(); statusObserver?.invalidate()
        if let o = timeObserver { player?.removeTimeObserver(o) }
        player = nil; timeObserver = nil
    }
}
