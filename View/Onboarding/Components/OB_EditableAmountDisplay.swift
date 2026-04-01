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
                .font(.h1)
                .foregroundStyle(AppColors.textPrimary)
            ZStack {
                // TextField 始终在视图树中，避免焦点丢失
                TextField("", text: $editText)
                    .font(.currencyHero.monospacedDigit())
                    .foregroundStyle(AppColors.textPrimary)
                    .keyboardType(.numberPad)
                    .focused($isFocused)
                    .multilineTextAlignment(.center)
                    .opacity(isFocused ? 1 : 0)
                    .onChange(of: isFocused) { _, newVal in
                        if !newVal { commit() }
                    }

                if !isFocused {
                    Text(formattedValue)
                        .font(.currencyHero.monospacedDigit())
                        .foregroundStyle(accentGradient)
                        .contentTransition(.numericText())
                }
            }
            .frame(minWidth: 80, minHeight: 56)
            .contentShape(Rectangle())
            .onTapGesture {
                editText = "\(Int(value))"
                isFocused = true
            }
            if !suffix.isEmpty {
                Text(suffix)
                    .font(.h3)
                    .fontWeight(.regular)
                    .foregroundColor(AppColors.textTertiary)
            }
            Spacer()
        }
        .frame(height: 80)
    }

    private func commit() {
        let stripped = editText.replacingOccurrences(of: ",", with: "")
        let parsed = Double(stripped) ?? 0
        value = max(parsed, range.lowerBound)
    }
}
