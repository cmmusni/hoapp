# 🏗️ Project Structure

```
hoapp/
├── apps/
│   ├── web_portal/              # Flutter Web (Marketing + SaaS + Portal)
│   │   ├── lib/
│   │   │   ├── main.dart        # Entry point (MultiProvider setup)
│   │   │   ├── router.dart      # GoRouter configuration (30+ routes)
│   │   │   └── screens/
│   │   │       ├── landing_page.dart
│   │   │       ├── login_page.dart         # Supports invite tokens
│   │   │       ├── signup_page.dart        # Supports invite + email pre-fill
│   │   │       ├── create_community_page.dart
│   │   │       ├── select_community_page.dart
│   │   │       ├── contact_page.dart
│   │   │       ├── features_page.dart
│   │   │       ├── pricing_page.dart
│   │   │       ├── support_page.dart
│   │   │       ├── auth_callback_page.dart
│   │   │       ├── cookie_consent_banner.dart
│   │   │       ├── upgrade_success_page.dart
│   │   │       ├── marketing_nav_bar.dart
│   │   │       └── portal/      # Community portal screens
│   │   │           ├── portal_shell.dart           # Role-aware sidebar navigation
│   │   │           ├── platform_admin_shell.dart   # Cross-community admin
│   │   │           ├── plan_gate.dart              # Plan-based feature gating
│   │   │           ├── onboarding_tour.dart        # First-time user guide
│   │   │           ├── announcements_page.dart
│   │   │           ├── violations_page.dart
│   │   │           ├── tickets_page.dart
│   │   │           ├── amenities_page.dart         # PlanGated
│   │   │           ├── billing_page.dart
│   │   │           ├── expenses_page.dart
│   │   │           ├── expense_income_chart_page.dart  # Financial reports
│   │   │           ├── pool_access_page.dart       # PlanGated
│   │   │           ├── registered_swimmers_page.dart   # PlanGated
│   │   │           ├── security_pass_page.dart     # PlanGated
│   │   │           ├── qr_scanner_page.dart        # PlanGated
│   │   │           ├── households_page.dart
│   │   │           ├── manage_users_page.dart
│   │   │           ├── settings_page.dart
│   │   │           ├── feedback_page.dart
│   │   │           ├── notifications_page.dart
│   │   │           ├── beta_requests_page.dart
│   │   │           ├── plan_pricing_page.dart
│   │   │           └── chatbot/
│   │   │               ├── chatbot_widget.dart     # Floating AI assistant
│   │   │               └── chatbot_knowledge.dart  # FAQ knowledge base
│   │   ├── test/
│   │   │   ├── widget_test.dart
│   │   │   └── signup_validation_test.dart
│   │   ├── integration_test/
│   │   │   ├── app_test.dart
│   │   │   └── signup_flow_test.dart
│   │   └── pubspec.yaml
│   │
│   └── mobile/                   # Flutter Mobile (Residents)
│       ├── lib/
│       │   ├── main.dart        # Entry point
│       │   └── screens/
│       │       ├── splash_screen.dart       # Bootstrap logic
│       │       ├── auth/
│       │       │   └── login_screen.dart
│       │       └── home/
│       │           └── home_screen.dart     # Bottom nav
│       ├── android/
│       │   ├── app/
│       │   │   ├── build.gradle            # Android build config
│       │   │   └── src/main/AndroidManifest.xml
│       │   └── key.properties.example       # Signing config
│       ├── test/
│       │   └── widget_test.dart
│       └── pubspec.yaml
│
├── packages/
│   ├── core_domain/              # Business logic & models
│   │   ├── lib/
│   │   │   ├── core_domain.dart
│   │   │   └── src/models/
│   │   │       ├── community.dart
│   │   │       ├── user_profile.dart
│   │   │       ├── user_role.dart
│   │   │       ├── unit.dart
│   │   │       ├── unit_type.dart
│   │   │       ├── household_member.dart
│   │   │       ├── announcement.dart
│   │   │       ├── violation.dart
│   │   │       ├── ticket.dart
│   │   │       ├── amenity.dart
│   │   │       ├── amenity_booking.dart
│   │   │       ├── invoice.dart
│   │   │       ├── invoice_line_item.dart
│   │   │       ├── payment.dart
│   │   │       ├── pool_access.dart
│   │   │       ├── pool_swimmer.dart
│   │   │       ├── expense.dart
│   │   │       ├── manual_income.dart
│   │   │       ├── recurring_billing.dart
│   │   │       ├── security_pass.dart
│   │   │       ├── or_template_config.dart
│   │   │       └── type_aliases.dart
│   │   └── pubspec.yaml
│   │
│   ├── core_data/                # Data layer & repositories
│   │   ├── lib/
│   │   │   ├── core_data.dart
│   │   │   ├── src/
│   │   │   │   ├── supabase_client.dart
│   │   │   │   ├── state/
│   │   │   │   │   └── app_state.dart      # Global state
│   │   │   │   ├── repositories/
│   │   │   │   │   ├── auth_repository.dart
│   │   │   │   │   ├── community_repository.dart
│   │   │   │   │   ├── announcement_repository.dart
│   │   │   │   │   ├── violation_repository.dart
│   │   │   │   │   ├── ticket_repository.dart
│   │   │   │   │   ├── amenity_repository.dart
│   │   │   │   │   ├── billing_repository.dart
│   │   │   │   │   ├── pool_access_repository.dart
│   │   │   │   │   ├── household_repository.dart
│   │   │   │   │   ├── expense_repository.dart
│   │   │   │   │   ├── income_repository.dart
│   │   │   │   │   ├── recurring_billing_repository.dart
│   │   │   │   │   └── security_pass_repository.dart
│   │   │   │   └── services/
│   │   │   │       ├── notification_service.dart   # OneSignal
│   │   │   │       ├── realtime_service.dart       # Supabase Realtime
│   │   │   │       └── storage_service.dart        # File uploads
│   │   ├── test/
│   │   │   ├── helpers/test_helpers.dart    # 13 mock factories
│   │   │   ├── repositories/
│   │   │   │   └── announcement_repository_test.dart
│   │   │   └── services/
│   │   │       ├── storage_service_test.dart
│   │   │       └── realtime_service_test.dart
│   │   └── pubspec.yaml
│   │
│   └── core_ui/                  # Shared UI components & theme
│       ├── lib/
│       │   ├── core_ui.dart
│       │   └── src/
│       │       ├── theme/
│       │       │   └── app_theme.dart       # Material 3 + FlexColorScheme
│       │       ├── services/
│       │       │   └── pdf_service.dart     # PDF generation
│       │       └── widgets/
│       │           ├── hoapp_button.dart
│       │           ├── hoapp_card.dart
│       │           ├── loading_indicator.dart
│       │           └── file_upload_widget.dart
│       ├── test/
│       │   ├── services/pdf_service_test.dart
│       │   └── widgets/widgets_test.dart
│       └── pubspec.yaml
│
├── supabase/
│   ├── config.toml               # Supabase CLI config
│   ├── seed.sql                  # Demo data (Elevé Homes)
│   ├── reset_schema.sql          # Schema reset script
│   ├── migrations/               # 62 migration files (Mar 22 – Apr 2, 2026)
│   │   ├── 20260322000001_initial_schema.sql      # Core tables
│   │   ├── 20260322000002_triggers.sql            # Triggers
│   │   ├── 20260322000003_rls_policies.sql        # RLS
│   │   ├── 20260322000004_storage_policies.sql    # Storage
│   │   ├── 20260322000005_enable_realtime.sql     # Realtime
│   │   ├── ...                                     # 55 more migrations
│   │   └── 20260406000002_portal_access_log.sql         # Latest
│   ├── functions/                # 21 Edge Functions (Deno)
│   │   ├── _shared/              # Shared utilities & middleware
│   │   ├── create_community/
│   │   ├── create_invite/
│   │   ├── accept_invite/
│   │   ├── verify_payment/
│   │   ├── book_amenity/
│   │   ├── create_upgrade_checkout/
│   │   ├── paymongo_webhook/
│   │   ├── provision_community/
│   │   ├── contact_us/
│   │   ├── request_access/
│   │   ├── review_pass/
│   │   ├── validate_pass/
│   │   ├── scan_invoice/
│   │   ├── send_notification/
│   │   ├── delete_user/
│   │   ├── batch_operations/
│   │   └── onesignal_cleanup/
│   ├── manual-scripts/           # Utility SQL scripts
│   └── snippets/                 # SQL snippets
│
├── .env.example                  # Environment template
├── .gitignore                    # Git ignore rules
├── Makefile                      # Development commands (18 targets)
├── setup.sh                      # Quick start script
├── build_prod.sh                 # Production build script
├── deploy_supabase.sh            # Supabase deployment script
├── run_tests.sh                  # Test runner script
├── cloudflare-build.sh           # Cloudflare Pages build
├── vercel_install.sh             # Vercel install helper
├── netlify.toml                  # Netlify config
├── vercel.json                   # Vercel config
├── .github/workflows/
│   ├── deploy.yml                # Main CI/CD pipeline
│   └── deploy-vercel.yml         # Vercel auto-deploy
│
├── README.md                     # Project overview
├── ARCHITECTURE.md               # System architecture
├── PROJECT_STRUCTURE.md          # This file
├── DEPLOYMENT.md                 # Deployment guide
├── DEPLOYMENT_READY.md           # Quick deployment reference
├── DEPLOYMENT_CHECKLIST.md       # Step-by-step checklist
├── DEPLOY_QUICK_REF.md           # Command quick reference
├── DELIVERABLES.md               # Project deliverables
├── TODO.md                       # Future enhancements
├── TEST_REPORT.md                # Signup test report
├── TEST_SUMMARY.md               # Test implementation summary
├── DATABASE_RESET_GUIDE.md       # Database reset guide
├── EMAIL_CONFIRMATION_SETUP.md   # Email verification setup
├── LOCAL_TESTING_GUIDE.md        # Local testing guide
├── MIGRATION_INSTRUCTIONS.md     # Migration instructions
└── docs/
    ├── ADVANCED_FEATURES.md
    ├── IMPLEMENTATION_SUMMARY_ADVANCED_FEATURES.md
    ├── QUICK_REFERENCE_ADVANCED_FEATURES.md
    └── TESTING_GUIDE.md
```
└── TODO.md                       # Future enhancements roadmap
```

## 📊 File Counts by Category

- **Database Migrations:** 62 files
- **Edge Functions:** 21 functions
- **Domain Models:** 23+ models (with generated .g.dart files)
- **Repositories:** 13 repositories (all fully implemented)
- **Services:** 3 services (notification, realtime, storage)
- **Web Screens:** 45+ screens
- **Mobile Screens:** 3 screens
- **Test Files:** 10 files
- **Storage Buckets:** 8+
- **Configuration:** 12+ files

**Total Lines of Code (estimated):** ~15,000+ lines

## 🎯 Key Files to Know

### Backend
- `migrations/20260322000001_initial_schema.sql` – Core database schema
- `migrations/20260322000003_rls_policies.sql` – Row Level Security
- `migrations/20260402000003_subscription_expiry_cron.sql` – Latest migration
- `functions/*/index.ts` – Edge Functions (invites, payments, booking, passes, etc.)

### Frontend Shared
- `core_domain/lib/src/models/*.dart` – Data models (with .g.dart generation)
- `core_data/lib/src/state/app_state.dart` – Active community state
- `core_data/lib/src/repositories/*.dart` – 13 repository classes
- `core_data/lib/src/services/*.dart` – Notification, realtime, storage services
- `core_ui/lib/src/theme/app_theme.dart` – Material 3 + FlexColorScheme theme
- `core_ui/lib/src/services/pdf_service.dart` – PDF generation
- `core_ui/lib/src/widgets/file_upload_widget.dart` – Upload components

### Web Portal
- `web_portal/lib/router.dart` – Route definitions (30+ routes with GoRouter)
- `web_portal/lib/screens/portal/portal_shell.dart` – Role-aware sidebar navigation
- `web_portal/lib/screens/portal/plan_gate.dart` – Plan-based feature gating
- `web_portal/lib/screens/portal/platform_admin_shell.dart` – Platform admin UI

### Mobile
- `mobile/lib/screens/splash_screen.dart` – Bootstrap & community detection
- `mobile/lib/screens/home/home_screen.dart` – Bottom navigation

## 🔄 Data Flow Diagram

```
┌────────────┐
│   User     │
└──────┬─────┘
       │
       ↓
┌────────────────────────────────────────┐
│  Flutter App (Web or Mobile)            │
│  ┌──────────────────────────────────┐  │
│  │  Screens & Widgets (UI Layer)    │  │
│  └───────────────┬──────────────────┘  │
│                  ↓                      │
│  ┌──────────────────────────────────┐  │
│  │  Repositories (Data Layer)       │  │
│  └───────────────┬──────────────────┘  │
└──────────────────┼──────────────────────┘
                   │
                   ↓
┌──────────────────────────────────────────┐
│  Supabase Client (HTTP/WebSocket)        │
│  • Auth (JWT)                            │
│  • Database queries (auto-RLS)           │
│  • Storage uploads                       │
│  • Edge Function calls                   │
└───────────────┬──────────────────────────┘
                │
                ↓
┌──────────────────────────────────────────┐
│  Supabase Platform                       │
│  ┌────────────┐  ┌────────────────────┐ │
│  │ Postgres   │  │  Edge Functions    │ │
│  │ (RLS)      │◄─┤  (Service Role)    │ │
│  └────────────┘  └────────────────────┘ │
│  ┌────────────┐  ┌────────────────────┐ │
│  │ Storage    │  │  Realtime (future) │ │
│  │ (Policies) │  │  (PubSub)          │ │
│  └────────────┘  └────────────────────┘ │
└──────────────────────────────────────────┘
```

## 🎨 Theme Customization Flow

```dart
// 1. Community stores brand in settings JSONB
{
  "brand": {
    "primary": "#2E7D32",
    "surface": "#ECEFF1"
  },
  "logo_url": "https://..."
}

// 2. AppState loads activeCommunity
appState.setActiveCommunityData(community);

// 3. Theme rebuilds dynamically
AppTheme.buildTheme(
  primaryColor: Color(int.parse(community.primaryColor.substring(1), radix: 16)),
  surfaceColor: Color(int.parse(community.surfaceColor.substring(1), radix: 16)),
)
```

## 🔐 Security Boundary Layers

```
┌─────────────────────────────────────────┐
│  Client (Web/Mobile)                    │
│  • Never trust user input               │
│  • Use anon_key only                    │
└──────────────┬──────────────────────────┘
               │
               ↓ (All queries filtered by RLS)
┌─────────────────────────────────────────┐
│  Row Level Security (RLS)               │
│  • is_community_member(community_id)    │
│  • is_community_staff(community_id)     │
│  • is_unit_member(unit_id)              │
└──────────────┬──────────────────────────┘
               │
               ↓ (Validated queries only)
┌─────────────────────────────────────────┐
│  PostgreSQL Database                    │
│  • Multi-tenant with community_id       │
│  • Constraints, triggers, indexes       │
└─────────────────────────────────────────┘

┌─────────────────────────────────────────┐
│  Edge Functions (service_role key)      │
│  • SECURITY DEFINER functions           │
│  • Explicit permission checks           │
│  • Audit logging required               │
└─────────────────────────────────────────┘
```

## ⚡ Quick Reference

### Environment Variables
```bash
SUPABASE_URL=https://xxxxx.supabase.co
SUPABASE_ANON_KEY=eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...
SUPABASE_SERVICE_ROLE_KEY=eyJhbGciOiJIUz... # Edge Functions only
WEB_BASE_URL=https://hoapp.net
MOBILE_SCHEME=hoapp
```

### Common Commands
```bash
make install        # Install all dependencies
make db-push        # Apply database migrations
make fn-deploy      # Deploy Edge Functions
make seed           # Seed demo data
make run-web        # Run web dev server
make run-mobile     # Run mobile app
make build-web      # Build web for production
make build-apk      # Build Android APK
make test           # Run all tests
make test-mocks     # Generate test mocks
make clean          # Clean build artifacts
make deploy-supabase  # Full backend deployment
make deploy-prod    # Production web deployment
```

### Database Connections
```bash
# Local development
postgres://postgres:postgres@localhost:54322/postgres

# Production (from Supabase dashboard)
postgres://postgres:[PASSWORD]@db.[PROJECT-REF].supabase.co:5432/postgres
```

### Useful SQL Queries
```sql
-- View all communities
SELECT id, name, slug, created_at FROM communities;

-- View users in a community
SELECT p.user_id, p.full_name, ur.role 
FROM profiles p
JOIN user_roles ur ON ur.user_id = p.user_id AND ur.community_id = p.community_id
WHERE p.community_id = 'YOUR_COMMUNITY_ID';

-- Check RLS policies
SELECT * FROM pg_policies WHERE tablename = 'announcements';

-- View audit logs
SELECT * FROM audit_logs ORDER BY created_at DESC LIMIT 50;
```

## 🧩 Extension Points

Want to add a new feature? Follow this pattern:

1. **Add database table** in new migration
2. **Create domain model** in `core_domain/lib/src/models/`
3. **Implement repository** in `core_data/lib/src/repositories/`
4. **Add RLS policies** for security
5. **Create UI screens** in web/mobile apps
6. **(Optional) Add Edge Function** for complex logic

## 📞 Support

For questions or issues, refer to:
- [README.md](README.md) – Overview
- [ARCHITECTURE.md](ARCHITECTURE.md) – System design
- [DEPLOYMENT.md](DEPLOYMENT.md) – How to deploy
- [TODO.md](TODO.md) – Future enhancements roadmap
- [docs/TESTING_GUIDE.md](docs/TESTING_GUIDE.md) – Testing guide
- [docs/ADVANCED_FEATURES.md](docs/ADVANCED_FEATURES.md) – PDF, uploads, realtime

---

**Last Updated**: April 2026

**This structure represents Supabase + Flutter best practices for a production-ready multi-tenant SaaS application.**
