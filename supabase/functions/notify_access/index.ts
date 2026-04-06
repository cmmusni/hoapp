import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import {
  corsHeaders,
  jsonResponse,
  errorResponse,
  createAdminClient,
} from '../_shared/utils.ts'
import { sendEmail } from '../_shared/email.ts'

serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  try {
    if (req.method !== 'POST') {
      return errorResponse('Method not allowed', 405)
    }

    const body = await req.json()
    const { fingerprint, platform } = body as {
      fingerprint?: string
      platform?: string
    }

    if (!fingerprint || fingerprint.length < 8 || fingerprint.length > 128) {
      return errorResponse('Invalid or missing fingerprint', 400)
    }

    const userAgent = req.headers.get('user-agent') ?? 'unknown'
    // Client IP from Supabase edge: x-forwarded-for or cf-connecting-ip
    const ipAddress =
      req.headers.get('x-forwarded-for')?.split(',')[0]?.trim() ??
      req.headers.get('cf-connecting-ip') ??
      'unknown'

    const supabase = createAdminClient()

    // Check if fingerprint OR IP is already known
    const { data: knownFingerprint } = await supabase
      .from('portal_access_log')
      .select('id')
      .eq('fingerprint', fingerprint)
      .limit(1)
      .maybeSingle()

    const { data: knownIP } = await supabase
      .from('portal_access_log')
      .select('id')
      .eq('ip_address', ipAddress)
      .limit(1)
      .maybeSingle()

    // Always log the access (upsert by fingerprint+ip combo)
    const { data: existingCombo } = await supabase
      .from('portal_access_log')
      .select('id')
      .eq('fingerprint', fingerprint)
      .eq('ip_address', ipAddress)
      .maybeSingle()

    if (existingCombo) {
      await supabase
        .from('portal_access_log')
        .update({ last_seen_at: new Date().toISOString(), user_agent: userAgent })
        .eq('id', existingCombo.id)
    } else {
      await supabase.from('portal_access_log').insert({
        fingerprint,
        user_agent: userAgent,
        ip_address: ipAddress,
        platform: platform ?? 'unknown',
      })
    }

    // Only send email if BOTH fingerprint and IP are completely new
    if (knownFingerprint || knownIP) {
      return jsonResponse({ ok: true, new_access: false })
    }

    // Look up the platform admin to send notification
    const { data: adminRole } = await supabase
      .from('platform_roles')
      .select('user_id')
      .eq('role', 'app_admin')
      .maybeSingle()

    if (!adminRole) {
      console.warn('No platform admin found')
      return jsonResponse({ ok: true, new_access: true, sent: false })
    }

    const { data: { user: adminUser } } = await supabase.auth.admin.getUserById(
      adminRole.user_id
    )

    if (!adminUser?.email) {
      console.warn('Platform admin has no email')
      return jsonResponse({ ok: true, new_access: true, sent: false })
    }

    const timestamp = new Date().toLocaleString('en-US', {
      timeZone: 'Asia/Manila',
      dateStyle: 'medium',
      timeStyle: 'short',
    })

    // Sanitize values for HTML output
    const safeUA = userAgent.replace(/[<>&"']/g, '')
    const safePlatform = (platform ?? 'unknown').replace(/[<>&"']/g, '')
    const safeIP = ipAddress.replace(/[<>&"']/g, '')

    const sent = await sendEmail({
      to: adminUser.email,
      subject: `[HOApp] New device & IP accessed portal – ${timestamp}`,
      html: `
        <div style="font-family: Arial, sans-serif; max-width: 600px; margin: 0 auto;">
          <h2 style="color: #215e3f;">🆕 New Device &amp; IP Detected</h2>
          <p>A completely new visitor accessed <strong>hoapp.net</strong> at <strong>${timestamp}</strong> (Asia/Manila).</p>
          <table style="width: 100%; border-collapse: collapse; margin-top: 16px;">
            <tr>
              <td style="padding: 8px; font-weight: bold; vertical-align: top; width: 110px;">Platform:</td>
              <td style="padding: 8px;">${safePlatform}</td>
            </tr>
            <tr>
              <td style="padding: 8px; font-weight: bold; vertical-align: top;">IP Address:</td>
              <td style="padding: 8px;">${safeIP}</td>
            </tr>
            <tr>
              <td style="padding: 8px; font-weight: bold; vertical-align: top;">Browser:</td>
              <td style="padding: 8px; word-break: break-all;">${safeUA}</td>
            </tr>
          </table>
          <hr style="margin-top: 24px; border: none; border-top: 1px solid #eee;" />
          <p style="color: #888; font-size: 12px;">This is an automated access notification from HOApp.</p>
        </div>
      `,
    })

    return jsonResponse({ ok: true, new_access: true, sent })
  } catch (err) {
    console.error('notify_access error:', err)
    return errorResponse('Internal server error', 500)
  }
})
