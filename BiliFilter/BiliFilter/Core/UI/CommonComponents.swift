import SwiftUI

// MARK: - 通用视频卡片
struct VideoCardView: View {
    let coverUrl: String
    let title: String
    let upName: String
    let playCount: Int
    let danmakuCount: Int
    let duration: Int
    var onTap: (() -> Void)?

    @EnvironmentObject private var themeManager: ThemeManager

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // 封面
            ZStack(alignment: .bottomTrailing) {
                BiliCover(url: coverUrl)
                    .frame(maxWidth: .infinity)
                    .aspectRatio(16/9, contentMode: .fit)

                // 时长标签
                Text(formatSeconds(duration))
                    .font(.caption2)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(.ultraThinMaterial)
                    .cornerRadius(4)
                    .padding(6)
            }

            // 标题
            Text(title)
                .font(.subheadline)
                .lineLimit(2)
                .foregroundColor(themeManager.primaryTextColor)
                .frame(maxHeight: 40, alignment: .top)

            // UP主 + 播放量
            HStack(spacing: 8) {
                Text(upName)
                    .font(.caption)
                    .foregroundColor(themeManager.secondaryTextColor)
                    .lineLimit(1)
                Spacer()
                HStack(spacing: 12) {
                    Label(formatCount(playCount), systemImage: "play.fill")
                        .font(.caption2)
                        .foregroundColor(themeManager.secondaryTextColor)
                    Label(formatCount(danmakuCount), systemImage: "text.bubble.fill")
                        .font(.caption2)
                        .foregroundColor(themeManager.secondaryTextColor)
                }
            }
        }
        .contentShape(Rectangle())
        .onTapGesture { onTap?() }
    }

    // formatCount和formatSeconds已移至BiliResponse.swift
}

// MARK: - 骨架屏
struct ShimmerModifier: ViewModifier {
    @State private var phase: CGFloat = 0

    func body(content: Content) -> some View {
        content
            .overlay(
                LinearGradient(
                    gradient: Gradient(colors: [.clear, .white.opacity(0.3), .clear]),
                    startPoint: .leading,
                    endPoint: .trailing
                )
                .offset(x: phase * 200 - 200)
                .blur(radius: 10)
            )
            .mask(content)
            .onAppear {
                withAnimation(.linear(duration: 1.5).repeatForever(autoreverses: false)) {
                    phase = 1
                }
            }
    }
}

extension View {
    func shimmer() -> some View {
        self.modifier(ShimmerModifier())
    }
}

// MARK: - 视频卡片网格
struct VideoCardGrid: View {
    let videos: [VideoItem]
    let columns: Int
    var onVideoTap: ((VideoItem) -> Void)?

    private var gridColumns: [GridItem] {
        Array(repeating: GridItem(.flexible(), spacing: 12), count: columns)
    }

    var body: some View {
        LazyVGrid(columns: gridColumns, spacing: 16) {
            ForEach(videos) { video in
                VideoCardView(
                    coverUrl: video.pic,
                    title: video.title,
                    upName: video.owner?.name ?? "",
                    playCount: video.stat?.viewCount ?? 0,
                    danmakuCount: video.stat?.danmakuCount ?? 0,
                    duration: video.duration,
                    onTap: { onVideoTap?(video) }
                )
            }
        }
        .padding(.horizontal, 12)
    }
}

// MARK: - 水平滚动视频列表
struct HorizontalVideoList: View {
    let videos: [VideoItem]
    var onVideoTap: ((VideoItem) -> Void)?

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
                        onTap: { onVideoTap?(video) }
                    )
                    .frame(width: 280)
                }
            }
            .padding(.horizontal, 12)
        }
    }
}
