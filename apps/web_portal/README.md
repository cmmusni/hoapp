# HOApp Web Portal

Production-ready Flutter web application for HOA/Condo community management.

## Overview

The HOApp Web Portal is a comprehensive multi-tenant SaaS platform that provides:

- **Marketing Site**: Landing page with sign-up and authentication
- **Community Creation**: Self-serve community setup with custom branding
- **Portal Dashboard**: Role-aware interface for community management

## Features

### For All Users
- 📢 **Announcements**: View and manage community updates
- 🎫 **Support Tickets**: Submit and track support requests
- 🏊 **Pool Access**: Register for pool access with PDF generation
- 💰 **Billing**: View invoices and upload payment proofs

### For Staff (Admin, Officers, Guards)
- 👥 **User Management**: Invite users with role assignment
- 🏘️ **Household Management**: Manage units and residents
- 🚨 **Violations**: Review and process violation reports
- 🏢 **Amenity Bookings**: Manage facility reservations
- ⚙️ **Settings**: Configure community branding and preferences
- 💵 **Financial Management**: Track income and expenses

### For Community Admins
- 🎨 **Branding**: Customize theme colors and  logo
- 📊 **Reports**: View financial and operational analytics
- 🔐 **Security**: Manage roles and permissions

## Tech Stack

- **Framework**: Flutter 3.x for Web
- **Router**: go_router for declarative routing
- **State Management**: Provider
- **Backend**: Supabase (Auth, Database, Storage, Functions)
- **Styling**: Material Design 3
- **Fonts**: Google Fonts (Poppins)

## Development

### Prerequisites
- Flutter SDK 3.16+
- Dart 3.2+

### Run Locally
```bash
# From project root
make run:web

# Or from this directory
flutter run -d chrome --web-port 3000
```

### Build for Production
```bash
# From project root
make deploy:prod

# Or from this directory
flutter build web --release
```

Output will be in `build/web/`

## Project Structure

```
lib/
├── main.dart                 # App entry point
├── router.dart               # Route configuration
└── screens/
    ├── landing_page.dart     # Marketing homepage
    ├── signup_page.dart      # User registration
    ├── login_page.dart       # Authentication
    ├── create_community_page.dart
    └── portal/
        ├── portal_shell.dart           # Main layout with navigation
        ├── announcements_page.dart
        ├── violations_page.dart
        ├── tickets_page.dart
        ├── amenities_page.dart
        ├── billing_page.dart
        ├── pool_access_page.dart
        ├── households_page.dart
        ├── manage_users_page.dart
        ├── settings_page.dart
        ├── expenses_page.dart
        ├── security_pass_page.dart
        └── registered_swimmers_page.dart
```

## Routing

### Public Routes
- `/` - Landing page
- `/signup` - Sign up
- `/login` - Login
- `/:community/login.html` - Community-specific login

### Protected Routes (require authentication)
- `/:community/` - Portal home
- `/:community/announcements`
- `/:community/violations`
- `/:community/tickets`
- `/:community/amenities`
- `/:community/billing`
- `/:community/pool-access`
- `/:community/households` (staff only)
- `/:community/manage-users` (staff only)
- `/:community/settings` (admin only)
- `/:community/expenses` (staff only)

## Deployment

### Netlify
```bash
netlify deploy --prod --dir=build/web
```

### Vercel
```bash
vercel --prod
```

### Cloudflare Pages
Upload `build/web` directory via dashboard or use CLI.

## Environment Variables

Required in `.env` (project root):
```
SUPABASE_URL=https://your-project.supabase.co
SUPABASE_ANON_KEY=your-anon-key
WEB_BASE_URL=https://your-domain.com
```

## Testing

```bash
# Run tests
flutter test

# Run with coverage
flutter test --coverage
```

## More Information

See the [main project README](../../README.md) for complete documentation.
