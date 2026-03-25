# HOApp — UI Scaffolding (Demo)

## Getting Started

```bash
cd apps/web_portal
flutter pub get
flutter run -d chrome          # web
flutter run                    # mobile (iOS/Android)
```

Navigate to **/demo** in the browser to see the scaffolded feature pages:
- `http://localhost:3000/demo`

## Library Rationale

| Library | Purpose | Link |
|---------|---------|------|
| **flex_color_scheme** | Material 3 theming with green brand + dark mode | [pub.dev](https://pub.dev/packages/flex_color_scheme) |
| **responsive_framework** | Breakpoint-aware layout switching (mobile/tablet/desktop) | [pub.dev](https://pub.dev/packages/responsive_framework) |
| **data_table_2** | Sticky header, fixed columns, sortable data tables | [pub.dev](https://pub.dev/packages/data_table_2) |
| **table_calendar** | Month/week/2-week calendar with range selection | [pub.dev](https://pub.dev/packages/table_calendar) |
| **fl_chart** | Line/bar charts for billing trends | [pub.dev](https://pub.dev/packages/fl_chart) |
| **flutter_form_builder** | Declarative forms with validation & conditional fields | [pub.dev](https://pub.dev/packages/flutter_form_builder) |

## Feature Pages

### Units (`/demo` → Units tab)
- Admin grid with search, status filter, and "Add Unit" button
- **DataTable2** with sticky header, sortable columns, status badges
- Row actions: View, Edit, Archive (demo snackbars)

### Households (`/demo` → Households tab)
- Current member roster with role badges
- **FormBuilder** form for adding members (name, relationship, email, phone, role)
- Conditional field: Move-in Date appears for tenants
- Validation + invite payload printed to console

### Amenities (`/demo` → Amenities tab)
- **table_calendar** with month/2-week/week format toggle
- Day and range selection with event list below
- "Request Reservation" dialog with FormBuilder (amenity, date, time slot, notes)

### Billing (`/demo` → Billing tab)
- Compact **DataTable2** invoice table with status badges and download action
- **fl_chart** line chart showing 12-month charges vs. paid trend
- Responsive: chart above table on mobile, side-by-side on desktop

## Responsive Breakpoints

| Breakpoint | Width | Layout |
|-----------|-------|--------|
| MOBILE | 0–450px | NavigationBar (bottom), stacked layouts |
| TABLET | 451–800px | NavigationBar (bottom), mixed layouts |
| DESKTOP | 801–1920px | NavigationRail (side), wider tables, side-by-side panels |
| 4K | 1921px+ | Same as desktop, more breathing room |

## Dark Mode

Dark mode is supported via `HOAppTheme.darkTheme`. Change `themeMode` in `main.dart`:

```dart
themeMode: ThemeMode.dark,   // or ThemeMode.system
```

## Plugging in Firebase / Supabase Later

The demo pages use mock data in `features/*/data/` files. To connect real data:

1. Replace mock lists with repository calls (e.g., `context.read<UnitRepository>().getUnits()`)
2. Swap `Future.delayed` loading with actual async fetches
3. Replace `debugPrint` payloads with repository `.create()` / `.update()` calls
4. The existing portal pages under `screens/portal/` already use Supabase — the demo feature pages are a UI reference
