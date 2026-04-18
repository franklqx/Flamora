//
//  OB_MicroInsightCard.swift
//  Flamora app
//
//  Onboarding - Micro Insight Card with slide-up animation
//

import SwiftUI

struct OB_MicroInsightCard: View {
    var emoji: String = ""
    var systemImage: String? = nil
    let text: String
    var highlightText: String = ""

    @State private var isVisible = false

    var body: some View {
        HStack(spacing: AppSpacing.md) {
            Group {
                if let sys = systemImage {
                    Image(systemName: sys)
                        .font(.categoryRowIcon)
                        .foregroundStyle(LinearGradient(
                            colors: AppColors.gradientShellAccent,
                            startPoint: .leading,
                            endPoint: .trailing
                        ))
                } else {
                    Text(emoji)
                        .font(.h2)
                }
            }

            if highlightText.isEmpty || !text.contains(highlightText) {
                Text(text)
                    .font(.bodySmall)
                    .foregroundColor(AppColors.inkSoft)
            } else {
                buildHighlightedText()
            }
        }
        .padding(AppSpacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppColors.glassCardBg)
        .clipShape(RoundedRectangle(cornerRadius: AppRadius.md))
        .offset(y: isVisible ? 0 : AppSpacing.md + AppSpacing.xs)
        .opacity(isVisible ? 1 : 0)
        .onAppear {
            withAnimation(.easeOut(duration: 0.3)) {
                isVisible = true
            }
        }
    }

    @ViewBuilder
    private func buildHighlightedText() -> some View {
        let parts = text.components(separatedBy: highlightText)
        Text("\(parts[0])\(Text(highlightText).foregroundColor(AppColors.inkPrimary).bold())\(parts.dropFirst().joined(separator: highlightText))")
            .foregroundColor(AppColors.inkSoft)
            .font(.bodySmall)
    }
}

#Preview {
    OB_MicroInsightCard(systemImage: "lightbulb", text: "Your savings rate is above average.", highlightText: "above average")
        .background(AppBackgroundView())
}
