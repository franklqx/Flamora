//
//  BudgetEditChooserSheet.swift
//  Meridian
//
//  White bottom sheet that lets the user pick between adjusting the overall
//  plan or editing per-category budgets. Replaces the native ActionSheet so
//  the chrome matches the rest of the app's light shell.
//

import SwiftUI

struct BudgetEditChooserSheet: View {
    let onAdjustOverallPlan: () -> Void
    let onEditCategoryBudgets: () -> Void

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.lg) {
            HStack {
                Text("Edit Budget")
                    .font(.h3)
                    .foregroundStyle(AppColors.inkPrimary)
                Spacer()
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark")
                        .font(.bodySemibold)
                        .foregroundStyle(AppColors.inkPrimary)
                        .frame(width: 32, height: 32)
                        .background(AppColors.inkTrack)
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
            }

            VStack(spacing: AppSpacing.sm) {
                row(title: "Adjust overall plan") {
                    onAdjustOverallPlan()
                    dismiss()
                }
                row(title: "Edit category budgets") {
                    onEditCategoryBudgets()
                    dismiss()
                }
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, AppSpacing.screenPadding)
        .padding(.top, AppSpacing.lg)
        .padding(.bottom, AppSpacing.lg)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppColors.shellBg1)
        .presentationDetents([.height(260)])
        .presentationDragIndicator(.visible)
    }

    private func row(title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack {
                Text(title)
                    .font(.bodyRegular)
                    .foregroundStyle(AppColors.inkPrimary)
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.footnoteSemibold)
                    .foregroundStyle(AppColors.inkFaint)
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
