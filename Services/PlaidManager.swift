//
//  PlaidManager.swift
//  Flamora app
//
//  Plaid 银行连接流程管理
//

import Foundation
import Supabase
internal import Functions

@Observable
class PlaidManager {
    static let shared = PlaidManager()

    var hasLinkedBank: Bool = false
    var isConnecting: Bool = false
    var connectedInstitutionName: String? = nil
    var showBudgetSetup: Bool = false
    var lastConnectionTime: Date? = nil
    private var client: SupabaseClient { SupabaseManager.shared.client }

    private init() {}

    // MARK: - 从 user-profile 加载银行连接状态
    func loadStatus() async {
        do {
            let session = try await client.auth.session
            let options = FunctionInvokeOptions(
                headers: ["Authorization": "Bearer \(session.accessToken)"]
            )
            let response: UserProfileResponse = try await client.functions.invoke("get-user-profile", options: options)
            hasLinkedBank = response.data.has_linked_bank
            connectedInstitutionName = response.data.plaid_institution_name
            #if DEBUG
            print("🏦 [PlaidManager] loadStatus — hasLinkedBank=\(hasLinkedBank)")
            #endif
        } catch {
            #if DEBUG
            print("🏦 [PlaidManager] loadStatus error: \(error)")
            #endif
        }
    }

    // MARK: - Step 1: 获取 link token，触发 Plaid Link
    func startLinkFlow() async {
        guard !isConnecting else { return }
        isConnecting = true
        defer { isConnecting = false }

        do {
            let session = try await client.auth.session
            let options = FunctionInvokeOptions(
                headers: ["Authorization": "Bearer \(session.accessToken)"],
                body: EmptyBody()
            )

            let response: CreateLinkTokenResponse = try await client.functions.invoke("create-link-token", options: options)
            let linkToken = response.data.link_token

            #if DEBUG
            // 仅输出 token 环境类型，不输出 token 本身
            let env = linkToken.hasPrefix("link-sandbox") ? "SANDBOX" :
                      linkToken.hasPrefix("link-production") ? "PRODUCTION" : "UNKNOWN"
            print("🏦 [PlaidManager] create-link-token OK — env=\(env)")
            #endif

            await MainActor.run {
                PlaidLinkPresenter.shared.present(
                    token: linkToken,
                    onSuccess: { [weak self] publicToken, institutionId, institutionName, selectedAccountIds in
                        Task { await self?.exchangePublicToken(
                            publicToken: publicToken,
                            institutionId: institutionId,
                            institutionName: institutionName,
                            selectedAccountIds: selectedAccountIds
                        )}
                    },
                    onDismiss: {}
                )
            }

        } catch let decodingError as DecodingError {
            #if DEBUG
            print("🏦 [PlaidManager] startLinkFlow decode error: \(decodingError)")
            #endif
        } catch let error as FunctionsError {
            if case .httpError(let code, _) = error {
                // 403 PREMIUM_REQUIRED → 触发 Paywall（生产路径）
                if code == 403 {
                    await MainActor.run {
                        SubscriptionManager.shared.showPaywall = true
                    }
                    return
                }
                #if DEBUG
                print("🏦 [PlaidManager] startLinkFlow HTTP \(code)")
                #endif
            }
        } catch {
            #if DEBUG
            print("🏦 [PlaidManager] startLinkFlow error: \(error)")
            #endif
        }
    }

    // MARK: - Step 3: 交换 public token
    func exchangePublicToken(publicToken: String, institutionId: String, institutionName: String, selectedAccountIds: [String] = []) async {
        do {
            // Proactively refresh if token is near expiry — mirrors APIService.authenticatedRequest.
            // User may spend several minutes inside Plaid Link UI; token can expire before we return.
            let accessToken: String
            do {
                let current = try await client.auth.session
                if current.expiresAt <= Date().timeIntervalSince1970 + 60 {
                    accessToken = try await client.auth.refreshSession().accessToken
                } else {
                    accessToken = current.accessToken
                }
            } catch {
                accessToken = try await client.auth.refreshSession().accessToken
            }

            let body = ExchangePublicTokenBody(
                public_token: publicToken,
                institution: .init(institution_id: institutionId, name: institutionName),
                selected_account_ids: selectedAccountIds
            )
            let options = FunctionInvokeOptions(
                headers: ["Authorization": "Bearer \(accessToken)"],
                body: body
            )
            // Invoke with 401-retry (same pattern as APIService.perform)
            let response: ExchangeResponse
            do {
                response = try await client.functions.invoke("exchange-public-token", options: options)
            } catch let fnError as FunctionsError {
                if case .httpError(let code, _) = fnError, code == 401 {
                    #if DEBUG
                    print("🏦 [PlaidManager] 401 from exchange-public-token — refreshing and retrying")
                    #endif
                    let retryToken = try await client.auth.refreshSession().accessToken
                    let retryOptions = FunctionInvokeOptions(
                        headers: ["Authorization": "Bearer \(retryToken)"],
                        body: body
                    )
                    response = try await client.functions.invoke("exchange-public-token", options: retryOptions)
                } else {
                    throw fnError
                }
            }
            if response.success {
                hasLinkedBank = true
                connectedInstitutionName = response.data.institution_name ?? institutionName
                lastConnectionTime = Date()
                #if DEBUG
                print("🏦 [PlaidManager] Bank linked — accounts=\(response.data.accounts_linked)")
                #endif
            }
        } catch let decodingError as DecodingError {
            #if DEBUG
            print("🏦 [PlaidManager] exchangePublicToken decode error: \(decodingError)")
            #endif
        } catch let fnError as FunctionsError {
            if case .httpError(let code, _) = fnError {
                #if DEBUG
                print("🏦 [PlaidManager] exchangePublicToken HTTP \(code)")
                #endif
            }
        } catch {
            #if DEBUG
            print("🏦 [PlaidManager] exchangePublicToken error: \(error)")
            #endif
        }
    }

    // MARK: - 断开银行连接
    func disconnectBank() async {
        do {
            let session = try await client.auth.session
            let options = FunctionInvokeOptions(
                headers: ["Authorization": "Bearer \(session.accessToken)"],
                body: EmptyBody()
            )
            let _: DisconnectResponse = try await client.functions.invoke("disconnect-bank", options: options)
            hasLinkedBank = false
            connectedInstitutionName = nil
            UserDefaults.standard.set(false, forKey: FlamoraStorageKey.budgetSetupCompleted)
            TabContentCache.shared.clearAfterBankDisconnect()
        } catch {
            #if DEBUG
            print("🏦 [PlaidManager] disconnectBank error: \(error)")
            #endif
        }
    }
}

// MARK: - Request Body Models

private struct EmptyBody: Encodable {}

private struct ExchangePublicTokenBody: Encodable {
    let public_token: String
    let institution: Institution
    let selected_account_ids: [String]

    struct Institution: Encodable {
        let institution_id: String
        let name: String
    }
}

// MARK: - Response Models

struct UserProfileResponse: Decodable {
    let success: Bool
    let data: ProfileData

    struct ProfileData: Decodable {
        let has_linked_bank: Bool
        let plaid_institution_name: String?
    }
}

struct CreateLinkTokenResponse: Decodable {
    let success: Bool
    let data: LinkTokenData

    struct LinkTokenData: Decodable {
        let link_token: String
        let expiration: String
    }
}

struct DisconnectResponse: Decodable {
    let success: Bool
}

struct ExchangeResponse: Decodable {
    let success: Bool
    let data: ExchangeData

    struct ExchangeData: Decodable {
        let item_id: String
        let institution_name: String?
        let accounts_linked: Int
        let has_investments: Bool
    }
}

// MARK: - UserDefaults keys

enum FlamoraStorageKey {
    static let budgetSetupCompleted = "flamoraBudgetSetupCompleted"

    /// 旧版未写入该标记但后端已有预算时，首次启动视为已完成，避免老用户被挡在「Build Your Plan」外。
    static func migrateBudgetSetupIfNeeded(budget: APIMonthlyBudget?, hasLinkedBank: Bool) {
        guard UserDefaults.standard.object(forKey: budgetSetupCompleted) == nil else { return }
        guard hasLinkedBank, let b = budget,
              (b.needsBudget + b.wantsBudget + b.savingsBudget) > 0,
              b.selectedPlan != nil else { return }
        UserDefaults.standard.set(true, forKey: budgetSetupCompleted)
    }
}
