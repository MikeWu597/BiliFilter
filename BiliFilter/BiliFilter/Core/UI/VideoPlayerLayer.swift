import SwiftUI
import AVFoundation
import AVKit

// 纯视频层，无系统控件，支持画中画
struct VideoPlayerLayer: UIViewRepresentable {
    let player: AVPlayer

    func makeUIView(context: Context) -> UIView {
        let view = PlayerUIView()
        view.player = player
        return view
    }

    func updateUIView(_ uiView: UIView, context: Context) {
        guard let view = uiView as? PlayerUIView else { return }
        view.player = player
    }
}

private class PlayerUIView: UIView, AVPictureInPictureControllerDelegate {
    var player: AVPlayer? {
        get { playerLayer.player }
        set { playerLayer.player = newValue }
    }
    private var pipController: AVPictureInPictureController?
    private var pipAttempted = false

    override class var layerClass: AnyClass { AVPlayerLayer.self }
    private var playerLayer: AVPlayerLayer { layer as! AVPlayerLayer }

    override init(frame: CGRect) {
        super.init(frame: frame)
        playerLayer.videoGravity = .resizeAspect
        NotificationCenter.default.addObserver(self, selector: #selector(didEnterBackground), name: UIApplication.didEnterBackgroundNotification, object: nil)
    }
    required init?(coder: NSCoder) { fatalError() }
    deinit { NotificationCenter.default.removeObserver(self) }

    override func didMoveToWindow() {
        super.didMoveToWindow()
        guard window != nil, !pipAttempted else { return }
        pipAttempted = true
        setupPiP()
    }

    private func setupPiP() {
        guard AVPictureInPictureController.isPictureInPictureSupported() else {
            print("[PiP] device not supported")
            return
        }
        guard let controller = AVPictureInPictureController(playerLayer: playerLayer) else {
            print("[PiP] init failed - playerLayer may not be ready")
            return
        }
        controller.canStartPictureInPictureAutomaticallyFromInline = true
        controller.delegate = self
        self.pipController = controller
        print("[PiP] setup done, possible=\(controller.isPictureInPicturePossible)")
    }

    @objc private func didEnterBackground() {
        print("[PiP] didEnterBackground, pipExists=\(pipController != nil), rate=\(player?.rate ?? 0)")
        guard let pip = pipController else {
            print("[PiP] no pipController")
            return
        }
        print("[PiP] isPossible=\(pip.isPictureInPicturePossible), isActive=\(pip.isPictureInPictureActive)")
        if pip.isPictureInPicturePossible {
            pip.startPictureInPicture()
            print("[PiP] start called")
        }
    }

    func pictureInPictureControllerDidStartPictureInPicture(_ controller: AVPictureInPictureController) {
        print("[PiP] didStart")
    }
    func pictureInPictureControllerDidStopPictureInPicture(_ controller: AVPictureInPictureController) {
        print("[PiP] didStop")
    }
    func pictureInPictureController(_ controller: AVPictureInPictureController, failedToStartPictureInPictureWithError error: Error) {
        print("[PiP] failed: \(error)")
    }
    func pictureInPictureController(_ controller: AVPictureInPictureController, restoreUserInterfaceForPictureInPictureStopWithCompletionHandler completionHandler: @escaping (Bool) -> Void) {
        print("[PiP] restoreUserInterface")
        completionHandler(true)
    }
}
