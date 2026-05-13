//
//  HomeExpandedOverlayView.swift
//  Meridian
//
//  Home 下拉展开专用页面（结构与 CashflowExpandedOverlayView 对齐）
//

import SwiftUI

struct HomeExpandedOverlayView: View {
    @Binding var displayState: SimulatorDisplayState

    let topPadding: CGFloat
    let onClose: () -> Void

    var body: some View {
        SimulatorView(
            displayState: $displayState,
            bottomPadding: 0,
            isFireOn: true,
            onFireToggle: onClose,
            contentTopPadding: topPadding,
            fillsBackground: false
        )
        .ignoresSafeArea(.container, edges: .bottom)
    }
}

