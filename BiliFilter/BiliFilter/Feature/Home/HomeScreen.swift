import SwiftUI

struct HomeScreen: View {
    @StateObject private var viewModel = HomeViewModel()
    @EnvironmentObject private var themeManager: ThemeManager

    var body: some View {
        VStack(spacing: 0) {
            HomeTopBar()
            HomeCategoryTabs(selected: $viewModel.selectedCategory)
                .onChange(of: viewModel.selectedCategory) { _, new in viewModel.switchCategory(new) }

            if viewModel.isLoading && viewModel.feedItems.isEmpty {
                Spacer()
                ProgressView().tint(themeManager.accentColor)
                Spacer()
            } else if let error = viewModel.errorMessage, viewModel.feedItems.isEmpty {
                Spacer()
                ErrorRetryView(message: error) { Task { await viewModel.loadFeed() } }
                Spacer()
            } else {
                feedContent
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(themeManager.backgroundColor.ignoresSafeArea())
        .task { if viewModel.feedItems.isEmpty { await viewModel.loadFeed() } }
    }

    @ViewBuilder
    private var feedContent: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                VideoCardGrid(videos: viewModel.feedItems.compactMap { $0.toVideoItem() }, columns: 2)
                    .padding(.top, 12)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .refreshable { await viewModel.refreshFeed() }
    }
}

struct HomeTopBar: View {
    @EnvironmentObject private var themeManager: ThemeManager
    var body: some View {
        HStack {
            HStack(spacing: 4) {
                Image(systemName: "play.rectangle.fill").font(.title3).foregroundColor(themeManager.accentColor)
                Text("BiliPai").font(.title3).fontWeight(.bold).foregroundColor(themeManager.accentColor)
            }
            Spacer()
            Image(systemName: "magnifyingglass").font(.title3).foregroundColor(.secondary)
            Image(systemName: "person.circle.fill").font(.title3).foregroundColor(.secondary)
        }
        .padding(.horizontal, 16).padding(.vertical, 8)
        .background(.regularMaterial)
    }
}

struct HomeCategoryTabs: View {
    @Binding var selected: HomeCategory
    @Namespace private var animation
    @EnvironmentObject private var themeManager: ThemeManager
    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 0) {
                ForEach(HomeCategory.allCases) { cat in
                    Button {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) { selected = cat }
                    } label: {
                        VStack(spacing: 4) {
                            Text(cat.rawValue)
                                .font(.subheadline)
                                .fontWeight(selected == cat ? .semibold : .regular)
                                .foregroundColor(selected == cat ? themeManager.accentColor : .secondary)
                                .padding(.horizontal, 16).padding(.vertical, 6)
                            if selected == cat {
                                Capsule().fill(themeManager.accentColor).frame(height: 2)
                                    .matchedGeometryEffect(id: "tab", in: animation)
                            } else {
                                Capsule().fill(.clear).frame(height: 2)
                            }
                        }
                    }
                }
            }.padding(.horizontal, 8)
        }
        .background(themeManager.backgroundColor)
    }
}

struct ErrorRetryView: View {
    let message: String; let onRetry: () -> Void
    @EnvironmentObject private var themeManager: ThemeManager
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "wifi.slash").font(.system(size: 48)).foregroundColor(.secondary)
            Text("加载失败").font(.headline)
            Text(message).font(.caption).foregroundColor(.secondary).multilineTextAlignment(.center).padding(.horizontal, 32)
            Button(action: onRetry) {
                HStack { Image(systemName: "arrow.clockwise"); Text("重试") }
                    .font(.subheadline).padding(.horizontal, 20).padding(.vertical, 8)
                    .background(themeManager.accentColor).foregroundColor(.white).cornerRadius(16)
            }
        }
    }
}

extension RecommendItem {
    func toVideoItem() -> VideoItem? {
        guard !bvid.isEmpty, let title = title else { return nil }
        return VideoItem(id: Int64(id), bvid: bvid, aid: Int64(id), title: title, pic: pic ?? "", duration: duration, pubdate: pubdate, owner: owner, stat: stat, cid: Int64(cid))
    }
}

#Preview { HomeScreen().environmentObject(ThemeManager.shared) }
