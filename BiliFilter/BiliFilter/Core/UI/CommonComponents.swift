import SwiftUI

// MARK: - 通用视频卡片
struct VideoCardView: View {
    let coverUrl: String
    let title: String
    let upName: String
    let playCount: Int
    let danmakuCount: Int
    let duration: Int
    var bvid: String?
    var cid: Int64?
    var filterReason: String?
    var ownerMid: Int64?

    @EnvironmentObject private var themeManager: ThemeManager

    var body: some View {
        cardContent
    }

    @ViewBuilder
    private var cardContent: some View {
        Group {
            if filterReason != nil {
                cardLayout
                    .overlay(filterOverlay)
            } else if let bvid = bvid, !bvid.isEmpty {
                NavigationLink(value: AppRoute.videoPlayer(bvid: bvid, cid: cid ?? 0)) {
                    cardLayout
                }
                .buttonStyle(.plain)
            } else {
                cardLayout
            }
        }
    }

    private var filterOverlay: some View {
        ZStack {
            Color(.systemGray5)
            VStack(spacing: 6) {
                Image(systemName: "eye.slash.fill")
                    .font(.title2)
                    .foregroundColor(.secondary)
                if let reason = filterReason {
                    Text(reason)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 4)
                }
            }
        }
    }

    private var cardLayout: some View {
        VStack(alignment: .leading, spacing: 8) {
            ZStack(alignment: .bottomTrailing) {
                BiliCover(url: coverUrl)
                    .frame(maxWidth: .infinity)
                    .aspectRatio(16/9, contentMode: .fit)
                Text(formatSeconds(duration))
                    .font(.caption2)
                    .padding(.horizontal, 6).padding(.vertical, 2)
                    .background(.ultraThinMaterial).cornerRadius(4)
                    .padding(6)
            }
            Text(title)
                .font(.subheadline).lineLimit(2)
                .foregroundColor(themeManager.primaryTextColor)
                .frame(maxHeight: 40, alignment: .top)
            HStack(spacing: 8) {
                if let mid = ownerMid {
                    NavigationLink(value: AppRoute.space(mid: mid)) {
                        Text(upName).font(.caption).foregroundColor(themeManager.accentColor).lineLimit(1)
                    }
                } else {
                    Text(upName).font(.caption).foregroundColor(themeManager.secondaryTextColor).lineLimit(1)
                }
            }
        }
    }
}

// MARK: - 视频卡片网格
struct VideoCardGrid: View {
    let videos: [VideoItem]
    let columns: Int
    @StateObject private var filter = FilterSettings.shared

    private var gridColumns: [GridItem] {
        Array(repeating: GridItem(.flexible(), spacing: 12), count: columns)
    }

    var body: some View {
        LazyVGrid(columns: gridColumns, spacing: 16) {
            ForEach(videos) { video in
                let reason = filter.checkVideo(duration: video.duration, title: video.title)
                VideoCardView(
                    coverUrl: video.pic,
                    title: video.title,
                    upName: video.owner?.name ?? "",
                    playCount: video.stat?.viewCount ?? 0,
                    danmakuCount: video.stat?.danmakuCount ?? 0,
                    duration: video.duration,
                    bvid: video.bvid.isEmpty ? nil : video.bvid,
                    cid: video.cid,
                    filterReason: reason,
                    ownerMid: video.owner?.mid
                )
            }
        }
        .padding(.horizontal, 12)
    }
}

// MARK: - 水平滚动视频列表
struct HorizontalVideoList: View {
    let videos: [VideoItem]
    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            LazyHStack(spacing: 12) {
                ForEach(videos) { video in
                    VideoCardView(
                        coverUrl: video.pic,
                        title: video.title,
                        upName: video.owner?.name ?? "",
                        playCount: video.stat?.viewCount ?? 0,
                        danmakuCount: video.stat?.danmakuCount ?? 0,
                        duration: video.duration,
                        bvid: video.bvid.isEmpty ? nil : video.bvid,
                        cid: video.cid
                    ).frame(width: 280)
                }
            }.padding(.horizontal, 12)
        }
    }
}

// MARK: - 骨架屏
struct ShimmerModifier: ViewModifier {
    @State private var phase: CGFloat = 0
    func body(content: Content) -> some View {
        content.overlay(
            LinearGradient(gradient: Gradient(colors: [.clear, .white.opacity(0.3), .clear]), startPoint: .leading, endPoint: .trailing)
                .offset(x: phase * 200 - 200).blur(radius: 10)
        ).mask(content)
        .onAppear { withAnimation(.linear(duration: 1.5).repeatForever(autoreverses: false)) { phase = 1 } }
    }
}
extension View {
    func shimmer() -> some View { modifier(ShimmerModifier()) }
}
