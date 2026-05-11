//
//  DetailSheetScaffold.swift
//  Flamora app
//
//  统一的二级详情页容器：light-shell 渐变背景 + 垂直滚动 + h1 标题 + 圆形关闭按钮。
//  用法：
//    DetailSheetScaffold(title: "Net Worth") { dismiss() } content: {
//        heroTrendCard
//        compositionCard
//    }
//

import SwiftUI

struct DetailSheetScaffold<Content: View>: View {
    let title: String
    let onDismiss: () -> Void
    var contentBottomPadding: CGFloat
    @ViewBuilder let content: () -> Content

    init(
        title: String,
        contentBottomPadding: CGFloat = AppSpacing.xl + AppSpacing.lg,
        onDismiss: @escaping () -> Void,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.title = title
        self.contentBottomPadding = contentBottomPadding
        self.onDismiss = onDismiss
        self.content = content
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
                    DetailSheetHeader(title: title, onDismiss: onDismiss)
                    content()
                }
                .padding(.horizontal, AppSpacing.screenPadding)
                .padding(.top, AppSpacing.screenPadding)
                .padding(.bottom, contentBottomPadding)
            }
        }
    }
}

private struct DetailSheetHeader: View {
    let title: String
    let onDismiss: () -> Void

    var body: some View {
        ZStack {
            Text(title.uppercased())
                .font(.cardHeader)
                .foregroundStyle(AppColors.inkPrimary)
                .tracking(AppTypography.Tracking.cardHeader)
                .lineLimit(1)

            HStack {
                Button(action: onDismiss) {
                    Image(systemName: "chevron.left")
                        .font(.h4)
                        .foregroundStyle(AppColors.inkPrimary)
                        .frame(width: 32, height: 32)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Back")
                .accessibilityHint("Dismiss \(title)")

                Spacer()
            }
        }
        .frame(height: 32)
        .padding(.top, AppSpacing.sm)
    }
}

#Preview("Default") {
    DetailSheetScaffold(title: "Net Worth", onDismiss: {}) {
        ForEach(0..<4) { _ in
            RoundedRectangle(cornerRadius: AppRadius.lg)
                .fill(
                    LinearGradient(
                        colors: [AppColors.glassCardBg, AppColors.glassCardBg2],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(height: 140)
                .overlay(
                    RoundedRectangle(cornerRadius: AppRadius.lg)
                        .stroke(AppColors.glassCardBorder, lineWidth: 1)
                )
        }
    }
}
