// supabase/functions/handle-revenuecat-webhook/index.ts

import { serve } from 'https://deno.land/std@0.168.0/http/server.ts'
import { corsHeaders, handleCors } from '../_shared/cors.ts'
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

serve(async (req) => {
  const corsResponse = handleCors(req)
  if (corsResponse) return corsResponse

  try {
    const supabase = createClient(
      Deno.env.get('SUPABASE_URL')!,
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!
    )

    const body = await req.json()
    const event = body.event
    const eventType = event?.type

    console.log(`[revenuecat-webhook] Received event: ${eventType}`)

    if (!event) {
      return new Response(
        JSON.stringify({ success: false, error: 'No event data' }),
        { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }

    // RevenueCat 发送的 app_user_id 就是我们的 Supabase user_id
    const appUserId = event.app_user_id
    if (!appUserId) {
      console.error('[revenuecat-webhook] Missing app_user_id')
      return new Response(
        JSON.stringify({ success: true, message: 'No app_user_id, skipping' }),
        { status: 200, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }

    // 提取通用字段
    const subscriberId = event.subscriber_id || null
    const productId = event.product_id || null
    const expirationAt = event.expiration_at_ms
      ? new Date(event.expiration_at_ms).toISOString()
      : null

    // ============================================================
    // 根据事件类型处理
    // ============================================================

    switch (eventType) {
      // 新购买 / 续费
      case 'INITIAL_PURCHASE':
      case 'RENEWAL':
      case 'PRODUCT_CHANGE':
      case 'NON_RENEWING_PURCHASE': {
        console.log(`[revenuecat-webhook] Activating subscription for user: ${appUserId}`)

        const subscriptionType = productId?.includes('yearly') ? 'yearly' : 'monthly'

        const { error } = await supabase
          .from('subscriptions')
          .upsert({
            user_id: appUserId,
            subscription_type: subscriptionType,
            status: 'active',
            revenue_cat_id: productId,
            revenue_cat_customer_id: subscriberId,
            started_at: new Date().toISOString(),
            expires_at: expirationAt,
            cancelled_at: null,
            metadata: {
              event_type: eventType,
              product_id: productId,
              last_updated: new Date().toISOString(),
            },
            updated_at: new Date().toISOString(),
          }, { onConflict: 'user_id' })

        if (error) {
          console.error('[revenuecat-webhook] Upsert error:', error)
        }
        break
      }

      // 取消（但可能还在有效期内）
      case 'CANCELLATION': {
        console.log(`[revenuecat-webhook] Cancellation for user: ${appUserId}`)

        const { error } = await supabase
          .from('subscriptions')
          .update({
            status: 'cancelled',
            cancelled_at: new Date().toISOString(),
            expires_at: expirationAt,
            metadata: {
              event_type: eventType,
              cancellation_reason: event.cancel_reason || null,
              last_updated: new Date().toISOString(),
            },
            updated_at: new Date().toISOString(),
          })
          .eq('user_id', appUserId)

        if (error) {
          console.error('[revenuecat-webhook] Update error:', error)
        }
        break
      }

      // 过期（真正失去访问权）
      case 'EXPIRATION': {
        console.log(`[revenuecat-webhook] Expiration for user: ${appUserId}`)

        const { error } = await supabase
          .from('subscriptions')
          .update({
            status: 'expired',
            expires_at: expirationAt || new Date().toISOString(),
            metadata: {
              event_type: eventType,
              last_updated: new Date().toISOString(),
            },
            updated_at: new Date().toISOString(),
          })
          .eq('user_id', appUserId)

        if (error) {
          console.error('[revenuecat-webhook] Update error:', error)
        }
        break
      }

      // 计费问题（付款失败）
      case 'BILLING_ISSUE': {
        console.log(`[revenuecat-webhook] Billing issue for user: ${appUserId}`)

        const { error } = await supabase
          .from('subscriptions')
          .update({
            status: 'billing_issue',
            metadata: {
              event_type: eventType,
              last_updated: new Date().toISOString(),
            },
            updated_at: new Date().toISOString(),
          })
          .eq('user_id', appUserId)

        if (error) {
          console.error('[revenuecat-webhook] Update error:', error)
        }
        break
      }

      // 恢复订阅
      case 'UNCANCELLATION': {
        console.log(`[revenuecat-webhook] Uncancellation for user: ${appUserId}`)

        const { error } = await supabase
          .from('subscriptions')
          .update({
            status: 'active',
            cancelled_at: null,
            expires_at: expirationAt,
            metadata: {
              event_type: eventType,
              last_updated: new Date().toISOString(),
            },
            updated_at: new Date().toISOString(),
          })
          .eq('user_id', appUserId)

        if (error) {
          console.error('[revenuecat-webhook] Update error:', error)
        }
        break
      }

      default:
        console.log(`[revenuecat-webhook] Unhandled event type: ${eventType}`)
    }

    // 始终返回 200
    return new Response(
      JSON.stringify({ success: true, event_type: eventType }),
      { status: 200, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    )
  } catch (error) {
    console.error('[revenuecat-webhook] Error:', error)

    // 即使出错也返回 200，避免 RevenueCat 重试
    return new Response(
      JSON.stringify({ success: true, message: 'Error logged' }),
      { status: 200, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    )
  }
})