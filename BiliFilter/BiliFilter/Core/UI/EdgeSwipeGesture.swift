import SwiftUI

struct EnableSwipeBack: ViewModifier {
    func body(content: Content) -> some View {
        content
            .onAppear {
                // 在视频页出现时强制启用系统侧滑返回
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                    guard let nav = topNavigationController() else { return }
                    nav.interactivePopGestureRecognizer?.isEnabled = true
                    nav.interactivePopGestureRecognizer?.delegate = nil
                }
            }
    }

    private func topNavigationController() -> UINavigationController? {
        guard let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let root = scene.windows.first?.rootViewController else { return nil }
        return findNavController(root)
    }

    private func findNavController(_ vc: UIViewController) -> UINavigationController? {
        if let nav = vc as? UINavigationController { return nav }
        if let nav = vc.navigationController { return nav }
        for child in vc.children {
            if let found = findNavController(child) { return found }
        }
        if let presented = vc.presentedViewController {
            return findNavController(presented)
        }
        return nil
    }
}

extension View {
    func enableSwipeBack() -> some View { modifier(EnableSwipeBack()) }
}
