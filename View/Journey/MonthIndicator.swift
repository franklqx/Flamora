//
//  MonthIndicator.swift
//  Flamora app
//
//  月份打卡指示器组件
//

import SwiftUI

struct MonthIndicator: View {
    let month: String
    let status: Status

    enum Status {
        case success
        case failed
        case pending
    }

    var body: some View {
        VStack(spacing: 8) {
            ZStack {
                Circle()
                    .fill(circleBackground)
                    .frame(width: 48, height: 48)
                    .overlay(
                        Circle()
                            .stroke(circleBorder, lineWidth: 0.75)
                    )

                icon
            }

            Text(month)
                .font(.footnoteRegular)
                .foregroundColor(labelColor)
        }
    }

    private var circleBackground: Color {
        switch status {
        case .success: return AppColors.textPrimary
        case .failed:  return AppColors.surfaceElevated
        case .pending: return AppColors.surfaceInput
        }
    }

    private var circleBorder: Color {
        switch status {
        case .success: return Color.clear
        case .failed:  return AppColors.surfaceBorder
        case .pending: return AppColors.surfaceBorder
        }
    }

    private var icon: some View {
        Group {
            switch status {
            case .success:
                Image(systemName: "checkmark")
                    .font(.h4)
                    .foregroundColor(AppColors.textInverse)
            case .failed:
                Image(systemName: "xmark")
                    .font(.h4)
                    .foregroundColor(AppColors.textTertiary)
            case .pending:
                Image(systemName: "ellipsis")
                    .font(.h4)
                    .foregroundColor(AppColors.textMuted)
            }
        }
    }

    private var labelColor: Color {
        switch status {
        case .pending: return AppColors.textPrimary
        default:       return AppColors.textSecondary
        }
    }
}

#Preview {
    HStack(spacing: 20) {
        MonthIndicator(month: "Aug", status: .success)
        MonthIndicator(month: "Sep", status: .success)
        MonthIndicator(month: "Oct", status: .failed)
        MonthIndicator(month: "Nov", status: .pending)
    }
    .padding()
    .background(AppColors.backgroundPrimary)
}
