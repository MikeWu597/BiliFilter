import SwiftUI

// MARK: - 路由定义
enum AppRoute: Hashable {
    case home
    case profile
    case videoPlayer(bvid: String, cid: Int64 = 0, aid: Int64 = 0)
    case search
    case live(roomId: Int64, title: String = "", uname: String = "")
    case liveList
    case liveAreaDetail(parentAreaId: Int, areaId: Int, title: String)
    case bangumi(initialType: Int = 1)
    case bangumiDetail(seasonId: Int64, epId: Int64 = 0)
    case bangumiPlayer(seasonId: Int64, epId: Int64, resumePositionMs: Int64 = 0)
    case space(mid: Int64)
    case history
    case web(url: String, title: String? = nil)
    case category(tid: Int, name: String)
    case partition
    case seasonSeriesDetail(type: String, id: Int64, mid: Int64, title: String, ownerName: String)
    case onboarding
}

// MARK: - 底栏Tab
enum BottomTab: String, CaseIterable, Hashable {
    case home
    case profile

    var iconName: String {
        switch self {
        case .home: return "house.fill"
        case .profile: return "person.fill"
        }
    }

    var title: String {
        switch self {
        case .home: return "首页"
        case .profile: return "我的"
        }
    }
}

let BottomTabColorMap: [BottomTab: Color] = [
    .home: iOSBlue,
    .profile: iOSPink,
]

// MARK: - 主导航
struct AppNavigation: View {
    @StateObject private var themeManager = ThemeManager.shared
    @State private var selectedTab: BottomTab = .home
    @State private var navigationPath = NavigationPath()

    var body: some View {
        TabView(selection: $selectedTab) {
            ForEach(BottomTab.allCases, id: \.self) { tab in
                NavigationStack(path: $navigationPath) {
                    mainView(for: tab)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .navigationDestination(for: AppRoute.self) { route in
                            destinationView(for: route)
                        }
                }
                .tabItem {
                    Image(systemName: tab.iconName)
                    Text(tab.title)
                }
                .tag(tab)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .tint(BottomTabColorMap[selectedTab] ?? iOSBlue)
        .environmentObject(themeManager)
    }

    @ViewBuilder
    func mainView(for tab: BottomTab) -> some View {
        switch tab {
        case .home: HomeScreen()
        case .profile: ProfileScreen()
        }
    }

    @ViewBuilder
    func destinationView(for route: AppRoute) -> some View {
        switch route {
        case .home: HomeScreen()
        case .profile: ProfileScreen()
        case .videoPlayer(let bvid, let cid, _): VideoPlayerScreen(bvid: bvid, cid: cid)
        case .search: SearchScreen()
        case .live: PlaceholderView(title: "直播间", icon: "play.tv.fill")
        case .liveList: LiveScreen()
        case .liveAreaDetail: PlaceholderView(title: "分区直播", icon: "antenna.radiowaves.left.and.right")
        case .bangumi: BangumiScreen()
        case .bangumiDetail: PlaceholderView(title: "番剧详情", icon: "tv.fill")
        case .bangumiPlayer: PlaceholderView(title: "番剧播放", icon: "play.tv")
        case .space(let mid): SpaceScreen(mid: mid)
        case .history: WatchHistoryScreen()
        case .web: PlaceholderView(title: "网页", icon: "safari")
        case .category: PlaceholderView(title: "分类", icon: "folder")
        case .partition: PlaceholderView(title: "分区", icon: "square.grid.3x3")
        case .seasonSeriesDetail: PlaceholderView(title: "合集", icon: "rectangle.stack")
        case .onboarding: PlaceholderView(title: "新手引导", icon: "hand.wave")
        }
    }
}

// MARK: - 占位视图
struct PlaceholderView: View {
    let title: String
    var icon: String?
    var subtitle: String?

    @EnvironmentObject private var themeManager: ThemeManager

    var body: some View {
        VStack(spacing: 16) {
            if let icon = icon {
                Image(systemName: icon)
                    .font(.system(size: 48))
                    .foregroundColor(themeManager.accentColor)
            }
            Text(title)
                .font(.title2)
                .fontWeight(.semibold)
                .foregroundColor(themeManager.primaryTextColor)
            if let subtitle = subtitle {
                Text(subtitle)
                    .font(.caption)
                    .foregroundColor(themeManager.secondaryTextColor)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(themeManager.backgroundColor)
    }
}

#Preview {
    AppNavigation()
}
