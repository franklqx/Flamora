//
//  InvestmentHeroData.swift
//  Meridian
//
//  @Observable shared state between InvestmentView (sheet) and
//  InvestmentPortfolioReveal (hero area overlay).
//  Created in MainTabView as @State and injected via .environment().
//

import Foundation
import Observation

@Observable
final class InvestmentHeroData {
    /// 所有 investment accounts 的合计市值
    var balance: Double = 0
    /// 总盈亏金额
    var gainAmount: Double = 0
    /// 总盈亏百分比
    var gainPercentage: Double = 0
    /// 按时间范围缓存的历史曲线（同 TabContentCache.portfolioHistory 格式）
    var historyCache: [String: [PortfolioDataPoint]] = [:]
    /// 用户当前选中的时间范围（Hero 与 InvestmentView 共享）
    var selectedRange: PortfolioTimeRange = .oneWeek

    /// 当前选中时间范围对应的数据点序列
    var currentData: [PortfolioDataPoint] {
        historyCache[selectedRange.heroCacheKey] ?? []
    }
}

extension PortfolioTimeRange {
    /// 映射到 `portfolioHistoryCache` 使用的字符串 key
    var heroCacheKey: String {
        switch self {
        case .oneWeek:      return "1w"
        case .oneMonth:     return "1m"
        case .threeMonths:  return "3m"
        case .ytd:          return "ytd"
        case .all:          return "all"
        }
    }
}
