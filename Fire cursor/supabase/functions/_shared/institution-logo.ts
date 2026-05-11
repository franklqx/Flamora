// supabase/functions/_shared/institution-logo.ts
//
// Helper to fetch Plaid institution branding (logo + primary color) and cache
// it on the plaid_items row. Logo PNGs from Plaid are base64-encoded and run
// 5–20 KB, so we store them inline rather than serving via a CDN.
//
// Plaid docs: https://plaid.com/docs/api/institutions/#institutionsget_by_id

export interface InstitutionBranding {
  logoBase64: string | null
  primaryColor: string | null
  logoUrl: string | null
}

interface FetchOptions {
  plaidClientId: string
  plaidSecret: string
  plaidBaseUrl: string
}

export async function fetchInstitutionBranding(
  institutionId: string,
  opts: FetchOptions
): Promise<InstitutionBranding | null> {
  try {
    const response = await fetch(`${opts.plaidBaseUrl}/institutions/get_by_id`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        client_id: opts.plaidClientId,
        secret: opts.plaidSecret,
        institution_id: institutionId,
        // US only — matches the Link flow. If you add new countries in Link,
        // update this list to keep institutions/get_by_id from 400-ing.
        country_codes: ['US'],
        options: {
          include_optional_metadata: true,
        },
      }),
    })

    const data = await response.json()
    if (!response.ok) {
      console.error(
        `[institution-logo] Plaid /institutions/get_by_id ${response.status}:`,
        data.error_message || data
      )
      return null
    }

    const inst = data.institution
    return {
      logoBase64: inst?.logo ?? null,
      primaryColor: inst?.primary_color ?? null,
      logoUrl: inst?.url ?? null,
    }
  } catch (err) {
    console.error('[institution-logo] Fetch error:', err)
    return null
  }
}

/**
 * Build a Supabase patch for plaid_items with branding fields + timestamp.
 * Safe to spread into an upsert/update payload — only sets columns when a
 * non-null value is available so re-runs don't blank cached data.
 */
export function brandingPatch(branding: InstitutionBranding | null): Record<string, unknown> {
  const patch: Record<string, unknown> = {
    institution_logo_fetched_at: new Date().toISOString(),
  }
  if (!branding) return patch
  if (branding.logoBase64) patch.institution_logo_base64 = branding.logoBase64
  if (branding.primaryColor) patch.institution_primary_color = branding.primaryColor
  if (branding.logoUrl) patch.institution_logo_url = branding.logoUrl
  return patch
}
