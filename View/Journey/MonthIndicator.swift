//
//  MonthIndicator.swift
//  Flamora app
//
//  月份打卡指示器组件
//

import SwiftUI

struct MonthIndicator: View {
    let month: String
    
    enum Status {
        case success
        case failed
        case pending
    }
    let status: Status
    
    var body: some View {
        VStack(spacing: 8) {
            ZStack {
                Circle()
                    .fill(backgroundColor)
                    .frame(width: 48, height: 48)
                icon
            }
            Text(month)
                .font(.system(size: 13))
                .foregroundColor(status == .pending ? .white : Color(hex: "#7C7C7C"))
        }
    }
    
    private var backgroundColor: Color {
        switch status {
        case .success: return .white
        case .failed: return Color(hex: "#3C3C3E")
        case .pending: return Color(hex: "#2C2C2E")
        }
    }
    
    private var icon: some View {
        Group {
            switch status {
            case .success:
                Image(systemName: "checkmark")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.black)
            case .failed:
                Image(systemName: "xmark")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(Color(hex: "#7C7C7C"))
            case .pending:
                Image(systemName: "ellipsis")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(Color(hex: "#5C5C5C"))
            }
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
    .background(Color.black)
}
