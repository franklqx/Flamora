// supabase/functions/get-transactions/index.ts

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
    // 2. 解析查询参数
    // ============================================================
    const url = new URL(req.url)

    const page = parseInt(url.searchParams.get('page') || '1')
    const limit = Math.min(parseInt(url.searchParams.get('limit') || '50'), 100)
    const offset = (page - 1) * limit

    // 筛选参数
    const category = url.searchParams.get('category')           // needs, wants, income, transfer
    const subcategory = url.searchParams.get('subcategory')     // dining_out, groceries, etc.
    const startDate = url.searchParams.get('start_date')        // 2026-01-01
    const endDate = url.searchParams.get('end_date')            // 2026-01-31
    const pendingReview = url.searchParams.get('pending_review') // true/false
    const search = url.searchParams.get('search')               // 搜索商户名

    // ============================================================
    // 3. 构建查询
    // ============================================================
    let query = supabase
      .from('transactions')
      .select('*', { count: 'exact' })
      .eq('user_id', user.id)
      .eq('pending', false)       // 默认只显示已清算的
      .order('date', { ascending: false })

    // 应用筛选条件
    if (category) {
      query = query.eq('flamora_category', category)
    }

    if (subcategory) {
      query = query.eq('flamora_subcategory', subcategory)
    }

    if (startDate) {
      query = query.gte('date', startDate)
    }

    if (endDate) {
      query = query.lte('date', endDate)
    }

    if (pendingReview === 'true') {
      query = query.eq('pending_review', true)
    } else if (pendingReview === 'false') {
      query = query.eq('pending_review', false)
    }

    if (search) {
      query = query.or(`merchant_name.ilike.%${search}%,name.ilike.%${search}%`)
    }

    // 分页
    query = query.range(offset, offset + limit - 1)

    const { data: transactions, error: txError, count } = await query

    if (txError) {
      console.error('Error fetching transactions:', txError)
      return new Response(
        JSON.stringify({ success: false, error: { code: 'QUERY_ERROR', message: txError.message } }),
        { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }

    // ============================================================
    // 4. 获取 pending_review 数量（总是返回，方便前端显示 badge）
    // ============================================================
    const { count: reviewCount } = await supabase
      .from('transactions')
      .select('*', { count: 'exact', head: true })
      .eq('user_id', user.id)
      .eq('pending_review', true)
      .eq('pending', false)

    // ============================================================
    // 5. 返回结果
    // ============================================================
    return new Response(
      JSON.stringify({
        success: true,
        data: {
          transactions: transactions || [],
          pagination: {
            page,
            limit,
            total: count || 0,
            total_pages: Math.ceil((count || 0) / limit),
            has_more: offset + limit < (count || 0),
          },
          pending_review_count: reviewCount || 0,
        },
        meta: {
          timestamp: new Date().toISOString(),
          user_id: user.id,
        },
      }),
      { status: 200, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    )
  } catch (error) {
    console.error('Error in get-transactions:', error)

    return new Response(
      JSON.stringify({ success: false, error: { code: 'INTERNAL_SERVER_ERROR', message: error.message || 'An unexpected error occurred' } }),
      { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    )
  }
})