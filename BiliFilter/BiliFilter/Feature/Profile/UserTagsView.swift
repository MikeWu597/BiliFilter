import SwiftUI
import Combine

// MARK: - 用户标记管理器
final class UserTagManager: ObservableObject {
    static let shared = UserTagManager()
    private let defaults = UserDefaults.standard
    private let tagsKey = "user_tags_data"

    struct Tag: Identifiable, Codable, Equatable {
        var id = UUID().uuidString
        var name: String
        var mids: [Int64] = []
        var names: [String] = [] // 对应的用户名
    }

    @Published var tags: [Tag] = [] {
        didSet { save() }
    }

    private init() {
        load()
    }

    private func load() {
        guard let data = defaults.data(forKey: tagsKey),
              let decoded = try? JSONDecoder().decode([Tag].self, from: data) else { return }
        tags = decoded
    }

    private func save() {
        if let data = try? JSONEncoder().encode(tags) {
            defaults.set(data, forKey: tagsKey)
        }
    }

    func addTag(name: String) {
        guard !name.isEmpty, !tags.contains(where: { $0.name == name }) else { return }
        tags.append(Tag(name: name))
    }

    func removeTag(_ tag: Tag) {
        tags.removeAll { $0.id == tag.id }
    }

    func addUser(to tagId: String, mid: Int64, name: String) {
        guard let idx = tags.firstIndex(where: { $0.id == tagId }) else { return }
        if !tags[idx].mids.contains(mid) {
            tags[idx].mids.append(mid)
            tags[idx].names.append(name)
        }
    }

    func removeUser(from tagId: String, mid: Int64) {
        guard let idx = tags.firstIndex(where: { $0.id == tagId }) else { return }
        if let userIdx = tags[idx].mids.firstIndex(of: mid) {
            tags[idx].mids.remove(at: userIdx)
            tags[idx].names.remove(at: userIdx)
        }
    }

    func tagsForUser(mid: Int64) -> [Tag] {
        tags.filter { $0.mids.contains(mid) }
    }
}

// MARK: - 用户标记管理页
struct UserTagsView: View {
    @StateObject private var manager = UserTagManager.shared
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
                    if tag.mids.isEmpty {
                        Text("暂无用户").font(.caption).foregroundColor(.secondary)
                    }
                    ForEach(Array(zip(tag.mids, tag.names)), id: \.0) { mid, name in
                        HStack {
                            Text(name).font(.subheadline)
                            Spacer()
                            Text("UID:\(mid)").font(.caption2).foregroundColor(.secondary)
                        }
                    }
                    .onDelete { idxSet in
                        for i in idxSet {
                            manager.removeUser(from: tag.id, mid: tag.mids[i])
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
        .navigationTitle("用户标记")
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - 添加标记Sheet
struct AddUserTagSheet: View {
    let mid: Int64
    let userName: String
    @Environment(\.dismiss) private var dismiss
    @StateObject private var manager = UserTagManager.shared
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
                                manager.addUser(to: tag.id, mid: mid, name: userName)
                            }
                            newTagName = ""
                            dismiss()
                        }
                        .disabled(newTagName.trimmingCharacters(in: .whitespaces).isEmpty)
                    }
                }
                Section("已有标记") {
                    if manager.tags.isEmpty {
                        Text("暂无标记，请先创建").font(.caption).foregroundColor(.secondary)
                    }
                    ForEach(manager.tags) { tag in
                        let isMember = tag.mids.contains(mid)
                        Button {
                            if isMember {
                                manager.removeUser(from: tag.id, mid: mid)
                            } else {
                                manager.addUser(to: tag.id, mid: mid, name: userName)
                            }
                        } label: {
                            HStack {
                                Text(tag.name)
                                Spacer()
                                if isMember {
                                    Image(systemName: "checkmark").foregroundColor(.accentColor)
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("标记用户")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("关闭") { dismiss() }
                }
            }
        }
    }
}
