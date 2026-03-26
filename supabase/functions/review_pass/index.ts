import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { encode as base64url } from "https://deno.land/std@0.168.0/encoding/base64url.ts"
import {
  corsHeaders,
  jsonResponse,
  errorResponse,
  withErrorHandling,
  validateAuth,
  createAdminClient,
  validateRequired,
  createAuditLog,
} from "../_shared/utils.ts"

interface ReviewRequest {
  pass_id: string
  action: 'approve' | 'reject'
  rejection_reason?: string
}

serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  return withErrorHandling(async () => {
    const body: ReviewRequest = await req.json()

    // Validate auth
    const authResult = await validateAuth(req, body)
    if (authResult instanceof Response) return authResult
    const { user } = authResult

    // Validate required fields
    const missingFields = validateRequired(body, ['pass_id', 'action'])
    if (missingFields.length > 0) {
      return errorResponse(`Missing required fields: ${missingFields.join(', ')}`, 400, 'MISSING_FIELDS')
    }

    if (!['approve', 'reject'].includes(body.action)) {
      return errorResponse('action must be approve or reject', 400)
    }

    const admin = createAdminClient()

    // Fetch the pass
    const { data: pass, error: fetchError } = await admin
      .from('security_passes')
      .select('*, pass_types(*)')
      .eq('id', body.pass_id)
      .single()

    if (fetchError || !pass) {
      return errorResponse('Pass not found', 404)
    }

    // Check caller is staff in this community
    const { data: callerRoles } = await admin
      .from('user_roles')
      .select('role')
      .eq('user_id', user.id)
      .eq('community_id', pass.community_id)

    const isStaff = callerRoles?.some(
      (r: any) => r.role === 'community_admin' || r.role === 'hoa_officer'
    )
    if (!isStaff) {
      return errorResponse('Only admins and HOA officers can review passes', 403)
    }

    // Validate pass is in reviewable state
    if (!['submitted', 'pending_review'].includes(pass.status)) {
      return errorResponse(`Cannot ${body.action} a pass with status: ${pass.status}`, 400)
    }

    if (body.action === 'approve') {
      // Generate cryptographic QR token
      const randomBytes = new Uint8Array(32)
      crypto.getRandomValues(randomBytes)
      const qrToken = base64url(randomBytes)

      const now = new Date().toISOString()

      // Determine if pass should be immediately active
      const validFrom = new Date(pass.valid_from)
      const isNowValid = validFrom <= new Date()
      const newStatus = isNowValid ? 'active' : 'approved'

      const { error: updateError } = await admin
        .from('security_passes')
        .update({
          status: newStatus,
          qr_token: qrToken,
          qr_generated_at: now,
          reviewed_by: user.id,
          reviewed_at: now,
          updated_at: now,
        })
        .eq('id', body.pass_id)

      if (updateError) {
        console.error('Update error:', updateError)
        return errorResponse('Failed to approve pass', 500)
      }

      await createAuditLog(admin, {
        communityId: pass.community_id,
        actorUserId: user.id,
        action: 'approve_pass',
        entity: 'security_pass',
        entityId: body.pass_id,
        meta: { pass_type: pass.pass_types?.slug, visitor: pass.visitor_name },
      })

      return jsonResponse({
        ok: true,
        status: newStatus,
        qr_token: qrToken,
      })
    } else {
      // Reject
      if (!body.rejection_reason) {
        return errorResponse('rejection_reason is required when rejecting', 400)
      }

      const now = new Date().toISOString()

      const { error: updateError } = await admin
        .from('security_passes')
        .update({
          status: 'rejected',
          reviewed_by: user.id,
          reviewed_at: now,
          rejection_reason: body.rejection_reason,
          updated_at: now,
        })
        .eq('id', body.pass_id)

      if (updateError) {
        console.error('Update error:', updateError)
        return errorResponse('Failed to reject pass', 500)
      }

      await createAuditLog(admin, {
        communityId: pass.community_id,
        actorUserId: user.id,
        action: 'reject_pass',
        entity: 'security_pass',
        entityId: body.pass_id,
        meta: { reason: body.rejection_reason },
      })

      return jsonResponse({ ok: true, status: 'rejected' })
    }
  }, 'review_pass')
})
