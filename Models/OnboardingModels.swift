//
//  OnboardingModels.swift
//  Flamora app
//
//  API Response models for Onboarding
//

import Foundation

// MARK: - API Response Models

struct CreateProfileResponse: Codable {
    let success: Bool
    let data: ProfileData
    let meta: Meta
    
    struct ProfileData: Codable {
        let profile: Profile
        let fireSummary: FireSummary
        
        struct Profile: Codable {
            let profileId: String
            let userId: String
            let username: String
            let onboardingCompleted: Bool
        }
        
        struct FireSummary: Codable {
            let fireNumber: Double
            let freedomAge: Int
            let yearsLeft: Int
            let requiredSavingsRate: Double
            let currentNetWorth: Double
            let gapToFire: Double
            let onTrack: Bool
        }
    }
    
    struct Meta: Codable {
        let timestamp: String
        let devMode: Bool?
    }
}

struct ErrorResponse: Codable {
    let success: Bool
    let error: ErrorDetail
    
    struct ErrorDetail: Codable {
        let code: String
        let message: String
    }
}

// MARK: - FIRE Summary Display Model
struct FireSummaryDisplayData {
    let fireNumber: Double
    let freedomAge: Int
    let yearsLeft: Int
    let savingsRate: Double
    let currentNetWorth: Double
    let gapToFire: Double
    let onTrack: Bool
    
    init(from apiSummary: CreateProfileResponse.ProfileData.FireSummary) {
        self.fireNumber = apiSummary.fireNumber
        self.freedomAge = apiSummary.freedomAge
        self.yearsLeft = apiSummary.yearsLeft
        self.savingsRate = apiSummary.requiredSavingsRate
        self.currentNetWorth = apiSummary.currentNetWorth
        self.gapToFire = apiSummary.gapToFire
        self.onTrack = apiSummary.onTrack
    }
}
