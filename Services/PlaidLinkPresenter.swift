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

        // ① 强制 WKWebView 立即放弃 first responder。
        //    不做这步，UIKit 的异步 first-responder 注销流程会在我们隐藏
        //    UITextEffectsWindow 之后重新 assert 它，导致触摸再次被拦截。
        UIApplication.shared.sendAction(
            #selector(UIResponder.resignFirstResponder),
            to: nil, from: nil, for: nil
        )

        // ② 立即禁用触摸拦截——不管后续 dismiss 动画如何，主界面马上可交互
        win.isUserInteractionEnabled = false

        let presented = win.rootViewController?.presentedViewController

        // ③ 仅在 linkVC 存在且尚未被 Plaid SDK 自行 dismiss 时才手动 dismiss
        if let presented, !presented.isBeingDismissed {
            // animated: false 避免动画期间 completion 延迟触发导致 window 残留
            presented.dismiss(animated: false) { [weak self] in
                self?.destroyWindow {
                    completion()
                }
            }
        } else {
            destroyWindow {
                completion()
            }
        }
    }

    private func destroyWindow(completion: @escaping () -> Void = {}) {
        plaidHandler = nil

        let win = overlayWindow
        overlayWindow = nil          // 先 nil 掉，防止 reentrant

        // 先 nil rootVC，切断 WKWebView 对 parent window VC 层级的引用。
        // 不做这步，WKWebView 会通过 parent VC 引用保持 UITextEffectsWindow 活跃。
        win?.rootViewController = nil
        win?.isHidden = true

        guard let scene = win?.windowScene else {
            print("🔗 [PlaidLinkPresenter] UIWindow destroyed (no scene ref)")
            DispatchQueue.main.async { completion() }
            return
        }

        // ── 第一次（同步）清理 ──
        hideElevatedWindows(in: scene, excluding: win)
        restoreKeyWindow(in: scene, excluding: win)

        // ── 第二次（延迟）清理 ──
        // UIKit 的 first-responder 注销是异步的：我们在同步阶段隐藏了
        // UITextEffectsWindow，但 UIKit 的异步处理流程可能在下一个 runloop
        // 将其重新显示。这里再做一次清理，确保彻底。
        // completion 在 deferred cleanup 之后触发，确保 UIKit window 层级稳定
        // 后再触发 SwiftUI 状态变更。
        DispatchQueue.main.async { [weak self] in
            guard let activeScene = UIApplication.shared.connectedScenes
                .compactMap({ $0 as? UIWindowScene })
                .first(where: { $0.activationState == .foregroundActive })
            else {
                completion()
                return
            }
            self?.hideElevatedWindows(in: activeScene, excluding: nil)
            print("🔗 [PlaidLinkPresenter] Deferred elevated-window cleanup done")
            completion()
        }
    }

    // MARK: - Helpers

    private func hideElevatedWindows(in scene: UIWindowScene, excluding win: UIWindow?) {
        // Plaid 的 WKWebView dismiss 后会遗留 UITextEffectsWindow（level=2002）
        // 该 window hidden=false + interaction=true，拦截所有触摸事件
        // 只隐藏 UITextEffectsWindow，保留其他系统窗口（键盘、SwiftUI sheet 等）
        for w in scene.windows where w !== win && !w.isHidden {
            let className = String(describing: type(of: w))
            if className == "UITextEffectsWindow" && w.windowLevel > .normal {
                print("🔗 [PlaidLinkPresenter] Hiding UITextEffectsWindow level=\(Int(w.windowLevel.rawValue))")
                w.isHidden = true
            }
        }
    }

    private func restoreKeyWindow(in scene: UIWindowScene, excluding win: UIWindow?) {
        // 恢复主 App window 为 key（level 最低的可见 window）
        let restoredWindow = scene.windows
            .filter { $0 !== win && !$0.isHidden }
            .min(by: { $0.windowLevel < $1.windowLevel })
        restoredWindow?.makeKeyAndVisible()
        print("🔗 [PlaidLinkPresenter] Key window restored → \(restoredWindow.map { String(describing: type(of: $0)) } ?? "nil")")
    }

    private func activeWindowScene() -> UIWindowScene? {
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .first { $0.activationState == .foregroundActive }
        ?? UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .first
    }
}
