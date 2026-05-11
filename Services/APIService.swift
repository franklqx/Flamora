//
//  APIService.swift
//  Flamora app
//
//  API Service for backend communication
//

import Foundation
internal import Auth
import Supabase
internal import Functions

class APIService {
    static let shared = APIService()
    
    private var baseURL: String { AppConfig.supabaseFunctionsBaseURL }
    private var anonKey: String { AppConfig.supabaseAnonKey }
    private var client: SupabaseClient { SupabaseManager.shared.client }
    
    private init() {}
    
    // MARK: - Create User Profile
    func createUserProfile(data: OnboardingData) async throws -> CreateProfileResponse {
        let url = URL(string: "\(baseURL)/create-user-profile")!
        var request = URLRequest(url: url, timeoutInterval: 20)
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
        let finalUserId = userId.lowercased()

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

    private func invokeFunction<T: Decodable, Body: Encodable>(
        _ function: String,
        body: Body
    ) async throws -> T {
        // Proactively refresh session if token is expiring within 60s (mirrors authenticatedRequest).
        let session: Session
        do {
            let current = try await client.auth.session
            if current.expiresAt <= Date().timeIntervalSince1970 + 60 {
                session = try await client.auth.refreshSession()
            } else {
                session = current
            }
        } catch {
            session = try await client.auth.refreshSession()
        }
        let options = FunctionInvokeOptions(
            headers: ["Authorization": "Bearer \(session.accessToken)"],
            body: body
        )
        let response: APIResponse<T> = try await client.functions.invoke(function, options: options)
        return response.data
    }

    private func invokeFunction<T: Decodable>(_ function: String) async throws -> T {
        try await invokeFunction(function, body: EmptyJSONBody())
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
        var request = URLRequest(url: urlComponents.url!, timeoutInterval: 20)
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

        // On 401, refresh session and retry once
        if httpResponse.statusCode == 401 {
            let function = request.url?.lastPathComponent ?? "unknown"
            #if DEBUG
            let bodyText = String(data: data, encoding: .utf8) ?? "(\(data.count) bytes)"
            print("⚠️ [APIService] 401 for \(function) — body: \(bodyText)")
            print("⚠️ [APIService] Refreshing session and retrying...")
            #endif
            guard request.url != nil else {
                throw APIError.httpError(401)
            }
            let _ = function // suppress unused warning in release
            let refreshedSession = try await SupabaseManager.shared.client.auth.refreshSession()
            var retryRequest = request
            retryRequest.setValue("Bearer \(refreshedSession.accessToken)", forHTTPHeaderField: "Authorization")
            let (retryData, retryResponse) = try await URLSession.shared.data(for: retryRequest)
            guard let retryHttp = retryResponse as? HTTPURLResponse else {
                throw APIError.invalidResponse
            }
            guard (200...299).contains(retryHttp.statusCode) else {
                #if DEBUG
                let retryBody = String(data: retryData, encoding: .utf8) ?? "(\(retryData.count) bytes)"
                print("❌ [APIService] Retry also failed with \(retryHttp.statusCode) — body: \(retryBody)")
                #endif
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

    /// Partial update for `user_profiles`. Used by the manual-mode budget
    /// setup to keep `monthly_income` / `current_net_worth` / `age` in sync
    /// with what the user just typed, so downstream readers (Home Hero,
    /// `get-active-fire-goal`, `generate-plans`, etc.) don't see stale
    /// onboarding estimates. Pass `nil` for any field you don't want to touch.
    @discardableResult
    func updateUserProfile(
        age: Int? = nil,
        monthlyIncome: Double? = nil,
        currentNetWorth: Double? = nil,
        currentMonthlyExpenses: Double? = nil,
        currencyCode: String? = nil,
        startingPortfolioBalance: Double? = nil,
        startingPortfolioSource: String? = nil
    ) async throws -> UpdatedUserProfile {
        var payload: [String: Any] = [:]
        if let age { payload["age"] = age }
        if let monthlyIncome { payload["monthly_income"] = monthlyIncome }
        if let currentNetWorth { payload["current_net_worth"] = currentNetWorth }
        if let currentMonthlyExpenses { payload["current_monthly_expenses"] = currentMonthlyExpenses }
        if let currencyCode { payload["currency_code"] = currencyCode }
        if let startingPortfolioBalance { payload["starting_portfolio_balance"] = startingPortfolioBalance }
        if let startingPortfolioSource { payload["starting_portfolio_source"] = startingPortfolioSource }
        let body = try JSONSerialization.data(withJSONObject: payload, options: [])
        let request = try await authenticatedRequest(function: "update-user-profile", body: body)
        let result: UpdatedUserProfile = try await perform(request)
        return result
    }

    func updateTransactionClassification(
        transactionId: String,
        category: String?,
        subcategory: String?
    ) async throws -> APITransaction {
        var payload: [String: Any] = ["transaction_id": transactionId]
        if let category { payload["flamora_category"] = category }
        if let subcategory { payload["flamora_subcategory"] = subcategory }
        let body: Data
        do {
            body = try JSONSerialization.data(withJSONObject: payload, options: [])
        } catch {
            throw error
        }
        let request = try await authenticatedRequest(function: "update-transaction-classification", body: body)
        let result: APITransaction = try await perform(request)
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

    /// 拉用户每日 net-worth 快照序列（来自 `net_worth_history`，由 Plaid webhook 自动写入）。
    /// `range`: `1w` | `1m` | `3m` | `1y` | `all`
    func getNetWorthHistory(range: String) async throws -> APINetWorthHistory {
        var request = try await authenticatedRequest(function: "get-net-worth-history")
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

    // MARK: - v2 Home / Plan System

    /// Fetch the official Hero model (v2 extended get-active-fire-goal response).
    /// Returns `HomeHeroModel` with FIRE date, active plan metadata, and progress status.
    func getHomeHero() async throws -> HomeHeroModel {
        try await invokeFunction("get-active-fire-goal")
    }

    /// Fetch the current setup stage for the Home state machine (S0–S5).
    func getSetupState() async throws -> HomeSetupStateResponse {
        try await invokeFunction("get-setup-state")
    }

    /// Like `getSetupState()`, but persists the response on success and returns the last cached value on failure (if any).
    func getSetupStatePersistingCache() async -> HomeSetupStateResponse? {
        do {
            let state = try await getSetupState()
            HomeSetupStateCache.save(state)
            return state
        } catch {
            #if DEBUG
            print("⚠️ [API] getSetupState failed, trying cache: \(error)")
            #endif
            return HomeSetupStateCache.load()
        }
    }

    /// Apply a chosen plan to become the official active plan.
    func applySelectedPlan(data: ApplyPlanRequest) async throws -> ActivePlanModel {
        try await invokeFunction("apply-selected-plan", body: data)
    }

    /// Preview simulator — powers demo and official sandbox modes.
    /// Never writes to official state.
    func previewSimulator(data: SimulatorPreviewRequest) async throws -> SimulatorPreviewModel {
        try await invokeFunction("preview-simulator", body: data)
    }

    /// Mark a setup step as completed in user_setup_state.
    /// Phase 2: backed by `mark-setup-step` Edge Function (not yet deployed).
    /// Accepted steps: "accounts_reviewed" | "snapshot_reviewed"
    func markSetupStep(_ step: String) async throws {
        let _: EmptySuccessResponse = try await invokeFunction("mark-setup-step", body: MarkSetupStepRequest(step: step))
    }

    // MARK: - Reports

    func getRecentReports(limit: Int = 12) async throws -> [ReportFeedItem] {
        let request = try await authenticatedRequest(
            function: "get-report-feed",
            queryParams: ["limit": "\(limit)"]
        )
        return try await perform(request)
    }

    func getArchivedReports(kind: ReportKind? = nil, year: Int? = nil, cursor: String? = nil, limit: Int = 20) async throws -> [ReportArchiveItem] {
        var params: [String: String] = ["limit": "\(limit)"]
        if let kind { params["kind"] = kind.rawValue }
        if let year { params["year"] = "\(year)" }
        if let cursor { params["cursor"] = cursor }
        let request = try await authenticatedRequest(function: "get-report-archive", queryParams: params)
        return try await perform(request)
    }

    func getLatestReport(kind: ReportKind) async throws -> ReportSnapshot {
        let request = try await authenticatedRequest(
            function: "get-report-detail",
            queryParams: [
                "kind": kind.rawValue,
                "latest": "true"
            ]
        )
        return try await perform(request)
    }

    func getReportDetail(id: String) async throws -> ReportSnapshot {
        let request = try await authenticatedRequest(
            function: "get-report-detail",
            queryParams: ["id": id]
        )
        return try await perform(request)
    }

    func markReportViewed(id: String) async throws {
        struct MarkReportViewedRequest: Encodable {
            let reportId: String

            enum CodingKeys: String, CodingKey {
                case reportId = "report_id"
            }
        }

        let _: EmptySuccessResponse = try await invokeFunction(
            "mark-report-viewed",
            body: MarkReportViewedRequest(reportId: id)
        )
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

private struct EmptyJSONBody: Encodable {}
private struct MarkSetupStepRequest: Encodable { let step: String }
private struct EmptySuccessResponse: Decodable {}

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
    /// 最近两次投资历史快照之间的真实变化，优先表示「今日变化」。
    let todayChange: Double?
    let todayChangePct: Double?
    let holdingsCount: Int
}

/// 单个 investment account 的余额与持仓拆分。
/// `APIService.perform` uses `keyDecodingStrategy = .convertFromSnakeCase`,
/// so `institution_logo_base64` → `institutionLogoBase64` automatically — no CodingKeys needed.
struct APIInvestmentAccount: Codable {
    let id: String
    let name: String
    let mask: String?
    let subtype: String?
    let institutionName: String?
    let institutionLogoBase64: String?
    let institutionLogoUrl: String?
    let institutionPrimaryColor: String?
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

/// 与 Edge Function `get-net-worth-history` 的 `data` 对齐（`{ points: [{date, value}], range }`）。
struct APINetWorthHistory: Codable {
    let points: [APIPortfolioPoint]
    let range: String
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
