import Foundation

// MARK: - 用户Hash反向查找（CRC32暴力破解）
// B站弹幕 midHash = CRC32(mid字符串)，多项式0xEDB88320，结果用十进制字符串表示
final class UserHashLookup {
    static let shared = UserHashLookup()
    private var cache: [UInt32: Int64] = [:]
    private var activeTasks: [UInt32: Task<Int64?, Never>] = [:]

    private init() {}

    func lookup(_ hashStr: String) async -> Int64? {
        // 先尝试直接当UID解析（某些版本XML直接暴露mID）
        if let direct = Int64(hashStr), direct > 0, direct < 999_999_999 {
            // 验证：小UID大概率就是真实UID
            if hashStr.count <= 10 { return direct }
        }
        // 否则当作CRC32十进制值搜索
        guard let hashVal = UInt32(hashStr), hashVal != 0 else { return nil }
        if let cached = cache[hashVal] { return cached }
        if let existing = activeTasks[hashVal] { return await existing.value }

        let task = Task<Int64?, Never> { [weak self] in
            let result = await self?.bruteForce(hashVal)
            if let result { self?.cache[hashVal] = result }
            self?.activeTasks[hashVal] = nil
            return result
        }
        activeTasks[hashVal] = task
        return await task.value
    }

    private func bruteForce(_ target: UInt32) async -> Int64? {
        let batchSize: Int64 = 10_000_000
        var start: Int64 = 800_000_000
        while start > 0 {
            if Task.isCancelled { return nil }
            let end = max(start - batchSize, 1)
            for mid in stride(from: start, to: end, by: -1) {
                let s = String(mid)
                if Self.crc32Reflected(s) == target || Self.crc32Normal(s) == target { return mid }
            }
            start = end - 1
            await Task.yield()
        }
        return nil
    }

    /// 标准CRC32（反射多项式，zip/gzip，bit0优先）
    static func crc32Reflected(_ str: String) -> UInt32 {
        var crc: UInt32 = 0xFFFFFFFF
        for b in str.utf8 {
            crc ^= UInt32(b)
            for _ in 0..<8 {
                if (crc & 1) != 0 { crc = (crc >> 1) ^ 0xEDB88320 }
                else { crc >>= 1 }
            }
        }
        return ~crc
    }

    /// 正规多项式（bit31优先）
    static func crc32Normal(_ str: String) -> UInt32 {
        var crc: UInt32 = 0xFFFFFFFF
        for b in str.utf8 {
            crc ^= (UInt32(b) << 24)
            for _ in 0..<8 {
                if (crc & 0x80000000) != 0 { crc = (crc << 1) ^ 0x04C11DB7 }
                else { crc <<= 1 }
            }
        }
        return ~crc
    }


    /// B站弹幕使用的CRC32（标准多项式，输入为mid的字符串形式）
    static func biliCRC32(_ str: String) -> UInt32 {
        let bytes = Array(str.utf8)
        var crc: UInt32 = 0xFFFFFFFF
        for b in bytes {
            crc ^= UInt32(b)
            for _ in 0..<8 {
                if (crc & 1) != 0 {
                    crc = (crc >> 1) ^ 0xEDB88320
                } else {
                    crc >>= 1
                }
            }
        }
        return ~crc
    }
}
