//
//  SavingsTargetCard.swift
//  Flamora app
//
//  Savings target summary card
//

import SwiftUI

struct SavingsTargetCard: View {
    @Binding var currentAmount: Double
    var targetAmount: Double
    var onAdd: () -> Void
    var onCardTap: (() -> Void)? = nil

    private var progress: Double {
        guard targetAmount > 0 else { return 0 }
        return min(max(currentAmount / targetAmount, 0), 1)
    }

    var body: some View {
        ZStack(alignment: .topTrailing) {
            VStack(spacing: 0) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Savings Target")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(Color(hex: "#7C7C7C"))

                        if currentAmount > 0 {
                            HStack(alignment: .firstTextBaseline, spacing: 6) {
                                Text(formatCurrency(currentAmount))
                                    .font(.system(size: 28, weight: .bold))
                                    .foregroundColor(.white)

                                Text("/ \(formatCurrency(targetAmount))")
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundColor(Color(hex: "#6B7280"))
                            }
                        } else {
                            Text(formatCurrency(targetAmount))
                                .font(.system(size: 28, weight: .bold))
                                .foregroundColor(.white)
                        }
                    }

                    Spacer()
                }

                if currentAmount > 0 {
                    VStack(spacing: 10) {
                        HStack {
                            Text("\(Int(progress * 100))% Achieved")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundColor(Color(hex: "#6B7280"))

                            Spacer()

                            Text("Fire Goal")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundColor(Color(hex: "#6B7280"))
                        }
                        .padding(.top, 16)

                        progressBar
                    }
                    .transition(.opacity.combined(with: .move(edge: .top)))
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
            .onTapGesture {
                onCardTap?()
            }

            if currentAmount <= 0 {
                Button(action: {
                    onAdd()
                }) {
                    ZStack {
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: [
                                        Color(hex: "#A78BFA"),
                                        Color(hex: "#F9A8D4"),
                                        Color(hex: "#FCD34D")
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 48, height: 48)

                        Image(systemName: "plus")
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundColor(.black)
                    }
                }
                .buttonStyle(.plain)
            }
        }
        .padding(20)
        .background(Color(hex: "#121212"))
        .cornerRadius(20)
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(Color(hex: "#222222"), lineWidth: 1)
        )
    }

    private var progressBar: some View {
        GeometryReader { geo in
            let width = geo.size.width
            let safeWidth = width.isFinite && width >= 0 ? width : 0
            let clampedProgress = max(0, min(progress, 1.0))
            let progressWidth = max(0, safeWidth * CGFloat(clampedProgress))

            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Color(hex: "#2C2C2E"))
                    .frame(height: 8)

                Capsule()
                    .fill(
                        LinearGradient(
                            colors: [
                                Color(hex: "#A78BFA"),
                                Color(hex: "#F9A8D4"),
                                Color(hex: "#FCD34D")
                            ],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(width: progressWidth, height: 8)
            }
        }
        .frame(height: 8)
    }

    private func formatCurrency(_ value: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "USD"
        formatter.maximumFractionDigits = 0
        formatter.minimumFractionDigits = 0
        return formatter.string(from: NSNumber(value: value)) ?? "$0"
    }
}

#Preview {
    ZStack {
        Color.black.ignoresSafeArea()
        SavingsTargetCard(
            currentAmount: .constant(4250),
            targetAmount: 5000,
            onAdd: {}
        )
            .padding()
    }
}
