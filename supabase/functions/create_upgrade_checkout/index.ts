import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import {
  corsHeaders,
  jsonResponse,
  errorResponse,
  withErrorHandling,
  validateAuth,
  createAdminClient,
} from '../_shared/utils.ts'

const PAYMONGO_SECRET = Deno.env.get('PAYMONGO_SECRET_KEY') ?? ''
const WEB_BASE_URL = Deno.env.get('WEB_BASE_URL') ?? 'https://hoapp.net'

serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  return withErrorHandling(async () => {
    const body = await req.json()
    const authResult = await validateAuth(req, body)
    if (authResult instanceof Response) return authResult
    const { user } = authResult

    const { community_id } = body
    if (!community_id) {
      return errorResponse('community_id is required', 400)
    }

    // Verify user is community admin
    const admin = createAdminClient()
    const { data: role } = await admin
      .from('user_roles')
      .select('role')
      .eq('user_id', user.id)
      .eq('community_id', community_id)
      .eq('role', 'community_admin')
      .single()

    if (!role) {
      return errorResponse('Only community admins can upgrade plans', 403)
    }

    // Check community isn't already professional
    const { data: community } = await admin
      .from('communities')
      .select('plan, name')
      .eq('id', community_id)
      .single()

    if (!community) {
      return errorResponse('Community not found', 404)
    }

    if (community.plan === 'enterprise') {
      return errorResponse('Enterprise plans are managed separately. Contact support.', 400)
    }

    const isRenewal = community.plan === 'professional'

    // Fetch dynamic pricing from plan_pricing table
    const { data: pricing } = await admin
      .from('plan_pricing')
      .select('price_centavos, label')
      .eq('plan', 'professional')
      .single()

    const amount = pricing?.price_centavos ?? 299900
    const priceLabel = pricing?.label ?? '₱2,999'

    // Create plan_subscriptions record
    const { data: subscription, error: subError } = await admin
      .from('plan_subscriptions')
      .insert({
        community_id,
        user_id: user.id,
        plan: 'professional',
        amount,
        currency: 'PHP',
        status: 'pending',
      })
      .select()
      .single()

    if (subError || !subscription) {
      console.error('Failed to create subscription record:', subError)
      return errorResponse(`Failed to create subscription: ${subError?.message ?? 'unknown error'}`, 500)
    }

    // Create PayMongo checkout session with QR PH
    const paymongoAuth = btoa(`${PAYMONGO_SECRET}:`)
    const checkoutRes = await fetch('https://api.paymongo.com/v1/checkout_sessions', {
      method: 'POST',
      headers: {
        'Authorization': `Basic ${paymongoAuth}`,
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      },
      body: JSON.stringify({
        data: {
          attributes: {
            line_items: [
              {
                name: isRenewal ? 'HOApp Professional Plan Renewal' : 'HOApp Professional Plan',
                description: `Professional plan ${isRenewal ? 'renewal' : 'upgrade'} for ${community.name}`,
                amount,
                currency: 'PHP',
                quantity: 1,
              },
            ],
            payment_method_types: ['qrph', 'gcash', 'grab_pay', 'paymaya'],
            description: `HOApp Professional Plan ${isRenewal ? 'Renewal' : 'Upgrade'} - ${community.name}`,
            send_email_receipt: true,
            show_description: true,
            show_line_items: true,
            reference_number: subscription.id,
            success_url: `${WEB_BASE_URL}/upgrade-success?subscription_id=${subscription.id}`,
            cancel_url: `${WEB_BASE_URL}/upgrade-cancelled`,
            metadata: {
              community_id,
              subscription_id: subscription.id,
              user_id: user.id,
            },
          },
        },
      }),
    })

    if (!checkoutRes.ok) {
      const errBody = await checkoutRes.text()
      console.error('PayMongo error:', checkoutRes.status, errBody)
      // Clean up subscription record
      await admin.from('plan_subscriptions').delete().eq('id', subscription.id)
      return errorResponse(`Failed to create payment session: ${errBody}`, 500)
    }

    const checkoutData = await checkoutRes.json()
    const checkoutSession = checkoutData.data
    const checkoutUrl = checkoutSession.attributes.checkout_url
    const checkoutId = checkoutSession.id

    // Update subscription with checkout ID
    await admin
      .from('plan_subscriptions')
      .update({ paymongo_checkout_id: checkoutId })
      .eq('id', subscription.id)

    return jsonResponse({
      ok: true,
      checkout_url: checkoutUrl,
      subscription_id: subscription.id,
    })
  }, 'create_upgrade_checkout')
})
