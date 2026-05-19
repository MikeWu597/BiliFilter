import SwiftUI
import Combine

struct LiveScreen: View {
    @StateObject private var viewModel = LiveViewModel()
    var body: some View {
        NavigationStack {
            VStack {
                if viewModel.isLoading { Spacer(); ProgressView(); Spacer() }
                else {
                    ScrollView {
                        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                            ForEach(viewModel.rooms) { room in LiveCard(room: room) }
                        }.padding(12)
                    }.refreshable { await viewModel.loadRooms() }
                }
            }
            .navigationTitle("直播")
        }
        .task { await viewModel.loadRooms() }
    }
}

@MainActor final class LiveViewModel: ObservableObject {
    @Published var rooms: [LiveRoom] = []; @Published var isLoading = false
    func loadRooms() async {
        isLoading = true; defer { isLoading = false }
        do {
            let r: BiliApiResponse<LiveListData> = try await ApiClient.shared.request(.liveList(parentAreaId: 0, areaId: 0, page: 1, pageSize: 30, sortType: "online"))
            if r.isSuccess { rooms = r.data?.list ?? [] }
        } catch {}
    }
}

struct LiveRoom: Identifiable, Codable {
    var id: Int64 { roomid ?? 0 }
    let roomid: Int64?; let uid: Int64?; let title: String?; let uname: String?; let cover: String?; let online: Int?; let live_time: String?
}
struct LiveListData: Codable { let list: [LiveRoom]?; let num: Int? }

struct LiveCard: View {
    let room: LiveRoom
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            ZStack(alignment: .bottomTrailing) {
                BiliCover(url: room.cover)
                HStack(spacing: 4) {
                    Circle().fill(.red).frame(width: 6, height: 6)
                    Text("\(room.online ?? 0)").font(.caption2).foregroundColor(.white)
                }.padding(.horizontal, 6).padding(.vertical, 2).background(.ultraThinMaterial).cornerRadius(4).padding(6)
            }
            Text(room.title ?? "").font(.subheadline).lineLimit(2)
            Text(room.uname ?? "").font(.caption).foregroundColor(.secondary)
        }
    }
}
#Preview { LiveScreen().environmentObject(ThemeManager.shared) }
