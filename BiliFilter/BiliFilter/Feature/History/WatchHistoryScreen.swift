import SwiftUI

struct WatchHistoryScreen: View {
    @StateObject private var history = WatchHistoryManager.shared
    @State private var searchText = ""
    @State private var showClearConfirm = false
    @EnvironmentObject private var themeManager: ThemeManager

    private var filteredVideos: [WatchedVideo] {
        history.search(keyword: searchText)
    }

    var body: some View {
        VStack(spacing: 0) {
            // 搜索框
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)
                TextField("搜索标题", text: $searchText)
                    .textFieldStyle(.plain)
                if !searchText.isEmpty {
                    Button {
                        searchText = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary)
                    }
                }
            }
            .padding(10)
            .background(Color(.systemGray6))
            .cornerRadius(10)
            .padding(.horizontal, 16)
            .padding(.vertical, 8)

            // 列表
            if filteredVideos.isEmpty {
                Spacer()
                VStack(spacing: 12) {
                    Image(systemName: "clock")
                        .font(.system(size: 48))
                        .foregroundColor(.secondary)
                    Text(searchText.isEmpty ? "暂无观看记录" : "未找到匹配结果")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                Spacer()
            } else {
                List {
                    ForEach(filteredVideos) { video in
                        NavigationLink(value: AppRoute.videoPlayer(bvid: video.bvid)) {
                            HistoryRow(video: video)
                        }
                    }
                    .onDelete { offsets in
                        deleteVideos(offsets: offsets)
                    }
                }
                .listStyle(.plain)
            }
        }
        .navigationTitle("观看历史")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                if !history.videos.isEmpty {
                    Button {
                        showClearConfirm = true
                    } label: {
                        Text("清空")
                            .foregroundColor(.red)
                    }
                }
            }
        }
        .alert("确认清空", isPresented: $showClearConfirm) {
            Button("取消", role: .cancel) {}
            Button("清空", role: .destructive) {
                history.clear()
            }
        } message: {
            Text("将删除所有观看记录，此操作不可撤销")
        }
    }

    private func deleteVideos(offsets: IndexSet) {
        let videosToDelete = offsets.map { filteredVideos[$0] }
        for video in videosToDelete {
            history.remove(bvid: video.bvid)
        }
    }
}

// MARK: - 历史记录行
struct HistoryRow: View {
    let video: WatchedVideo
    @EnvironmentObject private var themeManager: ThemeManager

    private var timeAgo: String {
        let interval = Date().timeIntervalSince(video.watchedAt)
        if interval < 60 { return "刚刚" }
        if interval < 3600 { return "\(Int(interval / 60))分钟前" }
        if interval < 86400 { return "\(Int(interval / 3600))小时前" }
        if interval < 2592000 { return "\(Int(interval / 86400))天前" }
        let formatter = DateFormatter()
        formatter.dateFormat = "MM-dd"
        return formatter.string(from: video.watchedAt)
    }

    var body: some View {
        HStack(spacing: 12) {
            BiliCover(url: video.coverUrl)
                .frame(width: 120, height: 68)
                .cornerRadius(6)

            VStack(alignment: .leading, spacing: 6) {
                Text(video.title)
                    .font(.subheadline)
                    .lineLimit(2)
                    .foregroundColor(themeManager.primaryTextColor)

                Spacer()

                Text(timeAgo)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(.vertical, 4)
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    NavigationStack {
        WatchHistoryScreen()
            .environmentObject(ThemeManager.shared)
    }
}
