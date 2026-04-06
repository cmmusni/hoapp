---
description: "Use when creating, modifying, or debugging Supabase Edge Functions. Covers authentication pattern, deployment flags, and Dart client integration for Edge Functions in this project."
applyTo: "supabase/functions/**"
---

# Supabase Edge Functions

## Authentication Pattern

Always use the shared `validateAuth` helper — never manually parse the Authorization header.

```typescript
import {
  corsHeaders,
  jsonResponse,
  errorResponse,
  createAdminClient,
  withErrorHandling,
  validateAuth,
} from '../_shared/utils.ts'

serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  return withErrorHandling(async () => {
    const body = await req.json()

    // validateAuth supports x-user-token header, Authorization header, and _jwt body fallback
    const authResult = await validateAuth(req, body)
    if (authResult instanceof Response) return authResult
    const { user } = authResult

    // Use createAdminClient() for DB queries that bypass RLS
    const supabase = createAdminClient()

    // ... function logic ...

    return jsonResponse({ ok: true })
  }, 'function_name')
})
```

## Dart Client Integration

When calling Edge Functions from Dart (`packages/core_data`), always pass the JWT via both `x-user-token` header and `_jwt` body field:

```dart
final jwt = _client.auth.currentSession?.accessToken;
await _client.functions.invoke(
  'function_name',
  headers: {
    if (jwt != null) 'x-user-token': jwt,
  },
  body: {
    // ... payload fields ...
    if (jwt != null) '_jwt': jwt,
  },
);
```

Do NOT set the `Authorization` header manually — the Supabase Flutter SDK adds it automatically, and duplicating it causes conflicts.

## Deployment

Always deploy with `--no-verify-jwt` since functions handle their own auth via `validateAuth`:

```bash
supabase functions deploy <function_name> --no-verify-jwt
```

## Shared Utilities

- `_shared/utils.ts` — `validateAuth`, `createAdminClient`, `jsonResponse`, `errorResponse`, `withErrorHandling`, `corsHeaders`, `createAuditLog`, rate limiting
- `_shared/email.ts` — `sendEmail` (Resend API), HTML email template generators
