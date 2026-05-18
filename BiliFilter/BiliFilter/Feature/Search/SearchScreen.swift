import SwiftUI

struct SearchScreen: View {
    @StateObject private var viewModel = SearchViewModel()
    @EnvironmentObject private var themeManager: ThemeManager
    @FocusState private var isFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            // 搜索栏
            HStack(spacing: 12) {
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(themeManager.secondaryTextColor)
                    TextField("搜索视频、UP主、番剧", text: $viewModel.query)
                        .focused($isFocused)
                        .submitLabel(.search)
                        .onSubmit { Task { await viewModel.search() } }
                    if !viewModel.query.isEmpty {
                        Button { viewModel.query = "" } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.gray)
                        }
                    }
                }
                .padding(10)
                .background(themeManager.systemGrayBackground)
                .cornerRadius(10)

                Button("取消") { }
                    .foregroundColor(themeManager.accentColor)
                    .font(.subheadline)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)

            if viewModel.results.isEmpty {
                // 热搜 + 历史
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        if !viewModel.searchHistory.isEmpty {
                            HStack {
                                Text("搜索历史")
                                    .font(.headline)
                                    .foregroundColor(themeManager.primaryTextColor)
                                Spacer()
                                Button("清空") { viewModel.clearHistory() }
                                    .font(.caption)
                                    .foregroundColor(themeManager.secondaryTextColor)
                            }
                            .padding(.horizontal, 16)

                            FlowLayout(spacing: 8) {
                                ForEach(viewModel.searchHistory, id: \.self) { term in
                                    Button {
                                        viewModel.query = term
                                        Task { await viewModel.search() }
                                    } label: {
                                        Text(term)
                                            .font(.subheadline)
                                            .padding(.horizontal, 12)
                                            .padding(.vertical, 6)
                                            .background(themeManager.surfaceColor)
                                            .cornerRadius(14)
                                            .foregroundColor(themeManager.primaryTextColor)
                                    }
                                }
                            }
                            .padding(.horizontal, 16)
                        }

                        Text("热搜")
                            .font(.headline)
                            .foregroundColor(themeManager.primaryTextColor)
                            .padding(.horizontal, 16)

                        ForEach(Array(viewModel.hotSearches.enumerated()), id: \.offset) { index, item in
                            Button {
                                viewModel.query = item
                                Task { await viewModel.search() }
                            } label: {
                                HStack {
                                    Text("\(index + 1)")
                                        .font(.subheadline)
                                        .fontWeight(.bold)
                                        .foregroundColor(index < 3 ? .red : themeManager.secondaryTextColor)
                                        .frame(width: 24)
                                    Text(item)
                                        .font(.subheadline)
                                        .foregroundColor(themeManager.primaryTextColor)
                                    Spacer()
                                }
                                .padding(.horizontal, 16)
                                .padding(.vertical, 8)
                            }
                        }
                    }
                    .padding(.top, 16)
                }
            } else {
                // 搜索结果
                ScrollView {
                    LazyVStack(spacing: 12) {
                        ForEach(viewModel.results, id: \.id) { item in
                            SearchResultRow(item: item)
                        }
                        if viewModel.hasMoreResults {
                            ProgressView()
                                .onAppear { Task { await viewModel.loadMore() } }
                        }
                    }
                    .padding(12)
                }
            }
        }
        .background(themeManager.backgroundColor)
        .task { await viewModel.loadHotSearches() }
    }
}

struct SearchResultRow: View {
    let item: SearchResultItem
    @EnvironmentObject private var themeManager: ThemeManager

    var body: some View {
        HStack(spacing: 12) {
            AsyncImage(url: URL(string: item.pic ?? "")) { phase in
                switch phase {
                case .success(let img): img.resizable().scaledToFill()
                default: Rectangle().fill(themeManager.surfaceColor)
                }
            }
            .frame(width: 140, height: 88)
            .clipShape(RoundedRectangle(cornerRadius: 6))

            VStack(alignment: .leading, spacing: 4) {
                Text(item.title ?? "")
                    .font(.subheadline)
                    .foregroundColor(themeManager.primaryTextColor)
                    .lineLimit(2)
                Text(item.author ?? "")
                    .font(.caption)
                    .foregroundColor(themeManager.secondaryTextColor)
                HStack(spacing: 12) {
                    Label("\(item.play ?? 0)", systemImage: "play.fill")
                    Label("\(item.danmaku ?? 0)", systemImage: "text.bubble")
                }
                .font(.caption2)
                .foregroundColor(themeManager.tertiaryTextColor)
            }
        }
    }
}

// 流式布局
struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = arrange(proposal.width ?? 0, subviews: subviews)
        return result.size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = arrange(bounds.width, subviews: subviews)
        for (index, frame) in result.frames.enumerated() {
            subviews[index].place(at: CGPoint(x: bounds.minX + frame.minX, y: bounds.minY + frame.minY), proposal: .unspecified)
        }
    }

    private func arrange(_ maxWidth: CGFloat, subviews: Subviews) -> (size: CGSize, frames: [CGRect]) {
        var frames: [CGRect] = []
        var x: CGFloat = 0, y: CGFloat = 0, lineHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > maxWidth && x > 0 {
                x = 0
                y += lineHeight + spacing
                lineHeight = 0
            }
            frames.append(CGRect(x: x, y: y, width: size.width, height: size.height))
            x += size.width + spacing
            lineHeight = max(lineHeight, size.height)
        }
        return (CGSize(width: maxWidth, height: y + lineHeight), frames)
    }
}

#Preview {
    SearchScreen().environmentObject(ThemeManager.shared)
}
