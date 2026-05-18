import SwiftUI

// MARK: - UIKit毛玻璃效果桥接
struct VisualEffectBlur: UIViewRepresentable {
    var style: UIBlurEffect.Style = .systemMaterial
    var intensity: CGFloat = 1.0

    func makeUIView(context: Context) -> UIVisualEffectView {
        let view = UIVisualEffectView(effect: UIBlurEffect(style: style))
        view.alpha = intensity
        return view
    }

    func updateUIView(_ uiView: UIVisualEffectView, context: Context) {
        uiView.effect = UIBlurEffect(style: style)
        uiView.alpha = intensity
    }
}

// MARK: - 液态玻璃效果 (iOS风格半透明模糊)
struct LiquidGlassView<Content: View>: View {
    let content: Content
    var cornerRadius: CGFloat = 16

    init(cornerRadius: CGFloat = 16, @ViewBuilder content: () -> Content) {
        self.cornerRadius = cornerRadius
        self.content = content()
    }

    var body: some View {
        content
            .background(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .fill(.ultraThinMaterial)
            )
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
    }
}

// MARK: - View扩展
extension View {
    func glassEffect(cornerRadius: CGFloat = 16) -> some View {
        self.modifier(GlassModifier(cornerRadius: cornerRadius))
    }

    func blurredBackground(style: UIBlurEffect.Style = .systemMaterial) -> some View {
        self.background(VisualEffectBlur(style: style))
    }
}

struct GlassModifier: ViewModifier {
    let cornerRadius: CGFloat

    func body(content: Content) -> some View {
        content
            .background(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .fill(.ultraThinMaterial)
            )
    }
}

// MARK: - iOS风格底栏胶囊指示器
struct IOSHomeIndicator: View {
    var body: some View {
        RoundedRectangle(cornerRadius: 3)
            .fill(Color.primary.opacity(0.3))
            .frame(width: 134, height: 5)
            .padding(.bottom, 8)
    }
}
