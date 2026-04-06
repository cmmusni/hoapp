# HOApp – Multi-Tenant HOA/Condo Management Platform

🏘️ **Production-Ready** Flutter + Supabase platform for HOA and condominium communities.

A complete multi-tenant SaaS solution with self-serve community creation, role-based access control, realtime features, plan-based feature gating, and comprehensive HOA management tools.

## 🏗️ Architecture

- **Frontend:** Flutter (Web + Mobile)
- **Backend:** Supabase (Auth, Postgres, Storage, Realtime, Edge Functions)
- **Multi-tenancy:** Single database with Row Level Security (RLS)
- **State Management:** Provider with ChangeNotifier (AppState)
- **Routing:** GoRouter with ShellRoute pattern
- **Deployment:** 
  - Web: hoapp.net (SPA with path routing)
  - Mobile: Android APK (sideload) + iOS (dev device testing)

## 📁 Project Structure

```
hoapp/
├── apps/
│   ├── web_portal/      # Flutter web (marketing + portal) – 45+ screens
│   └── mobile/          # Flutter mobile app
├── packages/
│   ├── core_ui/         # Shared UI components, theme, PDF service
│   ├── core_domain/     # Business logic & models (23+ models)
│   └── core_data/       # Data layer, repositories (13), services (3)
├── supabase/
│   ├── migrations/      # 60 migration files (schema, RLS, triggers, storage)
│   ├── functions/       # 18 Edge Functions (Deno)
│   └── seed.sql         # Demo data
├── .github/workflows/   # CI/CD pipelines (deploy.yml, deploy-vercel.yml)
└── Makefile             # Development commands
```

## 🚀 Quick Start

### Prerequisites

- Flutter SDK 3.16+ (Dart SDK >=3.2.0 <4.0.0)
- Supabase CLI
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
   make db-push
   ```

5. **Deploy Edge Functions:**
   ```bash
   make fn-deploy
   ```

6. **Seed demo data:**
   ```bash
   make seed
   ```

### Database Management

**Reset database** (⚠️ deletes all data):
```bash
make db-reset
```

For detailed instructions, see [DATABASE_RESET_GUIDE.md](DATABASE_RESET_GUIDE.md)

## 💻 Development

### Web Portal

```bash
make run-web
# Opens at http://localhost:3000
```

### Mobile App

```bash
make run-mobile
# Select device when prompted
```

## 📦 Production Deployment

### Quick Deploy

```bash
# Deploy backend (database + Edge Functions)
make deploy-supabase

# Build production web app
make deploy-prod
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

GitHub Actions workflows:

**`.github/workflows/deploy.yml`** (main CI/CD):
- ✓ Runs tests on every push/PR (Flutter 3.19.0)
- ✓ Generates coverage reports (Codecov)
- ✓ Builds web & mobile on push to main
- ✓ Deploys Supabase automatically
- ✓ Uploads build artifacts

**`.github/workflows/deploy-vercel.yml`** (Vercel):
- ✓ Auto-deploys to Vercel on push to master

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
   make build-apk
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

### Marketing & SaaS (Public)
- `/` – Landing page (redirects to portal if authenticated)
- `/signup` – Create HOApp account (supports `?invite=token` & `?email=base64`)
- `/login` – Login (supports `?invite=token`)
- `/features` – Feature showcase
- `/pricing` – Plan pricing display
- `/support` – Help page
- `/contact` – Contact form
- `/create-community` – Community creation wizard
- `/select-community` – Community switcher (authenticated)
- `/auth-callback`, `/auth/callback` – Email verification redirects
- `/upgrade-success` – Post-payment redirect (PayMongo)
- `/upgrade-cancelled` – Payment cancellation redirect

### Platform Admin
- `/admin` – Platform admin shell (cross-community management)

### Community Portal
- `/:community/login`, `/:community/login.html` – Community-specific login
- `/:community/signup` – Community-specific signup
- `/:community/announcements` – Community announcements
- `/:community/violations` – Violation reporting & tracking
- `/:community/tickets` – Support tickets
- `/:community/amenities` – Amenity bookings *(PlanGated)*
- `/:community/billing` – Invoice & payment management
- `/:community/expenses` – Expense tracking
- `/:community/financial-reports` – Income vs. expense charts
- `/:community/pool-access` – Pool registration *(PlanGated)*
- `/:community/registered-swimmers` – Pool swimmer roster *(PlanGated)*
- `/:community/security-pass` – Security pass requests *(PlanGated)*
- `/:community/qr-scanner` – Pass validation scanner *(PlanGated)*
- `/:community/households` – Household management (staff)
- `/:community/manage-users` – User administration (staff)
- `/:community/settings` – Community settings (community_admin)
- `/:community/feedback` – User feedback submission
- `/:community/notifications` – Notification history
- `/:community/beta-requests` – Beta access management

### Special
- `/demo` – UI demo shell with mock data

## 👥 Roles & Permissions

### Per-Community Roles
- **community_admin**: Full access to community settings and management
- **hoa_officer**: Staff operations (manage content, verify payments, invite users)
- **maintenance**: Maintenance staff operations
- **guard**: Read-only announcements + view bookings
- **resident**: Household member access, submit violations/tickets

### Platform Role
- **app_admin**: Platform-level operations (via SECURITY DEFINER functions)

## 🔑 Key Features

### Core Functionality

#### 🏢 Self-Serve Community Management
- **Community Creation**: Sign up and create communities with unique slugs
- **Custom Branding**: Community-specific themes, colors, and logos
- **Plan Tiers**: Starter (free), Professional, and Enterprise plans
- **Plan-Based Feature Gating**: PlanGate component wraps premium features
- **Multi-Tenant Architecture**: Single codebase serving all communities
- **Auto Detection**: Intelligent community selection based on user membership
- **Platform Admin Dashboard**: Cross-community management interface

#### 👥 Household & User Management
- **Unit Management**: Create and manage household units with configurable unit types
- **Unit Type Configuration**: Custom classifications with max occupancy settings
- **Member Profiles**: Support for multiple residents per unit (primary, member, child, tenant, other)
- **Flexible Membership**: Add both registered users and non-registered members
- **Invitation System**: Tokenized invite links with role assignment and expiry
- **Role-Based Access**: Community admin, HOA officer, maintenance, guard, and resident roles
- **Primary Member Management**: Primary members can manage their own household

#### 📢 Communications
- **Announcements**: Create, edit, pin, and schedule community announcements
- **Read Tracking**: Track which members have read announcements
- **File Attachments**: Support for announcement attachments and images
- **Realtime Updates**: Live notification system for instant updates

#### 🚨 Violations & Compliance
- **Anonymous Reporting**: Residents can submit violations with photo evidence
- **Privacy Protection**: Reporter identity hidden from peers, visible to staff
- **Photo Documentation**: Upload and attach violation evidence
- **Staff Workflow**: Review, categorize, and resolve violations (new → under_review → resolved)

#### 💬 Support Tickets
- **Threaded Conversations**: Chat-style ticket system with realtime messages
- **File Attachments**: Support for documents and images
- **Status Tracking**: Open, in-progress, resolved, closed states
- **Unread Indicators**: Notification system for new messages

#### 🏊 Amenity Reservations *(PlanGated)*
- **Booking Calendar**: Reserve pool and function room facilities
- **Dynamic Rules**: Configurable open/close times, pricing, max days ahead, same-day restrictions
- **Conflict Prevention**: Database-level exclusion constraints (tstzrange)
- **Access Control**: Pool Access registration requirement

#### 🏊‍♂️ Pool Access Management *(PlanGated)*
- **Registration System**: Digital waiver and swimmer registration per unit
- **Multi-Swimmer Support**: Track individual swimmer names and ages
- **Max Occupancy**: Per-unit-type capacity enforcement
- **PDF Generation**: Auto-generated registration forms
- **3-Month Lock**: Prevents frequent changes (safety requirement)
- **Document Upload**: Staff can upload signed documentation
- **Staff Registration**: Pool management for staff

#### 🔐 Security Passes *(PlanGated)*
- **Pass Types**: Configurable pass types (visitor, gate, contractor, delivery, etc.)
- **Request Workflow**: Residents request → staff approve/reject
- **QR Token Generation**: Unique tokens for pass validation
- **QR Scanner**: Built-in scanner for guards at entry points
- **Scan Logging**: Track entry/exit scans with timestamps

#### 💳 Billing & Payments
- **Invoice Management**: Create invoices with multi-category line items
- **Multiple Categories**: HOA dues, water bills, amenity fees, violations, other
- **GCash Integration**: Upload payment proof screenshots
- **Verification Workflow**: Staff review and confirmation
- **Official Receipts**: Generate and store payment receipts
- **Payment Tracking**: Complete payment history per household
- **Member Payment Access**: Residents can view their own payment history

#### 📊 Financial Management
- **Income Tracking**: Record and categorize community income (manual + invoiced)
- **Expense Tracking**: Manage operational expenses with receipt photo documentation
- **Expense Line Items**: Detailed expense categorization
- **Category Management**: Custom income and expense categories
- **Financial Reports**: Visual charts and dashboards (fl_chart)
- **Recurring Billing**: Automated invoice generation on schedule (monthly/quarterly/yearly)
- **Member Financial Reports**: Read-only financial transparency for residents

#### 💎 Plan & Subscription Management
- **Plan Tiers**: Starter, Professional, Enterprise with configurable pricing
- **PayMongo Integration**: Checkout session creation for plan upgrades
- **Payment Webhooks**: Automated payment verification via PayMongo webhook
- **Subscription Tracking**: Plan subscription status with expiry management
- **Automated Expiry**: CRON-based subscription expiry enforcement

#### 🤖 User Engagement
- **Onboarding Tour**: First-time user guided walkthrough
- **Chatbot Widget**: Floating AI assistant with FAQ/knowledge base
- **Feedback System**: Bug reports, feature requests, improvements (with image uploads)
- **Beta Access Requests**: Users can opt-in to beta features
- **User Preferences**: Personalized settings storage
- **Contact Form**: Public contact form for inquiries

#### 🔔 Notifications
- **OneSignal Integration**: Push notification delivery
- **Device Token Management**: Track notification tokens per user
- **Notification History**: View past notifications
- **Token Cleanup**: Automated stale token removal via edge function

## 🗄️ Database Schema

### 35+ tables organized by domain:

**Core Infrastructure:**
- `communities`, `buildings`, `units`, `unit_types`
- `profiles`, `user_roles`, `platform_roles`

**Invitations & Households:**
- `invites`, `household_members`

**Content & Communication:**
- `announcements`, `announcement_reads`, `announcement_attachments`
- `violations`, `tickets`, `messages`

**Amenities & Recreation:**
- `amenities`, `amenity_bookings`
- `pool_access_registrations`, `pool_registered_swimmers`

**Financial:**
- `invoices`, `invoice_line_items`, `payments`
- `expenses`, `manual_income`, `recurring_billings`
- `plan_subscriptions`, `plan_pricing`

**Security & Access:**
- `pass_types`, `security_passes`, `pass_scan_logs`

**User Engagement:**
- `feedback`, `contact_messages`, `user_preferences`, `beta_access_requests`

**System:**
- `audit_logs`, `notification_tokens`

**Storage Buckets:** violation-photos, payment-proofs, pool-access-docs, community-logos, announcement-attachments, expense-receipts, feedback-images

All tables protected by Row Level Security (RLS). 60 migration files applied (March 22 – April 2, 2026).

## 🔐 Security

- JWT-based authentication via Supabase Auth
- Row Level Security on all 35+ tables
- Community-scoped data access via helper functions (`is_community_member`, `is_community_staff`, `is_unit_member`)
- Audit logging for sensitive operations
- Storage bucket policies for file uploads (community-scoped paths)
- Service role only for Edge Functions (never client-side)
- Anonymous violation reporter privacy protection
- PKCE-based email verification flow

## ⚙️ Edge Functions (18)

| Function | Purpose |
|----------|---------|
| `create_community` | Community provisioning with slug validation |
| `create_invite` | Token-based invite generation |
| `accept_invite` | Invite acceptance with role/household assignment |
| `verify_payment` | Staff payment verification workflow |
| `book_amenity` | Amenity booking with conflict checking |
| `create_upgrade_checkout` | PayMongo checkout session creation |
| `paymongo_webhook` | Payment webhook processing |
| `provision_community` | Community initialization |
| `contact_us` | Contact form handler |
| `request_access` | Beta/feature access requests |
| `review_pass` | Security pass approval workflow |
| `validate_pass` | Security pass QR validation |
| `scan_invoice` | Invoice scanning/OCR |
| `send_notification` | Push notification delivery |
| `delete_user` | User account deletion |
| `batch_operations` | Batch CRUD (announcements, invoices, tickets, bookings) |
| `onesignal_cleanup` | Device token cleanup |
| `_shared` | Shared utilities, middleware, helpers |

## 🧪 Testing

Comprehensive test suite with unit tests, widget tests, and integration tests.

### Quick Start

```bash
# Run all tests (install deps, generate mocks, run tests)
./run_tests.sh

# Or use Makefile
make test              # Run all tests
make test-unit         # Unit tests only
make test-widget       # Widget tests only
make test-integration  # Integration tests only
make test-coverage     # Generate coverage report
make test-mocks        # Generate test mocks
```

### Test Coverage

| Component | Tests | Status |
|-----------|-------|--------|
| Storage Service | 14 | ✅ |
| Realtime Service | 9 | ✅ |
| PDF Service | 7 | ✅ |
| UI Widgets | 18 | ✅ |
| Signup Validation | 8 | ✅ |
| Repositories | 5 | ⚠️ Requires DI refactoring |
| Integration (App Flow) | 10 | ⚠️ Structural outline |
| Integration (Signup) | 14 | ⚠️ Requires test Supabase |

**Documentation**:
- **[TESTING_GUIDE.md](docs/TESTING_GUIDE.md)** - Complete testing guide
- **[TEST_SUMMARY.md](TEST_SUMMARY.md)** - Implementation summary
- **[TEST_REPORT.md](TEST_REPORT.md)** - Signup flow test report

## 📝 Demo Data

The seed script creates:
- Community: "Elevé Homes" (slug: `eleve-homes`)
  - Address: 123 Main Street, Metro Manila, Philippines
  - Brand: Primary `#215E3F`, Surface `#ECEFF1`
- Units: 401, 402, 407, 501, 502 (residential type)
- Amenity: Pool + Function Room (₱6,000/day, 08:00–22:00, 60-day advance max, no same-day)

Users must sign up via app — demo accounts created via admin signup.

Login at: `http://localhost:3000/eleve-homes/login.html`

## 🛠️ Common Tasks

### Add a new migration
```bash
cd supabase
supabase migration new your_migration_name
# Edit the generated file
make db-push
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

Default theme: Material 3 with FlexColorScheme, Primary `#2E7D32` (green), Surface `#ECEFF1` (light gray)

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

Community logos stored in `community-logos` storage bucket.

## 📊 Project Statistics

| Metric | Count |
|--------|-------|
| Database Migrations | 60 |
| Database Tables | 35+ |
| Edge Functions | 18 |
| Domain Models | 23+ |
| Repositories | 13 |
| Services | 3 |
| Web Screens | 45+ |
| Storage Buckets | 8+ |
| Test Files | 10 |
| Roles | 6 (5 community + 1 platform) |

## 🤝 Contributing

1. Create feature branch
2. Make changes
3. Run `flutter analyze`
4. Run `./run_tests.sh`
5. Submit PR

## 📄 License

Proprietary - All rights reserved

## 🆘 Support

For issues or questions, contact: support@hoapp.net

---

**Last Updated**: April 2026
