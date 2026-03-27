import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import {
  corsHeaders,
  jsonResponse,
  errorResponse,
  createAdminClient,
} from '../_shared/utils.ts'
import { sendEmail } from '../_shared/email.ts'

interface ContactRequest {
  name: string
  email: string
  subject: string
  message: string
}

serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  try {
    if (req.method !== 'POST') {
      return errorResponse('Method not allowed', 405)
    }

    const body: ContactRequest = await req.json()

    // Validate required fields
    const missing: string[] = []
    if (!body.name?.trim()) missing.push('name')
    if (!body.email?.trim()) missing.push('email')
    if (!body.subject?.trim()) missing.push('subject')
    if (!body.message?.trim()) missing.push('message')

    if (missing.length > 0) {
      return errorResponse(`Missing required fields: ${missing.join(', ')}`, 400)
    }

    // Basic email format check
    if (!body.email.includes('@') || !body.email.includes('.')) {
      return errorResponse('Invalid email address', 400)
    }

    // Limit field lengths to prevent abuse
    if (body.name.length > 200) return errorResponse('Name too long', 400)
    if (body.email.length > 320) return errorResponse('Email too long', 400)
    if (body.subject.length > 500) return errorResponse('Subject too long', 400)
    if (body.message.length > 5000) return errorResponse('Message too long', 400)

    const admin = createAdminClient()

    const { error } = await admin
      .from('contact_messages')
      .insert({
        name: body.name.trim(),
        email: body.email.trim(),
        subject: body.subject.trim(),
        message: body.message.trim(),
      })

    if (error) {
      console.error('Insert error:', error)
      return errorResponse('Failed to save message', 500)
    }

    // Send email notification to support
    await sendEmail({
      to: 'support@hoapp.net',
      subject: `[Contact Form] ${body.subject.trim()}`,
      html: `
        <div style="font-family: Arial, sans-serif; max-width: 600px; margin: 0 auto;">
          <h2 style="color: #215e3f;">New Contact Form Submission</h2>
          <table style="width: 100%; border-collapse: collapse;">
            <tr>
              <td style="padding: 8px; font-weight: bold; vertical-align: top;">Name:</td>
              <td style="padding: 8px;">${body.name.trim()}</td>
            </tr>
            <tr>
              <td style="padding: 8px; font-weight: bold; vertical-align: top;">Email:</td>
              <td style="padding: 8px;"><a href="mailto:${body.email.trim()}">${body.email.trim()}</a></td>
            </tr>
            <tr>
              <td style="padding: 8px; font-weight: bold; vertical-align: top;">Subject:</td>
              <td style="padding: 8px;">${body.subject.trim()}</td>
            </tr>
            <tr>
              <td style="padding: 8px; font-weight: bold; vertical-align: top;">Message:</td>
              <td style="padding: 8px; white-space: pre-wrap;">${body.message.trim()}</td>
            </tr>
          </table>
          <hr style="margin-top: 24px; border: none; border-top: 1px solid #eee;" />
          <p style="color: #888; font-size: 12px;">This message was sent from the HOApp contact form.</p>
        </div>
      `,
    })

    return jsonResponse({ ok: true, message: 'Message received' })
  } catch (err) {
    console.error('contact_us error:', err)
    return errorResponse('Internal server error', 500)
  }
})
