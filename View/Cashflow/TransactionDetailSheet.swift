//
//  TransactionDetailSheet.swift
//  Meridian
//
//  Transaction detail sheet — light-shell styling.
//  Shows info, allows subcategory editing; subcategory drives Needs/Wants classification.
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

    init(transaction: Transaction, linkedAccounts: [Account] = [], onSave: @escaping @MainActor (Transaction) async throws -> Void) {
        self.transaction = transaction
        self.linkedAccounts = linkedAccounts
        self.onSave = onSave
        _selectedSubcategoryKey = State(
            initialValue: TransactionCategoryCatalog.canonicalSubcategory(fromStored: transaction.subcategory)
        )
    }

    private var cardBackground: LinearGradient {
        LinearGradient(
            colors: [AppColors.glassCardBg, AppColors.glassCardBg2],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [AppColors.shellBg1, AppColors.shellBg2],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: AppSpacing.cardGap) {
                    headerCard
                    currentCategoryCard
                    categoryPickerCard
                    doneButton
                }
                .padding(.horizontal, AppSpacing.screenPadding)
                .padding(.top, AppSpacing.screenPadding)
                .padding(.bottom, AppSpacing.xl)
            }
        }
        .alert("Couldn't save changes", isPresented: Binding(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )) {
            Button("OK", role: .cancel) { errorMessage = nil }
        } message: {
            Text(errorMessage ?? "Please try again.")
        }
    }

    // MARK: - Header card (merchant + amount + account)

    private var headerCard: some View {
        VStack(alignment: .leading, spacing: AppSpacing.md) {
            HStack(spacing: AppSpacing.md) {
                ZStack {
                    Circle()
                        .fill(effectiveTint.opacity(0.14))
                        .frame(width: 48, height: 48)
                    Image(systemName: currentIcon)
                        .font(.h4)
                        .foregroundStyle(effectiveTint)
                }

                VStack(alignment: .leading, spacing: 3) {
                    Text(transaction.merchant)
                        .font(.h3)
                        .foregroundStyle(AppColors.inkPrimary)
                        .lineLimit(2)
                    Text(dateTimeLabel)
                        .font(.caption)
                        .foregroundStyle(AppColors.inkSoft)
                }

                Spacer()

                Button {
                    dismiss()
                } label: {
                    ZStack {
                        Circle()
                            .fill(AppColors.inkTrack)
                            .frame(width: 32, height: 32)
                        Image(systemName: "xmark")
                            .font(.footnoteSemibold)
                            .foregroundStyle(AppColors.inkPrimary)
                    }
                }
                .buttonStyle(.plain)
            }

            Text(formattedAmount(transaction.amount))
                .font(.currencyHero)
                .foregroundStyle(AppColors.inkPrimary)
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.5)
                .dynamicTypeSize(...DynamicTypeSize.xLarge)

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
                                    Circle().fill(AppColors.inkTrack)
                                        .frame(width: 20, height: 20)
                                }
                            }
                        } else {
                            Circle().fill(AppColors.inkTrack)
                                .frame(width: 20, height: 20)
                        }
                    }
                    Text(acct.institution)
                        .font(.caption)
                        .foregroundStyle(AppColors.inkSoft)
                    Text("·  \(acct.accountType.displayLabel)")
                        .font(.caption)
                        .foregroundStyle(AppColors.inkFaint)
                }
            }
        }
        .padding(AppSpacing.cardPadding)
        .background(cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: AppRadius.lg))
        .overlay(
            RoundedRectangle(cornerRadius: AppRadius.lg)
                .stroke(AppColors.glassCardBorder, lineWidth: 1)
        )
    }

    // MARK: - Current category card

    private var currentCategoryCard: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            Text("CURRENT CATEGORY")
                .font(.cardHeader)
                .foregroundStyle(AppColors.inkPrimary)
                .tracking(AppTypography.Tracking.cardHeader)

            currentCategoryBadge
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(AppSpacing.cardPadding)
        .background(cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: AppRadius.lg))
        .overlay(
            RoundedRectangle(cornerRadius: AppRadius.lg)
                .stroke(AppColors.glassCardBorder, lineWidth: 1)
        )
    }

    @ViewBuilder
    private var currentCategoryBadge: some View {
        let label = TransactionCategoryCatalog.displayName(forStoredSubcategory: effectiveStoredSubcategory) ?? "Uncategorized"
        let color = effectiveTint

        Text(label)
            .font(.footnoteSemibold)
            .foregroundStyle(color)
            .padding(.vertical, 6)
            .padding(.horizontal, 12)
            .background(color.opacity(0.14))
            .clipShape(Capsule())
    }

    // MARK: - Category picker card

    private var categoryPickerCard: some View {
        VStack(alignment: .leading, spacing: AppSpacing.lg) {
            Text("CATEGORY")
                .font(.cardHeader)
                .foregroundStyle(AppColors.inkPrimary)
                .tracking(AppTypography.Tracking.cardHeader)

            categoryGroup(label: "NEEDS", color: AppColors.allocIndigo, categories: needsCategories)
            categoryGroup(label: "WANTS", color: AppColors.budgetWantsPurple, categories: wantsCategories)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(AppSpacing.cardPadding)
        .background(cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: AppRadius.lg))
        .overlay(
            RoundedRectangle(cornerRadius: AppRadius.lg)
                .stroke(AppColors.glassCardBorder, lineWidth: 1)
        )
    }

    @ViewBuilder
    private func categoryGroup(label: String, color: Color, categories: [TransactionCategory]) -> some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            Text(label)
                .font(.cardRowMeta)
                .foregroundStyle(color)
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
        Button {
            selectedSubcategoryKey = cat.id
        } label: {
            HStack(spacing: 6) {
                Image(systemName: cat.icon)
                    .font(.caption)
                    .foregroundStyle(isSelected ? color : AppColors.inkSoft)
                Text(cat.name)
                    .font(.footnoteRegular)
                    .foregroundStyle(isSelected ? AppColors.inkPrimary : AppColors.inkSoft)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, AppSpacing.sm)
            .padding(.horizontal, AppSpacing.md)
            .background(
                RoundedRectangle(cornerRadius: AppRadius.md)
                    .fill(isSelected ? color.opacity(0.16) : AppColors.ctaWhite.opacity(0.55))
            )
            .overlay(
                RoundedRectangle(cornerRadius: AppRadius.md)
                    .stroke(isSelected ? color : AppColors.inkBorder, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Done button

    private var doneButton: some View {
        Button {
            Task { await save() }
        } label: {
            HStack(spacing: AppSpacing.sm) {
                if isSaving {
                    ProgressView().tint(AppColors.ctaWhite)
                }
                Text("Done")
                    .font(.sheetPrimaryButton)
                    .foregroundStyle(AppColors.ctaWhite)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 56)
            .background(AppColors.inkPrimary)
            .clipShape(RoundedRectangle(cornerRadius: AppRadius.button))
        }
        .disabled(isSaving)
        .buttonStyle(.plain)
        .padding(.top, AppSpacing.sm)
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

    private var effectiveTint: Color {
        switch effectiveCategory {
        case "needs": return AppColors.budgetNeedsBlue
        case "wants": return AppColors.budgetWantsPurple
        default: return AppColors.inkSoft
        }
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
