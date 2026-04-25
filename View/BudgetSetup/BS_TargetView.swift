//
//  BS_TargetView.swift
//  Flamora app
//
//  Budget Setup — Step 4: Set Your Target
//

import SwiftUI

struct BS_TargetView: View {
    @Bindable var viewModel: BudgetSetupViewModel

    @State private var showCurrentAgeSheet = false
    @State private var showTargetAgeSheet = false
    @State private var showFireInfoSheet = false
    @State private var showSpendingSheet = false
    @State private var draftCurrentAge: Int = 0
    @State private var draftTargetAge: Int = 0
    @State private var draftSpendingMonthly: Double = 0
    @State private var draftSpendingText: String = ""
    @FocusState private var isSpendingFieldFocused: Bool

    private let spendingMin: Double = 500
    private let spendingSliderMax: Double = 20000
    private let spendingHardCap: Double = 50000

    private var minTargetAge: Int { max(viewModel.currentAge + 1, 1) }
    private var maxTargetAge: Int { 80 }
    private var todaySpend: Double { max(0, viewModel.currentSnapshotSpend) }
    private var desiredFireNumber: Double { max(0, viewModel.retirementSpendingMonthly) * 12 / 0.04 }

    private enum SpendingComparisonState {
        case above(Int)
        case below(Int)
        case matches
    }

    private var spendingComparisonState: SpendingComparisonState? {
        spendingComparisonState(for: viewModel.retirementSpendingMonthly)
    }

    private func spendingComparisonState(for monthlySpending: Double) -> SpendingComparisonState? {
        guard todaySpend > 0 else { return nil }
        let delta = monthlySpending - todaySpend
        let pct = abs(delta) / todaySpend * 100
        if pct < 3 { return .matches }
        let roundedPct = Int(pct.rounded())
        return delta >= 0 ? .above(roundedPct) : .below(roundedPct)
    }

    private var draftSpendingSliderBinding: Binding<Double> {
        Binding(
            get: { min(max(draftSpendingMonthly, spendingMin), spendingSliderMax) },
            set: { updateDraftSpending($0) }
        )
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            LinearGradient(colors: [AppColors.shellBg1, AppColors.shellBg2], startPoint: .top, endPoint: .bottom)
                .ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: AppSpacing.lg) {
                    Spacer().frame(height: AppSpacing.xxl + AppSpacing.sm + AppSpacing.xs)

                    headerSection
                        .padding(.horizontal, AppSpacing.lg)

                    ageRow
                        .padding(.horizontal, AppSpacing.lg)

                    spendingFireCard
                        .padding(.horizontal, AppSpacing.lg)

                    Spacer().frame(height: AppSpacing.tabBarReserve + AppSpacing.md + AppSpacing.md + AppSpacing.sm)
                }
            }
            .scrollDismissesKeyboard(.interactively)

            stickyBottomCTA
        }
        .onAppear {
            viewModel.seedDefaultsForTargetStep()
        }
        .sheet(isPresented: $showCurrentAgeSheet) { currentAgeSheet }
        .sheet(isPresented: $showTargetAgeSheet) { targetAgeSheet }
        .sheet(isPresented: $showFireInfoSheet) { fireInfoSheet }
        .sheet(isPresented: $showSpendingSheet) { spendingSheet }
    }

    // MARK: - Header

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            Text("Set Your Target")
                .font(.cardFigurePrimary)
                .foregroundStyle(AppColors.inkPrimary)

            Text("Choose the age you want to retire, then set the monthly spending level you want your future plan to support.")
                .font(.bodySmall)
                .foregroundStyle(AppColors.inkSoft)
                .lineSpacing(3)
        }
    }

    // MARK: - Age Row (Variant A: side-by-side)

    private var ageRow: some View {
        HStack(spacing: AppSpacing.md) {
            compactAgeCard(title: "CURRENT AGE", value: viewModel.currentAge) {
                draftCurrentAge = viewModel.currentAge > 0 ? viewModel.currentAge : 28
                showCurrentAgeSheet = true
            }
            compactAgeCard(title: "TARGET AGE", value: viewModel.targetRetirementAge) {
                draftTargetAge = max(viewModel.targetRetirementAge, minTargetAge)
                showTargetAgeSheet = true
            }
        }
    }

    private func compactAgeCard(title: String, value: Int, onTap: @escaping () -> Void) -> some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: AppSpacing.sm) {
                Text(title)
                    .font(.label)
                    .tracking(1)
                    .foregroundStyle(AppColors.inkFaint)

                HStack(alignment: .firstTextBaseline) {
                    Text("\(value)")
                        .font(.h1)
                        .foregroundStyle(AppColors.inkPrimary)
                        .monospacedDigit()
                    Spacer()
                    Image(systemName: "pencil")
                        .font(.footnoteRegular)
                        .foregroundStyle(AppColors.accentAmber)
                }
            }
            .padding(AppSpacing.md)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(AppColors.glassCardBg)
            .clipShape(RoundedRectangle(cornerRadius: AppRadius.lg))
            .overlay(
                RoundedRectangle(cornerRadius: AppRadius.lg)
                    .stroke(AppColors.inkBorder, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(title) \(value). Tap to edit.")
    }

    // MARK: - Combined Spending + FIRE Card

    private var spendingFireCard: some View {
        VStack(alignment: .leading, spacing: AppSpacing.md) {
            VStack(alignment: .leading, spacing: AppSpacing.sm) {
                Text("DESIRED MONTHLY SPENDING")
                    .font(.label)
                    .tracking(1)
                    .foregroundStyle(AppColors.inkFaint)

                spendingAmountRow

                if let spendingComparisonState {
                    spendingComparisonFootnote(for: spendingComparisonState)
                }
            }

            Rectangle()
                .fill(AppColors.inkBorder)
                .frame(height: 1)

            VStack(alignment: .leading, spacing: AppSpacing.xs) {
                Text("YOUR FIRE NUMBER")
                    .font(.label)
                    .tracking(1)
                    .foregroundStyle(AppColors.inkFaint)

                Text("$\(formatted(desiredFireNumber))")
                    .font(.h2)
                    .foregroundStyle(AppColors.inkPrimary)
                    .monospacedDigit()
                    .contentTransition(.numericText())

                Button {
                    showFireInfoSheet = true
                } label: {
                    HStack(spacing: 4) {
                        Text("Based on the 4% rule")
                            .font(.caption)
                            .foregroundStyle(AppColors.inkSoft)
                        Image(systemName: "info.circle")
                            .font(.caption)
                            .foregroundStyle(AppColors.inkSoft)
                    }
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Learn about the 4% rule")
                .padding(.top, AppSpacing.xxs)
            }
        }
        .padding(AppSpacing.md)
        .background(AppColors.glassCardBg)
        .clipShape(RoundedRectangle(cornerRadius: AppRadius.lg))
        .overlay(
            RoundedRectangle(cornerRadius: AppRadius.lg)
                .stroke(AppColors.inkBorder, lineWidth: 1)
        )
    }

    private var spendingAmountRow: some View {
        Button {
            primeSpendingEditor()
            showSpendingSheet = true
        } label: {
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text("$\(formatted(viewModel.retirementSpendingMonthly))")
                    .font(.h1)
                    .foregroundStyle(AppColors.inkPrimary)
                    .monospacedDigit()
                Text("/mo")
                    .font(.bodyRegular)
                    .foregroundStyle(AppColors.inkSoft)
                Image(systemName: "pencil")
                    .font(.footnoteRegular)
                    .foregroundStyle(AppColors.accentAmber)
                Spacer()
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Desired monthly spending \(formatted(viewModel.retirementSpendingMonthly)) dollars")
    }

    @ViewBuilder
    private func spendingComparisonFootnote(for state: SpendingComparisonState) -> some View {
        switch state {
        case .above(let pct):
            HStack(spacing: 6) {
                HStack(spacing: 4) {
                    Image(systemName: "arrow.up")
                    Text("\(pct)%")
                }
                .foregroundStyle(AppColors.accentAmber)
                Text("more than you spend today")
                    .font(.footnoteRegular)
                    .foregroundStyle(AppColors.inkFaint)
            }
            .font(.footnoteSemibold)
            .contentTransition(.numericText())
            .padding(.leading, AppSpacing.sm + AppSpacing.xs)
        case .below(let pct):
            HStack(spacing: 6) {
                HStack(spacing: 4) {
                    Image(systemName: "arrow.down")
                    Text("\(pct)%")
                }
                .foregroundStyle(AppColors.accentAmber)
                Text("less than you spend today")
                    .font(.footnoteRegular)
                    .foregroundStyle(AppColors.inkFaint)
            }
            .font(.footnoteSemibold)
            .contentTransition(.numericText())
            .padding(.leading, AppSpacing.sm + AppSpacing.xs)
        case .matches:
            HStack(spacing: 6) {
                Image(systemName: "equal")
                    .foregroundStyle(AppColors.accentAmber)
                Text("About what you spend today")
                    .font(.footnoteRegular)
                    .foregroundStyle(AppColors.inkFaint)
            }
            .font(.footnoteSemibold)
            .padding(.leading, AppSpacing.sm + AppSpacing.xs)
        }
    }

    // MARK: - Sticky CTA

    private var stickyBottomCTA: some View {
        VStack(spacing: 0) {
            LinearGradient(colors: [Color.clear, AppColors.shellBg2], startPoint: .top, endPoint: .bottom)
                .frame(height: AppRadius.button)

            VStack(spacing: AppSpacing.xs) {
                Button {
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    if isSpendingFieldFocused { isSpendingFieldFocused = false }
                    Task {
                        let saved = await viewModel.saveFireGoal()
                        if saved {
                            await MainActor.run { viewModel.goToStep(.plan) }
                        }
                    }
                } label: {
                    HStack(spacing: AppSpacing.sm) {
                        if viewModel.isSavingGoal {
                            ProgressView().tint(AppColors.ctaWhite)
                        }
                        Text(viewModel.isSavingGoal ? "Saving..." : "Continue")
                            .font(.sheetPrimaryButton)
                    }
                    .foregroundStyle(AppColors.ctaWhite)
                    .frame(maxWidth: .infinity)
                    .frame(height: 56)
                    .background(canContinue ? AppColors.inkPrimary : AppColors.inkFaint)
                    .clipShape(RoundedRectangle(cornerRadius: AppRadius.button))
                }
                .disabled(!canContinue || viewModel.isSavingGoal)

                if let error = viewModel.goalSaveError {
                    Text(error)
                        .font(.caption)
                        .foregroundStyle(AppColors.error)
                }
            }
            .padding(.horizontal, AppSpacing.lg)
            .padding(.bottom, AppSpacing.md)
            .background(AppColors.shellBg2)
        }
    }

    private var canContinue: Bool {
        viewModel.retirementSpendingMonthly > 0 && viewModel.targetRetirementAge >= minTargetAge
    }

    // MARK: - Spending Sheet

    private var spendingSheet: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: AppSpacing.lg) {
                VStack(alignment: .leading, spacing: AppSpacing.sm) {
                    Text("Desired Monthly Spending")
                        .font(.h3)
                        .foregroundStyle(AppColors.inkPrimary)
                    Text("Set the monthly lifestyle you want your future plan to support. You can type an exact number or use the slider to explore.")
                        .font(.bodySmall)
                        .foregroundStyle(AppColors.inkSoft)
                        .lineSpacing(2)
                }

                VStack(alignment: .leading, spacing: AppSpacing.sm) {
                    spendingSheetAmountRow

                    if let comparison = spendingComparisonState(for: draftSpendingMonthly) {
                        spendingComparisonFootnote(for: comparison)
                    }
                }

                VStack(spacing: AppSpacing.xs) {
                    Slider(value: draftSpendingSliderBinding, in: spendingMin...spendingSliderMax, step: 50)
                        .tint(AppColors.accentAmber)

                    HStack {
                        Text("$\(formatted(spendingMin))")
                            .font(.caption)
                            .foregroundStyle(AppColors.inkFaint)
                        Spacer()
                        Text("$\(formatted(spendingSliderMax))")
                            .font(.caption)
                            .foregroundStyle(AppColors.inkFaint)
                    }
                }

                if todaySpend > 0 {
                    Button {
                        updateDraftSpending(todaySpend)
                    } label: {
                        Text("Match today")
                            .font(.footnoteSemibold)
                            .foregroundStyle(AppColors.inkPrimary)
                            .padding(.horizontal, AppSpacing.sm)
                            .padding(.vertical, AppSpacing.xs)
                            .background(AppColors.glassCardBg)
                            .clipShape(Capsule())
                            .overlay(
                                Capsule()
                                    .stroke(AppColors.inkBorder, lineWidth: 1)
                            )
                    }
                    .buttonStyle(.plain)
                }

                Spacer(minLength: 0)
            }
            .padding(AppSpacing.lg)
            .background(LinearGradient(colors: [AppColors.shellBg1, AppColors.shellBg2], startPoint: .top, endPoint: .bottom).ignoresSafeArea())
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") {
                        isSpendingFieldFocused = false
                        showSpendingSheet = false
                    }
                    .foregroundStyle(AppColors.inkSoft)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Apply") {
                        commitDraftSpending()
                        isSpendingFieldFocused = false
                        showSpendingSheet = false
                    }
                    .fontWeight(.semibold)
                    .foregroundStyle(AppColors.inkPrimary)
                }
            }
            .onAppear {
                primeSpendingEditor()
            }
            .onChange(of: draftSpendingText) { _, _ in
                guard isSpendingFieldFocused else { return }
                let digits = draftSpendingText.filter { $0.isNumber }
                let value = Double(digits) ?? 0
                draftSpendingMonthly = min(spendingHardCap, max(0, value))
            }
            .onChange(of: draftSpendingMonthly) { _, newValue in
                guard !isSpendingFieldFocused else { return }
                draftSpendingText = String(Int(newValue.rounded()))
            }
        }
        .presentationDetents([.height(430)])
        .presentationDragIndicator(.visible)
    }

    private var spendingSheetAmountRow: some View {
        HStack(alignment: .firstTextBaseline, spacing: 2) {
            Text("$")
                .font(.h1)
                .foregroundStyle(AppColors.inkPrimary)
            TextField("", text: $draftSpendingText)
                .keyboardType(.numberPad)
                .font(.h1.monospacedDigit())
                .foregroundStyle(AppColors.inkPrimary)
                .focused($isSpendingFieldFocused)
                .fixedSize()
                .toolbar {
                    ToolbarItemGroup(placement: .keyboard) {
                        Spacer()
                        Button("Done") {
                            isSpendingFieldFocused = false
                            commitDraftSpending()
                        }
                        .fontWeight(.semibold)
                        .foregroundStyle(AppColors.inkPrimary)
                    }
                }
            Text("/mo")
                .font(.bodyRegular)
                .foregroundStyle(AppColors.inkSoft)
                .padding(.leading, 4)
            Spacer()
        }
    }

    // MARK: - Current Age Sheet

    private var currentAgeSheet: some View {
        ageSheet(
            title: "Your Current Age",
            subtitle: "Used to project when you'll hit your FIRE number. Saving this updates your plan.",
            draft: $draftCurrentAge,
            range: 18...80,
            onCancel: { showCurrentAgeSheet = false },
            onApply: {
                let newAge = draftCurrentAge
                showCurrentAgeSheet = false
                Task { await viewModel.updateCurrentAge(newAge) }
            }
        )
        .presentationDetents([.height(360)])
        .presentationDragIndicator(.visible)
    }

    // MARK: - Target Age Sheet

    private var targetAgeSheet: some View {
        ageSheet(
            title: "Target Retirement Age",
            subtitle: "The age you'd like your plan to fund. Can't be earlier than your current age.",
            draft: $draftTargetAge,
            range: minTargetAge...maxTargetAge,
            onCancel: { showTargetAgeSheet = false },
            onApply: {
                viewModel.targetRetirementAge = draftTargetAge
                showTargetAgeSheet = false
            }
        )
        .presentationDetents([.height(360)])
        .presentationDragIndicator(.visible)
    }

    // MARK: - Age Sheet Template

    private func ageSheet(
        title: String,
        subtitle: String,
        draft: Binding<Int>,
        range: ClosedRange<Int>,
        onCancel: @escaping () -> Void,
        onApply: @escaping () -> Void
    ) -> some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: AppSpacing.lg) {
                VStack(alignment: .leading, spacing: AppSpacing.sm) {
                    Text(title)
                        .font(.h3)
                        .foregroundStyle(AppColors.inkPrimary)
                    Text(subtitle)
                        .font(.bodySmall)
                        .foregroundStyle(AppColors.inkSoft)
                        .lineSpacing(2)
                }

                HStack(alignment: .firstTextBaseline, spacing: AppSpacing.xs) {
                    Spacer()
                    Text("\(draft.wrappedValue)")
                        .font(.currencyHero.monospacedDigit())
                        .foregroundStyle(AppColors.inkPrimary)
                        .contentTransition(.numericText())
                    Text("yrs")
                        .font(.bodySemibold)
                        .foregroundStyle(AppColors.inkSoft)
                    Spacer()
                }

                VStack(spacing: AppSpacing.xs) {
                    Slider(
                        value: Binding(
                            get: { Double(draft.wrappedValue) },
                            set: { draft.wrappedValue = Int($0.rounded()) }
                        ),
                        in: Double(range.lowerBound)...Double(range.upperBound),
                        step: 1
                    )
                    .tint(AppColors.accentAmber)

                    HStack {
                        Text("\(range.lowerBound)")
                            .font(.caption)
                            .foregroundStyle(AppColors.inkFaint)
                        Spacer()
                        Text("\(range.upperBound)")
                            .font(.caption)
                            .foregroundStyle(AppColors.inkFaint)
                    }
                }

                Spacer(minLength: 0)
            }
            .padding(AppSpacing.lg)
            .background(LinearGradient(colors: [AppColors.shellBg1, AppColors.shellBg2], startPoint: .top, endPoint: .bottom).ignoresSafeArea())
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel", action: onCancel)
                        .foregroundStyle(AppColors.inkSoft)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Apply", action: onApply)
                        .fontWeight(.semibold)
                        .foregroundStyle(AppColors.inkPrimary)
                }
            }
        }
    }

    // MARK: - FIRE Info Sheet (4% rule)

    private var fireInfoSheet: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: AppSpacing.md) {
                VStack(alignment: .leading, spacing: AppSpacing.sm) {
                    Text("The 4% Rule")
                        .font(.h3)
                        .foregroundStyle(AppColors.inkPrimary)
                    Text("A popular FIRE guideline: if you save 25× your annual spending, you can withdraw about 4% per year and your money should last 30+ years.")
                        .font(.bodySmall)
                        .foregroundStyle(AppColors.inkSoft)
                        .lineSpacing(3)
                }

                VStack(alignment: .leading, spacing: AppSpacing.sm) {
                    Text("YOUR CALCULATION")
                        .font(.label)
                        .tracking(1)
                        .foregroundStyle(AppColors.inkFaint)

                    Text("$\(formatted(viewModel.retirementSpendingMonthly)) × 12 ÷ 0.04")
                        .font(.bodyRegular)
                        .foregroundStyle(AppColors.inkSoft)
                        .monospacedDigit()

                    Text("= $\(formatted(desiredFireNumber))")
                        .font(.h2)
                        .foregroundStyle(AppColors.inkPrimary)
                        .monospacedDigit()
                }
                .padding(AppSpacing.md)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(AppColors.glassCardBg)
                .clipShape(RoundedRectangle(cornerRadius: AppRadius.lg))
                .overlay(
                    RoundedRectangle(cornerRadius: AppRadius.lg)
                        .stroke(AppColors.inkBorder, lineWidth: 1)
                )

                Spacer(minLength: 0)
            }
            .padding(AppSpacing.lg)
            .background(LinearGradient(colors: [AppColors.shellBg1, AppColors.shellBg2], startPoint: .top, endPoint: .bottom).ignoresSafeArea())
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { showFireInfoSheet = false }
                        .fontWeight(.semibold)
                        .foregroundStyle(AppColors.inkPrimary)
                }
            }
        }
        .presentationDetents([.height(420)])
        .presentationDragIndicator(.visible)
    }

    // MARK: - Helpers

    private func primeSpendingEditor() {
        let initialValue = min(spendingHardCap, max(0, viewModel.retirementSpendingMonthly))
        draftSpendingMonthly = initialValue
        draftSpendingText = String(Int(initialValue.rounded()))
    }

    private func updateDraftSpending(_ value: Double) {
        let clamped = min(spendingHardCap, max(0, value))
        draftSpendingMonthly = clamped
        if !isSpendingFieldFocused {
            draftSpendingText = String(Int(clamped.rounded()))
        }
    }

    private func commitDraftSpending() {
        let digits = draftSpendingText.filter { $0.isNumber }
        let typedValue = Double(digits) ?? draftSpendingMonthly
        let clamped = min(spendingHardCap, max(0, typedValue))
        draftSpendingMonthly = clamped
        draftSpendingText = String(Int(clamped.rounded()))
        viewModel.retirementSpendingMonthly = clamped
    }

    private func formatted(_ value: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 0
        return formatter.string(from: NSNumber(value: value)) ?? "\(Int(value.rounded()))"
    }
}
