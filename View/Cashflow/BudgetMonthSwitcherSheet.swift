//
//  BudgetMonthSwitcherSheet.swift
//  Meridian
//
//  Lets the user pick a historical month to view in BudgetCard.
//  Only months with a saved monthly_budget record are listed.
//

import SwiftUI

struct BudgetMonthSwitcherSheet: View {
    let months: [Date]
    let selected: Date
    let onSelect: (Date) -> Void

    @Environment(\.dismiss) private var dismiss

    private static let labelFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "MMMM yyyy"
        return f
    }()

    private func isSelected(_ date: Date) -> Bool {
        Calendar.current.isDate(date, equalTo: selected, toGranularity: .month)
    }

    private func isCurrent(_ date: Date) -> Bool {
        Calendar.current.isDate(date, equalTo: Date(), toGranularity: .month)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.lg) {
            HStack {
                Text("Select month")
                    .font(.h3)
                    .foregroundStyle(AppColors.inkPrimary)
                Spacer()
                Button("Done") { dismiss() }
                    .font(.bodySemibold)
                    .foregroundStyle(AppColors.inkPrimary)
                    .accessibilityLabel("Done")
                    .accessibilityHint("Close month picker")
            }

            if months.isEmpty {
                HStack {
                    Spacer()
                    Text("No saved budgets yet.")
                        .font(.bodySmall)
                        .foregroundStyle(AppColors.inkSoft)
                    Spacer()
                }
                .padding(.vertical, AppSpacing.xl)
            } else {
                ScrollView {
                    VStack(spacing: AppSpacing.sm) {
                        ForEach(months, id: \.timeIntervalSince1970) { month in
                            row(for: month)
                        }
                    }
                }
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, AppSpacing.screenPadding)
        .padding(.top, AppSpacing.lg)
        .padding(.bottom, AppSpacing.lg)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppColors.shellBg1)
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }

    private func row(for month: Date) -> some View {
        Button {
            onSelect(month)
            dismiss()
        } label: {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(Self.labelFormatter.string(from: month))
                        .font(.bodyRegular)
                        .foregroundStyle(AppColors.inkPrimary)
                    if isCurrent(month) {
                        Text("Current")
                            .font(.caption)
                            .foregroundStyle(AppColors.inkSoft)
                    }
                }
                Spacer()
                if isSelected(month) {
                    Image(systemName: "checkmark")
                        .font(.bodySemibold)
                        .foregroundStyle(AppColors.inkPrimary)
                }
            }
            .padding(.horizontal, AppSpacing.cardPadding)
            .padding(.vertical, AppSpacing.md)
            .background(AppColors.glassCardBg)
            .clipShape(RoundedRectangle(cornerRadius: AppRadius.md))
            .overlay(
                RoundedRectangle(cornerRadius: AppRadius.md)
                    .stroke(AppColors.glassCardBorder, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}
