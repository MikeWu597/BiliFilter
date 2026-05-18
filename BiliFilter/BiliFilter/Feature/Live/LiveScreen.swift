import SwiftUI
import Combine

// MARK: - 直播列表
struct LiveScreen: View {
    @StateObject private var viewModel = LiveViewModel()
    @EnvironmentObject private var themeManager: ThemeManager

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                if viewModel.isLoading {
                    Spacer()
                    ProgressView().tint(themeManager.accentColor)
                    Spacer()
                } else {
                    ScrollView {
                        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                            ForEach(viewModel.rooms) { room in
                                LiveCard(room: room)
                            }
                        }
                        .padding(12)
                    }
                    .refreshable { await viewModel.loadRooms() }
                }
            }
            .background(themeManager.backgroundColor)
            .navigationTitle("直播")
        }
        .task { await viewModel.loadRooms() }
    }
}

// MARK: - 直播ViewModel
@MainActor
final class LiveViewModel: ObservableObject {
    @Published var rooms: [LiveRoom] = []
    @Published var selectedArea: Int = 0
    @Published var isLoading = false

    func loadRooms() async {
        isLoading = true
        defer { isLoading = false }
        do {
            let response: BiliApiResponse<LiveListData> = try await ApiClient.shared.request(
                .liveList(parentAreaId: selectedArea, areaId: 0, page: 1, pageSize: 30, sortType: "online")
            )
            if response.isSuccess {
                rooms = response.data?.list ?? []
            }
        } catch {}
    }
}

struct LiveRoom: Identifiable, Codable {
    var id: Int64 { roomid ?? 0 }
    let roomid: Int64?
    let uid: Int64?
    let title: String?
    let uname: String?
    let cover: String?
    let online: Int?
    let live_time: String?

    enum CodingKeys: String, CodingKey { case roomid, uid, title, uname, cover, online, live_time }
}

struct LiveListData: Codable {
    let list: [LiveRoom]?
    let num: Int?
    enum CodingKeys: String, CodingKey { case list, num }
}

struct LiveCard: View {
    let room: LiveRoom
    @EnvironmentObject private var themeManager: ThemeManager

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            ZStack(alignment: .bottomTrailing) {
                AsyncImage(url: URL(string: room.cover ?? "")) { phase in
                    switch phase {
                    case .success(let img): img.resizable().aspectRatio(16/9, contentMode: .fill)
                    default: Rectangle().fill(themeManager.surfaceColor).aspectRatio(16/9, contentMode: .fit)
                    }
                }
                .clipShape(RoundedRectangle(cornerRadius: 8))

                HStack(spacing: 4) {
                    Circle().fill(.red).frame(width: 6, height: 6)
                    Text("\(room.online ?? 0)")
                        .font(.caption2)
                        .foregroundColor(.white)
                }
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(.ultraThinMaterial)
                .cornerRadius(4)
                .padding(6)
            }

            Text(room.title ?? "")
                .font(.subheadline)
                .foregroundColor(themeManager.primaryTextColor)
                .lineLimit(2)
            Text(room.uname ?? "")
                .font(.caption)
                .foregroundColor(themeManager.secondaryTextColor)
        }
    }
}

#Preview {
    LiveScreen().environmentObject(ThemeManager.shared)
}
