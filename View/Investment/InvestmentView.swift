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
            Color.clear

            GeometryReader { proxy in
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 20) {
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

                    }
                    .frame(minHeight: proxy.size.height, alignment: .top)
                    .padding(.bottom, AppSpacing.tabBarReserve)
                }
            }
        }
    }
}

// MARK: - Header
private extension InvestmentView {
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
