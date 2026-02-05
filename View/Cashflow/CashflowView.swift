//
//  CashflowView.swift
//  Flamora app
//
//  Saving / Cash Flow summary page
//

import SwiftUI

struct CashflowView: View {
    private let data = MockData.cashflowData
    @State private var selectedMonthIndex = 3
    @State private var currentSavings: Double = 0
    @State private var needsTotal: Double = MockData.cashflowData.spending.needs
    @State private var wantsTotal: Double = MockData.cashflowData.spending.wants
    @State private var totalSpend: Double = MockData.cashflowData.spending.total
    @State private var reviewTransactions: [Transaction] = MockData.cashflowData.toReview.transactions
    @State private var reviewCount: Int = MockData.cashflowData.toReview.count

    private let monthOptions = ["Nov 25", "Dec 25", "Jan 26", "Feb 26"]

    private var spendingForDisplay: Spending {
        Spending(
            total: totalSpend,
            needs: needsTotal,
            wants: wantsTotal,
            budgetLimit: data.spending.budgetLimit
        )
    }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 20) {
                    header

                    monthSelector

                    SavingsTargetCard(
                        currentAmount: $currentSavings,
                        targetAmount: data.savingsTarget.goal
                    )
                    .padding(.horizontal, AppSpacing.screenPadding)

                    sectionTitle("Monthly Income")
                        .padding(.horizontal, AppSpacing.screenPadding)

                    IncomeCard(income: data.income)
                        .padding(.horizontal, AppSpacing.screenPadding)

                    sectionTitle("Monthly Budget")
                        .padding(.horizontal, AppSpacing.screenPadding)

                    BudgetCard(spending: spendingForDisplay)
                        .padding(.horizontal, AppSpacing.screenPadding)

                    toReviewSection

                    Color.clear.frame(height: 120)
                }
                .padding(.top, 8)
                .padding(.bottom, 24)
            }
        }
    }
}

// MARK: - Header
private extension CashflowView {
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

                Circle()
                    .fill(Color(hex: "#2C2C2E"))
                    .frame(width: 36, height: 36)
                    .overlay(
                        Image(systemName: "person.fill")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.white)
                    )
                    .overlay(
                        Circle()
                            .stroke(Color(hex: "#222222"), lineWidth: 1)
                    )
            }
        }
        .padding(.horizontal, AppSpacing.screenPadding)
    }

    var monthSelector: some View {
        HStack(spacing: 10) {
            ForEach(monthOptions.indices, id: \.self) { index in
                let isSelected = index == selectedMonthIndex
                Text(monthOptions[index])
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(isSelected ? .white : Color(hex: "#6B7280"))
                    .padding(.vertical, 8)
                    .padding(.horizontal, 16)
                    .background(
                        Capsule()
                            .fill(isSelected ? Color(hex: "#121212") : Color.clear)
                            .overlay(
                                Capsule()
                                    .stroke(isSelected ? Color(hex: "#222222") : Color.clear, lineWidth: 1)
                            )
                    )
                    .onTapGesture {
                        selectedMonthIndex = index
                    }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, AppSpacing.screenPadding)
    }
}

// MARK: - Sections
private extension CashflowView {
    func sectionTitle(_ title: String) -> some View {
        Text(title)
            .font(.system(size: 18, weight: .bold))
            .foregroundColor(.white)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - To Review
private extension CashflowView {
    var toReviewSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("To Review")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(.white)

                Spacer()

                Text("\(reviewCount) Left")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(Color(hex: "#9CA3AF"))
                    .padding(.vertical, 4)
                    .padding(.horizontal, 10)
                    .background(Color(hex: "#1A1A1A"))
                    .clipShape(Capsule())
            }
            .padding(.horizontal, AppSpacing.screenPadding)

            ForEach(reviewTransactions, id: \.id) { transaction in
                TransactionCard(
                    transaction: transaction,
                    onNeeds: { classify(transaction, as: .needs) },
                    onWants: { classify(transaction, as: .wants) }
                )
                .padding(.horizontal, AppSpacing.screenPadding)
            }
        }
    }

    enum ReviewCategory {
        case needs
        case wants
    }

    func classify(_ transaction: Transaction, as category: ReviewCategory) {
        if let index = reviewTransactions.firstIndex(where: { $0.id == transaction.id }) {
            reviewTransactions.remove(at: index)
            reviewCount = max(reviewCount - 1, 0)

            totalSpend += transaction.amount
            switch category {
            case .needs:
                needsTotal += transaction.amount
            case .wants:
                wantsTotal += transaction.amount
            }
        }
    }
}

// MARK: - Transaction Card
private struct TransactionCard: View {
    let transaction: Transaction
    let onNeeds: () -> Void
    let onWants: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(transaction.merchant)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.white)

                    Text(formattedDate(transaction.date))
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(Color(hex: "#6B7280"))
                }

                Spacer()

                Text(formattedAmount(transaction.amount))
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(.white)
            }

            HStack(spacing: 12) {
                Button(action: onNeeds) {
                    HStack(spacing: 6) {
                        Image(systemName: "house.fill")
                            .font(.system(size: 12, weight: .bold))
                        Text("Needs")
                            .font(.system(size: 12, weight: .bold))
                    }
                    .foregroundColor(.white)
                    .padding(.vertical, 8)
                    .padding(.horizontal, 16)
                    .background(Color(hex: "#93C5FD").opacity(0.2))
                    .clipShape(Capsule())
                }

                Button(action: onWants) {
                    HStack(spacing: 6) {
                        Image(systemName: "bag.fill")
                            .font(.system(size: 12, weight: .bold))
                        Text("Wants")
                            .font(.system(size: 12, weight: .bold))
                    }
                    .foregroundColor(.white)
                    .padding(.vertical, 8)
                    .padding(.horizontal, 16)
                    .background(Color(hex: "#C4B5FD").opacity(0.2))
                    .clipShape(Capsule())
                }
            }
        }
        .padding(20)
        .background(Color(hex: "#121212"))
        .cornerRadius(20)
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(Color(hex: "#222222"), lineWidth: 1)
        )
    }

    private func formattedDate(_ raw: String) -> String {
        raw.replacingOccurrences(of: "-", with: " ")
    }

    private func formattedAmount(_ amount: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "USD"
        formatter.maximumFractionDigits = 2
        formatter.minimumFractionDigits = 2
        return formatter.string(from: NSNumber(value: amount)) ?? "$0.00"
    }
}

#Preview {
    CashflowView()
}
