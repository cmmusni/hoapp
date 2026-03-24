import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2.39.0'

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
  'Access-Control-Allow-Methods': 'POST, OPTIONS, DELETE',
}

function jsonResponse<T>(data: T, status = 200) {
  return new Response(JSON.stringify(data), {
    status,
    headers: { ...corsHeaders, 'Content-Type': 'application/json' },
  })
}

serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  try {
    // Auth: extract caller from JWT
    const authHeader = req.headers.get('Authorization')
    if (!authHeader) {
      return jsonResponse({ ok: false, error: 'Unauthorized' }, 401)
    }

    const jwt = authHeader.replace('Bearer ', '')
    let jwtPayload: any
    try {
      jwtPayload = JSON.parse(atob(jwt.split('.')[1]))
    } catch {
      return jsonResponse({ ok: false, error: 'Invalid token' }, 401)
    }

    const callerId = jwtPayload.sub
    if (!callerId) {
      return jsonResponse({ ok: false, error: 'Invalid token' }, 401)
    }

    const { target_user_id, community_id } = await req.json()

    if (!target_user_id || !community_id) {
      return jsonResponse({ ok: false, error: 'target_user_id and community_id are required' }, 400)
    }

    // Prevent self-deletion
    if (target_user_id === callerId) {
      return jsonResponse({ ok: false, error: 'You cannot delete your own account' }, 403)
    }

    const supabaseAdmin = createClient(
      Deno.env.get('SUPABASE_URL') ?? '',
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? ''
    )

    // Verify caller is community_admin
    const { data: callerRoles } = await supabaseAdmin
      .from('user_roles')
      .select('role')
      .eq('user_id', callerId)
      .eq('community_id', community_id)

    const isAdmin = callerRoles?.some(r => r.role === 'community_admin')
    if (!isAdmin) {
      return jsonResponse({ ok: false, error: 'Only community admins can delete users' }, 403)
    }

    // Delete the auth user — cascades to profiles, user_roles, etc.
    const { error: deleteError } = await supabaseAdmin.auth.admin.deleteUser(target_user_id)

    if (deleteError) {
      console.error('Delete user error:', deleteError)
      return jsonResponse({ ok: false, error: 'Failed to delete user' }, 500)
    }

    // Audit log
    await supabaseAdmin
      .from('audit_logs')
      .insert({
        community_id,
        actor_user_id: callerId,
        action: 'delete_user',
        entity: 'user',
        entity_id: target_user_id,
        meta: { target_user_id }
      })

    return jsonResponse({ ok: true })

  } catch (err) {
    console.error('Unexpected error:', err)
    return jsonResponse({ ok: false, error: 'Internal server error' }, 500)
  }
})
