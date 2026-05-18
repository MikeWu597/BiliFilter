import SwiftUI
import Combine

// MARK: - 下载管理
struct DownloadScreen: View {
    @StateObject private var viewModel = DownloadViewModel()
    @EnvironmentObject private var themeManager: ThemeManager

    var body: some View {
        NavigationStack {
            Group {
                if viewModel.tasks.isEmpty {
                    ContentUnavailableView("暂无下载", systemImage: "arrow.down.circle", description: Text("下载的视频将显示在这里"))
                } else {
                    List {
                        ForEach(viewModel.tasks) { task in
                            DownloadTaskRow(task: task) {
                                viewModel.toggleTask(task)
                            }
                        }
                        .onDelete { indexSet in
                            for idx in indexSet {
                                viewModel.removeTask(at: idx)
                            }
                        }
                    }
                }
            }
            .navigationTitle("下载管理")
            .toolbar {
                if !viewModel.tasks.isEmpty {
                    Button("全部暂停") { viewModel.pauseAll() }
                }
            }
            .background(themeManager.backgroundColor)
        }
    }
}

// MARK: - 下载任务行
struct DownloadTaskRow: View {
    let task: DownloadTaskItem
    let onToggle: () -> Void
    @EnvironmentObject private var themeManager: ThemeManager

    var body: some View {
        HStack(spacing: 12) {
            AsyncImage(url: URL(string: task.cover)) { phase in
                switch phase {
                case .success(let img): img.resizable().scaledToFill()
                default: Rectangle().fill(themeManager.surfaceColor)
                }
            }
            .frame(width: 100, height: 60)
            .cornerRadius(6)

            VStack(alignment: .leading, spacing: 4) {
                Text(task.title)
                    .font(.subheadline)
                    .foregroundColor(themeManager.primaryTextColor)
                    .lineLimit(2)
                HStack {
                    Text(task.qualityName)
                        .font(.caption2)
                        .foregroundColor(themeManager.secondaryTextColor)
                    Text("·")
                        .foregroundColor(themeManager.tertiaryTextColor)
                    Text(task.statusText)
                        .font(.caption2)
                        .foregroundColor(task.status == .downloading ? themeManager.accentColor : themeManager.tertiaryTextColor)
                }
                if task.status == .downloading {
                    ProgressView(value: task.progress)
                        .tint(themeManager.accentColor)
                }
            }
            Spacer()
            Button(action: onToggle) {
                Image(systemName: task.status == .downloading ? "pause.circle" : "play.circle")
                    .font(.title2)
                    .foregroundColor(themeManager.accentColor)
            }
        }
    }
}

// MARK: - 下载任务模型
enum DownloadStatus {
    case pending, downloading, paused, completed, failed
}

struct DownloadTaskItem: Identifiable {
    let id: String
    let title: String
    let cover: String
    let bvid: String
    let cid: Int64
    let qualityName: String
    var status: DownloadStatus = .pending
    var progress: Double = 0
    var totalBytes: Int64 = 0
    var downloadedBytes: Int64 = 0
    var localPath: String?

    var statusText: String {
        switch status {
        case .pending: return "等待中"
        case .downloading: return "下载中"
        case .paused: return "已暂停"
        case .completed: return "已完成"
        case .failed: return "失败"
        }
    }
}

// MARK: - 下载ViewModel
@MainActor
final class DownloadViewModel: ObservableObject {
    @Published var tasks: [DownloadTaskItem] = []

    private var downloadTasks: [String: URLSessionDownloadTask] = [:]
    private lazy var session: URLSession = {
        let config = URLSessionConfiguration.background(withIdentifier: "com.bilifilter.download")
        return URLSession(configuration: config)
    }()

    func startDownload(bvid: String, cid: Int64, title: String, cover: String, quality: String, url: URL) {
        let taskId = "\(bvid)_\(cid)"
        let task = DownloadTaskItem(id: taskId, title: title, cover: cover, bvid: bvid, cid: cid, qualityName: quality, status: .pending)
        tasks.insert(task, at: 0)
    }

    func toggleTask(_ task: DownloadTaskItem) {
        guard let idx = tasks.firstIndex(where: { $0.id == task.id }) else { return }
        if tasks[idx].status == .downloading {
            tasks[idx].status = .paused
            downloadTasks[task.id]?.suspend()
        } else if tasks[idx].status == .paused {
            tasks[idx].status = .downloading
            downloadTasks[task.id]?.resume()
        }
    }

    func pauseAll() {
        for i in tasks.indices where tasks[i].status == .downloading {
            tasks[i].status = .paused
            downloadTasks[tasks[i].id]?.suspend()
        }
    }

    func removeTask(at index: Int) {
        let task = tasks[index]
        downloadTasks[task.id]?.cancel()
        downloadTasks.removeValue(forKey: task.id)
        tasks.remove(at: index)
    }
}

#Preview {
    DownloadScreen().environmentObject(ThemeManager.shared)
}
