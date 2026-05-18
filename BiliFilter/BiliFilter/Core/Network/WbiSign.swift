import Foundation
import CommonCrypto

// MARK: - WBI签名工具
enum WbiSign {
    private static let mixinKeyEncTab: [Int] = [
        46, 47, 18, 2, 53, 8, 23, 32, 15, 50, 10, 31, 58, 3, 45, 35, 27, 43, 5, 49,
        33, 9, 42, 19, 29, 28, 14, 39, 12, 38, 41, 13, 37, 48, 7, 16, 24, 55, 40,
        61, 26, 17, 0, 1, 60, 51, 30, 4, 22, 25, 54, 21, 56, 59, 6, 63, 57, 62, 11,
        36, 20, 34, 44, 52
    ]

    private static func getMixinKey(orig: String) -> String {
        var result = ""
        for i in mixinKeyEncTab {
            if i < orig.count {
                let index = orig.index(orig.startIndex, offsetBy: i)
                result.append(orig[index])
            }
        }
        return String(result.prefix(32))
    }

    private static func filterIllegalChars(_ value: String) -> String {
        let pattern = "[!'()*]"
        return value.replacingOccurrences(of: pattern, with: "", options: .regularExpression)
    }

    private static func encodeURIComponent(_ value: String) -> String {
        var allowed = CharacterSet.urlQueryAllowed
        allowed.remove(charactersIn: "!*'();:@&=+$,/?%#[]")
        return value.addingPercentEncoding(withAllowedCharacters: allowed) ?? value
    }

    private static func md5(_ string: String) -> String {
        let data = Data(string.utf8)
        var digest = [UInt8](repeating: 0, count: Int(CC_MD5_DIGEST_LENGTH))
        data.withUnsafeBytes { bytes in
            _ = CC_MD5(bytes.baseAddress, CC_LONG(data.count), &digest)
        }
        return digest.map { String(format: "%02x", $0) }.joined()
    }

    /// WBI签名
    static func sign(
        params: [String: String],
        imgKey: String,
        subKey: String,
        includeRiskFingerprint: Bool = false
    ) -> [String: String] {
        let mixinKey = getMixinKey(orig: imgKey + subKey)
        let currTime = Int(Date().timeIntervalSince1970)

        var rawParams: [String: String] = [:]
        for (key, value) in params {
            rawParams[key] = filterIllegalChars(value)
        }
        rawParams["wts"] = String(currTime)

        if includeRiskFingerprint {
            rawParams["dm_img_list"] = "[]"
            rawParams["dm_img_str"] = "V2ViR0wgMS4wIChPcGVuR0wgRVMgMi4wIENocm9taXVtKQ"
            rawParams["dm_cover_img_str"] = "QU5HTEUgKE5WSURJQSwgTlZJRElBIEdlRm9yY2UgR1RYIDEwNjAgNkdCIERpcmVjdDNEMTEgdnNfNV8wIHBzXzVfMCwgRDNEMTEp"
            rawParams["dm_img_inter"] = #"{"ds":[],"wh":[0,0,0],"of":[0,0,0]}"#
        }

        let sortedKeys = rawParams.keys.sorted()
        var queryParts: [String] = []
        for key in sortedKeys {
            guard let value = rawParams[key] else { continue }
            let encodedValue = encodeURIComponent(value)
            queryParts.append("\(key)=\(encodedValue)")
        }
        let queryString = queryParts.joined(separator: "&")

        let strToHash = queryString + mixinKey
        let wRid = md5(strToHash)

        rawParams["w_rid"] = wRid
        return rawParams
    }
}
