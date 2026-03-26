import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2.39.0'
import {
  corsHeaders,
  jsonResponse,
  errorResponse,
} from '../_shared/utils.ts'

interface ProvisionRequest {
  request_id: string
  community_name: string
  community_slug: string
  password: string
}

serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  try {
    if (req.method !== 'POST') {
      return errorResponse('Method not allowed', 405)
    }

    // Verify caller is a community_admin
    const authHeader = req.headers.get('Authorization')
    if (!authHeader) {
      return errorResponse('No Authorization header', 401)
    }

    const jwt = authHeader.replace('Bearer ', '').replace('bearer ', '')

    const supabaseAdmin = createClient(
      Deno.env.get('SUPABASE_URL') ?? '',
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? ''
    )

    const { data: { user: caller }, error: authError } = await supabaseAdmin.auth.getUser(jwt)
    if (authError || !caller) {
      return errorResponse('Authentication failed', 401)
    }

    // Verify caller is a platform admin (app_admin)
    const { data: platformRole } = await supabaseAdmin
      .from('platform_roles')
      .select('role')
      .eq('user_id', caller.id)
      .eq('role', 'app_admin')
      .maybeSingle()

    if (!platformRole) {
      return errorResponse('Only platform admins can provision communities', 403)
    }

    const body: ProvisionRequest = await req.json()
    const { request_id, community_name, community_slug, password } = body

    if (!request_id) return errorResponse('request_id is required', 400)
    if (!community_name?.trim()) return errorResponse('community_name is required', 400)
    if (!community_slug?.trim()) return errorResponse('community_slug is required', 400)
    if (!password || password.length < 6) return errorResponse('Password must be at least 6 characters', 400)

    // Validate slug format
    if (!/^[a-z0-9-]+$/.test(community_slug)) {
      return errorResponse('Invalid slug format. Use lowercase letters, numbers, and hyphens only.', 400)
    }

    // Fetch the beta request
    const { data: betaRequest, error: fetchError } = await supabaseAdmin
      .from('beta_access_requests')
      .select('*')
      .eq('id', request_id)
      .single()

    if (fetchError || !betaRequest) {
      return errorResponse('Beta request not found', 404)
    }

    if (betaRequest.status !== 'pending') {
      return errorResponse(`Request already ${betaRequest.status}`, 400)
    }

    // Check slug availability
    const { data: existingCommunity } = await supabaseAdmin
      .from('communities')
      .select('id')
      .eq('slug', community_slug)
      .single()

    if (existingCommunity) {
      return errorResponse('Community slug already taken', 409)
    }

    // 1. Create the auth user
    const { data: newUser, error: createUserError } = await supabaseAdmin.auth.admin.createUser({
      email: betaRequest.email,
      password: password,
      email_confirm: true,
      user_metadata: {
        full_name: betaRequest.name,
      },
    })

    if (createUserError) {
      // If user already exists, try to find them
      if (createUserError.message?.includes('already been registered')) {
        const { data: { users }, error: listError } = await supabaseAdmin.auth.admin.listUsers()
        const existingUser = users?.find((u: any) => u.email === betaRequest.email)
        if (!existingUser) {
          return errorResponse('User with this email exists but could not be found', 500)
        }
        // Use the existing user
        console.log('User already exists, using existing:', existingUser.id)
        return await provisionCommunity(
          supabaseAdmin, existingUser, betaRequest, community_name, community_slug, caller.id, request_id
        )
      }
      console.error('Create user error:', createUserError)
      return errorResponse(`Failed to create user: ${createUserError.message}`, 500)
    }

    return await provisionCommunity(
      supabaseAdmin, newUser.user, betaRequest, community_name, community_slug, caller.id, request_id
    )
  } catch (err) {
    console.error('provision_community error:', err)
    return errorResponse('Internal server error', 500)
  }
})

async function provisionCommunity(
  supabaseAdmin: any,
  user: any,
  betaRequest: any,
  communityName: string,
  communitySlug: string,
  processedBy: string,
  requestId: string,
) {
  // 2. Create community
  const { data: community, error: communityError } = await supabaseAdmin
    .from('communities')
    .insert({
      name: communityName,
      slug: communitySlug,
      settings: {
        brand: { primary: '#215E3F', surface: '#ECEFF1' },
      },
    })
    .select()
    .single()

  if (communityError) {
    console.error('Community creation error:', communityError)
    return errorResponse('Failed to create community', 500)
  }

  // 3. Create profile for the new user
  const { error: profileError } = await supabaseAdmin
    .from('profiles')
    .insert({
      user_id: user.id,
      community_id: community.id,
      full_name: betaRequest.name,
      email: betaRequest.email,
    })

  if (profileError) {
    console.error('Profile creation error:', profileError)
  }

  // 4. Assign community_admin role
  const { error: roleError } = await supabaseAdmin
    .from('user_roles')
    .insert({
      user_id: user.id,
      community_id: community.id,
      role: 'community_admin',
    })

  if (roleError) {
    console.error('Role assignment error:', roleError)
  }

  // 5. Update beta request status
  const { error: updateError } = await supabaseAdmin
    .from('beta_access_requests')
    .update({
      status: 'approved',
      provisioned_community_id: community.id,
      provisioned_user_id: user.id,
      processed_by: processedBy,
      processed_at: new Date().toISOString(),
    })
    .eq('id', requestId)

  if (updateError) {
    console.error('Beta request update error:', updateError)
  }

  // 6. Write audit log
  await supabaseAdmin
    .from('audit_logs')
    .insert({
      community_id: community.id,
      actor_id: processedBy,
      action: 'provision_community',
      details: {
        beta_request_id: requestId,
        user_email: betaRequest.email,
        community_name: communityName,
        community_slug: communitySlug,
      },
    })
    .then(({ error }: any) => {
      if (error) console.error('Audit log error:', error)
    })

  const portalUrl = `https://hoapp.net/${communitySlug}/login`

  return jsonResponse({
    ok: true,
    community_id: community.id,
    user_id: user.id,
    portal_url: portalUrl,
    message: `Community "${communityName}" created. User ${betaRequest.email} is now the admin.`,
  })
}
