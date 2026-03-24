# 🚀 HOApp Production Deployment Checklist

Use this checklist to ensure a smooth production deployment of HOApp.

---

## 📋 Pre-Deployment Checklist

### 1. Code Quality & Testing

- [ ] All tests passing (`./run_tests.sh`)
- [ ] No critical errors in code (`flutter analyze`)
- [ ] Code committed to main branch
- [ ] Version number updated in pubspec.yaml files
- [ ] CHANGELOG.md updated with release notes

### 2. Security Review

- [ ] `.env` file is in `.gitignore` (VERIFIED ✓)
- [ ] No hardcoded API keys or secrets in code
- [ ] All RLS policies reviewed and tested
- [ ] Storage bucket policies configured correctly
- [ ] Service role key usage limited to Edge Functions only
- [ ] Rate limiting configured on Edge Functions
- [ ] CORS settings reviewed

### 3. Database Preparation

**Location**: `supabase/migrations/`

Migrations verified:
- [x] `20260322000001_initial_schema.sql` - Core tables
- [x] `20260322000002_triggers.sql` - Audit logs & timestamps
- [x] `20260322000003_rls_policies.sql` - Row Level Security
- [x] `20260322000004_storage_policies.sql` - File upload policies
- [x] `20240322000005_enable_realtime.sql` - Realtime subscriptions

**Action Items**:
- [ ] Review all migration files for production readiness
- [ ] Test migrations on staging environment
- [ ] Backup existing database (if upgrading)
- [ ] Document rollback procedure

### 4. Edge Functions Verification

**Location**: `supabase/functions/`

Functions verified:
- [x] `create_community/` - Community creation with slug validation
- [x] `create_invite/` - User invitation system
- [x] `accept_invite/` - Invite acceptance & role assignment
- [x] `verify_payment/` - Payment verification workflow
- [x] `book_amenity/` - Amenity booking with conflict checking

**Action Items**:
- [ ] Test each function locally
- [ ] Review environment variable usage
- [ ] Check error handling and logging
- [ ] Verify CORS headers

### 5. Environment Variables

Required secrets for each platform:

**Supabase Project**:
- [ ] `SUPABASE_URL` - Your Supabase project URL
- [ ] `SUPABASE_ANON_KEY` - Public anon key (safe for client-side)
- [ ] `SUPABASE_SERVICE_ROLE_KEY` - Service role key (Edge Functions only)
- [ ] `WEB_BASE_URL` - Production domain (e.g., https://hoapp.net)

**For CI/CD (GitHub Secrets)**:
- [ ] `SUPABASE_URL`
- [ ] `SUPABASE_ANON_KEY`
- [ ] `SUPABASE_ACCESS_TOKEN` - For CLI access
- [ ] `SUPABASE_PROJECT_ID` - Project reference ID
- [ ] `KEYSTORE_BASE64` - Android keystore (base64 encoded)
- [ ] `KEYSTORE_PASSWORD` - Keystore password
- [ ] `KEY_PASSWORD` - Key password
- [ ] `KEY_ALIAS` - Key alias (default: hoapp-release)

**For Hosting Platform (Netlify/Vercel/Cloudflare)**:
- [ ] `SUPABASE_URL`
- [ ] `SUPABASE_ANON_KEY`

---

## 🗄️ Supabase Deployment

### Step 1: Create Production Project

1. [ ] Go to [supabase.com](https://supabase.com)
2. [ ] Create new project
3. [ ] Choose your region (closest to users)
4. [ ] Set strong database password
5. [ ] Wait for project initialization (~2 minutes)

### Step 2: Configure Project Settings

1. [ ] **Authentication**:
   - Enable Email provider
   - Configure email templates
   - Set site URL to your production domain
   - Add redirect URLs for OAuth callbacks

2. [ ] **Storage**:
   - Verify bucket policies are set
   - Configure file size limits
   - Enable public access for required buckets

3. [ ] **Database**:
   - Review connection pooler settings
   - Configure backups (automatic daily backups)
   - Set up read replicas (if needed for scale)

4. [ ] **API**:
   - Review rate limiting settings
   - Configure custom domains (optional)
   - Enable/disable realtime for specific tables

### Step 3: Link Local Project

```bash
cd supabase
supabase login
supabase link --project-ref YOUR_PROJECT_REF
```

- [ ] Supabase CLI installed
- [ ] Logged in with access token
- [ ] Project linked successfully

### Step 4: Apply Migrations

```bash
cd supabase
supabase db push
```

**Verify**:
- [ ] All 5 migrations applied successfully
- [ ] No errors in Supabase dashboard
- [ ] Public schema tables visible
- [ ] RLS policies active (check policies tab)

### Step 5: Deploy Edge Functions

```bash
cd supabase
supabase functions deploy create_community --no-verify-jwt
supabase functions deploy create_invite
supabase functions deploy accept_invite
supabase functions deploy verify_payment
supabase functions deploy book_amenity
```

**Verify**:
- [ ] All 5 functions deployed
- [ ] Functions appear in dashboard
- [ ] Environment variables set
- [ ] Test each function with sample data

**Set Edge Function Secrets**:
```bash
supabase secrets set SUPABASE_SERVICE_ROLE_KEY=your-service-role-key
supabase secrets set WEB_BASE_URL=https://hoapp.net
```

### Step 6: Seed Demo Data (Optional)

```bash
cd supabase
supabase db reset --seed
```

This creates the "Elevé Homes" demo community with sample data.

- [ ] Demo data seeded successfully
- [ ] Can login with demo credentials
- [ ] All features functional with demo data

---

## 🌐 Web Deployment

### Option 1: Netlify

**Setup**:
1. [ ] Connect GitHub repository to Netlify
2. [ ] Build settings auto-detected from `netlify.toml`
3. [ ] Add environment variables:
   - `SUPABASE_URL`
   - `SUPABASE_ANON_KEY`
4. [ ] Deploy site

**Custom Domain**:
1. [ ] Add custom domain in Netlify dashboard
2. [ ] Configure DNS records (A/CNAME)
3. [ ] Enable HTTPS (automatic with Let's Encrypt)
4. [ ] Update `WEB_BASE_URL` in Supabase secrets

**Verify**:
- [ ] Site accessible at production URL
- [ ] SPA routing works (no 404 on refresh)
- [ ] Can login and access features
- [ ] Community-specific URLs work (`/slug/login.html`)

### Option 2: Vercel

**Setup**:
1. [ ] Import project from GitHub
2. [ ] Framework preset: Other
3. [ ] Build settings from `vercel.json`
4. [ ] Add environment variables:
   - `SUPABASE_URL`
   - `SUPABASE_ANON_KEY`
5. [ ] Deploy

**Custom Domain**:
1. [ ] Add domain in Vercel dashboard
2. [ ] Update DNS with Vercel nameservers
3. [ ] SSL automatically provisioned
4. [ ] Update `WEB_BASE_URL` in Supabase

**Verify**:
- [ ] All routes accessible
- [ ] Environment variables working
- [ ] Performance optimized

### Option 3: Cloudflare Pages

**Setup**:
1. [ ] Connect GitHub repository
2. [ ] Build command: `./cloudflare-build.sh`
3. [ ] Build output: `apps/web_portal/build/web`
4. [ ] Add environment variables
5. [ ] Deploy

**Configuration**:
1. [ ] Enable "Single Page Application" mode
2. [ ] Configure custom domain
3. [ ] Set up redirects (automatic in SPA mode)

**Verify**:
- [ ] Build succeeds
- [ ] Site loads correctly
- [ ] Cache invalidated after deploy

---

## 📱 Mobile Deployment

### Android APK

#### First-Time Setup

1. **Generate Keystore**:
```bash
keytool -genkey -v -keystore ~/hoapp-release-key.jks \
  -keyalg RSA -keysize 2048 -validity 10000 \
  -alias hoapp-release
```

- [ ] Keystore generated
- [ ] Password saved in secure location
- [ ] Keystore backed up (DO NOT LOSE THIS!)

2. **Configure Signing**:

Create `apps/mobile/android/key.properties`:
```properties
storePassword=YOUR_STORE_PASSWORD
keyPassword=YOUR_KEY_PASSWORD
keyAlias=hoapp-release
storeFile=/path/to/hoapp-release-key.jks
```

- [ ] `key.properties` created
- [ ] Added to `.gitignore` (already included ✓)
- [ ] Paths correct

#### Build APK

```bash
cd apps/mobile
flutter build apk --release \
  --dart-define=SUPABASE_URL=https://your-project.supabase.co \
  --dart-define=SUPABASE_ANON_KEY=your-anon-key
```

- [ ] Build successful
- [ ] APK generated at `build/app/outputs/flutter-apk/app-release.apk`
- [ ] APK size acceptable (<30MB)

#### Distribution

**Option A: Direct Distribution (Sideloading)**
- [ ] Upload APK to file hosting (Google Drive, Dropbox, etc.)
- [ ] Share download link with users
- [ ] Provide instructions for enabling "Unknown Sources"

**Option B: Google Play Store**
1. [ ] Create Play Console account ($25 one-time fee)
2. [ ] Create app listing
3. [ ] Upload APK or build AAB:
   ```bash
   flutter build appbundle --release \
     --dart-define=SUPABASE_URL=... \
     --dart-define=SUPABASE_ANON_KEY=...
   ```
4. [ ] Complete store listing (screenshots, descriptions)
5. [ ] Submit for review
6. [ ] Handle any review feedback

### iOS (Development Distribution Only)

For free Apple Developer account:

1. [ ] Open `apps/mobile/ios/Runner.xcworkspace` in Xcode
2. [ ] Select Runner target
3. [ ] Enable "Automatically manage signing"
4. [ ] Sign in with Apple ID
5. [ ] Connect physical device
6. [ ] Enable Developer Mode on device
7. [ ] Run from Xcode

**Limitations**:
- [ ] Apps expire after 7 days
- [ ] Must re-install weekly
- [ ] Cannot distribute to other users
- [ ] Development devices only

**For Production iOS Distribution**:
- Requires paid Apple Developer Program ($99/year)
- Submit to App Store or TestFlight

---

## 🔄 CI/CD Setup (GitHub Actions)

### Configure Repository Secrets

Go to GitHub Settings → Secrets → Actions:

**Supabase**:
- [ ] `SUPABASE_URL`
- [ ] `SUPABASE_ANON_KEY`
- [ ] `SUPABASE_ACCESS_TOKEN` - Generate from Supabase dashboard
- [ ] `SUPABASE_PROJECT_ID`

**Android Signing**:
- [ ] `KEYSTORE_BASE64` - Base64 encode your keystore:
  ```bash
  base64 -i ~/hoapp-release-key.jks | tr -d '\n' | pbcopy
  ```
- [ ] `KEYSTORE_PASSWORD`
- [ ] `KEY_PASSWORD`
- [ ] `KEY_ALIAS`

### Enable Workflow

- [ ] Push to main branch triggers deployment
- [ ] Pull requests trigger tests only
- [ ] Artifacts uploaded (APK, web build)
- [ ] Monitor workflow runs

**Workflow includes**:
- ✓ Run tests
- ✓ Build web application
- ✓ Build Android APK
- ✓ Deploy Edge Functions
- ✓ Push database migrations

---

## ✅ Post-Deployment Verification

### Functional Testing

**Authentication**:
- [ ] Sign up with email works
- [ ] Login works
- [ ] Password reset works
- [ ] Session persists on refresh

**Community Creation**:
- [ ] Can create new community
- [ ] Slug validation works
- [ ] Creator assigned as admin
- [ ] Portal URL accessible

**User Invitations**:
- [ ] Can send invites
- [ ] Invite link works
- [ ] Role assignment correct
- [ ] Email notifications sent (if configured)

**Core Features**:
- [ ] Announcements CRUD works
- [ ] Violations submission works
- [ ] Tickets and chat functional
- [ ] Amenity booking works
- [ ] Billing and payments work
- [ ] Pool access registration works
- [ ] File uploads work (photos, PDFs)

**Realtime Features**:
- [ ] Realtime updates work
- [ ] Presence tracking works
- [ ] Broadcast messages work

**Mobile App (if deployed)**:
- [ ] App installs on Android
- [ ] Login works
- [ ] Deep links work
- [ ] Image upload works
- [ ] Push notifications work (if configured)

### Performance Testing

- [ ] Page load times acceptable (<3s)
- [ ] Images optimized
- [ ] API responses fast (<500ms)
- [ ] No memory leaks
- [ ] Handles 100+ concurrent users

### Security Testing

- [ ] RLS policies prevent unauthorized access
- [ ] File uploads restricted by size/type
- [ ] SQL injection prevented (Supabase handles this)
- [ ] XSS attacks prevented
- [ ] CSRF tokens validated
- [ ] HTTPS enforced
- [ ] Security headers present

### Browser/Device Testing

**Desktop Browsers**:
- [ ] Chrome
- [ ] Firefox
- [ ] Safari
- [ ] Edge

**Mobile Browsers**:
- [ ] Chrome Mobile
- [ ] Safari iOS

**Mobile App**:
- [ ] Android 10+
- [ ] iOS 14+ (if available)

---

## 📊 Monitoring & Maintenance

### Setup Monitoring

**Supabase Dashboard**:
- [ ] Monitor database usage
- [ ] Check Edge Function logs
- [ ] Review auth metrics
- [ ] Track storage usage

**Error Tracking** (Optional):
- [ ] Setup Sentry account
- [ ] Integrate Sentry SDK
- [ ] Configure error alerts

**Analytics** (Optional):
- [ ] Setup PostHog/Mixpanel
- [ ] Track key user events
- [ ] Monitor conversion funnels

### Backup Strategy

- [ ] Supabase automatic daily backups enabled
- [ ] Download manual backup after major changes
- [ ] Store backups in separate location
- [ ] Test restore procedure

### Update Schedule

- [ ] Plan monthly dependency updates
- [ ] Monitor Flutter stable releases
- [ ] Track Supabase changelog
- [ ] Schedule maintenance windows

---

## 🆘 Rollback Procedure

If deployment fails:

### Web Application
1. [ ] Revert to previous Git commit
2. [ ] Redeploy from hosting dashboard
3. [ ] Verify site restored

### Database
1. [ ] Restore from Supabase backup
2. [ ] Or rollback migration:
   ```bash
   cd supabase
   supabase db reset
   ```

### Edge Functions
1. [ ] Redeploy previous version
2. [ ] Or roll back code and redeploy

---

## 📝 Documentation

- [ ] Update README.md with production URLs
- [ ] Document environment variables
- [ ] Create user guide
- [ ] Document admin procedures
- [ ] Write API documentation
- [ ] Create troubleshooting guide

---

## 🎉 Launch Checklist

Final steps before public launch:

- [ ] All above sections completed
- [ ] Stakeholders notified
- [ ] Support channels ready
- [ ] Announcement prepared
- [ ] Monitor dashboard open
- [ ] On-call team notified
- [ ] Launch! 🚀

---

## 📞 Support & Resources

**Documentation**:
- [Flutter Docs](https://docs.flutter.dev)
- [Supabase Docs](https://supabase.com/docs)
- [HOApp GitHub](https://github.com/yourorg/hoapp)

**Community**:
- [Flutter Discord](https://discord.gg/flutter)
- [Supabase Discord](https://discord.supabase.com)

**Emergency Contacts**:
- Database Admin: [contact info]
- DevOps Lead: [contact info]
- Project Manager: [contact info]

---

## 🔄 Deployment Log

Document each deployment:

### Deployment 1 - [Date]
- **Version**: 1.0.0
- **Deployed By**: [Name]
- **Changes**: Initial production deployment
- **Status**: ✅ Success
- **Issues**: None
- **Notes**: Demo data seeded for testing

### Deployment 2 - [Date]
- **Version**: 1.0.1
- **Deployed By**: [Name]
- **Changes**: Bug fixes and performance improvements
- **Status**: ✅ Success
- **Issues**: Minor CSS issue fixed
- **Notes**: Zero downtime deployment

---

**Last Updated**: March 22, 2026
**Next Review**: April 22, 2026
