// supabase/functions/handle-plaid-webhook/index.ts

import { serve } from 'https://deno.land/std@0.168.0/http/server.ts'
import { corsHeaders, handleCors } from '../_shared/cors.ts'
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

serve(async (req) => {
  const corsResponse = handleCors(req)
  if (corsResponse) return corsResponse

  // ⚠️ 始终返回 200，避免 Plaid 重试
  // 错误只记日志，不返回错误状态码
  try {
    const supabase = createClient(
      Deno.env.get('SUPABASE_URL')!,
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!
    )

    const body = await req.json()
    const webhookType = body.webhook_type       // TRANSACTIONS, HOLDINGS, ITEM
    const webhookCode = body.webhook_code       // SYNC_UPDATES_AVAILABLE, DEFAULT_UPDATE, etc.
    const itemId = body.item_id

    console.log(`[webhook] Received: ${webhookType}.${webhookCode} for item_id: ${itemId}`)

    // TODO: 生产环境启用 Plaid webhook 签名验证
    // 使用 /webhook_verification_key/get 验证 JWT 签名

    // 查找对应的 plaid_item
    const { data: plaidItem, error: itemError } = await supabase
      .from('plaid_items')
      .select('id, user_id, access_token, products')
      .eq('item_id', itemId)
      .single()

    if (itemError || !plaidItem) {
      console.error(`[webhook] Unknown item_id: ${itemId}`, itemError)
      return new Response(JSON.stringify({ received: true }), {
        status: 200,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      })
    }

    // ============================================================
    // 路由：根据 webhook 类型分发处理
    // ============================================================

    switch (webhookType) {
      // --------------------------------------------------------
      // TRANSACTIONS 交易相关
      // --------------------------------------------------------
      case 'TRANSACTIONS': {
        if (webhookCode === 'SYNC_UPDATES_AVAILABLE') {
          console.log(`[webhook] Triggering transaction sync for user ${plaidItem.user_id}`)
          await syncTransactions(supabase, plaidItem)
        } else if (webhookCode === 'INITIAL_UPDATE' || webhookCode === 'HISTORICAL_UPDATE') {
          // 旧版 webhook，也触发同步
          console.log(`[webhook] Legacy ${webhookCode}, triggering sync`)
          await syncTransactions(supabase, plaidItem)
        } else {
          console.log(`[webhook] Unhandled TRANSACTIONS code: ${webhookCode}`)
        }
        break
      }

      // --------------------------------------------------------
      // HOLDINGS 投资相关
      // --------------------------------------------------------
      case 'HOLDINGS': {
        if (webhookCode === 'DEFAULT_UPDATE') {
          console.log(`[webhook] Triggering investment refresh for user ${plaidItem.user_id}`)
          await refreshInvestments(supabase, plaidItem)
        } else {
          console.log(`[webhook] Unhandled HOLDINGS code: ${webhookCode}`)
        }
        break
      }

      // --------------------------------------------------------
      // ITEM 连接状态相关
      // --------------------------------------------------------
      case 'ITEM': {
        if (webhookCode === 'ERROR') {
          console.error(`[webhook] Item error for user ${plaidItem.user_id}:`, body.error)
          await supabase
            .from('plaid_items')
            .update({
              status: 'error',
              error_code: body.error?.error_code,
              error_message: body.error?.error_message,
            })
            .eq('id', plaidItem.id)

        } else if (webhookCode === 'PENDING_EXPIRATION') {
          console.warn(`[webhook] Consent expiring for user ${plaidItem.user_id}`)
          await supabase
            .from('plaid_items')
            .update({
              consent_expires_at: body.consent_expiration_time,
            })
            .eq('id', plaidItem.id)

        } else if (webhookCode === 'LOGIN_REPAIRED') {
          console.log(`[webhook] Login repaired for user ${plaidItem.user_id}`)
          await supabase
            .from('plaid_items')
            .update({
              status: 'active',
              error_code: null,
              error_message: null,
            })
            .eq('id', plaidItem.id)

        } else {
          console.log(`[webhook] Unhandled ITEM code: ${webhookCode}`)
        }
        break
      }

      default:
        console.log(`[webhook] Unhandled webhook type: ${webhookType}`)
    }

    // 始终返回 200
    return new Response(
      JSON.stringify({ received: true }),
      { status: 200, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    )
  } catch (error) {
    console.error('[webhook] Unexpected error:', error)

    // 即使出错也返回 200，避免 Plaid 无限重试
    return new Response(
      JSON.stringify({ received: true }),
      { status: 200, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    )
  }
})


// ============================================================
// 核心函数：同步交易
// ============================================================
async function syncTransactions(
  supabase: any,
  plaidItem: { id: string; user_id: string; access_token: string }
) {
  const plaidClientId = Deno.env.get('PLAID_CLIENT_ID')!
  const plaidSecret = Deno.env.get('PLAID_SECRET')!
  const plaidEnv = Deno.env.get('PLAID_ENV') || 'sandbox'
  const plaidBaseUrl = plaidEnv === 'production'
    ? 'https://production.plaid.com'
    : 'https://sandbox.plaid.com'

  // 获取当前 cursor
  const { data: itemRecord } = await supabase
    .from('plaid_items')
    .select('transactions_cursor')
    .eq('id', plaidItem.id)
    .single()

  let cursor = itemRecord?.transactions_cursor || ''
  let hasMore = true
  let totalAdded = 0
  let totalModified = 0
  let totalRemoved = 0

  // 获取 plaid_account_id 映射
  const { data: dbAccounts } = await supabase
    .from('plaid_accounts')
    .select('id, account_id')
    .eq('plaid_item_id', plaidItem.id)

  const accountIdMap = new Map(
    dbAccounts?.map((a: any) => [a.account_id, a.id]) || []
  )

  // 分页拉取所有更新
  while (hasMore) {
    const syncResponse = await fetch(`${plaidBaseUrl}/transactions/sync`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        client_id: plaidClientId,
        secret: plaidSecret,
        access_token: plaidItem.access_token,
        cursor: cursor,
        count: 500,
        options: {
          include_personal_finance_category: true,
        },
      }),
    })

    const syncData = await syncResponse.json()

    if (!syncResponse.ok) {
      console.error('[sync] Plaid sync error:', syncData)
      break
    }

    // --- 处理新增交易 ---
    if (syncData.added?.length > 0) {
      const newTransactions = syncData.added.map((tx: any) => {
        const pfc = tx.personal_finance_category
        const mapping = mapPlaidCategory(pfc?.detailed, pfc?.primary, pfc?.confidence_level)

        return {
          user_id: plaidItem.user_id,
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

      // 过滤掉 plaid_account_id 为空的记录
      const validTransactions = newTransactions.filter((tx: any) => tx.plaid_account_id)

      if (validTransactions.length > 0) {
        const { error: insertError } = await supabase
          .from('transactions')
          .upsert(validTransactions, { onConflict: 'transaction_id' })

        if (insertError) {
          console.error('[sync] Error inserting transactions:', insertError)
        }
      }

      totalAdded += syncData.added.length
    }

    // --- 处理修改的交易 ---
    if (syncData.modified?.length > 0) {
      for (const tx of syncData.modified) {
        const pfc = tx.personal_finance_category
        const mapping = mapPlaidCategory(pfc?.detailed, pfc?.primary, pfc?.confidence_level)

        // 检查用户是否手动覆盖过分类
        const { data: existingTx } = await supabase
          .from('transactions')
          .select('is_category_overridden')
          .eq('transaction_id', tx.transaction_id)
          .single()

        const updateData: Record<string, any> = {
          amount: tx.amount,
          date: tx.date,
          datetime: tx.datetime,
          name: tx.name,
          merchant_name: tx.merchant_name,
          pfc_primary: pfc?.primary,
          pfc_detailed: pfc?.detailed,
          pfc_confidence: pfc?.confidence_level,
          pending: tx.pending,
          payment_channel: tx.payment_channel,
          location_city: tx.location?.city,
          location_region: tx.location?.region,
          location_country: tx.location?.country_code,
        }

        // 只在用户没手动改过分类时更新分类
        if (!existingTx?.is_category_overridden) {
          updateData.flamora_category = mapping.flamora_category
          updateData.flamora_subcategory = mapping.flamora_subcategory
          updateData.pending_review = mapping.pending_review
        }

        await supabase
          .from('transactions')
          .update(updateData)
          .eq('transaction_id', tx.transaction_id)
      }

      totalModified += syncData.modified.length
    }

    // --- 处理删除的交易 ---
    if (syncData.removed?.length > 0) {
      const removedIds = syncData.removed.map((tx: any) => tx.transaction_id)

      await supabase
        .from('transactions')
        .delete()
        .in('transaction_id', removedIds)

      totalRemoved += syncData.removed.length
    }

    // 更新 cursor 和分页状态
    cursor = syncData.next_cursor
    hasMore = syncData.has_more
  }

  // 保存最新的 cursor
  await supabase
    .from('plaid_items')
    .update({
      transactions_cursor: cursor,
      last_transactions_sync: new Date().toISOString(),
    })
    .eq('id', plaidItem.id)

  // 同步后更新账户余额
  await updateAccountBalances(supabase, plaidItem)

  console.log(`[sync] Complete: +${totalAdded} added, ~${totalModified} modified, -${totalRemoved} removed`)
}


// ============================================================
// 核心函数：刷新投资持仓
// ============================================================
async function refreshInvestments(
  supabase: any,
  plaidItem: { id: string; user_id: string; access_token: string }
) {
  const plaidClientId = Deno.env.get('PLAID_CLIENT_ID')!
  const plaidSecret = Deno.env.get('PLAID_SECRET')!
  const plaidEnv = Deno.env.get('PLAID_ENV') || 'sandbox'
  const plaidBaseUrl = plaidEnv === 'production'
    ? 'https://production.plaid.com'
    : 'https://sandbox.plaid.com'

  const response = await fetch(`${plaidBaseUrl}/investments/holdings/get`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({
      client_id: plaidClientId,
      secret: plaidSecret,
      access_token: plaidItem.access_token,
    }),
  })

  const holdingsData = await response.json()

  if (!response.ok) {
    console.error('[investments] Plaid API error:', holdingsData)
    return
  }

  // 更新 securities
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

    await supabase
      .from('securities')
      .upsert(securityRecords, { onConflict: 'security_id' })
  }

  // 获取账户 ID 映射
  const { data: dbAccounts } = await supabase
    .from('plaid_accounts')
    .select('id, account_id')
    .eq('plaid_item_id', plaidItem.id)

  const accountIdMap = new Map(
    dbAccounts?.map((a: any) => [a.account_id, a.id]) || []
  )

  // 清空旧 holdings，插入新快照
  const plaidAccountIds = dbAccounts?.map((a: any) => a.id) || []
  if (plaidAccountIds.length > 0) {
    await supabase
      .from('investment_holdings')
      .delete()
      .eq('user_id', plaidItem.user_id)
      .in('plaid_account_id', plaidAccountIds)
  }

  // 插入新 holdings
  if (holdingsData.holdings?.length > 0) {
    const holdingRecords = holdingsData.holdings
      .filter((h: any) => accountIdMap.has(h.account_id))
      .map((h: any) => ({
        user_id: plaidItem.user_id,
        plaid_account_id: accountIdMap.get(h.account_id),
        security_id: h.security_id,
        quantity: h.quantity,
        cost_basis: h.cost_basis,
        institution_price: h.institution_price,
        institution_value: h.institution_value,
        institution_price_as_of: h.institution_price_as_of,
        iso_currency_code: h.iso_currency_code,
      }))

    if (holdingRecords.length > 0) {
      await supabase
        .from('investment_holdings')
        .insert(holdingRecords)
    }
  }

  // 更新投资账户余额
  for (const account of holdingsData.accounts || []) {
    if (account.type === 'investment') {
      await supabase
        .from('plaid_accounts')
        .update({
          balance_current: account.balances?.current,
          balance_available: account.balances?.available,
        })
        .eq('account_id', account.account_id)
    }
  }

  // 更新净资产
  await updateNetWorth(supabase, plaidItem.user_id)

  // 更新 plaid_items 时间戳
  await supabase
    .from('plaid_items')
    .update({ last_investments_refresh: new Date().toISOString() })
    .eq('id', plaidItem.id)

  console.log(`[investments] Refreshed: ${holdingsData.holdings?.length || 0} holdings, ${holdingsData.securities?.length || 0} securities`)
}


// ============================================================
// 辅助函数：更新账户余额
// ============================================================
async function updateAccountBalances(
  supabase: any,
  plaidItem: { id: string; user_id: string; access_token: string }
) {
  const plaidClientId = Deno.env.get('PLAID_CLIENT_ID')!
  const plaidSecret = Deno.env.get('PLAID_SECRET')!
  const plaidEnv = Deno.env.get('PLAID_ENV') || 'sandbox'
  const plaidBaseUrl = plaidEnv === 'production'
    ? 'https://production.plaid.com'
    : 'https://sandbox.plaid.com'

  try {
    const response = await fetch(`${plaidBaseUrl}/accounts/get`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        client_id: plaidClientId,
        secret: plaidSecret,
        access_token: plaidItem.access_token,
      }),
    })

    const data = await response.json()
    if (!response.ok) return

    for (const account of data.accounts || []) {
      await supabase
        .from('plaid_accounts')
        .update({
          balance_current: account.balances?.current,
          balance_available: account.balances?.available,
          balance_limit: account.balances?.limit,
        })
        .eq('account_id', account.account_id)
    }

    // 同步完余额后更新净资产
    await updateNetWorth(supabase, plaidItem.user_id)
  } catch (error) {
    console.error('[balances] Error updating account balances:', error)
  }
}


// ============================================================
// 辅助函数：更新净资产
// ============================================================
async function updateNetWorth(supabase: any, userId: string) {
  // 汇总所有活跃账户余额
  const { data: accounts } = await supabase
    .from('plaid_accounts')
    .select('type, balance_current')
    .eq('user_id', userId)
    .eq('is_active', true)

  const investmentTotal = accounts
    ?.filter((a: any) => a.type === 'investment')
    .reduce((sum: number, a: any) => sum + (a.balance_current || 0), 0) || 0

  const depositoryTotal = accounts
    ?.filter((a: any) => a.type === 'depository')
    .reduce((sum: number, a: any) => sum + (a.balance_current || 0), 0) || 0

  const creditTotal = accounts
    ?.filter((a: any) => a.type === 'credit')
    .reduce((sum: number, a: any) => sum + (a.balance_current || 0), 0) || 0

  const totalNetWorth = investmentTotal + depositoryTotal - creditTotal

  // 更新 user_profiles
  await supabase
    .from('user_profiles')
    .update({
      plaid_net_worth: investmentTotal,
      plaid_net_worth_updated_at: new Date().toISOString(),
    })
    .eq('user_id', userId)

  // 获取 FIRE 目标
  const { data: fireGoal } = await supabase
    .from('fire_goals')
    .select('fire_number')
    .eq('user_id', userId)
    .eq('is_active', true)
    .single()

  const fireProgressPct = fireGoal?.fire_number > 0
    ? parseFloat(((investmentTotal / fireGoal.fire_number) * 100).toFixed(2))
    : null

  await snapshotCurrentAccountBalances(supabase, userId)

  // Upsert 今天的净资产记录
  const today = new Date().toISOString().split('T')[0]
  await supabase
    .from('net_worth_history')
    .upsert({
      user_id: userId,
      date: today,
      investment_total: investmentTotal,
      depository_total: depositoryTotal,
      total_net_worth: totalNetWorth,
      fire_number: fireGoal?.fire_number || null,
      fire_progress_pct: fireProgressPct,
    }, { onConflict: 'user_id,date' })
}

async function snapshotCurrentAccountBalances(supabase: any, userId: string) {
  const today = new Date().toISOString().split('T')[0]

  const { data: accounts, error } = await supabase
    .from('plaid_accounts')
    .select('id, type, balance_current, balance_available')
    .eq('user_id', userId)
    .eq('is_active', true)

  if (error) {
    console.error('[balances] Error loading accounts for balance snapshot:', error)
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
    console.error('[balances] Error upserting account balance history:', snapshotError)
  }
}


// ============================================================
// Plaid PFCv2 → Flamora 分类映射
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

// Primary 级别的 fallback 映射
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

  // 优先用 detailed 映射
  if (pfcDetailed && PFC_TO_FLAMORA_MAP[pfcDetailed]) {
    mapping = PFC_TO_FLAMORA_MAP[pfcDetailed]
  }
  // 退而用 primary 映射
  else if (pfcPrimary && PFC_PRIMARY_FALLBACK[pfcPrimary]) {
    mapping = PFC_PRIMARY_FALLBACK[pfcPrimary]
  }
  // 未知分类
  else {
    mapping = { flamora_category: 'wants', flamora_subcategory: 'uncategorized' }
    isUnknownCategory = true
  }

  // pending_review 逻辑：
  // 1. 未知/未映射的分类 → 必须审核
  // 2. Plaid 置信度为 MEDIUM / LOW / UNKNOWN → 需要审核
  // 3. VERY_HIGH / HIGH → 自动分类，不需要审核
  const lowConfidence = !pfcConfidence || ['MEDIUM', 'LOW', 'UNKNOWN'].includes(pfcConfidence)
  const pending_review = isUnknownCategory || lowConfidence

  return {
    ...mapping,
    pending_review,
  }
}
