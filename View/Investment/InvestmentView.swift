//
//  InvestmentView.swift
//  Flamora app
//
//  Investment overview page
//

import SwiftUI

struct InvestmentView: View {
    private let data = MockData.investmentData
    private let accountsBreakdown = MockData.investmentAccountsBreakdown
    @State private var showAccountsBreakdown = false

    var body: some View {
        ZStack {
            Color.clear

            GeometryReader { proxy in
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 20) {
                        PortfolioCard(portfolio: data.portfolio)
                            .padding(.horizontal, AppSpacing.screenPadding)

                        sectionHeader(title: "Accounts", actionTitle: "View all") {
                            showAccountsBreakdown = true
                        }
                        .padding(.horizontal, AppSpacing.screenPadding)

                        AccountsCard(accounts: data.accounts)
                            .padding(.horizontal, AppSpacing.screenPadding)

                        sectionHeader(title: "Asset allocation")
                            .padding(.horizontal, AppSpacing.screenPadding)

                        AssetAllocationCard(allocation: data.allocation)
                            .padding(.horizontal, AppSpacing.screenPadding)

                    }
                    .frame(minHeight: proxy.size.height, alignment: .top)
                    .padding(.bottom, AppSpacing.tabBarReserve)
                }
            }
        }
        .fullScreenCover(isPresented: $showAccountsBreakdown) {
            InvestmentAccountsBreakdownDetailView(data: accountsBreakdown)
        }
    }
}

// MARK: - Header
private extension InvestmentView {
    func sectionHeader(
        title: String,
        actionTitle: String? = nil,
        action: (() -> Void)? = nil
    ) -> some View {
        HStack {
            Text(title)
                .font(.system(size: 18, weight: .bold))
                .foregroundColor(.white)

            Spacer()

            if let actionTitle {
                if let action {
                    Button(action: action) {
                        Text(actionTitle)
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(Color(hex: "#A78BFA"))
                    }
                    .buttonStyle(.plain)
                } else {
                    Text(actionTitle)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(Color(hex: "#A78BFA"))
                }
            }
        }
    }
}

private struct InvestmentAccountsBreakdownDetailView: View {
    let data: InvestmentAccountsBreakdownData

    @Environment(\.dismiss) private var dismiss
    @State private var dragOffset: CGFloat = 0

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 24) {
                    headerSection

                    allocationsSection
                }
                .padding(.horizontal, 20)
                .padding(.top, 20)
                .padding(.bottom, 100)
            }
        }
        .preferredColorScheme(.dark)
        .offset(y: dragOffset)
        .gesture(
            DragGesture()
                .onChanged { value in
                    if value.translation.height > 0 {
                        dragOffset = value.translation.height
                    }
                }
                .onEnded { value in
                    if value.translation.height > 150 {
                        dismiss()
                    } else {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                            dragOffset = 0
                        }
                    }
                }
        )
    }

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                Text(data.title)
                    .font(.system(size: 28, weight: .bold))
                    .foregroundColor(.white)

                Spacer()

                Button(action: { dismiss() }) {
                    Image(systemName: "xmark")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.white)
                        .padding(.top, 2)
                }
                .buttonStyle(.plain)
            }

            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text(formatCurrency(data.totalAmount, minFractionDigits: 2, maxFractionDigits: 2))
                    .font(.system(size: 32, weight: .bold))
                    .foregroundColor(.white)

                Text("across connected accounts")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(Color(hex: "#9CA3AF"))
            }
        }
    }

    private var allocationsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Allocations")
                .font(.system(size: 22, weight: .bold))
                .foregroundColor(.white)

            VStack(spacing: 12) {
                ForEach(data.positions) { position in
                    InvestmentAccountPositionRow(position: position)
                }
            }
        }
    }

    private func formatCurrency(
        _ value: Double,
        minFractionDigits: Int,
        maxFractionDigits: Int
    ) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "USD"
        formatter.minimumFractionDigits = minFractionDigits
        formatter.maximumFractionDigits = maxFractionDigits
        return formatter.string(from: NSNumber(value: value)) ?? "$0"
    }
}

private struct InvestmentAccountPositionRow: View {
    let position: InvestmentAccountPosition

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 6) {
                Text(position.symbol)
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(.white)
                    .minimumScaleFactor(0.8)
                    .lineLimit(1)

                Text(position.institution.uppercased())
                    .font(.system(size: 12, weight: .semibold))
                    .tracking(0.4)
                    .foregroundColor(Color(hex: "#9CA3AF"))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.white.opacity(0.06))
                    )
            }

            Spacer()

            Text(formatCurrency(position.amount))
                .font(.system(size: 20, weight: .bold))
                .foregroundColor(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 16)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color.white.opacity(0.04))
        )
    }

    private func formatCurrency(_ value: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "USD"
        formatter.minimumFractionDigits = 0
        formatter.maximumFractionDigits = 0
        return formatter.string(from: NSNumber(value: value)) ?? "$0"
    }
}

#Preview {
    InvestmentView()
}
