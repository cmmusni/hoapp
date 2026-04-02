import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import {
  corsHeaders,
  jsonResponse,
  errorResponse,
  createAdminClient,
} from '../_shared/utils.ts'

/**
 * onesignal_cleanup — Delete a stale OneSignal user record by external_id
 * so the client SDK can re-claim the alias on a new device/browser.
 *
 * POST body:
 * {
 *   "external_id": "<supabase-user-uuid>"
 * }
 *
 * The caller must be authenticated and the external_id must match their own
 * user.id (users can only clean up their own alias).
 */
serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  try {
    if (req.method !== 'POST') {
      return errorResponse('Method not allowed', 405)
    }

    const authHeader = req.headers.get('Authorization')
    if (!authHeader) {
      return errorResponse('Missing authorization', 401)
    }

    const supabase = createAdminClient()
    const token = authHeader.replace('Bearer ', '')
    const { data: { user }, error: authError } = await supabase.auth.getUser(token)
    if (authError || !user) {
      return errorResponse('Invalid token', 401)
    }

    const { external_id } = await req.json()
    if (!external_id || typeof external_id !== 'string') {
      return errorResponse('external_id is required', 400)
    }

    // Users can only clean up their own alias
    if (external_id !== user.id) {
      return errorResponse('Forbidden: can only clean up your own alias', 403)
    }

    const appId = Deno.env.get('ONESIGNAL_APP_ID')
    const apiKey = Deno.env.get('ONESIGNAL_REST_API_KEY')
    if (!appId || !apiKey) {
      return errorResponse('OneSignal not configured on server', 500)
    }

    // Delete the user record that holds this external_id alias
    const osResponse = await fetch(
      `https://api.onesignal.com/apps/${appId}/users/by/external_id/${encodeURIComponent(external_id)}`,
      {
        method: 'DELETE',
        headers: {
          'Authorization': `Key ${apiKey}`,
          'Content-Type': 'application/json',
        },
      },
    )

    if (osResponse.status === 404) {
      // No stale record — nothing to clean up
      return jsonResponse({ ok: true, cleaned: false, message: 'No stale alias found' })
    }

    if (!osResponse.ok) {
      const errBody = await osResponse.text()
      console.error('OneSignal cleanup error:', osResponse.status, errBody)
      return errorResponse(`OneSignal API error: ${osResponse.status}`, 502)
    }

    console.log(`Cleaned up stale OneSignal alias for external_id=${external_id}`)
    return jsonResponse({ ok: true, cleaned: true })
  } catch (err) {
    console.error('onesignal_cleanup error:', err)
    return errorResponse('Internal server error', 500)
  }
})
