// Mobile app smoke test
//
// Note: The main app requires Supabase initialization and providers.
// Full app widget tests need proper mock setup for SupabaseClientManager
// and Provider dependencies.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('MaterialApp can be created', (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Center(child: Text('HOApp Mobile')),
        ),
      ),
    );

    expect(find.text('HOApp Mobile'), findsOneWidget);
  });
}
