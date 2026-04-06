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

    // Send email notification (non-blocking)
    // For rejected payments: notify the first primary household member of the unit
    // For verified payments: notify only the payment submitter
    if (payment.user_id && payment.invoices) {
      const { data: community } = await supabaseAdmin
        .from('communities')
        .select('name, slug')
        .eq('id', payment.community_id)
        .maybeSingle()

      if (community) {
        const baseUrl = Deno.env.get('WEB_BASE_URL') || 'https://hoapp.net'
        const portalLink = `${baseUrl}/${community.slug}/billing`
        const emailSubject = `Payment ${verified ? 'Verified' : 'Rejected'} - ${community.name}`

        // Collect recipients
        const recipients: { email: string; name: string }[] = []

        if (!verified && payment.invoices?.unit_id) {
          // Rejected: notify only the first primary household member (by created_at)
          const { data: primaryMember } = await supabaseAdmin
            .from('household_members')
            .select('user_id')
            .eq('unit_id', payment.invoices.unit_id)
            .eq('member_role', 'primary')
            .order('created_at', { ascending: true })
            .limit(1)
            .maybeSingle()

          if (primaryMember) {
            const { data: { user: memberUser } } = await supabaseAdmin.auth.admin.getUserById(primaryMember.user_id)
            if (memberUser?.email) {
              const { data: profile } = await supabaseAdmin
                .from('profiles')
                .select('full_name')
                .eq('user_id', primaryMember.user_id)
                .eq('community_id', payment.community_id)
                .maybeSingle()
              recipients.push({
                email: memberUser.email,
                name: profile?.full_name || memberUser.user_metadata?.full_name || memberUser.email.split('@')[0],
              })
            }
          }
        } else {
          // Verified: notify only the submitter
          const { data: { user: payerUser } } = await supabaseAdmin.auth.admin.getUserById(payment.user_id)
          if (payerUser?.email) {
            const { data: profile } = await supabaseAdmin
              .from('profiles')
              .select('full_name')
              .eq('user_id', payment.user_id)
              .eq('community_id', payment.community_id)
              .maybeSingle()
            recipients.push({
              email: payerUser.email,
              name: profile?.full_name || payerUser.user_metadata?.full_name || payerUser.email.split('@')[0],
            })
          }
        }

        // Send to all recipients
        for (const recipient of recipients) {
          sendEmail({
            to: recipient.email,
            subject: emailSubject,
            html: generatePaymentNotificationHTML({
              recipientName: recipient.name,
              communityName: community.name,
              invoiceNumber: payment.invoices.id,
              amount: amount || payment.amount,
              status: verified ? 'verified' : 'rejected',
              rejectionReason: rejection_reason,
              portalLink,
            }),
          }).catch(err => console.error('Email send failed for', recipient.email, err))
        }
      }
    }

    return jsonResponse({ ok: true })
  }, 'verify_payment')
})
