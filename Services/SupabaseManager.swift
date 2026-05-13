//
//  SupabaseManager.swift
//  Meridian
//
//  Supabase Auth Manager - 单例，管理认证状态
//

import Foundation
import Supabase
import RevenueCat

@MainActor
@Observable
class SupabaseManager {
    static let shared = SupabaseManager()

    let client: SupabaseClient
    var currentUser: User? = nil
    var isAuthenticated: Bool = false

    private init() {
        client = SupabaseClient(
            supabaseURL: URL(string: AppConfig.supabaseURL)!,
            supabaseKey: AppConfig.supabaseAnonKey,
            options: .init(
                auth: .init(
                    redirectToURL: URL(string: "com.meridian.app://auth-callback"),
                    emitLocalSessionAsInitialSession: true
                )
            )
        )
    }

    // MARK: - 启动时检查现有 session
    func checkSession() async {
        do {
            let session = try await client.auth.session
            currentUser = session.user
            isAuthenticated = true
        } catch {
            currentUser = nil
            isAuthenticated = false
        }
    }

    // MARK: - 持续监听 auth 状态变化，同步 RevenueCat
    func listenToAuthChanges() async {
        for await (event, session) in client.auth.authStateChanges {
            currentUser = session?.user
            isAuthenticated = session != nil

            switch event {
            case .signedIn, .initialSession:
                if let userId = session?.user.id.uuidString {
                    Task { await SubscriptionManager.shared.loginUser(userId: userId) }
                    Task { await PlaidManager.shared.loadStatus() }
                }
            case .signedOut:
                SubscriptionManager.shared.logoutUser()
                HomeSetupStateCache.clear()
            default:
                break
            }
        }
    }

    // MARK: - 注册新用户
    // 返回 true 表示需要邮箱验证（session 为 nil）
    func signUp(email: String, password: String) async throws -> Bool {
        let response = try await client.auth.signUp(email: email, password: password)
        currentUser = response.user
        isAuthenticated = response.session != nil
        return response.session == nil
    }

    // MARK: - 登录已有用户
    func signIn(email: String, password: String) async throws {
        let session = try await client.auth.signIn(email: email, password: password)
        currentUser = session.user
        isAuthenticated = true
        let userId = session.user.id.uuidString
        Task { await SubscriptionManager.shared.loginUser(userId: userId) }
        Task { await PlaidManager.shared.loadStatus() }
    }

    // MARK: - OAuth（Apple / Google 需在 Dashboard 启用；redirect URL 与 Info.plist URL Types 一致）

    /// 使用内置 `ASWebAuthenticationSession` 完成 OAuth（PKCE）。
    @discardableResult
    func signInWithOAuth(provider: Provider) async throws -> Session {
        let session = try await client.auth.signInWithOAuth(provider: provider)
        currentUser = session.user
        isAuthenticated = true
        let userId = session.user.id.uuidString
        Task { await SubscriptionManager.shared.loginUser(userId: userId) }
        Task { await PlaidManager.shared.loadStatus() }
        return session
    }

    // MARK: - 退出登录
    func signOut() async throws {
        try await client.auth.signOut()
        currentUser = nil
        isAuthenticated = false
        SubscriptionManager.shared.logoutUser()
        HomeSetupStateCache.clear()
    }

    // MARK: - Helpers

    /// 当前用户 ID（UUID string），用于传给 Edge Function
    var currentUserId: String? {
        currentUser?.id.uuidString
    }

    /// 当前 session 的 access token，用于需要认证的 API 调用
    var currentAccessToken: String? {
        get async {
            try? await client.auth.session.accessToken
        }
    }
}
