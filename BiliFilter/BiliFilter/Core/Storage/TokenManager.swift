import Foundation

final class TokenManager {
    static let shared = TokenManager()

    private let defaults = UserDefaults.standard

    var buvid3: String {
        if let cached = defaults.string(forKey: "buvid3"), !cached.isEmpty {
            return cached
        }
        let newId = UUID().uuidString + "infoc"
        defaults.set(newId, forKey: "buvid3")
        return newId
    }

    private init() {}
}
