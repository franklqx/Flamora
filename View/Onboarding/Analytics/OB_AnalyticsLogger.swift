//
//  OB_AnalyticsLogger.swift
//  Flamora app
//
//  Onboarding 埋点轻量封装
//  设计原则: 上报失败不影响主流程；事件/参数集中管理便于后续接 SDK
//
//  接入说明: 将 send(_:) 中的 print 替换为 Analytics SDK 调用即可
//

import Foundation

// MARK: - Event Enum

enum OB_AnalyticsEvent: String {
    // Roadmap 页面
    case roadmapViewed           = "roadmap_viewed"
    case roadmapCtaTapped        = "roadmap_cta_tapped"
    case roadmapCaseResolved     = "roadmap_case_resolved"
    case roadmapTimelineVisible  = "roadmap_timeline_visible"
    case roadmapLockedCardTapped = "roadmap_locked_card_tapped"

    // Aha Moment 页面
    case ahaViewed               = "aha_viewed"

    // 加载页
    case loadingAnalysisViewed   = "loading_analysis_viewed"
}

// MARK: - Logger

struct OB_AnalyticsLogger {

    // MARK: Roadmap Events

    /// 记录 Roadmap 展示事件（包含完整 FIRE 指标）
    static func log(_ event: OB_AnalyticsEvent, metrics: RoadmapMetrics) {
        let props: [String: Any] = [
            "case_type":            metrics.userCase.rawValue,
            "current_age":          metrics.currentAge,
            "freedom_age_before":   metrics.freedomAge,
            "freedom_age_after":    metrics.optimizedFreedomAge,
            "years_earlier":        metrics.yearsEarlier,
            "extra_monthly_invest": metrics.extraMonthlyInvestRecommendation,
            "savings_rate":         String(format: "%.1f", metrics.savingsRate),
            "target_amount":        Int(metrics.targetAmount),
            "delay_cost_years":     metrics.delayCostYears,
            "timeline_progress":    String(format: "%.2f", metrics.timelineProgress),
        ]
        send(event, properties: props)
    }

    /// 记录锁定洞察卡点击事件
    static func log(_ event: OB_AnalyticsEvent, cardTitle: String) {
        send(event, properties: ["card_title": cardTitle])
    }

    /// 记录无参数事件（如 aha_viewed）
    static func log(_ event: OB_AnalyticsEvent) {
        send(event, properties: [:])
    }

    // MARK: - Internals

    /// 实际发送逻辑 — 当前用 print，接入 SDK 时替换此函数即可
    private static func send(_ event: OB_AnalyticsEvent, properties: [String: Any]) {
        var logLine = "[Analytics] \(event.rawValue)"
        if !properties.isEmpty {
            let propsStr = properties
                .sorted { $0.key < $1.key }
                .map { "\($0.key)=\($0.value)" }
                .joined(separator: ", ")
            logLine += " | \(propsStr)"
        }
        print(logLine)

        // TODO: 接入 SDK 后替换以上 print，示例:
        // Mixpanel.mainInstance().track(event: event.rawValue, properties: properties)
        // Analytics.logEvent(event.rawValue, parameters: properties)
    }
}
