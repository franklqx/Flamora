// supabase/functions/disconnect-bank/index.ts

import { serve } from 'https://deno.land/std@0.168.0/http/server.ts'
import { corsHeaders, handleCors } from '../_shared/cors.ts'
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

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
        JSON.stringify({ success: false, error: { code: 'UNAUTHORIZED', message: 'Missing Authorization header' } }),
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
        JSON.stringify({ success: false, error: { code: 'UNAUTHORIZED', message: 'Invalid or expired token' } }),
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
    const body = await req.json()
    const plaidItemId = body.plaid_item_id // 可选：指定断开某个银行，不传则断开全部

    // ============================================================
    // 3. 获取要断开的 plaid_items
    // ============================================================
    let query = supabase
      .from('plaid_items')
      .select('id, access_token, item_id, institution_name')
      .eq('user_id', user.id)

    if (plaidItemId) {
      query = query.eq('id', plaidItemId)
    }

    const { data: plaidItems, error: itemsError } = await query

    if (itemsError || !plaidItems || plaidItems.length === 0) {
      return new Response(
        JSON.stringify({
          success: false,
          error: { code: 'NO_ITEMS_FOUND', message: 'No linked bank accounts found' },
        }),
        { status: 404, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }

    // ============================================================
    // 4. 调用 Plaid /item/remove 撤销 access_token
    // ============================================================
    const plaidClientId = Deno.env.get('PLAID_CLIENT_ID')!
    const plaidSecret = Deno.env.get('PLAID_SECRET')!
    const plaidEnv = Deno.env.get('PLAID_ENV') || 'sandbox'
    const plaidBaseUrl = plaidEnv === 'production'
      ? 'https://production.plaid.com'
      : 'https://sandbox.plaid.com'

    const removedItems: string[] = []

    for (const item of plaidItems) {
      try {
        await fetch(`${plaidBaseUrl}/item/remove`, {
          method: 'POST',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify({
            client_id: plaidClientId,
            secret: plaidSecret,
            access_token: item.access_token,
          }),
        })
        removedItems.push(item.institution_name || item.item_id)
        console.log(`[disconnect] Removed Plaid item: ${item.item_id}`)
      } catch (err) {
        console.error(`[disconnect] Failed to remove Plaid item ${item.item_id}:`, err)
        // 继续删除数据库记录，即使 Plaid API 调用失败
      }
    }

    // ============================================================
    // 5. 删除数据库记录（CASCADE 会处理子表）
    // ============================================================
    const itemIds = plaidItems.map((item: any) => item.id)

    // plaid_items 的 CASCADE 会自动删除:
    // - plaid_accounts (ON DELETE CASCADE)
    //   - transactions (ON DELETE CASCADE from plaid_accounts)
    //   - investment_holdings (ON DELETE CASCADE from plaid_accounts)
    const { error: deleteError } = await supabase
      .from('plaid_items')
      .delete()
      .in('id', itemIds)

    if (deleteError) {
      console.error('[disconnect] Error deleting plaid_items:', deleteError)
    }

    // 删除净资产历史（不受 CASCADE 影响）
    if (!plaidItemId) {
      // 只有断开全部时才清空历史
      await supabase
        .from('net_worth_history')
        .delete()
        .eq('user_id', user.id)
    }

    // ============================================================
    // 6. 更新 user_profiles
    // ============================================================
    // 检查用户是否还有其他连接
    const { data: remainingItems } = await supabase
      .from('plaid_items')
      .select('id')
      .eq('user_id', user.id)
      .limit(1)

    const hasRemainingConnections = remainingItems && remainingItems.length > 0

    if (!hasRemainingConnections) {
      await supabase
        .from('user_profiles')
        .update({
          has_linked_bank: false,
          plaid_net_worth: null,
          plaid_net_worth_updated_at: null,
        })
        .eq('user_id', user.id)
    }

    // ============================================================
    // 7. 返回结果
    // ============================================================
    return new Response(
      JSON.stringify({
        success: true,
        data: {
          removed_count: plaidItems.length,
          removed_institutions: removedItems,
          has_remaining_connections: hasRemainingConnections,
        },
        meta: {
          timestamp: new Date().toISOString(),
          user_id: user.id,
        },
      }),
      { status: 200, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    )
  } catch (error) {
    console.error('Error in disconnect-bank:', error)

    return new Response(
      JSON.stringify({ success: false, error: { code: 'INTERNAL_SERVER_ERROR', message: error.message || 'An unexpected error occurred' } }),
      { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    )
  }
})