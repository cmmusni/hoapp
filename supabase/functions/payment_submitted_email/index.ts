import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import {
  corsHeaders,
  jsonResponse,
  errorResponse,
  createAdminClient,
  withErrorHandling,
  validateAuth,
} from '../_shared/utils.ts'
import { sendEmail, generatePaymentSubmittedHTML } from '../_shared/email.ts'

/**
 * payment_submitted_email — Notify selected community admin(s) when a
 * resident submits a payment for verification.
 *
 * POST body:
 * {
 *   "community_id": "<uuid>",
 *   "invoice_id":   "<uuid>",
 *   "amount":       1234.56
 * }
 *
 * Logic:
 *  1. Load community settings → payment_notification_admin_ids
 *     If not configured, falls back to ALL community_admin users.
 *  2. Look up recipient emails via get_community_user_emails RPC.
 *  3. Resolve submitter name, unit number, and community name.
 *  4. Send email to each selected admin.
 */
serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  return withErrorHandling(async () => {
    if (req.method !== 'POST') {
      return errorResponse('Method not allowed', 405)
    }

    const body = await req.json()
    const { community_id, invoice_id, amount } = body

    const authResult = await validateAuth(req, body)
    if (authResult instanceof Response) return authResult
    const { user } = authResult

    const supabase = createAdminClient()

    if (!community_id || !invoice_id || amount == null) {
      return errorResponse('Missing required fields: community_id, invoice_id, amount', 400)
    }

    // 1. Load community
    const { data: community, error: comErr } = await supabase
      .from('communities')
      .select('name, slug, settings')
      .eq('id', community_id)
      .single()

    if (comErr || !community) {
      return errorResponse('Community not found', 404)
    }

    // 2. Determine which admins to notify
    let targetAdminIds: string[] | null =
      community.settings?.payment_notification_admin_ids ?? null

    // 3. Get all community admins with emails
    const { data: adminRoles } = await supabase
      .from('user_roles')
      .select('user_id')
      .eq('community_id', community_id)
      .eq('role', 'community_admin')

    if (!adminRoles || adminRoles.length === 0) {
      return jsonResponse({ ok: true, skipped: true, reason: 'no admins' })
    }

    // If no specific admins configured, notify all community admins
    if (!targetAdminIds || targetAdminIds.length === 0) {
      targetAdminIds = adminRoles.map((r: any) => r.user_id)
    } else {
      // Filter to only valid community admins
      const validAdminIds = new Set(adminRoles.map((r: any) => r.user_id))
      targetAdminIds = targetAdminIds.filter(id => validAdminIds.has(id))
      if (targetAdminIds.length === 0) {
        targetAdminIds = adminRoles.map((r: any) => r.user_id)
      }
    }

    // 4. Get emails & display names for target admins
    const { data: userEmailRows } = await supabase
      .rpc('get_community_user_emails', { p_community_id: community_id })

    const emailMap: Record<string, { email: string; name: string }> = {}
    if (userEmailRows) {
      for (const row of userEmailRows) {
        if (targetAdminIds.includes(row.user_id) && row.email) {
          emailMap[row.user_id] = {
            email: row.email,
            name: row.display_name || 'Admin',
          }
        }
      }
    }

    if (Object.keys(emailMap).length === 0) {
      return jsonResponse({ ok: true, skipped: true, reason: 'no admin emails found' })
    }

    // 5. Resolve submitter name
    let submitterName = 'A resident'
    const { data: submitterProfile } = await supabase
      .from('profiles')
      .select('full_name')
      .eq('user_id', user.id)
      .eq('community_id', community_id)
      .maybeSingle()

    if (submitterProfile?.full_name) {
      submitterName = submitterProfile.full_name
    } else if (user.email) {
      submitterName = user.email
    }

    // 6. Resolve unit number from invoice
    let unitNo = '-'
    const { data: invoice } = await supabase
      .from('invoices')
      .select('unit_id')
      .eq('id', invoice_id)
      .single()

    if (invoice?.unit_id) {
      const { data: unit } = await supabase
        .from('units')
        .select('unit_no')
        .eq('id', invoice.unit_id)
        .single()

      if (unit?.unit_no) {
        unitNo = unit.unit_no
      }
    }

    // 7. Build portal link
    const portalLink = `https://${community.slug}.hoapp.net/billing`

    // 8. Send emails
    let sentCount = 0
    for (const [, info] of Object.entries(emailMap)) {
      const html = generatePaymentSubmittedHTML({
        adminName: info.name,
        communityName: community.name,
        submitterName,
        unitNo,
        amount,
        invoiceId: invoice_id,
        portalLink,
      })

      const sent = await sendEmail({
        to: info.email,
        subject: `Payment Submitted — ${community.name}`,
        html,
      })
      if (sent) sentCount++
    }

    return jsonResponse({ ok: true, sent: sentCount })
  }, 'payment_submitted_email')
})
