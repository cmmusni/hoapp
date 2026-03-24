import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:core_ui/core_ui.dart';

void main() {
  group('HOAppButton Widget Tests', () {
    testWidgets('renders button with label', (WidgetTester tester) async {
      // Arrange
      const label = 'Test Button';

      // Act
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: HOAppButton(
              label: label,
              onPressed: () {},
            ),
          ),
        ),
      );

      // Assert
      expect(find.text(label), findsOneWidget);
      expect(find.byType(ElevatedButton), findsOneWidget);
    });

    testWidgets('button is disabled when onPressed is null', (WidgetTester tester) async {
      // Arrange & Act
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: HOAppButton(
              label: 'Disabled Button',
              onPressed: null,
            ),
          ),
        ),
      );

      // Assert
      final button = tester.widget<ElevatedButton>(find.byType(ElevatedButton));
      expect(button.onPressed, isNull);
    });

    testWidgets('shows loading indicator when isLoading is true', (WidgetTester tester) async {
      // Arrange & Act
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: HOAppButton(
              label: 'Loading Button',
              onPressed: () {},
              isLoading: true,
            ),
          ),
        ),
      );

      // Assert
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.text('Loading Button'), findsNothing);
    });

    testWidgets('calls onPressed when tapped', (WidgetTester tester) async {
      // Arrange
      var wasPressed = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: HOAppButton(
              label: 'Clickable Button',
              onPressed: () {
                wasPressed = true;
              },
            ),
          ),
        ),
      );

      // Act
      await tester.tap(find.byType(ElevatedButton));
      await tester.pumpAndSettle();

      // Assert
      expect(wasPressed, isTrue);
    });

    testWidgets('renders outlined variant correctly', (WidgetTester tester) async {
      // Arrange & Act
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: HOAppButton(
              label: 'Outlined Button',
              onPressed: () {},
              variant: ButtonVariant.outlined,
            ),
          ),
        ),
      );

      // Assert
      expect(find.byType(OutlinedButton), findsOneWidget);
      expect(find.byType(ElevatedButton), findsNothing);
    });

    testWidgets('renders text variant correctly', (WidgetTester tester) async {
      // Arrange & Act
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: HOAppButton(
              label: 'Text Button',
              onPressed: () {},
              variant: ButtonVariant.text,
            ),
          ),
        ),
      );

      // Assert
      expect(find.byType(TextButton), findsOneWidget);
      expect(find.byType(ElevatedButton), findsNothing);
    });

    testWidgets('renders with icon when provided', (WidgetTester tester) async {
      // Arrange & Act
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: HOAppButton(
              label: 'Icon Button',
              onPressed: () {},
              icon: Icons.add,
            ),
          ),
        ),
      );

      // Assert
      expect(find.byIcon(Icons.add), findsOneWidget);
      expect(find.text('Icon Button'), findsOneWidget);
    });

    testWidgets('respects isFullWidth property', (WidgetTester tester) async {
      // Arrange & Act
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 300,
              child: HOAppButton(
                label: 'Full Width Button',
                onPressed: () {},
                isFullWidth: true,
              ),
            ),
          ),
        ),
      );

      // Assert
      final button = tester.widget<SizedBox>(
        find.descendant(
          of: find.byType(HOAppButton),
          matching: find.byType(SizedBox),
        ).first,
      );
      expect(button.width, equals(double.infinity));
    });
  });

  group('HOAppCard Widget Tests', () {
    testWidgets('renders card with child', (WidgetTester tester) async {
      // Arrange
      const testText = 'Card Content';

      // Act
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: HOAppCard(
              child: Text(testText),
            ),
          ),
        ),
      );

      // Assert
      expect(find.byType(Card), findsOneWidget);
      expect(find.text(testText), findsOneWidget);
    });

    testWidgets('card is tappable when onTap provided', (WidgetTester tester) async {
      // Arrange
      var wasTapped = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: HOAppCard(
              onTap: () {
                wasTapped = true;
              },
              child: const Text('Tappable Card'),
            ),
          ),
        ),
      );

      // Act
      await tester.tap(find.byType(InkWell));
      await tester.pumpAndSettle();

      // Assert
      expect(wasTapped, isTrue);
    });

    testWidgets('card renders without InkWell when onTap is null', (WidgetTester tester) async {
      // Arrange & Act
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: HOAppCard(
              child: Text('Non-tappable Card'),
            ),
          ),
        ),
      );

      // Assert
      expect(find.byType(InkWell), findsNothing);
      expect(find.byType(Card), findsOneWidget);
    });
  });

  group('LoadingIndicator Widget Tests', () {
    testWidgets('renders with default message', (WidgetTester tester) async {
      // Arrange & Act
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: LoadingIndicator(),
          ),
        ),
      );

      // Assert
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.text('Loading...'), findsOneWidget);
    });

    testWidgets('renders with custom message', (WidgetTester tester) async {
      // Arrange
      const customMessage = 'Please wait...';

      // Act
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: LoadingIndicator(message: customMessage),
          ),
        ),
      );

      // Assert
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.text(customMessage), findsOneWidget);
    });

    testWidgets('centers content properly', (WidgetTester tester) async {
      // Arrange & Act
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: LoadingIndicator(),
          ),
        ),
      );

      // Assert
      expect(find.byType(Center), findsWidgets);
    });
  });
}
