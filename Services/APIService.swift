//
//  APIService.swift
//  Flamora app
//
//  API Service for backend communication
//

import Foundation
internal import Auth
import Supabase

class APIService {
    static let shared = APIService()
    
    private let baseURL = "https://vnyalfpmopvoswccewju.supabase.co/functions/v1"
    private let anonKey = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InZueWFsZnBtb3B2b3N3Y2Nld2p1Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzAxODg2ODgsImV4cCI6MjA4NTc2NDY4OH0.LWeaM9vRRoh0i-lUcMRV0BjTZHKVDvI8XGWRIcJajG4"
    
    private init() {}
    
    // MARK: - Create User Profile
    func createUserProfile(data: OnboardingData) async throws -> CreateProfileResponse {
        print("🔑 currentUserId: \(String(describing: SupabaseManager.shared.currentUserId))")

        let url = URL(string: "\(baseURL)/create-user-profile")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue(anonKey, forHTTPHeaderField: "apikey")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        // 转换 fireType 到后端需要的格式
        let lifestyleValue: String
        switch data.fireType.lowercased() {
        case "maintain":
            lifestyleValue = "current"
        case "lean":
            lifestyleValue = "simpler"
        case "fat":
            lifestyleValue = "dream"
        default:
            lifestyleValue = "current"
        }
        
        // 使用 OnboardingData 里在登录时存入的 userId（最可靠的来源）
        let userId = data.userId
        print("🔑 User ID: \(userId)")
        let finalUserId = userId.lowercased()
        print("🔑 最终 userId: \(finalUserId)")

        // 构建请求体
        let body: [String: Any] = [
            "user_id": finalUserId,
            "username": data.userName,
            "motivations": Array(data.motivations),
            "age": Int(data.age),
            "currency_code": data.currencyCode,
            "rough_monthly_income": Double(data.monthlyIncome) ?? 0,
            "rough_monthly_expenses": Double(data.monthlyExpenses) ?? 0,
            "rough_net_worth": Double(data.currentNetWorth) ?? 0,
            "desired_lifestyle": lifestyleValue
        ]
        
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        // 发送请求
        let (responseData, response) = try await URLSession.shared.data(for: request)
        
        // 检查 HTTP 响应
        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }
        
        // 检查状态码
        guard (200...299).contains(httpResponse.statusCode) else {
            // 尝试解析错误响应
            if let errorResponse = try? JSONDecoder().decode(ErrorResponse.self, from: responseData) {
                throw APIError.serverError(errorResponse.error.message)
            }
            throw APIError.httpError(httpResponse.statusCode)
        }
        
        // 解析成功响应
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        return try decoder.decode(CreateProfileResponse.self, from: responseData)
    }

    // MARK: - Private Helpers

    private struct APIResponse<T: Decodable>: Decodable {
        let success: Bool
        let data: T
    }

     func authenticatedRequest(
        function: String,
        queryParams: [String: String] = [:],
        body: Data? = nil
    ) async throws -> URLRequest {
        // Proactively refresh session if token is expiring within 60s
        let session: Session
        do {
            let current = try await SupabaseManager.shared.client.auth.session
            if current.expiresAt <= Date().timeIntervalSince1970 + 60 {
                session = try await SupabaseManager.shared.client.auth.refreshSession()
            } else {
                session = current
            }
        } catch {
            // If session fetch fails, try refreshing once
            session = try await SupabaseManager.shared.client.auth.refreshSession()
        }

        var urlComponents = URLComponents(string: "\(baseURL)/\(function)")!
        if !queryParams.isEmpty {
            urlComponents.queryItems = queryParams.map { URLQueryItem(name: $0.key, value: $0.value) }
        }
        var request = URLRequest(url: urlComponents.url!)
        request.httpMethod = "POST"
        request.setValue(anonKey, forHTTPHeaderField: "apikey")
        request.setValue("Bearer \(session.accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = body ?? "{}".data(using: .utf8)
        return request
    }

     func perform<T: Decodable>(_ request: URLRequest) async throws -> T {
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }

        // On 401, log response body and retry once with refreshed session
        if httpResponse.statusCode == 401 {
            let bodyText = String(data: data, encoding: .utf8) ?? "(\(data.count) bytes)"
            guard let originalURL = request.url else {
                print("❌ [APIService] 401 response body: \(bodyText)")
                throw APIError.httpError(401)
            }
            let function = originalURL.lastPathComponent
            print("⚠️ [APIService] 401 for \(function) — body: \(bodyText)")
            print("⚠️ [APIService] Refreshing session and retrying...")
            let refreshedSession = try await SupabaseManager.shared.client.auth.refreshSession()
            var retryRequest = request
            retryRequest.setValue("Bearer \(refreshedSession.accessToken)", forHTTPHeaderField: "Authorization")
            let (retryData, retryResponse) = try await URLSession.shared.data(for: retryRequest)
            guard let retryHttp = retryResponse as? HTTPURLResponse else {
                throw APIError.invalidResponse
            }
            guard (200...299).contains(retryHttp.statusCode) else {
                let retryBody = String(data: retryData, encoding: .utf8) ?? "(\(retryData.count) bytes)"
                print("❌ [APIService] Retry also failed with \(retryHttp.statusCode) — body: \(retryBody)")
                if let errorResponse = try? JSONDecoder().decode(ErrorResponse.self, from: retryData) {
                    throw APIError.serverError(errorResponse.error.message)
                }
                throw APIError.httpError(retryHttp.statusCode)
            }
            let decoder = JSONDecoder()
            decoder.keyDecodingStrategy = .convertFromSnakeCase
            let wrapper = try decoder.decode(APIResponse<T>.self, from: retryData)
            return wrapper.data
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            if let errorResponse = try? JSONDecoder().decode(ErrorResponse.self, from: data) {
                throw APIError.serverError(errorResponse.error.message)
            }
            throw APIError.httpError(httpResponse.statusCode)
        }
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        let wrapper = try decoder.decode(APIResponse<T>.self, from: data)
        return wrapper.data
    }

    // MARK: - Authenticated Data Calls

    func getActiveFireGoal() async throws -> APIFireGoal {
        let request = try await authenticatedRequest(function: "get-active-fire-goal")
        return try await perform(request)
    }

    func getNetWorthSummary() async throws -> APINetWorthSummary {
        let request = try await authenticatedRequest(function: "get-net-worth-summary")
        return try await perform(request)
    }

    func getSpendingSummary(month: String) async throws -> APISpendingSummary {
        let request = try await authenticatedRequest(function: "get-spending-summary", queryParams: ["month": month])
        return try await perform(request)
    }

    func getTransactions(
        page: Int = 1,
        limit: Int = 20,
        category: String? = nil,
        subcategory: String? = nil,
        startDate: String? = nil,
        endDate: String? = nil,
        pendingReview: Bool? = nil,
        accountId: String? = nil
    ) async throws -> APITransactionsResponse {
        var params: [String: String] = ["page": "\(page)", "limit": "\(limit)"]
        if let cat = category { params["category"] = cat }
        if let sub = subcategory { params["subcategory"] = sub }
        if let s = startDate { params["start_date"] = s }
        if let e = endDate { params["end_date"] = e }
        if let pr = pendingReview { params["pending_review"] = pr ? "true" : "false" }
        if let aid = accountId { params["account_id"] = aid }
        let request = try await authenticatedRequest(function: "get-transactions", queryParams: params)
        return try await perform(request)
    }

    func getMonthlyBudget(month: String) async throws -> APIMonthlyBudget {
        let request = try await authenticatedRequest(function: "get-monthly-budget", queryParams: ["month": month])
        return try await perform(request)
    }

    func saveSavingsCheckIn(month: String, savingsActual: Double?) async throws -> APIMonthlyBudget {
        struct SaveSavingsCheckInRequest: Encodable {
            let month: String
            let savingsActual: Double?

            enum CodingKeys: String, CodingKey {
                case month
                case savingsActual = "savings_actual"
            }
        }

        let body = try JSONEncoder().encode(
            SaveSavingsCheckInRequest(month: month, savingsActual: savingsActual)
        )
        let request = try await authenticatedRequest(function: "save-savings-checkin", body: body)
        return try await perform(request)
    }

    func updateTransactionClassification(
        transactionId: String,
        category: String?,
        subcategory: String?
    ) async throws -> APITransaction {
        print("🔄 [API] updateClassification start — id:\(transactionId) cat:\(category ?? "nil") sub:\(subcategory ?? "nil") onMain:\(Thread.isMainThread)")
        var payload: [String: Any] = ["transaction_id": transactionId]
        if let category { payload["flamora_category"] = category }
        if let subcategory { payload["flamora_subcategory"] = subcategory }
        print("🔄 [API] payload keys: \(payload.keys.sorted())")
        let body: Data
        do {
            body = try JSONSerialization.data(withJSONObject: payload, options: [])
        } catch {
            print("❌ [API] JSONSerialization failed: \(error)")
            throw error
        }
        print("🔄 [API] body ready (\(body.count) bytes), building auth request...")
        let request = try await authenticatedRequest(function: "update-transaction-classification", body: body)
        print("🔄 [API] auth request built, performing network call...")
        let result: APITransaction = try await perform(request)
        print("✅ [API] updateClassification success — id:\(result.id) cat:\(result.flamoraCategory ?? "nil")")
        return result
    }

    func getInvestmentHoldings() async throws -> APIInvestmentHoldingsPayload {
        let request = try await authenticatedRequest(function: "get-investment-holdings")
        return try await perform(request)
    }

    func getPortfolioHistory(range: String) async throws -> APIPortfolioHistory {
        var request = try await authenticatedRequest(function: "get-portfolio-history")
        if var components = URLComponents(url: request.url!, resolvingAgainstBaseURL: false) {
            components.queryItems = [URLQueryItem(name: "range", value: range)]
            request.url = components.url
        }
        return try await perform(request)
    }

    func getAccountBalanceHistory(accountId: String, range: String) async throws -> APIAccountBalanceHistory {
        var request = try await authenticatedRequest(function: "get-account-balance-history")
        if var components = URLComponents(url: request.url!, resolvingAgainstBaseURL: false) {
            components.queryItems = [
                URLQueryItem(name: "account_id", value: accountId),
                URLQueryItem(name: "range", value: range),
            ]
            request.url = components.url
        }
        return try await perform(request)
    }

    func calculateAvgSpending(months: Int) async throws -> APIAvgSpending {
        let body = try JSONEncoder().encode(["months": months])
        let request = try await authenticatedRequest(function: "calculate-avg-spending", body: body)
        return try await perform(request)
    }
}

// MARK: - API Errors
enum APIError: Error, LocalizedError {
    case invalidResponse
    case httpError(Int)
    case serverError(String)
    case decodingError
    
    var errorDescription: String? {
        switch self {
        case .invalidResponse:
            return "Invalid response from server"
        case .httpError(let code):
            return "HTTP error: \(code)"
        case .serverError(let message):
            return message
        case .decodingError:
            return "Failed to decode response"
        }
    }
}

// MARK: - New API Response Models

/// 与 Edge Function `get-spending-summary` 返回的 `data` 对齐。
struct APISpendingSummary: Codable {
    let month: String
    let totalSpending: Double
    let totalIncome: Double
    /// Active income (salary/payroll/wages)；旧版 API 不含此字段时回落到 totalIncome。
    let activeIncome: Double?
    /// Passive income (interest/dividends/rental)；旧版 API 不含此字段时回落到 0。
    let passiveIncome: Double?
    let incomeActiveSources: [APIIncomeSource]?
    let incomePassiveSources: [APIIncomeSource]?
    let needs: APISpendingCategoryBucket
    let wants: APISpendingCategoryBucket
    let savings: APISpendingSavingsBucket
}

struct APIIncomeSource: Codable {
    let name: String
    let amount: Double
    let percentage: Double
    /// 该来源桶内金额最大一笔的入账账户展示名（`get-spending-summary`）。
    let accountName: String?
    /// 该来源桶内当月最后一笔入账日 ISO `YYYY-MM-DD`。
    let creditDate: String?
}

struct APISpendingCategoryBucket: Codable {
    let total: Double
    let percentage: Double
    let budget: Double?
    let remaining: Double?
    let overBudget: Bool
    let subcategories: [APISpendingSubcategory]
}

struct APISpendingSubcategory: Codable {
    let subcategory: String
    let amount: Double
    let percentage: Double
}

struct APISpendingSavingsBucket: Codable {
    let budget: Double?
    let actual: Double?
    let estimated: Double?
}

/// 与 Edge Function `get-transactions` 返回的 `data` 对齐（见 `Fire cursor/supabase/functions/get-transactions/index.ts`）。
struct APITransactionsResponse: Codable {
    let transactions: [APITransaction]
    let pagination: APITransactionsPagination
    let pendingReviewCount: Int
}

struct APITransactionsPagination: Codable {
    let page: Int
    let limit: Int
    let total: Int
    let totalPages: Int
    let hasMore: Bool
}

/// `transactions` 表行（`select('*')`）；展示名优先 `merchant_name`，否则 `name`。
struct APITransaction: Codable {
    let id: String
    let merchantName: String?
    let name: String?
    let amount: Double
    let date: String
    let pendingReview: Bool?
    let flamoraCategory: String?
    let flamoraSubcategory: String?
    /// 与 `plaid_accounts.id` 一致。
    let plaidAccountId: String?

    /// 列表/行展示用商户名
    var merchantDisplay: String {
        let m = merchantName?.trimmingCharacters(in: .whitespacesAndNewlines)
        if let m, !m.isEmpty { return m }
        let n = name?.trimmingCharacters(in: .whitespacesAndNewlines)
        if let n, !n.isEmpty { return n }
        return "Transaction"
    }
}

extension Transaction {
    init(from api: APITransaction) {
        self.init(
            id: api.id,
            merchant: api.merchantDisplay,
            amount: api.amount,
            date: api.date,
            time: nil,
            pendingClassification: api.pendingReview ?? false,
            subcategory: api.flamoraSubcategory,
            category: api.flamoraCategory,
            note: nil,
            accountId: api.plaidAccountId
        )
    }

    /// 将本地编辑后的交易合并回列表（`date` 需与 `get-transactions` 的 `yyyy-MM-dd` 一致）。
    func asAPITransaction(normalizedDate: String) -> APITransaction {
        APITransaction(
            id: id,
            merchantName: merchant,
            name: nil,
            amount: amount,
            date: normalizedDate,
            pendingReview: pendingClassification,
            flamoraCategory: category,
            flamoraSubcategory: subcategory,
            plaidAccountId: accountId
        )
    }
}

/// 与 Edge Function `get-investment-holdings` 的 `data` 对齐。
struct APIInvestmentHoldingsPayload: Codable {
    let summary: APIInvestmentHoldingsSummary
    let typeBreakdown: [APIInvestmentTypeBreakdownRow]
    let holdings: [APIInvestmentHoldingRow]
    let accounts: [APIInvestmentAccount]?
}

struct APIInvestmentHoldingsSummary: Codable {
    let totalValue: Double
    /// 账户 balance_current 总和（包含未投资现金），是 Portfolio 主数字的正确来源。
    let totalAccountValue: Double?
    let totalHoldingsValue: Double?
    /// 账户总值 - 持仓市值，即券商内尚未买入任何证券的现金。
    let uninvestedCashValue: Double?
    let totalCostBasis: Double?
    let totalGainLoss: Double?
    let totalGainLossPct: Double?
    let holdingsCount: Int
}

/// 单个 investment account 的余额与持仓拆分。
struct APIInvestmentAccount: Codable {
    let id: String
    let name: String
    let mask: String?
    let subtype: String?
    let institutionName: String?
    let balanceCurrent: Double
    let holdingsValue: Double
    let uninvestedCashValue: Double
}

struct APIInvestmentTypeBreakdownRow: Codable {
    let type: String
    let value: Double
    let percentage: Double
}

struct APIInvestmentHoldingRow: Codable {
    let id: String
    /// 与 `plaid_accounts.id` 一致，用于与账户、交易关联。
    let plaidAccountId: String?
    let name: String
    let ticker: String?
    let type: String?
    let quantity: Double?
    let price: Double?
    let value: Double?
    let costBasis: Double?
    let gainLoss: Double?
    let gainLossPct: Double?
    let accountName: String?
    let accountMask: String?
}

struct APIAvgSpending: Codable {
    let averageMonthlySpending: Double
    let months: Int
    let needsAvg: Double
    let wantsAvg: Double
}

/// 与 Edge Function `get-portfolio-history` 的 `data` 对齐。
struct APIPortfolioHistory: Codable {
    let points: [APIPortfolioPoint]
    let range: String
}

struct APIPortfolioPoint: Codable {
    let date: String
    let value: Double
}

struct APIAccountBalanceHistory: Codable {
    let account: APIAccountBalanceHistoryAccount
    let points: [APIAccountBalanceHistoryPoint]
    let range: String
}

struct APIAccountBalanceHistoryAccount: Codable {
    let id: String
    let name: String
    let type: String
    let subtype: String?
    let mask: String?
    let institutionName: String?
}

struct APIAccountBalanceHistoryPoint: Codable {
    let date: String
    let currentBalance: Double
    let availableBalance: Double?
}
