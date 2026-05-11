// supabase/functions/exchange-public-token/index.ts

import { serve } from 'https://deno.land/std@0.168.0/http/server.ts'
import { corsHeaders, handleCors } from '../_shared/cors.ts'
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'
import { ensureIssueZeroReport, stampFirstBankConnectedAt } from '../_shared/report-builder.ts'
import { fetchInstitutionBranding, brandingPatch } from '../_shared/institution-logo.ts'

interface ExchangeRequest {
  public_token: string
  institution: {
    institution_id: string
    name: string
  }
  selected_account_ids?: string[]
}

// ============================================================
// Plaid PFCv2 → Flamora 分类映射（与 handle-plaid-webhook 保持一致）
// ============================================================

const PFC_TO_FLAMORA_MAP: Record<string, { flamora_category: string; flamora_subcategory: string }> = {
  // ===== NEEDS（刚性支出） =====
  "RENT_AND_UTILITIES_RENT": { flamora_category: "needs", flamora_subcategory: "rent" },
  "RENT_AND_UTILITIES_GAS_AND_ELECTRICITY": { flamora_category: "needs", flamora_subcategory: "utilities" },
  "RENT_AND_UTILITIES_WATER": { flamora_category: "needs", flamora_subcategory: "utilities" },
  "RENT_AND_UTILITIES_SEWAGE_AND_WASTE_MANAGEMENT": { flamora_category: "needs", flamora_subcategory: "utilities" },
  "RENT_AND_UTILITIES_TELEPHONE": { flamora_category: "needs", flamora_subcategory: "phone" },
  "RENT_AND_UTILITIES_INTERNET_AND_CABLE": { flamora_category: "needs", flamora_subcategory: "internet" },
  "RENT_AND_UTILITIES_OTHER_UTILITIES": { flamora_category: "needs", flamora_subcategory: "utilities" },
  "FOOD_AND_DRINK_GROCERIES": { flamora_category: "needs", flamora_subcategory: "groceries" },
  "MEDICAL_MEDICAL_PAYMENTS": { flamora_category: "needs", flamora_subcategory: "medical" },
  "MEDICAL_MEDICAL_SUPPLIES_AND_SUPPLEMENTS": { flamora_category: "needs", flamora_subcategory: "medical" },
  "MEDICAL_OTHER_MEDICAL": { flamora_category: "needs", flamora_subcategory: "medical" },
  "TRANSPORTATION_GAS": { flamora_category: "needs", flamora_subcategory: "transportation" },
  "TRANSPORTATION_PARKING": { flamora_category: "needs", flamora_subcategory: "transportation" },
  "TRANSPORTATION_PUBLIC_TRANSIT": { flamora_category: "needs", flamora_subcategory: "transportation" },
  "TRANSPORTATION_TOLLS": { flamora_category: "needs", flamora_subcategory: "transportation" },
  "TRANSPORTATION_CAR_INSURANCE": { flamora_category: "needs", flamora_subcategory: "insurance" },
  "TRANSPORTATION_CAR_DEALERS_AND_LEASING": { flamora_category: "needs", flamora_subcategory: "transportation" },
  "TRANSPORTATION_OTHER_TRANSPORTATION": { flamora_category: "needs", flamora_subcategory: "transportation" },
  "LOAN_PAYMENTS_MORTGAGE_PAYMENT": { flamora_category: "needs", flamora_subcategory: "loan_payment" },
  "LOAN_PAYMENTS_STUDENT_LOAN_PAYMENT": { flamora_category: "needs", flamora_subcategory: "loan_payment" },
  "LOAN_PAYMENTS_CAR_PAYMENT": { flamora_category: "needs", flamora_subcategory: "loan_payment" },
  "LOAN_PAYMENTS_OTHER_PAYMENT": { flamora_category: "needs", flamora_subcategory: "loan_payment" },
  "GENERAL_SERVICES_INSURANCE": { flamora_category: "needs", flamora_subcategory: "insurance" },
  "GENERAL_SERVICES_ACCOUNTING_AND_FINANCIAL_PLANNING": { flamora_category: "needs", flamora_subcategory: "services" },
  "GENERAL_SERVICES_CONSULTING_AND_LEGAL": { flamora_category: "needs", flamora_subcategory: "services" },
  "GENERAL_SERVICES_EDUCATION": { flamora_category: "needs", flamora_subcategory: "education" },
  "GENERAL_SERVICES_CHILDCARE": { flamora_category: "needs", flamora_subcategory: "childcare" },
  "GENERAL_SERVICES_OTHER_GENERAL_SERVICES": { flamora_category: "needs", flamora_subcategory: "services" },
  "GOVERNMENT_AND_NON_PROFIT_TAX_PAYMENT": { flamora_category: "needs", flamora_subcategory: "taxes" },
  "GOVERNMENT_AND_NON_PROFIT_GOVERNMENT_DEPARTMENTS_AND_AGENCIES": { flamora_category: "needs", flamora_subcategory: "government" },
  "HOME_IMPROVEMENT_HARDWARE": { flamora_category: "needs", flamora_subcategory: "home_maintenance" },
  "HOME_IMPROVEMENT_REPAIR_AND_MAINTENANCE": { flamora_category: "needs", flamora_subcategory: "home_maintenance" },

  // ===== WANTS（弹性支出） =====
  "FOOD_AND_DRINK_RESTAURANT": { flamora_category: "wants", flamora_subcategory: "dining_out" },
  "FOOD_AND_DRINK_FAST_FOOD": { flamora_category: "wants", flamora_subcategory: "dining_out" },
  "FOOD_AND_DRINK_COFFEE": { flamora_category: "wants", flamora_subcategory: "dining_out" },
  "FOOD_AND_DRINK_BEER_WINE_AND_LIQUOR": { flamora_category: "wants", flamora_subcategory: "dining_out" },
  "FOOD_AND_DRINK_VENDING_MACHINES": { flamora_category: "wants", flamora_subcategory: "dining_out" },
  "FOOD_AND_DRINK_OTHER_FOOD_AND_DRINK": { flamora_category: "wants", flamora_subcategory: "dining_out" },
  "ENTERTAINMENT_CASINOS_AND_GAMBLING": { flamora_category: "wants", flamora_subcategory: "entertainment" },
  "ENTERTAINMENT_MUSIC_AND_AUDIO": { flamora_category: "wants", flamora_subcategory: "subscriptions" },
  "ENTERTAINMENT_SPORTING_EVENTS_AMUSEMENT_PARKS_AND_MUSEUMS": { flamora_category: "wants", flamora_subcategory: "entertainment" },
  "ENTERTAINMENT_TV_AND_MOVIES": { flamora_category: "wants", flamora_subcategory: "subscriptions" },
  "ENTERTAINMENT_VIDEO_GAMES": { flamora_category: "wants", flamora_subcategory: "entertainment" },
  "ENTERTAINMENT_OTHER_ENTERTAINMENT": { flamora_category: "wants", flamora_subcategory: "entertainment" },
  "GENERAL_MERCHANDISE_BOOKSTORES_AND_NEWSSTANDS": { flamora_category: "wants", flamora_subcategory: "shopping" },
  "GENERAL_MERCHANDISE_CLOTHING_AND_ACCESSORIES": { flamora_category: "wants", flamora_subcategory: "shopping" },
  "GENERAL_MERCHANDISE_DEPARTMENT_STORES": { flamora_category: "wants", flamora_subcategory: "shopping" },
  "GENERAL_MERCHANDISE_DISCOUNT_STORES": { flamora_category: "wants", flamora_subcategory: "shopping" },
  "GENERAL_MERCHANDISE_ELECTRONICS": { flamora_category: "wants", flamora_subcategory: "shopping" },
  "GENERAL_MERCHANDISE_GIFTS_AND_NOVELTIES": { flamora_category: "wants", flamora_subcategory: "shopping" },
  "GENERAL_MERCHANDISE_OFFICE_SUPPLIES": { flamora_category: "wants", flamora_subcategory: "shopping" },
  "GENERAL_MERCHANDISE_ONLINE_MARKETPLACES": { flamora_category: "wants", flamora_subcategory: "shopping" },
  "GENERAL_MERCHANDISE_PET_SUPPLIES": { flamora_category: "wants", flamora_subcategory: "pets" },
  "GENERAL_MERCHANDISE_SPORTING_GOODS": { flamora_category: "wants", flamora_subcategory: "fitness" },
  "GENERAL_MERCHANDISE_SUPERSTORES": { flamora_category: "wants", flamora_subcategory: "shopping" },
  "GENERAL_MERCHANDISE_TOBACCO_AND_VAPE": { flamora_category: "wants", flamora_subcategory: "shopping" },
  "GENERAL_MERCHANDISE_OTHER_GENERAL_MERCHANDISE": { flamora_category: "wants", flamora_subcategory: "shopping" },
  "HOME_IMPROVEMENT_FURNITURE": { flamora_category: "wants", flamora_subcategory: "home" },
  "HOME_IMPROVEMENT_OTHER_HOME_IMPROVEMENT": { flamora_category: "wants", flamora_subcategory: "home" },
  "PERSONAL_CARE_GYMS_AND_FITNESS_CENTERS": { flamora_category: "wants", flamora_subcategory: "fitness" },
  "PERSONAL_CARE_HAIR_AND_BEAUTY": { flamora_category: "wants", flamora_subcategory: "personal_care" },
  "PERSONAL_CARE_LAUNDRY_AND_DRY_CLEANING": { flamora_category: "wants", flamora_subcategory: "personal_care" },
  "PERSONAL_CARE_OTHER_PERSONAL_CARE": { flamora_category: "wants", flamora_subcategory: "personal_care" },
  "TRAVEL_FLIGHTS": { flamora_category: "wants", flamora_subcategory: "travel" },
  "TRAVEL_LODGING": { flamora_category: "wants", flamora_subcategory: "travel" },
  "TRAVEL_RENTAL_CARS": { flamora_category: "wants", flamora_subcategory: "travel" },
  "TRAVEL_OTHER_TRAVEL": { flamora_category: "wants", flamora_subcategory: "travel" },
  "TRANSPORTATION_TAXIS_AND_RIDE_SHARES": { flamora_category: "wants", flamora_subcategory: "rideshare" },
  "BANK_FEES_ATM_FEES": { flamora_category: "wants", flamora_subcategory: "bank_fees" },
  "BANK_FEES_FOREIGN_TRANSACTION_FEES": { flamora_category: "wants", flamora_subcategory: "bank_fees" },
  "BANK_FEES_INSUFFICIENT_FUNDS": { flamora_category: "wants", flamora_subcategory: "bank_fees" },
  "BANK_FEES_INTEREST_CHARGE": { flamora_category: "wants", flamora_subcategory: "bank_fees" },
  "BANK_FEES_OVERDRAFT_FEES": { flamora_category: "wants", flamora_subcategory: "bank_fees" },
  "BANK_FEES_OTHER_BANK_FEES": { flamora_category: "wants", flamora_subcategory: "bank_fees" },
  "GENERAL_SERVICES_POSTAGE_AND_SHIPPING": { flamora_category: "wants", flamora_subcategory: "services" },
  "GENERAL_SERVICES_STORAGE": { flamora_category: "wants", flamora_subcategory: "services" },
  "GOVERNMENT_AND_NON_PROFIT_DONATIONS": { flamora_category: "wants", flamora_subcategory: "donations" },
  "GOVERNMENT_AND_NON_PROFIT_OTHER_GOVERNMENT_AND_NON_PROFIT": { flamora_category: "wants", flamora_subcategory: "donations" },

  // ===== INCOME =====
  "INCOME_DIVIDENDS": { flamora_category: "income", flamora_subcategory: "investment_income" },
  "INCOME_INTEREST_EARNED": { flamora_category: "income", flamora_subcategory: "investment_income" },
  "INCOME_RETIREMENT_PENSION": { flamora_category: "income", flamora_subcategory: "pension" },
  "INCOME_TAX_REFUND": { flamora_category: "income", flamora_subcategory: "tax_refund" },
  "INCOME_UNEMPLOYMENT": { flamora_category: "income", flamora_subcategory: "benefits" },
  "INCOME_WAGES": { flamora_category: "income", flamora_subcategory: "salary" },
  "INCOME_OTHER_INCOME": { flamora_category: "income", flamora_subcategory: "other_income" },

  // ===== TRANSFER（不计入支出） =====
  "TRANSFER_IN_CASH_ADVANCES_AND_LOANS": { flamora_category: "transfer", flamora_subcategory: "transfer_in" },
  "TRANSFER_IN_DEPOSIT": { flamora_category: "transfer", flamora_subcategory: "transfer_in" },
  "TRANSFER_IN_INVESTMENT_AND_RETIREMENT_FUNDS": { flamora_category: "transfer", flamora_subcategory: "transfer_in" },
  "TRANSFER_IN_SAVINGS": { flamora_category: "transfer", flamora_subcategory: "transfer_in" },
  "TRANSFER_IN_ACCOUNT_TRANSFER": { flamora_category: "transfer", flamora_subcategory: "transfer_in" },
  "TRANSFER_IN_OTHER_TRANSFER_IN": { flamora_category: "transfer", flamora_subcategory: "transfer_in" },
  "TRANSFER_OUT_INVESTMENT_AND_RETIREMENT_FUNDS": { flamora_category: "transfer", flamora_subcategory: "transfer_out" },
  "TRANSFER_OUT_SAVINGS": { flamora_category: "transfer", flamora_subcategory: "transfer_out" },
  "TRANSFER_OUT_WITHDRAWAL": { flamora_category: "transfer", flamora_subcategory: "transfer_out" },
  "TRANSFER_OUT_ACCOUNT_TRANSFER": { flamora_category: "transfer", flamora_subcategory: "transfer_out" },
  "TRANSFER_OUT_OTHER_TRANSFER_OUT": { flamora_category: "transfer", flamora_subcategory: "transfer_out" },
  "LOAN_PAYMENTS_CREDIT_CARD_PAYMENT": { flamora_category: "transfer", flamora_subcategory: "credit_card_payment" },
}

const PFC_PRIMARY_FALLBACK: Record<string, { flamora_category: string; flamora_subcategory: string }> = {
  "RENT_AND_UTILITIES": { flamora_category: "needs", flamora_subcategory: "utilities" },
  "FOOD_AND_DRINK": { flamora_category: "wants", flamora_subcategory: "dining_out" },
  "MEDICAL": { flamora_category: "needs", flamora_subcategory: "medical" },
  "TRANSPORTATION": { flamora_category: "needs", flamora_subcategory: "transportation" },
  "LOAN_PAYMENTS": { flamora_category: "needs", flamora_subcategory: "loan_payment" },
  "GENERAL_SERVICES": { flamora_category: "needs", flamora_subcategory: "services" },
  "ENTERTAINMENT": { flamora_category: "wants", flamora_subcategory: "entertainment" },
  "GENERAL_MERCHANDISE": { flamora_category: "wants", flamora_subcategory: "shopping" },
  "HOME_IMPROVEMENT": { flamora_category: "wants", flamora_subcategory: "home" },
  "PERSONAL_CARE": { flamora_category: "wants", flamora_subcategory: "personal_care" },
  "TRAVEL": { flamora_category: "wants", flamora_subcategory: "travel" },
  "BANK_FEES": { flamora_category: "wants", flamora_subcategory: "bank_fees" },
  "INCOME": { flamora_category: "income", flamora_subcategory: "other_income" },
  "TRANSFER_IN": { flamora_category: "transfer", flamora_subcategory: "transfer_in" },
  "TRANSFER_OUT": { flamora_category: "transfer", flamora_subcategory: "transfer_out" },
  "GOVERNMENT_AND_NON_PROFIT": { flamora_category: "needs", flamora_subcategory: "government" },
}

function mapPlaidCategory(
  pfcDetailed: string | null,
  pfcPrimary: string | null,
  pfcConfidence: string | null
): {
  flamora_category: string
  flamora_subcategory: string
  pending_review: boolean
} {
  let mapping: { flamora_category: string; flamora_subcategory: string } | null = null
  let isUnknownCategory = false

  if (pfcDetailed && PFC_TO_FLAMORA_MAP[pfcDetailed]) {
    mapping = PFC_TO_FLAMORA_MAP[pfcDetailed]
  } else if (pfcPrimary && PFC_PRIMARY_FALLBACK[pfcPrimary]) {
    mapping = PFC_PRIMARY_FALLBACK[pfcPrimary]
  } else {
    mapping = { flamora_category: 'wants', flamora_subcategory: 'uncategorized' }
    isUnknownCategory = true
  }

  const lowConfidence = !pfcConfidence || ['MEDIUM', 'LOW', 'UNKNOWN'].includes(pfcConfidence)
  const pending_review = isUnknownCategory || lowConfidence

  return { ...mapping, pending_review }
}

// ============================================================
// Main handler
// ============================================================

serve(async (req) => {
  const corsResponse = handleCors(req)
  if (corsResponse) return corsResponse

  try {
    // ============================================================
    // 1. 身份验证
    // ============================================================
    const authHeader = req.headers.get('Authorization')
    if (!authHeader) {
      return new Response(
        JSON.stringify({
          success: false,
          error: { code: 'UNAUTHORIZED', message: 'Missing Authorization header' },
        }),
        { status: 401, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }

    const supabaseAuth = createClient(
      Deno.env.get('SUPABASE_URL')!,
      Deno.env.get('SUPABASE_ANON_KEY')!,
      { global: { headers: { Authorization: authHeader } } }
    )

    const { data: { user }, error: authError } = await supabaseAuth.auth.getUser()
    if (authError || !user) {
      return new Response(
        JSON.stringify({
          success: false,
          error: { code: 'UNAUTHORIZED', message: 'Invalid or expired token' },
        }),
        { status: 401, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }

    const supabase = createClient(
      Deno.env.get('SUPABASE_URL')!,
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!
    )

    // ============================================================
    // 2. 解析请求
    // ============================================================
    const body: ExchangeRequest = await req.json()

    if (!body.public_token) {
      return new Response(
        JSON.stringify({
          success: false,
          error: { code: 'MISSING_PUBLIC_TOKEN', message: 'public_token is required' },
        }),
        { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }

    // ============================================================
    // 3. Plaid 配置
    // ============================================================
    const plaidClientId = Deno.env.get('PLAID_CLIENT_ID')!
    const plaidSecret = Deno.env.get('PLAID_SECRET')!
    const plaidEnv = Deno.env.get('PLAID_ENV') || 'sandbox'
    const plaidBaseUrl = plaidEnv === 'production'
      ? 'https://production.plaid.com'
      : 'https://sandbox.plaid.com'

    async function plaidRequest(endpoint: string, body: Record<string, unknown>) {
      const response = await fetch(`${plaidBaseUrl}${endpoint}`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          client_id: plaidClientId,
          secret: plaidSecret,
          ...body,
        }),
      })
      const data = await response.json()
      if (!response.ok) {
        throw new Error(`Plaid ${endpoint} error: ${data.error_message || JSON.stringify(data)}`)
      }
      return data
    }

    // ============================================================
    // 4. 交换 public_token → access_token
    // ============================================================
    console.log(`[exchange] Step 1: Exchanging public_token for user ${user.id}`)

    const exchangeData = await plaidRequest('/item/public_token/exchange', {
      public_token: body.public_token,
    })

    const accessToken = exchangeData.access_token
    const itemId = exchangeData.item_id

    // ============================================================
    // 5. 获取 Item 信息（判断启用了哪些产品）
    // ============================================================
    console.log('[exchange] Step 2: Fetching item info')

    const itemData = await plaidRequest('/item/get', {
      access_token: accessToken,
    })

    const availableProducts = itemData.item?.available_products || []
    const billedProducts = itemData.item?.billed_products || []
    const hasInvestments = billedProducts.includes('investments')

    // ============================================================
    // 6. 获取账户列表
    // ============================================================
    console.log('[exchange] Step 3: Fetching accounts')

    const accountsData = await plaidRequest('/accounts/get', {
      access_token: accessToken,
    })

    // ============================================================
    // 7. 存入 plaid_items 表（修复 3：详细写入日志）
    // ============================================================
    console.log('[exchange] Step 4: Storing plaid_item')

    // Fetch institution branding (logo + primary color) before insert so we can
    // store it in one round-trip. Best-effort: branding failure must not block
    // the link flow — the iOS row falls back to an SF Symbol when logo is null.
    let branding: Awaited<ReturnType<typeof fetchInstitutionBranding>> = null
    if (body.institution?.institution_id) {
      branding = await fetchInstitutionBranding(body.institution.institution_id, {
        plaidClientId,
        plaidSecret,
        plaidBaseUrl,
      })
      if (branding?.logoBase64) {
        console.log(`[exchange] ✅ Institution branding fetched (logo ${branding.logoBase64.length} bytes, color ${branding.primaryColor})`)
      } else {
        console.log('[exchange] ⚠️ Institution branding not available')
      }
    }

    const { data: plaidItem, error: itemInsertError } = await supabase
      .from('plaid_items')
      .upsert({
        user_id: user.id,
        access_token: accessToken,
        item_id: itemId,
        institution_id: body.institution?.institution_id || null,
        institution_name: body.institution?.name || null,
        status: 'active',
        products: billedProducts,
        ...brandingPatch(branding),
      }, { onConflict: 'item_id' })
      .select()
      .single()

    if (itemInsertError) {
      console.error('[exchange] ❌ plaid_items write failed:', itemInsertError)
      throw new Error(`Failed to store Plaid item: ${itemInsertError.message}`)
    }
    console.log(`[exchange] ✅ plaid_items written: id=${plaidItem.id}`)

    // ============================================================
    // 8. 存入 plaid_accounts 表（修复 2：失败时抛出错误）
    // ============================================================
    console.log(`[exchange] Step 5: Storing ${accountsData.accounts.length} accounts`)

    // 只将用户在 Plaid Link 中勾选的账户标记为 active；空数组表示客户端未传，默认全部激活
    const selectedAccountIds: string[] = body.selected_account_ids ?? []

    const accountRecords = accountsData.accounts.map((account: any) => ({
      plaid_item_id: plaidItem.id,
      user_id: user.id,
      account_id: account.account_id,
      name: account.name,
      official_name: account.official_name,
      mask: account.mask,
      type: account.type,
      subtype: account.subtype,
      balance_available: account.balances?.available,
      balance_current: account.balances?.current,
      balance_limit: account.balances?.limit,
      iso_currency_code: account.balances?.iso_currency_code || 'USD',
      is_active: selectedAccountIds.length === 0 || selectedAccountIds.includes(account.account_id),
    }))

    const { error: accountsInsertError } = await supabase
      .from('plaid_accounts')
      .upsert(accountRecords, { onConflict: 'account_id' })

    if (accountsInsertError) {
      console.error('[exchange] ❌ plaid_accounts write failed:', accountsInsertError)
      throw new Error(`Failed to store Plaid accounts: ${accountsInsertError.message}`)
    }
    console.log(`[exchange] ✅ plaid_accounts written: ${accountRecords.length} accounts`)

    // ============================================================
    // 9. Transactions Sync（修复 1：拉取并写入 transactions 表）
    // ============================================================
    console.log('[exchange] Step 6: Transactions sync — fetching and writing to DB')

    try {
      // 从 DB 查出刚插入的账户 ID 映射（Plaid account_id → DB UUID）
      const { data: dbAccounts } = await supabase
        .from('plaid_accounts')
        .select('id, account_id')
        .eq('plaid_item_id', plaidItem.id)

      const accountIdMap = new Map(
        dbAccounts?.map((a: any) => [a.account_id, a.id]) || []
      )

      let cursor = ''
      let hasMore = true
      let totalAdded = 0

      // 分页拉取所有初始交易
      while (hasMore) {
        const syncData = await plaidRequest('/transactions/sync', {
          access_token: accessToken,
          cursor: cursor,
          count: 500,
          options: { include_personal_finance_category: true },
        })

        // 写入新增交易
        if (syncData.added?.length > 0) {
          const newTransactions = syncData.added.map((tx: any) => {
            const pfc = tx.personal_finance_category
            const mapping = mapPlaidCategory(pfc?.detailed, pfc?.primary, pfc?.confidence_level)
            return {
              user_id: user.id,
              plaid_account_id: accountIdMap.get(tx.account_id),
              transaction_id: tx.transaction_id,
              amount: tx.amount,
              iso_currency_code: tx.iso_currency_code,
              date: tx.date,
              datetime: tx.datetime,
              name: tx.name,
              merchant_name: tx.merchant_name,
              pfc_primary: pfc?.primary,
              pfc_detailed: pfc?.detailed,
              pfc_confidence: pfc?.confidence_level,
              flamora_category: mapping.flamora_category,
              flamora_subcategory: mapping.flamora_subcategory,
              pending_review: mapping.pending_review,
              pending: tx.pending,
              payment_channel: tx.payment_channel,
              location_city: tx.location?.city,
              location_region: tx.location?.region,
              location_country: tx.location?.country_code,
            }
          })

          // 过滤掉无法映射到 DB 账户的交易
          const validTransactions = newTransactions.filter((tx: any) => tx.plaid_account_id)

          if (validTransactions.length > 0) {
            const { error: txInsertError } = await supabase
              .from('transactions')
              .upsert(validTransactions, { onConflict: 'transaction_id' })

            if (txInsertError) {
              console.error('[exchange] ❌ transactions write failed:', txInsertError)
            } else {
              console.log(`[exchange] ✅ transactions written: ${validTransactions.length} records`)
            }
          }

          totalAdded += syncData.added.length
        }

        // 更新 cursor 和分页状态
        cursor = syncData.next_cursor
        hasMore = syncData.has_more
      }

      // 保存最终 cursor
      await supabase
        .from('plaid_items')
        .update({
          transactions_cursor: cursor,
          last_transactions_sync: new Date().toISOString(),
        })
        .eq('id', plaidItem.id)

      console.log(`[exchange] ✅ Transactions sync complete: ${totalAdded} total transactions`)
    } catch (syncError) {
      console.error('[exchange] ❌ Transactions sync error:', syncError)
      // 不中断主流程 — 后续可通过 webhook 补同步
    }

    // ============================================================
    // 10. 获取投资数据（如果有 investments 产品）
    // ============================================================
    let investmentSummary = null

    if (hasInvestments) {
      console.log('[exchange] Step 7: Fetching investment holdings')

      try {
        const holdingsData = await plaidRequest('/investments/holdings/get', {
          access_token: accessToken,
        })

        // 存入 securities 表（公共数据，upsert）
        if (holdingsData.securities?.length > 0) {
          const securityRecords = holdingsData.securities.map((sec: any) => ({
            security_id: sec.security_id,
            name: sec.name,
            ticker_symbol: sec.ticker_symbol,
            type: sec.type,
            close_price: sec.close_price,
            close_price_as_of: sec.close_price_as_of,
            iso_currency_code: sec.iso_currency_code,
            is_cash_equivalent: sec.is_cash_equivalent,
          }))

          const { error: secError } = await supabase
            .from('securities')
            .upsert(securityRecords, { onConflict: 'security_id' })

          if (secError) console.error('[exchange] Error upserting securities:', secError)
        }

        // 获取投资账户的 plaid_account_id 映射
        const { data: dbAccounts } = await supabase
          .from('plaid_accounts')
          .select('id, account_id')
          .eq('plaid_item_id', plaidItem.id)

        const accountIdMap = new Map(
          dbAccounts?.map((a: any) => [a.account_id, a.id]) || []
        )

        // 存入 investment_holdings 表
        if (holdingsData.holdings?.length > 0) {
          const holdingRecords = holdingsData.holdings.map((h: any) => ({
            user_id: user.id,
            plaid_account_id: accountIdMap.get(h.account_id),
            security_id: h.security_id,
            quantity: h.quantity,
            cost_basis: h.cost_basis,
            institution_price: h.institution_price,
            institution_value: h.institution_value,
            institution_price_as_of: h.institution_price_as_of,
            iso_currency_code: h.iso_currency_code,
          }))

          const validRecords = holdingRecords.filter((r: any) => r.plaid_account_id)

          if (validRecords.length > 0) {
            const { error: holdingsError } = await supabase
              .from('investment_holdings')
              .insert(validRecords)

            if (holdingsError) console.error('[exchange] Error inserting holdings:', holdingsError)
          }
        }

        const investmentTotal = holdingsData.accounts
          ?.filter((a: any) => a.type === 'investment')
          .reduce((sum: number, a: any) => sum + (a.balances?.current || 0), 0) || 0

        investmentSummary = {
          total_value: investmentTotal,
          holdings_count: holdingsData.holdings?.length || 0,
          securities_count: holdingsData.securities?.length || 0,
        }

        console.log(`[exchange] Investments: $${investmentTotal}, ${holdingsData.holdings?.length || 0} holdings`)
      } catch (investError) {
        console.error('[exchange] Investment fetch error:', investError)
      }
    }

    // ============================================================
    // 11. 更新净资产 + 用户档案（只汇总 is_active 账户，与 handle-plaid-webhook 保持一致）
    // ============================================================
    console.log('[exchange] Step 8: Updating net worth')

    const activeInvestmentAccounts = accountRecords
      .filter((r: any) => r.is_active && r.type === 'investment')

    const investmentTotal = activeInvestmentAccounts
      .reduce((sum: number, r: any) => sum + (r.balance_current || 0), 0)

    const depositoryTotal = accountRecords
      .filter((r: any) => r.is_active && r.type === 'depository')
      .reduce((sum: number, r: any) => sum + (r.balance_current || 0), 0)

    const creditTotal = accountRecords
      .filter((r: any) => r.is_active && r.type === 'credit')
      .reduce((sum: number, r: any) => sum + (r.balance_current || 0), 0)

    const totalNetWorth = investmentTotal + depositoryTotal - creditTotal

    const profileUpdate: Record<string, unknown> = {
      plaid_net_worth: investmentTotal,
      plaid_net_worth_updated_at: new Date().toISOString(),
      has_linked_bank: true,
    }

    if (activeInvestmentAccounts.length > 0) {
      profileUpdate.starting_portfolio_balance = investmentTotal
      profileUpdate.starting_portfolio_source = 'plaid_investment'
      profileUpdate.starting_portfolio_updated_at = new Date().toISOString()
    }

    const { error: profileError } = await supabase
      .from('user_profiles')
      .update(profileUpdate)
      .eq('user_id', user.id)

    if (profileError) console.error('[exchange] Error updating profile:', profileError)

    const { data: fireGoal } = await supabase
      .from('fire_goals')
      .select('fire_number')
      .eq('user_id', user.id)
      .eq('is_active', true)
      .single()

    const fireProgressPct = fireGoal?.fire_number > 0
      ? parseFloat(((investmentTotal / fireGoal.fire_number) * 100).toFixed(2))
      : null

    await snapshotCurrentAccountBalances(supabase, user.id)

    const today = new Date().toISOString().split('T')[0]
    const { error: nwError } = await supabase
      .from('net_worth_history')
      .upsert({
        user_id: user.id,
        date: today,
        investment_total: investmentTotal,
        depository_total: depositoryTotal,
        total_net_worth: totalNetWorth,
        fire_number: fireGoal?.fire_number || null,
        fire_progress_pct: fireProgressPct,
      }, { onConflict: 'user_id,date' })

    if (nwError) console.error('[exchange] Error upserting net_worth_history:', nwError)

    try {
      await stampFirstBankConnectedAt(supabase, user.id)
      await ensureIssueZeroReport(supabase, user.id)
    } catch (reportError) {
      console.error('[exchange] Error generating issue zero:', reportError)
    }

    // ============================================================
    // 12. 返回成功结果
    // ============================================================
    console.log(`[exchange] ✅ Complete for user ${user.id}, institution: ${body.institution?.name}`)

    return new Response(
      JSON.stringify({
        success: true,
        data: {
          item_id: plaidItem.id,
          institution_name: body.institution?.name || null,
          accounts_linked: accountsData.accounts.length,
          accounts: accountsData.accounts.map((a: any) => ({
            name: a.name,
            type: a.type,
            subtype: a.subtype,
            mask: a.mask,
          })),
          has_investments: hasInvestments,
          investment_summary: investmentSummary,
          net_worth: {
            investment_total: investmentTotal,
            depository_total: depositoryTotal,
            total_net_worth: totalNetWorth,
            fire_progress_pct: fireProgressPct,
          },
        },
        meta: {
          timestamp: new Date().toISOString(),
          user_id: user.id,
        },
      }),
      { status: 201, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    )
  } catch (error) {
    console.error('[exchange] Error in exchange-public-token:', error)

    return new Response(
      JSON.stringify({
        success: false,
        error: {
          code: 'INTERNAL_SERVER_ERROR',
          message: error.message || 'An unexpected error occurred',
        },
      }),
      { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    )
  }
})

async function snapshotCurrentAccountBalances(supabase: any, userId: string) {
  const today = new Date().toISOString().split('T')[0]

  const { data: accounts, error } = await supabase
    .from('plaid_accounts')
    .select('id, type, balance_current, balance_available')
    .eq('user_id', userId)
    .eq('is_active', true)

  if (error) {
    console.error('[exchange] Error loading accounts for balance snapshot:', error)
    return
  }

  const rows = (accounts || []).map((account: any) => ({
    user_id: userId,
    plaid_account_id: account.id,
    date: today,
    account_type: account.type,
    current_balance: account.balance_current,
    available_balance: account.balance_available,
  }))

  if (rows.length === 0) return

  const { error: snapshotError } = await supabase
    .from('account_balance_history')
    .upsert(rows, { onConflict: 'user_id,plaid_account_id,date' })

  if (snapshotError) {
    console.error('[exchange] Error upserting account balance history:', snapshotError)
  }
}
