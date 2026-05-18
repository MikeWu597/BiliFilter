import SwiftUI
import AVFoundation
import Combine

// MARK: - 播放器状态
enum PlayerState: Equatable {
    case idle
    case loading
    case playing
    case paused
    case buffering
    case error(String)
}

// MARK: - 播放器ViewModel
@MainActor
final class PlayerViewModel: ObservableObject {
    @Published var playerState: PlayerState = .idle
    @Published var currentTime: Double = 0
    @Published var duration: Double = 0
    @Published var isPlaying = false
    @Published var volume: Float = 1.0
    @Published var brightness: CGFloat = 0.5
    @Published var playbackSpeed: Float = 1.0
    @Published var showControls = true
    @Published var isFullscreen = false
    @Published var currentQuality: Int = 112
    @Published var danmakuEnabled = true
    @Published var danmakuAlpha: Double = 0.8
    @Published var danmakuFontScale: Double = 1.0
    @Published var videoInfo: ViewInfo?
    @Published var relatedVideos: [VideoItem] = []
    @Published var pages: [PageItem] = []
    @Published var currentPage: Int = 0
    @Published var availableQualities: [Int] = []
    @Published var errorMessage: String?

    private let repository = VideoRepository.shared
    var player: AVPlayer?
    private var timeObserver: Any?
    private var cancellables = Set<AnyCancellable>()

    let bvid: String
    let cid: Int64
    let aid: Int64

    init(bvid: String, cid: Int64 = 0, aid: Int64 = 0) {
        self.bvid = bvid
        self.cid = cid
        self.aid = aid
        setupBrightness()
    }

    private func setupBrightness() {
        brightness = UIScreen.main.brightness
    }

    func loadVideo() async {
        playerState = .loading
        do {
            let detail = try await repository.fetchVideoInfo(bvid: bvid)
            self.videoInfo = detail?.View
            self.relatedVideos = detail?.Related ?? []
            self.pages = detail?.View?.pages ?? []

            let effectiveCid = cid > 0 ? cid : (detail?.View?.cid ?? 0)
            let playData = try await repository.fetchPlayUrl(bvid: bvid, cid: effectiveCid, qn: currentQuality)
            if let dash = playData?.dash {
                await setupPlayer(dash: dash)
            } else if let durl = playData?.durl, let urlStr = durl.first?.url, let url = URL(string: urlStr) {
                await setupPlayer(url: url)
            }
            availableQualities = playData?.accept_quality ?? []
            playerState = .playing
        } catch {
            playerState = .error(error.localizedDescription)
            errorMessage = error.localizedDescription
        }
    }

    private func setupPlayer(dash: DashInfo) async {
        guard let videoStream = dash.video?.first,
              let videoUrl = URL(string: videoStream.baseUrl ?? "") else { return }

        let asset = AVURLAsset(url: videoUrl)
        let playerItem = AVPlayerItem(asset: asset)
        let newPlayer = AVPlayer(playerItem: playerItem)
        self.player = newPlayer

        addTimeObserver()
        newPlayer.play()
        isPlaying = true

        if let dur = dash.duration {
            duration = Double(dur)
        }
    }

    private func setupPlayer(url: URL) async {
        let playerItem = AVPlayerItem(url: url)
        let newPlayer = AVPlayer(playerItem: playerItem)
        self.player = newPlayer

        addTimeObserver()
        newPlayer.play()
        isPlaying = true
    }

    private func addTimeObserver() {
        timeObserver = player?.addPeriodicTimeObserver(forInterval: CMTime(seconds: 0.5, preferredTimescale: 600), queue: .main) { [weak self] time in
            self?.currentTime = time.seconds
            if let duration = self?.player?.currentItem?.duration.seconds, duration.isFinite {
                self?.duration = duration
            }
        }
    }

    func togglePlay() {
        guard let player = player else { return }
        if player.rate > 0 {
            player.pause()
            isPlaying = false
        } else {
            player.play()
            isPlaying = true
        }
    }

    func seek(to time: Double) {
        let cmTime = CMTime(seconds: time, preferredTimescale: 600)
        player?.seek(to: cmTime)
    }

    func seekForward(_ seconds: Double = 10) {
        let newTime = currentTime + seconds
        seek(to: min(newTime, duration))
    }

    func seekBackward(_ seconds: Double = 10) {
        let newTime = currentTime - seconds
        seek(to: max(newTime, 0))
    }

    func setSpeed(_ speed: Float) {
        playbackSpeed = speed
        player?.rate = speed
    }

    func setQuality(_ qn: Int) {
        currentQuality = qn
        Task { await loadVideo() }
    }

    func setVolume(_ newVolume: Float) {
        volume = newVolume
        player?.volume = newVolume
    }

    func setBrightness(_ newBrightness: CGFloat) {
        brightness = newBrightness
        UIScreen.main.brightness = newBrightness
    }

    func toggleFullscreen() {
        isFullscreen.toggle()
    }

    func switchPage(_ index: Int) {
        guard index < pages.count, pages[index].cid != nil else { return }
        currentPage = index
        Task { await loadVideo() }
    }

    func cleanup() {
        player?.pause()
        player = nil
        if let observer = timeObserver {
            player?.removeTimeObserver(observer)
        }
        timeObserver = nil
    }
}
