//
//  SavingsInputSheet.swift
//  Flamora app
//
//  Savings input modal — light-shell version (Home + Cashflow shared).
//  旧的深色版本归档在 OLDDESIGN/SavingsInputSheet.swift。
//

import SwiftUI

struct SavingsInputSheet: View {
    @Binding var amount: Double
    var targetAmount: Double = 0
    var onSubmit: ((Double) -> Void)? = nil
    @Environment(\.dismiss) private var dismiss
    @State private var inputText: String = ""
    @State private var sheetHeight: CGFloat = 520
    @State private var safeAreaBottom: CGFloat = 0

    private var parsedAmount: Double? {
        guard !inputText.isEmpty else { return nil }
        return Double(inputText)
    }

    private var formattedAmountText: String {
        guard let value = parsedAmount, value > 0 else { return "0" }
        let f = NumberFormatter()
        f.numberStyle = .decimal
        f.maximumFractionDigits = 0
        f.groupingSeparator = ","
        return f.string(from: NSNumber(value: value)) ?? inputText
    }

    private enum DeltaState {
        case onTarget
        case over(Int)
        case under(Int)

        var text: String {
            switch self {
            case .onTarget:    return "On target"
            case .over(let p): return "+\(p)% vs target"
            case .under(let p): return "-\(p)% vs target"
            }
        }
    }

    private var deltaState: DeltaState? {
        guard let value = parsedAmount, value > 0, targetAmount > 0 else { return nil }
        let pct = ((value - targetAmount) / targetAmount) * 100
        let rounded = Int(abs(pct).rounded())
        if rounded == 0 { return .onTarget }
        return pct > 0 ? .over(rounded) : .under(rounded)
    }

    private var deltaColor: Color {
        switch deltaState {
        case .onTarget: return AppColors.inkSoft
        case .over:     return AppColors.progressGreen
        case .under:    return AppColors.accentAmber
        case .none:     return .clear
        }
    }

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                LinearGradient(
                    colors: [AppColors.shellBg1, AppColors.shellBg2],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()

                VStack(spacing: AppSpacing.lg) {
                    headerBlock

                    amountDisplay

                    keypad

                    submitButton
                }
                .frame(maxWidth: .infinity, alignment: .top)
                .padding(.horizontal, AppSpacing.screenPadding)
                .padding(.top, AppSpacing.lg)
                .padding(.bottom, AppSpacing.md)
                .background(
                    GeometryReader { contentProxy in
                        Color.clear
                            .preference(key: ContentHeightKey.self, value: contentProxy.size.height)
                    }
                )
            }
            .ignoresSafeArea(.container, edges: .bottom)
            .onAppear { safeAreaBottom = proxy.safeAreaInsets.bottom }
            .onChange(of: proxy.safeAreaInsets.bottom) { _, newValue in
                safeAreaBottom = newValue
            }
        }
        .ignoresSafeArea(.container, edges: .bottom)
        .presentationDetents([.height(sheetHeight)])
        .presentationDragIndicator(.visible)
        .presentationCornerRadius(AppRadius.xl)
        .presentationBackground(AppColors.shellBg1)
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

    // MARK: - Header

    private var headerBlock: some View {
        VStack(spacing: AppSpacing.xs) {
            Text("SAVINGS CHECK-IN")
                .font(.cardHeader)
                .foregroundColor(AppColors.inkPrimary)
                .tracking(AppTypography.Tracking.cardHeader)

            Text("How much did you save this month?")
                .font(.detailTitle)
                .foregroundStyle(AppColors.inkPrimary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)
        }
    }

    // MARK: - Amount display

    private var amountDisplay: some View {
        VStack(spacing: AppSpacing.xs) {
            HStack(alignment: .firstTextBaseline, spacing: AppSpacing.xs) {
                Text("$")
                    .font(.h1)
                    .foregroundStyle(AppColors.inkSoft)

                Text(inputText.isEmpty ? "0" : formattedAmountText)
                    .font(.currencyHero)
                    .foregroundStyle(inputText.isEmpty ? AppColors.inkFaint : AppColors.inkPrimary)
                    .monospacedDigit()
                    .contentTransition(.numericText())
                    .animation(.easeOut(duration: 0.15), value: inputText)
            }

            if let delta = deltaState {
                Text(delta.text)
                    .font(.footnoteSemibold)
                    .foregroundStyle(deltaColor)
                    .transition(.opacity)
            } else {
                Text(" ")
                    .font(.footnoteSemibold)
            }
        }
        .padding(.vertical, AppSpacing.sm)
        .animation(.easeOut(duration: 0.15), value: inputText)
    }

    // MARK: - Keypad

    private var keypad: some View {
        VStack(spacing: AppSpacing.md) {
            keypadRow(["1", "2", "3"])
            keypadRow(["4", "5", "6"])
            keypadRow(["7", "8", "9"])
            HStack(spacing: AppSpacing.xl) {
                Spacer(minLength: 0)
                numberButton("0")
                deleteButton
                Spacer(minLength: 0)
            }
        }
    }

    private func keypadRow(_ numbers: [String]) -> some View {
        HStack(spacing: AppSpacing.xl) {
            ForEach(numbers, id: \.self) { number in
                numberButton(number)
            }
        }
    }

    private func numberButton(_ number: String) -> some View {
        Button {
            appendDigit(number)
        } label: {
            Text(number)
                .font(.h2)
                .foregroundStyle(AppColors.inkPrimary)
                .frame(width: 72, height: 56)
                .contentShape(Rectangle())
        }
        .buttonStyle(KeypadButtonStyle())
    }

    private var deleteButton: some View {
        Button {
            guard !inputText.isEmpty else { return }
            inputText.removeLast()
        } label: {
            Image(systemName: "delete.left")
                .font(.h3)
                .foregroundStyle(AppColors.inkSoft)
                .frame(width: 72, height: 56)
                .contentShape(Rectangle())
        }
        .buttonStyle(KeypadButtonStyle())
    }

    private func appendDigit(_ digit: String) {
        // Guard against leading zeros (e.g. "0" + "5" → "05"). Allow "0" on its own.
        if inputText == "0" { inputText = digit }
        else if inputText.count < 8 { inputText.append(digit) }
    }

    // MARK: - Submit

    private var submitButton: some View {
        let enabled = (parsedAmount ?? 0) > 0
        return Button {
            guard let value = parsedAmount, value > 0 else { return }
            amount = value
            onSubmit?(value)
            dismiss()
        } label: {
            Text("Submit")
                .font(.sheetPrimaryButton)
                .foregroundStyle(enabled ? AppColors.ctaWhite : AppColors.inkFaint)
                .frame(maxWidth: .infinity)
                .frame(height: 56)
                .background(
                    RoundedRectangle(cornerRadius: AppRadius.button)
                        .fill(enabled ? AppColors.ctaBlack : AppColors.inkTrack)
                )
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
        .padding(.horizontal, AppSpacing.xs)
    }
}

// MARK: - Keypad button style

private struct KeypadButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .background(
                Circle()
                    .fill(AppColors.inkTrack.opacity(configuration.isPressed ? 0.6 : 0))
                    .frame(width: 64, height: 64)
            )
            .scaleEffect(configuration.isPressed ? 0.94 : 1.0)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

// MARK: - Preference

private struct ContentHeightKey: PreferenceKey {
    static var defaultValue: CGFloat = 0

    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = max(value, nextValue())
    }
}

#Preview {
    ZStack {
        AppColors.backgroundPrimary.ignoresSafeArea()
    }
    .sheet(isPresented: .constant(true)) {
        SavingsInputSheet(amount: .constant(1500))
    }
}
