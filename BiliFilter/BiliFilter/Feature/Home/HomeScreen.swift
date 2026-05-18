import SwiftUI

// MARK: - 首页
struct HomeScreen: View {
    @StateObject private var viewModel = HomeViewModel()
    @EnvironmentObject private var themeManager: ThemeManager
    @State private var scrollOffset: CGFloat = 0

    var body: some View {
        ZStack(alignment: .top) {
            themeManager.backgroundColor.ignoresSafeArea()

            VStack(spacing: 0) {
                // 顶部栏
                HomeTopBar()

                // 分类标签
                HomeCategoryTabs(selected: $viewModel.selectedCategory)
                    .onChange(of: viewModel.selectedCategory) { _, new in
                        viewModel.switchCategory(new)
                    }

                // 内容区域
                if viewModel.isLoading && viewModel.feedItems.isEmpty {
                    Spacer()
                    ProgressView()
                        .tint(themeManager.accentColor)
                    Spacer()
                } else if let error = viewModel.errorMessage, viewModel.feedItems.isEmpty {
                    Spacer()
                    ErrorRetryView(message: error) {
                        Task { await viewModel.loadFeed() }
                    }
                    Spacer()
                } else {
                    feedContent
                }
            }
        }
        .task {
            if viewModel.feedItems.isEmpty {
                await viewModel.loadFeed()
            }
        }
    }

    @ViewBuilder
    private var feedContent: some View {
        if viewModel.selectedCategory == .recommend {
            // 推荐流
            ScrollView {
                LazyVStack(spacing: 0) {
                    // 视频网格
                    VideoCardGrid(
                        videos: viewModel.feedItems.compactMap { $0.toVideoItem() },
                        columns: 2,
                        onVideoTap: { _ in }
                    )
                    .padding(.top, 12)

                    // 加载更多
                    if viewModel.hasMoreData {
                        ProgressView()
                            .padding()
                            .task {
                                await viewModel.refreshFeed()
                            }
                    }
                }
            }
            .refreshable {
                await viewModel.refreshFeed()
            }
        } else {
            // 分类内容
            ScrollView {
                LazyVStack(spacing: 0) {
                    VideoCardGrid(
                        videos: viewModel.categoryVideos,
                        columns: 2,
                        onVideoTap: { _ in }
                    )
                    .padding(.top, 12)
                }
            }
            .refreshable {
                viewModel.switchCategory(viewModel.selectedCategory)
            }
        }
    }
}

// MARK: - 首页顶部栏
struct HomeTopBar: View {
    @EnvironmentObject private var themeManager: ThemeManager

    var body: some View {
        HStack {
            // Logo / 标题
            HStack(spacing: 4) {
                Image(systemName: "play.rectangle.fill")
                    .font(.title3)
                    .foregroundColor(themeManager.accentColor)
                Text("BiliPai")
                    .font(.title3)
                    .fontWeight(.bold)
                    .foregroundColor(themeManager.accentColor)
            }

            Spacer()

            // 搜索入口
            Button {

            } label: {
                Image(systemName: "magnifyingglass")
                    .font(.title3)
                    .foregroundColor(themeManager.secondaryTextColor)
            }

            // 头像 / 个人中心入口
            Button {

            } label: {
                Image(systemName: "person.circle.fill")
                    .font(.title3)
                    .foregroundColor(themeManager.secondaryTextColor)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(
            VisualEffectBlur(style: .systemChromeMaterial)
                .ignoresSafeArea(edges: .top)
        )
    }
}

// MARK: - 分类标签
struct HomeCategoryTabs: View {
    @Binding var selected: HomeCategory
    @Namespace private var animation
    @EnvironmentObject private var themeManager: ThemeManager

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 0) {
                ForEach(HomeCategory.allCases) { category in
                    Button {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                            selected = category
                        }
                    } label: {
                        VStack(spacing: 4) {
                            Text(category.rawValue)
                                .font(.subheadline)
                                .fontWeight(selected == category ? .semibold : .regular)
                                .foregroundColor(
                                    selected == category
                                        ? themeManager.accentColor
                                        : themeManager.secondaryTextColor
                                )
                                .padding(.horizontal, 16)
                                .padding(.vertical, 6)

                            if selected == category {
                                Capsule()
                                    .fill(themeManager.accentColor)
                                    .frame(height: 2)
                                    .matchedGeometryEffect(id: "tab", in: animation)
                            } else {
                                Capsule()
                                    .fill(.clear)
                                    .frame(height: 2)
                            }
                        }
                    }
                }
            }
            .padding(.horizontal, 8)
        }
        .background(
            themeManager.backgroundColor
        )
    }
}

// MARK: - 错误重试视图
struct ErrorRetryView: View {
    let message: String
    let onRetry: () -> Void

    @EnvironmentObject private var themeManager: ThemeManager

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "wifi.slash")
                .font(.system(size: 48))
                .foregroundColor(themeManager.secondaryTextColor)
            Text("加载失败")
                .font(.headline)
                .foregroundColor(themeManager.primaryTextColor)
            Text(message)
                .font(.caption)
                .foregroundColor(themeManager.secondaryTextColor)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
            Button(action: onRetry) {
                HStack {
                    Image(systemName: "arrow.clockwise")
                    Text("重试")
                }
                .font(.subheadline)
                .padding(.horizontal, 20)
                .padding(.vertical, 8)
                .background(themeManager.accentColor)
                .foregroundColor(.white)
                .cornerRadius(16)
            }
        }
    }
}

// MARK: - RecommendItem 转 VideoItem
extension RecommendItem {
    func toVideoItem() -> VideoItem? {
        guard !bvid.isEmpty, let title = title else { return nil }
        return VideoItem(
            id: Int64(id),
            bvid: bvid,
            aid: Int64(id),
            title: title,
            pic: pic ?? "",
            duration: duration,
            pubdate: pubdate,
            owner: owner,
            stat: stat,
            cid: Int64(cid),
            desc: nil,
            short_link: nil
        )
    }
}

// MARK: - Preview
#Preview {
    HomeScreen()
        .environmentObject(ThemeManager.shared)
}
