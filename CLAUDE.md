# Flamora — Claude 工作规范

## 项目信息
- iOS SwiftUI app（FIRE 财务自由追踪器）
- 后端：Supabase Functions
- 暗色主题，火焰渐变（#A78BFA → #FCA5A5 → #FCD34D）
- 不使用第三方库（纯 Apple 框架）
- 模拟器名称：iPhone 17 / iPhone 17 Pro / iPhone 17 Pro Max

---

## ⛔ 硬编码禁令（每次写代码都要检查）

### 字体
```swift
// ❌ 禁止
.font(.system(size: 14, weight: .semibold))
.font(.system(size: 28, weight: .bold))

// ✅ 必须用 token
.font(.inlineLabel)
.font(.cardFigurePrimary)
```

### 颜色
```swift
// ❌ 禁止
Color.white
Color.white.opacity(0.3)
Color.black.opacity(0.4)

// ✅ 必须用 token
AppColors.textPrimary
AppColors.overlayWhiteForegroundSoft
AppColors.cardShadow
```
> 例外：渐变的透明起点 `Color.black.opacity(0)` / `Color.clear` 可以保留，这是 SwiftUI 渐变的技术需要。

### 间距
```swift
// ❌ 禁止
.padding(16)
.padding(.horizontal, 20)
VStack(spacing: 12)

// ✅ 必须用 token
.padding(AppSpacing.md)
.padding(.horizontal, AppSpacing.cardPadding)
VStack(spacing: AppSpacing.cardGap)
```

### 圆角
```swift
// ❌ 禁止
.cornerRadius(12)
.clipShape(RoundedRectangle(cornerRadius: 16))

// ✅ 必须用 token
.clipShape(RoundedRectangle(cornerRadius: AppRadius.card))
```

---

## 换字体（整个 app）

**只需说：** "把 app 字体换成 [字体名]"

**改动位置：** `Style/Typography.swift` → `appFont()` 函数，一行搞定：

```swift
// 当前（SF Pro 系统默认）
private extension Font {
    static func appFont(_ size: CGFloat, _ weight: Font.Weight) -> Font {
        .system(size: size, weight: weight)
    }
}

// 换成 SF Rounded（圆润感）
.system(size: size, weight: weight, design: .rounded)

// 换成自定义字体
Font(UIFont(name: "Inter-Regular", size: size) ?? ...)
```

> `obQuestion`（PlayfairDisplay）是 Onboarding 专用衬线字体，**不受** `appFont()` 控制，需单独指定。

---

## 改字号 / 字重

**改某个层级的字号：** `Style/Typography.swift` → `AppTypography` 里的常量
```swift
// 例：正文字号从 16 改成 17
static let body: CGFloat = 17   // 改这一行，所有 .bodyRegular / .bodySemibold 自动更新
```

**改某个 token 的字重：** `Style/Typography.swift` → 找到对应的 token 改 weight
```swift
// 例：h3 从 semibold 改成 bold
static var h3: Font { appFont(AppTypography.h3, .bold) }
```

---

## 新增 token（当现有 token 无法覆盖新场景）

在 `Style/Typography.swift` 对应 MARK 区域添加：
```swift
static var myNewToken: Font { appFont(XX, .weight) }
```

**添加前先确认：**
1. 现有 32 个 token 里是否已有合适的？（查下方速查表）
2. 新 token 的字号是否在标准尺寸层级内？（10/12/13/14/15/16/17/18/20/22/24/28/32/40/48）
3. 避免创建"只用一次"的 token

---

## Font Token 速查表

| Token | 字号 | 字重 | 典型用途 |
|---|---|---|---|
| `.display` | 40 | bold | 大型展示标题 |
| `.h1` | 32 | bold | 页面主标题 |
| `.h2` | 24 | bold | 二级标题 |
| `.h3` | 20 | semibold | 三级标题、报价正文 |
| `.h4` | 18 | semibold | 四级标题 |
| `.detailSheetTitle` | 32 | bold | Sheet 大标题（同 h1）|
| `.detailTitle` | 22 | bold | Sheet 子标题 |
| `.bodyRegular` | 16 | regular | 正文 |
| `.bodySemibold` | 16 | semibold | 强调正文 |
| `.bodySmall` | 14 | regular | 小号正文 |
| `.bodySmallSemibold` | 14 | semibold | 强调小正文 |
| `.inlineLabel` | 14 | medium | 行内标签、次级行 |
| `.inlineFigureBold` | 14 | bold | 行内数字强调 |
| `.supportingText` | 15 | regular | CTA 副文案 |
| `.figureSecondarySemibold` | 15 | semibold | 行汇总标签 |
| `.cardFigureSecondary` | 15 | bold | 卡片副数字 |
| `.statRowSemibold` | 17 | semibold | 统计行强调 |
| `.fieldBodyMedium` | 17 | medium | 输入框正文 |
| `.cardFigurePrimary` | 28 | bold | 卡片主数字 |
| `.currencyHero` | 48 | bold | 大金额展示 |
| `.footnoteRegular` | 13 | regular | 脚注 |
| `.footnoteSemibold` | 13 | semibold | 强调脚注 |
| `.footnoteBold` | 13 | bold | 卡片紧凑 chrome |
| `.caption` | 12 | regular | 注释 |
| `.smallLabel` | 12 | semibold | 紧凑标签 |
| `.label` | 10 | semibold | 极小标签 |
| `.miniLabel` | 9 | semibold | 徽章、pill |
| `.cardHeader` | 11 | bold | 全大写卡片标题 |
| `.cardRowMeta` | 11 | medium | 行元信息 |
| `.sheetPrimaryButton` | 18 | bold | Sheet 主按钮 |
| `.sheetCloseGlyph` | 28 | regular | 关闭按钮 × |
| `.chromeIconMedium` | 18 | medium | Tab bar 图标 |
| `.navChevron` | 26 | semibold | 全屏返回按钮 |
| `.categoryRowIcon` | 21 | semibold | 列表前置图标 |
| `.quoteBody` | 20 | bold | 引用卡片正文 |
| `.obQuestion` | 24 | semibold | OB 问题标题（PlayfairDisplay）|

---

## Design System 文件位置

| 文件 | 内容 |
|---|---|
| `Style/Typography.swift` | 字体 token + 尺寸常量 + `appFont()` 入口 |
| `Style/Colors.swift` | 颜色 token（AppColors）|
| `Style/Spacing.swift` | 间距 token（AppSpacing）|
| `Style/Radius.swift` | 圆角 token（AppRadius）|

---

## 架构说明

- 入口：`Flamora_appApp.swift` → `ContentView` → `OnboardingContainerView` 或 `MainTabView`
- Onboarding 数据：`OnboardingData`（Observable class）
- API：`APIService.shared`（Supabase）
- 新增 Swift 文件后需手动更新 `project.pbxproj`

---

## 按钮样式（主 CTA）

白底黑字，高度 56pt，圆角 `AppRadius.button`
