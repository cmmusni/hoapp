// Email service utilities using Resend API
// Set RESEND_API_KEY in Supabase secrets to enable email sending

export interface SendEmailParams {
  to: string
  subject: string
  html: string
  from?: string
}

/**
 * Send email using Resend API
 * Requires RESEND_API_KEY environment variable
 */
export async function sendEmail(params: SendEmailParams): Promise<boolean> {
  const resendApiKey = Deno.env.get('RESEND_API_KEY')
  
  if (!resendApiKey) {
    console.warn('RESEND_API_KEY not set, skipping email send')
    return false
  }

  const { to, subject, html, from = 'HOApp <noreply@hoapp.net>' } = params

  try {
    const response = await fetch('https://api.resend.com/emails', {
      method: 'POST',
      headers: {
        'Authorization': `Bearer ${resendApiKey}`,
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({
        from,
        to: [to],
        subject,
        html,
      }),
    })

    if (!response.ok) {
      const error = await response.text()
      console.error('Email send failed:', error)
      return false
    }

    const result = await response.json()
    console.log('Email sent successfully:', result.id)
    return true
  } catch (error) {
    console.error('Email send error:', error)
    return false
  }
}

/**
 * Generate invite email HTML
 */
export function formatRoleLabel(role: string): string {
  const roleLabels: Record<string, string> = {
    'community_admin': 'Community Admin',
    'hoa_officer': 'HOA Officer',
    'security_guard': 'Security Guard',
    'resident': 'Resident',
  }
  return roleLabels[role] || role.replace(/_/g, ' ').replace(/\b\w/g, c => c.toUpperCase())
}

export function generateInviteEmailHTML(params: {
  recipientName: string
  communityName: string
  inviteLink: string
  inviterName: string
  role: string
  expiresAt: Date
}): string {
  const { recipientName, communityName, inviteLink, inviterName, role, expiresAt } = params
  
  const roleLabel = formatRoleLabel(role)
  const expiryDate = expiresAt.toLocaleDateString('en-US', {
    year: 'numeric',
    month: 'long',
    day: 'numeric',
  })

  return `
<!DOCTYPE html>
<html>
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>Invitation to ${communityName}</title>
</head>
<body style="font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, 'Helvetica Neue', Arial, sans-serif; line-height: 1.6; color: #333; max-width: 600px; margin: 0 auto; padding: 20px;">
  <div style="background: linear-gradient(135deg, #2E7D32 0%, #1B5E20 100%); color: white; padding: 30px; border-radius: 10px 10px 0 0; text-align: center;">
    <h1 style="margin: 0; font-size: 28px;">🏠 HOApp Invitation</h1>
  </div>
  
  <div style="background: #ffffff; padding: 30px; border: 1px solid #e1e8ed; border-top: none; border-radius: 0 0 10px 10px;">
    <p style="font-size: 16px; margin-top: 0;">Hi${recipientName ? ' ' + recipientName : ''},</p>
    
    <p style="font-size: 16px;">
      <strong>${inviterName}</strong> has invited you to join <strong>${communityName}</strong> on HOApp 
      as <strong>${roleLabel}</strong>.
    </p>
    
    <div style="background: #f1f8e9; border-left: 4px solid #2E7D32; padding: 15px; margin: 25px 0;">
      <p style="margin: 0; font-size: 14px; color: #4a5568;">
        <strong>Community:</strong> ${communityName}<br>
        <strong>Role:</strong> ${roleLabel}<br>
        <strong>Expires:</strong> ${expiryDate}
      </p>
    </div>
    
    <p style="font-size: 16px;">
      Click the button below to accept the invitation and create your account:
    </p>
    
    <div style="text-align: center; margin: 30px 0;">
      <a href="${inviteLink}" 
         style="display: inline-block; background: linear-gradient(135deg, #2E7D32 0%, #1B5E20 100%); color: white; text-decoration: none; padding: 14px 40px; border-radius: 8px; font-weight: bold; font-size: 16px;">
        Accept Invitation
      </a>
    </div>
    
    <p style="font-size: 14px; color: #718096;">
      Or copy and paste this link into your browser:<br>
      <a href="${inviteLink}" style="color: #2E7D32; word-break: break-all;">${inviteLink}</a>
    </p>
    
    <hr style="border: none; border-top: 1px solid #e1e8ed; margin: 30px 0;">
    
    <p style="font-size: 13px; color: #a0aec0; margin-bottom: 0;">
      This invitation will expire on ${expiryDate}. If you didn't expect this invitation, you can safely ignore this email.
    </p>
  </div>
  
  <div style="text-align: center; margin-top: 20px; padding: 20px;">
    <p style="font-size: 12px; color: #a0aec0; margin: 0;">
      © ${new Date().getFullYear()} HOApp. All rights reserved.
    </p>
  </div>
</body>
</html>
  `.trim()
}

/**
 * Generate payment verification notification email HTML
 */
export function generatePaymentNotificationHTML(params: {
  recipientName: string
  communityName: string
  invoiceNumber: string
  amount: number
  status: 'verified' | 'rejected'
  rejectionReason?: string
  portalLink: string
}): string {
  const { recipientName, communityName, invoiceNumber, amount, status, rejectionReason, portalLink } = params
  
  const isVerified = status === 'verified'
  const statusColor = isVerified ? '#48bb78' : '#f56565'
  const statusText = isVerified ? 'Verified' : 'Rejected'

  return `
<!DOCTYPE html>
<html>
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>Payment ${statusText}</title>
</head>
<body style="font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, 'Helvetica Neue', Arial, sans-serif; line-height: 1.6; color: #333; max-width: 600px; margin: 0 auto; padding: 20px;">
  <div style="background: ${statusColor}; color: white; padding: 30px; border-radius: 10px 10px 0 0; text-align: center;">
    <h1 style="margin: 0; font-size: 28px;">${isVerified ? '✓' : '✗'} Payment ${statusText}</h1>
  </div>
  
  <div style="background: #ffffff; padding: 30px; border: 1px solid #e1e8ed; border-top: none; border-radius: 0 0 10px 10px;">
    <p style="font-size: 16px; margin-top: 0;">Hi ${recipientName},</p>
    
    <p style="font-size: 16px;">
      Your payment submission for ${communityName} has been ${status === 'verified' ? 'verified' : 'rejected'}.
    </p>
    
    <div style="background: #f7fafc; border-left: 4px solid ${statusColor}; padding: 15px; margin: 25px 0;">
      <p style="margin: 0; font-size: 14px; color: #4a5568;">
        <strong>Invoice:</strong> ${invoiceNumber}<br>
        <strong>Amount:</strong> ₱${amount.toFixed(2)}<br>
        <strong>Status:</strong> ${statusText}
      </p>
    </div>
    
    ${rejectionReason ? `
    <div style="background: #fff5f5; border: 1px solid #feb2b2; border-radius: 8px; padding: 15px; margin: 20px 0;">
      <p style="margin: 0; font-size: 14px; color: #c53030;">
        <strong>Reason for rejection:</strong><br>
        ${rejectionReason}
      </p>
    </div>
    ` : ''}
    
    <p style="font-size: 16px;">
      ${isVerified 
        ? 'Your payment has been successfully processed. Thank you!' 
        : 'Please review the rejection reason and submit a new payment proof if needed.'}
    </p>
    
    <div style="text-align: center; margin: 30px 0;">
      <a href="${portalLink}" 
         style="display: inline-block; background: ${statusColor}; color: white; text-decoration: none; padding: 14px 40px; border-radius: 8px; font-weight: bold; font-size: 16px;">
        View Details
      </a>
    </div>
  </div>
  
  <div style="text-align: center; margin-top: 20px; padding: 20px;">
    <p style="font-size: 12px; color: #a0aec0; margin: 0;">
      © ${new Date().getFullYear()} HOApp. All rights reserved.
    </p>
  </div>
</body>
</html>
  `.trim()
}
