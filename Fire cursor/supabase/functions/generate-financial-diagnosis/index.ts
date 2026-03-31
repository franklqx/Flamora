// supabase/functions/generate-financial-diagnosis/index.ts
//
// NEW: Analyzes user's financial data and generates AI-powered insights
// Uses Claude Haiku for text generation, all math done in code (not by AI)

import { serve } from 'https://deno.land/std@0.168.0/http/server.ts'
import { corsHeaders, handleCors } from '../_shared/cors.ts'
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

interface DiagnosisRequest {
  // From calculate-avg-spending
  avg_monthly_spending: number
  avg_monthly_needs: number
  avg_monthly_wants: number
  avg_monthly_income_detected: number
  months_analyzed: number
  monthly_breakdown: Array<{ month: string; needs: number; wants: number; total: number }>
  income_discrepancy: boolean
  manual_income: number
  fallback?: boolean

  // From get-user-profile
  age: number
  plaid_net_worth: number
}

serve(async (req) => {
  const corsResponse = handleCors(req)
  if (corsResponse) return corsResponse

  try {
    // ============================================================
    // 1. Auth
    // ============================================================
    const authHeader = req.headers.get('Authorization')
    if (!authHeader) {
      return new Response(
        JSON.stringify({ success: false, error: { code: 'UNAUTHORIZED', message: 'Missing Authorization header' } }),
        { status: 401, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }

    const supabase = createClient(
      Deno.env.get('SUPABASE_URL') ?? '',
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? ''
    )

    const token = authHeader.replace('Bearer ', '')
    const { data: { user }, error: authError } = await supabase.auth.getUser(token)
    if (authError || !user) {
      return new Response(
        JSON.stringify({ success: false, error: { code: 'UNAUTHORIZED', message: 'Invalid token' } }),
        { status: 401, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }

    // ============================================================
    // 2. Parse request
    // ============================================================
    const body: DiagnosisRequest = await req.json()

    // ============================================================
    // 3. Compute metrics (ALL math done here, not by AI)
    // ============================================================
    const income = body.manual_income || body.avg_monthly_income_detected || 1
    const spending = body.avg_monthly_spending
    const savings = income - spending
    const savingsRate = income > 0 ? (savings / income) * 100 : 0
    const needsRatio = spending > 0 ? (body.avg_monthly_needs / spending) * 100 : 60
    const wantsRatio = spending > 0 ? (body.avg_monthly_wants / spending) * 100 : 40

    // Monthly volatility
    const totals = body.monthly_breakdown.map(m => m.total)
    const maxSpending = totals.length > 0 ? Math.max(...totals) : spending
    const minSpending = totals.length > 0 ? Math.min(...totals) : spending
    const maxMonth = body.monthly_breakdown.find(m => m.total === maxSpending)?.month || 'N/A'
    const minMonth = body.monthly_breakdown.find(m => m.total === minSpending)?.month || 'N/A'
    const volatility = spending > 0 ? ((maxSpending - minSpending) / spending) * 100 : 0

    // Negative savings months
    const negativeSavingsMonths = body.monthly_breakdown.filter(m => m.total > income).length

    // Top wants category estimation (we don't have subcategory data here,
    // but the AI prompt will reference general patterns)

    const metrics = {
      avg_income: round2(income),
      avg_spending: round2(spending),
      avg_savings: round2(savings),
      savings_rate: round2(savingsRate),
      needs_total: round2(body.avg_monthly_needs),
      wants_total: round2(body.avg_monthly_wants),
      needs_ratio: round2(needsRatio),
      wants_ratio: round2(wantsRatio),
      net_worth: round2(body.plaid_net_worth || 0),
      age: body.age,
      months_analyzed: body.months_analyzed,
      negative_savings_months: negativeSavingsMonths,
      spending_volatility: round2(volatility),
      max_spending_month: maxMonth,
      max_spending_amount: round2(maxSpending),
      min_spending_month: minMonth,
      min_spending_amount: round2(minSpending),
      income_discrepancy: body.income_discrepancy,
    }

    // ============================================================
    // 4. Call Claude Haiku for AI text generation
    // ============================================================
    const anthropicKey = Deno.env.get('ANTHROPIC_API_KEY')
    let aiDiagnosis: any = null

    if (anthropicKey) {
      try {
        aiDiagnosis = await generateAIDiagnosis(anthropicKey, metrics, body.monthly_breakdown)
      } catch (aiError) {
        console.error('AI diagnosis error (falling back to rules):', aiError)
        // Fall through to rule-based fallback
      }
    }

    // Fallback if AI fails or no API key
    if (!aiDiagnosis) {
      aiDiagnosis = generateRuleBasedDiagnosis(metrics)
    }

    // ============================================================
    // 5. Return
    // ============================================================
    return new Response(
      JSON.stringify({
        success: true,
        data: {
          metrics,
          ai_diagnosis: aiDiagnosis,
        },
        meta: {
          timestamp: new Date().toISOString(),
          user_id: user.id,
          ai_powered: anthropicKey ? true : false,
        },
      }),
      { status: 200, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    )
  } catch (error) {
    console.error('Error in generate-financial-diagnosis:', error)
    return new Response(
      JSON.stringify({ success: false, error: { code: 'INTERNAL_SERVER_ERROR', message: error.message || 'An unexpected error occurred' } }),
      { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    )
  }
})


// ============================================================
// AI Diagnosis via Claude Haiku
// ============================================================
async function generateAIDiagnosis(
  apiKey: string,
  metrics: any,
  monthlyBreakdown: any[]
): Promise<any> {

  const systemPrompt = `You are a financial analyst for Flamora, a FIRE (Financial Independence, Retire Early) app. Generate a financial diagnosis based on real bank data.

RULES:
- Return ONLY valid JSON, no markdown, no backticks, no preamble
- Be specific with the exact numbers provided (use $ formatting like $2,400)
- Be encouraging but honest about problems
- Keep each insight to 2-3 sentences max
- Reference specific months when relevant
- Generate exactly 3 insights with a good mix of types

JSON structure:
{
  "insights": [
    { "type": "positive" | "warning" | "tip", "title": "5-8 word headline", "description": "2-3 sentences with specific numbers" }
  ],
  "summary": "3-4 sentence overall assessment"
}`

  const trendStr = monthlyBreakdown
    .map(m => `${m.month}: Needs $${Math.round(m.needs).toLocaleString()}, Wants $${Math.round(m.wants).toLocaleString()}, Total $${Math.round(m.total).toLocaleString()}`)
    .join('\n')

  const userPrompt = `User financial data (past ${metrics.months_analyzed} months):

INCOME: $${Math.round(metrics.avg_income).toLocaleString()}/month
SPENDING: $${Math.round(metrics.avg_spending).toLocaleString()}/month (Needs ${metrics.needs_ratio.toFixed(0)}%, Wants ${metrics.wants_ratio.toFixed(0)}%)
SAVINGS: $${Math.round(metrics.avg_savings).toLocaleString()}/month (${metrics.savings_rate.toFixed(1)}% rate)
NET WORTH: $${Math.round(metrics.net_worth).toLocaleString()}
AGE: ${metrics.age}

MONTHLY TREND:
${trendStr}

ALERTS:
- Negative savings months: ${metrics.negative_savings_months} of ${metrics.months_analyzed}
- Highest spend: ${metrics.max_spending_month} at $${Math.round(metrics.max_spending_amount).toLocaleString()}
- Lowest spend: ${metrics.min_spending_month} at $${Math.round(metrics.min_spending_amount).toLocaleString()}
- Spending volatility: ${metrics.spending_volatility.toFixed(0)}%
- Income discrepancy (bank vs self-reported): ${metrics.income_discrepancy ? 'YES' : 'No'}`

  const response = await fetch('https://api.anthropic.com/v1/messages', {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      'x-api-key': apiKey,
      'anthropic-version': '2023-06-01',
    },
    body: JSON.stringify({
      model: 'claude-haiku-4-5-20251001',
      max_tokens: 800,
      system: systemPrompt,
      messages: [{ role: 'user', content: userPrompt }],
    }),
  })

  if (!response.ok) {
    const errText = await response.text()
    throw new Error(`Anthropic API error ${response.status}: ${errText}`)
  }

  const data = await response.json()
  const text = data.content?.[0]?.text || ''

  // Parse JSON (strip any accidental backticks)
  const clean = text.replace(/```json\s?/g, '').replace(/```/g, '').trim()
  return JSON.parse(clean)
}


// ============================================================
// Rule-based fallback (no AI needed)
// ============================================================
function generateRuleBasedDiagnosis(metrics: any): any {
  const insights: any[] = []

  // Insight 1: Savings rate
  if (metrics.savings_rate >= 30) {
    insights.push({
      type: 'positive',
      title: 'Excellent savings rate',
      description: `You're saving $${Math.round(metrics.avg_savings).toLocaleString()}/month — a ${metrics.savings_rate.toFixed(1)}% savings rate. This is well above average and puts you on a strong path to FIRE.`,
    })
  } else if (metrics.savings_rate >= 15) {
    insights.push({
      type: 'positive',
      title: 'Solid savings foundation',
      description: `You're saving $${Math.round(metrics.avg_savings).toLocaleString()}/month — a ${metrics.savings_rate.toFixed(1)}% savings rate. There's room to grow, but you're building a good habit.`,
    })
  } else if (metrics.savings_rate >= 0) {
    insights.push({
      type: 'warning',
      title: 'Savings rate needs attention',
      description: `Your savings rate is ${metrics.savings_rate.toFixed(1)}%. For FIRE, most experts recommend at least 20-30%. Look for areas to cut back.`,
    })
  } else {
    insights.push({
      type: 'warning',
      title: 'Spending exceeds income',
      description: `You're spending more than you earn — averaging $${Math.round(Math.abs(metrics.avg_savings)).toLocaleString()}/month in deficit. Addressing this is the first step toward financial freedom.`,
    })
  }

  // Insight 2: Spending volatility
  if (metrics.negative_savings_months > 0) {
    insights.push({
      type: 'warning',
      title: `Spending spike in ${metrics.max_spending_month}`,
      description: `Your spending hit $${Math.round(metrics.max_spending_amount).toLocaleString()} in ${metrics.max_spending_month}, exceeding your income. ${metrics.negative_savings_months} out of ${metrics.months_analyzed} months had negative savings.`,
    })
  } else if (metrics.spending_volatility > 30) {
    insights.push({
      type: 'tip',
      title: 'Your spending varies a lot',
      description: `There's a ${metrics.spending_volatility.toFixed(0)}% gap between your highest and lowest months. Smoothing this out will make budgeting easier and more predictable.`,
    })
  } else {
    insights.push({
      type: 'positive',
      title: 'Consistent spending pattern',
      description: `Your monthly spending is relatively stable. This consistency makes it easier to plan and optimize your budget for FIRE.`,
    })
  }

  // Insight 3: Wants ratio
  if (metrics.wants_ratio > 40) {
    insights.push({
      type: 'tip',
      title: 'Discretionary spending is high',
      description: `Wants make up ${metrics.wants_ratio.toFixed(0)}% of your spending ($${Math.round(metrics.wants_total).toLocaleString()}/month). Even a 10% reduction could add $${Math.round(metrics.wants_total * 0.1 * 12).toLocaleString()}/year to investments.`,
    })
  } else {
    insights.push({
      type: 'positive',
      title: 'Well-balanced spending mix',
      description: `Your needs-to-wants ratio (${metrics.needs_ratio.toFixed(0)}/${metrics.wants_ratio.toFixed(0)}) shows disciplined spending. You're keeping discretionary costs in check.`,
    })
  }

  // Summary
  const summaryParts: string[] = []
  if (metrics.savings_rate >= 20) {
    summaryParts.push(`A ${metrics.savings_rate.toFixed(1)}% savings rate gives you strong FIRE momentum.`)
  } else {
    summaryParts.push(`At ${metrics.savings_rate.toFixed(1)}%, there's an opportunity to increase your savings rate.`)
  }
  if (metrics.net_worth > 0) {
    summaryParts.push(`With $${Math.round(metrics.net_worth).toLocaleString()} in investments at age ${metrics.age}, you have a foundation to build on.`)
  }
  summaryParts.push('Setting a budget aligned with your FIRE goal is the next step to accelerate your timeline.')

  return {
    insights,
    summary: summaryParts.join(' '),
  }
}


function round2(value: number): number {
  return Math.round(value * 100) / 100
}
