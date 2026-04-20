import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import {
  corsHeaders,
  jsonResponse,
  errorResponse,
  createAdminClient,
  validateAuth,
  withErrorHandling,
} from '../_shared/utils.ts'

/**
 * send_notification — Send push notifications via Firebase Cloud Messaging (FCM HTTP v1 API).
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
 * Requires FIREBASE_SERVICE_ACCOUNT_KEY (JSON string) and FIREBASE_PROJECT_ID env vars.
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

    // Authenticate the caller
    const authResult = await validateAuth(req, body)
    if (authResult instanceof Response) return authResult
    const { user } = authResult

    const { community_id, heading, content, url, target_user_ids, target_roles, data } = body

    if (!community_id) return errorResponse('community_id is required', 400)
    if (!heading?.trim()) return errorResponse('heading is required', 400)
    if (!content?.trim()) return errorResponse('content is required', 400)

    const supabase = createAdminClient()

    // Verify the caller belongs to this community
    const { data: roleRow } = await supabase
      .from('user_roles')
      .select('role')
      .eq('user_id', user.id)
      .eq('community_id', community_id)
      .maybeSingle()

    if (!roleRow) {
      return errorResponse('User does not belong to this community', 403)
    }

    // Get FCM tokens for target users
    let tokens: string[] = []

    if (target_user_ids && Array.isArray(target_user_ids) && target_user_ids.length > 0) {
      // Send to specific users
      const { data: tokenRows } = await supabase
        .from('notification_tokens')
        .select('token')
        .in('user_id', target_user_ids)

      tokens = (tokenRows || []).map((r: { token: string }) => r.token)
    } else {
      // Send to all community members, optionally filtered by role
      let memberQuery = supabase
        .from('user_roles')
        .select('user_id')
        .eq('community_id', community_id)

      if (target_roles && Array.isArray(target_roles) && target_roles.length > 0) {
        memberQuery = memberQuery.in('role', target_roles)
      }

      const { data: memberRows } = await memberQuery

      // Exclude the caller from broadcast notifications so they don't get
      // notified about their own action.
      const memberIds = (memberRows || [])
        .map((r: { user_id: string }) => r.user_id)
        .filter((id: string) => id !== user.id)

      if (memberIds.length > 0) {
        const { data: tokenRows } = await supabase
          .from('notification_tokens')
          .select('token')
          .in('user_id', memberIds)

        tokens = (tokenRows || []).map((r: { token: string }) => r.token)
      }
    }

    if (tokens.length === 0) {
      return jsonResponse({ ok: true, sent: 0, message: 'No registered tokens found' })
    }

    // Get Firebase access token
    const accessToken = await getFirebaseAccessToken()
    if (!accessToken) {
      return errorResponse('Firebase not configured on server', 500)
    }

    const projectId = Deno.env.get('FIREBASE_PROJECT_ID')
    if (!projectId) {
      return errorResponse('FIREBASE_PROJECT_ID not configured', 500)
    }

    // Build notification payload
    const notificationData: Record<string, string> = {
      community_id,
      click_action: 'FLUTTER_NOTIFICATION_CLICK',
    }
    if (url) notificationData.url = url
    if (data && typeof data === 'object') {
      Object.entries(data).forEach(([k, v]) => {
        notificationData[k] = String(v)
      })
    }

    // Send to each token (FCM v1 API sends one message at a time)
    // Batch in parallel with a concurrency limit
    const BATCH_SIZE = 500
    let successCount = 0
    let failureCount = 0
    const invalidTokens: string[] = []

    for (let i = 0; i < tokens.length; i += BATCH_SIZE) {
      const batch = tokens.slice(i, i + BATCH_SIZE)
      const results = await Promise.allSettled(
        batch.map(async (token) => {
          const response = await fetch(
            `https://fcm.googleapis.com/v1/projects/${projectId}/messages:send`,
            {
              method: 'POST',
              headers: {
                'Content-Type': 'application/json',
                'Authorization': `Bearer ${accessToken}`,
              },
              body: JSON.stringify({
                message: {
                  token,
                  notification: {
                    title: heading.trim(),
                    body: content.trim(),
                  },
                  data: notificationData,
                  android: {
                    priority: 'high',
                    notification: {
                      channel_id: 'hoapp_notifications',
                      default_sound: true,
                    },
                  },
                  apns: {
                    payload: {
                      aps: {
                        sound: 'default',
                        badge: 1,
                      },
                    },
                  },
                  webpush: {
                    notification: {
                      icon: '/icons/Icon-192.png',
                    },
                    fcm_options: {
                      link: url || '/',
                    },
                  },
                },
              }),
            }
          )

          if (!response.ok) {
            const err = await response.json()
            // Token is invalid/expired — mark for cleanup
            if (
              err?.error?.details?.some(
                (d: any) => d.errorCode === 'UNREGISTERED' || d.errorCode === 'INVALID_ARGUMENT'
              ) ||
              err?.error?.status === 'NOT_FOUND'
            ) {
              invalidTokens.push(token)
            }
            throw new Error(err?.error?.message || 'FCM send failed')
          }

          return response.json()
        })
      )

      results.forEach((r) => {
        if (r.status === 'fulfilled') successCount++
        else failureCount++
      })
    }

    // Clean up invalid tokens
    if (invalidTokens.length > 0) {
      await supabase
        .from('notification_tokens')
        .delete()
        .in('token', invalidTokens)
      console.log(`Cleaned up ${invalidTokens.length} invalid FCM tokens`)
    }

    return jsonResponse({
      ok: true,
      sent: successCount,
      failed: failureCount,
      cleaned: invalidTokens.length,
    })
  }, 'send_notification')
})

/**
 * Get a short-lived OAuth2 access token for Firebase using a service account key.
 */
async function getFirebaseAccessToken(): Promise<string | null> {
  const serviceAccountKeyJson = Deno.env.get('FIREBASE_SERVICE_ACCOUNT_KEY')
  if (!serviceAccountKeyJson) return null

  try {
    const sa = JSON.parse(serviceAccountKeyJson)

    // Create JWT for token exchange
    const now = Math.floor(Date.now() / 1000)
    const header = { alg: 'RS256', typ: 'JWT' }
    const payload = {
      iss: sa.client_email,
      scope: 'https://www.googleapis.com/auth/firebase.messaging',
      aud: 'https://oauth2.googleapis.com/token',
      iat: now,
      exp: now + 3600,
    }

    const encodedHeader = base64url(JSON.stringify(header))
    const encodedPayload = base64url(JSON.stringify(payload))
    const signingInput = `${encodedHeader}.${encodedPayload}`

    // Sign the JWT with the service account private key
    const privateKey = await importPrivateKey(sa.private_key)
    const signature = await sign(signingInput, privateKey)

    const jwt = `${signingInput}.${signature}`

    // Exchange JWT for access token
    const tokenResponse = await fetch('https://oauth2.googleapis.com/token', {
      method: 'POST',
      headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
      body: new URLSearchParams({
        grant_type: 'urn:ietf:params:oauth:grant-type:jwt-bearer',
        assertion: jwt,
      }),
    })

    const tokenData = await tokenResponse.json()
    return tokenData.access_token || null
  } catch (e) {
    console.error('getFirebaseAccessToken error:', e)
    return null
  }
}

function base64url(str: string): string {
  const encoded = btoa(str)
  return encoded.replace(/\+/g, '-').replace(/\//g, '_').replace(/=+$/, '')
}

async function importPrivateKey(pem: string): Promise<CryptoKey> {
  const pemContents = pem
    .replace(/-----BEGIN PRIVATE KEY-----/, '')
    .replace(/-----END PRIVATE KEY-----/, '')
    .replace(/\n/g, '')

  const binaryDer = Uint8Array.from(atob(pemContents), (c) => c.charCodeAt(0))

  return await crypto.subtle.importKey(
    'pkcs8',
    binaryDer,
    { name: 'RSASSA-PKCS1-v1_5', hash: 'SHA-256' },
    false,
    ['sign']
  )
}

async function sign(input: string, key: CryptoKey): Promise<string> {
  const encoded = new TextEncoder().encode(input)
  const signature = await crypto.subtle.sign('RSASSA-PKCS1-v1_5', key, encoded)
  const base64 = btoa(String.fromCharCode(...new Uint8Array(signature)))
  return base64.replace(/\+/g, '-').replace(/\//g, '_').replace(/=+$/, '')
}
