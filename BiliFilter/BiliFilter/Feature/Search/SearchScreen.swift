import SwiftUI

struct SearchScreen: View {
    @StateObject private var viewModel = SearchViewModel()
    @EnvironmentObject private var themeManager: ThemeManager
    @Environment(\.dismiss) private var dismiss
    @FocusState private var isFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            // 搜索栏
            HStack(spacing: 10) {
                HStack(spacing: 8) {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(themeManager.secondaryTextColor)
                    TextField("搜索视频", text: $viewModel.query)
                        .focused($isFocused)
                        .submitLabel(.search)
                        .onSubmit { Task { await viewModel.search() } }
                    if !viewModel.query.isEmpty {
                        Button {
                            viewModel.query = ""
                            viewModel.results = []
                            viewModel.errorMessage = nil
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.gray)
                        }
                    }
                }
                .padding(10)
                .background(themeManager.systemGrayBackground)
                .cornerRadius(10)

                Button("搜索") {
                    isFocused = false
                    Task { await viewModel.search() }
                }
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(.white)
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(themeManager.accentColor)
                .cornerRadius(8)
                .disabled(viewModel.query.trimmingCharacters(in: .whitespaces).isEmpty)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)

            // 内容区
            if viewModel.isLoading && viewModel.results.isEmpty {
                Spacer()
                ProgressView()
                    .tint(themeManager.accentColor)
                Spacer()
            } else if let error = viewModel.errorMessage, viewModel.results.isEmpty {
                Spacer()
                VStack(spacing: 16) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 40))
                        .foregroundColor(.secondary)
                    Text(error)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                Spacer()
            } else if !viewModel.results.isEmpty {
                // 搜索结果
                ScrollView {
                    LazyVStack(spacing: 12) {
                        ForEach(viewModel.results.indices, id: \.self) { i in
                            let item = viewModel.results[i]
                            let filterReason = FilterSettings.shared.checkVideo(
                                duration: item.durationSeconds,
                                title: item.cleanedTitle,
                                ownerMid: item.mid,
                                ownerName: item.author ?? "",
                                bvid: item.bvid ?? "",
                                coverUrl: item.normalizedCoverUrl,
                                recordAppear: false
                            )
                            if let reason = filterReason {
                                // 被过滤的视频：不显示封面，用灰色遮罩
                                FilteredSearchRow(item: item, reason: reason)
                            } else if let bvid = item.bvid, !bvid.isEmpty {
                                NavigationLink(value: AppRoute.videoPlayer(bvid: bvid)) {
                                    SearchResultRow(item: item)
                                }
                                .buttonStyle(.plain)
                            } else {
                                SearchResultRow(item: item)
                            }
                        }
                        if viewModel.hasMoreResults && !viewModel.isLoading {
                            ProgressView()
                                .padding(.vertical, 8)
                                .onAppear { Task { await viewModel.loadMore() } }
                        }
                    }
                    .padding(12)
                }
            } else {
                // 初始空状态
                Spacer()
                VStack(spacing: 12) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 40))
                        .foregroundColor(.secondary)
                    Text("输入关键词搜索视频")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                Spacer()
            }
        }
        .background(themeManager.backgroundColor)
        .navigationTitle("搜索")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { isFocused = true }
    }
}

// MARK: - 被过滤的搜索结果行
struct FilteredSearchRow: View {
    let item: SearchResultItem
    let reason: String
    @EnvironmentObject private var themeManager: ThemeManager

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Color(.systemGray5)
                    .frame(width: 140, height: 88)
                    .cornerRadius(8)
                VStack(spacing: 4) {
                    Image(systemName: "eye.slash.fill")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(reason)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
            }

            VStack(alignment: .leading, spacing: 4) {
                Text("已过滤")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Text(reason)
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .lineLimit(2)
            }
        }
        .padding(8)
        .background(Color(.systemGray6))
        .cornerRadius(10)
    }
}

// MARK: - 搜索结果行
struct SearchResultRow: View {
    let item: SearchResultItem
    @EnvironmentObject private var themeManager: ThemeManager

    var body: some View {
        HStack(spacing: 12) {
            BiliCover(url: item.normalizedCoverUrl)
                .frame(width: 140, height: 88)

            VStack(alignment: .leading, spacing: 6) {
                Text(item.cleanedTitle)
                    .font(.subheadline)
                    .foregroundColor(themeManager.primaryTextColor)
                    .lineLimit(2)
                Text(item.author ?? "")
                    .font(.caption)
                    .foregroundColor(themeManager.secondaryTextColor)
                HStack(spacing: 12) {
                    Label(formatCount(item.playCount), systemImage: "play.fill")
                    Label(formatCount(item.danmakuCount), systemImage: "text.bubble")
                    if item.durationSeconds > 0 {
                        Label(formatSeconds(item.durationSeconds), systemImage: "clock")
                    }
                }
                .font(.caption2)
                .foregroundColor(themeManager.tertiaryTextColor)
            }
        }
    }
}

// 流式布局
struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = arrange(proposal.width ?? 0, subviews: subviews)
        return result.size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = arrange(bounds.width, subviews: subviews)
        for (index, frame) in result.frames.enumerated() {
            subviews[index].place(at: CGPoint(x: bounds.minX + frame.minX, y: bounds.minY + frame.minY), proposal: .unspecified)
        }
    }

    private func arrange(_ maxWidth: CGFloat, subviews: Subviews) -> (size: CGSize, frames: [CGRect]) {
        var frames: [CGRect] = []
        var x: CGFloat = 0, y: CGFloat = 0, lineHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > maxWidth && x > 0 {
                x = 0
                y += lineHeight + spacing
                lineHeight = 0
            }
            frames.append(CGRect(x: x, y: y, width: size.width, height: size.height))
            x += size.width + spacing
            lineHeight = max(lineHeight, size.height)
        }
        return (CGSize(width: maxWidth, height: y + lineHeight), frames)
    }
}

#Preview {
    NavigationStack {
        SearchScreen().environmentObject(ThemeManager.shared)
    }
}
