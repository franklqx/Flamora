//
//  SavingsInputSheet.swift
//  Flamora app
//
//  Savings input modal
//

import SwiftUI

struct SavingsInputSheet: View {
    @Binding var amount: Double
    @Environment(\.dismiss) private var dismiss
    @State private var inputText: String = ""
    @FocusState private var isFocused: Bool

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack(spacing: 24) {
                Capsule()
                    .fill(Color(hex: "#2C2C2E"))
                    .frame(width: 40, height: 5)
                    .padding(.top, 12)

                Text("How much did you save this month?")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)

                HStack(spacing: 6) {
                    Text("$")
                        .font(.system(size: 40, weight: .bold))
                        .foregroundColor(.white)

                    TextField("0", text: $inputText)
                        .keyboardType(.numberPad)
                        .font(.system(size: 40, weight: .bold))
                        .foregroundColor(.white)
                        .focused($isFocused)
                        .onChange(of: inputText) { _, newValue in
                            inputText = newValue.filter { $0.isNumber }
                        }
                }
                .padding(.vertical, 8)

                GradientButton(title: "Submit") {
                    if let value = Double(inputText) {
                        amount = value
                    }
                    dismiss()
                }
                .opacity(inputText.isEmpty ? 0.6 : 1.0)
                .disabled(inputText.isEmpty)

                Spacer()
            }
            .padding(24)
        }
        .onAppear {
            inputText = amount > 0 ? String(format: "%.0f", amount) : ""
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                isFocused = true
            }
        }
    }
}

#Preview {
    SavingsInputSheet(amount: .constant(1500))
}
