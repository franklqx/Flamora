//
//  InvestmentView.swift
//  Flamora app
//
//  Investment overview page
//

import SwiftUI

struct InvestmentView: View {
    private let data = MockData.investmentData

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 20) {
                    header

                    PortfolioCard(portfolio: data.portfolio)
                        .padding(.horizontal, AppSpacing.screenPadding)

                    sectionHeader(title: "Accounts", actionTitle: "View all")
                        .padding(.horizontal, AppSpacing.screenPadding)

                    AccountsCard(accounts: data.accounts)
                        .padding(.horizontal, AppSpacing.screenPadding)

                    sectionHeader(title: "Asset allocation")
                        .padding(.horizontal, AppSpacing.screenPadding)

                    AssetAllocationCard(allocation: data.allocation)
                        .padding(.horizontal, AppSpacing.screenPadding)

                    Color.clear.frame(height: 120)
                }
                .padding(.top, 8)
                .padding(.bottom, 24)
            }
        }
    }
}

// MARK: - Header
private extension InvestmentView {
    var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 0) {
                Text("Welcome back,")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(Color(hex: "#7C7C7C"))

                Text("Alex Sterling")
                    .font(.system(size: 30, weight: .bold))
                    .foregroundColor(.white)
            }

            Spacer()

            HStack(spacing: 10) {
                Button(action: {}) {
                    Circle()
                        .fill(Color(hex: "#121212"))
                        .frame(width: 36, height: 36)
                        .overlay(
                            Image(systemName: "eye")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(.white)
                        )
                        .overlay(
                            Circle()
                                .stroke(Color(hex: "#222222"), lineWidth: 1)
                        )
                }
                .buttonStyle(.plain)

                Button(action: {}) {
                    Circle()
                        .fill(Color(hex: "#121212"))
                        .frame(width: 36, height: 36)
                        .overlay(
                            Image(systemName: "gearshape.fill")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(.white)
                        )
                        .overlay(
                            Circle()
                                .stroke(Color(hex: "#222222"), lineWidth: 1)
                        )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, AppSpacing.screenPadding)
    }

    func sectionHeader(title: String, actionTitle: String? = nil) -> some View {
        HStack {
            Text(title)
                .font(.system(size: 18, weight: .bold))
                .foregroundColor(.white)

            Spacer()

            if let actionTitle {
                Text(actionTitle)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(Color(hex: "#A78BFA"))
            }
        }
    }
}

#Preview {
    InvestmentView()
}
