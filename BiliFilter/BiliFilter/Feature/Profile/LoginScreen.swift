import SwiftUI
import Combine

struct LoginScreen: View {
    @StateObject private var viewModel = LoginViewModel()
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 24) {
            Spacer()
            Text("扫码登录").font(.title).fontWeight(.bold)
            Text("请使用Bilibili客户端扫描二维码").font(.subheadline).foregroundColor(.secondary)

            if let qrUrl = viewModel.qrCodeUrl {
                QRCodeView(url: qrUrl)
            } else {
                ProgressView().frame(width: 200, height: 200)
            }

            if viewModel.isExpired {
                Text("二维码已过期").font(.caption).foregroundColor(.orange)
                Button("刷新") { Task { await viewModel.generateQRCode() } }
            }

            Text(viewModel.statusText).font(.subheadline)
                .foregroundColor(viewModel.isSuccess ? .green : .secondary)
                .multilineTextAlignment(.center)
            Spacer()
        }
        .navigationTitle("登录").navigationBarTitleDisplayMode(.inline)
        .task { await viewModel.generateQRCode() }
        .onChange(of: viewModel.isSuccess) { success in if success { dismiss() } }
    }
}

@MainActor final class LoginViewModel: ObservableObject {
    @Published var qrCodeUrl: String?; @Published var qrcodeKey: String?
    @Published var isExpired = false; @Published var isSuccess = false
    @Published var statusText = "加载中..."
    private var pollingTask: Task<Void, Never>?

    func generateQRCode() async {
        isExpired = false; statusText = "加载中..."
        do {
            let r: BiliApiResponse<QRCodeData> = try await ApiClient.shared.request(.qrCodeUrl)
            if r.isSuccess, let d = r.data {
                qrCodeUrl = d.url; qrcodeKey = d.qrcode_key; statusText = "请扫描二维码"
                startPolling()
            } else { statusText = "获取二维码失败" }
        } catch { statusText = "网络错误: \(error.localizedDescription)" }
    }

    private func startPolling() {
        pollingTask?.cancel()
        pollingTask = Task {
            guard let key = qrcodeKey else { return }
            while !Task.isCancelled {
                do {
                    let r: BiliApiResponse<QRCodePollData> = try await ApiClient.shared.request(.qrCodePoll(qrcodeKey: key))
                    guard r.isSuccess, let d = r.data else { continue }
                    switch d.code {
                    case 0:
                        statusText = "登录成功"; isSuccess = true
                        if let urlStr = d.url, let url = URL(string: urlStr),
                           let comps = URLComponents(url: url, resolvingAgainstBaseURL: false) {
                            let sess = comps.queryItems?.first(where: { $0.name == "SESSDATA" })?.value
                            let csrf = comps.queryItems?.first(where: { $0.name == "bili_jct" })?.value
                            let mid = Int64(comps.queryItems?.first(where: { $0.name == "DedeUserID" })?.value ?? "0") ?? 0
                            if let sess = sess { TokenManager.shared.login(sessdata: sess, csrf: csrf ?? "", mid: mid) }
                        }
                        return
                    case 86038: statusText = "二维码已过期"; isExpired = true; return
                    case 86090: statusText = "已扫码，请确认"
                    case 86101: statusText = "正在登录中"
                    default: statusText = d.message ?? "未知状态"
                    }
                } catch {}
                try? await Task.sleep(nanoseconds: 2_000_000_000)
            }
        }
    }
    deinit { pollingTask?.cancel() }
}

struct QRCodeData: Codable {
    let url: String?; let qrcode_key: String?
}
struct QRCodePollData: Codable {
    let code: Int?; let message: String?; let url: String?
}

struct QRCodeView: View {
    let url: String

    var body: some View {
        if let img = generateQRCode(from: url) {
            Image(uiImage: img)
                .resizable().interpolation(.none).scaledToFit()
                .frame(width: 200, height: 200).padding(16)
                .background(Color.white).cornerRadius(12)
        } else {
            ProgressView().frame(width: 200, height: 200)
        }
    }

    private func generateQRCode(from string: String) -> UIImage? {
        guard let data = string.data(using: .utf8) else { return nil }
        guard let filter = CIFilter(name: "CIQRCodeGenerator") else { return nil }
        filter.setValue(data, forKey: "inputMessage")
        filter.setValue("H", forKey: "inputCorrectionLevel")
        guard let output = filter.outputImage else { return nil }
        let scaled = output.transformed(by: CGAffineTransform(scaleX: 10, y: 10))
        let ctx = CIContext()
        guard let cg = ctx.createCGImage(scaled, from: scaled.extent) else { return nil }
        return UIImage(cgImage: cg)
    }
}
#Preview { LoginScreen() }
