import SwiftUI

// MARK: - 路由定义
enum AppRoute: Hashable {
    case home
    case dynamic
    case history
    case profile
    case videoPlayer(bvid: String, cid: Int64 = 0, aid: Int64 = 0)
    case search
    case searchTrending
    case topicDetail(topicId: Int64)
    case live(roomId: Int64, title: String = "", uname: String = "")
    case liveList
    case liveArea
    case liveFollowing
    case liveAreaDetail(parentAreaId: Int, areaId: Int, title: String)
    case bangumi(initialType: Int = 1)
    case bangumiDetail(seasonId: Int64, epId: Int64 = 0)
    case bangumiPlayer(seasonId: Int64, epId: Int64, resumePositionMs: Int64 = 0)
    case dynamicDetail(dynamicId: String)
    case articleDetail(articleId: Int64, title: String? = nil)
    case space(mid: Int64)
    case following(mid: Int64)
    case favorite
    case watchLater
    case downloadList
    case settings
    case appearanceSettings
    case playbackSettings
    case permissionSettings
    case pluginsSettings(importUrl: String? = nil)
    case bottomBarSettings
    case iconSettings
    case animationSettings
    case tipsSettings
    case openSourceLicenses
    case login
    case web(url: String, title: String? = nil)
    case story
    case offlineVideoPlayer(taskId: String)
    case category(tid: Int, name: String)
    case partition
    case chat(talkerId: Int64, sessionType: Int, userName: String)
    case inbox
    case replyMe
    case atMe
    case likeMe
    case systemNotice
    case audioMode
    case musicDetail(sid: Int64)
    case nativeMusic(title: String, bvid: String, cid: Int64)
    case settingsShare
    case webDavBackup
    case seasonSeriesDetail(type: String, id: Int64, mid: Int64, title: String, ownerName: String)
    case onboarding
    case blockedList
    case jsonPluginEditor
}

// MARK: - 底栏Tab
enum BottomTab: String, CaseIterable, Hashable {
    case home
    case dynamic
    case history
    case favorites
    case profile

    var iconName: String {
        switch self {
        case .home: return "house.fill"
        case .dynamic: return "rectangle.3.group.fill"
        case .history: return "clock.fill"
        case .favorites: return "star.fill"
        case .profile: return "person.fill"
        }
    }

    var title: String {
        switch self {
        case .home: return "首页"
        case .dynamic: return "动态"
        case .history: return "历史"
        case .favorites: return "收藏"
        case .profile: return "我的"
        }
    }
}

let BottomTabColorMap: [BottomTab: Color] = [
    .home: iOSBlue,
    .dynamic: iOSOrange,
    .history: iOSTeal,
    .favorites: iOSRed,
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
        .tint(BottomTabColorMap[selectedTab] ?? iOSBlue)
        .environmentObject(themeManager)
    }

    @ViewBuilder
    func mainView(for tab: BottomTab) -> some View {
        switch tab {
        case .home: HomeScreen()
        case .dynamic: DynamicScreen()
        case .history: HistoryScreen()
        case .favorites: FavoriteScreen()
        case .profile: ProfileScreen()
        }
    }

    @ViewBuilder
    func destinationView(for route: AppRoute) -> some View {
        switch route {
        case .home: HomeScreen()
        case .dynamic: DynamicScreen()
        case .history: HistoryScreen()
        case .profile: ProfileScreen()
        case .favorite: FavoriteScreen()
        case .videoPlayer(let bvid, let cid, _): VideoPlayerScreen(bvid: bvid, cid: cid)
        case .search: SearchScreen()
        case .searchTrending: PlaceholderView(title: "热搜", icon: "flame.fill")
        case .live: PlaceholderView(title: "直播间", icon: "play.tv.fill")
        case .liveList: LiveScreen()
        case .liveArea: PlaceholderView(title: "直播分区", icon: "square.grid.3x3")
        case .liveFollowing: PlaceholderView(title: "关注的直播", icon: "heart.fill")
        case .bangumi: BangumiScreen()
        case .bangumiDetail: PlaceholderView(title: "番剧详情", icon: "tv.fill")
        case .settings: SettingsScreen()
        case .login: LoginScreen()
        case .space: PlaceholderView(title: "UP主空间", icon: "person.fill")
        case .downloadList: DownloadScreen()
        case .watchLater: PlaceholderView(title: "稍后再看", icon: "clock.badge")
        case .dynamicDetail: PlaceholderView(title: "动态详情", icon: "rectangle.3.group")
        case .topicDetail: PlaceholderView(title: "话题", icon: "number")
        case .articleDetail: PlaceholderView(title: "专栏", icon: "doc.text")
        case .web: PlaceholderView(title: "网页", icon: "safari")
        case .appearanceSettings: AppearanceSettingsScreen()
        case .playbackSettings: PlaybackSettingsScreen()
        case .permissionSettings: PlaceholderView(title: "权限管理", icon: "lock.shield")
        case .pluginsSettings: PlaceholderView(title: "插件中心", icon: "puzzlepiece")
        case .bottomBarSettings: PlaceholderView(title: "底栏设置", icon: "rectangle.bottomthird.inset.filled")
        case .iconSettings: PlaceholderView(title: "图标设置", icon: "app.badge")
        case .animationSettings: PlaceholderView(title: "动画设置", icon: "sparkles")
        case .tipsSettings: PlaceholderView(title: "小贴士", icon: "lightbulb")
        case .openSourceLicenses: PlaceholderView(title: "开源许可", icon: "doc.text")
        case .following: PlaceholderView(title: "关注列表", icon: "person.2")
        case .liveAreaDetail: PlaceholderView(title: "分区直播", icon: "antenna.radiowaves.left.and.right")
        case .story: PlaceholderView(title: "短视频", icon: "rectangle.portrait")
        case .offlineVideoPlayer: PlaceholderView(title: "离线播放", icon: "play.rectangle")
        case .category: PlaceholderView(title: "分类", icon: "folder")
        case .partition: PlaceholderView(title: "分区", icon: "square.grid.3x3")
        case .chat: PlaceholderView(title: "私信", icon: "envelope")
        case .inbox: InboxScreen()
        case .replyMe: PlaceholderView(title: "回复我的", icon: "arrowshape.turn.up.left")
        case .atMe: PlaceholderView(title: "@我的", icon: "at")
        case .likeMe: PlaceholderView(title: "赞我的", icon: "heart")
        case .systemNotice: PlaceholderView(title: "系统通知", icon: "bell")
        case .audioMode: PlaceholderView(title: "听视频", icon: "headphones")
        case .musicDetail: PlaceholderView(title: "音频", icon: "music.note")
        case .nativeMusic: PlaceholderView(title: "原生音频", icon: "music.note")
        case .settingsShare: PlaceholderView(title: "设置分享", icon: "square.and.arrow.up")
        case .webDavBackup: PlaceholderView(title: "WebDAV备份", icon: "icloud")
        case .seasonSeriesDetail: PlaceholderView(title: "合集", icon: "rectangle.stack")
        case .bangumiPlayer: PlaceholderView(title: "番剧播放", icon: "play.tv")
        case .onboarding: PlaceholderView(title: "新手引导", icon: "hand.wave")
        case .blockedList: PlaceholderView(title: "黑名单", icon: "nosign")
        case .jsonPluginEditor: PlaceholderView(title: "插件编辑", icon: "curlybraces")
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
