# 🚀 HOApp Deployment Quick Reference

Quick commands for deploying HOApp to production.

## Prerequisites

```bash
# Install required tools
brew install supabase/tap/supabase  # Supabase CLI
brew install flutter                # Flutter SDK

# Verify installations
flutter doctor
supabase --version
```

## 📋 Pre-Deployment

1. **Create .env file** (never commit this!):
```bash
cp .env.example .env
# Edit .env with your production credentials
```

2. **Run tests**:
```bash
./run_tests.sh
```

## 🗄️ Deploy Supabase (Backend)

### First-Time Setup

```bash
# 1. Create project at supabase.com
# 2. Link local project
cd supabase
supabase login
supabase link --project-ref YOUR_PROJECT_REF
```

### Deploy Database & Functions

```bash
# Automated deployment
./deploy_supabase.sh
```

**Or manually**:
```bash
# Push migrations
cd supabase
supabase db push

# Deploy Edge Functions
supabase functions deploy create_community --no-verify-jwt
supabase functions deploy create_invite
supabase functions deploy accept_invite
supabase functions deploy verify_payment
supabase functions deploy book_amenity

# Set secrets
supabase secrets set SUPABASE_SERVICE_ROLE_KEY=your-key
supabase secrets set WEB_BASE_URL=https://hoapp.net
```

## 🌐 Deploy Web Application

### Build Production

```bash
# Automated build (runs tests first)
./build_prod.sh
```

**Or manually**:
```bash
cd apps/web_portal
flutter build web --release \
  --dart-define=SUPABASE_URL=https://your-project.supabase.co \
  --dart-define=SUPABASE_ANON_KEY=your-anon-key
```

### Deploy to Netlify

```bash
# Install Netlify CLI
npm install -g netlify-cli

# Deploy
netlify deploy --prod --dir=apps/web_portal/build/web
```

**Or use Git integration**:
1. Connect GitHub repo to Netlify
2. Set environment variables in dashboard
3. Push to main branch → auto-deploys

### Deploy to Vercel

```bash
# Install Vercel CLI
npm install -g vercel

# Deploy
vercel --prod
```

**Or use Git integration**:
1. Import project from GitHub
2. Configure environment variables
3. Push to main → auto-deploys

### Deploy to Cloudflare Pages

Cloudflare Pages works via Git integration only:
1. Connect repository
2. Build command: `./cloudflare-build.sh`
3. Output: `apps/web_portal/build/web`
4. Push to main → auto-deploys

## 📱 Build Mobile Apps

### Android APK

**First time**: Generate keystore
```bash
keytool -genkey -v -keystore ~/hoapp-release-key.jks \
  -keyalg RSA -keysize 2048 -validity 10000 \
  -alias hoapp-release
```

**Build**:
```bash
cd apps/mobile
flutter build apk --release \
  --dart-define=SUPABASE_URL=https://your-project.supabase.co \
  --dart-define=SUPABASE_ANON_KEY=your-anon-key
  
# Output: build/app/outputs/flutter-apk/app-release.apk
```

### iOS (Development)

```bash
# Open in Xcode
open apps/mobile/ios/Runner.xcworkspace

# Then:
# 1. Select Runner target
# 2. Enable "Automatically manage signing"
# 3. Select your device
# 4. Click Run
```

## 🔄 CI/CD (GitHub Actions)

### Setup Secrets

Go to GitHub Settings → Secrets:

```
SUPABASE_URL
SUPABASE_ANON_KEY
SUPABASE_ACCESS_TOKEN
SUPABASE_PROJECT_ID
KEYSTORE_BASE64
KEYSTORE_PASSWORD
KEY_PASSWORD
KEY_ALIAS
```

### Trigger Deployment

```bash
# Push to main triggers full deployment
git push origin main

# Pull requests trigger tests only
git checkout -b feature/my-feature
git push origin feature/my-feature
# Create PR → tests run automatically
```

## ✅ Verify Deployment

### Test Checklist

```bash
# Backend
- [ ] Login to Supabase dashboard
- [ ] Check all tables created
- [ ] Verify RLS policies active
- [ ] Test Edge Functions

# Frontend
- [ ] Visit production URL
- [ ] Sign up new account
- [ ] Create community
- [ ] Test all features
- [ ] Check on mobile browsers
```

### Quick Tests

**Authentication**:
```
1. Visit /signup
2. Create account
3. Verify email (check inbox)
4. Login
```

**Community Creation**:
```
1. Login
2. Click "Create Community"
3. Enter details
4. Visit /<slug>/login.html
```

**Edge Functions**:
```bash
# Test create_community
curl -X POST https://your-project.supabase.co/functions/v1/create_community \
  -H "Authorization: Bearer YOUR_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"name":"Test Community","slug":"test-community"}'
```

## 🆘 Rollback

### Web Application

```bash
# Redeploy previous commit
git checkout <previous-commit>
./build_prod.sh
netlify deploy --prod --dir=apps/web_portal/build/web
```

### Supabase

```bash
# Rollback database
cd supabase
supabase db reset

# Redeploy functions from previous commit
git checkout <previous-commit>
./deploy_supabase.sh
```

## 📊 Monitoring

### Supabase Dashboard

- Database: Monitor query performance
- Authentication: Track user signups
- Edge Functions: View logs and errors
- Storage: Check usage and costs

### Error Logs

```bash
# View Edge Function logs
cd supabase
supabase functions logs create_community --tail
supabase functions logs create_invite --tail
```

### Database Queries

```bash
# Run SQL queries
cd supabase
supabase db query "SELECT COUNT(*) FROM communities;"
```

## 🔐 Security Notes

**Never commit**:
- `.env` files
- `key.properties` files
- Keystore files (`.jks`)
- Service role keys

**Always**:
- Use environment variables
- Enable HTTPS
- Review RLS policies
- Rotate keys periodically
- Monitor audit logs

## 📝 Environment Variables Reference

### Required for Build

```bash
SUPABASE_URL=https://your-project.supabase.co
SUPABASE_ANON_KEY=eyJhbGc...  # Public anon key (safe for client)
```

### Required for Edge Functions

```bash
SUPABASE_SERVICE_ROLE_KEY=eyJhbGc...  # Server-only, never expose
WEB_BASE_URL=https://hoapp.net        # Production domain
```

### Optional

```bash
MOBILE_SCHEME=hoapp  # Deep linking scheme
```

## 📚 Documentation

- **[DEPLOYMENT.md](DEPLOYMENT.md)** - Full deployment guide
- **[DEPLOYMENT_CHECKLIST.md](DEPLOYMENT_CHECKLIST.md)** - Complete checklist
- **[README.md](README.md)** - Project overview
- **[TESTING_GUIDE.md](docs/TESTING_GUIDE.md)** - Testing documentation

## 🎯 Common Commands

```bash
# Development
make run:web                  # Run web locally
make run:mobile              # Run mobile app
make test                    # Run all tests

# Production
./build_prod.sh              # Build web for production
./deploy_supabase.sh         # Deploy backend
make build:apk               # Build Android APK

# Maintenance
make install                 # Install all dependencies
make clean                   # Clean build artifacts
make db:push                 # Apply migrations
make fn:deploy               # Deploy Edge Functions
```

## 🚨 Troubleshooting

### Build fails

```bash
make clean
make install
./build_prod.sh
```

### Tests fail

```bash
cd packages/core_data
flutter pub run build_runner clean
flutter pub run build_runner build --delete-conflicting-outputs
flutter test
```

### Supabase connection issues

1. Check `.env` has correct values
2. Verify RLS policies
3. Check network/firewall
4. Review Edge Function logs

### Deployment to Netlify/Vercel fails

1. Check environment variables set
2. Verify build command in config
3. Check build logs for errors
4. Ensure Flutter version correct

---

**Last Updated**: March 22, 2026
