import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2.39.0'

interface BookAmenityRequest {
  amenity_id: string
  target_date: string  // YYYY-MM-DD
  unit_id: string
}

interface BookAmenityResponse {
  ok: boolean
  booking_id?: string
  error?: string
}

serve(async (req) => {
  try {
    if (req.method === 'OPTIONS') {
      return new Response('ok', { headers: corsHeaders })
    }

    const authHeader = req.headers.get('Authorization')
    if (!authHeader) {
      return jsonResponse({ ok: false, error: 'Unauthorized' }, 401)
    }

    const supabase = createClient(
      Deno.env.get('SUPABASE_URL') ?? '',
      Deno.env.get('SUPABASE_ANON_KEY') ?? '',
      { global: { headers: { Authorization: authHeader } } }
    )

    const { data: { user }, error: userError } = await supabase.auth.getUser()
    if (userError || !user) {
      return jsonResponse({ ok: false, error: 'Unauthorized' }, 401)
    }

    const { amenity_id, target_date, unit_id }: BookAmenityRequest = await req.json()

    if (!amenity_id || !target_date || !unit_id) {
      return jsonResponse({ ok: false, error: 'Missing required fields' }, 400)
    }

    const supabaseAdmin = createClient(
      Deno.env.get('SUPABASE_URL') ?? '',
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? ''
    )

    // Fetch amenity and rules
    const { data: amenity, error: amenityError } = await supabaseAdmin
      .from('amenities')
      .select('*')
      .eq('id', amenity_id)
      .single()

    if (amenityError || !amenity) {
      return jsonResponse({ ok: false, error: 'Amenity not found' }, 404)
    }

    const rules = amenity.rules || {}
    const openTime = rules.open || '08:00'
    const closeTime = rules.close || '22:00'
    const allowSameDay = rules.allow_same_day !== false
    const maxDaysAhead = rules.max_days_ahead || 60

    // Validate date
    const bookingDate = new Date(target_date)
    const today = new Date()
    today.setHours(0, 0, 0, 0)
    bookingDate.setHours(0, 0, 0, 0)

    if (bookingDate < today) {
      return jsonResponse({ ok: false, error: 'Cannot book dates in the past' }, 400)
    }

    const daysAhead = Math.floor((bookingDate.getTime() - today.getTime()) / (1000 * 60 * 60 * 24))

    // Minimum 3 days advance booking required
    if (daysAhead < 3) {
      return jsonResponse({ ok: false, error: 'Booking must be made at least 3 days in advance' }, 400)
    }

    if (daysAhead > maxDaysAhead) {
      return jsonResponse({ ok: false, error: `Cannot book more than ${maxDaysAhead} days ahead` }, 400)
    }

    // Check precondition: user must have pool access registration
    const { data: poolAccess } = await supabaseAdmin
      .from('pool_access_registrations')
      .select('id')
      .eq('community_id', amenity.community_id)
      .eq('user_id', user.id)
      .single()

    if (!poolAccess) {
      return jsonResponse({ ok: false, error: 'Pool access registration required before booking' }, 403)
    }

    // Check precondition: user must be in household of selected unit
    const { data: householdMember } = await supabaseAdmin
      .from('household_members')
      .select('id')
      .eq('unit_id', unit_id)
      .eq('user_id', user.id)
      .single()

    if (!householdMember) {
      return jsonResponse({ ok: false, error: 'You must be a member of the selected unit' }, 403)
    }

    // Build time range (full day: 08:00 - 22:00 in target timezone)
    const startTime = `${target_date}T${openTime}:00+08:00`  // Assuming PH timezone UTC+8
    const endTime = `${target_date}T${closeTime}:00+08:00`

    // Insert booking as pending (requires staff approval)
    const { data: booking, error: bookingError } = await supabaseAdmin
      .from('amenity_bookings')
      .insert({
        community_id: amenity.community_id,
        amenity_id,
        user_id: user.id,
        unit_id,
        time_range: `[${startTime},${endTime})`,
        status: 'pending',
        notes: `Booking request for ${target_date}`
      })
      .select()
      .single()

    if (bookingError) {
      // Check for overlap conflict (exclusion constraint violation)
      if (bookingError.code === '23P01') {
        return jsonResponse({ ok: false, error: 'Time slot already booked' }, 409)
      }
      console.error('Booking creation error:', bookingError)
      return jsonResponse({ ok: false, error: 'Failed to create booking' }, 500)
    }

    // Auto-create invoice for amenity booking
    // Due date is 3 days before the booking date
    const price = rules.price || 0
    const currency = rules.currency || 'PHP'
    if (price > 0) {
      const dueDateMs = bookingDate.getTime() - (3 * 24 * 60 * 60 * 1000)
      const dueDate = new Date(dueDateMs)
      const dueDateStr = dueDate.toISOString().split('T')[0]

      await supabaseAdmin
        .from('invoices')
        .insert({
          community_id: amenity.community_id,
          unit_id,
          category: 'amenity',
          amount: price,
          currency,
          due_date: dueDateStr,
          status: 'unpaid',
          source_id: booking.id,
          description: `Amenity Booking: ${amenity.name} on ${target_date}`,
        })
    }

    // Audit log
    await supabaseAdmin
      .from('audit_logs')
      .insert({
        community_id: amenity.community_id,
        actor_user_id: user.id,
        action: 'book_amenity',
        entity: 'amenity_booking',
        entity_id: booking.id,
        meta: { amenity_id, target_date, unit_id }
      })

    return jsonResponse<BookAmenityResponse>({
      ok: true,
      booking_id: booking.id
    })

  } catch (err) {
    console.error('Unexpected error:', err)
    return jsonResponse({ ok: false, error: 'Internal server error' }, 500)
  }
})

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

function jsonResponse<T>(data: T, status = 200) {
  return new Response(JSON.stringify(data), {
    status,
    headers: { ...corsHeaders, 'Content-Type': 'application/json' },
  })
}
