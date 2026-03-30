# Email Confirmation Setup for HOApp

This guide explains how to properly configure email confirmations in your Supabase project.

## Problem

When users sign up, they receive a confirmation email. However, when they click the confirmation link, nothing happens or they get stuck on a loading page.

## Solution

### 1. Configure Supabase Redirect URLs

You need to add the correct redirect URLs in your Supabase project settings:

1. Go to your Supabase Dashboard: https://supabase.com/dashboard
2. Select your project
3. Navigate to **Authentication** → **URL Configuration**
4. Add the following URLs to **Redirect URLs**:

**For Local Development:**
```
http://localhost:3000/auth/callback
http://localhost:3000/auth-callback
```

**For Production:**
```
https://your-domain.com/auth/callback
https://your-domain.com/auth-callback
```

5. Click **Save**

### 2. Configure Email Templates (Optional)

By default, Supabase uses a redirect URL that includes the confirmation parameters. To ensure proper handling:

1. Go to **Authentication** → **Email Templates**
2. Select **Confirm signup**
3. Ensure the confirmation link uses the correct format:
   ```
   {{ .SiteURL }}/auth/callback?token_hash={{ .TokenHash }}&type=signup
   ```

### 3. Code Changes

The following code changes have been implemented to handle email confirmations properly:

#### ✅ Updated `AuthCallbackPage`
- Sets up auth state listener IMMEDIATELY in `initState()` to catch PKCE code exchange
- Handles `AuthChangeEvent.initialSession` event (fired when SDK completes PKCE exchange)
- Uses polling approach: checks session every 500ms for up to 10 seconds
- Checks for existing session before waiting (in case exchange already completed)
- Adds comprehensive debug logging at each step
- Has a 5-second final timeout with fallback to login page
- Properly handles both PKCE code flow and direct token flow

#### ✅ Updated `SupabaseClientManager`
- Configured with PKCE auth flow for web (more secure)
- Uses implicit flow for mobile apps
- Automatically exchanges PKCE code for tokens on callback

#### ✅ Router Configuration
Routes configured to handle:
- `/auth/callback` - Primary callback route (used by email verification)
- `/auth-callback` - Alternative callback route
- `/` with `?code=...` - Detects PKCE code and redirects to callback

## Testing

### 1. Sign Up
1. Go to http://localhost:3000/signup
2. Enter your email and password
3. Click "Sign Up"
4. Check your email inbox

### 2. Confirm Email
1. Click the confirmation link in the email
2. You should see "Verifying your account..."
3. Then "Processing verification..."
4. Then "Setting up your account..."
5. Finally, you'll be redirected to your community or create-community page

### 3. Check Browser Console
Open browser DevTools (F12) and check the Console tab for debug messages:
- `Auth callback: URI=...` - Shows the callback URL with parameters
- `Auth callback: Query params=...` - Shows all query parameters (code, type, etc.)
- `Auth callback: code=present` - Confirms PKCE code is in URL
- `Auth callback: checking existing session` - Shows session check status
- `Auth callback: user already signed in` - Confirms authentication successful
- `Auth callback: auth state changed: signedIn` - Shows successful sign-in event

## Troubleshooting

### Issue: "Error processing verification" or stuck on loading

**Possible Causes:**
- Router context not available during initialization
- PKCE code exchange timing issue

**Solution:** 
This has been fixed in the latest version:
- AuthCallbackPage now uses `addPostFrameCallback` to ensure router context is ready
- Increased delay to 1500ms for PKCE code exchange
- Extended timeout to 15 seconds
If still seeing issues:
1. Check browser console for specific error messages
2. Ensure you're using the latest code
3. Try hard refresh (Cmd+Shift+R or Ctrl+Shift+R)

### Issue: "Verification timed out. Redirecting..." after 15 seconds

**Possible Causes:**
- PKCE code exchange failed
- Network connectivity issue
- Supabase auth service unavailable
- Session not being established by SDK

**Solution:**
1. Check browser console for error messages (look for "Auth callback:" logs)
2. Verify Supabase URL and anon key are correct in `.env`
3. Ensure PKCE flow is enabled in `supabase_client.dart`:
   ```dart
   authOptions: FlutterAuthClientOptions(
     authFlowType: kIsWeb ? AuthFlowType.pkce : AuthFlowType.implicit,
   )
   ```
4. Check network tab in DevTools for failed requests to Supabase
5. Try signing up again with a different email

### Issue: Redirected to login page after confirmation

**Cause:** Session not properly established

**Solution:**
1. Check that email confirmation is enabled in Supabase (Auth → Providers → Email)
2. Ensure "Enable email confirmations" is checked
3. Try disabling and re-enabling it

### Issue: Page shows errors about missing Supabase configuration

**Cause:** Environment variables not loaded

**Solution:**
1. Ensure `.env` file exists in project root
2. Verify it contains:
   ```
   SUPABASE_URL=https://your-project.supabase.co
   SUPABASE_ANON_KEY=your-anon-key
   ```
3. Restart the Flutter app after changing `.env`

## Email Confirmation Flow

```
┌─────────────┐
│ User Signs  │
│     Up      │
└──────┬──────┘
       │
       ▼
┌─────────────────────────────────┐
│ Supabase sends confirmation     │
│ email with token                │
└──────┬──────────────────────────┘
       │
       ▼
┌─────────────────────────────────┐
│ User clicks link in email       │
│ Browser opens:                  │
│ /auth/callback?token=...        │
└──────┬──────────────────────────┘
       │
       ▼
┌─────────────────────────────────┐
│ AuthCallbackPage loads          │
│ - Detects tokens in URL        │
│ - Waits for SDK to process     │
└──────┬──────────────────────────┘
       │
       ▼
┌─────────────────────────────────┐
│ Supabase SDK exchanges token    │
│ for session (JWT)               │
└──────┬──────────────────────────┘
       │
       ▼
┌─────────────────────────────────┐
│ AuthCallbackPage detects        │
│ authenticated user              │
└──────┬──────────────────────────┘
       │
       ▼
┌─────────────────────────────────┐
│ Accept any pending invites      │
└──────┬──────────────────────────┘
       │
       ▼
┌─────────────────────────────────┐
│ Redirect to community portal    │
│ or home page                    │
└─────────────────────────────────┘
```

## Production Deployment

When deploying to production:

1. **Add Production URLs to Supabase:**
   - `https://yourdomain.com/auth/callback`
   - `https://yourdomain.com/auth-callback`

2. **Update Environment Variables:**
   ```bash
   # In your hosting platform (Netlify, Vercel, etc.)
   SUPABASE_URL=https://your-project.supabase.co
   SUPABASE_ANON_KEY=your-production-anon-key
   WEB_BASE_URL=https://yourdomain.com
   ```

3. **Test Email Confirmation:**
   - Create a new account on production
   - Confirm email
   - Verify you're redirected properly

## Additional Resources

- [Supabase Auth Documentation](https://supabase.com/docs/guides/auth)
- [Supabase Email Templates](https://supabase.com/docs/guides/auth/auth-email-templates)
- [Flutter Supabase Package](https://pub.dev/packages/supabase_flutter)
