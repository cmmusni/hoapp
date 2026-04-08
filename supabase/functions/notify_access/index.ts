import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import {
  corsHeaders,
  jsonResponse,
  errorResponse,
  createAdminClient,
} from '../_shared/utils.ts'
import { sendEmail } from '../_shared/email.ts'

/** Parse user-agent string into browser and OS components. */
function parseUserAgent(ua: string): { browser: string; os: string } {
  let browser = 'Unknown'
  let os = 'Unknown'

  // --- Browser detection ---
  if (ua.includes('Firefox/') && !ua.includes('Seamonkey')) {
    const m = ua.match(/Firefox\/([\d.]+)/)
    browser = `Firefox ${m?.[1] ?? ''}`
  } else if (ua.includes('Edg/')) {
    const m = ua.match(/Edg\/([\d.]+)/)
    browser = `Microsoft Edge ${m?.[1] ?? ''}`
  } else if (ua.includes('OPR/') || ua.includes('Opera/')) {
    const m = ua.match(/(?:OPR|Opera)\/([\d.]+)/)
    browser = `Opera ${m?.[1] ?? ''}`
  } else if (ua.includes('Chrome/') && !ua.includes('Chromium')) {
    const m = ua.match(/Chrome\/([\d.]+)/)
    browser = `Chrome ${m?.[1] ?? ''}`
  } else if (ua.includes('Safari/') && !ua.includes('Chrome') && !ua.includes('Chromium')) {
    const m = ua.match(/Version\/([\d.]+)/)
    browser = `Safari ${m?.[1] ?? ''}`
  }

  // --- OS detection ---
  if (ua.includes('Windows NT 10')) os = 'Windows 10/11'
  else if (ua.includes('Windows NT 6.3')) os = 'Windows 8.1'
  else if (ua.includes('Windows NT 6.1')) os = 'Windows 7'
  else if (ua.includes('Windows')) os = 'Windows'
  else if (ua.includes('Mac OS X')) {
    const m = ua.match(/Mac OS X ([\d_]+)/)
    os = `macOS ${m?.[1]?.replace(/_/g, '.') ?? ''}`
  } else if (ua.includes('Android')) {
    const m = ua.match(/Android ([\d.]+)/)
    os = `Android ${m?.[1] ?? ''}`
  } else if (ua.includes('iPhone OS') || ua.includes('iPad')) {
    const m = ua.match(/OS ([\d_]+)/)
    os = `iOS ${m?.[1]?.replace(/_/g, '.') ?? ''}`
  } else if (ua.includes('Linux')) os = 'Linux'

  return { browser: browser.trim(), os: os.trim() }
}

/** Map ISO 3166-1 alpha-2 country code to flag emoji + name. */
function countryLabel(code: string | null): string {
  if (!code || code.length !== 2) return 'Unknown'
  const names: Record<string, string> = {
    PH: 'Philippines', US: 'United States', SG: 'Singapore', JP: 'Japan',
    DE: 'Germany', GB: 'United Kingdom', AU: 'Australia', CA: 'Canada',
    IN: 'India', KR: 'South Korea', HK: 'Hong Kong', MY: 'Malaysia',
    TH: 'Thailand', ID: 'Indonesia', VN: 'Vietnam', TW: 'Taiwan',
    FR: 'France', NL: 'Netherlands', BR: 'Brazil', AE: 'UAE',
  }
  // Convert country code to flag emoji (regional indicator symbols)
  const flag = String.fromCodePoint(
    ...[...code.toUpperCase()].map(c => 0x1F1E6 + c.charCodeAt(0) - 65)
  )
  return `${flag} ${names[code.toUpperCase()] ?? code.toUpperCase()}`
}

/** Sanitize a value for safe HTML output. */
function esc(val: unknown): string {
  return String(val ?? '—').replace(/[<>&"']/g, '')
}

serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  try {
    if (req.method !== 'POST') {
      return errorResponse('Method not allowed', 405)
    }

    const body = await req.json()
    const {
      fingerprint,
      platform,
      screen_resolution,
      color_depth,
      language,
      languages,
      timezone,
      timezone_offset,
      referrer,
      page_url,
      cookie_enabled,
      online,
      hardware_concurrency,
      device_memory,
      touch_support,
    } = body as Record<string, unknown>

    if (!fingerprint || typeof fingerprint !== 'string' || fingerprint.length < 8 || fingerprint.length > 128) {
      return errorResponse('Invalid or missing fingerprint', 400)
    }

    const userAgent = req.headers.get('user-agent') ?? 'unknown'
    // Client IP from Supabase edge: x-forwarded-for or cf-connecting-ip
    const ipAddress =
      req.headers.get('x-forwarded-for')?.split(',')[0]?.trim() ??
      req.headers.get('cf-connecting-ip') ??
      'unknown'

    // Cloudflare geolocation headers
    const cfCountry = req.headers.get('cf-ipcountry')
    const cfCity = req.headers.get('cf-ipcity')
    const cfRegion = req.headers.get('cf-region')
    const cfTimezone = req.headers.get('cf-timezone')
    const cfASN = req.headers.get('cf-asn')

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

    // Parse user-agent for readable browser/OS info
    const { browser, os } = parseUserAgent(userAgent)

    // Build location string from Cloudflare headers
    const locationParts: string[] = []
    if (cfCity) locationParts.push(cfCity)
    if (cfRegion) locationParts.push(cfRegion)
    const countryStr = countryLabel(cfCountry)
    if (countryStr !== 'Unknown') locationParts.push(countryStr)
    const locationStr = locationParts.length > 0 ? locationParts.join(', ') : 'Unknown'

    // Build device spec summary
    const deviceSpecs: string[] = []
    if (hardware_concurrency) deviceSpecs.push(`${hardware_concurrency} CPU cores`)
    if (device_memory) deviceSpecs.push(`${device_memory} GB RAM`)
    if (touch_support && Number(touch_support) > 0) deviceSpecs.push(`Touch (${touch_support} points)`)
    else deviceSpecs.push('No touch')
    const deviceSpecStr = deviceSpecs.length > 0 ? deviceSpecs.join(' · ') : '—'

    // Helper for table rows
    const row = (label: string, value: string, icon = '') =>
      `<tr>
        <td style="padding: 8px 12px; font-weight: 600; vertical-align: top; width: 150px; color: #555; white-space: nowrap;">${icon} ${esc(label)}</td>
        <td style="padding: 8px 12px; word-break: break-all;">${value}</td>
      </tr>`

    const sectionHeader = (title: string) =>
      `<tr><td colspan="2" style="padding: 16px 12px 6px; font-weight: 700; font-size: 14px; color: #215e3f; border-bottom: 1px solid #e0e0e0;">${title}</td></tr>`

    const sent = await sendEmail({
      to: adminUser.email,
      subject: `[HOApp] New device accessed portal – ${timestamp}`,
      html: `
        <div style="font-family: 'Segoe UI', Arial, sans-serif; max-width: 640px; margin: 0 auto; background: #fff; border: 1px solid #e8e8e8; border-radius: 8px; overflow: hidden;">
          <div style="background: #215e3f; padding: 20px 24px;">
            <h2 style="color: #fff; margin: 0; font-size: 20px;">🆕 New Device Detected</h2>
            <p style="color: #b8dfc9; margin: 6px 0 0; font-size: 13px;">A completely new visitor accessed <strong>hoapp.net</strong></p>
          </div>
          <div style="padding: 0 8px 16px;">
            <table style="width: 100%; border-collapse: collapse; font-size: 14px;">
              ${sectionHeader('📍 Location & Network')}
              ${row('Location', esc(locationStr), '')}
              ${row('IP Address', esc(ipAddress), '')}
              ${cfASN ? row('ASN', esc(cfASN), '') : ''}
              ${row('Timestamp', `${esc(timestamp)} (Asia/Manila)`, '')}

              ${sectionHeader('🖥️ Browser & OS')}
              ${row('Browser', esc(browser), '')}
              ${row('Operating System', esc(os), '')}
              ${row('Platform', esc(platform ?? 'unknown'), '')}
              ${row('Full User-Agent', `<span style="font-size: 12px; color: #777;">${esc(userAgent)}</span>`, '')}

              ${sectionHeader('📱 Device Details')}
              ${row('Screen', esc(screen_resolution ?? '—'), '')}
              ${row('Color Depth', screen_resolution ? `${esc(color_depth)}-bit` : '—', '')}
              ${row('Hardware', esc(deviceSpecStr), '')}

              ${sectionHeader('🌐 Browser Settings')}
              ${row('Language', esc(language ?? '—'), '')}
              ${languages ? row('All Languages', esc(languages), '') : ''}
              ${row('Timezone', `${esc(timezone ?? cfTimezone ?? '—')} (UTC${Number(timezone_offset) >= 0 ? '+' : ''}${timezone_offset ?? '?'} min)`, '')}
              ${row('Cookies', cookie_enabled ? '✅ Enabled' : '❌ Disabled', '')}
              ${row('Online', online ? '✅ Yes' : '❌ No', '')}

              ${referrer ? `${sectionHeader('🔗 Referral')}${row('Referrer', esc(referrer), '')}` : ''}
              ${page_url ? row('Landing Page', esc(page_url), '') : ''}
            </table>
          </div>
          <div style="background: #f9f9f9; padding: 12px 24px; border-top: 1px solid #e8e8e8;">
            <p style="color: #999; font-size: 11px; margin: 0;">This is an automated access notification from HOApp. Fingerprint: <code style="font-size: 10px;">${esc(fingerprint)}</code></p>
          </div>
        </div>
      `,
    })

    return jsonResponse({ ok: true, new_access: true, sent })
  } catch (err) {
    console.error('notify_access error:', err)
    return errorResponse('Internal server error', 500)
  }
})
