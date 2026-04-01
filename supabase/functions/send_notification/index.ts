import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import {
  corsHeaders,
  jsonResponse,
  errorResponse,
  createAdminClient,
} from '../_shared/utils.ts'

/**
 * send_notification — Send web push notifications via OneSignal.
 *
 * POST body:
 * {
 *   "community_id": "<uuid>",          // required – target community
 *   "heading": "New Announcement",      // required – notification title
 *   "content": "Check out…",            // required – notification body
 *   "url": "/c/slug/announcements",     // optional – click URL
 *   "target_user_ids": ["uuid",…],      // optional – specific users (omit for all community members)
 *   "data": { … }                       // optional – custom payload
 * }
 *
 * Requires ONESIGNAL_APP_ID and ONESIGNAL_REST_API_KEY env vars.
 */
serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  try {
    if (req.method !== 'POST') {
      return errorResponse('Method not allowed', 405)
    }

    // Authenticate the caller (must be a staff/admin user or service role)
    const authHeader = req.headers.get('Authorization')
    if (!authHeader) {
      return errorResponse('Missing authorization', 401)
    }

    const supabase = createAdminClient()

    // Verify the JWT to get the calling user
    const token = authHeader.replace('Bearer ', '')
    const { data: { user }, error: authError } = await supabase.auth.getUser(token)
    if (authError || !user) {
      return errorResponse('Invalid token', 401)
    }

    const body = await req.json()
    const { community_id, heading, content, url, target_user_ids, data } = body

    if (!community_id) return errorResponse('community_id is required', 400)
    if (!heading?.trim()) return errorResponse('heading is required', 400)
    if (!content?.trim()) return errorResponse('content is required', 400)

    // Verify the caller is staff/admin in this community
    const { data: roleRow } = await supabase
      .from('user_roles')
      .select('role')
      .eq('user_id', user.id)
      .eq('community_id', community_id)
      .maybeSingle()

    const staffRoles = ['admin', 'staff', 'superadmin']
    if (!roleRow || !staffRoles.includes(roleRow.role)) {
      return errorResponse('Only staff/admin can send notifications', 403)
    }

    // Build OneSignal payload
    const appId = Deno.env.get('ONESIGNAL_APP_ID')
    const apiKey = Deno.env.get('ONESIGNAL_REST_API_KEY')
    if (!appId || !apiKey) {
      return errorResponse('OneSignal not configured on server', 500)
    }

    const osPayload: Record<string, unknown> = {
      app_id: appId,
      headings: { en: heading.trim() },
      contents: { en: content.trim() },
    }

    // Targeting
    if (target_user_ids && Array.isArray(target_user_ids) && target_user_ids.length > 0) {
      // Send to specific users by their external_user_id (Supabase user.id)
      osPayload.include_aliases = { external_id: target_user_ids }
      osPayload.target_channel = 'push'
    } else {
      // Send to all subscribers tagged with this community_id
      osPayload.filters = [
        { field: 'tag', key: 'community_id', relation: '=', value: community_id },
      ]
    }

    if (url) {
      osPayload.url = url
    }

    if (data && typeof data === 'object') {
      osPayload.data = data
    }

    // Send via OneSignal REST API
    const osResponse = await fetch('https://api.onesignal.com/notifications', {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'Authorization': `Key ${apiKey}`,
      },
      body: JSON.stringify(osPayload),
    })

    const osResult = await osResponse.json()

    if (!osResponse.ok) {
      console.error('OneSignal error:', osResult)
      return errorResponse(
        `OneSignal API error: ${osResult.errors?.[0] || 'Unknown error'}`,
        502,
      )
    }

    return jsonResponse({
      ok: true,
      notification_id: osResult.id,
      recipients: osResult.recipients,
    })
  } catch (err) {
    console.error('send_notification error:', err)
    return errorResponse('Internal server error', 500)
  }
})
