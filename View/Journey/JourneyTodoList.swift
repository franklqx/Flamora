//
//  JourneyTodoList.swift
//  Flamora app
//
//  GET STARTED checklist on Journey tab.
//  Shows 3 setup steps; sorts incomplete items first, completed items last.
//  Hidden entirely when all three are complete (caller's responsibility).
//

import SwiftUI

struct JourneyTodoList: View {
    let hasLinkedBank: Bool
    let hasFireGoal: Bool
    let budgetSetupCompleted: Bool
    let onConnectAccounts: () -> Void
    let onSetFireGoal: () -> Void
    let onCompleteBudgetSetup: () -> Void

    // MARK: - Item Model

    private struct Item: Identifiable {
        enum Kind { case connect, goal, budget }
        let kind: Kind
        var id: Kind { kind }
        let title: String
        let subtitle: String
        let isCompleted: Bool
    }

    private var sortedItems: [Item] {
        let all: [Item] = [
            Item(kind: .connect,
                 title: "Connect your accounts",
                 subtitle: "Link your bank to see real data",
                 isCompleted: hasLinkedBank),
            Item(kind: .goal,
                 title: "Set your FIRE goal",
                 subtitle: "Tell us when you want to retire",
                 isCompleted: hasFireGoal),
            Item(kind: .budget,
                 title: "Complete budget setup",
                 subtitle: "Get a personalized savings plan",
                 isCompleted: budgetSetupCompleted),
        ]
        return all.filter { !$0.isCompleted } + all.filter { $0.isCompleted }
    }

    // MARK: - Body

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.md) {
            Text("GET STARTED")
                .font(.cardHeader)
                .tracking(AppTypography.Tracking.cardHeader)
                .foregroundStyle(AppColors.textSecondary)

            VStack(spacing: 0) {
                ForEach(Array(sortedItems.enumerated()), id: \.element.id) { index, item in
                    row(item)

                    if index < sortedItems.count - 1 {
                        Rectangle()
                            .fill(AppColors.overlayWhiteForegroundSoft)
                            .frame(height: 0.5)
                    }
                }
            }
        }
        .padding(AppSpacing.cardPadding)
        .background(AppColors.backgroundCard)
        .clipShape(RoundedRectangle(cornerRadius: AppRadius.card))
    }

    // MARK: - Row

    @ViewBuilder
    private func row(_ item: Item) -> some View {
        Button { action(for: item) } label: {
            HStack(spacing: AppSpacing.md) {
                circleIndicator(completed: item.isCompleted)

                VStack(alignment: .leading, spacing: AppSpacing.xs) {
                    Text(item.title)
                        .font(.bodySemibold)
                        .foregroundStyle(item.isCompleted ? AppColors.textSecondary : AppColors.textPrimary)
                        .strikethrough(item.isCompleted, color: AppColors.textSecondary)
                    Text(item.subtitle)
                        .font(.footnoteRegular)
                        .foregroundStyle(AppColors.textSecondary)
                }

                Spacer()

                if !item.isCompleted {
                    Image(systemName: "chevron.right")
                        .font(.inlineLabel)
                        .foregroundStyle(AppColors.textTertiary)
                }
            }
            .padding(.vertical, AppSpacing.md)
        }
        .buttonStyle(.plain)
        .disabled(item.isCompleted)
    }

    @ViewBuilder
    private func circleIndicator(completed: Bool) -> some View {
        if completed {
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: AppColors.gradientFire,
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 22, height: 22)
                Image(systemName: "checkmark")
                    .font(.caption)
                    .fontWeight(.bold)
                    .foregroundStyle(AppColors.textInverse)
            }
        } else {
            Circle()
                .strokeBorder(AppColors.overlayWhiteAt25, lineWidth: 1.5)
                .frame(width: 22, height: 22)
        }
    }

    // MARK: - Actions

    private func action(for item: Item) {
        switch item.kind {
        case .connect: onConnectAccounts()
        case .goal:    onSetFireGoal()
        case .budget:  onCompleteBudgetSetup()
        }
    }
}
