import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import {
  corsHeaders,
  jsonResponse,
  errorResponse,
  withErrorHandling,
  validateAuth,
  createAdminClient,
  validateRequired,
  createAuditLog,
} from '../_shared/utils.ts'
import { sendEmail, generatePaymentNotificationHTML } from '../_shared/email.ts'

interface VerifyPaymentRequest {
  payment_id: string
  verified: boolean
  receipt_url?: string
  rejection_reason?: string
  amount?: number
}

serve(async (req) => {
  // Handle CORS preflight
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  return withErrorHandling(async () => {
    // Parse body first so _jwt fallback works in validateAuth
    const body: VerifyPaymentRequest = await req.json()

    // Validate authentication
    const authResult = await validateAuth(req, body)
    if (authResult instanceof Response) return authResult
    const { user } = authResult

    // Validate required fields
    const missing = validateRequired(body, ['payment_id', 'verified'])
    if (missing.length > 0) {
      return errorResponse(
        `Missing required fields: ${missing.join(', ')}`,
        400,
        'MISSING_FIELDS'
      )
    }

    const { payment_id, verified, receipt_url, rejection_reason, amount } = body

    const supabaseAdmin = createAdminClient()

    // Fetch payment with related data
    const { data: payment, error: paymentError } = await supabaseAdmin
      .from('payments')
      .select(`
        *,
        invoices (
          id,
          amount,
          unit_id
        )
      `)
      .eq('id', payment_id)
      .maybeSingle()

    if (paymentError || !payment) {
      return errorResponse('Payment not found', 404, 'NOT_FOUND')
    }

    // Check if user is staff in the community
    const { data: userRoles } = await supabaseAdmin
      .from('user_roles')
      .select('role')
      .eq('user_id', user.id)
      .eq('community_id', payment.community_id)

    const isStaff = userRoles?.some(r =>
      ['community_admin', 'hoa_officer'].includes(r.role)
    )

    if (!isStaff) {
      return errorResponse(
        'Only staff can verify payments',
        403,
        'INSUFFICIENT_PERMISSIONS'
      )
    }

    // Update payment status
    const updateData: any = {
      status: verified ? 'verified' : 'rejected',
      verified_by: user.id,
      verified_at: new Date().toISOString(),
    }

    if (verified) {
      if (receipt_url) updateData.receipt_url = receipt_url
      if (amount !== undefined) updateData.amount = amount
    } else {
      updateData.rejection_reason = rejection_reason || 'No reason provided'
    }

    const { error: updateError } = await supabaseAdmin
      .from('payments')
      .update(updateData)
      .eq('id', payment_id)

    if (updateError) {
      console.error('Payment update error:', updateError)
      return errorResponse('Failed to update payment', 500, 'UPDATE_FAILED')
    }

    // Update invoice status if verified
    if (verified && payment.invoices) {
      await supabaseAdmin
        .from('invoices')
        .update({ status: 'paid' })
        .eq('id', payment.invoice_id)
    }

    // Audit log
    await createAuditLog(supabaseAdmin, {
      communityId: payment.community_id,
      actorUserId: user.id,
      action: verified ? 'verify_payment' : 'reject_payment',
      entity: 'payment',
      entityId: payment_id,
      meta: {
        invoice_id: payment.invoice_id,
        amount: amount || payment.amount,
        ...(rejection_reason && { reason: rejection_reason }),
      },
    })

    // Send email notification to user (non-blocking)
    if (payment.user_id) {
      const { data: payerProfile } = await supabaseAdmin
        .from('profiles')
        .select('full_name, email')
        .eq('user_id', payment.user_id)
        .eq('community_id', payment.community_id)
        .maybeSingle()

      const { data: community } = await supabaseAdmin
        .from('communities')
        .select('name, slug')
        .eq('id', payment.community_id)
        .maybeSingle()

      if (payerProfile?.email && community && payment.invoices) {
        const baseUrl = Deno.env.get('WEB_BASE_URL') || 'https://hoapp.net'
        const portalLink = `${baseUrl}/${community.slug}/billing`

        sendEmail({
          to: payerProfile.email,
          subject: `Payment ${verified ? 'Verified' : 'Rejected'} - ${community.name}`,
          html: generatePaymentNotificationHTML({
            recipientName: payerProfile.full_name || payerProfile.email.split('@')[0],
            communityName: community.name,
            invoiceNumber: payment.invoices.invoice_number,
            amount: amount || payment.amount,
            status: verified ? 'verified' : 'rejected',
            rejectionReason: rejection_reason,
            portalLink,
          }),
        }).catch(err => console.error('Email send failed:', err))
      }
    }

    return jsonResponse({ ok: true })
  }, 'verify_payment')
})
