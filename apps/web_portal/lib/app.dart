import 'package:flutter/material.dart';
import 'core/widgets/app_scaffold.dart';
import 'features/units/view/units_page.dart';
import 'features/households/view/households_page.dart';
import 'features/amenities/view/amenities_page.dart';
import 'features/billing/view/billing_page.dart';

/// Demo app shell for the scaffolded feature pages.
/// Access via /demo in the main router.
class DemoShell extends StatefulWidget {
  const DemoShell({super.key});

  @override
  State<DemoShell> createState() => _DemoShellState();
}

class _DemoShellState extends State<DemoShell> {
  int _selectedIndex = 0;

  static const _titles = ['Units', 'Households', 'Amenities', 'Billing'];

  static const _pages = <Widget>[
    UnitsPage(),
    HouseholdsPage(),
    AmenitiesPage(),
    BillingPage(),
  ];

  static const _destinations = <NavigationDestination>[
    NavigationDestination(
      icon: Icon(Icons.apartment_outlined),
      selectedIcon: Icon(Icons.apartment),
      label: 'Units',
    ),
    NavigationDestination(
      icon: Icon(Icons.family_restroom_outlined),
      selectedIcon: Icon(Icons.family_restroom),
      label: 'Households',
    ),
    NavigationDestination(
      icon: Icon(Icons.pool_outlined),
      selectedIcon: Icon(Icons.pool),
      label: 'Amenities',
    ),
    NavigationDestination(
      icon: Icon(Icons.receipt_long_outlined),
      selectedIcon: Icon(Icons.receipt_long),
      label: 'Billing',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      selectedIndex: _selectedIndex,
      onDestinationSelected: (i) => setState(() => _selectedIndex = i),
      title: _titles[_selectedIndex],
      body: _pages[_selectedIndex],
      destinations: _destinations,
    );
  }
}
