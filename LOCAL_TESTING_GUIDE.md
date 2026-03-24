# Local Testing Setup - Summary

## Status: ✅ App Compiles and Runs

The Flutter web app has been configured for local testing. While not all features are functional due to model/UI mismatches, the core authentication and navigation work for testing purposes.

## Changes Made for Local Testing

### 1. Type Aliases Created
**File:** `packages/core_domain/lib/src/models/type_aliases.dart`
- `typedef PoolAccess = PoolAccessRegistration` - UI code uses `PoolAccess`, model is `PoolAccessRegistration`
- `typedef HouseholdRole = MemberRole` - UI code uses `HouseholdRole`, model is `MemberRole`

### 2. Disabled Pages (Commented Out)
**File:** `apps/web_portal/lib/router.dart`
The following pages have been temporarily disabled due to compilation errors:
- ❌ Amenities Page
- ❌ Billing & Payments Page  
- ❌ Pool Access Page
- ❌ Households Page
- ❌ Manage Users Page

### 3. Working Pages (Available for Testing)  
- ✅ Landing Page
- ✅ Login Page
- ✅ Signup Page
- ✅ Announcements Page
- ✅ Violations Page
- ✅ Tickets Page
- ✅ Settings Page (limited functionality)

### 4. Core Fixes Applied

#### Realtime Service
**File:** `packages/core_data/lib/src/services/realtime_service.dart`
- Fixed `onPostgresChanges()` return type mismatch
- Stubbed presence tracking (returns empty list for now)
- Fixed channel subscription flow

#### Theme Configuration
**File:** `packages/core_ui/lib/src/theme/app_theme.dart`
- Changed `CardTheme` to `CardThemeData` for compatibility

#### File Upload Widget
**File:** `packages/core_ui/lib/src/widgets/file_upload_widget.dart`
- Fixed `getSupabaseClient()` calls to use `Supabase.instance.client`

#### PDF Service
**File:** `packages/core_ui/lib/src/services/pdf_service.dart`
- Commented out missing model properties (phoneNumber, emergencyContactRelationship, unitNumber, paidAt, notes)
- TODO markers added for future model enhancements

#### Settings Page
**File:** `apps/web_portal/lib/screens/portal/settings_page.dart`
- Changed `getCommunity()` to `getCommunityById()`
- Stubbed `updateCommunity()` method (not implemented in repository)
- Fixed button styling (removed unsupported parameters) 

#### Router Configuration
**File:** `apps/web_portal/lib/router.dart`
- Fixed trailing slash issue on `/:community` route

## How to Run for Local Testing

```bash
cd apps/web_portal
flutter run -d chrome --web-port 3000
```

The app will open at `http://localhost:3000`

## Test Credentials

Use the Supabase project credentials:
- **Project URL:** https://rdkpxdgxepybuswyirrs.supabase.co
- **Anon Key:** eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InJka3B4ZGd4ZXB5YnVzd3lpcnJzIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzQxNjE5NTIsImV4cCI6MjA4OTczNzk1Mn0.gU3MpxmJ2idouYZ80BbWMVsWiHmYUgR6Wc2oaUp-3pA

## Known Limitations (For Local Testing)

1. **Disabled Features:**
   - Amenity management and bookings
   - Billing and invoice management
   - Pool access registration
   - Household member management
   - User administration

2. **Stubbed Functionality:**
   - Presence tracking (realtime user status)
   - Community settings updates
   - PDF generation has limited fields

3. **Model Mismatches:**
   - Many UI screens expect richer domain models than currently exist
   - Property name differences (unitNo vs unitNumber, phone vs phoneNumber, etc.)

## Next Steps for Full Functionality

To enable all features, choose one of these approaches:

### Option A: Enhance Domain Models
Add missing properties to match UI expectations:
- Add `type`, `unitNumber`, `paidAt`, `notes` to Invoice
- Add `capacity`, `ratePerHour`, `description` to Amenity
- Add `unitNumber`, `ownerName`, `floor` to Unit
- Add `fullName`, `role`, `dateOfBirth` to HouseholdMember
- Add `referenceNumber`, `method` to Payment
- Add `bookingDate`, `startTime`, `endTime` to AmenityBooking

### Option B: Refactor UI
Update UI code to work with existing simplified models

### Option C: Hybrid Approach
Keep domain models simple, create view models/DTOs for UI that aggregate multiple domain entities

## Production Deployment Status

✅ **Backend:** Fully deployed and operational
- Database: 5 migrations applied successfully
- Edge Functions: All 5 functions deployed and working
- RLS Policies: Active and configured
- Storage: Configured with proper policies  
- Realtime: Enabled on 9 tables

⚠️ **Frontend:** Requires model alignment work before production deployment

The backend is production-ready. Frontend needs development work to align models with UI expectations before deploying to Netlify/Vercel/Cloudflare Pages.
