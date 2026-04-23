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
        HStack(alignment: .firstTextBaseline) {
            Text(title)
                .font(.h1)
                .foregroundStyle(AppColors.inkPrimary)
                .tracking(-0.5)
                .lineLimit(1)
                .minimumScaleFactor(0.6)

            Spacer(minLength: AppSpacing.sm)

            Button(action: onDismiss) {
                ZStack {
                    Circle()
                        .fill(AppColors.inkTrack)
                        .frame(width: 34, height: 34)
                    Image(systemName: "xmark")
                        .font(.footnoteSemibold)
                        .foregroundStyle(AppColors.inkPrimary)
                }
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Close")
        }
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
