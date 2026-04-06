//
//  ErrorBanner.swift
//  Flamora app
//
//  Minimal reusable error banner for data-load and action failures.
//  Usage: ErrorBanner(message: "...", onRetry: { ... })
//

import SwiftUI

struct ErrorBanner: View {
    let message: String
    var onRetry: (() -> Void)?

    var body: some View {
        HStack(spacing: AppSpacing.sm) {
            Image(systemName: "exclamationmark.circle")
                .font(.bodySmall)
                .foregroundStyle(AppColors.textPrimary)
            Text(message)
                .font(.bodySmall)
                .foregroundStyle(AppColors.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
            if let retry = onRetry {
                Button(action: retry) {
                    Text("Retry")
                        .font(.bodySmallSemibold)
                        .foregroundStyle(AppColors.textPrimary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(AppSpacing.md)
        .background(AppColors.overlayBlackMid)
        .clipShape(RoundedRectangle(cornerRadius: AppRadius.card))
        .padding(.horizontal, AppSpacing.screenPadding)
    }
}
