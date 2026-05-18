import SwiftUI
import Combine

// MARK: - 扫码登录
struct LoginScreen: View {
    @StateObject private var viewModel = LoginViewModel()
    @EnvironmentObject private var themeManager: ThemeManager
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            Text("扫码登录")
                .font(.title)
                .fontWeight(.bold)
                .foregroundColor(themeManager.primaryTextColor)

            Text("请使用Bilibili客户端扫描二维码")
                .font(.subheadline)
                .foregroundColor(themeManager.secondaryTextColor)

            // 二维码
            if let qrUrl = viewModel.qrCodeUrl {
                AsyncImage(url: URL(string: qrUrl)) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .interpolation(.none)
                            .scaledToFit()
                            .frame(width: 200, height: 200)
                            .padding(16)
                            .background(Color.white)
                            .cornerRadius(12)
                    case .failure:
                        Image(systemName: "qrcode")
                            .font(.system(size: 120))
                            .foregroundColor(.gray)
                    case .empty:
                        ProgressView().frame(width: 200, height: 200)
                    @unknown default:
                        EmptyView()
                    }
                }
            } else {
                ProgressView().frame(width: 200, height: 200)
            }

            if viewModel.isExpired {
                Text("二维码已过期，点击刷新")
                    .font(.caption)
                    .foregroundColor(.orange)
                Button("刷新二维码") {
                    Task { await viewModel.generateQRCode() }
                }
                .font(.subheadline)
                .foregroundColor(themeManager.accentColor)
            }

            Text(viewModel.statusText)
                .font(.subheadline)
                .foregroundColor(viewModel.isSuccess ? .green : themeManager.secondaryTextColor)
                .multilineTextAlignment(.center)

            Spacer()
        }
        .padding()
        .background(themeManager.backgroundColor)
        .task { await viewModel.generateQRCode() }
        .onChange(of: viewModel.isSuccess) { success in
            if success { dismiss() }
        }
    }
}

// MARK: - 登录ViewModel
@MainActor
final class LoginViewModel: ObservableObject {
    @Published var qrCodeUrl: String?
    @Published var qrcodeKey: String?
    @Published var isExpired = false
    @Published var isSuccess = false
    @Published var statusText = "请扫描二维码"

    private var pollingTask: Task<Void, Never>?

    func generateQRCode() async {
        isExpired = false
        statusText = "加载中..."
        do {
            let response: BiliApiResponse<QRCodeData> = try await ApiClient.shared.request(.qrCodeUrl)
            if response.isSuccess, let data = response.data {
                qrCodeUrl = data.url
                qrcodeKey = data.qrcode_key
                statusText = "请扫描二维码"
                startPolling()
            } else {
                statusText = "获取二维码失败"
            }
        } catch {
            statusText = "网络错误: \(error.localizedDescription)"
        }
    }

    private func startPolling() {
        pollingTask?.cancel()
        pollingTask = Task {
            guard let key = qrcodeKey else { return }
            while !Task.isCancelled {
                do {
                    let response: BiliApiResponse<QRCodePollData> = try await ApiClient.shared.request(.qrCodePoll(qrcodeKey: key))
                    guard response.isSuccess, let data = response.data else { continue }

                    switch data.code {
                    case 0:
                        statusText = "登录成功"
                        isSuccess = true
                        if let url = URL(string: data.url ?? "") {
                            let components = URLComponents(url: url, resolvingAgainstBaseURL: false)
                            let sessdata = components?.queryItems?.first(where: { $0.name == "SESSDATA" })?.value
                            let csrf = components?.queryItems?.first(where: { $0.name == "bili_jct" })?.value
                            let mid = Int64(components?.queryItems?.first(where: { $0.name == "DedeUserID" })?.value ?? "0") ?? 0
                            if let sess = sessdata {
                                TokenManager.shared.login(sessdata: sess, csrf: csrf ?? "", mid: mid)
                            }
                        }
                        return
                    case 86038: statusText = "二维码已过期"
                        isExpired = true; return
                    case 86090: statusText = "已扫码，请在手机上确认"
                    case 86101: statusText = "正在登录中"
                    default: statusText = data.message ?? "未知状态"
                    }
                } catch {}
                try? await Task.sleep(nanoseconds: 2_000_000_000)
            }
        }
    }

    deinit { pollingTask?.cancel() }
}

struct QRCodeData: Codable {
    let url: String?
    let qrcode_key: String?
    enum CodingKeys: String, CodingKey { case url, qrcode_key }
}

struct QRCodePollData: Codable {
    let code: Int?
    let message: String?
    let url: String?
    enum CodingKeys: String, CodingKey { case code, message, url }
}

#Preview {
    LoginScreen().environmentObject(ThemeManager.shared)
}
