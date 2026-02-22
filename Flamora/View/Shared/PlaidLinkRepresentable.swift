//
//  PlaidLinkRepresentable.swift
//  Flamora app
//
//  UIViewControllerRepresentable 包装 Plaid Link iOS SDK
//

import SwiftUI
import LinkKit

struct PlaidLinkRepresentable: UIViewControllerRepresentable {
    let token: String
    var onSuccess: (String, String, String) -> Void  // publicToken, institutionId, institutionName
    var onDismiss: () -> Void

    func makeUIViewController(context: Context) -> PlaidLinkHostViewController {
        PlaidLinkHostViewController(token: token, onSuccess: onSuccess, onDismiss: onDismiss)
    }

    func updateUIViewController(_ uiViewController: PlaidLinkHostViewController, context: Context) {}
}

// MARK: - Host View Controller

class PlaidLinkHostViewController: UIViewController {
    private let token: String
    private let onSuccess: (String, String, String) -> Void
    private let onDismiss: () -> Void
    private var handler: Handler?

    init(token: String,
         onSuccess: @escaping (String, String, String) -> Void,
         onDismiss: @escaping () -> Void) {
        self.token = token
        self.onSuccess = onSuccess
        self.onDismiss = onDismiss
        super.init(nibName: nil, bundle: nil)
        print("🔗 [PlaidLinkHost] init — token prefix: \(String(token.prefix(30)))")
    }

    required init?(coder: NSCoder) { fatalError() }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .clear
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        print("🔗 [PlaidLinkHost] viewDidAppear — handler: \(handler != nil)")
        guard handler == nil else { return }
        openPlaidLink()
    }

    // MARK: - 找到真正持有 linkViewController 的 VC
    // PlaidLinkHostViewController 是 UIHostingController 的 child VC
    // self.present(linkVC) 会被 UIKit 路由到 parent（UIHostingController）
    // 所以 linkViewController 挂在 parent.presentedViewController，而非 self.presentedViewController
    private func findLinkViewController() -> UIViewController? {
        var vc: UIViewController = self
        // 沿 parent 链向上查找第一个有 presentedViewController 的 VC
        while let parent = vc.parent {
            if let presented = parent.presentedViewController {
                print("🔗 [PlaidLinkHost] found linkVC on parent: \(type(of: parent))")
                return presented
            }
            vc = parent
        }
        // 兜底：检查 self 本身
        if let presented = self.presentedViewController {
            print("🔗 [PlaidLinkHost] found linkVC on self")
            return presented
        }
        print("🔗 [PlaidLinkHost] ⚠️ linkVC not found in parent chain")
        return nil
    }

    private func dismissLinkVC(completion: @escaping () -> Void) {
        if let linkVC = findLinkViewController() {
            print("🔗 [PlaidLinkHost] dismissing linkVC: \(type(of: linkVC))")
            linkVC.dismiss(animated: false, completion: completion)
        } else {
            completion()
        }
    }

    private func openPlaidLink() {
        print("🔗 [PlaidLinkHost] ── openPlaidLink() BEGIN ──")
        print("🔗 [PlaidLinkHost] token: \(token)")

        var config = LinkTokenConfiguration(
            token: token,
            onSuccess: { [weak self] linkSuccess in
                let publicToken = linkSuccess.publicToken
                let institutionId = linkSuccess.metadata.institution.id
                let institutionName = linkSuccess.metadata.institution.name
                print("🔗 [PlaidLinkHost] ✅ onSuccess — \(institutionName) (\(institutionId))")
                DispatchQueue.main.async {
                    guard let self = self else { return }
                    // 先 dismiss linkViewController（挂在 parent 上），再调回调
                    self.dismissLinkVC {
                        self.onSuccess(publicToken, institutionId, institutionName)
                    }
                }
            }
        )

        config.onExit = { [weak self] (exit: LinkExit) in
            print("🔗 [PlaidLinkHost] onExit called")
            if let err = exit.error {
                print("🔗 [PlaidLinkHost]   errorCode: \(err.errorCode)")
                print("🔗 [PlaidLinkHost]   errorMessage: \(err.errorMessage)")
                print("🔗 [PlaidLinkHost]   displayMessage: \(err.displayMessage ?? "nil")")
            } else {
                print("🔗 [PlaidLinkHost]   no error (user dismissed)")
            }
            DispatchQueue.main.async {
                guard let self = self else { return }
                self.dismissLinkVC {
                    self.onDismiss()
                }
            }
        }

        let result = Plaid.create(config)
        switch result {
        case .success(let h):
            print("🔗 [PlaidLinkHost] ✅ Plaid.create succeeded — opening with .custom")
            handler = h
            // .custom 模式：我们负责 present linkViewController
            // UIKit 会将 present 请求路由到 parent（UIHostingController）
            h.open(presentUsing: .custom({ [weak self] linkViewController in
                print("🔗 [PlaidLinkHost] presenting linkViewController: \(type(of: linkViewController))")
                self?.present(linkViewController, animated: true)
            }))
        case .failure(let error):
            print("🔗 [PlaidLinkHost] ❌ Plaid.create FAILED: \(error)")
            onDismiss()
        }

        print("🔗 [PlaidLinkHost] ── openPlaidLink() END ──")
    }
}
