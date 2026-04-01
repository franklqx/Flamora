//
//  TabContentCache.swift
//  Flamora app
//
//  跨 Tab 切换时保留上次拉取的摘要数据，避免子视图销毁后重进出现「先空后闪」。
//  断连银行时清空。
//

import Foundation

final class TabContentCache {
    static let shared = TabContentCache()

    /// Investment Tab 上次成功的 `get-net-worth-summary`；断连或未加载时为 nil。
    private(set) var investmentNetWorth: APINetWorthSummary?

    private init() {}

    func setInvestmentNetWorth(_ value: APINetWorthSummary?) {
        investmentNetWorth = value
    }

    func clearAfterBankDisconnect() {
        investmentNetWorth = nil
    }
}
