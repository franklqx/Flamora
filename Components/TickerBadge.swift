//
//  TickerBadge.swift
//  Meridian
//
//  Placeholder badge for holdings rows when no real security logo exists
//  (Plaid investments endpoints don't return security logos). Pill-shaped so
//  4–5 letter tickers (AAPL, GOOGL, AMZN, VXUS) fit without crowding the edges.
//

import SwiftUI

struct TickerBadge: View {
    let symbol: String
    var tint: Color = AppColors.inkTrack
    /// Foreground text color. Defaults to inkPrimary; pass a brand tint when the
    /// badge sits on an allocation row whose dot color we want to echo.
    var textColor: Color = AppColors.inkPrimary
    var size: CGSize = CGSize(width: 56, height: 40)

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: AppRadius.md)
                .fill(tint)
                .frame(width: size.width, height: size.height)
            Text(symbol)
                .font(.footnoteBold)
                .foregroundStyle(textColor)
                .minimumScaleFactor(0.5)
                .lineLimit(1)
                .padding(.horizontal, AppSpacing.sm)
        }
        .frame(width: size.width, height: size.height)
    }
}
