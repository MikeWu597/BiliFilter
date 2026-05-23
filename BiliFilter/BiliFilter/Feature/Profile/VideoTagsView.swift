import SwiftUI
import Combine

// MARK: - 视频标记管理器
final class VideoTagManager: ObservableObject {
    static let shared = VideoTagManager()
    private let defaults = UserDefaults.standard
    private let tagsKey = "video_tags_data"

    struct Tag: Identifiable, Codable, Equatable {
        var id = UUID().uuidString
        var name: String
        var bvids: [String] = []
        var titles: [String] = []
    }

    @Published var tags: [Tag] = [] {
        didSet { save() }
    }

    private init() { load() }

    private func load() {
        guard let d = defaults.data(forKey: tagsKey),
              let decoded = try? JSONDecoder().decode([Tag].self, from: d) else { return }
        tags = decoded
    }

    private func save() {
        if let d = try? JSONEncoder().encode(tags) { defaults.set(d, forKey: tagsKey) }
    }

    func addTag(name: String) {
        guard !name.isEmpty, !tags.contains(where: { $0.name == name }) else { return }
        tags.append(Tag(name: name))
    }

    func removeTag(_ tag: Tag) { tags.removeAll { $0.id == tag.id } }

    func addVideo(to tagId: String, bvid: String, title: String) {
        guard let idx = tags.firstIndex(where: { $0.id == tagId }) else { return }
        if !tags[idx].bvids.contains(bvid) {
            tags[idx].bvids.append(bvid)
            tags[idx].titles.append(title)
        }
    }

    func removeVideo(from tagId: String, bvid: String) {
        guard let idx = tags.firstIndex(where: { $0.id == tagId }) else { return }
        if let i = tags[idx].bvids.firstIndex(of: bvid) {
            tags[idx].bvids.remove(at: i)
            tags[idx].titles.remove(at: i)
        }
    }
}

// MARK: - 视频标记管理页
struct VideoTagsView: View {
    @StateObject private var manager = VideoTagManager.shared
    @State private var newTagName = ""

    var body: some View {
        List {
            Section {
                HStack {
                    TextField("新建标记名称", text: $newTagName)
                    Button("添加") {
                        manager.addTag(name: newTagName.trimmingCharacters(in: .whitespaces))
                        newTagName = ""
                    }
                    .disabled(newTagName.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            ForEach(manager.tags) { tag in
                Section {
                    if tag.bvids.isEmpty {
                        Text("暂无视频").font(.caption).foregroundColor(.secondary)
                    }
                    ForEach(Array(zip(tag.bvids, tag.titles)), id: \.0) { bvid, title in
                        VStack(alignment: .leading, spacing: 2) {
                            Text(title).font(.subheadline).lineLimit(2)
                            Text(bvid).font(.caption2).foregroundColor(.secondary)
                        }
                    }
                    .onDelete { idxSet in
                        for i in idxSet {
                            manager.removeVideo(from: tag.id, bvid: tag.bvids[i])
                        }
                    }
                } header: {
                    HStack {
                        Text(tag.name).font(.headline)
                        Spacer()
                        Button { manager.removeTag(tag) } label: {
                            Image(systemName: "trash").font(.caption).foregroundColor(.red)
                        }
                    }
                }
            }
        }
        .navigationTitle("视频标记")
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - 添加视频标记Sheet
struct AddVideoTagSheet: View {
    let bvid: String
    let title: String
    @Environment(\.dismiss) private var dismiss
    @StateObject private var manager = VideoTagManager.shared
    @State private var newTagName = ""

    var body: some View {
        NavigationStack {
            List {
                Section("新建标记") {
                    HStack {
                        TextField("标记名称", text: $newTagName)
                        Button("创建并添加") {
                            let name = newTagName.trimmingCharacters(in: .whitespaces)
                            guard !name.isEmpty else { return }
                            manager.addTag(name: name)
                            if let tag = manager.tags.first(where: { $0.name == name }) {
                                manager.addVideo(to: tag.id, bvid: bvid, title: title)
                            }
                            newTagName = ""
                            dismiss()
                        }
                        .disabled(newTagName.trimmingCharacters(in: .whitespaces).isEmpty)
                    }
                }
                Section("已有标记") {
                    if manager.tags.isEmpty {
                        Text("暂无标记").font(.caption).foregroundColor(.secondary)
                    }
                    ForEach(manager.tags) { tag in
                        let marked = tag.bvids.contains(bvid)
                        Button {
                            if marked {
                                manager.removeVideo(from: tag.id, bvid: bvid)
                            } else {
                                manager.addVideo(to: tag.id, bvid: bvid, title: title)
                            }
                        } label: {
                            HStack {
                                Text(tag.name)
                                Spacer()
                                if marked { Image(systemName: "checkmark").foregroundColor(.accentColor) }
                            }
                        }
                    }
                }
            }
            .navigationTitle("标记视频")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("关闭") { dismiss() } }
            }
        }
    }
}
