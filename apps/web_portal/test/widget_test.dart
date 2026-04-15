// Web portal smoke test
//
// Note: The main app entry point uses dart:html and dart:js which are not
// available in the VM test environment. Widget tests that depend on the full
// app should use `flutter test --platform chrome` or integration tests.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('MaterialApp can be created', (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Center(child: Text('HOApp Web Portal')),
        ),
      ),
    );

    expect(find.text('HOApp Web Portal'), findsOneWidget);
  });
}
