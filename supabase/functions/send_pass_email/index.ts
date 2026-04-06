import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import {
  corsHeaders,
  jsonResponse,
  errorResponse,
  createAdminClient,
  withErrorHandling,
  validateAuth,
} from '../_shared/utils.ts'
import { sendEmail, generatePassQrEmailHTML } from '../_shared/email.ts'

/**
 * send_pass_email — Email the QR code to the visitor's email address.
 *
 * POST body:
 * {
 *   "pass_id":       "<uuid>",   // required
 *   "community_id":  "<uuid>"    // required
 * }
 *
 * The function looks up:
 *  1. The security pass (visitor_name, visitor_email, qr_token, purpose, valid_from, valid_until)
 *  2. Community name
 *  3. Requester profile name and unit
 *
 * If the pass has no visitor_email, it returns ok: true with skipped: true.
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
    const { pass_id, community_id } = body

    // Authenticate caller
    const authResult = await validateAuth(req, body)
    if (authResult instanceof Response) return authResult

    if (!pass_id || !community_id) {
      return errorResponse('Missing required fields: pass_id, community_id', 400)
    }

    const supabase = createAdminClient()

    // 1. Load the security pass
    const { data: pass, error: passErr } = await supabase
      .from('security_passes')
      .select('visitor_name, visitor_email, qr_token, purpose, valid_from, valid_until, requested_by')
      .eq('id', pass_id)
      .eq('community_id', community_id)
      .maybeSingle()

    if (passErr || !pass) {
      console.warn('Pass not found:', pass_id)
      return jsonResponse({ ok: true, skipped: true, reason: 'pass_not_found' })
    }

    if (!pass.visitor_email) {
      console.log('No visitor email for pass', pass_id)
      return jsonResponse({ ok: true, skipped: true, reason: 'no_visitor_email' })
    }

    if (!pass.qr_token) {
      console.log('No QR token for pass', pass_id)
      return jsonResponse({ ok: true, skipped: true, reason: 'no_qr_token' })
    }

    // 2. Load community name
    const { data: community } = await supabase
      .from('communities')
      .select('name')
      .eq('id', community_id)
      .maybeSingle()

    const communityName = community?.name || 'Your Community'

    // 3. Load requester name from profile
    let requesterName = 'A resident'
    let unitNo: string | undefined

    if (pass.requested_by) {
      const { data: profile } = await supabase
        .from('profiles')
        .select('full_name')
        .eq('user_id', pass.requested_by)
        .eq('community_id', community_id)
        .maybeSingle()

      if (profile?.full_name) {
        requesterName = profile.full_name
      }

      // Get unit number via household_members
      const { data: member } = await supabase
        .from('household_members')
        .select('units(unit_no)')
        .eq('user_id', pass.requested_by)
        .eq('community_id', community_id)
        .maybeSingle()

      if (member?.units && typeof member.units === 'object' && (member.units as any).unit_no) {
        unitNo = (member.units as any).unit_no
      }
    }

    // 4. Format dates
    const fmtDate = (iso: string) => {
      const d = new Date(iso)
      return d.toLocaleDateString('en-US', {
        year: 'numeric',
        month: 'short',
        day: 'numeric',
        hour: 'numeric',
        minute: '2-digit',
      })
    }

    // 5. Generate and send email
    const html = generatePassQrEmailHTML({
      visitorName: pass.visitor_name || 'Visitor',
      communityName,
      qrToken: pass.qr_token,
      purpose: pass.purpose || undefined,
      validFrom: fmtDate(pass.valid_from),
      validUntil: fmtDate(pass.valid_until),
      requestedBy: requesterName,
      unitNo,
    })

    const sent = await sendEmail({
      to: pass.visitor_email,
      subject: `Your Security Pass for ${communityName}`,
      html,
    })

    return jsonResponse({
      ok: true,
      email_sent: sent,
      recipient: pass.visitor_email,
    })
  }, 'send_pass_email')
})
