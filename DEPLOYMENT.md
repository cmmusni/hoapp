# HOApp Deployment Guide

## 📱 Android APK Build & Distribution

### 1. Generate Release Keystore (First Time Only)

```bash
keytool -genkey -v -keystore ~/hoapp-release-key.jks \
  -keyalg RSA -keysize 2048 -validity 10000 \
  -alias hoapp-release
```

### 2. Configure Signing

Copy the example key properties file:
```bash
cd apps/mobile/android
cp key.properties.example key.properties
```

Edit `key.properties` with your keystore details:
```properties
storePassword=YOUR_STORE_PASSWORD
keyPassword=YOUR_KEY_PASSWORD
keyAlias=hoapp-release
storeFile=/Users/yourname/hoapp-release-key.jks
```

### 3. Build Release APK

```bash
make build:apk
```

Output: `apps/mobile/build/app/outputs/flutter-apk/app-release.apk`

### 4. Distribution

**For Sideloading:**
- Share the APK file directly
- Users must enable "Install from Unknown Sources" in Android settings

**For Google Play Store:**
- Create app listing in Play Console
- Upload APK or AAB bundle
- Complete store listing and submit for review

---

## 🍎 iOS Build & Testing (Dev Device)

### Prerequisites
- macOS with Xcode installed
- Free Apple ID
- Physical iOS device with Developer Mode enabled

### Steps

1. **Open Xcode:**
   ```bash
   open apps/mobile/ios/Runner.xcworkspace
   ```

2. **Configure Signing:**
   - Select Runner target
   - Go to "Signing & Capabilities"
   - Check "Automatically manage signing"
   - Select your Apple ID team

3. **Enable Developer Mode on Device:**
   - Settings → Privacy & Security → Developer Mode → Enable
   - Restart device when prompted

4. **Run on Device:**
   - Select your device in Xcode
   - Click Run (▶️)
   - App will install on device

5. **Re-installation:**
   - Free Apple IDs require weekly re-installation
   - Apps expire after 7 days

---

## 🌐 Web Deployment

### Build

```bash
make build:web
```

Output: `apps/web_portal/build/web`

### Hosting Configuration

#### Netlify

Create `netlify.toml`:
```toml
[build]
  publish = "apps/web_portal/build/web"
  command = "cd apps/web_portal && flutter build web"

[[redirects]]
  from = "/*"
  to = "/index.html"
  status = 200
```

#### Vercel

Create `vercel.json`:
```json
{
  "buildCommand": "cd apps/web_portal && flutter build web",
  "outputDirectory": "apps/web_portal/build/web",
  "rewrites": [
    { "source": "/(.*)", "destination": "/index.html" }
  ]
}
```

#### Cloudflare Pages

1. Connect repository
2. Set build command: `cd apps/web_portal && flutter build web`
3. Set output directory: `apps/web_portal/build/web`
4. Configure "Single Page Application" mode

---

## 🗄️ Database Setup

### 1. Create Supabase Project

1. Go to [supabase.com](https://supabase.com)
2. Create new project
3. Note your project URL and anon key

### 2. Apply Migrations

```bash
cd supabase
supabase link --project-ref YOUR_PROJECT_REF
make db:push
```

### 3. Deploy Edge Functions

```bash
make fn:deploy
```

### 4. Seed Demo Data

```bash
make seed
```

---

## ⚙️ Environment Variables

### For Web & Mobile Apps

Update `.env`:
```env
SUPABASE_URL=https://your-project.supabase.co
SUPABASE_ANON_KEY=your-anon-key
```

### For Flutter Web Build

Pass as build arguments:
```bash
flutter build web \
  --dart-define=SUPABASE_URL=https://your-project.supabase.co \
  --dart-define=SUPABASE_ANON_KEY=your-anon-key
```

### For Flutter Mobile Build

```bash
flutter build apk \
  --dart-define=SUPABASE_URL=https://your-project.supabase.co \
  --dart-define=SUPABASE_ANON_KEY=your-anon-key
```

---

## 🧪 Testing

### Run All Tests

```bash
flutter test
```

### Test Specific Feature

```bash
flutter test test/auth_test.dart
```

---

## 📊 Monitoring

### Supabase Dashboard

- View database tables
- Monitor Edge Function logs
- Check auth users
- Storage usage

### Error Tracking

Consider integrating:
- Sentry for error tracking
- Firebase Crashlytics for crash reports
- PostHog for analytics

---

## 🔐 Security Checklist

- [ ] Never commit `.env` or `key.properties` files
- [ ] Use strong keystore passwords
- [ ] Store keystore file securely (backup recommended)
- [ ] Review RLS policies before production
- [ ] Enable 2FA on Supabase account
- [ ] Rotate service role keys regularly
- [ ] Monitor audit logs for suspicious activity

---

## 📝 Maintenance

### Update Dependencies

```bash
make install
```

### Database Migrations

```bash
cd supabase
supabase migration new your_migration_name
# Edit migration file
make db:push
```

### Rollback Migration

```bash
cd supabase
supabase db reset
```

---

## 🆘 Troubleshooting

### Build Errors

1. Clean build cache:
   ```bash
   make clean
   make install
   ```

2. Check Flutter doctor:
   ```bash
   flutter doctor -v
   ```

### Supabase Connection Issues

1. Verify credentials in `.env`
2. Check RLS policies
3. View Edge Function logs:
   ```bash
   cd supabase
   supabase functions logs --tail
   ```

### Deep Link Testing

**Android:**
```bash
adb shell am start -W -a android.intent.action.VIEW \
  -d "hoapp://accept-invite?token=YOUR_TOKEN" \
  com.hoapp.mobile
```

**iOS:**
```bash
xcrun simctl openurl booted "hoapp://accept-invite?token=YOUR_TOKEN"
```
