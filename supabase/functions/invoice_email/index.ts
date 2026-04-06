import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import {
  corsHeaders,
  jsonResponse,
  errorResponse,
  createAdminClient,
  withErrorHandling,
  validateAuth,
} from '../_shared/utils.ts'
import { sendEmail, generateInvoiceNotificationHTML } from '../_shared/email.ts'

/**
 * invoice_email — Send an email notification to the primary household member
 * of the invoiced unit after a new invoice is created.
 *
 * POST body:
 * {
 *   "invoice_id":    "<uuid>",   // required
 *   "community_id":  "<uuid>",   // required
 *   "unit_id":       "<uuid>",   // required
 *   "amount":        1234.56,    // required
 *   "due_date":      "2026-05-01", // required (ISO date string)
 *   "description":   "Monthly Dues + Water" // optional
 * }
 *
 * The function looks up:
 *  1. Community name & slug (for the portal link)
 *  2. Unit number
 *  3. First primary household member with an email address
 *
 * If no eligible recipient is found the function returns ok: true with
 * skipped: true so the caller never fails.
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
    const { invoice_id, community_id, unit_id, amount, due_date, description } = body

    // Authenticate caller (supports x-user-token, Authorization header, _jwt in body)
    const authResult = await validateAuth(req, body)
    if (authResult instanceof Response) return authResult
    const { user } = authResult

    const supabase = createAdminClient()

    if (!invoice_id || !community_id || !unit_id || amount == null || !due_date) {
      return errorResponse('Missing required fields: invoice_id, community_id, unit_id, amount, due_date', 400)
    }

    // 1. Load community (name + slug for portal link)
    const { data: community, error: comErr } = await supabase
      .from('communities')
      .select('name, slug')
      .eq('id', community_id)
      .maybeSingle()

    if (comErr || !community) {
      console.warn('Community not found:', community_id)
      return jsonResponse({ ok: true, skipped: true, reason: 'community_not_found' })
    }

    // 2. Load unit number
    const { data: unit, error: unitErr } = await supabase
      .from('units')
      .select('unit_no')
      .eq('id', unit_id)
      .maybeSingle()

    if (unitErr || !unit) {
      console.warn('Unit not found:', unit_id)
      return jsonResponse({ ok: true, skipped: true, reason: 'unit_not_found' })
    }

    // 3. Find the first primary household member of this unit
    const { data: members, error: memErr } = await supabase
      .from('household_members')
      .select('user_id')
      .eq('unit_id', unit_id)
      .eq('member_role', 'primary')
      .limit(10)

    if (memErr || !members || members.length === 0) {
      console.log('No primary household members for unit', unit_id)
      return jsonResponse({ ok: true, skipped: true, reason: 'no_primary_member' })
    }

    // 4. Find the first primary member who has an email address
    let recipientEmail: string | null = null
    let recipientName: string | null = null

    for (const member of members) {
      const { data: { user: memberUser }, error: userErr } = await supabase.auth.admin.getUserById(member.user_id)
      if (userErr || !memberUser) continue

      const email = memberUser.email
      if (email) {
        recipientEmail = email

        // Try to get full name from profiles table
        const { data: profile } = await supabase
          .from('profiles')
          .select('full_name')
          .eq('user_id', member.user_id)
          .eq('community_id', community_id)
          .maybeSingle()

        recipientName = profile?.full_name || memberUser.user_metadata?.full_name || email.split('@')[0]
        break
      }
    }

    if (!recipientEmail) {
      console.log('No primary member with email found for unit', unit_id)
      return jsonResponse({ ok: true, skipped: true, reason: 'no_member_with_email' })
    }

    // 5. Build the portal link
    const baseUrl = Deno.env.get('WEB_BASE_URL') || 'https://hoapp.net'
    const portalLink = `${baseUrl}/${community.slug}/billing`

    // 6. Format due date for display
    const dueDateObj = new Date(due_date)
    const formattedDueDate = dueDateObj.toLocaleDateString('en-US', {
      year: 'numeric',
      month: 'long',
      day: 'numeric',
    })

    // 7. Generate and send email
    const html = generateInvoiceNotificationHTML({
      recipientName: recipientName || 'Resident',
      communityName: community.name,
      amount: typeof amount === 'number' ? amount : parseFloat(amount),
      dueDate: formattedDueDate,
      description: description || undefined,
      portalLink,
      unitNo: unit.unit_no,
    })

    const sent = await sendEmail({
      to: recipientEmail,
      subject: `New Invoice – ₱${amount.toLocaleString('en-PH', { minimumFractionDigits: 2 })} due ${formattedDueDate} | ${community.name}`,
      html,
    })

    console.log(`Invoice email ${sent ? 'sent' : 'failed'} to ${recipientEmail} for invoice ${invoice_id}`)

    return jsonResponse({ ok: true, sent, recipientEmail })
  }, 'invoice_email')
})
