# Edge Functions Configuration Guide

## Email Service Setup (Resend)

To enable email notifications for invites and payment verifications, you need to configure the Resend API:

### 1. Get Resend API Key

1. Sign up at [https://resend.com](https://resend.com)
2. Create a new API key from the dashboard
3. Copy the API key (starts with `re_`)

### 2. Set Environment Variable in Supabase

```bash
# Using Supabase CLI
supabase secrets set RESEND_API_KEY=re_your_api_key_here

# Or through Supabase Dashboard:
# Project Settings → Edge Functions → Secrets → Add new secret
# Name: RESEND_API_KEY
# Value: re_your_api_key_here
```

### 3. Configure Sender Domain (Optional but Recommended)

By default, emails are sent from `noreply@hoapp.net`. To use your own domain:

1. In Resend dashboard, add and verify your domain
2. Update the `from` parameter in `_shared/email.ts`:
   ```typescript
   const { to, subject, html, from = 'Your App <noreply@yourdomain.com>' } = params
   ```

### 4. Test Email Sending

```bash
# Test create_invite function
curl -X POST https://your-project.supabase.co/functions/v1/create_invite \
  -H "Authorization: Bearer YOUR_ANON_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "community_id": "...",
    "email": "test@example.com",
    "role": "resident"
  }'
```

## Web Base URL Configuration

Set the base URL for invite links and portal links:

```bash
# Production
supabase secrets set WEB_BASE_URL=https://yourdomain.com

# Localhost (for testing)
supabase secrets set WEB_BASE_URL=http://localhost:3000
```

## Rate Limiting

Current limits:
- **create_invite**: 10 invites per hour per user
- **batch_operations**: 5 batch requests per minute per user

To adjust limits, edit the `withRateLimit` calls in each function:

```typescript
const rateLimitResponse = withRateLimit(user.id, {
  maxRequests: 10,        // Max requests
  windowMs: 60 * 60 * 1000, // Time window (1 hour = 3600000ms)
  key: 'function_name',
})
```

## Batch Operations

The batch operations endpoint supports:

### Supported Entities:
- `announcement` - Create, update, delete
- `invoice` - Create, update
- `ticket` - Update status
- `amenity_booking` - Delete

### Example Request:

\`\`\`json
{
  "community_id": "uuid",
  "operations": [
    {
      "id": "op1",
      "operation": "create",
      "entity": "announcement",
      "data": {
        "title": "Pool Maintenance",
        "body": "Pool will be closed...",
        "pinned": false
      }
    },
    {
      "id": "op2",
      "operation": "update",
      "entity": "ticket",
      "data": {
        "ticket_id": "uuid",
        "status": "resolved"
      }
    }
  ]
}
\`\`\`

### Limits:
- Maximum 100 operations per batch
- Only staff/admin can execute batch operations

## Deployment

After adding new edge functions, deploy them:

\`\`\`bash
# Deploy all functions
supabase functions deploy

# Deploy specific function
supabase functions deploy create_invite
supabase functions deploy verify_payment
supabase functions deploy batch_operations

# View logs
supabase functions logs create_invite --tail
\`\`\`

## Email Templates

Email templates are defined in `/supabase/functions/_shared/email.ts`:

- **Invite Email** - `generateInviteEmailHTML()`
- **Payment Notification** - `generatePaymentNotificationHTML()`

To customize templates, edit these functions. The HTML uses inline styles for email client compatibility.

## Error Handling

All edge functions now use standardized error handling from `_shared/utils.ts`:

- **400** - Bad Request (MISSING_FIELDS, INVALID_REQUEST)
- **401** - Unauthorized (AUTH_ERROR, INVALID_TOKEN)
- **403** - Forbidden (INSUFFICIENT_PERMISSIONS, FORBIDDEN)
- **404** - Not Found (NOT_FOUND)
- **429** - Rate Limit Exceeded (RATE_LIMIT_EXCEEDED)
- **500** - Internal Server Error (INTERNAL_ERROR)

Error responses include:
- `ok: false`
- `error: string` - Human-readable message
- `code: string` - Machine-readable error code

## Monitoring

Check function logs for email delivery status:

\`\`\`bash
# View recent logs
supabase functions logs create_invite --tail

# Search for email errors
supabase functions logs create_invite | grep "Email send"
\`\`\`

Successful emails log: `Email sent successfully: <message_id>`
Failed emails log: `Email send failed: <error>`

## Security Notes

1. **API Keys**: Never commit API keys to version control
2. **Rate Limiting**: Protects against abuse and API quota exhaustion
3. **Authentication**: All functions validate JWT tokens
4. **RLS**: Database operations respect Row Level Security policies
5. **Audit Logs**: All operations are logged for compliance

---

For more information, see:
- [Supabase Edge Functions Docs](https://supabase.com/docs/guides/functions)
- [Resend API Docs](https://resend.com/docs)
