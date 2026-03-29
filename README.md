# HOApp – Multi-Tenant HOA/Condo Management Platform

🏘️ **Production-Ready** Flutter + Supabase platform for HOA and condominium communities.

A complete multi-tenant SaaS solution with self-serve community creation, role-based access control, realtime features, and comprehensive HOA management tools.

## 🏗️ Architecture

- **Frontend:** Flutter (Web + Mobile)
- **Backend:** Supabase (Auth, Postgres, Storage, Realtime, Edge Functions)
- **Multi-tenancy:** Single database with Row Level Security (RLS)
- **Deployment:** 
  - Web: hoapp.net (SPA with path routing)
  - Mobile: Android APK (sideload) + iOS (dev device testing)

## 📁 Project Structure

```
hoapp/
├── apps/
│   ├── web_portal/      # Flutter web (marketing + portal)
│   └── mobile/          # Flutter mobile app
├── packages/
│   ├── core_ui/         # Shared UI components
│   ├── core_domain/     # Business logic & models
│   └── core_data/       # Data layer & API clients
├── supabase/
│   ├── migrations/      # Database schema & RLS
│   ├── functions/       # Edge Functions (Deno)
│   └── seed.sql         # Demo data
└── Makefile             # Development commands
```

## 🚀 Quick Start

### Prerequisites

- Flutter SDK 3.16+
- Supabase CLI
- Dart 3.2+
- Android Studio (for APK builds)
- Xcode (for iOS testing, macOS only)

### Setup

1. **Clone and install dependencies:**
   ```bash
   git clone <repo-url>
   cd hoapp
   make install
   ```

2. **Configure environment:**
   ```bash
   cp .env.example .env
   # Edit .env with your Supabase credentials
   ```

3. **Initialize Supabase:**
   ```bash
   cd supabase
   supabase init
   supabase link --project-ref your-project-ref
   ```

4. **Apply migrations:**
   ```bash
   make db:push
   ```

5. **Deploy Edge Functions:**
   ```bash
   make fn:deploy
   ```

6. **Seed demo data:**
   ```bash
   make seed
   ```

### Database Management

**Reset database** (⚠️ deletes all data):
```bash
make db:reset
```

For detailed instructions, see [DATABASE_RESET_GUIDE.md](DATABASE_RESET_GUIDE.md)

## 💻 Development

### Web Portal

```bash
make run:web
# Opens at http://localhost:3000
```

### Mobile App

```bash
make run:mobile
# Select device when prompted
```

## 📦 Production Deployment

### Quick Deploy

```bash
# Deploy backend (database + Edge Functions)
make deploy:supabase

# Build production web app
make deploy:prod
```

### Automated Scripts

- **`./build_prod.sh`** - Build web app with tests
- **`./deploy_supabase.sh`** - Deploy database & functions
- **`./run_tests.sh`** - Run full test suite

### Hosting Platforms

Production configurations included for:
- **Netlify**: `netlify.toml` ✓
- **Vercel**: `vercel.json` ✓
- **Cloudflare Pages**: `cloudflare-build.sh` ✓

### CI/CD Pipeline

GitHub Actions workflow (`.github/workflows/deploy.yml`):
- ✓ Runs tests on every push/PR
- ✓ Builds web & mobile on main
- ✓ Deploys Supabase automatically
- ✓ Uploads build artifacts

### Documentation

- **[DEPLOYMENT_READY.md](DEPLOYMENT_READY.md)** - 🚀 START HERE
- **[DEPLOYMENT_CHECKLIST.md](DEPLOYMENT_CHECKLIST.md)** - Complete checklist
- **[DEPLOY_QUICK_REF.md](DEPLOY_QUICK_REF.md)** - Quick command reference
- **[DEPLOYMENT.md](DEPLOYMENT.md)** - Full deployment guide

### Android APK

1. **Generate keystore (first time only):**
   ```bash
   keytool -genkey -v -keystore ~/hoapp-release-key.jks \
     -keyalg RSA -keysize 2048 -validity 10000 \
     -alias hoapp-release
   ```

2. **Configure signing** (`apps/mobile/android/key.properties`):
   ```properties
   storePassword=your-store-password
   keyPassword=your-key-password
   keyAlias=hoapp-release
   storeFile=/Users/yourname/hoapp-release-key.jks
   ```

3. **Build:**
   ```bash
   make build:apk
   # Output: apps/mobile/build/app/outputs/flutter-apk/app-release.apk
   ```

### iOS (Dev Device Testing)

1. Open `apps/mobile/ios/Runner.xcworkspace` in Xcode
2. Select your device
3. Enable "Automatically manage signing"
4. Use free Apple ID
5. Enable Developer Mode on device (Settings → Privacy & Security)
6. Run from Xcode
7. Re-install weekly (free account limit)

## 🌐 URL Structure

### Marketing & SaaS
- `/` – Landing page
- `/signup` – Create HOApp account
- `/login` – Login to account

### Community Portal
- `/:community/login.html` – Community-specific login
- `/:community/` – Portal home (role-aware)
- `/:community/announcements`
- `/:community/violations`
- `/:community/tickets`
- `/:community/amenities`
- `/:community/billing`
- `/:community/pool-access`
- `/:community/households` (staff)
- `/:community/manage-users` (staff)
- `/:community/settings` (community_admin)

## 👥 Roles & Permissions

### Per-Community Roles
- **community_admin**: Full access to community settings
- **hoa_officer**: Staff operations (no global settings)
- **guard**: Read-only + basic operations
- **resident**: Household member access

### Platform Role
- **app_admin**: Platform-level operations (via SECURITY DEFINER functions)

## 🔑 Key Features

### Core Functionality

#### 🏢 Self-Serve Community Management
- **Community Creation**: Sign up and create communities with unique slugs
- **Custom Branding**: Community-specific themes and settings
- **Multi-Tenant Architecture**: Single codebase serving all communities
- **Auto Detection**: Intelligent community selection based on user membership

#### 👥 Household & User Management
- **Unit Management**: Create and manage household units
- **Member Profiles**: Support for multiple residents per unit
- **Flexible Membership**: Add both registered users and non-registered members
- **Invitation System**: Tokenized invite links with role assignment and expiry
- **Role-Based Access**: Community admin, HOA officer, guard, and resident roles

#### 📢 Communications
- **Announcements**: Create, edit, pin, and schedule community announcements
- **Realtime Updates**: Live notification system for instant updates
- **Rich Content**: Support for formatted text and attachments

#### 🚨 Violations & Compliance
- **Anonymous Reporting**: Residents can submit violations with photo evidence
- **Privacy Protection**: Reporter identity hidden from peers, visible to staff
- **Photo Documentation**: Upload and attach violation evidence
- **Staff Workflow**: Review, categorize, and resolve violations

#### 💬 Support Tickets
- **Threaded Conversations**: Chat-style ticket system
- **File Attachments**: Support for documents and images
- **Status Tracking**: Open, in-progress, resolved, closed states
- **Unread Indicators**: Notification system for new messages

#### 🏊 Amenity Reservations
- **Booking Calendar**: Reserve pool and function room facilities
- **Conflict Prevention**: Database-level exclusion constraints
- **Payment Integration**: ₱8,000/day function room fee
- **Access Control**: Pool Access registration requirement

#### 🏊‍♂️ Pool Access Management
- **Registration System**: Digital waiver and swimmer registration
- **PDF Generation**: Auto-generated registration forms
- **3-Month Lock**: Prevents frequent changes (safety requirement)
- **Document Upload**: Staff can upload signed documentation

#### 💳 Billing & Payments
- **Invoice Management**: Create invoices for dues, amenities, and other fees
- **Multiple Categories**: HOA dues, water bills, amenity fees, violations, other
- **GCash Integration**: Upload payment proof screenshots
- **Verification Workflow**: Staff review and confirmation
- **Official Receipts**: Generate and store payment receipts
- **Payment Tracking**: Complete payment history per household

#### 📊 Financial Management
- **Income Tracking**: Record and categorize community income
- **Expense Tracking**: Manage operational expenses with photo documentation
- **Category Management**: Custom income and expense categories
- **Financial Reports**: Visual charts and reports for transparency
- **Recurring Billing**: Set up automatic monthly billing for dues

## 🗄️ Database Schema

Key tables:
- `communities`, `buildings`, `units`
- `profiles`, `user_roles`, `platform_roles`
- `invites`, `household_members`
- `announcements`, `violations`, `tickets`, `messages`
- `amenities`, `amenity_bookings`
- `invoices`, `payments`
- `pool_access_registrations`
- `audit_logs`, `notification_tokens`

All tables protected by Row Level Security (RLS).

## 🔐 Security

- JWT-based authentication via Supabase Auth
- Row Level Security on all tables
- Community-scoped data access
- Audit logging for sensitive operations
- Storage bucket policies for file uploads
- Service role only for Edge Functions (never client-side)

## 🧪 Testing

Comprehensive test suite with unit tests, widget tests, and integration tests.

### Quick Start

```bash
# Run all tests (install deps, generate mocks, run tests)
./run_tests.sh

# Or use Makefile
make test              # Run all tests
make test:unit         # Unit tests only
make test:widget       # Widget tests only
make test:integration  # Integration tests only
make test:coverage     # Generate coverage report
```

### Test Coverage

| Component | Tests | Status |
|-----------|-------|--------|
| Storage Service | 14 | ✅ |
| Realtime Service | 9 | ✅ |
| PDF Service | 7 | ✅ |
| UI Widgets | 18 | ✅ |
| Repositories | 5 | ⚠️ |
| Integration | 10 | ⚠️ |

**Documentation**:
- **[TESTING_GUIDE.md](docs/TESTING_GUIDE.md)** - Complete testing guide
- **[TEST_SUMMARY.md](TEST_SUMMARY.md)** - Implementation summary

## 📝 Demo Data

The seed script creates:
- Community: "Elevé Homes" (slug: `eleve-homes`)
- Units: 401, 402, 407
- Users: 1 admin, 1 officer, 1 resident (Unit 407)
- Amenity: Pool + Function Room
- Sample invoices and announcements

Login at: `http://localhost:3000/eleve-homes/login.html`

## 🛠️ Common Tasks

### Add a new migration
```bash
cd supabase
supabase migration new your_migration_name
# Edit the generated file
make db:push
```

### Deploy a single function
```bash
cd supabase
supabase functions deploy function_name
```

### View logs
```bash
cd supabase
supabase functions logs function_name --tail
```

## 📱 Deep Links

Mobile app supports invite deep links:
- Custom scheme: `hoapp://accept-invite?token=...`
- Web fallback: `hoapp.net/:community/login.html?invite=...`

## 🎨 Branding

Default theme: Material 3, Primary `#2E7D32` (green), Surface `#ECEFF1` (light gray)

Dynamic per-community branding via `communities.settings`:
```json
{
  "brand": {
    "primary": "#2E7D32",
    "surface": "#ECEFF1"
  },
  "logo_url": "https://..."
}
```

## 🤝 Contributing

1. Create feature branch
2. Make changes
3. Run `flutter analyze`
4. Submit PR

## 📄 License

Proprietary - All rights reserved

## 🆘 Support

For issues or questions, contact: support@hoapp.net
