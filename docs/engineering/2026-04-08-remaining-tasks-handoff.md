# Flamora — 剩余任务 Handoff 文件
**生成时间：** 2026-04-08  
**项目路径：** `/Users/frankli/Desktop/关羽与吕布/Flamora app`  
**Xcode 项目：** `Flamora app.xcodeproj`  
**目标平台：** iOS 17+，SwiftUI，纯 Apple 框架，暗色主题

---

## 背景摘要

已完成的工作（**不要重复**）：

| 阶段 | 内容 | 状态 |
|---|---|---|
| Design Tokens | `Style/Colors.swift` 新增 Hero/TabBar/SimDetails token | ✅ 完成 |
| Design Tokens | 新建 `Style/Shadows.swift`（glassCardShadow/simDetailsShadow/tabBarShadow ViewModifier） | ✅ 完成 |
| Phase 0 DRY | 新建 `View/Journey/JourneyViewModel.swift`（@Observable，接管 Home 数据加载） | ✅ 完成 |
| Phase 0 DRY | 新建 `Helpers/NumberFormatter+App.swift`（compactCurrency/currency/currentMonthString） | ✅ 完成 |
| Phase 0 DRY | 新建 `View/Journey/LegendItemView.swift`（dot/dash 两种图例样式） | ✅ 完成 |
| Phase 0 DRY | `JourneyView.swift` 重构：使用 `JourneyViewModel`，`.task(id: journeyReloadTrigger)` 模式 | ✅ 完成 |
| Phase 0 DRY | `SimulatorView.swift` 重构：使用 `NumberFormatter.currency()`、`LegendItemView` | ✅ 完成 |
| Phase 1 | `MainTabView.swift`：HomeState enum、highPriorityGesture、drag-linked expansion 已存在 | ✅ 已存在 |
| Phase 2-a | `JourneyView.swift`：已用 `JourneyReloadTrigger` + `.task(id:)` | ✅ 已存在 |
| Phase 2-b | OB_WelcomeView Timer：`invalidateBudgetAnimationTimers()` 已在 onDisappear 调用 | ✅ 已存在 |
| Phase 3-a/b/c | SimulatorView token 替换、UIScreen.main 已无硬编码 | ✅ 已存在 |

---

## 剩余任务（5 项）

### Task 1 — OB 文件 `.cornerRadius()` 替换（10 分钟）

**背景：** SwiftUI 中 `.cornerRadius()` 已 deprecated，应改用 `.clipShape(RoundedRectangle(...))`。

**文件 1：** `View/Onboarding/Views/OB_SignInView.swift`

搜索：`.cornerRadius(AppRadius.md)`（共 2 处，在 124、134 行附近）

改为：
```swift
// 改前
.cornerRadius(AppRadius.md)

// 改后
.clipShape(RoundedRectangle(cornerRadius: AppRadius.md))
```

**文件 2：** `View/Onboarding/Views/OB_PaywallView.swift`

搜索：`.cornerRadius(6)`（175 行附近）—— **注意：这里是硬编码数值**

改为：
```swift
// 改前
.cornerRadius(6)

// 改后（AppRadius.sm = 6，确认后使用 token）
.clipShape(RoundedRectangle(cornerRadius: AppRadius.sm))
```

> 先打开 `Style/Radius.swift` 确认 `AppRadius.sm` 的值是否为 6，如果不一致则新增 token 或用最接近的。

**不需要修改 project.pbxproj**（修改的是已有文件）。

---

### Task 2 — Tab 内容 cross-fade 动画（15 分钟）

**背景：** `MainTabView` 的 tab 切换目前是硬切，需要加 0.2s cross-fade。

**文件：** `View/MainTabView.swift`

定位到 `HomeBottomSheet` 结构体（约 272 行），找到：
```swift
Group {
    switch selectedTab {
    case .cashflow:
        CashflowView()
    case .investment:
        InvestmentView()
    case .settings:
        SettingsView(isEmbeddedInSheet: true)
    }
}
.frame(maxWidth: .infinity, maxHeight: .infinity)
.clipped()
```

改为：
```swift
Group {
    switch selectedTab {
    case .cashflow:
        CashflowView()
    case .investment:
        InvestmentView()
    case .settings:
        SettingsView(isEmbeddedInSheet: true)
    }
}
.id(selectedTab)                    // 触发视图替换（cross-fade 必需）
.transition(.opacity)
.animation(.easeInOut(duration: 0.2), value: selectedTab)
.frame(maxWidth: .infinity, maxHeight: .infinity)
.clipped()
```

**不需要修改 project.pbxproj**。

---

### Task 3 — "Back to Home" Sheet Peek Label（30 分钟）

**背景：** 当用户往下拖 sheet（接近进入 simulator 的临界点），应 fade in 文字提示 "Back to Home"，progress > 0.72 时可见。

**文件：** `View/MainTabView.swift`

**Step 1：** 给 `HomeBottomSheet` 传入 drag progress。

找到 `HomeBottomSheet` 结构体定义（约 272 行）：
```swift
private struct HomeBottomSheet: View {
    let height: CGFloat
    let selectedTab: MainTabItem
    let sheetDragGesture: AnyGesture<DragGesture.Value>
```

改为：
```swift
private struct HomeBottomSheet: View {
    let height: CGFloat
    let selectedTab: MainTabItem
    let sheetDragGesture: AnyGesture<DragGesture.Value>
    let dragProgress: CGFloat          // 新增：0 = resting, 1 = fully collapsed
```

**Step 2：** 更新 `HomeBottomSheet` 的初始化调用（在 `MainTabView.body` 里，约 59 行）：
```swift
// 改前
HomeBottomSheet(
    height: sheetHeight,
    selectedTab: selectedTab,
    sheetDragGesture: sheetDragGesture
)

// 改后
HomeBottomSheet(
    height: sheetHeight,
    selectedTab: selectedTab,
    sheetDragGesture: sheetDragGesture,
    dragProgress: sheetDragNormalizedProgress()
)
```

**Step 3：** 在 `HomeBottomSheet.body` 的把手行（HStack 那段，约 279 行）里加 peek label：
```swift
HStack {
    Capsule()
        .fill(AppColors.surfaceBorder)
        .frame(width: 36, height: 4)
}
.frame(maxWidth: .infinity)
.frame(height: 24)
.contentShape(Rectangle())
.highPriorityGesture(sheetDragGesture)
.overlay(alignment: .center) {    // 新增：peek label overlay
    let labelOpacity = max(0, min(1, (dragProgress - 0.72) / 0.28))
    if labelOpacity > 0 {
        Text("Back to Home")
            .font(.footnoteRegular)
            .foregroundStyle(AppColors.textSecondary)
            .opacity(labelOpacity)
            .allowsHitTesting(false)
    }
}
```

**不需要修改 project.pbxproj**。

---

### Task 4 — ZStack Hero 重构（大任务，1-2 小时）

**背景：** 设计稿要求 JourneyView 内的 Hero card 使用 ZStack 构建，topbar 固定顶部，hero content 独立 opacity 动画。当前 Hero 完全由 MainTabView 的 `HomeHeroCardSurface` 管理。

**目标架构：**
- Hero 背景渐变 (`investHeroGradient`)：全时可见
- TopBar（`TopHeaderBar`）：fixed top，z-index 最高
- Hero content（文字、进度条等）：独立 opacity，可随动画淡入淡出

**参考：** `design-reference/home-rebuild-glass-prototype.html` 中 `.hero-section` 部分的 CSS 结构。

**文件：** `View/Journey/JourneyView.swift`（主要）、`View/MainTabView.swift`（hero surface 引用）

**具体改法：**

在 `JourneyView.body` 的最外层 `GeometryReader` 内，将当前的 `ScrollView` 包裹在 `ZStack` 中：

```swift
var body: some View {
    GeometryReader { proxy in
        ZStack(alignment: .top) {
            // Layer 1: Hero gradient background（固定，不滚动）
            LinearGradient(
                colors: AppColors.investHeroGradient,
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .frame(height: 220)   // Hero 区高度，与 HomeLayout.heroFullHeight 对齐
            .ignoresSafeArea(edges: .top)

            // Layer 2: Scrollable content
            ScrollView(showsIndicators: false) {
                VStack(spacing: AppSpacing.lg) {
                    // ... 原有内容，顶部留出 hero 高度的 padding ...
                    Color.clear.frame(height: 220)  // 占位，让内容从 hero 下方开始
                    // ... 原有卡片 ...
                }
                .frame(minHeight: proxy.size.height, alignment: .top)
                .padding(.top, AppSpacing.md)
                .padding(.bottom, max(bottomPadding, AppSpacing.lg))
            }
        }
    }
    // ... task/onReceive modifiers 保持不变 ...
}
```

> ⚠️ 注意：`TopHeaderBar` 由 `MainTabView` 统一管理，**不要**在 JourneyView 内重复添加。只需在 JourneyView 顶部留出 `TopHeaderBar.height + AppSpacing.md` 的 padding 空间。

---

### Task 5 — 首次进场动画（大任务，1 小时）

**背景：** App 首次加载 Home 时，Hero 应先 fade in，然后 Sheet 从底部 slide+fade in。

**时序：**
1. t=0ms：Hero content fade in（200ms，easeOut）
2. t=120ms：Sheet 从底部 slide+fade in（320ms，easeOut，偏移 40pt）

**文件：** `View/Journey/JourneyView.swift`

在 `JourneyView` 中新增 2 个状态变量：
```swift
@State private var heroVisible = false
@State private var sheetVisible = false
```

给 Hero card 加 opacity + 给整个 content VStack 加 offset/opacity：
```swift
// Hero 部分
FIRECountdownCard(...)
    .opacity(heroVisible ? 1 : 0)
    .animation(.easeOut(duration: 0.2), value: heroVisible)

// Sheet content（GuidedSetupCard / HomeActionStrip / HomeSandboxShell）
Group {
    if viewModel.homeSetupStage.needsGuidedCard {
        GuidedSetupCard(...)
    } else {
        HomeActionStrip(...)
    }
    HomeSandboxShell(...)
}
.opacity(sheetVisible ? 1 : 0)
.offset(y: sheetVisible ? 0 : 40)
.animation(.easeOut(duration: 0.32), value: sheetVisible)
```

在 `.task(id: journeyReloadTrigger)` 的 `await viewModel.loadData()` 完成后触发：
```swift
.task(id: journeyReloadTrigger) {
    await viewModel.loadData()
    // 首次加载完成后触发进场动画
    if !heroVisible {
        withAnimation(.easeOut(duration: 0.2)) { heroVisible = true }
        try? await Task.sleep(for: .milliseconds(120))
        withAnimation(.easeOut(duration: 0.32)) { sheetVisible = true }
    }
}
```

---

## 执行顺序建议

```
Task 1 → Task 2 → Task 3 → Task 4 → Task 5
（每个 task 完成后 Build & Run 验证，不要堆积）
```

---

## 关键约束（每次写代码前检查）

### 字体 — 必须用 token
```swift
// ❌ 禁止
.font(.system(size: 14, weight: .semibold))
// ✅ 必须
.font(.inlineLabel)
```

### 颜色 — 必须用 token
```swift
// ❌ 禁止（在 View 里直接写）
Color.white.opacity(0.3)
// ✅ 必须
AppColors.overlayWhiteForegroundSoft
```
> **例外：** `Color.black.opacity(0)` / `Color.clear` 用于渐变透明起点，可以保留。

### 间距 — 必须用 token
```swift
// ❌ 禁止
.padding(16)
// ✅ 必须
.padding(AppSpacing.md)
```

### 圆角 — 必须用 clipShape + token
```swift
// ❌ 禁止
.cornerRadius(12)
// ✅ 必须
.clipShape(RoundedRectangle(cornerRadius: AppRadius.card))
```

---

## 关键文件路径

| 文件 | 用途 |
|---|---|
| `Style/Colors.swift` | 颜色 token（AppColors）|
| `Style/Typography.swift` | 字体 token |
| `Style/Spacing.swift` | 间距 token（AppSpacing）|
| `Style/Radius.swift` | 圆角 token（AppRadius）|
| `Style/Shadows.swift` | 阴影 ViewModifier（glassCardShadow 等）|
| `View/MainTabView.swift` | 主导航容器，HomeState enum，tab bar，Hero surface |
| `View/Journey/JourneyView.swift` | Home screen 内容视图 |
| `View/Journey/JourneyViewModel.swift` | Home 数据 ViewModel（@Observable）|
| `Helpers/NumberFormatter+App.swift` | 货币/日期格式化工具 |
| `View/Journey/LegendItemView.swift` | 图例组件（dot/dash 样式）|
| `design-reference/home-rebuild-glass-prototype.html` | **视觉设计源文件**（CSS 值直接参考）|

---

## 新增 Swift 文件时的注意事项

如果 Task 4/5 中需要抽取新的 View 文件，必须同时更新 `Flamora app.xcodeproj/project.pbxproj`，否则 Xcode 不会编译新文件。

更新 pbxproj 的方法：
1. 找到 `/* Begin PBXFileReference section */` — 添加文件引用
2. 找到 `/* Begin PBXBuildFile section */` — 添加 build 引用  
3. 找到对应的 `PBXGroup`（按文件所在目录）— 添加到 `children` 列表

参考已有条目格式（搜索 `LegendItemView.swift` 找到最近添加的例子）。

---

*文件由 Claude（claude-4.6-sonnet-medium-thinking）自动生成，基于 Flamora 项目实际代码检查结果。*
