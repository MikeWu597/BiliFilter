import SwiftUI
import AVFoundation

struct VideoPlayerScreen: View {
    @StateObject private var viewModel: PlayerViewModel
    @EnvironmentObject private var themeManager: ThemeManager
    @Environment(\.dismiss) private var dismiss
    @State private var showQualityMenu = false
    @State private var showSpeedMenu = false
    @State private var showDanmakuSettings = false
    @State private var showPageSelector = false

    init(bvid: String, cid: Int64 = 0, aid: Int64 = 0) {
        _viewModel = StateObject(wrappedValue: PlayerViewModel(bvid: bvid, cid: cid, aid: aid))
    }

    var body: some View {
        Group {
            if viewModel.isFullscreen {
                fullscreenPlayer
                    .toolbar(.hidden, for: .tabBar)
            } else {
                normalPlayer
            }
        }
        .navigationBarBackButtonHidden(true)
        .toolbarBackground(.hidden, for: .navigationBar)
        .enableSwipeBack()
        .statusBarHidden(viewModel.isFullscreen)
        .task { await viewModel.loadVideo() }
        .onDisappear { viewModel.cleanup() }
        .sheet(isPresented: $showQualityMenu) { qualityMenu }
        .sheet(isPresented: $showSpeedMenu) { speedMenu }
        .sheet(isPresented: $showDanmakuSettings) { danmakuSettings }
        .sheet(isPresented: $showPageSelector) { pageSelector }
    }

    private var normalPlayer: some View {
        GeometryReader { geo in
            VStack(spacing: 0) {
                ZStack {
                    Color.black
                    if let player = viewModel.player {
                        VideoPlayerLayer(player: player)
                    }
                    DanmakuRenderer(items: viewModel.danmakuItems, currentTime: viewModel.currentTime, alpha: viewModel.danmakuAlpha, fontScale: viewModel.danmakuFontScale, isEnabled: viewModel.danmakuEnabled, isPlaying: viewModel.isPlaying)
                    if viewModel.playerState == .loading {
                        ProgressView().tint(.white).scaleEffect(1.5)
                    }
                }
                .frame(width: geo.size.width, height: geo.size.width * 9/16)
                .overlay(alignment: .top) { if viewModel.showControls { topControls } }
                .overlay(alignment: .bottom) { if viewModel.showControls { bottomControls } }
                .onTapGesture(count: 2) { viewModel.togglePlay() }
                .onTapGesture { toggleControls() }
                .gesture(volumeBrightnessGesture(in: geo))

                videoInfoSection
            }
            .background(themeManager.backgroundColor)
        }
    }

    private var fullscreenPlayer: some View {
        GeometryReader { geo in
            ZStack {
                Color.black
                if let player = viewModel.player {
                    VideoPlayerLayer(player: player)
                }
                DanmakuRenderer(items: viewModel.danmakuItems, currentTime: viewModel.currentTime, alpha: viewModel.danmakuAlpha, fontScale: viewModel.danmakuFontScale, isEnabled: viewModel.danmakuEnabled, isPlaying: viewModel.isPlaying)
                if viewModel.playerState == .loading {
                    ProgressView().tint(.white).scaleEffect(1.5)
                }

                if viewModel.showControls {
                    VStack {
                        HStack {
                            Button { viewModel.exitFullscreen() } label: {
                                Image(systemName: "arrow.down.right.and.arrow.up.left")
                                    .font(.title3).foregroundColor(.white)
                                    .padding(10).background(Circle().fill(.ultraThinMaterial))
                            }
                            Spacer()
                        }
                        .padding(.horizontal, 12).padding(.top, 48)
                        Spacer()
                        bottomControls
                    }
                }
            }
            .onTapGesture(count: 2) { viewModel.togglePlay() }
            .onTapGesture { viewModel.showControls.toggle() }
            .gesture(volumeBrightnessGesture(in: geo))
        }
        .ignoresSafeArea()
        .background(Color.black.ignoresSafeArea())
    }

    private var topControls: some View {
        HStack {
            Button { dismiss() } label: {
                Image(systemName: "chevron.left")
                    .font(.title3).foregroundColor(.white)
                    .padding(10).background(Circle().fill(.ultraThinMaterial))
            }
            Spacer()
            Text(viewModel.videoInfo?.title ?? "")
                .font(.subheadline).foregroundColor(.white).lineLimit(1)
            Spacer()
            Button { showDanmakuSettings = true } label: {
                Image(systemName: "list.bullet.rectangle")
                    .font(.title3).foregroundColor(.white)
                    .padding(10).background(Circle().fill(.ultraThinMaterial))
            }
        }
        .padding(.horizontal, 12)
        .padding(.top, 8)
        .padding(.bottom, 40)
        .background(LinearGradient(colors: [.black.opacity(0.6), .clear], startPoint: .top, endPoint: .bottom))
    }

    private var bottomControls: some View {
        VStack(spacing: 12) {
            Slider(value: $viewModel.currentTime, in: 0...max(viewModel.duration, 1)) { editing in
                if !editing { viewModel.seek(to: viewModel.currentTime) }
            }.tint(.white).padding(.horizontal, 16)

            HStack {
                Text(formatTime(viewModel.currentTime)).font(.caption2).foregroundColor(.white)
                Spacer()
                Text(formatTime(viewModel.duration)).font(.caption2).foregroundColor(.white.opacity(0.6))
            }.padding(.horizontal, 16)

            HStack(spacing: 16) {
                Button { showPageSelector = true } label: {
                    Image(systemName: "list.number").font(.body).foregroundColor(.white)
                }
                Spacer()
                Button { showSpeedMenu = true } label: {
                    Text("\(String(format: "%.1f", viewModel.playbackSpeed))x")
                        .font(.caption).foregroundColor(.white)
                        .padding(.horizontal, 10).padding(.vertical, 4)
                        .background(.ultraThinMaterial).cornerRadius(4)
                }
                Button { showQualityMenu = true } label: {
                    Text("画质").font(.caption).foregroundColor(.white)
                        .padding(.horizontal, 10).padding(.vertical, 4)
                        .background(.ultraThinMaterial).cornerRadius(4)
                }
                Button { viewModel.toggleFullscreen() } label: {
                    Image(systemName: "arrow.up.left.and.arrow.down.right")
                        .font(.body).foregroundColor(.white)
                }
            }.padding(.horizontal, 16)
        }
        .padding(.top, 40)
        .padding(.bottom, 12)
        .background(LinearGradient(colors: [.clear, .black.opacity(0.7)], startPoint: .top, endPoint: .bottom))
    }

    private var videoInfoSection: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 12, pinnedViews: []) {
                if let info = viewModel.videoInfo {
                    Text(info.title ?? "").font(.headline).padding(.horizontal, 16).padding(.top, 12)
                    HStack {
                        BiliAvatar(url: info.owner?.face, size: 40)
                        VStack(alignment: .leading) {
                            Text(info.owner?.name ?? "").font(.subheadline).fontWeight(.medium)
                            if let stat = info.stat {
                                HStack(spacing: 12) {
                                    Label(formatCount(stat.viewCount), systemImage: "play.fill")
                                    Label(formatCount(stat.danmakuCount), systemImage: "text.bubble")
                                    Label(formatCount(stat.likeCount), systemImage: "hand.thumbsup")
                                }.font(.caption).foregroundColor(.secondary)
                            }
                        }
                    }.padding(.horizontal, 16)
                    if let desc = info.desc, !desc.isEmpty {
                        Text(desc).font(.subheadline).foregroundColor(.secondary).lineLimit(3).padding(.horizontal, 16)
                    }
                }
                if !viewModel.relatedVideos.isEmpty {
                    Text("相关推荐").font(.headline).padding(.horizontal, 16).padding(.top, 4)
                    ForEach(viewModel.relatedVideos) { video in
                        VideoCardView(coverUrl: video.pic, title: video.title, upName: video.owner?.name ?? "", playCount: video.stat?.viewCount ?? 0, danmakuCount: video.stat?.danmakuCount ?? 0, duration: video.duration, bvid: video.bvid, cid: video.cid).padding(.horizontal, 16)
                    }
                }
                // 评论区
                replyHeader

                if viewModel.isLoadingReplies && viewModel.replyItems.isEmpty {
                    HStack { Spacer(); ProgressView().tint(themeManager.accentColor); Spacer() }
                        .padding(.vertical, 24)
                } else if let err = viewModel.replyErrorMessage, viewModel.replyItems.isEmpty {
                    Button { Task { await viewModel.loadReplies() } } label: {
                        Label(err, systemImage: "arrow.clockwise")
                            .font(.caption).foregroundColor(.secondary)
                    }.padding(.vertical, 24).frame(maxWidth: .infinity)
                }

                ForEach(Array(viewModel.replyItems.enumerated()), id: \.element.id) { idx, reply in
                    let subs = viewModel.expandedReplies[reply.rpid]
                    ReplyRow(
                        reply: reply,
                        subReplies: subs,
                        isLoadingSub: viewModel.loadingSubReplies.contains(reply.rpid),
                        onToggle: { viewModel.toggleSubReplies(for: reply.rpid) }
                    )
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    Divider().padding(.leading, 56)
                }

                // 底部加载更多：用id确保每次新评论追加后onAppear重新触发
                if viewModel.hasMoreReplies {
                    Color.clear
                        .frame(height: 60)
                        .id("replyLoader-\(viewModel.replyItems.count)")
                        .onAppear {
                            print("[Reply] sentinel APPEAR count=\(viewModel.replyItems.count) hasMore=\(viewModel.hasMoreReplies) loading=\(viewModel.isLoadingReplies)")
                            if !viewModel.isLoadingReplies {
                                Task { await viewModel.loadMoreReplies() }
                            }
                        }
                }

                if viewModel.isLoadingReplies && !viewModel.replyItems.isEmpty {
                    HStack { Spacer(); ProgressView().scaleEffect(0.8); Spacer() }
                        .padding(.vertical, 12)
                }
            }.padding(.bottom, 32)
        }
    }



    private var replyHeader: some View {
        let totalCount = viewModel.videoInfo?.stat?.replyCount ?? viewModel.replyItems.count
        return HStack {
            Text("评论 \(totalCount > 0 ? formatCount(totalCount) : "")")
                .font(.headline)
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.top, 16)
        .padding(.bottom, 8)
    }

    private func volumeBrightnessGesture(in geo: GeometryProxy) -> some Gesture {
        DragGesture(minimumDistance: 20).onChanged { value in
            let halfW = geo.size.width / 2
            let change = -Float(value.translation.height / 500)
            if value.startLocation.x < halfW {
                viewModel.setBrightness(min(1, max(0, viewModel.brightness + CGFloat(change))))
            } else {
                viewModel.setVolume(min(1, max(0, viewModel.volume + change)))
            }
        }
    }

    private func toggleControls() {
        withAnimation(.easeInOut(duration: 0.3)) { viewModel.showControls.toggle() }
    }

    private func formatTime(_ s: Double) -> String {
        let t = Int(s); let h = t/3600; let m = (t%3600)/60; let sec = t%60
        return h > 0 ? String(format: "%d:%02d:%02d", h, m, sec) : String(format: "%d:%02d", m, sec)
    }

    // MARK: Sheets
    private var qualityMenu: some View {
        NavigationStack {
            List(viewModel.availableQualities, id: \.self) { qn in
                Button { viewModel.setQuality(qn); showQualityMenu = false } label: {
                    HStack {
                        Text(qualityName(qn)); Spacer()
                        if qn == viewModel.currentQuality { Image(systemName: "checkmark").foregroundColor(.accentColor) }
                    }
                }
            }.navigationTitle("画质").navigationBarTitleDisplayMode(.inline)
        }.presentationDetents([.medium])
    }
    private var speedMenu: some View {
        NavigationStack {
            List([0.5, 0.75, 1.0, 1.25, 1.5, 2.0], id: \.self) { sp in
                Button { viewModel.setSpeed(Float(sp)); showSpeedMenu = false } label: {
                    HStack {
                        Text("\(String(format: "%.1f", sp))x"); Spacer()
                        if Float(sp) == viewModel.playbackSpeed { Image(systemName: "checkmark").foregroundColor(.accentColor) }
                    }
                }
            }.navigationTitle("倍速").navigationBarTitleDisplayMode(.inline)
        }.presentationDetents([.medium])
    }
    private var danmakuSettings: some View {
        NavigationStack {
            List {
                Toggle("弹幕", isOn: $viewModel.danmakuEnabled)
                VStack(alignment: .leading) {
                    Text("透明度: \(String(format: "%.0f%%", viewModel.danmakuAlpha*100))")
                    Slider(value: $viewModel.danmakuAlpha, in: 0.1...1.0)
                }
                VStack(alignment: .leading) {
                    Text("字号: \(String(format: "%.1f", viewModel.danmakuFontScale))")
                    Slider(value: $viewModel.danmakuFontScale, in: 0.5...1.5)
                }
            }.navigationTitle("弹幕").navigationBarTitleDisplayMode(.inline)
        }.presentationDetents([.medium])
    }
    private var pageSelector: some View {
        NavigationStack {
            List(Array(viewModel.pages.enumerated()), id: \.offset) { i, p in
                Button { viewModel.switchPage(i); showPageSelector = false } label: {
                    HStack {
                        Text("P\(p.page ?? i+1) \(p.part ?? "")"); Spacer()
                        if i == viewModel.currentPage { Image(systemName: "checkmark").foregroundColor(.accentColor) }
                    }
                }
            }.navigationTitle("选集").navigationBarTitleDisplayMode(.inline)
        }.presentationDetents([.medium, .large])
    }
    private func qualityName(_ qn: Int) -> String {
        switch qn {
        case 127: "8K"; case 126: "杜比"; case 125: "HDR"; case 120: "4K"; case 116: "1080P60"; case 112: "1080P+"
        case 80: "1080P"; case 74: "720P60"; case 64: "720P"; case 32: "480P"; case 16: "360P"; default: "\(qn)P"
        }
    }
}

// MARK: - 评论行
struct ReplyRow: View {
    let reply: ReplyItem
    var subReplies: [ReplyItem]? = nil
    var isLoadingSub: Bool = false
    var onToggle: (() -> Void)? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .top, spacing: 10) {
                AsyncImage(url: URL(string: reply.member.avatarUrl)) { img in
                    img.resizable().aspectRatio(contentMode: .fill)
                } placeholder: {
                    Color.gray.opacity(0.2)
                }
                .frame(width: 34, height: 34)
                .clipShape(Circle())

                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        Text(reply.member.uname)
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(.primary)
                        if let level = reply.member.levelInfo?.currentLevel, level > 0 {
                            Text("Lv\(level)")
                                .font(.system(size: 10))
                                .foregroundColor(.white)
                                .padding(.horizontal, 4)
                                .padding(.vertical, 1)
                                .background(Color.orange)
                                .cornerRadius(3)
                        }
                        Spacer()
                        Text(reply.timeAgo)
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                    Text(reply.content.message)
                        .font(.subheadline)
                        .foregroundColor(.primary)
                        .lineLimit(6)
                    HStack(spacing: 16) {
                        if let loc = reply.replyControl?.location, !loc.isEmpty {
                            Text(loc)
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                        Label("\(reply.likeCount)", systemImage: "hand.thumbsup")
                            .font(.caption2).foregroundColor(.secondary)
                        if reply.replyCount > 0 {
                            Button { onToggle?() } label: {
                                Label("\(reply.replyCount)", systemImage: "text.bubble")
                                    .font(.caption2)
                            }
                        }
                    }
                }
            }

            // 内嵌子回复预览（来自API返回的replies字段）
            if let embedded = reply.replies, !embedded.isEmpty, subReplies == nil {
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(embedded.prefix(3)) { sub in
                        HStack(alignment: .top, spacing: 8) {
                            Text(sub.member.uname)
                                .font(.caption).foregroundColor(.accentColor)
                            + Text("：\(sub.content.message)")
                                .font(.caption).foregroundColor(.secondary)
                        }
                        .lineLimit(1)
                        .padding(.leading, 44)
                    }
                    if reply.replyCount > 3 {
                        Button { onToggle?() } label: {
                            Text("查看全部\(reply.replyCount)条回复")
                                .font(.caption).foregroundColor(.accentColor)
                        }
                        .padding(.leading, 44)
                        .padding(.top, 2)
                    }
                }
                .padding(.top, 4)
            }

            // 展开加载的完整子回复
            if let subs = subReplies {
                if isLoadingSub {
                    HStack { Spacer(); ProgressView().scaleEffect(0.7); Spacer() }
                        .padding(.vertical, 4).padding(.leading, 44)
                }
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(subs) { sub in
                        HStack(alignment: .top, spacing: 8) {
                            Text(sub.member.uname)
                                .font(.caption).foregroundColor(.accentColor)
                            + Text("：\(sub.content.message)")
                                .font(.caption).foregroundColor(.secondary)
                        }
                        .lineLimit(3)
                        .padding(.leading, 44)
                    }
                }
                .padding(.top, 4)
                Button { onToggle?() } label: {
                    Text("收起回复")
                        .font(.caption).foregroundColor(.accentColor)
                }
                .padding(.leading, 44)
                .padding(.top, 2)
            }
        }
    }
}


#Preview {
    NavigationStack { VideoPlayerScreen(bvid: "BV1xx411c7mD").environmentObject(ThemeManager.shared) }
}
