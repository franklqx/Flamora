//
//  PlaidTrustBridgeView.swift
//  Flamora app
//
//  Trust bridge sheet shown once before the user's first Plaid connection.
//

import SwiftUI

struct PlaidTrustBridgeView: View {
    @Environment(\.dismiss) private var dismiss

    @State private var showPrivacy = false
    @State private var showTerms   = false

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [AppColors.shellBg1, AppColors.shellBg2],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            VStack(spacing: 0) {
                // Close button row
                HStack {
                    Spacer()
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.footnoteSemibold)
                            .foregroundColor(AppColors.inkPrimary)
                            .frame(width: 34, height: 34)
                            .background(AppColors.inkTrack)
                            .clipShape(Circle())
                    }
                }
                .padding(.horizontal, AppSpacing.cardPadding)
                .padding(.top, AppSpacing.lg)

                Spacer()

                // Icon
                ZStack {
                    Circle()
                        .fill(RadialGradient(
                            colors: [AppColors.gradientStart.opacity(0.18), Color.clear],
                            center: .center,
                            startRadius: 0,
                            endRadius: 72
                        ))
                        .frame(width: 144, height: 144)

                    Image(systemName: "lock.shield.fill")
                        .font(.currencyHero)
                        .foregroundStyle(LinearGradient(
                            colors: AppColors.gradientFire,
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ))
                        .dynamicTypeSize(...DynamicTypeSize.xLarge)
                }

                Spacer().frame(height: AppSpacing.lg)

                // Title + body
                VStack(spacing: AppSpacing.sm) {
                    Text(AppLinks.TrustBridge.title)
                        .font(.h1)
                        .foregroundStyle(AppColors.inkPrimary)
                        .multilineTextAlignment(.center)

                    Text(AppLinks.TrustBridge.body)
                        .font(.supportingText)
                        .foregroundColor(AppColors.inkSoft)
                        .multilineTextAlignment(.center)
                        .lineSpacing(4)
                        .padding(.horizontal, AppSpacing.lg)
                }

                Spacer().frame(height: AppSpacing.lg)

                // Trust badges
                VStack(spacing: AppSpacing.cardGap) {
                    ForEach(AppLinks.TrustBridge.badges, id: \.icon) { badge in
                        HStack(spacing: AppSpacing.md) {
                            Image(systemName: badge.icon)
                                .font(.bodyRegular)
                                .foregroundColor(AppColors.accentGreen)
                                .frame(width: 28)
                            Text(badge.label)
                                .font(.inlineLabel)
                                .foregroundStyle(AppColors.inkPrimary)
                            Spacer()
                            Image(systemName: "checkmark")
                                .font(.footnoteSemibold)
                                .foregroundColor(AppColors.accentGreen)
                        }
                        .padding(.horizontal, AppSpacing.cardPadding)
                        .padding(.vertical, AppSpacing.md)
                        .background(
                            LinearGradient(
                                colors: [AppColors.glassCardBg, AppColors.glassCardBg2],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .clipShape(RoundedRectangle(cornerRadius: AppRadius.md))
                        .overlay(
                            RoundedRectangle(cornerRadius: AppRadius.md)
                                .stroke(AppColors.glassCardBorder, lineWidth: 1)
                        )
                    }
                }
                .padding(.horizontal, AppSpacing.screenPadding)

                Spacer()

                // Legal links
                HStack(spacing: AppSpacing.sm) {
                    Button {
                        showPrivacy = true
                    } label: {
                        Text("Privacy Policy")
                            .font(.caption)
                            .foregroundColor(AppColors.inkMeta)
                            .underline()
                    }
                    Text("·")
                        .font(.caption)
                        .foregroundColor(AppColors.inkMeta)
                    Button {
                        showTerms = true
                    } label: {
                        Text("Terms of Service")
                            .font(.caption)
                            .foregroundColor(AppColors.inkMeta)
                            .underline()
                    }
                }
                .padding(.bottom, AppSpacing.md)

                // Primary CTA
                Button {
                    UserDefaults.standard.set(true, forKey: AppLinks.plaidTrustBridgeSeen)
                    dismiss()
                } label: {
                    Text(AppLinks.TrustBridge.buttonLabel)
                        .font(.statRowSemibold)
                        .foregroundColor(AppColors.textInverse)
                        .frame(maxWidth: .infinity)
                        .frame(height: 56)
                        .background(LinearGradient(
                            colors: AppColors.gradientFlamePill,
                            startPoint: .leading,
                            endPoint: .trailing
                        ))
                        .clipShape(RoundedRectangle(cornerRadius: AppRadius.button))
                }
                .padding(.horizontal, AppSpacing.screenPadding)
                .padding(.bottom, AppSpacing.xl)
            }
        }
        .sheet(isPresented: $showPrivacy) {
            SafariView(url: AppLinks.privacyPolicyURL)
                .ignoresSafeArea()
        }
        .sheet(isPresented: $showTerms) {
            SafariView(url: AppLinks.termsOfServiceURL)
                .ignoresSafeArea()
        }
    }
}

#Preview {
    PlaidTrustBridgeView()
        .environment(PlaidManager.shared)
}
