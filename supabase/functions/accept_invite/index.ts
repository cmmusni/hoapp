import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2.39.0'

interface AcceptInviteRequest {
  token?: string
}

interface AcceptInviteResponse {
  ok: boolean
  community_id?: string
  community_slug?: string
  community_name?: string
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

    // Extract user ID from JWT (deployed with --no-verify-jwt)
    const jwt = authHeader.replace('Bearer ', '')
    let jwtPayload: any
    try {
      jwtPayload = JSON.parse(atob(jwt.split('.')[1]))
    } catch {
      return jsonResponse({ ok: false, error: 'Invalid token' }, 401)
    }

    const userId = jwtPayload.sub
    if (!userId) {
      return jsonResponse({ ok: false, error: 'Invalid token: no subject' }, 401)
    }

    const supabaseAdmin = createClient(
      Deno.env.get('SUPABASE_URL') ?? '',
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? ''
    )

    // Look up user via admin client (bypasses auth issues)
    const { data: { user }, error: userError } = await supabaseAdmin.auth.admin.getUserById(userId)
    if (userError || !user) {
      console.error('getUserById failed:', userError)
      return jsonResponse({ ok: false, error: 'Unauthorized' }, 401)
    }

    const { token }: AcceptInviteRequest = await req.json().catch(() => ({}))

    let invite: any = null

    if (token) {
      const { data: tokenInvite, error: inviteError } = await supabaseAdmin
        .from('invites')
        .select('*')
        .eq('token', token)
        .single()

      if (inviteError || !tokenInvite) {
        return jsonResponse({ ok: false, error: 'Invalid invite token' }, 404)
      }
      invite = tokenInvite
    } else {
      // No token provided: auto-claim latest pending invite for current user email
      if (!user.email) {
        return jsonResponse({ ok: false, error: 'User email is required' }, 400)
      }

      const { data: pendingInvite, error: pendingInviteError } = await supabaseAdmin
        .from('invites')
        .select('*')
        .ilike('email', user.email)
        .is('accepted_at', null)
        .gt('expires_at', new Date().toISOString())
        .order('created_at', { ascending: false })
        .limit(1)
        .maybeSingle()

      if (pendingInviteError) {
        console.error('Pending invite query error:', pendingInviteError)
        return jsonResponse({ ok: false, error: 'Failed to look up pending invites' }, 500)
      }

      if (!pendingInvite) {
        return jsonResponse({ ok: true })
      }

      invite = pendingInvite
    }

    // Check expiry
    if (new Date(invite.expires_at) < new Date()) {
      return jsonResponse({ ok: false, error: 'Invite has expired' }, 410)
    }

    // Check if already accepted
    if (invite.accepted_at) {
      // Even if already accepted, ensure profile exists (in case it failed before)
      const { data: existingProfile } = await supabaseAdmin
        .from('profiles')
        .select('user_id')
        .eq('user_id', user.id)
        .eq('community_id', invite.community_id)
        .maybeSingle()

      if (!existingProfile) {
        // Profile is missing — recreate it
        console.log('Invite already accepted but profile missing, creating profile...')
        await supabaseAdmin
          .from('profiles')
          .upsert({
            user_id: user.id,
            community_id: invite.community_id,
            full_name: user.user_metadata?.full_name || user.email?.split('@')[0] || 'User',
            email: user.email
          }, { onConflict: 'user_id,community_id' })

        // Check if role exists before inserting
        const { data: existingRole } = await supabaseAdmin
          .from('user_roles')
          .select('id')
          .eq('user_id', user.id)
          .eq('community_id', invite.community_id)
          .eq('role', invite.role)
          .maybeSingle()

        if (!existingRole) {
          await supabaseAdmin
            .from('user_roles')
            .insert({
              user_id: user.id,
              community_id: invite.community_id,
              role: invite.role
            })
        }
      }

      // Fetch community for response
      const { data: community } = await supabaseAdmin
        .from('communities')
        .select('id, slug, name')
        .eq('id', invite.community_id)
        .single()

      return jsonResponse({
        ok: true,
        community_id: community?.id,
        community_slug: community?.slug,
        community_name: community?.name,
      })
    }

    // Check if email matches (optional strict check)
    // if (user.email !== invite.email) {
    //   return jsonResponse({ ok: false, error: 'Email mismatch' }, 403)
    // }

    // Upsert profile
    const { error: profileError } = await supabaseAdmin
      .from('profiles')
      .upsert({
        user_id: user.id,
        community_id: invite.community_id,
        full_name: user.user_metadata?.full_name || user.email?.split('@')[0] || 'User',
        email: user.email
      }, {
        onConflict: 'user_id,community_id'
      })

    if (profileError) {
      console.error('Profile upsert error:', profileError)
      return jsonResponse({ ok: false, error: 'Failed to create profile' }, 500)
    }

    // Insert user_role
    const { error: roleError } = await supabaseAdmin
      .from('user_roles')
      .insert({
        user_id: user.id,
        community_id: invite.community_id,
        role: invite.role
      })

    if (roleError) {
      // Check if role already exists
      const { data: existingRole } = await supabaseAdmin
        .from('user_roles')
        .select('id')
        .eq('user_id', user.id)
        .eq('community_id', invite.community_id)
        .eq('role', invite.role)
        .single()

      if (!existingRole) {
        console.error('Role insert error:', roleError)
        return jsonResponse({ ok: false, error: 'Failed to assign role' }, 500)
      }
    }

    // If household invite, link user to household_members
    if (invite.invite_kind === 'household' && invite.unit_id) {
      console.log('=== HOUSEHOLD LINKING ===')
      console.log('household_member_id:', invite.household_member_id)
      console.log('unit_id:', invite.unit_id)
      console.log('user.id:', user.id)

      // Check if user is already a household member for this unit
      const { data: existingMember } = await supabaseAdmin
        .from('household_members')
        .select('id')
        .eq('unit_id', invite.unit_id)
        .eq('user_id', user.id)
        .maybeSingle()

      console.log('existingMember:', existingMember)

      if (!existingMember) {
        if (invite.household_member_id) {
          // Verify the target row exists first
          const { data: targetRow, error: lookupError } = await supabaseAdmin
            .from('household_members')
            .select('id, user_id, member_name, member_role')
            .eq('id', invite.household_member_id)
            .maybeSingle()

          console.log('Target row lookup:', targetRow, 'error:', lookupError)

          if (targetRow) {
            // Update the exact row: set user_id, clear member_name
            const { data: updated, error: updateError } = await supabaseAdmin
              .from('household_members')
              .update({ user_id: user.id, member_name: null })
              .eq('id', invite.household_member_id)
              .select()

            console.log('Update result:', updated, 'error:', updateError)

            if (updateError) {
              console.error('Household member update FAILED:', updateError)
            }
          } else {
            // Target row not found — insert a new one
            console.log('Target household member not found, inserting new row')
            const { error: memberError } = await supabaseAdmin
              .from('household_members')
              .insert({
                community_id: invite.community_id,
                unit_id: invite.unit_id,
                user_id: user.id,
                member_role: 'member'
              })

            if (memberError) {
              console.error('Household member insert error:', memberError)
            }
          }
        } else {
          // No specific member referenced — insert a new row
          const { error: memberError } = await supabaseAdmin
            .from('household_members')
            .insert({
              community_id: invite.community_id,
              unit_id: invite.unit_id,
              user_id: user.id,
              member_role: 'member'
            })

          if (memberError) {
            console.error('Household member insert error:', memberError)
          }
        }
      }
    }

    // Mark invite as accepted
    const { error: updateError } = await supabaseAdmin
      .from('invites')
      .update({ accepted_at: new Date().toISOString() })
      .eq('id', invite.id)

    if (updateError) {
      console.error('Invite update error:', updateError)
    }

    // Audit log
    await supabaseAdmin
      .from('audit_logs')
      .insert({
        community_id: invite.community_id,
        actor_user_id: user.id,
        action: 'accept_invite',
        entity: 'invite',
        entity_id: invite.id,
        meta: { role: invite.role, invite_kind: invite.invite_kind }
      })

    // Fetch community details
    const { data: community } = await supabaseAdmin
      .from('communities')
      .select('id, slug, name')
      .eq('id', invite.community_id)
      .single()

    return jsonResponse<AcceptInviteResponse>({
      ok: true,
      community_id: community?.id,
      community_slug: community?.slug,
      community_name: community?.name
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
