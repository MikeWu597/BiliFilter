import SwiftUI

// MARK: - 路由定义
enum AppRoute: Hashable {
    case home
    case dynamic
    case history
    case profile

    // 视频
    case videoPlayer(bvid: String, cid: Int64 = 0, aid: Int64 = 0)
    case videoDetail(bvid: String)

    // 搜索
    case search
    case searchTrending
    case topicDetail(topicId: Int64)

    // 直播
    case live(roomId: Int64, title: String = "", uname: String = "")
    case liveList
    case liveArea
    case liveFollowing
    case liveAreaDetail(parentAreaId: Int, areaId: Int, title: String)

    // 番剧
    case bangumi(initialType: Int = 1)
    case bangumiDetail(seasonId: Int64, epId: Int64 = 0)
    case bangumiPlayer(seasonId: Int64, epId: Int64, resumePositionMs: Int64 = 0)

    // 动态
    case dynamicDetail(dynamicId: String)
    case articleDetail(articleId: Int64, title: String? = nil)

    // 空间
    case space(mid: Int64)
    case following(mid: Int64)

    // 列表
    case favorite
    case watchLater
    case downloadList

    // 设置
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

    // 登录
    case login

    // WebView
    case web(url: String, title: String? = nil)

    // 其他
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

    var route: AppRoute {
        switch self {
        case .home: return .home
        case .dynamic: return .dynamic
        case .history: return .history
        case .favorites: return .favorite
        case .profile: return .profile
        }
    }
}

// MARK: - Tab颜色
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
                    destinationView(for: tab.route)
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
    func destinationView(for route: AppRoute) -> some View {
        switch route {
        case .home:
            PlaceholderView(title: "首页", icon: "house.fill")
        case .dynamic:
            PlaceholderView(title: "动态", icon: "rectangle.3.group.fill")
        case .history:
            PlaceholderView(title: "历史", icon: "clock.fill")
        case .profile:
            PlaceholderView(title: "我的", icon: "person.fill")
        case .favorite:
            PlaceholderView(title: "收藏", icon: "star.fill")
        case .videoPlayer(let bvid, let cid, let aid):
            PlaceholderView(title: "播放器", subtitle: "bvid: \(bvid) cid: \(cid)")
        case .videoDetail(let bvid):
            PlaceholderView(title: "视频详情", subtitle: bvid)
        case .search:
            PlaceholderView(title: "搜索", icon: "magnifyingglass")
        case .searchTrending:
            PlaceholderView(title: "热搜", icon: "flame.fill")
        case .live(let roomId, let title, _):
            PlaceholderView(title: "直播间", subtitle: title.isEmpty ? "房间号: \(roomId)" : title)
        case .liveList:
            PlaceholderView(title: "直播列表", icon: "antenna.radiowaves.left.and.right")
        case .liveArea:
            PlaceholderView(title: "直播分区", icon: "square.grid.3x3")
        case .liveFollowing:
            PlaceholderView(title: "关注的直播", icon: "heart.fill")
        case .bangumi:
            PlaceholderView(title: "番剧", icon: "tv.fill")
        case .bangumiDetail(let seasonId, _):
            PlaceholderView(title: "番剧详情", subtitle: "season: \(seasonId)")
        case .settings:
            PlaceholderView(title: "设置", icon: "gearshape.fill")
        case .login:
            PlaceholderView(title: "登录", icon: "person.badge.key")
        case .space(let mid):
            PlaceholderView(title: "UP主空间", subtitle: "mid: \(mid)")
        case .downloadList:
            PlaceholderView(title: "下载列表", icon: "arrow.down.circle.fill")
        case .watchLater:
            PlaceholderView(title: "稍后再看", icon: "clock.badge")
        case .dynamicDetail(let id):
            PlaceholderView(title: "动态详情", subtitle: id)
        case .topicDetail(let topicId):
            PlaceholderView(title: "话题", subtitle: "id: \(topicId)")
        case .articleDetail(let id, let title):
            PlaceholderView(title: title ?? "专栏", subtitle: "id: \(id)")
        case .web(let url, let title):
            PlaceholderView(title: title ?? "网页", subtitle: url)
        case .appearanceSettings:
            PlaceholderView(title: "外观设置", icon: "paintpalette.fill")
        case .playbackSettings:
            PlaceholderView(title: "播放设置", icon: "play.rectangle.fill")
        case .permissionSettings:
            PlaceholderView(title: "权限管理", icon: "lock.shield.fill")
        case .pluginsSettings:
            PlaceholderView(title: "插件中心", icon: "puzzlepiece.extension.fill")
        case .bottomBarSettings:
            PlaceholderView(title: "底栏设置", icon: "rectangle.bottomthird.inset.filled")
        case .iconSettings:
            PlaceholderView(title: "图标设置", icon: "app.badge.fill")
        case .animationSettings:
            PlaceholderView(title: "动画设置", icon: "sparkles")
        case .tipsSettings:
            PlaceholderView(title: "小贴士", icon: "lightbulb.fill")
        case .openSourceLicenses:
            PlaceholderView(title: "开源许可", icon: "doc.text.fill")
        case .following(let mid):
            PlaceholderView(title: "关注列表", subtitle: "mid: \(mid)")
        case .liveAreaDetail(_, _, let title):
            PlaceholderView(title: title, icon: "antenna.radiowaves.left.and.right")
        case .story:
            PlaceholderView(title: "竖屏短视频", icon: "rectangle.portrait.fill")
        case .offlineVideoPlayer(let taskId):
            PlaceholderView(title: "离线播放", subtitle: taskId)
        case .category(_, let name):
            PlaceholderView(title: name, icon: "folder.fill")
        case .partition:
            PlaceholderView(title: "分区", icon: "square.grid.3x3")
        case .chat(let talkerId, _, let userName):
            PlaceholderView(title: userName, subtitle: "私信")
        case .inbox:
            PlaceholderView(title: "消息中心", icon: "envelope.fill")
        case .replyMe:
            PlaceholderView(title: "回复我的", icon: "arrowshape.turn.up.left.fill")
        case .atMe:
            PlaceholderView(title: "@我的", icon: "at")
        case .likeMe:
            PlaceholderView(title: "赞我的", icon: "heart.fill")
        case .systemNotice:
            PlaceholderView(title: "系统通知", icon: "bell.fill")
        case .audioMode:
            PlaceholderView(title: "听视频", icon: "headphones")
        case .musicDetail(let sid):
            PlaceholderView(title: "音频", subtitle: "sid: \(sid)")
        case .nativeMusic(let title, _, _):
            PlaceholderView(title: title, icon: "music.note")
        case .settingsShare:
            PlaceholderView(title: "设置分享", icon: "square.and.arrow.up.fill")
        case .webDavBackup:
            PlaceholderView(title: "WebDAV备份", icon: "icloud.fill")
        case .seasonSeriesDetail(_, let id, _, let title, _):
            PlaceholderView(title: title, subtitle: "id: \(id)")
        case .bangumiPlayer(let seasonId, let epId, _):
            PlaceholderView(title: "番剧播放", subtitle: "s\(seasonId)e\(epId)")
        case .onboarding:
            PlaceholderView(title: "新手引导", icon: "hand.wave.fill")
        case .blockedList:
            PlaceholderView(title: "黑名单", icon: "nosign")
        case .jsonPluginEditor:
            PlaceholderView(title: "JSON插件编辑", icon: "curlybraces")
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

// MARK: - Preview
#Preview {
    AppNavigation()
}
