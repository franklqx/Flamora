//
//  IncomeDetailView.swift
//  Flamora app
//
//  Income drill-down detail page (Active / Passive)
//  - Header: title + total amount + month label
//  - Annual Trend: 12-month bar chart (tappable)
//  - Sources: list of income sources (updates per selected month)
//

import SwiftUI

struct IncomeDetailView: View {
    let data: IncomeDetailData

    @Environment(\.dismiss) private var dismiss
    @State private var dragOffset: CGFloat = 0
    @State private var selectedBarIndex: Int = 0
    @State private var editableMonthlyData: [Int: IncomeMonthData]
    @State private var isSourceEditorPresented = false
    @State private var editingSourceID = ""
    @State private var editingSourceSeriesKey = ""
    @State private var editingSourceMonthIndex = 0
    @State private var editingSourceName = ""
    @State private var editingSourceType: IncomeSourceType = .active
    @State private var applySmartRules = true

    private let monthLabels = ["J", "F", "M", "A", "M", "J", "J", "A", "S", "O", "N", "D"]
    private let monthsFull = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]

    init(data: IncomeDetailData) {
        self.data = data
        _editableMonthlyData = State(initialValue: data.monthlyData)
    }

    private var maxChartValue: Double {
        let values = data.annualTrend.compactMap { $0 }
        return max(values.max() ?? 1, 1)
    }

    /// Current month's data based on selected bar
    private var selectedMonthData: IncomeMonthData? {
        editableMonthlyData[selectedBarIndex]
    }

    private var selectedTotal: Double {
        selectedMonthData?.total ?? data.annualTrend[selectedBarIndex] ?? 0
    }

    private var selectedSources: [IncomeDetailSource] {
        selectedMonthData?.sources ?? []
    }

    private var selectedMonthLabel: String {
        monthsFull[selectedBarIndex]
    }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 24) {
                    headerSection

                    annualTrendSection

                    sourcesSection
                }
                .padding(.horizontal, 20)
                .padding(.top, 20)
                .padding(.bottom, 100)
            }
        }
        .preferredColorScheme(.dark)
        .offset(y: dragOffset)
        .gesture(
            DragGesture()
                .onChanged { value in
                    if value.translation.height > 0 {
                        dragOffset = value.translation.height
                    }
                }
                .onEnded { value in
                    if value.translation.height > 150 {
                        dismiss()
                    } else {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                            dragOffset = 0
                        }
                    }
                }
        )
        .sheet(isPresented: $isSourceEditorPresented) {
            IncomeSourceEditorSheet(
                sourceName: $editingSourceName,
                selectedType: $editingSourceType,
                applySmartRules: $applySmartRules,
                onClose: { isSourceEditorPresented = false },
                onSave: saveSourceEdits
            )
            .presentationDetents([.height(460)])
            .presentationDragIndicator(.hidden)
        }
    }
}

// MARK: - Header
private extension IncomeDetailView {
    var headerSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                Text(data.title)
                    .font(.system(size: 28, weight: .bold))
                    .foregroundColor(.white)

                Spacer()

                Button(action: { dismiss() }) {
                    Image(systemName: "xmark")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.white)
                        .padding(.top, 2)
                }
                .buttonStyle(.plain)
            }

            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text(formatCurrency(selectedTotal))
                    .font(.system(size: 32, weight: .bold))
                    .foregroundColor(.white)

                Text("earned in \(selectedMonthLabel)")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(Color(hex: "#9CA3AF"))
            }
        }
    }
}

// MARK: - Annual Trend
private extension IncomeDetailView {
    var annualTrendSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("ANNUAL TREND")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(Color(hex: "#6B7280"))
                    .tracking(1.5)

                Spacer()

                Text("Jan - Dec 2026")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(Color(hex: "#9CA3AF"))
            }

            chartView
                .frame(height: 220)
        }
    }

    var chartView: some View {
        GeometryReader { geometry in
            let barAreaHeight = geometry.size.height - 30
            let barSpacing: CGFloat = 8
            let totalSpacing = barSpacing * 11
            let barWidth = (geometry.size.width - totalSpacing) / 12

            HStack(alignment: .bottom, spacing: barSpacing) {
                ForEach(0..<12, id: \.self) { index in
                    barColumn(
                        index: index,
                        barWidth: barWidth,
                        maxHeight: barAreaHeight
                    )
                    .onTapGesture {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            selectedBarIndex = index
                        }
                    }
                }
            }
        }
    }

    func barColumn(index: Int, barWidth: CGFloat, maxHeight: CGFloat) -> some View {
        let amount = data.annualTrend[index]
        let height = barHeight(for: amount, maxHeight: maxHeight)
        let isSelected = index == selectedBarIndex

        return VStack(spacing: 10) {
            Group {
                if
                    isSelected,
                    amount != nil,
                    let monthData = editableMonthlyData[index],
                    !monthData.sources.isEmpty
                {
                    stackedBarFill(for: monthData)
                } else {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color(hex: "#D1D5DB").opacity(0.25))
                }
            }
                .frame(width: barWidth, height: height)
                .opacity(amount == nil ? 0.3 : 1.0)

            Text(monthLabels[index])
                .font(.system(size: 11, weight: isSelected ? .bold : .semibold))
                .foregroundColor(isSelected ? .white : Color(hex: "#9CA3AF"))
        }
        .frame(maxWidth: .infinity)
    }

    func barHeight(for amount: Double?, maxHeight: CGFloat) -> CGFloat {
        guard let amount = amount, amount > 0 else { return 16 }
        let ratio = min(amount / maxChartValue, 1.0)
        return max(16, maxHeight * CGFloat(ratio))
    }

    func stackedBarFill(for monthData: IncomeMonthData) -> some View {
        let total = max(monthData.sources.reduce(0) { $0 + $1.amount }, 0.0001)
        let stackedSources = Array(monthData.sources.reversed())

        return GeometryReader { geometry in
            let availableHeight = geometry.size.height

            VStack(spacing: 0) {
                ForEach(stackedSources) { source in
                    Rectangle()
                        .fill(sourceColor(for: source))
                        .frame(maxWidth: .infinity)
                        .frame(height: availableHeight * CGFloat(source.amount / total))
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
        }
        .clipShape(RoundedRectangle(cornerRadius: 4))
    }
}

// MARK: - Sources
private extension IncomeDetailView {
    var sourcesSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Sources")
                .font(.system(size: 22, weight: .bold))
                .foregroundColor(.white)

            VStack(spacing: 12) {
                ForEach(selectedSources) { source in
                    Button {
                        openSourceEditor(for: source)
                    } label: {
                        sourceCard(source: source)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    func sourceCard(source: IncomeDetailSource) -> some View {
        GeometryReader { geometry in
            let width = geometry.size.width
            let ratio = min(max(source.percentage / 100, 0), 1)
            let fillWidth = ratio == 0 ? 0 : max(56, width * CGFloat(ratio))

            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 20)
                    .fill(Color.white.opacity(0.06))

                RoundedRectangle(cornerRadius: 20)
                    .fill(sourceColor(for: source).opacity(0.88))
                    .frame(width: fillWidth)

                HStack(spacing: 14) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(source.name)
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(.white)

                        Text("\(source.account) · \(source.type.displayName)")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(Color(hex: "#D1D5DB").opacity(0.8))
                    }

                    Spacer()

                    VStack(alignment: .trailing, spacing: 4) {
                        Text(formatCurrency(source.amount))
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(.white)

                        Text("\(Int(source.percentage.rounded()))%")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(Color(hex: "#9CA3AF"))
                    }
                }
                .padding(.horizontal, 18)
            }
        }
        .frame(height: 92)
    }

    func sourceColor(for source: IncomeDetailSource) -> Color {
        Color(hex: source.colorHex)
    }

    func openSourceEditor(for source: IncomeDetailSource) {
        editingSourceID = source.id
        editingSourceSeriesKey = sourceSeriesKey(for: source.id)
        editingSourceMonthIndex = selectedBarIndex
        editingSourceName = source.name
        editingSourceType = source.type
        applySmartRules = true
        isSourceEditorPresented = true
    }

    func saveSourceEdits() {
        let trimmedName = editingSourceName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else { return }

        if applySmartRules {
            for monthIndex in editableMonthlyData.keys {
                guard let monthData = editableMonthlyData[monthIndex] else { continue }
                let updatedSources = monthData.sources.map { source in
                    guard sourceSeriesKey(for: source.id) == editingSourceSeriesKey else { return source }
                    var updated = source
                    updated.name = trimmedName
                    updated.type = editingSourceType
                    return updated
                }
                editableMonthlyData[monthIndex] = IncomeMonthData(total: monthData.total, sources: updatedSources)
            }
        } else {
            guard let monthData = editableMonthlyData[editingSourceMonthIndex] else { return }
            let updatedSources = monthData.sources.map { source in
                guard source.id == editingSourceID else { return source }
                var updated = source
                updated.name = trimmedName
                updated.type = editingSourceType
                return updated
            }
            editableMonthlyData[editingSourceMonthIndex] = IncomeMonthData(total: monthData.total, sources: updatedSources)
        }

        isSourceEditorPresented = false
    }

    func sourceSeriesKey(for sourceID: String) -> String {
        guard let lastDash = sourceID.lastIndex(of: "-") else { return sourceID }
        return String(sourceID[..<lastDash])
    }
}

// MARK: - Helper
private extension IncomeDetailView {
    func formatCurrency(_ value: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "USD"
        formatter.maximumFractionDigits = 2
        formatter.minimumFractionDigits = 2
        return formatter.string(from: NSNumber(value: value)) ?? "$0.00"
    }
}

// MARK: - Previews
#Preview("Active Income") {
    IncomeDetailView(data: MockData.activeIncomeDetail)
}

#Preview("Passive Income") {
    IncomeDetailView(data: MockData.passiveIncomeDetail)
}

private extension IncomeSourceType {
    var helperDescription: String {
        switch self {
        case .active:
            return "Active income comes from your work and services."
        case .passive:
            return "Passive income contributes to your retirement withdrawal coverage."
        }
    }
}

private struct IncomeSourceEditorSheet: View {
    @Binding var sourceName: String
    @Binding var selectedType: IncomeSourceType
    @Binding var applySmartRules: Bool

    let onClose: () -> Void
    let onSave: () -> Void

    private var isSaveDisabled: Bool {
        sourceName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        ZStack {
            Color(hex: "#17181F").ignoresSafeArea()

            VStack(spacing: 0) {
                Capsule()
                    .fill(Color(hex: "#4B5563"))
                    .frame(width: 44, height: 5)
                    .padding(.top, 12)

                VStack(alignment: .leading, spacing: 20) {
                    HStack {
                        Text("Edit Source")
                            .font(.system(size: 33, weight: .bold))
                            .foregroundColor(.white)

                        Spacer()

                        Button(action: onClose) {
                            Image(systemName: "xmark")
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundColor(Color(hex: "#9CA3AF"))
                                .frame(width: 30, height: 30)
                        }
                        .buttonStyle(.plain)
                    }

                    VStack(alignment: .leading, spacing: 10) {
                        Text("Source Name")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(.white)

                        TextField("Rental Property", text: $sourceName)
                            .textInputAutocapitalization(.words)
                            .disableAutocorrection(true)
                            .font(.system(size: 17, weight: .medium))
                            .foregroundColor(.white)
                            .padding(.horizontal, 14)
                            .frame(height: 48)
                            .background(
                                RoundedRectangle(cornerRadius: 14)
                                    .fill(Color.white.opacity(0.08))
                            )
                    }

                    VStack(alignment: .leading, spacing: 12) {
                        Text("Income Type")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(.white)

                        HStack(spacing: 6) {
                            ForEach(IncomeSourceType.allCases, id: \.self) { type in
                                Button {
                                    selectedType = type
                                } label: {
                                    Text(type.displayName)
                                        .font(.system(size: 16, weight: .semibold))
                                        .foregroundColor(
                                            selectedType == type
                                            ? Color(hex: "#111827")
                                            : Color(hex: "#9CA3AF")
                                        )
                                        .frame(maxWidth: .infinity)
                                        .frame(height: 38)
                                        .background(
                                            Capsule()
                                                .fill(selectedType == type ? Color.white : Color.clear)
                                        )
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(4)
                        .background(
                            RoundedRectangle(cornerRadius: 16)
                                .fill(Color.white.opacity(0.08))
                        )

                        HStack(alignment: .top, spacing: 8) {
                            Image(systemName: "info.circle.fill")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundColor(Color(hex: "#6B7280"))
                                .padding(.top, 1)

                            Text(selectedType.helperDescription)
                                .font(.system(size: 13, weight: .medium))
                                .foregroundColor(Color(hex: "#9CA3AF"))
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }

                    Divider()
                        .overlay(Color.white.opacity(0.08))

                    HStack(spacing: 12) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Smart Rules")
                                .font(.system(size: 17, weight: .semibold))
                                .foregroundColor(.white)

                            Text("Apply to all history & future records")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(Color(hex: "#9CA3AF"))
                        }

                        Spacer()

                        Toggle("", isOn: $applySmartRules)
                            .labelsHidden()
                            .tint(Color(hex: "#A78BFA"))
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 16)

                Spacer(minLength: 16)

                Divider()
                    .overlay(Color.white.opacity(0.08))

                Button(action: onSave) {
                    Text("Save Changes")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 52)
                        .background(
                            RoundedRectangle(cornerRadius: 14)
                                .fill(Color.white.opacity(0.08))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 14)
                                .stroke(Color.white.opacity(0.08), lineWidth: 1)
                        )
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 20)
                .padding(.top, 16)
                .padding(.bottom, 14)
                .disabled(isSaveDisabled)
                .opacity(isSaveDisabled ? 0.45 : 1)
            }
        }
    }
}

// MARK: - Spending Detail View (Needs / Wants)

struct SpendingAnalysisDetailView: View {
    let data: SpendingDetailData

    @Environment(\.dismiss) private var dismiss
    @State private var dragOffset: CGFloat = 0
    @State private var selectedBarIndex: Int = 0
    @State private var selectedCategory: SpendingDetailCategory?

    private let monthLabels = ["J", "F", "M", "A", "M", "J", "J", "A", "S", "O", "N", "D"]
    private let monthsFull = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]
    private let monthsLong = ["January", "February", "March", "April", "May", "June", "July", "August", "September", "October", "November", "December"]

    private var accentColor: Color { Color(hex: data.accentColor) }

    private var maxChartValue: Double {
        let values = data.annualTrend.compactMap { $0 }
        return max(values.max() ?? 1, 1)
    }

    private var selectedMonthData: SpendingDetailMonthData? {
        data.monthlyData[selectedBarIndex]
    }

    private var selectedTotal: Double {
        selectedMonthData?.total ?? data.annualTrend[selectedBarIndex] ?? 0
    }

    private var selectedCategories: [SpendingDetailCategory] {
        (selectedMonthData?.categories ?? []).sorted { $0.amount > $1.amount }
    }

    private var selectedMonthLabel: String {
        monthsFull[selectedBarIndex]
    }

    private var selectedMonthLongLabel: String {
        monthsLong[selectedBarIndex]
    }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 24) {
                    headerSection

                    chartSection

                    categoriesSection
                }
                .padding(.horizontal, 20)
                .padding(.top, 20)
                .padding(.bottom, 100)
            }
        }
        .preferredColorScheme(.dark)
        .offset(y: dragOffset)
        .gesture(
            DragGesture()
                .onChanged { value in
                    if value.translation.height > 0 {
                        dragOffset = value.translation.height
                    }
                }
                .onEnded { value in
                    if value.translation.height > 150 {
                        dismiss()
                    } else {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                            dragOffset = 0
                        }
                    }
                }
        )
        .fullScreenCover(item: $selectedCategory) { category in
            SpendingCategoryTransactionsDetailView(
                category: category,
                monthLabel: selectedMonthLongLabel,
                groups: transactionGroups(for: category)
            )
        }
    }
}

private extension SpendingAnalysisDetailView {
    var headerSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                Text(data.title)
                    .font(.system(size: 28, weight: .bold))
                    .foregroundColor(.white)

                Spacer()

                Button(action: { dismiss() }) {
                    Image(systemName: "xmark")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.white)
                        .padding(.top, 2)
                }
                .buttonStyle(.plain)
            }

            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text(formatCurrencyNoCents(selectedTotal))
                    .font(.system(size: 32, weight: .bold))
                    .foregroundColor(.white)

                Text("spend in \(selectedMonthLabel)")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(Color(hex: "#9CA3AF"))
            }
        }
    }
}

private extension SpendingAnalysisDetailView {
    var chartSection: some View {
        chartView
            .frame(height: 220)
    }

    var chartView: some View {
        GeometryReader { geometry in
            let barAreaHeight = geometry.size.height - 30
            let barSpacing: CGFloat = 8
            let totalSpacing = barSpacing * 11
            let barWidth = (geometry.size.width - totalSpacing) / 12

            HStack(alignment: .bottom, spacing: barSpacing) {
                ForEach(0..<12, id: \.self) { index in
                    barColumn(index: index, barWidth: barWidth, maxHeight: barAreaHeight)
                        .onTapGesture {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                selectedBarIndex = index
                            }
                        }
                }
            }
        }
    }

    func barColumn(index: Int, barWidth: CGFloat, maxHeight: CGFloat) -> some View {
        let amount = data.annualTrend[index]
        let height = barHeight(for: amount, maxHeight: maxHeight)
        let isSelected = index == selectedBarIndex

        return VStack(spacing: 10) {
            RoundedRectangle(cornerRadius: 4)
                .fill(isSelected ? accentColor : Color(hex: "#D1D5DB").opacity(0.25))
                .frame(width: barWidth, height: height)
                .opacity(amount == nil ? 0.3 : 1.0)

            Text(monthLabels[index])
                .font(.system(size: 11, weight: isSelected ? .bold : .semibold))
                .foregroundColor(isSelected ? .white : Color(hex: "#9CA3AF"))
        }
        .frame(maxWidth: .infinity)
    }

    func barHeight(for amount: Double?, maxHeight: CGFloat) -> CGFloat {
        guard let amount = amount, amount > 0 else { return 16 }
        let ratio = min(amount / maxChartValue, 1.0)
        return max(16, maxHeight * CGFloat(ratio))
    }
}

private extension SpendingAnalysisDetailView {
    var categoriesSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Categories")
                .font(.system(size: 22, weight: .bold))
                .foregroundColor(.white)

            VStack(spacing: 12) {
                ForEach(selectedCategories) { category in
                    Button {
                        selectedCategory = category
                    } label: {
                        categoryCard(category: category)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    func categoryCard(category: SpendingDetailCategory) -> some View {
        GeometryReader { geometry in
            let width = geometry.size.width
            let ratio = min(max(category.percentage / 100, 0), 1)
            let fillWidth = min(width, max(56, width * CGFloat(ratio)))

            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 20)
                    .fill(Color.white.opacity(0.04))

                RoundedRectangle(cornerRadius: 20)
                    .fill(accentColor.opacity(0.82))
                    .frame(width: fillWidth)

                HStack(spacing: 12) {
                    HStack(spacing: 10) {
                        Image(systemName: category.icon)
                            .font(.system(size: 21, weight: .semibold))
                            .foregroundColor(.white)
                            .frame(width: 24)

                        Text(category.name)
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(.white)
                    }

                    Spacer()

                    VStack(alignment: .trailing, spacing: 4) {
                        Text(formatCurrency(category.amount))
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(.white)

                        Text("\(Int(category.percentage.rounded()))%")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(Color(hex: "#9CA3AF"))
                    }
                }
                .padding(.horizontal, 16)
            }
        }
        .frame(height: 84)
    }
}

private extension SpendingAnalysisDetailView {
    func formatCurrencyNoCents(_ value: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "USD"
        formatter.maximumFractionDigits = 0
        formatter.minimumFractionDigits = 0
        return formatter.string(from: NSNumber(value: value)) ?? "$0"
    }

    func formatCurrency(_ value: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "USD"
        formatter.maximumFractionDigits = 2
        formatter.minimumFractionDigits = 2
        return formatter.string(from: NSNumber(value: value)) ?? "$0.00"
    }
}

private extension SpendingAnalysisDetailView {
    static let defaultCategoryTemplates: [SpendingCategoryTransactionTemplate] = [
        SpendingCategoryTransactionTemplate(merchant: "Netflix", subtitle: "Premium Plan - Visa ending in 4242", amount: 19.99, group: .today),
        SpendingCategoryTransactionTemplate(merchant: "Spotify", subtitle: "Family Plan - Visa ending in 4242", amount: 16.99, group: .today),
        SpendingCategoryTransactionTemplate(merchant: "iCloud+", subtitle: "2TB Storage - Apple Pay", amount: 9.99, group: .yesterday),
        SpendingCategoryTransactionTemplate(merchant: "Adobe Creative Cloud", subtitle: "All Apps Plan - Visa ending in 4242", amount: 54.99, group: .midMonth),
        SpendingCategoryTransactionTemplate(merchant: "ChatGPT Plus", subtitle: "Monthly Subscription - Apple Pay", amount: 20.00, group: .midMonth),
        SpendingCategoryTransactionTemplate(merchant: "YouTube Premium", subtitle: "Individual - Visa ending in 4242", amount: 13.99, group: .midMonth)
    ]

    static let categoryTransactionTemplates: [String: [SpendingCategoryTransactionTemplate]] = [
        "Rent & Housing": [
            SpendingCategoryTransactionTemplate(merchant: "Luna Apartments", subtitle: "Monthly Rent - ACH Transfer", amount: 1450.00, group: .today),
            SpendingCategoryTransactionTemplate(merchant: "City Utilities", subtitle: "Water and Gas - AutoPay", amount: 126.40, group: .yesterday),
            SpendingCategoryTransactionTemplate(merchant: "Home Insurance", subtitle: "Policy Renewal - Visa ending in 4242", amount: 84.70, group: .midMonth),
            SpendingCategoryTransactionTemplate(merchant: "Building Maintenance", subtitle: "Service Fee - Debit Card", amount: 62.90, group: .midMonth),
            SpendingCategoryTransactionTemplate(merchant: "Renter Add-on", subtitle: "Appliance Coverage - Apple Pay", amount: 28.50, group: .midMonth)
        ],
        "Groceries": [
            SpendingCategoryTransactionTemplate(merchant: "Whole Foods", subtitle: "Weekly Groceries - Apple Pay", amount: 86.32, group: .today),
            SpendingCategoryTransactionTemplate(merchant: "Trader Joe's", subtitle: "Household Refill - Visa ending in 4242", amount: 72.15, group: .today),
            SpendingCategoryTransactionTemplate(merchant: "Costco", subtitle: "Monthly Stock-up - Visa ending in 4242", amount: 214.78, group: .yesterday),
            SpendingCategoryTransactionTemplate(merchant: "Safeway", subtitle: "Fresh Produce - Apple Pay", amount: 54.20, group: .midMonth),
            SpendingCategoryTransactionTemplate(merchant: "H Mart", subtitle: "Pantry Items - Debit Card", amount: 38.35, group: .midMonth)
        ],
        "Utilities": [
            SpendingCategoryTransactionTemplate(merchant: "Pacific Electric", subtitle: "Monthly Bill - AutoPay", amount: 118.30, group: .today),
            SpendingCategoryTransactionTemplate(merchant: "City Water", subtitle: "Utilities Bill - AutoPay", amount: 62.10, group: .yesterday),
            SpendingCategoryTransactionTemplate(merchant: "Comcast", subtitle: "Home Internet - Visa ending in 4242", amount: 79.99, group: .midMonth),
            SpendingCategoryTransactionTemplate(merchant: "T-Mobile", subtitle: "Phone Plan - Apple Pay", amount: 44.50, group: .midMonth)
        ],
        "Transportation": [
            SpendingCategoryTransactionTemplate(merchant: "Shell", subtitle: "Fuel - Visa ending in 4242", amount: 52.30, group: .today),
            SpendingCategoryTransactionTemplate(merchant: "Caltrain", subtitle: "Monthly Pass - Apple Pay", amount: 89.00, group: .yesterday),
            SpendingCategoryTransactionTemplate(merchant: "Uber", subtitle: "Commute Ride - Apple Pay", amount: 26.40, group: .midMonth),
            SpendingCategoryTransactionTemplate(merchant: "City Parking", subtitle: "Garage Fee - Debit Card", amount: 18.75, group: .midMonth)
        ],
        "Health & Fitness": [
            SpendingCategoryTransactionTemplate(merchant: "Equinox", subtitle: "Gym Membership - Visa ending in 4242", amount: 69.00, group: .today),
            SpendingCategoryTransactionTemplate(merchant: "CVS Pharmacy", subtitle: "Prescription Refill - Apple Pay", amount: 24.60, group: .yesterday),
            SpendingCategoryTransactionTemplate(merchant: "One Medical", subtitle: "Virtual Visit - Apple Pay", amount: 38.00, group: .midMonth),
            SpendingCategoryTransactionTemplate(merchant: "Vitamin Shoppe", subtitle: "Supplements - Debit Card", amount: 16.40, group: .midMonth)
        ],
        "Dining & Social": [
            SpendingCategoryTransactionTemplate(merchant: "Blue Bottle", subtitle: "Coffee Meetup - Apple Pay", amount: 14.90, group: .today),
            SpendingCategoryTransactionTemplate(merchant: "Sushi Roku", subtitle: "Dinner with Friends - Visa ending in 4242", amount: 86.40, group: .today),
            SpendingCategoryTransactionTemplate(merchant: "Sweetgreen", subtitle: "Lunch - Apple Pay", amount: 17.80, group: .yesterday),
            SpendingCategoryTransactionTemplate(merchant: "Nobu", subtitle: "Weekend Social - Visa ending in 4242", amount: 164.20, group: .midMonth),
            SpendingCategoryTransactionTemplate(merchant: "Speakeasy SF", subtitle: "Cocktails - Debit Card", amount: 72.50, group: .midMonth)
        ],
        "Shopping": [
            SpendingCategoryTransactionTemplate(merchant: "Amazon", subtitle: "Home Accessories - Visa ending in 4242", amount: 74.30, group: .today),
            SpendingCategoryTransactionTemplate(merchant: "Uniqlo", subtitle: "Everyday Basics - Apple Pay", amount: 42.00, group: .yesterday),
            SpendingCategoryTransactionTemplate(merchant: "Sephora", subtitle: "Skin Care - Apple Pay", amount: 58.40, group: .midMonth),
            SpendingCategoryTransactionTemplate(merchant: "Nike", subtitle: "Training Shoes - Visa ending in 4242", amount: 96.70, group: .midMonth),
            SpendingCategoryTransactionTemplate(merchant: "Target", subtitle: "Small Essentials - Debit Card", amount: 36.20, group: .midMonth)
        ],
        "Subscriptions": [
            SpendingCategoryTransactionTemplate(merchant: "Netflix", subtitle: "Premium Plan - Visa ending in 4242", amount: 19.99, group: .today),
            SpendingCategoryTransactionTemplate(merchant: "Spotify", subtitle: "Family Plan - Visa ending in 4242", amount: 16.99, group: .today),
            SpendingCategoryTransactionTemplate(merchant: "iCloud+", subtitle: "2TB Storage - Apple Pay", amount: 9.99, group: .yesterday),
            SpendingCategoryTransactionTemplate(merchant: "Adobe Creative Cloud", subtitle: "All Apps Plan - Visa ending in 4242", amount: 54.99, group: .midMonth),
            SpendingCategoryTransactionTemplate(merchant: "ChatGPT Plus", subtitle: "Monthly Subscription - Apple Pay", amount: 20.00, group: .midMonth),
            SpendingCategoryTransactionTemplate(merchant: "YouTube Premium", subtitle: "Individual - Visa ending in 4242", amount: 13.99, group: .midMonth)
        ],
        "Travel": [
            SpendingCategoryTransactionTemplate(merchant: "United Airlines", subtitle: "Trip Deposit - Visa ending in 4242", amount: 118.00, group: .today),
            SpendingCategoryTransactionTemplate(merchant: "Booking.com", subtitle: "Hotel Reservation - Apple Pay", amount: 76.40, group: .yesterday),
            SpendingCategoryTransactionTemplate(merchant: "Lyft", subtitle: "Airport Ride - Apple Pay", amount: 34.25, group: .midMonth),
            SpendingCategoryTransactionTemplate(merchant: "Delta", subtitle: "Seat Upgrade - Visa ending in 4242", amount: 46.30, group: .midMonth)
        ],
        "Hobbies & Leisure": [
            SpendingCategoryTransactionTemplate(merchant: "Steam", subtitle: "Game Purchase - Visa ending in 4242", amount: 32.00, group: .today),
            SpendingCategoryTransactionTemplate(merchant: "AMC Theatres", subtitle: "Movie Tickets - Apple Pay", amount: 28.70, group: .yesterday),
            SpendingCategoryTransactionTemplate(merchant: "Michaels", subtitle: "Art Supplies - Debit Card", amount: 34.90, group: .midMonth),
            SpendingCategoryTransactionTemplate(merchant: "Kindle", subtitle: "Book Purchase - Apple Pay", amount: 14.20, group: .midMonth)
        ]
    ]

    func transactionGroups(for category: SpendingDetailCategory) -> [SpendingCategoryTransactionGroup] {
        let templates = Self.categoryTransactionTemplates[category.name] ?? Self.defaultCategoryTemplates
        let baseTotal = max(templates.reduce(0) { $0 + $1.amount }, 1)
        let scale = category.amount / baseTotal
        let monthToken = monthsFull[selectedBarIndex].uppercased()

        return SpendingCategoryTransactionGroupType.allCases.compactMap { group in
            let items = templates.enumerated().compactMap { index, template -> SpendingCategoryTransaction? in
                guard template.group == group else { return nil }
                return SpendingCategoryTransaction(
                    id: "\(category.id)-\(group.rawValue)-\(index)",
                    merchant: template.merchant,
                    subtitle: template.subtitle,
                    amount: roundedToCents(template.amount * scale)
                )
            }
            guard !items.isEmpty else { return nil }
            return SpendingCategoryTransactionGroup(
                id: "\(category.id)-\(group.rawValue)",
                title: groupTitle(for: group, monthToken: monthToken),
                items: items
            )
        }
    }

    func groupTitle(for group: SpendingCategoryTransactionGroupType, monthToken: String) -> String {
        switch group {
        case .today:
            return "TODAY"
        case .yesterday:
            return "YESTERDAY"
        case .midMonth:
            return "\(monthToken) 15"
        }
    }

    func roundedToCents(_ value: Double) -> Double {
        (value * 100).rounded() / 100
    }
}

private enum SpendingCategoryTransactionGroupType: String, CaseIterable {
    case today
    case yesterday
    case midMonth
}

private struct SpendingCategoryTransactionTemplate {
    let merchant: String
    let subtitle: String
    let amount: Double
    let group: SpendingCategoryTransactionGroupType
}

private struct SpendingCategoryTransaction: Identifiable {
    let id: String
    let merchant: String
    let subtitle: String
    let amount: Double
}

private struct SpendingCategoryTransactionGroup: Identifiable {
    let id: String
    let title: String
    let items: [SpendingCategoryTransaction]
}

private struct SpendingCategoryTransactionsDetailView: View {
    let category: SpendingDetailCategory
    let monthLabel: String
    let groups: [SpendingCategoryTransactionGroup]

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 22) {
                    backButton

                    headerSection

                    groupsSection
                }
                .padding(.horizontal, 20)
                .padding(.top, 18)
                .padding(.bottom, 100)
            }
        }
        .preferredColorScheme(.dark)
    }
}

private extension SpendingCategoryTransactionsDetailView {
    var backButton: some View {
        Button(action: { dismiss() }) {
            Image(systemName: "chevron.left")
                .font(.system(size: 26, weight: .semibold))
                .foregroundColor(.white)
                .padding(.vertical, 8)
        }
        .buttonStyle(.plain)
    }

    var headerSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(category.name)
                .font(.system(size: 28, weight: .bold))
                .foregroundColor(.white)

            Text(formatCurrency(category.amount))
                .font(.system(size: 48, weight: .bold))
                .foregroundColor(.white)

            Text("Total spend in \(monthLabel)")
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(Color(hex: "#94A3B8"))
        }
    }

    var groupsSection: some View {
        VStack(alignment: .leading, spacing: 22) {
            ForEach(groups) { group in
                VStack(alignment: .leading, spacing: 10) {
                    Text(group.title)
                        .font(.system(size: 14, weight: .bold))
                        .tracking(2)
                        .foregroundColor(Color(hex: "#94A3B8"))

                    VStack(spacing: 0) {
                        ForEach(Array(group.items.enumerated()), id: \.element.id) { index, item in
                            transactionRow(item)

                            if index < group.items.count - 1 {
                                Divider()
                                    .background(Color.white.opacity(0.10))
                            }
                        }
                    }
                }
            }
        }
    }

    func transactionRow(_ item: SpendingCategoryTransaction) -> some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(item.merchant)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white)

                Text(item.subtitle)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(Color(hex: "#94A3B8"))
            }

            Spacer()

            Text(formatCurrency(item.amount))
                .font(.system(size: 16, weight: .bold))
                .foregroundColor(.white)
                .padding(.top, 2)
        }
        .padding(.vertical, 14)
    }

    func formatCurrency(_ value: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "USD"
        formatter.maximumFractionDigits = 2
        formatter.minimumFractionDigits = 2
        return formatter.string(from: NSNumber(value: value)) ?? "$0.00"
    }
}

#Preview("Spending Needs") {
    SpendingAnalysisDetailView(data: MockData.needsSpendingDetail)
}

#Preview("Spending Wants") {
    SpendingAnalysisDetailView(data: MockData.wantsSpendingDetail)
}

// MARK: - Spending Detail View (Total)

struct TotalSpendingAnalysisDetailView: View {
    let data: TotalSpendingDetailData

    @Environment(\.dismiss) private var dismiss
    @State private var dragOffset: CGFloat = 0
    @State private var selectedBarIndex: Int = 0

    private let monthLabels = ["J", "F", "M", "A", "M", "J", "J", "A", "S", "O", "N", "D"]
    private let monthsFull = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]

    private let needsColor = Color(hex: "#A78BFA")
    private let wantsColor = Color(hex: "#93C5FD")

    private var maxChartValue: Double {
        let values = data.annualTrend.compactMap { $0 }
        return max(values.max() ?? 1, 1)
    }

    private var selectedMonthData: TotalSpendingMonthData? {
        data.monthlyData[selectedBarIndex]
    }

    private var selectedTotal: Double {
        selectedMonthData?.total ?? data.annualTrend[selectedBarIndex] ?? 0
    }

    private var selectedMonthLabel: String {
        monthsFull[selectedBarIndex]
    }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 24) {
                    headerSection

                    chartSection

                    sourcesSection
                }
                .padding(.horizontal, 20)
                .padding(.top, 20)
                .padding(.bottom, 100)
            }
        }
        .preferredColorScheme(.dark)
        .offset(y: dragOffset)
        .gesture(
            DragGesture()
                .onChanged { value in
                    if value.translation.height > 0 {
                        dragOffset = value.translation.height
                    }
                }
                .onEnded { value in
                    if value.translation.height > 150 {
                        dismiss()
                    } else {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                            dragOffset = 0
                        }
                    }
                }
        )
    }
}

private extension TotalSpendingAnalysisDetailView {
    var headerSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                Text(data.title)
                    .font(.system(size: 28, weight: .bold))
                    .foregroundColor(.white)

                Spacer()

                Button(action: { dismiss() }) {
                    Image(systemName: "xmark")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.white)
                        .padding(.top, 2)
                }
                .buttonStyle(.plain)
            }

            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text(formatCurrencyNoCents(selectedTotal))
                    .font(.system(size: 32, weight: .bold))
                    .foregroundColor(.white)

                Text("spend in \(selectedMonthLabel)")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(Color(hex: "#9CA3AF"))
            }
        }
    }
}

private extension TotalSpendingAnalysisDetailView {
    var chartSection: some View {
        chartView
            .frame(height: 220)
    }

    var chartView: some View {
        GeometryReader { geometry in
            let barAreaHeight = geometry.size.height - 30
            let barSpacing: CGFloat = 8
            let totalSpacing = barSpacing * 11
            let barWidth = (geometry.size.width - totalSpacing) / 12

            HStack(alignment: .bottom, spacing: barSpacing) {
                ForEach(0..<12, id: \.self) { index in
                    barColumn(index: index, barWidth: barWidth, maxHeight: barAreaHeight)
                        .onTapGesture {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                selectedBarIndex = index
                            }
                        }
                }
            }
        }
    }

    func barColumn(index: Int, barWidth: CGFloat, maxHeight: CGFloat) -> some View {
        let amount = data.annualTrend[index]
        let height = barHeight(for: amount, maxHeight: maxHeight)
        let isSelected = index == selectedBarIndex

        return VStack(spacing: 10) {
            Group {
                if isSelected {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(
                            LinearGradient(
                                colors: [needsColor, wantsColor],
                                startPoint: .bottom,
                                endPoint: .top
                            )
                        )
                } else {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color(hex: "#D1D5DB").opacity(0.25))
                }
            }
            .frame(width: barWidth, height: height)
            .opacity(amount == nil ? 0.3 : 1.0)

            Text(monthLabels[index])
                .font(.system(size: 11, weight: isSelected ? .bold : .semibold))
                .foregroundColor(isSelected ? .white : Color(hex: "#9CA3AF"))
        }
        .frame(maxWidth: .infinity)
    }

    func barHeight(for amount: Double?, maxHeight: CGFloat) -> CGFloat {
        guard let amount = amount, amount > 0 else { return 16 }
        let ratio = min(amount / maxChartValue, 1.0)
        return max(16, maxHeight * CGFloat(ratio))
    }
}

private extension TotalSpendingAnalysisDetailView {
    var sourcesSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Sources")
                .font(.system(size: 22, weight: .bold))
                .foregroundColor(.white)

            if let monthData = selectedMonthData {
                VStack(spacing: 12) {
                    sourceCard(
                        name: "Needs",
                        amount: monthData.needsAmount,
                        percentage: monthData.needsPercentage,
                        color: needsColor
                    )

                    sourceCard(
                        name: "Wants",
                        amount: monthData.wantsAmount,
                        percentage: monthData.wantsPercentage,
                        color: wantsColor
                    )
                }
            }
        }
    }

    func sourceCard(name: String, amount: Double, percentage: Double, color: Color) -> some View {
        HStack(spacing: 14) {
            RoundedRectangle(cornerRadius: 4)
                .fill(color)
                .frame(width: 5, height: 56)

            VStack(alignment: .leading, spacing: 4) {
                Text(name)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(.white)

                Text("\(selectedMonthLabel) 2026")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(Color(hex: "#6B7280"))
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 4) {
                Text(formatCurrency(amount))
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(.white)

                Text("\(Int(percentage.rounded()))%")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(Color(hex: "#9CA3AF"))
            }
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(color.opacity(0.35))
        )
    }
}

private extension TotalSpendingAnalysisDetailView {
    func formatCurrencyNoCents(_ value: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "USD"
        formatter.maximumFractionDigits = 0
        formatter.minimumFractionDigits = 0
        return formatter.string(from: NSNumber(value: value)) ?? "$0"
    }

    func formatCurrency(_ value: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "USD"
        formatter.maximumFractionDigits = 2
        formatter.minimumFractionDigits = 2
        return formatter.string(from: NSNumber(value: value)) ?? "$0.00"
    }
}

#Preview("Spending Total") {
    TotalSpendingAnalysisDetailView(data: MockData.totalSpendingDetail)
}
