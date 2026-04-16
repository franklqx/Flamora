//
//  JourneyTodoList.swift
//  Flamora app
//
//  Archived with `JourneyView` (OLDDESIGN). Placeholder checklist used by the old shell; not in app target.
//

import SwiftUI

struct JourneyTodoList: View {
    let hasLinkedBank: Bool
    let hasFireGoal: Bool
    let budgetSetupCompleted: Bool
    var onConnectAccounts: (() -> Void)?
    var onSetFireGoal: (() -> Void)?
    var onCompleteBudgetSetup: (() -> Void)?

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.md) {
            Text("Your checklist")
                .font(.cardHeader)
                .foregroundStyle(AppColors.textSecondary)
                .tracking(AppTypography.Tracking.cardHeader)

            todoRow(done: hasFireGoal, title: "Set FIRE goal", action: onSetFireGoal)
            todoRow(done: hasLinkedBank, title: "Connect accounts", action: onConnectAccounts)
            todoRow(done: budgetSetupCompleted, title: "Finish budget setup", action: onCompleteBudgetSetup)
        }
        .padding(AppSpacing.cardPadding)
        .background(AppColors.surfaceElevated)
        .clipShape(RoundedRectangle(cornerRadius: AppRadius.card))
        .overlay(
            RoundedRectangle(cornerRadius: AppRadius.card)
                .stroke(AppColors.overlayWhiteStroke, lineWidth: 1)
        )
        .padding(.horizontal, AppSpacing.screenPadding)
    }

    @ViewBuilder
    private func todoRow(done: Bool, title: String, action: (() -> Void)?) -> some View {
        Button {
            action?()
        } label: {
            HStack(spacing: AppSpacing.md) {
                Image(systemName: done ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(done ? AppColors.accentGreen : AppColors.textSecondary)
                Text(title)
                    .font(.bodySmall)
                    .foregroundStyle(AppColors.textPrimary)
                Spacer(minLength: 0)
            }
        }
        .buttonStyle(.plain)
        .disabled(done)
    }
}
