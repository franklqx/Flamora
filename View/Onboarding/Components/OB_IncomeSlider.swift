//
//  OB_IncomeSlider.swift
//  Flamora app
//
//  Onboarding - Custom Slider with currency display and keyboard input
//

import SwiftUI

struct OB_IncomeSlider: View {
    @Binding var value: Double
    let range: ClosedRange<Double>
    var step: Double = 100
    var currencySymbol: String = "$"
    var suffix: String = "/mo"
    var onEditingChanged: ((Bool) -> Void)? = nil

    @State private var isEditing = false
    @State private var textInput = ""
    @FocusState private var isTextFieldFocused: Bool

    var body: some View {
        VStack(spacing: AppSpacing.lg) {
            // MARK: - Value Display
            valueDisplay

            // MARK: - Custom Slider Track
            GeometryReader { geo in
                let width = geo.size.width
                let progress = CGFloat((value - range.lowerBound) / (range.upperBound - range.lowerBound))
                let thumbX = progress * width

                ZStack(alignment: .leading) {
                    // Track background
                    Capsule()
                        .fill(Color(hex: "#333333"))
                        .frame(height: 4)

                    // Filled portion
                    Capsule()
                        .fill(Color.white)
                        .frame(width: max(0, thumbX), height: 4)

                    // Thumb
                    Circle()
                        .fill(Color.white)
                        .frame(width: 28, height: 28)
                        .shadow(color: .black.opacity(0.2), radius: 4, y: 2)
                        .offset(x: max(0, min(thumbX - 14, width - 28)))
                }
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { gesture in
                            let percent = max(0, min(1, gesture.location.x / width))
                            let rawValue = range.lowerBound + Double(percent) * (range.upperBound - range.lowerBound)
                            value = (rawValue / step).rounded() * step
                            value = max(range.lowerBound, min(range.upperBound, value))
                            onEditingChanged?(true)
                        }
                        .onEnded { _ in
                            onEditingChanged?(false)
                        }
                )
            }
            .frame(height: 28)

            // MARK: - Range Labels
            HStack {
                Text(formatCurrency(range.lowerBound))
                    .font(.caption)
                    .foregroundColor(AppColors.textTertiary)
                Spacer()
                Text(formatCurrency(range.upperBound))
                    .font(.caption)
                    .foregroundColor(AppColors.textTertiary)
            }
        }
    }

    // MARK: - Value Display

    @ViewBuilder
    private var valueDisplay: some View {
        if isEditing {
            HStack(alignment: .firstTextBaseline, spacing: 2) {
                Text(currencySymbol)
                    .font(.system(size: 48, weight: .bold))
                    .foregroundColor(AppColors.textPrimary)

                TextField("", text: $textInput)
                    .font(.system(size: 48, weight: .bold))
                    .foregroundColor(AppColors.textPrimary)
                    .keyboardType(.numberPad)
                    .focused($isTextFieldFocused)
                    .multilineTextAlignment(.center)
                    .fixedSize()
                    .onSubmit { commitTextInput() }
                    .onChange(of: isTextFieldFocused) { _, focused in
                        if !focused { commitTextInput() }
                    }

                Text(suffix)
                    .font(.system(size: 20, weight: .regular))
                    .foregroundColor(AppColors.textTertiary)
            }
        } else {
            Button {
                textInput = "\(Int(value))"
                isEditing = true
                isTextFieldFocused = true
            } label: {
                HStack(alignment: .firstTextBaseline, spacing: 2) {
                    Text(currencySymbol)
                        .font(.system(size: 48, weight: .bold))
                        .foregroundColor(AppColors.textPrimary)

                    Text(formattedValue)
                        .font(.system(size: 48, weight: .bold))
                        .foregroundColor(AppColors.textPrimary)

                    Text(suffix)
                        .font(.system(size: 20, weight: .regular))
                        .foregroundColor(AppColors.textTertiary)
                }
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - Helpers

    private var formattedValue: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 0
        return formatter.string(from: NSNumber(value: value)) ?? "\(Int(value))"
    }

    private func formatCurrency(_ val: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 0
        return "\(currencySymbol)\(formatter.string(from: NSNumber(value: val)) ?? "\(Int(val))")"
    }

    private func commitTextInput() {
        if let parsed = Double(textInput.replacingOccurrences(of: ",", with: "")) {
            value = max(range.lowerBound, min(range.upperBound, (parsed / step).rounded() * step))
        }
        isEditing = false
    }
}

#Preview {
    OB_IncomeSlider(value: .constant(5000), range: 0...50000, currencySymbol: "$")
        .background(AppBackgroundView())
}
