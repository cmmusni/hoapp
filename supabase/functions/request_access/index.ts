import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2.39.0'
import {
  corsHeaders,
  jsonResponse,
  errorResponse,
} from '../_shared/utils.ts'
import { sendEmail } from '../_shared/email.ts'

interface RequestAccessBody {
  name: string
  email: string
  organization?: string
}

serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  try {
    if (req.method !== 'POST') {
      return errorResponse('Method not allowed', 405)
    }

    const body: RequestAccessBody = await req.json()

    if (!body.name?.trim()) return errorResponse('Name is required', 400)
    if (!body.email?.trim()) return errorResponse('Email is required', 400)
    if (!body.email.includes('@') || !body.email.includes('.')) {
      return errorResponse('Invalid email address', 400)
    }
    if (body.name.length > 200) return errorResponse('Name too long', 400)
    if (body.email.length > 320) return errorResponse('Email too long', 400)
    if (body.organization && body.organization.length > 300) {
      return errorResponse('Organization name too long', 400)
    }

    const name = body.name.trim()
    const email = body.email.trim()
    const org = body.organization?.trim() || 'Not specified'

    // Save to database
    const supabaseAdmin = createClient(
      Deno.env.get('SUPABASE_URL') ?? '',
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? ''
    )

    const { error: dbError } = await supabaseAdmin
      .from('beta_access_requests')
      .insert({
        name,
        email,
        organization: org !== 'Not specified' ? org : null,
      })

    if (dbError) {
      console.error('Failed to save beta request:', dbError)
    }

    const sent = await sendEmail({
      to: 'support@hoapp.net',
      subject: `[Beta Access Request] ${name}`,
      html: `
        <h2>New Beta Access Request</h2>
        <table style="border-collapse:collapse;">
          <tr><td style="padding:8px;font-weight:bold;">Name:</td><td style="padding:8px;">${name}</td></tr>
          <tr><td style="padding:8px;font-weight:bold;">Email:</td><td style="padding:8px;">${email}</td></tr>
          <tr><td style="padding:8px;font-weight:bold;">Community/Organization:</td><td style="padding:8px;">${org}</td></tr>
        </table>
        <p style="margin-top:16px;color:#666;">This request was submitted via the HOApp login page.</p>
      `,
    })

    if (!sent) {
      console.warn('Email delivery failed, but request logged')
    }

    return jsonResponse({ ok: true, message: 'Access request submitted' })
  } catch (err) {
    console.error('request_access error:', err)
    return errorResponse('Internal server error', 500)
  }
})
