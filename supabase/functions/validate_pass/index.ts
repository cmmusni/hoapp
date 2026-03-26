import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import {
  corsHeaders,
  jsonResponse,
  errorResponse,
  withErrorHandling,
  validateAuth,
  createAdminClient,
  validateRequired,
} from "../_shared/utils.ts"

interface ValidateRequest {
  qr_token: string
  community_id: string
  scan_type: 'entry' | 'exit'
}

serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  return withErrorHandling(async () => {
    const body: ValidateRequest = await req.json()

    // Validate auth
    const authResult = await validateAuth(req, body)
    if (authResult instanceof Response) return authResult
    const { user } = authResult

    // Validate required fields
    const missingFields = validateRequired(body, ['qr_token', 'community_id', 'scan_type'])
    if (missingFields.length > 0) {
      return errorResponse(`Missing required fields: ${missingFields.join(', ')}`, 400, 'MISSING_FIELDS')
    }

    const admin = createAdminClient()

    // Check caller is guard or staff in this community
    const { data: callerRoles } = await admin
      .from('user_roles')
      .select('role')
      .eq('user_id', user.id)
      .eq('community_id', body.community_id)

    const isAuthorized = callerRoles?.some(
      (r: any) => ['community_admin', 'hoa_officer', 'guard'].includes(r.role)
    )
    if (!isAuthorized) {
      return errorResponse('Only guards and staff can scan passes', 403)
    }

    // Look up the pass by QR token
    const { data: pass, error: fetchError } = await admin
      .from('security_passes')
      .select('*, pass_types(*)')
      .eq('qr_token', body.qr_token)
      .single()

    if (fetchError || !pass) {
      // Log invalid scan
      await admin.from('pass_scan_logs').insert({
        pass_id: null, // unknown
        community_id: body.community_id,
        scanned_by: user.id,
        scan_type: body.scan_type,
        scan_result: 'invalid',
        notes: 'QR token not found',
      }).then(() => {}).catch(() => {})

      return jsonResponse({
        ok: false,
        scan_result: 'invalid',
        message: 'Invalid QR code — pass not found',
      })
    }

    // Verify pass belongs to this community
    if (pass.community_id !== body.community_id) {
      return jsonResponse({
        ok: false,
        scan_result: 'invalid',
        message: 'This pass does not belong to this community',
      })
    }

    const now = new Date()
    const validFrom = new Date(pass.valid_from)
    const validUntil = new Date(pass.valid_until)
    const gracePeriodMs = (pass.pass_types?.grace_period_hours ?? 2) * 60 * 60 * 1000
    const expiryWithGrace = new Date(validUntil.getTime() + gracePeriodMs)

    // Determine scan result
    let scanResult: string
    let message: string
    let shouldAllowEntry = false

    if (pass.status === 'revoked') {
      scanResult = 'revoked'
      message = 'This pass has been revoked'
    } else if (pass.status === 'rejected') {
      scanResult = 'invalid'
      message = 'This pass was rejected'
    } else if (pass.status === 'expired' || now > expiryWithGrace) {
      scanResult = 'expired'
      message = 'This pass has expired'
    } else if (pass.status === 'used' || (pass.max_uses > 0 && pass.use_count >= pass.max_uses)) {
      scanResult = 'used_up'
      message = 'This pass has been fully used'
    } else if (now < validFrom) {
      scanResult = 'invalid'
      message = `This pass is not yet valid. Valid from: ${validFrom.toLocaleString()}`
    } else if (['approved', 'active'].includes(pass.status)) {
      scanResult = 'valid'
      shouldAllowEntry = true
      message = 'Pass is valid — entry/exit allowed'
    } else {
      scanResult = 'invalid'
      message = `Pass status "${pass.status}" is not scannable`
    }

    // Log the scan
    await admin.from('pass_scan_logs').insert({
      pass_id: pass.id,
      community_id: body.community_id,
      scanned_by: user.id,
      scan_type: body.scan_type,
      scan_result: scanResult,
    })

    // If valid, update usage count and status
    if (shouldAllowEntry) {
      const newUseCount = (pass.use_count || 0) + 1
      const isNowUsedUp = pass.max_uses > 0 && newUseCount >= pass.max_uses

      await admin
        .from('security_passes')
        .update({
          use_count: newUseCount,
          status: isNowUsedUp ? 'used' : 'active',
          updated_at: now.toISOString(),
        })
        .eq('id', pass.id)
    }

    return jsonResponse({
      ok: shouldAllowEntry,
      scan_result: scanResult,
      message,
      pass: shouldAllowEntry ? {
        id: pass.id,
        pass_type: pass.pass_types?.name ?? 'Unknown',
        visitor_name: pass.visitor_name,
        purpose: pass.purpose,
        plate_number: pass.plate_number,
        valid_from: pass.valid_from,
        valid_until: pass.valid_until,
        use_count: (pass.use_count || 0) + (shouldAllowEntry ? 1 : 0),
        max_uses: pass.max_uses,
      } : null,
    })
  }, 'validate_pass')
})
