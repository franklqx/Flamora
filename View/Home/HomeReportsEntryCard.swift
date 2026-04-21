//
//  HomeReportsEntryCard.swift
//  Flamora app
//
//  Home Tab — Report 入口卡片（3 条入口：Monthly / Issue Zero / Annual）。
//  点击触发 `onSelect(.monthly | .issueZero | .annual)`；父 View 负责 present
//  `MonthlyReportView` / `IssueZeroView` / `AnnualReportView`（详见 DESIGN.md §Report Screens）。
//

import SwiftUI

enum HomeReportKind: String, Identifiable {
    case monthly
    case issueZero
    case annual

    var id: String { rawValue }

    var reportKind: ReportKind {
        switch self {
        case .monthly: return .monthly
        case .issueZero: return .issueZero
        case .annual: return .annual
        }
    }
}

struct HomeReportsEntryCard: View {
    var isConnected: Bool = true
    var monthlyReport: ReportSnapshot?
    var issueZeroReport: ReportSnapshot?
    var annualReport: ReportSnapshot?
    var onSelect: (HomeReportKind) -> Void

    private var cardBackground: LinearGradient {
        LinearGradient(
            colors: [AppColors.glassCardBg, AppColors.glassCardBg2],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    private var currentMonthLabel: String {
        let f = DateFormatter()
        f.dateFormat = "MMMM"
        return f.string(from: Date())
    }

    private var currentYearLabel: String {
        let f = DateFormatter()
        f.dateFormat = "yyyy"
        return f.string(from: Date())
    }

    var body: some View {
        VStack(spacing: 0) {
            header

            Rectangle()
                .fill(AppColors.inkDivider)
                .frame(height: 0.5)
                .padding(.horizontal, AppSpacing.cardPadding)

            if isConnected {
                connectedRows
            } else {
                lockedState
            }
        }
        .background(cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: AppRadius.lg))
        .overlay(
            RoundedRectangle(cornerRadius: AppRadius.lg)
                .stroke(AppColors.glassCardBorder, lineWidth: 1)
        )
    }

    // MARK: - Header

    private var header: some View {
        HStack {
            Text("REPORTS")
                .font(.cardHeader)
                .foregroundColor(AppColors.inkFaint)
                .tracking(AppTypography.Tracking.cardHeader)

            Spacer()

            Text("STORIES")
                .font(.cardHeader)
                .foregroundColor(AppColors.inkFaint)
                .tracking(AppTypography.Tracking.cardHeader)
        }
        .padding(.horizontal, AppSpacing.cardPadding)
        .padding(.top, AppSpacing.cardPadding)
        .padding(.bottom, AppSpacing.sm + AppSpacing.xs)
    }

    // MARK: - Rows

    @ViewBuilder
    private var connectedRows: some View {
        VStack(spacing: 0) {
            reportRow(
                kind: .monthly,
                title: "\(currentMonthLabel) Report",
                subtitle: monthlyReport != nil ? "Your FIRE progress this month" : "Not ready yet",
                symbol: "calendar",
                showNewBadge: monthlyReport?.isUnread == true,
                isAvailable: monthlyReport != nil
            )

            if issueZeroReport != nil {
                divider
                reportRow(
                    kind: .issueZero,
                    title: "Issue Zero",
                    subtitle: "Your first look at the numbers",
                    symbol: "sparkles",
                    showNewBadge: false,
                    isAvailable: true
                )
            }

            divider

            reportRow(
                kind: .annual,
                title: "\(currentYearLabel) Wrapped",
                subtitle: annualReport != nil ? "Your year in FIRE" : "Available Jan 1 each year",
                symbol: "gift.fill",
                showNewBadge: false,
                isAvailable: annualReport != nil
            )
        }
        .padding(.horizontal, AppSpacing.cardPadding)
        .padding(.vertical, AppSpacing.sm)
    }

    private var divider: some View {
        Rectangle()
            .fill(AppColors.inkDivider)
            .frame(height: 0.5)
            .padding(.leading, 40)   // indent past leading icon
    }

    private func reportRow(
        kind: HomeReportKind,
        title: String,
        subtitle: String,
        symbol: String,
        showNewBadge: Bool,
        isAvailable: Bool
    ) -> some View {
        Button {
            guard isAvailable else { return }
            onSelect(kind)
        } label: {
            HStack(spacing: AppSpacing.md) {
                ZStack {
                    Circle()
                        .fill(AppColors.inkTrack)
                        .frame(width: 32, height: 32)
                    Image(systemName: symbol)
                        .font(.footnoteSemibold)
                        .foregroundStyle(AppColors.inkPrimary.opacity(0.72))
                }

                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: AppSpacing.xs) {
                        Text(title)
                            .font(.inlineLabel)
                            .foregroundStyle(AppColors.inkPrimary)

                        if showNewBadge {
                            Text("NEW")
                                .font(.miniLabel)
                                .foregroundColor(AppColors.ctaWhite)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(
                                    Capsule().fill(AppColors.success)
                                )
                        }
                    }
                    Text(subtitle)
                        .font(.caption)
                        .foregroundColor(AppColors.inkSoft)
                        .lineLimit(1)
                }

                Spacer(minLength: 0)

                Image(systemName: "chevron.right")
                    .font(.footnoteSemibold)
                    .foregroundStyle(isAvailable ? AppColors.inkFaint : AppColors.inkFaint.opacity(0.5))
            }
            .padding(.vertical, AppSpacing.sm + 2)
            .contentShape(Rectangle())
            .opacity(isAvailable ? 1 : 0.58)
        }
        .buttonStyle(.plain)
        .disabled(!isAvailable)
    }

    // MARK: - Locked

    private var lockedState: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            Text("Your reports will appear here")
                .font(.footnoteRegular)
                .foregroundStyle(AppColors.inkSoft)

            Text("Connect accounts + set a budget to get monthly + annual FIRE reports.")
                .font(.caption)
                .foregroundStyle(AppColors.inkFaint)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, AppSpacing.cardPadding)
        .padding(.vertical, AppSpacing.md)
    }
}

// MARK: - Preview

#Preview("Connected") {
    ZStack {
        AppColors.backgroundPrimary.ignoresSafeArea()

        HomeReportsEntryCard(
            isConnected: true,
            monthlyReport: .previewWeekly,
            issueZeroReport: .previewWeekly,
            annualReport: .previewWeekly,
            onSelect: { _ in }
        )
        .padding()
    }
}

#Preview("Locked") {
    ZStack {
        AppColors.backgroundPrimary.ignoresSafeArea()

        HomeReportsEntryCard(
            isConnected: false,
            monthlyReport: nil,
            issueZeroReport: nil,
            annualReport: nil,
            onSelect: { _ in }
        )
        .padding()
    }
}
