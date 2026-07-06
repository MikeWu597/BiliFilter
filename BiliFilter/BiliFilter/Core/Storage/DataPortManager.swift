import Foundation
import Compression

// MARK: - 数据导入导出管理器
enum DataPortManager {
    private static let fm = FileManager.default

    // MARK: - 导出
    static func exportData() async throws -> URL {
        let tmpDir = fm.temporaryDirectory.appendingPathComponent("BiliFilter_export_\(UUID().uuidString.prefix(8))")
        try fm.createDirectory(at: tmpDir, withIntermediateDirectories: true)

        // 收集所有数据并写入
        try await exportVideoFilters(to: tmpDir)
        try await exportCommentFilters(to: tmpDir)
        try await exportDanmakuFilters(to: tmpDir)
        try await exportUIDFilters(to: tmpDir)
        try await exportUserTags(to: tmpDir)
        try await exportVideoTags(to: tmpDir)
        try await exportWatchHistory(to: tmpDir)

        // 压缩
        let zipURL = fm.temporaryDirectory.appendingPathComponent("BiliFilter_export.zip")
        try? fm.removeItem(at: zipURL)
        try await zipDirectory(tmpDir, to: zipURL)
        try? fm.removeItem(at: tmpDir)
        return zipURL
    }

    // MARK: - 导入
    static func importData(from zipURL: URL) async throws {
        let tmpDir = fm.temporaryDirectory.appendingPathComponent("BiliFilter_import_\(UUID().uuidString.prefix(8))")
        try fm.createDirectory(at: tmpDir, withIntermediateDirectories: true)
        defer { try? fm.removeItem(at: tmpDir) }

        try await unzipFile(zipURL, to: tmpDir)

        // 逐项导入
        try await importVideoFilters(from: tmpDir)
        try await importCommentFilters(from: tmpDir)
        try await importDanmakuFilters(from: tmpDir)
        try await importUIDFilters(from: tmpDir)
        try await importUserTags(from: tmpDir)
        try await importVideoTags(from: tmpDir)
        try await importWatchHistory(from: tmpDir)
    }

    // MARK: - 各模块导出

    private static func exportVideoFilters(to root: URL) async throws {
        let dir = root.appendingPathComponent("视频过滤")
        try fm.createDirectory(at: dir, withIntermediateDirectories: true)
        let settings = await MainActor.run { FilterSettings.shared }

        // 时长过滤
        if settings.durationEnabled {
            let sub = dir.appendingPathComponent("时长过滤")
            try fm.createDirectory(at: sub, withIntermediateDirectories: true)
            let rule: [String: Any] = ["type": "duration", "min": settings.durationMin, "max": settings.durationMax]
            try JSONSerialization.data(withJSONObject: rule).write(to: sub.appendingPathComponent("rule.json"))
            try exportFilteredCSV(to: sub.appendingPathComponent("filtered.csv"), headers: "bvid,title,duration,owner_name,owner_mid,cover_url,filter_reason,time",
                                   records: await MainActor.run { FilteredLog.shared.videoLog })
        }
        // 标题过滤
        if settings.titleEnabled {
            let sub = dir.appendingPathComponent("标题过滤")
            try fm.createDirectory(at: sub, withIntermediateDirectories: true)
            let rule: [String: Any] = ["type": "title", "min": settings.titleMin, "max": settings.titleMax]
            try JSONSerialization.data(withJSONObject: rule).write(to: sub.appendingPathComponent("rule.json"))
        }

        // 标题关键词过滤
        if settings.keywordFilterEnabled {
            let sub = dir.appendingPathComponent("标题关键词过滤")
            try fm.createDirectory(at: sub, withIntermediateDirectories: true)
            let rule: [String: Any] = ["type": "title_keyword", "keywords": settings.titleKeywords]
            try JSONSerialization.data(withJSONObject: rule).write(to: sub.appendingPathComponent("rule.json"))
        }

        // 首页出现次数过滤
        if settings.appearCountEnabled {
            let sub = dir.appendingPathComponent("首页出现次数过滤")
            try fm.createDirectory(at: sub, withIntermediateDirectories: true)
            let rule: [String: Any] = ["type": "appear_count", "max": settings.maxAppearCount]
            try JSONSerialization.data(withJSONObject: rule).write(to: sub.appendingPathComponent("rule.json"))
            // 导出出现次数数据
            let counts = await MainActor.run { AppearCountTracker.shared.rawCounts }
            let csv = "bvid,count\n" + counts.map { "\($0.key),\($0.value)" }.joined(separator: "\n")
            try csv.write(to: sub.appendingPathComponent("appear_counts.csv"), atomically: true, encoding: .utf8)
        }

        // 标记过滤（仅导出开关状态，标记数据由用户标记/视频标记模块导出）
        if settings.taggedUserFilterEnabled || settings.taggedVideoFilterEnabled {
            let sub = dir.appendingPathComponent("标记过滤")
            try fm.createDirectory(at: sub, withIntermediateDirectories: true)
            let rule: [String: Any] = [
                "type": "tagged",
                "taggedUser": settings.taggedUserFilterEnabled,
                "taggedVideo": settings.taggedVideoFilterEnabled
            ]
            try JSONSerialization.data(withJSONObject: rule).write(to: sub.appendingPathComponent("rule.json"))
        }
    }

    private static func exportCommentFilters(to root: URL) async throws {
        let dir = root.appendingPathComponent("评论区过滤")
        try fm.createDirectory(at: dir, withIntermediateDirectories: true)
        let settings = await MainActor.run { CommentFilterSettings.shared }

        if settings.levelFilterEnabled {
            let sub = dir.appendingPathComponent("等级过滤")
            try fm.createDirectory(at: sub, withIntermediateDirectories: true)
            let rule: [String: Any] = ["type": "level", "levels": Array(settings.selectedLevels).sorted()]
            try JSONSerialization.data(withJSONObject: rule).write(to: sub.appendingPathComponent("rule.json"))
        }
        if settings.keywordFilterEnabled {
            let sub = dir.appendingPathComponent("关键词过滤")
            try fm.createDirectory(at: sub, withIntermediateDirectories: true)
            let rule: [String: Any] = ["type": "keyword", "keywords": settings.keywords]
            try JSONSerialization.data(withJSONObject: rule).write(to: sub.appendingPathComponent("rule.json"))
            try exportFilteredCSV(to: sub.appendingPathComponent("filtered.csv"), headers: "rpid,content,username,user_mid,user_level,like_count,reply_count,filter_reason,time",
                                   records: await MainActor.run { FilteredLog.shared.commentLog })
        }
        if settings.nameFilterEnabled {
            let sub = dir.appendingPathComponent("用户名过滤")
            try fm.createDirectory(at: sub, withIntermediateDirectories: true)
            let rule: [String: Any] = ["type": "name", "keywords": settings.nameKeywords]
            try JSONSerialization.data(withJSONObject: rule).write(to: sub.appendingPathComponent("rule.json"))
        }
        if settings.lengthFilterEnabled {
            let sub = dir.appendingPathComponent("长度过滤")
            try fm.createDirectory(at: sub, withIntermediateDirectories: true)
            let rule: [String: Any] = ["type": "length", "min": settings.lengthMin, "max": settings.lengthMax]
            try JSONSerialization.data(withJSONObject: rule).write(to: sub.appendingPathComponent("rule.json"))
        }
    }

    private static func exportDanmakuFilters(to root: URL) async throws {
        let dir = root.appendingPathComponent("弹幕过滤")
        try fm.createDirectory(at: dir, withIntermediateDirectories: true)
        let settings = await MainActor.run { DanmakuFilterSettings.shared }

        if settings.enabled {
            let sub = dir.appendingPathComponent("关键词过滤")
            try fm.createDirectory(at: sub, withIntermediateDirectories: true)
            let rule: [String: Any] = ["type": "keyword", "keywords": settings.keywords]
            try JSONSerialization.data(withJSONObject: rule).write(to: sub.appendingPathComponent("rule.json"))
            try exportFilteredCSV(to: sub.appendingPathComponent("filtered.csv"), headers: "content,time,mode,color_hex,user_hash,filter_reason,time",
                                   records: await MainActor.run { FilteredLog.shared.danmakuLog })
        }
    }

    private static func exportUIDFilters(to root: URL) async throws {
        let dir = root.appendingPathComponent("用户过滤")
        try fm.createDirectory(at: dir, withIntermediateDirectories: true)
        let settings = await MainActor.run { UIDFilterSettings.shared }

        if settings.enabled {
            let sub = dir.appendingPathComponent("UID长度过滤")
            try fm.createDirectory(at: sub, withIntermediateDirectories: true)
            let rule: [String: Any] = ["type": "uid_length", "max": settings.maxUIDLength]
            try JSONSerialization.data(withJSONObject: rule).write(to: sub.appendingPathComponent("rule.json"))
            try exportFilteredCSV(to: sub.appendingPathComponent("filtered.csv"), headers: "mid,uname,level,sign,uid_length,filter_reason,time",
                                   records: await MainActor.run { FilteredLog.shared.uidLog })
        }
    }

    private static func exportUserTags(to root: URL) async throws {
        let dir = root.appendingPathComponent("用户标记")
        try fm.createDirectory(at: dir, withIntermediateDirectories: true)
        let tags = await MainActor.run { UserTagManager.shared.tags }

        for tag in tags {
            let csv = "mid,name,tagged_time\n" + zip(tag.mids, tag.names).map { mid, name in
                "\(mid),\"\(name.replacingOccurrences(of: "\"", with: "\"\""))\","
            }.joined(separator: "\n")
            try csv.write(to: dir.appendingPathComponent("\(sanitizeFileName(tag.name)).csv"), atomically: true, encoding: .utf8)
        }
    }

    private static func exportVideoTags(to root: URL) async throws {
        let dir = root.appendingPathComponent("视频标记")
        try fm.createDirectory(at: dir, withIntermediateDirectories: true)
        let tags = await MainActor.run { VideoTagManager.shared.tags }

        for tag in tags {
            let csv = "bvid,title,tagged_time\n" + zip(tag.bvids, tag.titles).map { bvid, title in
                "\(bvid),\"\(title.replacingOccurrences(of: "\"", with: "\"\""))\","
            }.joined(separator: "\n")
            try csv.write(to: dir.appendingPathComponent("\(sanitizeFileName(tag.name)).csv"), atomically: true, encoding: .utf8)
        }
    }

    private static func exportWatchHistory(to root: URL) async throws {
        let dir = root.appendingPathComponent("观看历史")
        try fm.createDirectory(at: dir, withIntermediateDirectories: true)
        let videos = await MainActor.run { WatchHistoryManager.shared.allVideos }
        guard !videos.isEmpty else { return }

        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        let data = try encoder.encode(videos)
        try data.write(to: dir.appendingPathComponent("history.json"))
    }

    private static func exportFilteredCSV(to url: URL, headers: String, records: [String]) throws {
        let csv = headers + "\n" + records.joined(separator: "\n")
        try csv.write(to: url, atomically: true, encoding: .utf8)
    }

    // MARK: - 各模块导入

    private static func importVideoFilters(from root: URL) async throws {
        let dir = root.appendingPathComponent("视频过滤")
        guard fm.fileExists(atPath: dir.path) else { return }
        await MainActor.run { FilteredLog.shared.videoLog.removeAll() }

        // 导入标题关键词过滤
        let kwDir = dir.appendingPathComponent("标题关键词过滤")
        if fm.fileExists(atPath: kwDir.path) {
            let ruleFile = kwDir.appendingPathComponent("rule.json")
            if let data = try? Data(contentsOf: ruleFile),
               let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let keywords = json["keywords"] as? [String] {
                await MainActor.run {
                    FilterSettings.shared.titleKeywords = keywords
                    FilterSettings.shared.keywordFilterEnabled = true
                }
            }
        }

        // 导入首页出现次数过滤
        let acDir = dir.appendingPathComponent("首页出现次数过滤")
        if fm.fileExists(atPath: acDir.path) {
            let ruleFile = acDir.appendingPathComponent("rule.json")
            if let data = try? Data(contentsOf: ruleFile),
               let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let max = json["max"] as? Int {
                await MainActor.run {
                    FilterSettings.shared.maxAppearCount = max
                    FilterSettings.shared.appearCountEnabled = true
                }
            }
            let csvFile = acDir.appendingPathComponent("appear_counts.csv")
            if let content = try? String(contentsOf: csvFile, encoding: .utf8) {
                var counts: [String: Int] = [:]
                for line in content.components(separatedBy: "\n").dropFirst() where !line.isEmpty {
                    let cols = line.components(separatedBy: ",")
                    if cols.count >= 2, let count = Int(cols[1]) {
                        counts[cols[0]] = count
                    }
                }
                await MainActor.run { AppearCountTracker.shared.importCounts(counts) }
            }
        }

        // 导入标记过滤开关
        let tagDir = dir.appendingPathComponent("标记过滤")
        if fm.fileExists(atPath: tagDir.path) {
            let ruleFile = tagDir.appendingPathComponent("rule.json")
            if let data = try? Data(contentsOf: ruleFile),
               let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                await MainActor.run {
                    FilterSettings.shared.taggedUserFilterEnabled = json["taggedUser"] as? Bool ?? false
                    FilterSettings.shared.taggedVideoFilterEnabled = json["taggedVideo"] as? Bool ?? false
                }
            }
        }
    }

    private static func importCommentFilters(from root: URL) async throws {
        let dir = root.appendingPathComponent("评论区过滤")
        guard fm.fileExists(atPath: dir.path) else { return }
        await MainActor.run { FilteredLog.shared.commentLog.removeAll() }
    }

    private static func importDanmakuFilters(from root: URL) async throws {
        let dir = root.appendingPathComponent("弹幕过滤")
        guard fm.fileExists(atPath: dir.path) else { return }
        await MainActor.run { FilteredLog.shared.danmakuLog.removeAll() }
    }

    private static func importUIDFilters(from root: URL) async throws {
        let dir = root.appendingPathComponent("用户过滤")
        guard fm.fileExists(atPath: dir.path) else { return }
        await MainActor.run { FilteredLog.shared.uidLog.removeAll() }
    }

    private static func importUserTags(from root: URL) async throws {
        let dir = root.appendingPathComponent("用户标记")
        guard fm.fileExists(atPath: dir.path) else { return }
        let tags = await MainActor.run { UserTagManager.shared }
        tags.tags.removeAll()

        for file in (try? fm.contentsOfDirectory(at: dir, includingPropertiesForKeys: nil)) ?? [] {
            guard file.pathExtension == "csv" else { continue }
            let name = file.deletingPathExtension().lastPathComponent
            let content = try String(contentsOf: file, encoding: .utf8)
            let lines = content.components(separatedBy: "\n").dropFirst()
            var mids: [Int64] = [], names: [String] = []
            for line in lines where !line.isEmpty {
                let cols = parseCSVLine(line)
                if cols.count >= 2, let mid = Int64(cols[0]) {
                    mids.append(mid); names.append(cols[1])
                }
            }
            await MainActor.run { tags.addTag(name: name) }
            if let tag = tags.tags.first(where: { $0.name == name }) {
                for (mid, uname) in zip(mids, names) {
                    await MainActor.run { tags.addUser(to: tag.id, mid: mid, name: uname) }
                }
            }
        }
    }

    private static func importVideoTags(from root: URL) async throws {
        let dir = root.appendingPathComponent("视频标记")
        guard fm.fileExists(atPath: dir.path) else { return }
        let tags = await MainActor.run { VideoTagManager.shared }
        tags.tags.removeAll()

        for file in (try? fm.contentsOfDirectory(at: dir, includingPropertiesForKeys: nil)) ?? [] {
            guard file.pathExtension == "csv" else { continue }
            let name = file.deletingPathExtension().lastPathComponent
            let content = try String(contentsOf: file, encoding: .utf8)
            let lines = content.components(separatedBy: "\n").dropFirst()
            var bvids: [String] = [], titles: [String] = []
            for line in lines where !line.isEmpty {
                let cols = parseCSVLine(line)
                if cols.count >= 2 { bvids.append(cols[0]); titles.append(cols[1]) }
            }
            await MainActor.run { tags.addTag(name: name) }
            if let tag = tags.tags.first(where: { $0.name == name }) {
                for (bvid, title) in zip(bvids, titles) {
                    await MainActor.run { tags.addVideo(to: tag.id, bvid: bvid, title: title) }
                }
            }
        }
    }

    private static func importWatchHistory(from root: URL) async throws {
        let dir = root.appendingPathComponent("观看历史")
        guard fm.fileExists(atPath: dir.path) else { return }
        let file = dir.appendingPathComponent("history.json")
        guard fm.fileExists(atPath: file.path) else { return }

        let data = try Data(contentsOf: file)
        let videos = try JSONDecoder().decode([WatchedVideo].self, from: data)
        await MainActor.run { WatchHistoryManager.shared.importVideos(videos) }
    }

    // MARK: - 工具

    private static func sanitizeFileName(_ name: String) -> String {
        let invalid = CharacterSet(charactersIn: "/\\:*?\"<>|")
        return name.components(separatedBy: invalid).joined(separator: "_")
    }

    private static func parseCSVLine(_ line: String) -> [String] {
        var cols: [String] = []
        var current = ""
        var inQuotes = false
        for ch in line {
            if ch == "\"" { inQuotes.toggle(); continue }
            if ch == "," && !inQuotes { cols.append(current); current = ""; continue }
            current.append(ch)
        }
        cols.append(current)
        return cols
    }

    private static func zipDirectory(_ source: URL, to dest: URL) async throws {
        let files = collectFiles(from: source)
        var localHeaders = Data()
        var centralDir = Data()
        var currentOffset: UInt32 = 0

        for (path, fileData) in files {
            let crc = crc32Of(fileData)
            let compressed = try (fileData as NSData).compressed(using: .zlib) as Data
            let compSize = UInt32(compressed.count)
            let uncompSize = UInt32(fileData.count)
            let nameData = path.data(using: .utf8)!
            let nameLen = UInt16(nameData.count)

            // Local file header
            var local: [UInt8] = []
            local.append(contentsOf: withBytes(of: UInt32(0x04034b50).littleEndian)) // signature
            local.append(contentsOf: withBytes(of: UInt16(20).littleEndian)) // version
            local.append(contentsOf: withBytes(of: UInt16(0).littleEndian)) // flags
            local.append(contentsOf: withBytes(of: UInt16(8).littleEndian)) // method=DEFLATE
            local.append(contentsOf: withBytes(of: UInt32(0).littleEndian)) // mtime
            local.append(contentsOf: withBytes(of: crc.littleEndian))
            local.append(contentsOf: withBytes(of: compSize.littleEndian))
            local.append(contentsOf: withBytes(of: uncompSize.littleEndian))
            local.append(contentsOf: withBytes(of: nameLen.littleEndian))
            local.append(contentsOf: withBytes(of: UInt16(0).littleEndian)) // extra
            local.append(contentsOf: nameData)
            let localOffset = currentOffset
            localHeaders.append(Data(local))
            localHeaders.append(compressed)
            currentOffset += UInt32(local.count) + compSize

            // Central directory entry
            var cd: [UInt8] = []
            cd.append(contentsOf: withBytes(of: UInt32(0x02014b50).littleEndian))
            cd.append(contentsOf: withBytes(of: UInt16(20).littleEndian)) // version made
            cd.append(contentsOf: withBytes(of: UInt16(20).littleEndian)) // version needed
            cd.append(contentsOf: withBytes(of: UInt16(0).littleEndian)) // flags
            cd.append(contentsOf: withBytes(of: UInt16(8).littleEndian)) // method
            cd.append(contentsOf: withBytes(of: UInt32(0).littleEndian)) // mtime
            cd.append(contentsOf: withBytes(of: crc.littleEndian))
            cd.append(contentsOf: withBytes(of: compSize.littleEndian))
            cd.append(contentsOf: withBytes(of: uncompSize.littleEndian))
            cd.append(contentsOf: withBytes(of: nameLen.littleEndian))
            cd.append(contentsOf: withBytes(of: UInt16(0).littleEndian)) // extra
            cd.append(contentsOf: withBytes(of: UInt16(0).littleEndian)) // comment
            cd.append(contentsOf: withBytes(of: UInt16(0).littleEndian)) // disk
            cd.append(contentsOf: withBytes(of: UInt16(0).littleEndian)) // internal
            cd.append(contentsOf: withBytes(of: UInt32(0).littleEndian)) // external
            cd.append(contentsOf: withBytes(of: localOffset.littleEndian)) // local header offset
            cd.append(contentsOf: nameData)
            centralDir.append(Data(cd))
        }

        let cdOffset = UInt32(localHeaders.count)
        let cdSize = UInt32(centralDir.count)
        var eocd: [UInt8] = []
        eocd.append(contentsOf: withBytes(of: UInt32(0x06054b50).littleEndian))
        eocd.append(contentsOf: withBytes(of: UInt16(0).littleEndian)) // disk
        eocd.append(contentsOf: withBytes(of: UInt16(0).littleEndian)) // cd disk
        eocd.append(contentsOf: withBytes(of: UInt16(files.count).littleEndian)) // cd count this disk
        eocd.append(contentsOf: withBytes(of: UInt16(files.count).littleEndian)) // cd total
        eocd.append(contentsOf: withBytes(of: cdSize.littleEndian))
        eocd.append(contentsOf: withBytes(of: cdOffset.littleEndian))
        eocd.append(contentsOf: withBytes(of: UInt16(0).littleEndian)) // comment length

        var result = Data()
        result.append(localHeaders)
        result.append(centralDir)
        result.append(Data(eocd))
        try result.write(to: dest)
    }

    private static func unzipFile(_ source: URL, to dest: URL) async throws {
        let zipData = try Data(contentsOf: source)
        // Parse ZIP: find EOCD, then read central directory, then extract files
        guard zipData.count > 22 else { throw NSError(domain: "ZIP", code: 1, userInfo: [NSLocalizedDescriptionKey: "文件太小"]) }

        // Find EOCD signature
        var eocdOffset = 0
        let end = min(65557, zipData.count - 22) // EOCD max search range
        for i in 0...end {
            let pos = zipData.count - 22 - i
            if zipData[pos] == 0x50 && zipData[pos+1] == 0x4b && zipData[pos+2] == 0x05 && zipData[pos+3] == 0x06 {
                eocdOffset = pos; break
            }
        }
        guard eocdOffset > 0 else { throw NSError(domain: "ZIP", code: 2, userInfo: [NSLocalizedDescriptionKey: "无效ZIP文件"]) }

        let eocd = zipData.subdata(in: eocdOffset..<zipData.count)
        let cdCount = Int(eocd[10..<12].withUnsafeBytes { $0.load(as: UInt16.self).littleEndian })
        let cdSize = Int(eocd[12..<16].withUnsafeBytes { $0.load(as: UInt32.self).littleEndian })
        let cdOffset = Int(eocd[16..<20].withUnsafeBytes { $0.load(as: UInt32.self).littleEndian })

        // Parse central directory
        var pos = cdOffset
        for _ in 0..<cdCount {
            // Skip to filename length (offset 28)
            let nameLen = Int(zipData[pos+28..<pos+30].withUnsafeBytes { $0.load(as: UInt16.self).littleEndian })
            let extraLen = Int(zipData[pos+30..<pos+32].withUnsafeBytes { $0.load(as: UInt16.self).littleEndian })
            let commentLen = Int(zipData[pos+32..<pos+34].withUnsafeBytes { $0.load(as: UInt16.self).littleEndian })
            let compSize = Int(zipData[pos+20..<pos+24].withUnsafeBytes { $0.load(as: UInt32.self).littleEndian })
            let localOffset = Int(zipData[pos+42..<pos+46].withUnsafeBytes { $0.load(as: UInt32.self).littleEndian })
            let path = String(data: zipData[pos+46..<pos+46+nameLen], encoding: .utf8) ?? ""; pos += 46 + nameLen + extraLen + commentLen

            // Read local header
            let localNameLen = Int(zipData[localOffset+26..<localOffset+28].withUnsafeBytes { $0.load(as: UInt16.self).littleEndian })
            let localExtraLen = Int(zipData[localOffset+28..<localOffset+30].withUnsafeBytes { $0.load(as: UInt16.self).littleEndian })
            let dataStart = localOffset + 30 + localNameLen + localExtraLen
            let compData = zipData[dataStart..<dataStart+compSize]

            let uncompressed = try (compData as NSData).decompressed(using: .zlib) as Data
            let fileURL = dest.appendingPathComponent(path)
            try fm.createDirectory(at: fileURL.deletingLastPathComponent(), withIntermediateDirectories: true)
            try uncompressed.write(to: fileURL)
        }
    }

    private static func withBytes<T>(of value: T) -> [UInt8] {
        var v = value
        return withUnsafeBytes(of: &v) { Array($0) }
    }

    private static func crc32Of(_ data: Data) -> UInt32 {
        var crc: UInt32 = 0xFFFFFFFF
        for b in data { crc ^= UInt32(b); for _ in 0..<8 { crc = (crc & 1) != 0 ? (crc >> 1) ^ 0xEDB88320 : crc >> 1 } }
        return ~crc
    }

    private static func collectFiles(from root: URL, base: String = "") -> [(String, Data)] {
        var result: [(String, Data)] = []
        guard let files = try? fm.contentsOfDirectory(at: root, includingPropertiesForKeys: nil) else { return result }
        for url in files.sorted(by: { $0.lastPathComponent < $1.lastPathComponent }) {
            var isDir: ObjCBool = false
            fm.fileExists(atPath: url.path, isDirectory: &isDir)
            let relPath = base.isEmpty ? url.lastPathComponent : base + "/" + url.lastPathComponent
            if isDir.boolValue {
                result.append(contentsOf: collectFiles(from: url, base: relPath))
            } else if let data = try? Data(contentsOf: url) {
                result.append((relPath, data))
            }
        }
        return result
    }

}

// MARK: - 过滤日志（追踪被过滤项）
@MainActor
final class FilteredLog {
    static let shared = FilteredLog()
    private let defaults = UserDefaults.standard
    private let maxRecords = 5000

    var videoLog: [String] {
        get { defaults.stringArray(forKey: "flog_video") ?? [] }
        set { defaults.set(Array(newValue.suffix(maxRecords)), forKey: "flog_video") }
    }
    var commentLog: [String] {
        get { defaults.stringArray(forKey: "flog_comment") ?? [] }
        set { defaults.set(Array(newValue.suffix(maxRecords)), forKey: "flog_comment") }
    }
    var danmakuLog: [String] {
        get { defaults.stringArray(forKey: "flog_danmaku") ?? [] }
        set { defaults.set(Array(newValue.suffix(maxRecords)), forKey: "flog_danmaku") }
    }
    var uidLog: [String] {
        get { defaults.stringArray(forKey: "flog_uid") ?? [] }
        set { defaults.set(Array(newValue.suffix(maxRecords)), forKey: "flog_uid") }
    }

    func logVideo(bvid: String, title: String, duration: Int, ownerName: String, ownerMid: Int64, coverUrl: String, reason: String) {
        let t = Date().timeIntervalSince1970
        let row = "\(bvid),\"\(title.replacingOccurrences(of: "\"", with: "\"\""))\",\(duration),\"\(ownerName)\",\(ownerMid),\"\(coverUrl)\",\"\(reason)\",\(Int64(t))"
        videoLog.append(row)
    }

    func logComment(rpid: Int64, content: String, username: String, userMid: Int64, level: Int?, like: Int, reply: Int, reason: String) {
        let t = Date().timeIntervalSince1970
        let safe = content.replacingOccurrences(of: "\"", with: "\"\"")
        let row = "\(rpid),\"\(safe)\",\"\(username)\",\(userMid),\(level ?? -1),\(like),\(reply),\"\(reason)\",\(Int64(t))"
        commentLog.append(row)
    }

    func logDanmaku(content: String, time: Double, mode: Int, colorHex: String, userHash: String, reason: String) {
        let t = Date().timeIntervalSince1970
        let safe = content.replacingOccurrences(of: "\"", with: "\"\"")
        let row = "\"\(safe)\",\(String(format:"%.2f",time)),\(mode),\"\(colorHex)\",\"\(userHash)\",\"\(reason)\",\(Int64(t))"
        danmakuLog.append(row)
    }

    func logUID(mid: Int64, uname: String, level: Int?, sign: String, reason: String) {
        let t = Date().timeIntervalSince1970
        let row = "\(mid),\"\(uname)\",\(level ?? -1),\"\(sign.replacingOccurrences(of: "\"", with: "\"\""))\",\(String(mid).count),\"\(reason)\",\(Int64(t))"
        uidLog.append(row)
    }
}
