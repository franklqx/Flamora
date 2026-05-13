//
//  AppBackgroundView.swift
//  Meridian
//
//  全局纯黑背景 - 所有页面统一使用
//

import SwiftUI

struct AppBackgroundView: View {
    var body: some View {
        AppColors.backgroundPrimary
            .ignoresSafeArea()
    }
}

#Preview {
    AppBackgroundView()
}
