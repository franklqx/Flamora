//
//  PlaidLinkPresenter.swift
//  Flamora app
//
//  用独立 UIWindow 呈现 Plaid Link，彻底绕开 SwiftUI fullScreenCover
//  触摸拦截 Bug（Plaid dismiss 后残留透明 UIHostingController）
//

import UIKit
import LinkKit

final class PlaidLinkPresenter {
    static let shared = PlaidLinkPresenter()

    private var overlayWindow: UIWindow?
    private var plaidHandler: Handler?

    private init() {}

    // MARK: - Present

    /// 在独立 UIWindow 上呈现 Plaid Link。
    /// 必须在 Main Thread 调用。
    func present(
        token: String,
        onSuccess: @escaping (String, String, String) -> Void,
        onDismiss: @escaping () -> Void
    ) {
        assert(Thread.isMainThread, "PlaidLinkPresenter.present() must be called on main thread")

        guard overlayWindow == nil else {
            print("🔗 [PlaidLinkPresenter] already presenting, ignoring duplicate call")
            return
        }

        guard let scene = activeWindowScene() else {
            print("🔗 [PlaidLinkPresenter] ❌ no active UIWindowScene found")
            onDismiss()
            return
        }

        // 独立 UIWindow，windowLevel 高于主窗口，不干扰 SwiftUI 视图层级
        let win = UIWindow(windowScene: scene)
        win.windowLevel = UIWindow.Level.alert + 1
        win.backgroundColor = .clear

        let rootVC = UIViewController()
        rootVC.view.backgroundColor = .clear
        win.rootViewController = rootVC
        win.makeKeyAndVisible()
        overlayWindow = win

        print("🔗 [PlaidLinkPresenter] UIWindow created (level=\(win.windowLevel.rawValue))")

        var config = LinkTokenConfiguration(
            token: token,
            onSuccess: { [weak self] linkSuccess in
                let publicToken  = linkSuccess.publicToken
                let institutionId   = linkSuccess.metadata.institution.id
                let institutionName = linkSuccess.metadata.institution.name
                print("🔗 [PlaidLinkPresenter] ✅ onSuccess — \(institutionName) (\(institutionId))")
                DispatchQueue.main.async {
                    self?.tearDown {
                        onSuccess(publicToken, institutionId, institutionName)
                    }
                }
            }
        )

        config.onExit = { [weak self] exit in
            if let err = exit.error {
                print("🔗 [PlaidLinkPresenter] onExit error: \(err.errorCode) — \(err.errorMessage)")
            } else {
                print("🔗 [PlaidLinkPresenter] onExit (user dismissed)")
            }
            DispatchQueue.main.async {
                self?.tearDown { onDismiss() }
            }
        }

        let result = Plaid.create(config)
        switch result {
        case .success(let handler):
            plaidHandler = handler
            handler.open(presentUsing: .custom({ [weak rootVC] linkViewController in
                print("🔗 [PlaidLinkPresenter] presenting linkViewController on overlay rootVC")
                rootVC?.present(linkViewController, animated: true)
            }))
        case .failure(let error):
            print("🔗 [PlaidLinkPresenter] ❌ Plaid.create failed: \(error)")
            tearDown { onDismiss() }
        }
    }

    // MARK: - Tear Down

    private func tearDown(completion: @escaping () -> Void) {
        guard let win = overlayWindow else {
            completion()
            return
        }

        // ① 立即禁用触摸拦截——不管后续 dismiss 动画如何，主界面马上可交互
        win.isUserInteractionEnabled = false

        let presented = win.rootViewController?.presentedViewController

        // ② 仅在 linkVC 存在且尚未被 Plaid SDK 自行 dismiss 时才手动 dismiss
        if let presented, !presented.isBeingDismissed {
            // animated: false 避免动画期间 completion 延迟触发导致 window 残留
            presented.dismiss(animated: false) { [weak self] in
                self?.destroyWindow()
                completion()
            }
        } else {
            destroyWindow()
            completion()
        }
    }

    private func destroyWindow() {
        plaidHandler = nil

        let win = overlayWindow
        overlayWindow = nil          // 先 nil 掉，防止 reentrant

        win?.isHidden = true

        guard let scene = win?.windowScene else {
            print("🔗 [PlaidLinkPresenter] UIWindow destroyed (no scene ref)")
            return
        }

        // ── 清理：隐藏所有 level > normal 的可见 window ──
        // Plaid 的 WKWebView dismiss 后会遗留 UITextEffectsWindow（level=2002）
        // 该 window hidden=false + interaction=true，拦截所有触摸事件
        for w in scene.windows where w !== win && !w.isHidden && w.windowLevel > .normal {
            print("🔗 [PlaidLinkPresenter] Hiding elevated window: \(type(of: w)) level=\(Int(w.windowLevel.rawValue))")
            w.isHidden = true
        }

        // ── 恢复主 App window 为 key（level 最低的可见 window）──
        let restoredWindow = scene.windows
            .filter { $0 !== win && !$0.isHidden }
            .min(by: { $0.windowLevel < $1.windowLevel })
        restoredWindow?.makeKeyAndVisible()

        print("🔗 [PlaidLinkPresenter] Key window restored → \(restoredWindow.map { String(describing: type(of: $0)) } ?? "nil")")
    }

    // MARK: - Helpers

    private func activeWindowScene() -> UIWindowScene? {
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .first { $0.activationState == .foregroundActive }
        ?? UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .first
    }
}
