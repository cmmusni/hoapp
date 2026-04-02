import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import {
  corsHeaders,
  jsonResponse,
  errorResponse,
  createAdminClient,
} from '../_shared/utils.ts'

/**
 * PayMongo Webhook Handler
 * 
 * Listens for checkout_session.payment.paid events from PayMongo.
 * On successful payment: updates subscription status, upgrades community plan.
 * 
 * Set this URL as your PayMongo webhook endpoint:
 *   https://<project>.supabase.co/functions/v1/paymongo_webhook
 */
serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  // Only accept POST
  if (req.method !== 'POST') {
    return errorResponse('Method not allowed', 405)
  }

  try {
    const payload = await req.json()
    const event = payload?.data?.attributes

    if (!event) {
      console.error('Invalid webhook payload')
      return jsonResponse({ ok: true, message: 'ignored' })
    }

    const eventType = event.type
    console.log('PayMongo webhook event:', eventType)

    // We only care about successful payments
    if (eventType !== 'checkout_session.payment.paid') {
      console.log('Ignoring event type:', eventType)
      return jsonResponse({ ok: true, message: 'event ignored' })
    }

    const checkoutData = event.data
    const metadata = checkoutData?.attributes?.metadata
    const checkoutId = checkoutData?.id
    const referenceNumber = checkoutData?.attributes?.reference_number

    // Extract payment intent ID from the payments array
    const payments = checkoutData?.attributes?.payments ?? []
    const paymentId = payments[0]?.id ?? null

    // Try to find subscription by checkout ID or reference number
    const admin = createAdminClient()
    
    let subscriptionId = metadata?.subscription_id ?? referenceNumber

    if (!subscriptionId && checkoutId) {
      // Fallback: find by checkout ID
      const { data: sub } = await admin
        .from('plan_subscriptions')
        .select('id')
        .eq('paymongo_checkout_id', checkoutId)
        .single()
      subscriptionId = sub?.id
    }

    if (!subscriptionId) {
      console.error('Could not find subscription for webhook event')
      return jsonResponse({ ok: true, message: 'subscription not found' })
    }

    // Get subscription details
    const { data: subscription, error: subErr } = await admin
      .from('plan_subscriptions')
      .select('*')
      .eq('id', subscriptionId)
      .single()

    if (subErr || !subscription) {
      console.error('Subscription not found:', subscriptionId, subErr)
      return jsonResponse({ ok: true, message: 'subscription not found' })
    }

    // Skip if already processed
    if (subscription.status === 'paid') {
      console.log('Subscription already paid, skipping:', subscriptionId)
      return jsonResponse({ ok: true, message: 'already processed' })
    }

    // Update subscription to paid with expiry (30 days from now)
    const expiresAt = new Date()
    expiresAt.setDate(expiresAt.getDate() + 30)
    const graceEndsAt = new Date(expiresAt)
    graceEndsAt.setDate(graceEndsAt.getDate() + 7)

    const { error: updateErr } = await admin
      .from('plan_subscriptions')
      .update({
        status: 'paid',
        paymongo_payment_id: paymentId,
        paid_at: new Date().toISOString(),
        expires_at: expiresAt.toISOString(),
        grace_ends_at: graceEndsAt.toISOString(),
      })
      .eq('id', subscriptionId)

    if (updateErr) {
      console.error('Failed to update subscription:', updateErr)
      return errorResponse('Failed to update subscription', 500)
    }

    // Upgrade community plan and set expiry
    const { error: planErr } = await admin
      .from('communities')
      .update({
        plan: subscription.plan,
        plan_expires_at: expiresAt.toISOString(),
      })
      .eq('id', subscription.community_id)

    if (planErr) {
      console.error('Failed to upgrade community plan:', planErr)
      return errorResponse('Failed to upgrade plan', 500)
    }

    console.log(
      `Community ${subscription.community_id} upgraded to ${subscription.plan} via payment ${paymentId}`
    )

    return jsonResponse({
      ok: true,
      message: 'plan upgraded',
      community_id: subscription.community_id,
      plan: subscription.plan,
    })
  } catch (err) {
    console.error('Webhook error:', err)
    // Always return 200 to PayMongo so it doesn't retry forever
    return jsonResponse({ ok: true, message: 'error handled' })
  }
})
