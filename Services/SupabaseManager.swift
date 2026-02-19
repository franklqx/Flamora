//
//  SupabaseManager.swift
//  Flamora app
//
//  Supabase Auth Manager - 单例，管理认证状态
//

import Foundation
import Supabase

@Observable
class SupabaseManager {
    static let shared = SupabaseManager()

    let client: SupabaseClient
    var currentUser: User? = nil
    var isAuthenticated: Bool = false

    private init() {
        client = SupabaseClient(
            supabaseURL: URL(string: "https://vnyalfpmopvoswccewju.supabase.co")!,
            supabaseKey: "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InZueWFsZnBtb3B2b3N3Y2Nld2p1Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzAxODg2ODgsImV4cCI6MjA4NTc2NDY4OH0.LWeaM9vRRoh0i-lUcMRV0BjTZHKVDvI8XGWRIcJajG4",
            options: .init(
                auth: .init(
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

    // MARK: - 持续监听 auth 状态变化
    func listenToAuthChanges() async {
        for await (_, session) in await client.auth.authStateChanges {
            currentUser = session?.user
            isAuthenticated = session != nil
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
    }

    // MARK: - 退出登录
    func signOut() async throws {
        try await client.auth.signOut()
        currentUser = nil
        isAuthenticated = false
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
