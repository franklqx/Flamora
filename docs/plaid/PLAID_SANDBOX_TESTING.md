# Plaid Sandbox Test Plan

这份方案是为当前 Flamora 项目定制的，目标是一次覆盖以下链路：

- `Investment` 卡片与持仓接口
- `Budget Setup` 的 6 个月分析流程
- `Cashflow` 的收入 / 支出 / 储蓄汇总
- 后端 `needs / wants / income / transfer` 分类映射

## 1. 推荐使用方式

优先使用 Plaid Dashboard 的 `Developers -> Sandbox -> Sandbox Users` 创建自定义用户。

- 用户名建议：`flamora_balanced_household`
- 配置对象：直接粘贴 [sandbox-balanced-household.json](/Users/staygreen/Documents/GitHub/Flamora/docs/plaid/sandbox-balanced-household.json)
- 密码：任意非空字符串

然后在 App 的 Plaid Link 里：

- 选择非 OAuth institution
- 推荐 `First Platypus Bank` 或 `First Gingham Credit Union`
- 用上面的用户名登录

## 2. 这个测试用户会覆盖什么

- `checking` 账户：
  - 6 个月工资入账
  - 房租、水电、网络、油费、 groceries
  - dining out、shopping、subscriptions、rideshare、travel
  - 转账到 savings / brokerage
- `savings` 账户：
  - 每月从 checking 转入
  - 每月底利息
- `investment` 账户：
  - brokerage 余额
  - holdings: `AAPL` / `VTI` / `BND`
  - investment transactions: cash / buy / dividend

## 3. 建议验收顺序

1. 先连银行，确认 `get-plaid-accounts` 能看到三类账户：
   - checking
   - savings
   - investment
2. 看 `Investment` 页：
   - 顶部总额是否非 0
   - `Asset Allocation` 是否有股票 / 债券或其他分布
   - `Accounts` 是否能看到 investment 与 depository 账户
3. 看 `Cashflow` 页：
   - 是否有交易
   - 总支出是否非 0
   - savings target 是否有值
4. 跑 `Budget Setup`：
   - Step 0 能选到 checking/savings 类交易账户
   - Step 1 能分析出 6 个月数据
   - Step 3 的 Needs / Wants 是否合理
   - 最终能生成并保存 budget
5. 看分类质量：
   - rent / utilities / groceries 是否更偏 `needs`
   - Spotify / Netflix / rideshare / shopping / travel 是否更偏 `wants`
   - payroll / interest / dividend 是否落入 `income`
   - checking -> savings / brokerage 是否更偏 `transfer`

## 4. 当前项目里的一个关键注意点

你的 Link Token 现在是：

- `products: ['transactions']`
- `optional_products: ['investments']`

见 [create-link-token/index.ts](/Users/staygreen/Documents/GitHub/Flamora/Fire%20cursor/supabase/functions/create-link-token/index.ts#L102)

而 investment 持仓抓取是在 exchange 阶段看 `hasInvestments` 再决定要不要写库，见 [exchange-public-token/index.ts](/Users/staygreen/Documents/GitHub/Flamora/Fire%20cursor/supabase/functions/exchange-public-token/index.ts#L446)

如果你连上后发现：

- checking / savings 正常
- transactions 正常
- 但 holdings / securities 为空

优先检查两件事：

- 当前 Link 会话里 `investments` 是否真的被启用
- Plaid Dashboard 里该 Sandbox institution 是否支持你当前的 optional product 组合

## 5. 当前 Investment 验收的已知代码风险

就算 sandbox 用户数据正常，当前仓库里仍有两个已知问题会影响你看到的结果：

- `PortfolioCard` 的走势图还是 mock，不是真实净值历史
- `get-investment-holdings` 没把 `security_id` 查出来，可能导致 holdings/securities 聚合异常

所以这份 sandbox 用户最适合先验证：

- 账户是否入库
- 交易是否入库
- 分类是否基本正确
- 持仓是否有写入

但不适合把 `Portfolio` 曲线的真实性当成通过标准。
