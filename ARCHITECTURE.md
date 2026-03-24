# HOApp System Architecture

## 📐 High-Level Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                         PRESENTATION LAYER                       │
├─────────────────────┬───────────────────────────────────────────┤
│   Flutter Web App   │       Flutter Mobile App                  │
│   (hoapp.com)       │       (Android APK / iOS)                 │
│                     │                                           │
│ • Marketing Site    │ • Resident-focused                        │
│ • SaaS Signup       │ • Auto community detection                │
│ • Community Portal  │ • Deep link support                       │
│ • Role-aware UI     │ • Offline-ready (future)                  │
└─────────────────────┴───────────────────────────────────────────┘
                              ↓
┌─────────────────────────────────────────────────────────────────┐
│                      SHARED PACKAGES LAYER                       │
├──────────────────┬──────────────────┬──────────────────────────┤
│   core_domain    │    core_data     │       core_ui            │
│                  │                  │                          │
│ • Models         │ • Repositories   │ • Theme                  │
│ • Entities       │ • API Clients    │ • Widgets                │
│ • Business Logic │ • State Mgmt     │ • Components             │
└──────────────────┴──────────────────┴──────────────────────────┘
                              ↓
┌─────────────────────────────────────────────────────────────────┐
│                        BACKEND LAYER                            │
├─────────────────────────────────────────────────────────────────┤
│                      Supabase Platform                          │
│                                                                 │
│ ┌─────────────┐ ┌──────────────┐ ┌────────────┐ ┌───────────┐│
│ │   Auth      │ │  PostgreSQL  │ │  Storage   │ │  Realtime ││
│ │   (JWT)     │ │  (RLS)       │ │  (Buckets) │ │  (PubSub) ││
│ └─────────────┘ └──────────────┘ └────────────┘ └───────────┘│
│                                                                 │
│ ┌─────────────────────────────────────────────────────────────┐│
│ │              Edge Functions (Deno)                          ││
│ │  • create_community  • create_invite  • accept_invite      ││
│ │  • verify_payment    • book_amenity                        ││
│ └─────────────────────────────────────────────────────────────┘│
└─────────────────────────────────────────────────────────────────┘
```

## 🏗️ Database Architecture

### Multi-Tenancy Model

```
┌──────────────────────────────────────────────────────────────┐
│                      communities                              │
│  • id (UUID)                                                 │
│  • slug (unique)                                             │
│  • settings (JSONB) → dynamic branding                       │
└────────────┬─────────────────────────────────────────────────┘
             │
             ├─► profiles (user_id, community_id) [PK]
             ├─► user_roles (role per community)
             ├─► units (household units)
             │     └─► household_members (unit ↔ user many-to-many)
             ├─► announcements
             ├─► violations
             ├─► tickets
             │     └─► messages
             ├─► amenities
             │     └─► amenity_bookings (with tstzrange exclusion)
             ├─► invoices
             │     └─► payments
             └─► pool_access_registrations
```

### Row Level Security (RLS) Strategy

Every table has `community_id` or references one.

**Helper Functions:**
- `is_community_member(community_id)` → checks `profiles` table
- `is_community_staff(community_id)` → checks for admin/officer roles
- `is_unit_member(unit_id)` → checks `household_members`

**Policy Pattern:**
```sql
-- SELECT: Members can view their community's data
CREATE POLICY "..." ON table_name FOR SELECT
  USING (is_community_member(community_id));

-- INSERT/UPDATE/DELETE: Staff only
CREATE POLICY "..." ON table_name FOR ALL
  USING (is_community_staff(community_id));
```

## 🔄 Data Flow Examples

### 1. Community Creation Flow

```
User Signup (Web)
  ↓
Login
  ↓
Create Community Form
  ↓
Edge Function: create_community
  ├─► Insert communities
  ├─► Insert profiles (creator)
  ├─► Insert user_roles (community_admin)
  ├─► Seed amenity (Pool + Function Room)
  └─► Return portal_url
  ↓
Redirect to /:slug/login.html
```

### 2. Invite & Accept Flow

```
Staff: Manage Users Page
  ↓
Fill Invite Form (email, role, unit)
  ↓
Edge Function: create_invite
  ├─► Validate staff permission
  ├─► Create unit if new_unit_no provided
  ├─► Generate secure token
  ├─► Insert invites row
  └─► Return invite_link
  ↓
Copy link → Send to invitee
  ↓
Invitee clicks link → Login/Signup
  ↓
Edge Function: accept_invite
  ├─► Validate token & expiry
  ├─► Upsert profiles
  ├─► Insert user_roles
  ├─► Insert household_members (if household invite)
  ├─► Mark invite accepted
  └─► Return community details
  ↓
Auto-navigate to community portal
```

### 3. Amenity Booking Flow

```
User: Amenities Page
  ↓
Select Date → Click Book
  ↓
Edge Function: book_amenity
  ├─► Check pool_access_registrations (required)
  ├─► Check household_members (must be in unit)
  ├─► Validate date rules (rules JSON)
  ├─► Build tstzrange
  ├─► Insert amenity_bookings
  │     └─► Conflict? → 409 (exclusion constraint)
  └─► Audit log
  ↓
Booking Confirmed
```

### 4. Payment Verification Flow

```
Resident: Upload GCash Proof
  ↓
Insert payments (status='submitted', proof_url)
  ↓
Staff: Billing Page → Review Payment
  ↓
Edge Function: verify_payment
  ├─► Validate staff permission
  ├─► Update payments (status='verified', receipt_url)
  ├─► Update invoices (status='paid')
  └─► Audit log
  ↓
Resident sees verified payment + receipt
```

## 🎨 Frontend Architecture

### Web Portal (Flutter Web)

**Routing Strategy:**
- Root: Marketing & SaaS (`/`, `/signup`, `/login`)
- Portal: `/:community/*` with role-aware menus
- ShellRoute for consistent appbar/drawer

**State Management:**
- `AppState` (activeCommunity, userRoles)
- Provider for dependency injection
- Future: Riverpod or Bloc for complex state

**Responsive Design:**
- Desktop: Side navigation + content area
- Tablet: Drawer navigation
- Mobile: Bottom navigation (future)

### Mobile App (Flutter)

**Bootstrap Flow:**
```
Splash
  ├─► Not authenticated? → Login
  └─► Authenticated?
        ├─► Load user communities
        ├─► 0 communities → "Join Your Community" dialog
        ├─► 1 community → Auto-select → Home
        └─► 2+ communities → Community Picker → Home
```

**Navigation:**
- BottomNavigationBar (Announcements, Violations, Tickets, Amenities, Profile)
- Profile tab → My Household, Pool Access, Billing
- Deep links for invite acceptance

## 🔐 Security Model

### Authentication
- Supabase Auth (JWT-based)
- Email/password signup
- Session management
- Password reset

### Authorization Levels

| Role              | Permissions                                    |
|-------------------|------------------------------------------------|
| `resident`        | View/create content, manage own household      |
| `guard`           | Read announcements, view bookings              |
| `hoa_officer`     | Manage content, verify payments, invite users  |
| `community_admin` | Full community control + settings              |
| `app_admin`       | Platform-level (via SECURITY DEFINER only)     |

### Data Access Control

**Client-side:**
- RLS enforced on all Supabase queries
- Users see only their community's data
- Staff see full context; residents see filtered views

**Server-side:**
- Edge Functions use service_role key
- Always write audit_logs for mutations
- Validate permissions before operations

### Storage Security

Bucket policies check:
1. User authentication
2. Community membership
3. Path ownership (e.g., `{community_id}/{user_id}/...`)
4. Role (staff vs. resident)

## 📦 Deployment Model

### Web
- Single Flutter Web build
- SPA hosted on Netlify/Vercel/Cloudflare
- Path-based routing (no # in URLs)
- Environment variables via build args

### Mobile
- **Android:** Single APK for all communities
- **iOS:** Ad-hoc distribution (free Apple ID for dev testing)
- Deep linking via `hoapp://` scheme
- Auto community detection post-login

### Backend
- Supabase Cloud (managed Postgres + Edge Functions)
- Migrations via Supabase CLI
- Edge Functions auto-deployed

## 🧪 Testing Strategy

### Unit Tests
- Domain models
- Repository logic
- Utility functions

### Widget Tests
- Individual screens
- Form validation
- Button interactions

### Integration Tests
- Auth flow (signup → login)
- Community creation
- Invite acceptance
- Booking workflow

### E2E Tests
- Full user journeys
- Cross-platform (web + mobile)

### Database Tests
- RLS policy verification
- Trigger functionality
- Constraint enforcement

## 🚀 Performance Considerations

### Database
- Indexes on foreign keys and frequently queried columns
- GiST index for tstzrange queries
- Materialized views for complex reports (future)

### Frontend
- Lazy loading routes
- Image optimization
- Pagination for large lists
- Caching with reactive updates

### Backend
- Edge Functions: cold start ~100ms
- Connection pooling via Supabase
- CDN for static assets

## 📊 Monitoring & Observability

### Metrics to Track
- Auth success/failure rates
- API response times
- Edge Function invocation counts
- Storage usage
- Active users per community

### Logging
- Supabase Function logs
- Client-side error boundary
- Audit logs for sensitive operations

### Alerts
- High error rates
- Failed payments
- Unusual RLS denials
- Storage quota warnings

## 🔄 Future Enhancements

### Scalability
- Read replicas for heavy queries
- Redis for caching
- Background jobs for notifications
- Webhook queue for integrations

### Features
- GraphQL API layer
- Mobile push notifications
- PWA support for web
- Multi-language support
- AI-powered search

### DevOps
- Blue-green deployments
- Feature flags
- A/B testing framework
- Automated backups to S3

---

**Architecture Principles:**

✅ **Multi-tenancy first** – Every query scoped by `community_id`  
✅ **Security by default** – RLS on all tables, least privilege  
✅ **Universal build** – One codebase, many communities  
✅ **Progressive disclosure** – Show complexity only when needed  
✅ **Mobile-first design** – Responsive and touch-friendly  
✅ **Audit everything** – Track all mutations for compliance  

This architecture supports scaling from a single community to hundreds while maintaining security isolation and operational simplicity.
