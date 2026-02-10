//
//  APIService.swift
//  Flamora app
//
//  API Service for backend communication
//

import Foundation

class APIService {
    static let shared = APIService()
    
    private let baseURL = "https://vnyalfpmopvoswccewju.supabase.co/functions/v1"
    private let anonKey = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InZueWFsZnBtb3B2b3N3Y2Nld2p1Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzAxODg2ODgsImV4cCI6MjA4NTc2NDY4OH0.LWeaM9vRRoh0i-lUcMRV0BjTZHKVDvI8XGWRIcJajG4"
    
    private init() {}
    
    // MARK: - Create User Profile
    func createUserProfile(data: OnboardingData) async throws -> CreateProfileResponse {
        
        let url = URL(string: "\(baseURL)/create-user-profile")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(anonKey)", forHTTPHeaderField: "Authorization")
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
        
        // 构建请求体
        let body: [String: Any] = [
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
