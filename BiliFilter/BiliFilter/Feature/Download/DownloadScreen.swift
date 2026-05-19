import SwiftUI
import Combine

struct DownloadScreen: View {
    @StateObject private var viewModel = DownloadViewModel()
    var body: some View {
        Group {
            if viewModel.tasks.isEmpty {
                ContentUnavailableView("暂无下载", systemImage: "arrow.down.circle", description: Text("下载的视频将显示在这里"))
            } else {
                List {
                    ForEach(viewModel.tasks) { task in
                        HStack(spacing: 12) {
                            BiliCover(url: task.cover).frame(width: 100, height: 60)
                            VStack(alignment: .leading, spacing: 4) {
                                Text(task.title).font(.subheadline).lineLimit(2)
                                HStack {
                                    Text(task.qualityName).font(.caption2).foregroundColor(.secondary)
                                    Text("·").foregroundColor(.secondary)
                                    Text(task.statusText).font(.caption2)
                                        .foregroundColor(task.status == .downloading ? .accentColor : .secondary)
                                }
                                if task.status == .downloading {
                                    ProgressView(value: task.progress).tint(.accentColor)
                                }
                            }
                            Spacer()
                            Button {
                                viewModel.toggleTask(task)
                            } label: {
                                Image(systemName: task.status == .downloading ? "pause.circle" : "play.circle").font(.title2)
                            }
                        }
                    }
                    .onDelete { idx in idx.forEach { viewModel.removeTask(at: $0) } }
                }
            }
        }
        .navigationTitle("下载管理")
    }
}

enum DownloadStatus { case pending, downloading, paused, completed, failed }

struct DownloadTaskItem: Identifiable {
    let id: String; let title: String; let cover: String; let bvid: String; let cid: Int64; let qualityName: String
    var status: DownloadStatus = .pending; var progress: Double = 0; var totalBytes: Int64 = 0; var downloadedBytes: Int64 = 0; var localPath: String?
    var statusText: String {
        switch status {
        case .pending: return "等待中"; case .downloading: return "下载中"
        case .paused: return "已暂停"; case .completed: return "已完成"; case .failed: return "失败"
        }
    }
}

@MainActor final class DownloadViewModel: ObservableObject {
    @Published var tasks: [DownloadTaskItem] = []
    func startDownload(bvid: String, cid: Int64, title: String, cover: String, quality: String, url: URL) {
        tasks.insert(DownloadTaskItem(id: "\(bvid)_\(cid)", title: title, cover: cover, bvid: bvid, cid: cid, qualityName: quality), at: 0)
    }
    func toggleTask(_ task: DownloadTaskItem) {
        guard let i = tasks.firstIndex(where: { $0.id == task.id }) else { return }
        tasks[i].status = tasks[i].status == .downloading ? .paused : .downloading
    }
    func pauseAll() {
        for i in tasks.indices where tasks[i].status == .downloading { tasks[i].status = .paused }
    }
    func removeTask(at index: Int) { tasks.remove(at: index) }
}
#Preview { DownloadScreen() }
