import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import {
  corsHeaders,
  jsonResponse,
  errorResponse,
  withErrorHandling,
  validateAuth,
  createAdminClient,
  withRateLimit,
  validateRequired,
  createAuditLog,
} from '../_shared/utils.ts'
import { sendEmail, generateInviteEmailHTML } from '../_shared/email.ts'

interface CreateInviteRequest {
  community_id: string
  email: string
  role: string
  unit_id?: string
  invite_kind?: 'role' | 'household'
  new_unit_no?: string
  expires_at?: string
  _jwt?: string // Optional JWT token passed in body
}

serve(async (req) => {
  // Handle CORS preflight
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  return withErrorHandling(async () => {
    // Parse request body first
    const body: CreateInviteRequest = await req.json()
    
    // Debug logging
    console.log('=== CREATE INVITE DEBUG v11 ===')
    console.log('Body keys:', Object.keys(body))
    console.log('Has _jwt in body:', '_jwt' in body)
    console.log('_jwt length:', body._jwt ? body._jwt.length : 0)
    console.log('Headers:', Object.fromEntries(req.headers.entries()))
    console.log('SUPABASE_URL:', Deno.env.get('SUPABASE_URL'))
    console.log('SUPABASE_ANON_KEY exists:', !!Deno.env.get('SUPABASE_ANON_KEY'))
    
    // Validate authentication (supports JWT in headers OR body)
    const authResult = await validateAuth(req, body)
    if (authResult instanceof Response) {
      console.log('Auth validation failed')
      return authResult
    }
    const { user, supabase } = authResult
    
    console.log('Auth validated successfully for user:', user.id)

    // Rate limiting: 10 invites per hour per user
    const rateLimitResponse = withRateLimit(user.id, {
      maxRequests: 10,
      windowMs: 60 * 60 * 1000, // 1 hour
      key: 'create_invite',
    })
    if (rateLimitResponse) return rateLimitResponse

    // Validate required fields
    const missing = validateRequired(body, ['community_id', 'email', 'role'])
    if (missing.length > 0) {
      return errorResponse(
        `Missing required fields: ${missing.join(', ')}`,
        400,
        'MISSING_FIELDS'
      )
    }

    // Remove _jwt from body before processing
    delete body._jwt

    const {
      community_id,
      email,
      role,
      unit_id,
      invite_kind = 'role',
      new_unit_no,
      expires_at,
    } = body

    const supabaseAdmin = createAdminClient()

    // Check if user is staff OR (household invite to their own unit)
    const { data: userRoles } = await supabaseAdmin
      .from('user_roles')
      .select('role')
      .eq('user_id', user.id)
      .eq('community_id', community_id)

    const isStaff = userRoles?.some(r =>
      ['community_admin', 'hoa_officer'].includes(r.role)
    )

    if (invite_kind === 'household') {
      if (!unit_id && !new_unit_no) {
        return errorResponse(
          'unit_id or new_unit_no required for household invite',
          400,
          'MISSING_UNIT'
        )
      }

      // If not staff, verify caller is member of the unit
      if (!isStaff && unit_id) {
        const { data: membership } = await supabaseAdmin
          .from('household_members')
          .select('id')
          .eq('unit_id', unit_id)
          .eq('user_id', user.id)
          .maybeSingle()

        if (!membership) {
          return errorResponse(
            'Not authorized to invite to this unit',
            403,
            'FORBIDDEN'
          )
        }
      }
    } else {
      // Role invites require staff
      if (!isStaff) {
        return errorResponse(
          'Only staff can send role invites',
          403,
          'INSUFFICIENT_PERMISSIONS'
        )
      }
    }

    // If new_unit_no provided, create unit
    let finalUnitId = unit_id
    if (new_unit_no && !unit_id) {
      const { data: newUnit, error: unitError } = await supabaseAdmin
        .from('units')
        .insert({
          community_id,
          unit_no: new_unit_no,
        })
        .select()
        .single()

      if (unitError) {
        // Check if unit already exists
        const { data: existingUnit } = await supabaseAdmin
          .from('units')
          .select('id')
          .eq('community_id', community_id)
          .eq('unit_no', new_unit_no)
          .maybeSingle()

        if (existingUnit) {
          finalUnitId = existingUnit.id
        } else {
          console.error('Unit creation error:', unitError)
          return errorResponse('Failed to create unit', 500, 'UNIT_CREATION_FAILED')
        }
      } else {
        finalUnitId = newUnit.id
      }
    }

    // Generate secure token
    const token = crypto.randomUUID() + '-' + Date.now().toString(36)

    // Calculate expiry (default 7 days)
    const expiresAtDate = expires_at
      ? new Date(expires_at)
      : new Date(Date.now() + 7 * 24 * 60 * 60 * 1000)

    // Create invite
    const { data: invite, error: inviteError } = await supabaseAdmin
      .from('invites')
      .insert({
        community_id,
        email,
        role,
        unit_id: finalUnitId,
        invite_kind,
        token,
        expires_at: expiresAtDate.toISOString(),
        invited_by: user.id,
      })
      .select()
      .single()

    if (inviteError) {
      console.error('Invite creation error:', inviteError)
      return errorResponse('Failed to create invite', 500, 'INVITE_CREATION_FAILED')
    }

    // Audit log
    await createAuditLog(supabaseAdmin, {
      communityId: community_id,
      actorUserId: user.id,
      action: 'create_invite',
      entity: 'invite',
      entityId: invite.id,
      meta: { email, role, invite_kind, unit_id: finalUnitId },
    })

    // Get community slug for invite link
    const { data: community } = await supabaseAdmin
      .from('communities')
      .select('slug, name')
      .eq('id', community_id)
      .maybeSingle()

    const baseUrl = Deno.env.get('WEB_BASE_URL') || 'https://hoapp.net'
    // Base64url-encode the email so it's not plainly visible in the URL
    const encodedEmail = btoa(email).replace(/\+/g, '-').replace(/\//g, '_').replace(/=+$/, '')
    const inviteLink = community
      ? `${baseUrl}/${community.slug}/signup?invite=${token}&email=${encodedEmail}`
      : `${baseUrl}/signup?invite=${token}&email=${encodedEmail}`

    // Send email notification (non-blocking)
    if (community) {
      const { data: inviterProfile } = await supabaseAdmin
        .from('profiles')
        .select('full_name')
        .eq('user_id', user.id)
        .eq('community_id', community_id)
        .maybeSingle()

      sendEmail({
        to: email,
        subject: `You've been invited to ${community.name}`,
        html: generateInviteEmailHTML({
          recipientName: email.split('@')[0],
          communityName: community.name,
          inviteLink,
          inviterName: inviterProfile?.full_name || user.email || 'A community member',
          role,
          expiresAt: expiresAtDate,
        }),
      }).catch(err => console.error('Email send failed:', err))
    }

    return jsonResponse({
      ok: true,
      invite_link: inviteLink,
    })
  }, 'create_invite')
})
