//
//  SimulatorView.swift
//  Flamora app
//
//  Simulator Main + Edit Profile Sheet
//

import SwiftUI

/// 模拟器高级假设（与后端用户画像解耦；非 MockData）。
private enum SimulatorAdvancedDefaults {
    static let inflationRate: Double = 3.0
    static let forecastGrowthRate: Double = 7.0
}

struct SimulatorSettings {
    var age: Int
    var monthlyIncome: Double
    var monthlyContribution: Double
    var expectedBudget: Double
    var currentInvestment: Double
    var inflation: Double
    var growthRate: Double

    static func from(_ data: SimulatorData) -> SimulatorSettings {
        SimulatorSettings(
            age: data.currentProfile.age,
            monthlyIncome: data.currentProfile.monthlyIncome,
            monthlyContribution: data.currentProfile.monthlyContribution,
            expectedBudget: data.currentProfile.expectedBudget,
            currentInvestment: data.currentProfile.currentInvestment,
            inflation: data.advancedSettings.inflationRate,
            growthRate: data.advancedSettings.forecastGrowthRate
        )
    }

    static func fromAPI() -> SimulatorSettings {
        let profile = MockData.apiUserProfile
        let fireGoal = MockData.apiFireGoal
        return SimulatorSettings(
            age: fireGoal.currentAge,
            monthlyIncome: profile.monthlyIncome,
            monthlyContribution: profile.monthlyIncome - profile.currentMonthlyExpenses,
            expectedBudget: profile.currentMonthlyExpenses,
            currentInvestment: fireGoal.currentNetWorth,
            inflation: SimulatorAdvancedDefaults.inflationRate,
            growthRate: SimulatorAdvancedDefaults.forecastGrowthRate
        )
    }
}

struct SimulatorView: View {
    @Binding var displayState: SimulatorDisplayState
    @State private var settings: SimulatorSettings = .fromAPI()
    @State private var showEditor = false
    @State private var isPulsing = false
    let isFireOn: Bool
    let onFireToggle: (() -> Void)?
    let bottomPadding: CGFloat

    private var progressFraction: Double {
        let target = computedFireCalculation.targetAmount
        let current = computedFireCalculation.currentNetWorth
        guard target > 0 else { return 0 }
        return min(max(current / target, 0), 1)
    }

    private var progressPercentText: String {
        String(format: "%.0f%%", progressFraction * 100)
    }

    init(
        displayState: Binding<SimulatorDisplayState>,
        bottomPadding: CGFloat = 0,
        isFireOn: Bool = true,
        onFireToggle: (() -> Void)? = nil
    ) {
        _displayState = displayState
        self.isFireOn = isFireOn
        self.onFireToggle = onFireToggle
        self.bottomPadding = bottomPadding
    }

    var body: some View {
        ZStack {
            Color.clear  // 与其他页面一致，不额外添加黑色层

            switch displayState {
            case .overview:
                overviewContent
            case .loading:
                loadingContent
            case .results:
                resultsContent
            }
        }
        .animation(nil, value: bottomPadding)
        .fullScreenCover(isPresented: $showEditor) {
            SimulatorEditProfileView(
                settings: $settings,
                onClose: { showEditor = false },
                onLaunch: {
                    showEditor = false
                    runSimulation()
                }
            )
        }
    }

    private func runSimulation() {
        displayState = .loading
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
            displayState = .results
        }
    }
}

enum SimulatorDisplayState {
    case overview
    case loading
    case results
}

// MARK: - Main Content
private extension SimulatorView {
    var overviewContent: some View {
        GeometryReader { proxy in
            ScrollView(showsIndicators: false) {
                VStack(spacing: 24) {
                    heroTitle

                    circularProgress
                        .padding(.vertical, 16)

                    detailedAnalysis

                    GradientButton(title: "Enter simulator") {
                        showEditor = true
                    }
                    .padding(.top, 8)

                }
                .frame(minHeight: proxy.size.height, alignment: .top)
                .padding(.bottom, max(bottomPadding, AppSpacing.lg))
                .padding(.top, AppSpacing.md)
            }
        }
    }

    var heroTitle: some View {
        let fireAge = computedFireCalculation.fireAge

        let ageGradient = LinearGradient(
            colors: AppColors.gradientFire,
            startPoint: .leading,
            endPoint: .trailing
        )

        return HStack(spacing: 6) {
            Text("FIRE by age")
                .font(.cardFigurePrimary)
                .foregroundStyle(AppColors.textPrimary)

            Text("\(fireAge)")
                .font(.cardFigurePrimary)
                .foregroundStyle(ageGradient)
        }
        .frame(maxWidth: .infinity, alignment: .center)
        .multilineTextAlignment(.center)
        .padding(.horizontal, AppSpacing.screenPadding)
    }

    var circularProgress: some View {
        CircularProgressView(
            progress: progressFraction,
            percentText: progressPercentText
        )
    }

    var detailedAnalysis: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("DETAILED WEALTH ANALYSIS")
                .font(.cardHeader)
                .foregroundColor(AppColors.textTertiary)
                .tracking(1.5)
                .padding(.horizontal, AppSpacing.screenPadding)

            AnalysisCard(icon: "target", title: "Target Amount", value: formatCurrency(computedFireCalculation.targetAmount))
            AnalysisCard(icon: "dollarsign.circle.fill", title: "Current Net Worth", value: formatCurrency(computedFireCalculation.currentNetWorth))
            AnalysisCard(icon: "creditcard.fill", title: "Ideal Monthly Spending", value: formatCurrency(computedFireCalculation.idealMonthlySpending))
        }
    }

    var loadingContent: some View {
        VStack(spacing: 24) {
            Spacer()

            ZStack {
                Circle()
                    .stroke(AppColors.surfaceBorder, style: StrokeStyle(lineWidth: 2, dash: [6, 6]))
                    .frame(width: 220, height: 220)

                Circle()
                    .fill(AppColors.surfaceElevated)
                    .frame(width: 140, height: 140)
                    .overlay(
                        FlameIcon(size: 64, color: AppColors.textPrimary)
                    )
                    .shadow(color: AppColors.brandSecondary.opacity(0.25), radius: 30)
                    .scaleEffect(isPulsing ? 1.06 : 0.94)
                    .animation(.easeInOut(duration: 1.2).repeatForever(autoreverses: true), value: isPulsing)
            }
            .onAppear { isPulsing = true }
            .onDisappear { isPulsing = false }

            VStack(spacing: 8) {
                Text("Simulating your future…")
                    .font(.detailTitle)
                    .foregroundStyle(AppColors.textPrimary)

                Text("ANALYZING CONTRIBUTION PATTERNS…")
                    .font(.footnoteSemibold)
                    .foregroundColor(AppColors.textTertiary)
                    .tracking(1.5)
            }

            Spacer()
        }
        .padding(.horizontal, 24)
    }

    var resultsContent: some View {
        GeometryReader { proxy in
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 24) {
                    resultsTitle

                    resultsChart

                    resultsCards

                    GradientButton(title: "Save Simulation") {
                        displayState = .overview
                    }
                    .padding(.top, 8)

                }
                .frame(minHeight: proxy.size.height, alignment: .top)
                .padding(.bottom, max(bottomPadding, AppSpacing.lg))
                .padding(.top, AppSpacing.md)
                .padding(.horizontal, AppSpacing.screenPadding)
            }
        }
    }

    var resultsTitle: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("You will reach financial")
                .font(.cardFigurePrimary)
                .foregroundStyle(AppColors.textPrimary)

            Text("independence at age \(computedFireCalculation.fireAge)")
                .font(.cardFigurePrimary)
                .foregroundStyle(AppColors.textPrimary)

            Text("Detailed FIRE progress analysis")
                .font(.supportingText)
                .foregroundColor(AppColors.textTertiary)
        }
    }

    var resultsChart: some View {
        VStack(alignment: .leading, spacing: 12) {
            GeometryReader { proxy in
                let width = proxy.size.width
                let height = proxy.size.height

                ZStack {
                    Path { path in
                        path.move(to: CGPoint(x: 0, y: height * 0.7))
                        path.addCurve(
                            to: CGPoint(x: width * 0.55, y: height * 0.35),
                            control1: CGPoint(x: width * 0.2, y: height * 0.55),
                            control2: CGPoint(x: width * 0.35, y: height * 0.35)
                        )
                        path.addCurve(
                            to: CGPoint(x: width, y: height * 0.75),
                            control1: CGPoint(x: width * 0.75, y: height * 0.45),
                            control2: CGPoint(x: width * 0.9, y: height * 0.7)
                        )
                    }
                    .stroke(
                        LinearGradient(
                            colors: [AppColors.accentBlueBright, AppColors.warning],
                            startPoint: .leading,
                            endPoint: .trailing
                        ),
                        style: StrokeStyle(lineWidth: 3, lineCap: .round)
                    )

                    Circle()
                        .stroke(AppColors.textPrimary, lineWidth: 3)
                        .frame(width: 14, height: 14)
                        .position(x: width * 0.55, y: height * 0.35)

                    Path { path in
                        path.move(to: CGPoint(x: width * 0.55, y: height * 0.35))
                        path.addLine(to: CGPoint(x: width * 0.55, y: height))
                    }
                    .stroke(AppColors.surfaceBorder, style: StrokeStyle(lineWidth: 1, dash: [4, 6]))
                }
            }
            .frame(height: 220)

            HStack {
                Text("Age \(settings.age)")
                    .font(.footnoteRegular)
                    .foregroundColor(AppColors.textTertiary)

                Spacer()

                Text("Age \(computedFireCalculation.fireAge) (FIRE)")
                    .font(.footnoteSemibold)
                    .foregroundStyle(AppColors.textPrimary)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 6)
                    .background(AppColors.surfaceElevated)
                    .clipShape(Capsule())

                Spacer()

                Text("Age 90")
                    .font(.footnoteRegular)
                    .foregroundColor(AppColors.textTertiary)
            }
        }
    }

    var resultsCards: some View {
        let fireAge = computedFireCalculation.fireAge
        let yearsUntilFire = max(fireAge - settings.age, 0)
        let fireYear = Calendar.current.component(.year, from: Date()) + yearsUntilFire

        return HStack(spacing: 16) {
            resultStatCard(
                title: "FIRE DATE",
                value: "\(fireYear)",
                subvalue: "Age \(fireAge)",
                accent: AppColors.warning
            )

            resultStatCard(
                title: "TOTAL WEALTH",
                value: formatCurrency(computedFireCalculation.targetAmount),
                subvalue: "At milestone",
                accent: AppColors.accentBlueBright
            )
        }
    }

    func resultStatCard(title: String, value: String, subvalue: String, accent: Color) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.smallLabel)
                .foregroundColor(AppColors.textTertiary)
                .tracking(1.2)

            Text(value)
                .font(.h3)
                .foregroundStyle(AppColors.textPrimary)

            Text(subvalue)
                .font(.bodySmallSemibold)
                .foregroundColor(accent)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(AppSpacing.md)
        .background(AppColors.surface)
        .overlay(
            RoundedRectangle(cornerRadius: AppRadius.lg)
                .stroke(AppColors.surfaceBorder, lineWidth: 0.75)
        )
        .cornerRadius(AppRadius.lg)
    }
}

// MARK: - Edit Profile Full Screen
private struct SimulatorEditProfileView: View {
    @Binding var settings: SimulatorSettings
    let onClose: () -> Void
    let onLaunch: () -> Void

    @State private var showAdvanced = false
    @State private var activeField: SettingField?

    var body: some View {
        ZStack {
            AppColors.backgroundPrimary.ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 24) {
                    header

                    titleSection

                    settingsSection

                    advancedSection

                    GradientButton(title: "Launch simulation") {
                        onLaunch()
                    }
                    .padding(.top, 8)

                    Color.clear.frame(height: 24)
                }
                .padding(.horizontal, 24)
                .padding(.top, 24)
            }
        }
        .sheet(item: $activeField) { field in
            SettingEditorSheet(
                field: field,
                settings: $settings
            )
        }
    }
}

private extension SimulatorEditProfileView {
    var header: some View {
        HStack(spacing: 10) {
            FlameIcon(size: 18, color: AppColors.brandPrimary)

            Text("PREDICT")
                .font(.inlineFigureBold)
                .foregroundColor(AppColors.textSecondary)
                .tracking(2)

            Spacer()

            Button(action: onClose) {
                Image(systemName: "xmark")
                    .font(.bodySemibold)
                    .foregroundColor(AppColors.textSecondary)
                    .frame(width: 28, height: 28)
            }
            .buttonStyle(.plain)
        }
    }

    var titleSection: some View {
        Text("Edit your Profile")
            .font(.largeTitle.bold())
            .foregroundStyle(AppColors.textPrimary)
            .padding(.top, 8)
    }

    var settingsSection: some View {
        VStack(spacing: 0) {
            SettingRow(title: "Current age", value: "\(settings.age)", unit: "years") {
                activeField = .age
            }
            divider

            SettingRow(title: "Current monthly income", value: formatCurrency(settings.monthlyIncome), unit: "/mo") {
                activeField = .income
            }
            divider

            SettingRow(title: "Monthly Contribution", value: formatCurrency(settings.monthlyContribution), unit: "/mo") {
                activeField = .contribution
            }
            divider

            SettingRow(title: "Expected budget", value: formatCurrency(settings.expectedBudget), unit: "/mo") {
                activeField = .budget
            }
            divider

            SettingRow(title: "Current Investment amount", value: formatCurrency(settings.currentInvestment), unit: "") {
                activeField = .investment
            }
        }
        .padding(.top, 8)
    }

    var advancedSection: some View {
        VStack(spacing: 16) {
            Button {
                withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) {
                    showAdvanced.toggle()
                }
            } label: {
                HStack {
                    Text("Advanced settings")
                        .font(.body.weight(.semibold))
                        .foregroundStyle(AppColors.textPrimary)

                    Spacer()

                    Image(systemName: showAdvanced ? "chevron.up" : "chevron.down")
                        .font(.bodySmallSemibold)
                        .foregroundColor(AppColors.textSecondary)
                }
                .padding(.vertical, 12)
                .padding(.horizontal, 18)
                .background(AppColors.surface)
                .overlay(
                    Capsule()
                        .stroke(AppColors.surfaceBorder, lineWidth: 1)
                )
                .clipShape(Capsule())
            }
            .buttonStyle(.plain)

            if showAdvanced {
                VStack(spacing: 0) {
                    SettingRow(title: "Inflation", value: formatPercent(settings.inflation), unit: "") {
                        activeField = .inflation
                    }
                    divider

                    SettingRow(title: "Forecast Growth Rate", value: formatPercent(settings.growthRate), unit: "") {
                        activeField = .growthRate
                    }
                }
            }
        }
        .padding(.top, 4)
    }

    var divider: some View {
        Divider()
            .overlay(AppColors.surfaceElevated)
            .padding(.vertical, 4)
    }

    func formatCurrency(_ value: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "USD"
        formatter.maximumFractionDigits = 0
        formatter.minimumFractionDigits = 0
        return formatter.string(from: NSNumber(value: value)) ?? "$0"
    }

    func formatPercent(_ value: Double) -> String {
        String(format: "%.1f%%", value)
    }
}

// MARK: - Setting Row
private struct SettingRow: View {
    let title: String
    let value: String
    let unit: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack {
                Text(title)
                    .font(.bodyRegular)
                    .foregroundColor(AppColors.textSecondary)

                Spacer()

                HStack(spacing: 6) {
                    Text(value)
                        .font(.body.bold())
                        .foregroundStyle(AppColors.textPrimary)

                    if !unit.isEmpty {
                        Text(unit)
                            .font(.bodyRegular)
                            .foregroundColor(AppColors.textTertiary)
                    }

                    Image(systemName: "chevron.down")
                        .font(.bodySmallSemibold)
                        .foregroundColor(AppColors.textTertiary)
                }
            }
            .padding(.vertical, 16)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Editing Sheet
private enum SettingField: String, Identifiable {
    case age
    case income
    case contribution
    case budget
    case investment
    case inflation
    case growthRate

    var id: String { rawValue }

    var title: String {
        switch self {
        case .age: return "Current age"
        case .income: return "Current monthly income"
        case .contribution: return "Monthly Contribution"
        case .budget: return "Expected budget"
        case .investment: return "Current Investment amount"
        case .inflation: return "Inflation"
        case .growthRate: return "Forecast Growth Rate"
        }
    }

    var suffix: String {
        switch self {
        case .age: return "years"
        case .income, .contribution, .budget: return "/mo"
        case .investment: return ""
        case .inflation, .growthRate: return "%"
        }
    }
}

private struct SettingEditorSheet: View {
    let field: SettingField
    @Binding var settings: SimulatorSettings
    @Environment(\.dismiss) private var dismiss
    @State private var inputValue: String

    init(field: SettingField, settings: Binding<SimulatorSettings>) {
        self.field = field
        self._settings = settings

        let currentValue: String
        switch field {
        case .age:
            currentValue = String(settings.wrappedValue.age)
        case .income:
            currentValue = String(format: "%.0f", settings.wrappedValue.monthlyIncome)
        case .contribution:
            currentValue = String(format: "%.0f", settings.wrappedValue.monthlyContribution)
        case .budget:
            currentValue = String(format: "%.0f", settings.wrappedValue.expectedBudget)
        case .investment:
            currentValue = String(format: "%.0f", settings.wrappedValue.currentInvestment)
        case .inflation:
            currentValue = String(format: "%.1f", settings.wrappedValue.inflation)
        case .growthRate:
            currentValue = String(format: "%.1f", settings.wrappedValue.growthRate)
        }
        _inputValue = State(initialValue: currentValue)
    }

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 16) {
                Text(field.title)
                    .font(.statRowSemibold)
                    .foregroundStyle(AppColors.textPrimary)

                HStack {
                    TextField("Enter value", text: $inputValue)
                        .keyboardType(.decimalPad)
                        .textFieldStyle(.roundedBorder)

                    if !field.suffix.isEmpty {
                        Text(field.suffix)
                            .font(.bodyRegular)
                            .foregroundColor(AppColors.textSecondary)
                    }
                }

                Spacer()
            }
            .padding(24)
            .background(AppColors.backgroundPrimary)
            .navigationTitle("Edit")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        applyValue()
                        dismiss()
                    }
                }
            }
        }
        .presentationDetents([.medium])
    }

    private func applyValue() {
        switch field {
        case .age:
            if let value = Int(inputValue) {
                settings.age = max(0, value)
            }
        case .income:
            if let value = Double(inputValue) {
                settings.monthlyIncome = max(0, value)
            }
        case .contribution:
            if let value = Double(inputValue) {
                settings.monthlyContribution = max(0, value)
            }
        case .budget:
            if let value = Double(inputValue) {
                settings.expectedBudget = max(0, value)
            }
        case .investment:
            if let value = Double(inputValue) {
                settings.currentInvestment = max(0, value)
            }
        case .inflation:
            if let value = Double(inputValue) {
                settings.inflation = max(0, value)
            }
        case .growthRate:
            if let value = Double(inputValue) {
                settings.growthRate = max(0, value)
            }
        }
    }
}

// MARK: - Derived Calculation
private extension SimulatorView {
    var computedFireCalculation: FireCalculation {
        let annualSpend = settings.expectedBudget * 12
        let targetAmount = annualSpend * 25
        let currentNetWorth = settings.currentInvestment
        let monthlySavings = max(settings.monthlyContribution, 0)
        let required = max(targetAmount - currentNetWorth, 0)
        let yearsToFire = monthlySavings > 0 ? Int(ceil(required / (monthlySavings * 12))) : 99
        let fireAge = settings.age + yearsToFire
        let progress = targetAmount > 0 ? Int(min(max(currentNetWorth / targetAmount, 0), 1) * 100) : 0

        return FireCalculation(
            targetAmount: targetAmount,
            currentNetWorth: currentNetWorth,
            idealMonthlySpending: settings.expectedBudget,
            fireAge: fireAge,
            fireDate: "",
            progressPercent: progress
        )
    }
}

// MARK: - Formatting
private extension SimulatorView {
    func formatCurrency(_ value: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "USD"
        formatter.maximumFractionDigits = 0
        formatter.minimumFractionDigits = 0
        return formatter.string(from: NSNumber(value: value)) ?? "$0"
    }

    func formatPercent(_ value: Double) -> String {
        String(format: "%.1f%%", value)
    }

    func gradientText(_ text: String) -> some View {
        LinearGradient(
            colors: [
                AppColors.accentPurple,
                AppColors.accentPink,
                AppColors.accentAmber
            ],
            startPoint: .leading,
            endPoint: .trailing
        )
        .mask(
            Text(text)
        )
    }
}

// MARK: - Circular Progress
private struct CircularProgressView: View {
    let progress: Double
    let percentText: String

    private let circleSize: CGFloat = 220

    var body: some View {
        ZStack {
            Circle()
                .stroke(AppColors.progressTrack, lineWidth: 14)

            Circle()
                .trim(from: 0, to: progress)
                .stroke(
                    LinearGradient(
                        colors: [AppColors.accentPurple, AppColors.accentPink],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    style: StrokeStyle(lineWidth: 14, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
        }
        .frame(width: circleSize, height: circleSize)
        .overlay(centerContent)
    }

    private var centerContent: some View {
        VStack(spacing: 8) {
            ZStack {
                Image("FlameIcon")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 44, height: 44)
                    .opacity(0.25)
                    .blur(radius: 6)

                LinearGradient(
                    colors: [AppColors.accentPurple, AppColors.accentPink, AppColors.accentAmber],
                    startPoint: .leading,
                    endPoint: .trailing
                )
                .mask(
                    Image("FlameIcon")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 44, height: 44)
                )
                .shadow(color: AppColors.accentPink.opacity(0.6), radius: 10)
            }
            .frame(height: 44)

            Text(percentText)
                .font(.h1)
                .foregroundStyle(AppColors.textPrimary)

            Text("ACHIEVED")
                .font(.miniLabel)
                .foregroundColor(AppColors.textTertiary)
                .tracking(2)
        }
    }
}

// MARK: - Preview
#Preview {
    SimulatorView(displayState: .constant(.overview))
}
