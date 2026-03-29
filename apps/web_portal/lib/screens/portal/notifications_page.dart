import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:core_data/core_data.dart';
import 'package:core_ui/core_ui.dart' as shared;

class NotificationsPage extends StatelessWidget {
  const NotificationsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final slug = context.read<AppState>().activeCommunity?.slug ?? '';
    return shared.NotificationsScreen(
      key: key,
      onNavigate: (section) {
        final route = _routeForSection(section, slug);
        context.go(route);
      },
    );
  }

  static String _routeForSection(String section, String slug) {
    switch (section) {
      case 'Announcements':
        return '/$slug/announcements';
      case 'Violations':
        return '/$slug/violations';
      case 'Tickets':
        return '/$slug/tickets';
      case 'Billing & Payments':
        return '/$slug/billing';
      case 'Amenities':
        return '/$slug/amenities';
      case 'Feedback':
        return '/$slug/feedback';
      default:
        return '/$slug/announcements';
    }
  }
}
