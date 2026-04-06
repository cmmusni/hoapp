---
description: "Apply when modifying UI, features, or behavior in the web portal or mobile app. Ensures changes are mirrored across both platforms."
applyTo: "apps/**"
---

# Cross-Platform Consistency

## Rule: All changes must be applied to both web and mobile

This is a multi-platform Flutter project. When making changes to features, UI, or behavior, **always apply the equivalent change to both platforms**:

| Web Portal | Mobile App |
|---|---|
| `apps/web_portal/` | `apps/mobile/` |

## Key file mappings

| Feature | Web | Mobile |
|---|---|---|
| Shell / Navigation | `lib/screens/portal/portal_shell.dart` | `lib/screens/home/home_screen.dart` |
| Billing | `lib/screens/portal/billing_page.dart` | `lib/screens/billing/billing_screen.dart` |
| Notifications | Uses `core_ui` shared screen | Uses `core_ui` shared screen |

## Shared packages

Code in `packages/` is shared across both platforms. Changes there automatically apply to both:

- `packages/core_data/` — repositories, API calls
- `packages/core_domain/` — models, enums
- `packages/core_ui/` — shared UI widgets and screens

Prefer putting logic in shared packages when possible to avoid duplication.

## Checklist for every change

1. Implement the change in the first platform
2. Find the equivalent file/widget in the other platform
3. Apply the same change, adapting for platform-specific patterns (e.g. `showDialog` vs `showModalBottomSheet`, `context.go()` vs `Navigator`)
4. Verify no compile errors on both platforms
