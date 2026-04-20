# Firebase Push Notifications Setup Guide

## Overview

HOApp uses Firebase Cloud Messaging (FCM) for push notifications across:
- **Android** (mobile app)
- **iOS** (mobile app)
- **Web** (web portal)

## Prerequisites

1. A Firebase project at [console.firebase.google.com](https://console.firebase.google.com)
2. FlutterFire CLI installed: `dart pub global activate flutterfire_cli`
3. Firebase CLI installed: `npm install -g firebase-tools`

---

## Step 1: Configure Firebase Project

### Option A: Use FlutterFire CLI (Recommended)

```bash
# From the mobile app directory
cd apps/mobile
flutterfire configure --project=YOUR_PROJECT_ID
```

This auto-generates `lib/firebase_options.dart` with your platform configs and downloads `google-services.json` (Android) and `GoogleService-Info.plist` (iOS).

### Option B: Manual Configuration

1. **Android**: Download `google-services.json` from Firebase Console → Project Settings → Android app → place it at `apps/mobile/android/app/google-services.json`
2. **iOS**: Download `GoogleService-Info.plist` → place it at `apps/mobile/ios/Runner/GoogleService-Info.plist`
3. **Web**: Copy the Firebase config values into:
   - `apps/mobile/lib/firebase_options.dart`
   - `apps/web_portal/lib/firebase_options.dart`
   - `apps/web_portal/web/firebase-messaging-sw.js`

---

## Step 2: Update Firebase Options Files

Replace the placeholder values in:

- `apps/mobile/lib/firebase_options.dart`
- `apps/web_portal/lib/firebase_options.dart`
- `apps/web_portal/web/firebase-messaging-sw.js`

With your actual Firebase project credentials.

---

## Step 3: iOS Setup

1. In Xcode, enable **Push Notifications** capability for the Runner target.
2. Enable **Background Modes** → check **Remote notifications** (already added to Info.plist).
3. Upload your APNs authentication key (`.p8` file) to Firebase Console → Project Settings → Cloud Messaging → iOS app.

---

## Step 4: Web Push (VAPID Key)

1. Go to Firebase Console → Project Settings → Cloud Messaging → Web configuration.
2. Generate a **Web Push certificate** (VAPID key pair).
3. Pass the VAPID public key when building the web portal:
   ```bash
   flutter build web --dart-define=FIREBASE_VAPID_KEY=YOUR_VAPID_PUBLIC_KEY
   ```

---

## Step 5: Edge Function Secrets

Set the following Supabase secrets for the `send_notification` Edge Function:

```bash
# Your Firebase project ID
supabase secrets set FIREBASE_PROJECT_ID=your-project-id

# Your Firebase service account key (entire JSON, single line)
supabase secrets set FIREBASE_SERVICE_ACCOUNT_KEY='{"type":"service_account","project_id":"...","private_key":"...","client_email":"...",...}'
```

To get the service account key:
1. Firebase Console → Project Settings → Service Accounts
2. Click **Generate new private key**
3. Copy the JSON content (minified, single line)

---

## Step 6: Deploy

```bash
# Deploy the updated Edge Function
supabase functions deploy send_notification --no-verify-jwt

# Build mobile app
cd apps/mobile
flutter build apk --flavor standard

# Build web portal
cd apps/web_portal
flutter build web --dart-define=FIREBASE_VAPID_KEY=YOUR_VAPID_KEY
```

---

## Architecture

```
┌────────────────────────────────────────┐
│  Mobile / Web App                       │
│  ┌──────────────────────────────────┐  │
│  │ Firebase Messaging SDK            │  │
│  │ → Requests permission             │  │
│  │ → Gets FCM token                  │  │
│  │ → Stores token in notification_   │  │
│  │   tokens table via Supabase       │  │
│  └──────────────────────────────────┘  │
└────────────────────────────────────────┘
                    │
                    ▼
┌────────────────────────────────────────┐
│  notification_tokens table              │
│  (user_id, token, platform)            │
└────────────────────────────────────────┘
                    │
                    ▼
┌────────────────────────────────────────┐
│  send_notification Edge Function        │
│  → Looks up FCM tokens from DB          │
│  → Gets OAuth2 token from service acct  │
│  → Sends via FCM HTTP v1 API            │
│  → Cleans up invalid tokens             │
└────────────────────────────────────────┘
                    │
                    ▼
┌────────────────────────────────────────┐
│  Firebase Cloud Messaging               │
│  → Delivers to Android/iOS/Web          │
└────────────────────────────────────────┘
```

---

## Removed Dependencies

The following OneSignal dependencies are no longer needed:
- `ONESIGNAL_APP_ID` secret (can be removed)
- `ONESIGNAL_REST_API_KEY` secret (can be removed)
- `onesignal_cleanup` Edge Function (deprecated, can be removed)

---

## Troubleshooting

- **No notifications on iOS**: Ensure APNs key is uploaded to Firebase and Push Notifications capability is enabled in Xcode.
- **No notifications on Android 13+**: The app requests runtime notification permission on first launch. Users must grant it.
- **No web push**: Ensure `firebase-messaging-sw.js` is served from the root and the VAPID key matches.
- **Token not registering**: Check that the user is authenticated before `initialize()` is called. Tokens are only stored for logged-in users.
