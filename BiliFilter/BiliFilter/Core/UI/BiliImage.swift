import SwiftUI

// MARK: - B站图片加载器 (非泛型，支持缓存+Referer)
actor BiliImageLoader {
    static let shared = BiliImageLoader()

    private let session: URLSession = {
        let config = URLSessionConfiguration.default
        config.httpAdditionalHeaders = [
            "User-Agent": "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36",
            "Referer": "https://www.bilibili.com",
        ]
        return URLSession(configuration: config)
    }()

    private let cache = NSCache<NSString, UIImage>()

    func load(_ urlString: String?) async -> UIImage? {
        guard let urlString = urlString?.replacingOccurrences(of: "http://", with: "https://"),
              let url = URL(string: urlString) else { return nil }

        let key = NSString(string: urlString)
        if let cached = cache.object(forKey: key) { return cached }

        do {
            let (data, _) = try await session.data(from: url)
            if let image = UIImage(data: data) {
                cache.setObject(image, forKey: key)
                return image
            }
        } catch {}
        return nil
    }
}

// MARK: - 封面图组件
struct BiliCover: View {
    let url: String?
    var cornerRadius: CGFloat = 8
    var aspectRatio: CGFloat = 16/9

    @State private var image: UIImage?
    @State private var didFail = false

    var body: some View {
        Group {
            if let image = image {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(aspectRatio, contentMode: .fill)
                    .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
            } else if didFail {
                ZStack {
                    Color(.systemGray6)
                    Image(systemName: "photo").foregroundColor(.gray)
                }
                .aspectRatio(aspectRatio, contentMode: .fit)
                .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
            } else {
                Color(.systemGray6)
                    .aspectRatio(aspectRatio, contentMode: .fit)
                    .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
            }
        }
        .task {
            image = await BiliImageLoader.shared.load(url)
            didFail = image == nil
        }
    }
}

// MARK: - 圆形头像
struct BiliAvatar: View {
    let url: String?
    var size: CGFloat = 40

    @State private var image: UIImage?
    @State private var loadFailed = false

    var body: some View {
        Group {
            if let image = image {
                Image(uiImage: image).resizable().scaledToFill()
            } else {
                Circle()
                    .fill(Color(.systemGray4))
                    .overlay(Image(systemName: "person.fill").foregroundColor(.gray))
            }
        }
        .frame(width: size, height: size)
        .clipShape(Circle())
        .task(id: url) {
            guard let url else { return }
            image = await BiliImageLoader.shared.load(url)
            if image == nil, !loadFailed {
                loadFailed = true
                print("[Image] avatar load failed: \(url.prefix(50))")
            }
        }
    }
}
