import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2.39.0'

interface CreateCommunityRequest {
  name: string
  slug: string
}

interface CreateCommunityResponse {
  ok: boolean
  community_id?: string
  slug?: string
  portal_url?: string
  error?: string
}

// Define CORS headers at the top
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

serve(async (req) => {
  // Handle CORS
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  console.log('DEBUG: Function started')
  console.log('DEBUG: Method:', req.method)

  try {
    // Get the Authorization header
    const authHeader = req.headers.get('Authorization') || req.headers.get('authorization')
    
    console.log('DEBUG: Auth header:', authHeader ? `present (${authHeader.substring(0, 30)}...)` : 'missing')

    // Log all headers
    const allHeaders: string[] = []
    req.headers.forEach((value, key) => {
      allHeaders.push(`${key}: ${value.substring(0, 30)}${value.length > 30 ? '...' : ''}`)
    })
    console.log('DEBUG: All headers:', allHeaders.join(', '))

    if (!authHeader) {
      console.log('DEBUG: No auth header, returning 401')
      return jsonResponse(
        {
          ok: false,
          error: 'No Authorization header',
        },
        401
      )
    }

    // Extract JWT token
    const jwt = authHeader.replace('Bearer ', '').replace('bearer ', '')
    console.log('DEBUG: JWT length:', jwt.length)

    // Create service role client to verify the JWT
    const supabaseAdmin = createClient(
      Deno.env.get('SUPABASE_URL') ?? '',
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? ''
    )

    // Verify the JWT
    console.log('DEBUG: Verifying JWT with service role...')
    const { data: { user }, error: userError } = await supabaseAdmin.auth.getUser(jwt)
    
    console.log('DEBUG: Verification error:', userError?.message || 'none')
    console.log('DEBUG: User ID:', user?.id || 'none')

    if (userError || !user) {
      console.log('DEBUG: Auth failed, returning 401')
      return jsonResponse(
        {
          ok: false,
          error: 'Authentication failed',
          details: userError?.message,
        },
        401
      )
    }

    console.log('DEBUG: Auth successful, creating community...')
    return await createCommunityWithUser(req, user, supabaseAdmin)
  } catch (error) {
    console.error('Unexpected error:', error)
    return jsonResponse({ ok: false, error: error.message }, 500)
  }
})

async function createCommunityWithUser(req: Request, user: any, supabaseAdmin: any) {
  // Parse request
  const { name, slug }: CreateCommunityRequest = await req.json()

  if (!name || !slug) {
    return jsonResponse({ ok: false, error: 'Missing name or slug' }, 400)
  }

  // Validate slug format (lowercase, alphanumeric + hyphens)
  if (!/^[a-z0-9-]+$/.test(slug)) {
    return jsonResponse({ ok: false, error: 'Invalid slug format' }, 400)
  }

  // Check slug availability
  const { data: existing } = await supabaseAdmin
    .from('communities')
    .select('id')
    .eq('slug', slug)
    .single()

  if (existing) {
    return jsonResponse({ ok: false, error: 'Slug already taken' }, 409)
  }

  // Insert community
  const { data: community, error: communityError } = await supabaseAdmin
    .from('communities')
    .insert({
      name,
      slug,
      settings: {
        brand: {
          primary: '#2E7D32',
          surface: '#ECEFF1'
        }
      }
    })
    .select()
    .single()

  if (communityError) {
    console.error('Community creation error:', communityError)
    return jsonResponse({ ok: false, error: 'Failed to create community' }, 500)
  }

  // Create profile for creator
  const { error: profileError } = await supabaseAdmin
    .from('profiles')
    .insert({
      user_id: user.id,
      community_id: community.id,
      full_name: user.user_metadata?.full_name || user.email?.split('@')[0] || 'User',
      email: user.email
    })

  if (profileError) {
    console.error('Profile creation error:', profileError)
    return jsonResponse({ ok: false, error: 'Failed to create profile' }, 500)
  }

  // Assign community_admin role
  const { error: roleError } = await supabaseAdmin
    .from('user_roles')
    .insert({
      user_id: user.id,
      community_id: community.id,
      role: 'community_admin'
    })

  if (roleError) {
    console.error('Role assignment error:', roleError)
    return jsonResponse({ ok: false, error: 'Failed to assign role' }, 500)
  }

  // Seed default amenity: Pool + Function Room
  const { error: amenityError } = await supabaseAdmin
    .from('amenities')
    .insert({
      community_id: community.id,
      name: 'Pool + Function Room',
      rules: {
        unit: 'day',
        open: '08:00',
        close: '22:00',
        price: 8000,
        currency: 'PHP',
        allow_same_day: false,
        max_days_ahead: 60
      }
    })

  if (amenityError) {
    console.error('Amenity creation error:', amenityError)
    // Non-fatal, continue
  }

  // Audit log
  await supabaseAdmin
    .from('audit_logs')
    .insert({
      community_id: community.id,
      actor_user_id: user.id,
      action: 'create_community',
      entity: 'community',
      entity_id: community.id,
      meta: { name, slug }
    })

  const portalUrl = `${Deno.env.get('WEB_BASE_URL') || 'https://hoapp.net'}/${slug}/login.html`

  return jsonResponse<CreateCommunityResponse>({
    ok: true,
    community_id: community.id,
    slug: community.slug,
    portal_url: portalUrl
  })
}
