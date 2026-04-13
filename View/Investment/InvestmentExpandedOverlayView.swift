//
//  InvestmentExpandedOverlayView.swift
//  Flamora app
//

import SwiftUI

struct InvestmentExpandedOverlayView: View {
    let topPadding: CGFloat
    let onClose: () -> Void

    @Environment(PlaidManager.self) private var plaidManager
    @StateObject private var store = InvestmentDataStore()
    @State private var selectedRange: PortfolioTimeRange = .oneWeek
    @State private var expandedAccountIds: Set<String> = []
    @State private var showTrustBridge = false

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: AppSpacing.lg) {
                topBar
                    .padding(.top, topPadding)

                amountSection
                chartSection
                metricsSection

                if !plaidManager.hasLinkedBank {
                    SheetPrimaryCTAButton(label: "Connect Accounts", action: openConnectFlow)
                }

                detailSection
            }
            .padding(.horizontal, AppSpacing.screenPadding)
            .padding(.bottom, AppSpacing.xl)
        }
        .onAppear {
            store.restoreFromCache()
        }
        .task {
            await store.load(plaidManager: plaidManager)
        }
        .onChange(of: plaidManager.hasLinkedBank) { _, _ in
            Task { await store.load(plaidManager: plaidManager) }
        }
        .onChange(of: plaidManager.lastConnectionTime) { _, _ in
            Task { await store.load(plaidManager: plaidManager) }
        }
        .sheet(isPresented: $showTrustBridge, onDismiss: {
            if UserDefaults.standard.bool(forKey: AppLinks.plaidTrustBridgeSeen) {
                Task { await plaidManager.startLinkFlow() }
            }
        }) {
            PlaidTrustBridgeView()
        }
    }
}

private extension InvestmentExpandedOverlayView {
    var topBar: some View {
        HStack {
            Text("Investment Total")
                .font(.h1)
                .foregroundStyle(AppColors.heroTextPrimary)
            Spacer()
        }
    }

    var amountSection: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            Text(formattedHeadlineValue)
                .font(.currencyHero)
                .foregroundStyle(AppColors.heroTextPrimary)
                .contentTransition(.numericText())
                .monospacedDigit()

            if plaidManager.hasLinkedBank, let pct = store.todayChangePct {
                Text(formattedPercent(pct) + " today")
                    .font(.footnoteSemibold)
                    .foregroundStyle(pct >= 0 ? AppColors.success : AppColors.error)
                    .padding(.horizontal, AppSpacing.sm + AppSpacing.xs)
                    .padding(.vertical, AppSpacing.xs)
                    .background(Color.black.opacity(0.24))
                    .clipShape(Capsule())
            } else {
                HStack(spacing: AppSpacing.xs) {
                    Image(systemName: "lock.fill")
                        .font(.caption)
                    Text("Connect to unlock live performance")
                        .font(.footnoteSemibold)
                }
                .foregroundStyle(AppColors.heroTextSoft)
                .padding(.horizontal, AppSpacing.sm + AppSpacing.xs)
                .padding(.vertical, AppSpacing.xs)
                .background(Color.black.opacity(0.24))
                .clipShape(Capsule())
            }
        }
    }

    var chartSection: some View {
        VStack(alignment: .leading, spacing: AppSpacing.md) {
            InvestmentHeroChartCard(
                points: chartPoints,
                isLocked: !plaidManager.hasLinkedBank
            )

            GlassPillSelector(
                items: PortfolioTimeRange.allCases,
                selected: $selectedRange,
                label: { $0.label }
            )
        }
    }

    var metricsSection: some View {
        HStack(spacing: 0) {
            metricColumn(
                title: "Total Gain",
                value: plaidManager.hasLinkedBank ? formatSignedCurrency(store.totalGainLoss) : "$—",
                detail: plaidManager.hasLinkedBank ? optionalPercent(store.totalGainLossPct) : "Locked",
                positive: (store.totalGainLoss ?? 0) >= 0
            )
            metricDivider
            metricColumn(
                title: "Today Change",
                value: plaidManager.hasLinkedBank ? formatSignedCurrency(store.todayChange) : "$—",
                detail: plaidManager.hasLinkedBank ? optionalPercent(store.todayChangePct) : "Locked",
                positive: (store.todayChange ?? 0) >= 0
            )
            metricDivider
            metricColumn(
                title: "Cash",
                value: plaidManager.hasLinkedBank ? formatCurrency(store.cashValue) : "$—",
                detail: plaidManager.hasLinkedBank ? optionalPercent(store.cashPercentage) : "Locked",
                positive: true
            )
        }
        .padding(.vertical, AppSpacing.md)
        .background(Color.black.opacity(0.18))
        .clipShape(RoundedRectangle(cornerRadius: AppRadius.card))
        .overlay(
            RoundedRectangle(cornerRadius: AppRadius.card)
                .stroke(Color.white.opacity(0.08), lineWidth: 1)
        )
    }

    var detailSection: some View {
        VStack(alignment: .leading, spacing: AppSpacing.md) {
            Text("Investment Details")
                .font(.h4)
                .foregroundStyle(AppColors.inkPrimary)

            if plaidManager.hasLinkedBank {
                ForEach(store.accountGroups) { group in
                    InvestmentAccountGroupCard(
                        group: group,
                        isExpanded: expandedAccountIds.contains(group.id),
                        onTap: { toggleAccountGroup(group.id) }
                    )
                }
            } else {
                ForEach(lockedPreviewGroups) { group in
                    LockedInvestmentAccountGroupCard(group: group)
                }
            }
        }
    }

    var chartPoints: [PortfolioDataPoint] {
        if plaidManager.hasLinkedBank {
            let live = store.history(for: selectedRange)
            if !live.isEmpty { return live }
            return flatFallbackPoints(value: store.portfolioBalanceDisplay)
        }
        return lockedPreviewPoints(for: selectedRange)
    }

    var formattedHeadlineValue: String {
        plaidManager.hasLinkedBank ? formatCurrency(store.portfolioBalanceDisplay) : "$—"
    }

    var metricDivider: some View {
        Rectangle()
            .fill(Color.white.opacity(0.08))
            .frame(width: 1)
            .padding(.vertical, AppSpacing.sm)
    }

    var backgroundView: some View {
        ZStack {
            LinearGradient(
                gradient: AppColors.investBrandLinearGradient,
                startPoint: .top,
                endPoint: .bottom
            )
            RadialGradient(
                gradient: Gradient(colors: [AppColors.heroGlowPurple1, .clear]),
                center: UnitPoint(x: 0.16, y: 0.05),
                startRadius: 0,
                endRadius: 260
            )
            RadialGradient(
                gradient: Gradient(colors: [AppColors.investHeroGlowPurple2, .clear]),
                center: UnitPoint(x: 0.84, y: 0.12),
                startRadius: 0,
                endRadius: 280
            )
            RadialGradient(
                gradient: Gradient(colors: [AppColors.heroGlowPink, .clear]),
                center: UnitPoint(x: 0.62, y: 0.55),
                startRadius: 0,
                endRadius: 320
            )
        }
        .ignoresSafeArea()
    }

    func metricColumn(title: String, value: String, detail: String, positive: Bool) -> some View {
        VStack(spacing: AppSpacing.xs) {
            Text(title)
                .font(.smallLabel)
                .foregroundStyle(AppColors.heroTextFaint)

            Text(value)
                .font(.bodySemibold)
                .foregroundStyle(positive ? AppColors.heroTextPrimary : AppColors.heroTextPrimary)
                .multilineTextAlignment(.center)

            Text(detail)
                .font(.caption)
                .foregroundStyle(positive ? AppColors.heroTextSoft : AppColors.heroTextSoft)
        }
        .frame(maxWidth: .infinity)
    }

    func toggleAccountGroup(_ id: String) {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.82)) {
            if expandedAccountIds.contains(id) {
                expandedAccountIds.remove(id)
            } else {
                expandedAccountIds.insert(id)
            }
        }
    }

    func openConnectFlow() {
        if plaidManager.shouldShowTrustBridge() {
            showTrustBridge = true
        } else {
            Task { await plaidManager.startLinkFlow() }
        }
    }

    func formatCurrency(_ value: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "USD"
        formatter.maximumFractionDigits = 0
        formatter.minimumFractionDigits = 0
        return formatter.string(from: NSNumber(value: value)) ?? "$0"
    }

    func formatSignedCurrency(_ value: Double?) -> String {
        guard let value else { return "$—" }
        let base = formatCurrency(abs(value))
        return value >= 0 ? "+\(base)" : "-\(base)"
    }

    func formattedPercent(_ value: Double) -> String {
        value >= 0 ? "+\(String(format: "%.2f%%", value))" : "\(String(format: "%.2f%%", value))"
    }

    func optionalPercent(_ value: Double?) -> String {
        guard let value else { return "—" }
        return formattedPercent(value)
    }

    func lockedPreviewPoints(for range: PortfolioTimeRange) -> [PortfolioDataPoint] {
        let calendar = Calendar.current
        let now = Date()
        let previewValues: [Double]
        switch range {
        case .oneWeek:
            previewValues = [182_000, 184_200, 183_100, 188_400, 190_250, 189_600, 193_500]
        case .oneMonth:
            previewValues = [170_000, 171_200, 173_800, 175_400, 179_000, 181_500, 184_300, 187_200, 188_900, 191_400]
        case .threeMonths:
            previewValues = [150_000, 154_000, 158_500, 162_200, 168_900, 173_400, 179_600, 183_200, 188_100, 194_000]
        case .ytd:
            previewValues = [138_000, 142_500, 151_000, 158_400, 166_000, 174_500, 182_300, 191_200]
        case .all:
            previewValues = [92_000, 108_000, 121_000, 137_500, 151_400, 168_800, 182_000, 197_200]
        }
        return previewValues.enumerated().map { index, value in
            let dayOffset = previewValues.count - index - 1
            let date = calendar.date(byAdding: .day, value: -dayOffset, to: now) ?? now
            return PortfolioDataPoint(date: date, value: value)
        }
    }

    func flatFallbackPoints(value: Double) -> [PortfolioDataPoint] {
        let now = Date()
        let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: now) ?? now
        let fallbackValue = max(value, 0)
        return [
            PortfolioDataPoint(date: yesterday, value: fallbackValue),
            PortfolioDataPoint(date: now, value: fallbackValue)
        ]
    }

    var lockedPreviewGroups: [LockedAccountPreview] {
        [
            LockedAccountPreview(
                id: "brokerage-preview",
                title: "Primary Brokerage",
                subtitle: "Brokerage • •••• 4382",
                rows: [
                    LockedHoldingPreview(symbol: "VOO", name: "S&P 500 ETF"),
                    LockedHoldingPreview(symbol: "AAPL", name: "Apple")
                ]
            ),
            LockedAccountPreview(
                id: "crypto-preview",
                title: "Crypto Wallet",
                subtitle: "Crypto • •••• 1921",
                rows: [
                    LockedHoldingPreview(symbol: "ETH", name: "Ethereum"),
                    LockedHoldingPreview(symbol: "SOL", name: "Solana")
                ]
            )
        ]
    }
}

private struct InvestmentHeroChartCard: View {
    let points: [PortfolioDataPoint]
    let isLocked: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.md) {
            GeometryReader { proxy in
                let line = chartLine(in: proxy.size)
                ZStack {
                    ForEach(0..<4, id: \.self) { index in
                        Rectangle()
                            .fill(Color.white.opacity(0.06))
                            .frame(height: 1)
                            .offset(y: verticalOffset(index: index, height: proxy.size.height))
                    }

                    line
                        .stroke(
                            LinearGradient(
                                colors: [AppColors.heroTextSoft, AppColors.accentPink],
                                startPoint: .leading,
                                endPoint: .trailing
                            ),
                            style: StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round)
                        )

                    if let lastPoint = lastPlotPoint(in: proxy.size) {
                        Circle()
                            .fill(AppColors.accentPink)
                            .frame(width: 10, height: 10)
                            .position(lastPoint)
                    }

                    if isLocked {
                        RoundedRectangle(cornerRadius: AppRadius.card)
                            .fill(Color.black.opacity(0.18))
                        VStack(spacing: AppSpacing.xs) {
                            Image(systemName: "lock.fill")
                                .font(.bodySemibold)
                            Text("Connect to unlock live chart")
                                .font(.caption)
                        }
                        .foregroundStyle(AppColors.heroTextSoft)
                    }
                }
            }
            .frame(height: 220)

            HStack {
                ForEach(dateLabels, id: \.self) { label in
                    Text(label)
                        .font(.caption)
                        .foregroundStyle(AppColors.heroTextFaint)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
        .padding(AppSpacing.cardPadding)
        .background(Color.black.opacity(0.18))
        .clipShape(RoundedRectangle(cornerRadius: AppRadius.card))
        .overlay(
            RoundedRectangle(cornerRadius: AppRadius.card)
                .stroke(Color.white.opacity(0.08), lineWidth: 1)
        )
    }

    private var dateLabels: [String] {
        guard points.count >= 3 else { return ["", "", ""] }
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"
        let indices = [0, max(points.count / 2, 0), max(points.count - 1, 0)]
        return indices.map { formatter.string(from: points[$0].date) }
    }

    private func chartLine(in size: CGSize) -> Path {
        var path = Path()
        guard points.count > 1 else { return path }

        let values = points.map(\.value)
        let minValue = values.min() ?? 0
        let maxValue = values.max() ?? 1
        let span = max(maxValue - minValue, 1)

        for (index, point) in points.enumerated() {
            let x = size.width * CGFloat(index) / CGFloat(points.count - 1)
            let normalized = (point.value - minValue) / span
            let y = size.height - (CGFloat(normalized) * (size.height - 24)) - 12
            let location = CGPoint(x: x, y: y)
            if index == 0 {
                path.move(to: location)
            } else {
                path.addLine(to: location)
            }
        }

        return path
    }

    private func lastPlotPoint(in size: CGSize) -> CGPoint? {
        guard points.count > 1, let last = points.last else { return nil }
        let values = points.map(\.value)
        let minValue = values.min() ?? 0
        let maxValue = values.max() ?? 1
        let span = max(maxValue - minValue, 1)
        let normalized = (last.value - minValue) / span
        return CGPoint(
            x: size.width,
            y: size.height - (CGFloat(normalized) * (size.height - 24)) - 12
        )
    }

    private func verticalOffset(index: Int, height: CGFloat) -> CGFloat {
        let fraction = CGFloat(index) / 3
        return (-height / 2) + (height * fraction)
    }
}

private struct InvestmentAccountGroupCard: View {
    let group: InvestmentAccountGroup
    let isExpanded: Bool
    let onTap: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            Button(action: onTap) {
                HStack(spacing: AppSpacing.md) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(group.account.name ?? group.account.institution)
                            .font(.bodySemibold)
                            .foregroundStyle(AppColors.inkPrimary)
                        Text(subtitle)
                            .font(.caption)
                            .foregroundStyle(AppColors.inkMeta)
                    }

                    Spacer()

                    VStack(alignment: .trailing, spacing: 2) {
                        Text(formatCurrency(group.account.balance))
                            .font(.bodySemibold)
                            .foregroundStyle(AppColors.inkPrimary)
                        Text("Cash \(formatCurrency(group.cashValue))")
                            .font(.caption)
                            .foregroundStyle(AppColors.inkMeta)
                    }

                    Image(systemName: "chevron.down")
                        .font(.caption)
                        .foregroundStyle(AppColors.inkMeta)
                        .rotationEffect(.degrees(isExpanded ? 180 : 0))
                }
                .padding(AppSpacing.cardPadding)
            }
            .buttonStyle(.plain)

            if isExpanded {
                Rectangle()
                    .fill(Color.white.opacity(0.45))
                    .frame(height: 1)
                    .padding(.horizontal, AppSpacing.cardPadding)

                VStack(spacing: 8) {
                    ForEach(group.holdings.indices, id: \.self) { index in
                        HStack(spacing: AppSpacing.md) {
                            ZStack {
                                RoundedRectangle(cornerRadius: AppRadius.sm)
                                    .fill(AppColors.overlayWhiteMid)
                                    .frame(width: 38, height: 38)
                                Text(group.holdings[index].symbol)
                                    .font(.caption)
                                    .foregroundStyle(AppColors.inkPrimary)
                            }

                            VStack(alignment: .leading, spacing: 2) {
                                Text(group.holdings[index].name)
                                    .font(.bodySmallSemibold)
                                    .foregroundStyle(AppColors.inkPrimary)
                                Text(shareLabel(group.holdings[index]))
                                    .font(.caption)
                                    .foregroundStyle(AppColors.inkMeta)
                            }

                            Spacer()

                            Text(formatCurrency(group.holdings[index].totalValue))
                                .font(.bodySmallSemibold)
                                .foregroundStyle(AppColors.inkPrimary)
                        }
                        .padding(10)
                        .background(
                            RoundedRectangle(cornerRadius: 14)
                                .fill(Color.white.opacity(0.52))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 14)
                                .stroke(Color.white.opacity(0.68), lineWidth: 1)
                        )
                    }
                }
                .padding(.horizontal, AppSpacing.cardPadding)
                .padding(.vertical, AppSpacing.md)
            }
        }
        .background(
            LinearGradient(
                colors: [Color.white.opacity(0.86), Color(hex: "#F8F9FF").opacity(0.78)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .clipShape(RoundedRectangle(cornerRadius: AppRadius.card))
        .overlay(
            RoundedRectangle(cornerRadius: AppRadius.card)
                .stroke(Color.white.opacity(0.62), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.12), radius: 20, y: 8)
    }

    private var subtitle: String {
        var parts: [String] = [group.account.accountType.displayLabel]
        if let mask = group.account.mask, !mask.isEmpty {
            parts.append("• •••• \(mask)")
        }
        return parts.joined(separator: " ")
    }

    private func shareLabel(_ holding: Holding) -> String {
        if holding.shares > 0 {
            return String(format: "%.2f shares", holding.shares)
        }
        return "Position"
    }

    private func formatCurrency(_ value: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "USD"
        formatter.maximumFractionDigits = 0
        formatter.minimumFractionDigits = 0
        return formatter.string(from: NSNumber(value: value)) ?? "$0"
    }
}

private struct LockedAccountPreview: Identifiable {
    let id: String
    let title: String
    let subtitle: String
    let rows: [LockedHoldingPreview]
}

private struct LockedHoldingPreview: Identifiable {
    let symbol: String
    let name: String
    var id: String { symbol }
}

private struct LockedInvestmentAccountGroupCard: View {
    let group: LockedAccountPreview

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: AppSpacing.md) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(group.title)
                        .font(.bodySemibold)
                        .foregroundStyle(AppColors.inkPrimary)
                    Text(group.subtitle)
                        .font(.caption)
                        .foregroundStyle(AppColors.inkMeta)
                }

                Spacer()

                HStack(spacing: AppSpacing.xs) {
                    Image(systemName: "lock.fill")
                        .font(.caption)
                    Text("$—")
                        .font(.bodySemibold)
                }
                .foregroundStyle(AppColors.inkSoft)
            }
            .padding(AppSpacing.cardPadding)

            Rectangle()
                .fill(Color.white.opacity(0.45))
                .frame(height: 1)
                .padding(.horizontal, AppSpacing.cardPadding)

            VStack(spacing: 8) {
                ForEach(group.rows.indices, id: \.self) { index in
                    HStack(spacing: AppSpacing.md) {
                        ZStack {
                            RoundedRectangle(cornerRadius: AppRadius.sm)
                                .fill(AppColors.overlayWhiteMid)
                                .frame(width: 38, height: 38)
                            Image(systemName: "lock.fill")
                                .font(.caption)
                                .foregroundStyle(AppColors.inkSoft)
                        }

                        VStack(alignment: .leading, spacing: 2) {
                            Text(group.rows[index].symbol)
                                .font(.bodySmallSemibold)
                                .foregroundStyle(AppColors.inkPrimary)
                            Text(group.rows[index].name)
                                .font(.caption)
                                .foregroundStyle(AppColors.inkMeta)
                        }

                        Spacer()

                        Text("$—")
                            .font(.bodySmallSemibold)
                            .foregroundStyle(AppColors.inkSoft)
                    }
                    .padding(10)
                    .background(
                        RoundedRectangle(cornerRadius: 14)
                            .fill(Color.white.opacity(0.52))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .stroke(Color.white.opacity(0.68), lineWidth: 1)
                    )
                }
            }
            .padding(.horizontal, AppSpacing.cardPadding)
            .padding(.vertical, AppSpacing.md)
        }
        .background(
            LinearGradient(
                colors: [Color.white.opacity(0.86), Color(hex: "#F8F9FF").opacity(0.78)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .clipShape(RoundedRectangle(cornerRadius: AppRadius.card))
        .overlay(
            RoundedRectangle(cornerRadius: AppRadius.card)
                .stroke(Color.white.opacity(0.62), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.12), radius: 20, y: 8)
    }
}
