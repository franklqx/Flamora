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

    @State private var showInputSheet = false

    private var progress: Double {
        guard targetAmount > 0 else { return 0 }
        return min(max(currentAmount / targetAmount, 0), 1)
    }

    var body: some View {
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

                if currentAmount > 0 {
                    ZStack {
                        Circle()
                            .fill(Color(hex: "#1A1A1A"))
                            .frame(width: 40, height: 40)

                        Image(systemName: "piggy.bank")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(Color(hex: "#A78BFA"))
                    }
                } else {
                    Button(action: {
                        showInputSheet = true
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

                    ProgressBar(
                        progress: progress,
                        color: Color(hex: "#8B5CF6"),
                        height: 8
                    )
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .padding(20)
        .background(Color(hex: "#121212"))
        .cornerRadius(20)
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(Color(hex: "#222222"), lineWidth: 1)
        )
        .sheet(isPresented: $showInputSheet) {
            SavingsInputSheet(amount: $currentAmount)
                .presentationDetents([.medium])
        }
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
        SavingsTargetCard(currentAmount: .constant(4250), targetAmount: 5000)
            .padding()
    }
}
