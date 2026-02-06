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
    @State private var sheetHeight: CGFloat = 520
    @State private var safeAreaBottom: CGFloat = 0

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                Color.black.ignoresSafeArea()

                VStack(spacing: 24) {
                    Text("How much did you save this month?")
                        .font(.system(size: 22, weight: .bold))
                        .foregroundColor(.white)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: .infinity)

                    HStack(spacing: 6) {
                        Text("$")
                            .font(.system(size: 40, weight: .bold))
                            .foregroundColor(.white)

                        Text(inputText.isEmpty ? "0" : inputText)
                            .font(.system(size: 40, weight: .bold))
                            .foregroundColor(.white)
                    }
                    .padding(.vertical, 8)

                    keypad

                    GradientButton(title: "Submit") {
                        if let value = Double(inputText) {
                            amount = value
                        }
                        dismiss()
                    }
                    .opacity(inputText.isEmpty ? 0.6 : 1.0)
                    .disabled(inputText.isEmpty)
                }
                .frame(maxWidth: .infinity, alignment: .top)
                .padding(.horizontal, 24)
                .padding(.top, 32)
                .background(
                    GeometryReader { contentProxy in
                        Color.clear
                            .preference(key: ContentHeightKey.self, value: contentProxy.size.height)
                    }
                )
            }
            .ignoresSafeArea(.container, edges: .bottom)
            .onAppear {
                safeAreaBottom = proxy.safeAreaInsets.bottom
            }
            .onChange(of: proxy.safeAreaInsets.bottom) { _, newValue in
                safeAreaBottom = newValue
            }
        }
        .ignoresSafeArea(.container, edges: .bottom)
        .presentationDetents([.height(sheetHeight)])
        .onPreferenceChange(ContentHeightKey.self) { newValue in
            let targetHeight = max(newValue + safeAreaBottom, 360)
            if abs(sheetHeight - targetHeight) > 1 {
                sheetHeight = targetHeight
            }
        }
        .onAppear {
            inputText = amount > 0 ? String(format: "%.0f", amount) : ""
        }
    }

    private var keypad: some View {
        VStack(spacing: 16) {
            keypadRow(["1", "2", "3"])
            keypadRow(["4", "5", "6"])
            keypadRow(["7", "8", "9"])
            HStack(spacing: 24) {
                Spacer()
                numberButton("0")
                deleteButton
                Spacer()
            }
        }
    }

    private func keypadRow(_ numbers: [String]) -> some View {
        HStack(spacing: 24) {
            ForEach(numbers, id: \.self) { number in
                numberButton(number)
            }
        }
    }

    private func numberButton(_ number: String) -> some View {
        Button(action: {
            inputText.append(number)
        }) {
            Text(number)
                .font(.system(size: 28, weight: .semibold))
                .foregroundColor(.white)
                .frame(width: 72, height: 64)
        }
        .buttonStyle(.plain)
    }

    private var deleteButton: some View {
        Button(action: {
            guard !inputText.isEmpty else { return }
            inputText.removeLast()
        }) {
            Image(systemName: "delete.left")
                .font(.system(size: 22, weight: .semibold))
                .foregroundColor(.white)
                .frame(width: 72, height: 64)
        }
        .buttonStyle(.plain)
    }
}

private struct ContentHeightKey: PreferenceKey {
    static var defaultValue: CGFloat = 0

    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = max(value, nextValue())
    }
}

#Preview {
    SavingsInputSheet(amount: .constant(1500))
}
