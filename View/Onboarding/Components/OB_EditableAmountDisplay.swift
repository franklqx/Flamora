//
//  OB_EditableAmountDisplay.swift
//  Flamora app
//
//  Reusable editable amount display: tap number to open keyboard, type to input.
//

import SwiftUI

struct OB_EditableAmountDisplay: View {
    @Binding var value: Double
    @FocusState.Binding var isFocused: Bool
    let range: ClosedRange<Double>
    let currencySymbol: String
    let suffix: String
    let accentGradient: LinearGradient
    @State private var editText: String = ""

    private var formattedValue: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 0
        return formatter.string(from: NSNumber(value: value)) ?? "\(Int(value))"
    }

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 2) {
            Spacer()
            Text(currencySymbol)
                .font(.system(size: 32, weight: .bold))
                .foregroundStyle(.white)
            if isFocused {
                TextField("", text: $editText)
                    .font(.system(size: 48, weight: .bold).monospacedDigit())
                    .foregroundStyle(accentGradient)
                    .keyboardType(.numberPad)
                    .focused($isFocused)
                    .multilineTextAlignment(.center)
                    .frame(minWidth: 80)
                    .onAppear { editText = "\(Int(value))" }
                    .onChange(of: isFocused) { _, newVal in
                        if !newVal { commit() }
                    }
            } else {
                Text(formattedValue)
                    .font(.system(size: 48, weight: .bold).monospacedDigit())
                    .foregroundStyle(accentGradient)
                    .contentTransition(.numericText())
                    .frame(minWidth: 80, minHeight: 56)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        editText = "\(Int(value))"
                        isFocused = true
                    }
            }
            if !suffix.isEmpty {
                Text(suffix)
                    .font(.system(size: 20, weight: .regular))
                    .foregroundColor(AppColors.textTertiary)
            }
            Spacer()
        }
        .frame(height: 80)
    }

    private func commit() {
        let stripped = editText.replacingOccurrences(of: ",", with: "")
        let parsed = Double(stripped) ?? 0
        let clamped = min(max(parsed, range.lowerBound), range.upperBound)
        value = clamped
    }
}
