//
//  DailyQuoteCard.swift
//  Flamora app
//

import SwiftUI

private let dailyQuotes: [String] = [
    "It's not about being rich\nIt's about being free.",
    "Financial freedom is available to those who learn about it and work for it.",
    "Do not save what is left after spending,\nbut spend what is left after saving."
]

struct DailyQuoteCard: View {
    @State private var quoteIndex: Int = 0

    var body: some View {
        ZStack(alignment: .topTrailing) {
            VStack(alignment: .leading, spacing: AppSpacing.md) {
                Text("DAILY QUOTE")
                    .font(.cardHeader)
                    .foregroundStyle(AppColors.textPrimary)
                    .tracking(AppTypography.Tracking.cardHeader)

                Text(dailyQuotes[quoteIndex])
                    .font(.quoteBody)
                    .foregroundStyle(AppColors.textPrimary)
                    .lineSpacing(4)
                    .fixedSize(horizontal: false, vertical: true)

                HStack(spacing: AppSpacing.sm) {
                    HStack(spacing: AppSpacing.sm) {
                        ForEach(0..<dailyQuotes.count, id: \.self) { i in
                            Capsule()
                                .fill(i == quoteIndex ? AppColors.textPrimary : AppColors.overlayWhiteForegroundSoft)
                                .frame(width: i == quoteIndex ? 20 : 6, height: 3)
                                .animation(.easeInOut(duration: 0.2), value: quoteIndex)
                        }
                    }
                    Text("\(quoteIndex + 1)/\(dailyQuotes.count)")
                        .font(.caption)
                        .foregroundStyle(AppColors.textSecondary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, AppSpacing.cardPadding)
            .padding(.vertical, AppSpacing.cardPadding)
            .background(
                GeometryReader { geo in
                    ZStack {
                        Image("AppBackground")
                            .resizable()
                            .scaledToFill()
                            .frame(width: geo.size.width, height: geo.size.height * 4.0)
                            .offset(y: -geo.size.height * 3.0)
                        LinearGradient(
                            colors: [AppColors.overlayBlackSoft, AppColors.overlayBlackMid],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    }
                }
                .allowsHitTesting(false)
            )
            .clipShape(RoundedRectangle(cornerRadius: AppRadius.lg))
            .overlay(
                RoundedRectangle(cornerRadius: AppRadius.lg)
                    .stroke(AppColors.dailyQuoteAccent.opacity(0.20), lineWidth: 0.75)
                    .allowsHitTesting(false)
            )

            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    quoteIndex = (quoteIndex + 1) % dailyQuotes.count
                }
            } label: {
                Image(systemName: "xmark")
                    .font(.smallLabel)
                    .foregroundStyle(AppColors.overlayWhiteOnPhoto)
                    .frame(width: 28, height: 28)
            }
            .buttonStyle(.plain)
            .padding(.top, AppSpacing.sm + 2)
            .padding(.trailing, AppSpacing.sm + 2)
        }
        .padding(.horizontal, AppSpacing.screenPadding)
    }
}

#Preview {
    ZStack {
        AppColors.backgroundPrimary.ignoresSafeArea()
        DailyQuoteCard()
            .padding(.top, AppSpacing.xl)
    }
}
