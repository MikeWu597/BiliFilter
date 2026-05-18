import Foundation
import Combine

// MARK: - 令牌管理器
final class TokenManager: ObservableObject {
    static let shared = TokenManager()

    private let defaults = UserDefaults.standard

    @Published var sessdata: String? {
        didSet { defaults.set(sessdata, forKey: "sessdata") }
    }
    @Published var csrf: String? {
        didSet { defaults.set(csrf, forKey: "bili_jct") }
    }
    @Published var accessToken: String? {
        didSet { defaults.set(accessToken, forKey: "access_token") }
    }
    @Published var refreshToken: String? {
        didSet { defaults.set(refreshToken, forKey: "refresh_token") }
    }
    @Published var mid: Int64 {
        didSet { defaults.set(String(mid), forKey: "dedeuserid") }
    }
    @Published var isVip: Bool {
        didSet { defaults.set(isVip, forKey: "is_vip") }
    }
    @Published var isLoggedIn: Bool {
        didSet { defaults.set(isLoggedIn, forKey: "is_logged_in") }
    }

    var buvid3: String {
        if let cached = defaults.string(forKey: "buvid3"), !cached.isEmpty {
            return cached
        }
        let newId = UUID().uuidString + "infoc"
        defaults.set(newId, forKey: "buvid3")
        return newId
    }

    private init() {
        self.sessdata = defaults.string(forKey: "sessdata")
        self.csrf = defaults.string(forKey: "bili_jct")
        self.accessToken = defaults.string(forKey: "access_token")
        self.refreshToken = defaults.string(forKey: "refresh_token")
        self.mid = Int64(defaults.string(forKey: "dedeuserid") ?? "") ?? 0
        self.isVip = defaults.bool(forKey: "is_vip")
        self.isLoggedIn = defaults.bool(forKey: "is_logged_in")
    }

    func logout() {
        sessdata = nil
        csrf = nil
        accessToken = nil
        refreshToken = nil
        mid = 0
        isVip = false
        isLoggedIn = false
    }

    func login(sessdata: String, csrf: String, mid: Int64) {
        self.sessdata = sessdata
        self.csrf = csrf
        self.mid = mid
        self.isLoggedIn = true
    }
}
