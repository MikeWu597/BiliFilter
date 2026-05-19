import Foundation

// MARK: - B站API客户端
actor ApiClient {
    static let shared = ApiClient()
    static let guest = ApiClient(useCookies: false)

    private let session: URLSession
    private let useCookies: Bool
    private let cookieStorage = HTTPCookieStorage.sharedCookieStorage(forGroupContainerIdentifier: "BiliFilter")

    private var imgKey: String = ""
    private var subKey: String = ""
    private var wbiKeysLoaded = false

    private let userAgent = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36"

    private init(useCookies: Bool = true) {
        self.useCookies = useCookies
        let config = URLSessionConfiguration.default
        if useCookies {
            config.httpCookieStorage = cookieStorage
            config.httpShouldSetCookies = true
            config.httpCookieAcceptPolicy = .always
        }
        config.timeoutIntervalForRequest = 30
        config.timeoutIntervalForResource = 60
        self.session = URLSession(configuration: config)
    }

    // MARK: - WBI Key管理

    func ensureWbiKeys() async {
        guard !wbiKeysLoaded else { return }
        // 先从缓存加载
        if let cachedImg = UserDefaults.standard.string(forKey: "wbi_img_key"),
           let cachedSub = UserDefaults.standard.string(forKey: "wbi_sub_key"),
           !cachedImg.isEmpty, !cachedSub.isEmpty {
            self.imgKey = cachedImg; self.subKey = cachedSub
            self.wbiKeysLoaded = true
        }
        // 异步尝试刷新
        do {
            try await refreshWbiKeys()
        } catch {
            print("[ApiClient] WBI refresh failed: \(error)")
            if !wbiKeysLoaded {
                // 硬编码兜底密钥
                self.imgKey = "7cd084941338484aae1ad9425b84077c"
                self.subKey = "4932caff0ff746eab6f01bf08b70ac45"
                self.wbiKeysLoaded = true
            }
        }
    }

    private func refreshWbiKeys() async throws {
        // 先访问首页建立cookie会话，避免Cloudflare拦截
        if let homeUrl = URL(string: "https://www.bilibili.com/") {
            var homeReq = URLRequest(url: homeUrl)
            homeReq.setValue(userAgent, forHTTPHeaderField: "User-Agent")
            homeReq.setValue("en-US,en;q=0.9,zh-CN;q=0.8,zh;q=0.7", forHTTPHeaderField: "Accept-Language")
            _ = try? await session.data(for: homeReq)
        }

        var request = URLRequest(url: URL(string: "https://api.bilibili.com/x/web-interface/nav")!)
        request.setValue(userAgent, forHTTPHeaderField: "User-Agent")
        request.setValue("https://www.bilibili.com", forHTTPHeaderField: "Referer")
        request.setValue("en-US,en;q=0.9,zh-CN;q=0.8,zh;q=0.7", forHTTPHeaderField: "Accept-Language")
        injectCookies(into: &request)

        let (data, resp) = try await session.data(for: request)
        guard let httpResp = resp as? HTTPURLResponse, httpResp.statusCode == 200 else {
            throw ApiError.invalidResponse
        }
        saveCookies(from: httpResp)

        // 用 nav 接口返回的 wbi_img 提取密钥
        struct NavResp: Codable {
            struct Data: Codable {
                struct WbiImg: Codable { let img_url: String; let sub_url: String }
                let wbi_img: WbiImg
            }
            let code: Int; let data: Data?
        }
        let decoded = try JSONDecoder().decode(NavResp.self, from: data)
        if let wbi = decoded.data?.wbi_img {
            let img = extractKeyFromUrl(wbi.img_url)
            let sub = extractKeyFromUrl(wbi.sub_url)
            UserDefaults.standard.set(img, forKey: "wbi_img_key")
            UserDefaults.standard.set(sub, forKey: "wbi_sub_key")
            self.imgKey = img; self.subKey = sub
            self.wbiKeysLoaded = true
        }
    }

    private func extractKeyFromUrl(_ urlString: String) -> String {
        let components = urlString.components(separatedBy: "/")
        guard let filename = components.last else { return "" }
        return filename.components(separatedBy: ".").first ?? ""
    }

    // MARK: - 通用请求方法

    func request<T: Codable>(
        _ api: BiliAPI,
        needsWbi: Bool = false,
        includeRiskFingerprint: Bool = false
    ) async throws -> T {
        var url = api.url
        var queryParams: [String: String] = [:]

        if needsWbi {
            await ensureWbiKeys()
            if wbiKeysLoaded {
                var params: [String: String] = [:]
                if let components = url?.query() {
                    let pairs = components.components(separatedBy: "&")
                    for pair in pairs {
                        let kv = pair.components(separatedBy: "=")
                        if kv.count == 2 {
                            params[kv[0]] = kv[1].removingPercentEncoding ?? kv[1]
                        }
                    }
                }
                let signedParams = WbiSign.sign(params: params, imgKey: imgKey, subKey: subKey, includeRiskFingerprint: includeRiskFingerprint)
                queryParams = signedParams
            }
        }

        var components = URLComponents()
        components.scheme = api.scheme
        components.host = api.baseHost
        components.path = api.path
        if !queryParams.isEmpty {
            components.queryItems = queryParams.map { URLQueryItem(name: $0.key, value: $0.value) }
        } else {
            components.queryItems = api.queryItems.isEmpty ? nil : api.queryItems
        }
        url = components.url
        guard let finalUrl = url else { throw ApiError.invalidURL }

        var request = URLRequest(url: finalUrl)
        request.httpMethod = api.httpMethod
        request.setValue(userAgent, forHTTPHeaderField: "User-Agent")
        request.setValue("https://www.bilibili.com", forHTTPHeaderField: "Referer")
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        // 注入Cookie
        injectCookies(into: &request)

        if api.httpMethod == "POST" {
            if let body = api.body {
                request.httpBody = body
                request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
            }
        }

        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw ApiError.invalidResponse
        }

        if httpResponse.statusCode != 200 {
            throw ApiError.httpError(httpResponse.statusCode)
        }

        // 保存响应Cookie
        saveCookies(from: httpResponse)

        let decoder = JSONDecoder()
        do {
            let result = try decoder.decode(T.self, from: data)
            return result
        } catch {
            // 尝试打印错误响应body
            if let body = String(data: data, encoding: .utf8) {
                print("[ApiClient] Decode error for \(finalUrl.path): \(error)")
                print("[ApiClient] Response body: \(String(body.prefix(500)))")
            }
            throw ApiError.decodingError(error)
        }
    }

    // MARK: - POST表单请求

    func postForm<T: Codable>(
        _ api: BiliAPI,
        formFields: [String: String]
    ) async throws -> T {
        guard let url = api.url else { throw ApiError.invalidURL }

        var components = URLComponents()
        components.queryItems = formFields.map { URLQueryItem(name: $0.key, value: $0.value) }
        let bodyString = components.percentEncodedQuery ?? ""

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.httpBody = bodyString.data(using: .utf8)
        request.setValue(userAgent, forHTTPHeaderField: "User-Agent")
        request.setValue("https://www.bilibili.com", forHTTPHeaderField: "Referer")
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")

        injectCookies(into: &request)

        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw ApiError.invalidResponse
        }
        saveCookies(from: httpResponse)

        return try JSONDecoder().decode(T.self, from: data)
    }

    // MARK: - Cookie管理

    private func injectCookies(into request: inout URLRequest) {
        guard useCookies, let url = request.url else { return }
        var cookies: [HTTPCookie] = []

        // buvid3
        let buvid3 = TokenManager.shared.buvid3
        if let cookie = HTTPCookie(properties: [
            .domain: url.host ?? "bilibili.com",
            .path: "/",
            .name: "buvid3",
            .value: buvid3,
        ]) { cookies.append(cookie) }

        // SESSDATA
        if let sessdata = TokenManager.shared.sessdata, !sessdata.isEmpty {
            if let cookie = HTTPCookie(properties: [
                .domain: "bilibili.com",
                .path: "/",
                .name: "SESSDATA",
                .value: sessdata,
            ]) { cookies.append(cookie) }
        }

        // bili_jct
        if let csrf = TokenManager.shared.csrf, !csrf.isEmpty {
            if let cookie = HTTPCookie(properties: [
                .domain: "bilibili.com",
                .path: "/",
                .name: "bili_jct",
                .value: csrf,
            ]) { cookies.append(cookie) }
        }

        let headers = HTTPCookie.requestHeaderFields(with: cookies)
        for (key, value) in headers {
            request.setValue(value, forHTTPHeaderField: key)
        }
    }

    private func saveCookies(from response: HTTPURLResponse) {
        guard let headerFields = response.allHeaderFields as? [String: String],
              let url = response.url else { return }
        let cookies = HTTPCookie.cookies(withResponseHeaderFields: headerFields, for: url)
        for cookie in cookies {
            if cookie.name == "SESSDATA" {
                TokenManager.shared.sessdata = cookie.value
            } else if cookie.name == "bili_jct" {
                TokenManager.shared.csrf = cookie.value
            }
        }
    }
}

// MARK: - API错误
enum ApiError: Error {
    case invalidURL
    case invalidResponse
    case httpError(Int)
    case decodingError(Error)
    case networkError(Error)
    case biliError(code: Int, message: String)
}

extension ApiError: LocalizedError {
    var errorDescription: String? {
        switch self {
        case .invalidURL: return "无效的URL"
        case .invalidResponse: return "无效的响应"
        case .httpError(let code): return "HTTP错误: \(code)"
        case .decodingError(let error): return "解析错误: \(error.localizedDescription)"
        case .networkError(let error): return "网络错误: \(error.localizedDescription)"
        case .biliError(let code, let message): return "B站错误 [\(code)]: \(message)"
        }
    }
}

// MARK: - URL Query String helper
extension URL {
    func query() -> String? {
        if let queryItems = URLComponents(url: self, resolvingAgainstBaseURL: false)?.queryItems {
            return queryItems.map { "\($0.name)=\($0.value ?? "")" }.joined(separator: "&")
        }
        return nil
    }
}
