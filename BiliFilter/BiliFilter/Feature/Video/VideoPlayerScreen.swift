import SwiftUI
import AVKit

// MARK: - 视频播放器
struct VideoPlayerScreen: View {
    @StateObject private var viewModel: PlayerViewModel
    @EnvironmentObject private var themeManager: ThemeManager
    @Environment(\.dismiss) private var dismiss
    @State private var showQualityMenu = false
    @State private var showSpeedMenu = false
    @State private var showSettings = false
    @State private var showDanmakuSettings = false
    @State private var showPageSelector = false
    @State private var controlsTimer: Timer?
    @State private var dragOffset: CGFloat = 0
    @State private var isDragSeeking = false

    init(bvid: String, cid: Int64 = 0, aid: Int64 = 0) {
        _viewModel = StateObject(wrappedValue: PlayerViewModel(bvid: bvid, cid: cid, aid: aid))
    }

    var body: some View {
        GeometryReader { geo in
            ZStack {
                Color.black.ignoresSafeArea()

                VStack(spacing: 0) {
                    // 播放器区域
                    playerArea(size: geo.size)

                    if !viewModel.isFullscreen {
                        // 竖屏信息区域
                        videoInfoSection
                    }
                }
            }
        }
        .navigationBarHidden(viewModel.isFullscreen)
        .statusBarHidden(viewModel.isFullscreen)
        .task { await viewModel.loadVideo() }
        .onDisappear { viewModel.cleanup() }
        .onTapGesture { toggleControls() }
        .gesture(volumeBrightnessGesture)
        .overlay(alignment: .topTrailing) {
            if viewModel.showControls {
                topControls
            }
        }
        .overlay(alignment: .bottom) {
            if viewModel.showControls {
                bottomControls
            }
        }
        .overlay(alignment: .center) {
            if viewModel.playerState == .loading {
                ProgressView()
                    .tint(.white)
                    .scaleEffect(1.5)
            }
        }
        .sheet(isPresented: $showQualityMenu) { qualityMenu }
        .sheet(isPresented: $showSpeedMenu) { speedMenu }
        .sheet(isPresented: $showDanmakuSettings) { danmakuSettings }
        .sheet(isPresented: $showPageSelector) { pageSelector }
    }

    // MARK: - 播放器
    @ViewBuilder
    private func playerArea(size: CGSize) -> some View {
        ZStack {
            if let player = viewModel.player {
                VideoPlayer(player: player)
            } else {
                Rectangle().fill(.black)
            }

            // 弹幕层
            if viewModel.danmakuEnabled {
                DanmakuOverlay(
                    currentTime: viewModel.currentTime,
                    alpha: viewModel.danmakuAlpha,
                    fontScale: viewModel.danmakuFontScale
                )
            }

            // 中心播放按钮
            if viewModel.showControls && viewModel.playerState != .loading {
                HStack(spacing: 40) {
                    Button { viewModel.seekBackward() } label: {
                        Image(systemName: "gobackward.10")
                            .font(.title)
                            .foregroundColor(.white)
                    }
                    Button { viewModel.togglePlay() } label: {
                        Image(systemName: viewModel.isPlaying ? "pause.circle.fill" : "play.circle.fill")
                            .font(.system(size: 56))
                            .foregroundColor(.white)
                    }
                    Button { viewModel.seekForward() } label: {
                        Image(systemName: "goforward.10")
                            .font(.title)
                            .foregroundColor(.white)
                    }
                }
            }
        }
        .frame(
            width: viewModel.isFullscreen ? size.width : size.width,
            height: viewModel.isFullscreen ? size.height : size.width * 9/16
        )
    }

    // MARK: - 顶部控制
    private var topControls: some View {
        HStack {
            Button { dismiss() } label: {
                Image(systemName: "chevron.left")
                    .font(.title3)
                    .foregroundColor(.white)
                    .padding(12)
                    .background(Circle().fill(.ultraThinMaterial))
            }
            Spacer()
            Button { showDanmakuSettings = true } label: {
                Image(systemName: "list.bullet.rectangle")
                    .font(.title3)
                    .foregroundColor(.white)
                    .padding(12)
                    .background(Circle().fill(.ultraThinMaterial))
            }
            Button { showSettings = true } label: {
                Image(systemName: "ellipsis")
                    .font(.title3)
                    .foregroundColor(.white)
                    .padding(12)
                    .background(Circle().fill(.ultraThinMaterial))
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 48)
    }

    // MARK: - 底部控制
    private var bottomControls: some View {
        VStack(spacing: 8) {
            // 进度条
            Slider(value: $viewModel.currentTime, in: 0...max(viewModel.duration, 1)) { editing in
                isDragSeeking = editing
                if !editing { viewModel.seek(to: viewModel.currentTime) }
            }
            .tint(themeManager.accentColor)
            .padding(.horizontal)

            // 时间 + 按钮
            HStack {
                Text(formatTime(viewModel.currentTime))
                    .font(.caption)
                    .foregroundColor(.white)
                Text("/")
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.6))
                Text(formatTime(viewModel.duration))
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.6))

                Spacer()

                Button { showPageSelector = true } label: {
                    Image(systemName: "list.number")
                        .font(.body)
                        .foregroundColor(.white)
                }
                Button { showSpeedMenu = true } label: {
                    Text("\(String(format: "%.1f", viewModel.playbackSpeed))x")
                        .font(.caption)
                        .foregroundColor(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(.ultraThinMaterial)
                        .cornerRadius(4)
                }
                Button { showQualityMenu = true } label: {
                    Text("画质")
                        .font(.caption)
                        .foregroundColor(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(.ultraThinMaterial)
                        .cornerRadius(4)
                }
                Button { viewModel.toggleFullscreen() } label: {
                    Image(systemName: viewModel.isFullscreen ? "arrow.down.right.and.arrow.up.left" : "arrow.up.left.and.arrow.down.right")
                        .font(.body)
                        .foregroundColor(.white)
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 12)
        }
        .background(
            LinearGradient(colors: [.clear, .black.opacity(0.6)], startPoint: .top, endPoint: .bottom)
        )
    }

    // MARK: - 视频信息
    private var videoInfoSection: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                if let info = viewModel.videoInfo {
                    Text(info.title ?? "")
                        .font(.headline)
                        .foregroundColor(themeManager.primaryTextColor)
                        .lineLimit(2)
                        .padding(.horizontal, 16)
                        .padding(.top, 12)

                    // UP主信息
                    HStack {
                        BiliAvatar(url: info.owner?.face, size: 40)

                        VStack(alignment: .leading) {
                            Text(info.owner?.name ?? "")
                                .font(.subheadline)
                                .fontWeight(.medium)
                                .foregroundColor(themeManager.primaryTextColor)
                            if let stat = info.stat {
                                HStack(spacing: 12) {
                                    Label("\(stat.viewCount)", systemImage: "play.fill")
                                    Label("\(stat.danmakuCount)", systemImage: "text.bubble")
                                    Label("\(stat.likeCount)", systemImage: "hand.thumbsup")
                                }
                                .font(.caption)
                                .foregroundColor(themeManager.secondaryTextColor)
                            }
                        }
                        Spacer()
                        Button {
                            // 关注操作
                        } label: {
                            Text("+ 关注")
                                .font(.caption)
                                .fontWeight(.medium)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 6)
                                .background(themeManager.accentColor)
                                .foregroundColor(.white)
                                .cornerRadius(14)
                        }
                    }
                    .padding(.horizontal, 16)

                    // 简介
                    if let desc = info.desc, !desc.isEmpty {
                        Text(desc)
                            .font(.subheadline)
                            .foregroundColor(themeManager.secondaryTextColor)
                            .lineLimit(3)
                            .padding(.horizontal, 16)
                    }
                }

                // 相关视频
                if !viewModel.relatedVideos.isEmpty {
                    Text("相关推荐")
                        .font(.headline)
                        .foregroundColor(themeManager.primaryTextColor)
                        .padding(.horizontal, 16)
                        .padding(.top, 4)

                    ForEach(viewModel.relatedVideos) { video in
                        VideoCardView(
                            coverUrl: video.pic,
                            title: video.title,
                            upName: video.owner?.name ?? "",
                            playCount: video.stat?.viewCount ?? 0,
                            danmakuCount: video.stat?.danmakuCount ?? 0,
                            duration: video.duration
                        )
                        .padding(.horizontal, 16)
                    }
                }
            }
            .padding(.bottom, 32)
        }
        .background(themeManager.backgroundColor)
    }

    // MARK: - 手势 (亮度/音量)
    private var volumeBrightnessGesture: some Gesture {
        DragGesture(minimumDistance: 20)
            .onChanged { value in
                let halfWidth = UIScreen.main.bounds.width / 2
                let location = value.startLocation
                let translation = value.translation

                if location.x < halfWidth {
                    // 左侧 - 亮度
                    let change = -translation.height / 500
                    viewModel.setBrightness(min(1, max(0, viewModel.brightness + change)))
                } else {
                    // 右侧 - 音量
                    let change = -translation.height / 500
                    viewModel.setVolume(min(1, max(0, viewModel.volume + Float(change))))
                }
            }
    }

    private func toggleControls() {
        withAnimation(.easeInOut(duration: 0.3)) {
            viewModel.showControls.toggle()
        }
        if viewModel.showControls {
            startControlsTimer()
        }
    }

    private func startControlsTimer() {
        controlsTimer?.invalidate()
        controlsTimer = Timer.scheduledTimer(withTimeInterval: 3, repeats: false) { _ in
            withAnimation(.easeInOut(duration: 0.3)) {
                viewModel.showControls = false
            }
        }
    }

    // MARK: - Sheets
    private var qualityMenu: some View {
        NavigationStack {
            List {
                ForEach(viewModel.availableQualities, id: \.self) { qn in
                    Button {
                        viewModel.setQuality(qn)
                        showQualityMenu = false
                    } label: {
                        HStack {
                            Text(qualityName(qn))
                                .foregroundColor(themeManager.primaryTextColor)
                            Spacer()
                            if qn == viewModel.currentQuality {
                                Image(systemName: "checkmark")
                                    .foregroundColor(themeManager.accentColor)
                            }
                        }
                    }
                }
            }
            .navigationTitle("画质选择")
            .navigationBarTitleDisplayMode(.inline)
        }
        .presentationDetents([.medium])
    }

    private var speedMenu: some View {
        NavigationStack {
            List {
                ForEach([0.5, 0.75, 1.0, 1.25, 1.5, 2.0], id: \.self) { speed in
                    Button {
                        viewModel.setSpeed(Float(speed))
                        showSpeedMenu = false
                    } label: {
                        HStack {
                            Text("\(String(format: "%.1f", speed))x")
                                .foregroundColor(themeManager.primaryTextColor)
                            Spacer()
                            if Float(speed) == viewModel.playbackSpeed {
                                Image(systemName: "checkmark")
                                    .foregroundColor(themeManager.accentColor)
                            }
                        }
                    }
                }
            }
            .navigationTitle("播放速度")
            .navigationBarTitleDisplayMode(.inline)
        }
        .presentationDetents([.medium])
    }

    private var danmakuSettings: some View {
        NavigationStack {
            List {
                Toggle("弹幕开关", isOn: $viewModel.danmakuEnabled)
                VStack(alignment: .leading) {
                    Text("透明度: \(String(format: "%.0f%%", viewModel.danmakuAlpha * 100))")
                    Slider(value: $viewModel.danmakuAlpha, in: 0.1...1.0)
                }
                VStack(alignment: .leading) {
                    Text("字体缩放: \(String(format: "%.1f", viewModel.danmakuFontScale))")
                    Slider(value: $viewModel.danmakuFontScale, in: 0.5...1.5)
                }
            }
            .navigationTitle("弹幕设置")
            .navigationBarTitleDisplayMode(.inline)
        }
        .presentationDetents([.medium])
    }

    private var pageSelector: some View {
        NavigationStack {
            List(Array(viewModel.pages.enumerated()), id: \.offset) { index, page in
                Button {
                    viewModel.switchPage(index)
                    showPageSelector = false
                } label: {
                    HStack {
                        Text("P\(page.page ?? index+1) \(page.part ?? "")")
                            .foregroundColor(themeManager.primaryTextColor)
                        Spacer()
                        if index == viewModel.currentPage {
                            Image(systemName: "checkmark")
                                .foregroundColor(themeManager.accentColor)
                        }
                    }
                }
            }
            .navigationTitle("选集")
            .navigationBarTitleDisplayMode(.inline)
        }
        .presentationDetents([.medium, .large])
    }

    private func formatTime(_ seconds: Double) -> String {
        let total = Int(seconds)
        let h = total / 3600
        let m = (total % 3600) / 60
        let s = total % 60
        if h > 0 {
            return String(format: "%d:%02d:%02d", h, m, s)
        }
        return String(format: "%d:%02d", m, s)
    }

    private func qualityName(_ qn: Int) -> String {
        switch qn {
        case 127: return "8K"
        case 126: return "杜比视界"
        case 125: return "HDR"
        case 120: return "4K超清"
        case 116: return "1080P60高帧"
        case 112: return "1080P高码率"
        case 80: return "1080P"
        case 74: return "720P60"
        case 64: return "720P"
        case 48: return "720P"
        case 32: return "480P"
        case 16: return "360P"
        default: return "\(qn)P"
        }
    }
}

// MARK: - 弹幕覆盖层
struct DanmakuOverlay: View {
    let currentTime: Double
    let alpha: Double
    let fontScale: Double

    @State private var danmakuItems: [DanmakuItem] = []

    var body: some View {
        GeometryReader { geo in
            ZStack {
                ForEach(danmakuItems) { item in
                    Text(item.text)
                        .font(.system(size: 16 * fontScale))
                        .foregroundColor(.white.opacity(alpha))
                        .shadow(color: .black.opacity(0.5), radius: 2)
                        .position(x: item.x + geo.size.width, y: item.y)
                        .animation(.linear(duration: item.speed), value: item.x)
                }
            }
            .clipped()
        }
    }

    struct DanmakuItem: Identifiable {
        let id = UUID()
        let text: String
        let x: CGFloat
        let y: CGFloat
        let speed: Double
    }
}

// MARK: - Preview
#Preview {
    NavigationStack {
        VideoPlayerScreen(bvid: "BV1xx411c7mD")
    }
    .environmentObject(ThemeManager.shared)
}
