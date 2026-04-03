//
//  TransactionDetailSheet.swift
//  Flamora app
//
//  Transaction detail sheet — shows info, allows subcategory editing and notes.
//  Subcategory drives Needs/Wants classification.
//

import SwiftUI

struct TransactionDetailSheet: View {
    let transaction: Transaction
    /// 来自 `get-net-worth-summary` 等真实账户列表，用于匹配 `transaction.accountId`。
    var linkedAccounts: [Account] = []
    let onSave: @MainActor (Transaction) async throws -> Void

    @State private var selectedSubcategoryKey: String?
    @State private var isSaving = false
    @State private var errorMessage: String?
    @Environment(\.dismiss) private var dismiss

    private var needsCategories: [TransactionCategory] { TransactionCategoryCatalog.needsCategories }
    private var wantsCategories: [TransactionCategory] { TransactionCategoryCatalog.wantsCategories }
    private var initialSubcategoryKey: String? {
        TransactionCategoryCatalog.canonicalSubcategory(fromStored: transaction.subcategory)
    }

    init(transaction: Transaction, linkedAccounts: [Account] = [], onSave: @escaping @MainActor (Transaction) async throws -> Void) {
        self.transaction = transaction
        self.linkedAccounts = linkedAccounts
        self.onSave = onSave
        _selectedSubcategoryKey = State(
            initialValue: TransactionCategoryCatalog.canonicalSubcategory(fromStored: transaction.subcategory)
        )
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 0) {

                // MARK: Header
                HStack(spacing: AppSpacing.md) {
                    ZStack {
                        Circle()
                            .fill(AppColors.surfaceElevated)
                            .frame(width: 48, height: 48)
                            .overlay(Circle().stroke(AppColors.surfaceBorder, lineWidth: 0.75))
                        Image(systemName: currentIcon)
                            .font(.h4)
                            .foregroundColor(AppColors.textSecondary)
                    }

                    VStack(alignment: .leading, spacing: 3) {
                        Text(transaction.merchant)
                            .font(.h3)
                            .foregroundStyle(AppColors.textPrimary)
                        Text(dateTimeLabel)
                            .font(.inlineLabel)
                            .foregroundColor(AppColors.textTertiary)
                    }

                    Spacer()

                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark")
                            .font(.bodySmall)
                            .foregroundColor(AppColors.textSecondary)
                            .frame(width: 32, height: 32)
                            .background(AppColors.surfaceElevated)
                            .clipShape(Circle())
                            .overlay(Circle().stroke(AppColors.surfaceBorder, lineWidth: 0.75))
                    }
                    .buttonStyle(.plain)
                }
                .padding(.top, AppSpacing.lg)
                .padding(.horizontal, AppSpacing.cardPadding)

                // MARK: Amount
                Text(formattedAmount(transaction.amount))
                    .font(.h1)
                    .foregroundStyle(AppColors.textPrimary)
                    .padding(.top, AppSpacing.sm)
                    .padding(.horizontal, AppSpacing.cardPadding)

                // MARK: Account
                if let acct = transactionAccount {
                    HStack(spacing: AppSpacing.sm) {
                        Group {
                            if let urlString = acct.logoUrl, let url = URL(string: urlString) {
                                AsyncImage(url: url) { phase in
                                    switch phase {
                                    case .success(let image):
                                        image.resizable().scaledToFill()
                                            .frame(width: 20, height: 20)
                                            .clipShape(Circle())
                                    default:
                                        Circle().fill(AppColors.surfaceElevated)
                                            .frame(width: 20, height: 20)
                                    }
                                }
                            } else {
                                Circle().fill(AppColors.surfaceElevated)
                                    .frame(width: 20, height: 20)
                            }
                        }
                        Text(acct.institution)
                            .font(.inlineLabel)
                            .foregroundColor(AppColors.textSecondary)
                        Text("·  \(acct.accountType.displayLabel)")
                            .font(.inlineLabel)
                            .foregroundColor(AppColors.textTertiary)
                    }
                    .padding(.top, AppSpacing.sm)
                    .padding(.horizontal, AppSpacing.cardPadding)
                }

                VStack(alignment: .leading, spacing: AppSpacing.sm) {
                    Text("CURRENT CATEGORY")
                        .font(.cardHeader)
                        .foregroundColor(AppColors.textTertiary)
                        .tracking(0.8)

                    currentCategoryBadge
                }
                .padding(.top, AppSpacing.lg)
                .padding(.horizontal, AppSpacing.cardPadding)

                // MARK: Category section
                VStack(alignment: .leading, spacing: AppSpacing.md) {
                    Text("CATEGORY")
                        .font(.cardHeader)
                        .foregroundColor(AppColors.textTertiary)
                        .tracking(0.8)

                    // Needs group
                    categoryGroup(label: "NEEDS", color: AppColors.chartBlue, categories: needsCategories)

                    // Wants group
                    categoryGroup(label: "WANTS", color: AppColors.chartAmber, categories: wantsCategories)
                }
                .padding(.top, AppSpacing.lg)
                .padding(.horizontal, AppSpacing.cardPadding)

                // MARK: Done button
                Button(action: {
                    Task { await save() }
                }) {
                    HStack(spacing: AppSpacing.sm) {
                        if isSaving {
                            ProgressView()
                                .tint(AppColors.textInverse)
                        }
                        Text(primaryButtonTitle)
                            .font(.sheetPrimaryButton)
                            .foregroundStyle(AppColors.textInverse)
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 56)
                    .background(AppColors.textPrimary)
                    .clipShape(RoundedRectangle(cornerRadius: AppRadius.button))
                }
                .disabled(isSaving)
                .buttonStyle(.plain)
                .padding(.top, AppSpacing.xl)
                .padding(.horizontal, AppSpacing.cardPadding)
                .padding(.bottom, AppSpacing.xl)
            }
        }
        .background(AppColors.backgroundPrimary)
        .alert("Couldn’t save changes", isPresented: Binding(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )) {
            Button("OK", role: .cancel) { errorMessage = nil }
        } message: {
            Text(errorMessage ?? "Please try again.")
        }
    }

    // MARK: - Category Group

    @ViewBuilder
    private func categoryGroup(label: String, color: Color, categories: [TransactionCategory]) -> some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            Text(label)
                .font(.cardRowMeta)
                .foregroundColor(color.opacity(0.8))
                .tracking(0.6)

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: AppSpacing.sm) {
                ForEach(categories) { cat in
                    categoryChip(cat, color: color)
                }
            }
        }
    }

    @ViewBuilder
    private func categoryChip(_ cat: TransactionCategory, color: Color) -> some View {
        let isSelected = selectedSubcategoryKey == cat.id
        Button(action: {
            selectedSubcategoryKey = cat.id
        }) {
            HStack(spacing: 6) {
                Image(systemName: cat.icon)
                    .font(.caption)
                    .foregroundColor(isSelected ? AppColors.textPrimary : AppColors.textSecondary)
                Text(cat.name)
                    .font(.bodySmall)
                    .foregroundColor(isSelected ? AppColors.textPrimary : AppColors.textSecondary)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, AppSpacing.sm)
            .padding(.horizontal, AppSpacing.md)
            .background(isSelected ? color.opacity(0.35) : Color.clear)
            .clipShape(RoundedRectangle(cornerRadius: AppRadius.md))
            .overlay(
                RoundedRectangle(cornerRadius: AppRadius.md)
                    .stroke(isSelected ? color : AppColors.surfaceBorder, lineWidth: 0.75)
            )
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private var currentCategoryBadge: some View {
        let label = TransactionCategoryCatalog.displayName(forStoredSubcategory: effectiveStoredSubcategory) ?? "Uncategorized"
        let color = effectiveCategory == "needs" ? AppColors.chartBlue : (effectiveCategory == "wants" ? AppColors.chartGold : AppColors.textTertiary)

        Text(label)
            .font(.miniLabel)
            .foregroundColor(color)
            .padding(.vertical, 6)
            .padding(.horizontal, 10)
            .background(color.opacity(0.16))
            .clipShape(Capsule())
            .overlay(
                Capsule()
                    .stroke(color.opacity(0.35), lineWidth: 0.75)
            )
    }

    // MARK: - Helpers

    private var transactionAccount: Account? {
        guard let accountId = transaction.accountId else { return nil }
        return linkedAccounts.first { $0.id == accountId }
    }

    private var currentIcon: String {
        if let selectedSubcategoryKey,
           let cat = TransactionCategoryCatalog.all.first(where: { $0.id == selectedSubcategoryKey }) {
            return cat.icon
        }
        if let icon = TransactionCategoryCatalog.icon(forStoredSubcategory: transaction.subcategory) {
            return icon
        }
        return merchantIcon(for: transaction.merchant)
    }

    private var dateTimeLabel: String {
        let datePart = formattedDate(transaction.date)
        if let t = transaction.time, !t.isEmpty {
            return "\(datePart)  ·  \(t)"
        }
        return datePart
    }

    private var effectiveStoredSubcategory: String? {
        selectedSubcategoryKey ?? transaction.subcategory
    }

    private var effectiveCategory: String? {
        if let selectedSubcategoryKey {
            return TransactionCategoryCatalog.parent(forStoredSubcategory: selectedSubcategoryKey)
        }
        return transaction.category
    }

    private var primaryButtonTitle: String {
        "Done"
    }

    private var hasChanges: Bool {
        effectiveStoredSubcategory != transaction.subcategory || effectiveCategory != transaction.category
    }

    @MainActor
    private func save() async {
        guard !isSaving else { return }
        guard hasChanges else {
            dismiss()
            return
        }

        isSaving = true
        var updated = transaction
        updated.subcategory = effectiveStoredSubcategory
        updated.category = effectiveCategory
        updated.pendingClassification = effectiveStoredSubcategory != nil ? false : transaction.pendingClassification

        do {
            try await onSave(updated)
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
        isSaving = false
    }

    private func merchantIcon(for merchant: String) -> String {
        let m = merchant.lowercased()
        if m.contains("rent") || m.contains("mortgage")                      { return "house.fill" }
        if m.contains("whole foods") || m.contains("grocery") || m.contains("market") { return "cart.fill" }
        if m.contains("netflix") || m.contains("spotify") || m.contains("apple music") || m.contains("hulu") { return "play.tv.fill" }
        if m.contains("gas") || m.contains("shell") || m.contains("chevron") { return "fuelpump.fill" }
        if m.contains("starbucks") || m.contains("coffee") || m.contains("cafe") { return "cup.and.saucer.fill" }
        if m.contains("uber") || m.contains("lyft")                          { return "car.fill" }
        if m.contains("amazon") || m.contains("target") || m.contains("walmart") { return "bag.fill" }
        if m.contains("eats") || m.contains("restaurant") || m.contains("dining") { return "fork.knife" }
        return "creditcard.fill"
    }

    private func formattedDate(_ raw: String) -> String {
        let parts = raw.split(separator: "-")
        let months = ["Jan","Feb","Mar","Apr","May","Jun","Jul","Aug","Sep","Oct","Nov","Dec"]
        if parts.count == 2, let m = Int(parts[0]), let d = Int(parts[1]), m >= 1, m <= 12 {
            return "\(months[m - 1]) \(d)"
        }
        if parts.count == 3, let m = Int(parts[1]), let d = Int(parts[2]), m >= 1, m <= 12 {
            return "\(months[m - 1]) \(d)"
        }
        return raw
    }

    private func formattedAmount(_ amount: Double) -> String {
        let fmt = NumberFormatter()
        fmt.numberStyle = .currency
        fmt.currencyCode = "USD"
        fmt.maximumFractionDigits = 2
        fmt.minimumFractionDigits = 2
        return fmt.string(from: NSNumber(value: -amount)) ?? "$0.00"
    }
}
