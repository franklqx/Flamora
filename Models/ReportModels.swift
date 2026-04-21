//
//  ReportModels.swift
//  Flamora app
//
//  Unified report/feed/archive models for weekly, monthly, annual, and issue-zero stories.
//

import Foundation

enum ReportKind: String, Codable, CaseIterable, Identifiable {
    case weekly
    case monthly
    case annual
    case issueZero = "issue_zero"

    var id: String { rawValue }

    var displayTitle: String {
        switch self {
        case .weekly: return "Weekly Report"
        case .monthly: return "Monthly Report"
        case .annual: return "Annual Wrapped"
        case .issueZero: return "Issue Zero"
        }
    }

    var sectionTitle: String {
        switch self {
        case .weekly: return "Weekly"
        case .monthly: return "Monthly"
        case .annual: return "Annual"
        case .issueZero: return "Issue Zero"
        }
    }

    var systemImage: String {
        switch self {
        case .weekly: return "calendar.badge.clock"
        case .monthly: return "calendar"
        case .annual: return "chart.bar.doc.horizontal"
        case .issueZero: return "sparkles"
        }
    }
}

enum ReportStatus: String, Codable {
    case pending
    case ready
    case failed
}

enum StoryBackgroundStyle: String, Codable {
    case purple
    case green
    case amber
    case blue
    case dark
}

enum StoryHeroStyle: String, Codable {
    case gradientFire = "gradient_fire"
    case success
    case warning
    case error
    case primary
    case secondary
}

enum StoryLayout: String, Codable {
    case hero
    case insight
    case grid
    case headline
    case cta
}

enum StoryHeroFont: String, Codable {
    case storyHero
    case h1
    case h2
    case cardFigurePrimary
}

struct ReportPeriod: Codable, Equatable {
    let start: String
    let end: String
    let label: String
}

struct StoryMetricRow: Codable, Identifiable, Equatable {
    let id: String
    let label: String
    let value: String
    let note: String?
    let valueStyle: StoryHeroStyle?

    init(id: String = UUID().uuidString, label: String, value: String, note: String? = nil, valueStyle: StoryHeroStyle? = nil) {
        self.id = id
        self.label = label
        self.value = value
        self.note = note
        self.valueStyle = valueStyle
    }
}

struct StoryGridItem: Codable, Identifiable, Equatable {
    let id: String
    let label: String
    let value: String

    init(id: String = UUID().uuidString, label: String, value: String) {
        self.id = id
        self.label = label
        self.value = value
    }
}

struct StoryPayload: Codable, Identifiable, Equatable {
    let id: String
    let layout: StoryLayout
    let label: String?
    let background: StoryBackgroundStyle
    let heroText: String?
    let heroSubtext: String?
    let heroStyle: StoryHeroStyle?
    let heroFont: StoryHeroFont?
    let badgeText: String?
    let rows: [StoryMetricRow]
    let gridItems: [StoryGridItem]
    let insightText: String?
    let insightSource: String?
    let ctaLabel: String?
}

struct ReportFeedItem: Codable, Identifiable, Equatable {
    let id: String
    let reportId: String
    let kind: ReportKind
    let title: String
    let subtitle: String
    let periodLabel: String
    let generatedAt: String
    let viewedAt: String?
    let isUnread: Bool
    let status: ReportStatus

    enum CodingKeys: String, CodingKey {
        case id
        case reportId = "report_id"
        case kind
        case title
        case subtitle
        case periodLabel = "period_label"
        case generatedAt = "generated_at"
        case viewedAt = "viewed_at"
        case isUnread = "is_unread"
        case status
    }
}

typealias ReportArchiveItem = ReportFeedItem

struct ReportSnapshot: Codable, Identifiable, Equatable {
    let id: String
    let userId: String?
    let kind: ReportKind
    let status: ReportStatus
    let title: String
    let period: ReportPeriod
    let generatedAt: String
    let viewedAt: String?
    let insightText: String?
    let insightProvider: String?
    let metricsPayload: [String: String]
    let stories: [StoryPayload]

    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case kind
        case status
        case title
        case period
        case generatedAt = "generated_at"
        case viewedAt = "viewed_at"
        case insightText = "insight_text"
        case insightProvider = "insight_provider"
        case metricsPayload = "metrics_payload"
        case stories = "story_payload"
    }

    var isUnread: Bool { viewedAt == nil }
}

extension ReportSnapshot {
    static let previewWeekly = ReportSnapshot(
        id: "preview-weekly",
        userId: "preview",
        kind: .weekly,
        status: .ready,
        title: "Weekly Report",
        period: ReportPeriod(start: "2026-04-07", end: "2026-04-13", label: "Apr 7 – Apr 13"),
        generatedAt: "2026-04-14T09:00:00Z",
        viewedAt: nil,
        insightText: "You saved more this week because dining-out dropped while income held steady. If you keep that pace, your FIRE date keeps inching forward.",
        insightProvider: "Groq · Llama 3.3",
        metricsPayload: ["weekly_savings": "420"],
        stories: [
            StoryPayload(
                id: "fire",
                layout: .hero,
                label: "FIRE THIS WEEK",
                background: .purple,
                heroText: "-6 d",
                heroSubtext: "vs last week",
                heroStyle: .gradientFire,
                heroFont: .storyHero,
                badgeText: nil,
                rows: [
                    StoryMetricRow(label: "FIRE date", value: "Mar 2041"),
                    StoryMetricRow(label: "Last week", value: "Mar 2041", note: "6 days later"),
                    StoryMetricRow(label: "Net worth", value: "$412,400")
                ],
                gridItems: [],
                insightText: nil,
                insightSource: nil,
                ctaLabel: nil
            ),
            StoryPayload(
                id: "savings",
                layout: .hero,
                label: "NET SAVINGS",
                background: .green,
                heroText: "$420",
                heroSubtext: "saved this week",
                heroStyle: .success,
                heroFont: .storyHero,
                badgeText: nil,
                rows: [
                    StoryMetricRow(label: "Income", value: "$1,980"),
                    StoryMetricRow(label: "Spending", value: "$1,560"),
                    StoryMetricRow(label: "Savings rate", value: "21%")
                ],
                gridItems: [],
                insightText: nil,
                insightSource: nil,
                ctaLabel: nil
            ),
            StoryPayload(
                id: "outlier",
                layout: .hero,
                label: "SPENDING OUTLIER",
                background: .amber,
                heroText: "$186",
                heroSubtext: "Dining Out",
                heroStyle: .warning,
                heroFont: .cardFigurePrimary,
                badgeText: nil,
                rows: [
                    StoryMetricRow(label: "vs avg", value: "↑ 1.8×", note: "4-week baseline", valueStyle: .warning),
                    StoryMetricRow(label: "2nd highest", value: "Shopping · $132"),
                    StoryMetricRow(label: "Total spend", value: "$1,560")
                ],
                gridItems: [],
                insightText: nil,
                insightSource: nil,
                ctaLabel: nil
            ),
            StoryPayload(
                id: "insight",
                layout: .insight,
                label: "AI INSIGHT",
                background: .dark,
                heroText: nil,
                heroSubtext: nil,
                heroStyle: nil,
                heroFont: nil,
                badgeText: nil,
                rows: [],
                gridItems: [],
                insightText: "You created most of this week's progress by cutting a single category, not by earning more. That makes this pace repeatable.",
                insightSource: "Powered by Llama 3.3 via Groq",
                ctaLabel: nil
            )
        ]
    )
}
