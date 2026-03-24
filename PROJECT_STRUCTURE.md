# 🏗️ Project Structure

```
hoapp/
├── apps/
│   ├── web_portal/              # Flutter Web (Marketing + SaaS + Portal)
│   │   ├── lib/
│   │   │   ├── main.dart        # Entry point
│   │   │   ├── router.dart      # GoRouter configuration
│   │   │   └── screens/
│   │   │       ├── landing_page.dart
│   │   │       ├── login_page.dart
│   │   │       ├── signup_page.dart
│   │   │       ├── create_community_page.dart
│   │   │       └── portal/      # Community portal screens
│   │   │           ├── portal_shell.dart
│   │   │           ├── announcements_page.dart
│   │   │           ├── violations_page.dart
│   │   │           ├── tickets_page.dart
│   │   │           ├── amenities_page.dart
│   │   │           ├── billing_page.dart
│   │   │           ├── pool_access_page.dart
│   │   │           ├── households_page.dart
│   │   │           ├── manage_users_page.dart
│   │   │           └── settings_page.dart
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
│   │   │       ├── household_member.dart
│   │   │       ├── announcement.dart
│   │   │       ├── violation.dart
│   │   │       ├── ticket.dart
│   │   │       ├── amenity.dart
│   │   │       ├── amenity_booking.dart
│   │   │       ├── invoice.dart
│   │   │       ├── payment.dart
│   │   │       └── pool_access.dart
│   │   └── pubspec.yaml
│   │
│   ├── core_data/                # Data layer & repositories
│   │   ├── lib/
│   │   │   ├── core_data.dart
│   │   │   ├── src/
│   │   │   │   ├── supabase_client.dart
│   │   │   │   ├── state/
│   │   │   │   │   └── app_state.dart      # Global state
│   │   │   │   └── repositories/
│   │   │   │       ├── auth_repository.dart
│   │   │   │       ├── community_repository.dart
│   │   │   │       ├── announcement_repository.dart
│   │   │   │       ├── violation_repository.dart     # TODO
│   │   │   │       ├── ticket_repository.dart        # TODO
│   │   │   │       ├── amenity_repository.dart       # TODO
│   │   │   │       ├── billing_repository.dart       # TODO
│   │   │   │       ├── pool_access_repository.dart   # TODO
│   │   │   │       └── household_repository.dart     # TODO
│   │   └── pubspec.yaml
│   │
│   └── core_ui/                  # Shared UI components & theme
│       ├── lib/
│       │   ├── core_ui.dart
│       │   └── src/
│       │       ├── theme/
│       │       │   └── app_theme.dart       # Material 3 theme
│       │       └── widgets/
│       │           ├── hoapp_button.dart
│       │           ├── hoapp_card.dart
│       │           └── loading_indicator.dart
│       └── pubspec.yaml
│
├── supabase/
│   ├── config.toml               # Supabase CLI config
│   ├── seed.sql                  # Demo data
│   ├── migrations/
│   │   ├── 20260322000001_initial_schema.sql      # Tables
│   │   ├── 20260322000002_triggers.sql            # Triggers
│   │   ├── 20260322000003_rls_policies.sql        # RLS
│   │   └── 20260322000004_storage_policies.sql    # Storage
│   └── functions/                # Edge Functions (Deno)
│       ├── create_community/
│       │   └── index.ts
│       ├── create_invite/
│       │   └── index.ts
│       ├── accept_invite/
│       │   └── index.ts
│       ├── verify_payment/
│       │   └── index.ts
│       └── book_amenity/
│           └── index.ts
│
├── .env.example                  # Environment template
├── .gitignore                    # Git ignore rules
├── Makefile                      # Development commands
├── setup.sh                      # Quick start script
│
├── README.md                     # This file
├── ARCHITECTURE.md               # System architecture
├── DEPLOYMENT.md                 # Deployment guide
└── TODO.md                       # Implementation checklist
```

## 📊 File Counts by Category

- **Database Migrations:** 4 files
- **Edge Functions:** 5 functions
- **Domain Models:** 13 models
- **Repositories:** 9 repositories (3 implemented, 6 TODO)
- **Web Screens:** 14 screens
- **Mobile Screens:** 3 screens
- **Configuration:** 8 files

**Total Lines of Code (estimated):** ~3,500 lines

## 🎯 Key Files to Know

### Backend
- `migrations/20260322000001_initial_schema.sql` – Complete database schema
- `migrations/20260322000003_rls_policies.sql` – Row Level Security
- `functions/*/index.ts` – Business logic for invites, payments, booking

### Frontend Shared
- `core_domain/lib/src/models/*.dart` – Data models (need .g.dart generation)
- `core_data/lib/src/state/app_state.dart` – Active community state
- `core_ui/lib/src/theme/app_theme.dart` – Material 3 theme builder

### Web Portal
- `web_portal/lib/router.dart` – Route definitions
- `web_portal/lib/screens/portal/portal_shell.dart` – Role-aware navigation

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
WEB_BASE_URL=https://hoapp.com
MOBILE_SCHEME=hoapp
```

### Common Commands
```bash
make install        # Install all dependencies
make db:push        # Apply database migrations
make fn:deploy      # Deploy Edge Functions
make seed           # Seed demo data
make run:web        # Run web dev server
make run:mobile     # Run mobile app
make build:web      # Build web for production
make build:apk      # Build Android APK
make clean          # Clean build artifacts
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
- [TODO.md](TODO.md) – What's left to build

---

**This structure represents Supabase + Flutter best practices for a production-ready multi-tenant SaaS application.**
