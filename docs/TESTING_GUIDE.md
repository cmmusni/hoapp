# Testing Guide for HOApp

This guide explains how to run and write tests for the HOApp platform.

## Test Structure

Tests are organized into three main categories:

### 1. Unit Tests
Test individual functions, classes, and services in isolation.

**Location**: 
- `packages/core_data/test/` - Repository and service tests
- `packages/core_ui/test/` - Widget and UI tests

**Examples**:
- `storage_service_test.dart` - File upload/download logic
- `realtime_service_test.dart` - Subscription management
- `pdf_service_test.dart` - PDF generation
- `announcement_repository_test.dart` - Database operations

### 2. Widget Tests
Test Flutter widgets in isolation with simulated user interactions.

**Location**: `packages/core_ui/test/widgets/`

**Examples**:
- `widgets_test.dart` - HOAppButton, HOAppCard, LoadingIndicator
- `file_upload_widget_test.dart` - File upload components (TODO)

### 3. Integration Tests
Test complete user workflows across multiple components.

**Location**: `apps/web_portal/integration_test/`

**Examples**:
- `app_test.dart` - Full application workflows

---

## Running Tests

### Run All Unit Tests
```bash
# For core_data package
cd packages/core_data
flutter test

# For core_ui package
cd packages/core_ui
flutter test
```

### Run Specific Test File
```bash
cd packages/core_data
flutter test test/services/storage_service_test.dart
```

### Run Integration Tests
```bash
cd apps/web_portal
flutter test integration_test/app_test.dart
```

### Run Tests with Coverage
```bash
cd packages/core_data
flutter test --coverage
genhtml coverage/lcov.info -o coverage/html
open coverage/html/index.html
```

---

## Writing Tests

### Unit Test Example

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:mockito/annotations.dart';

@GenerateMocks([SupabaseClient])
import 'my_test.mocks.dart';

void main() {
  late MyRepository repository;
  late MockSupabaseClient mockClient;

  setUp(() {
    mockClient = MockSupabaseClient();
    repository = MyRepository(mockClient);
  });

  group('MyRepository', () {
    test('fetches data successfully', () async {
      // Arrange
      when(mockClient.from('table')).thenReturn(...);

      // Act
      final result = await repository.getData();

      // Assert
      expect(result, isNotEmpty);
      verify(mockClient.from('table')).called(1);
    });

    test('handles errors gracefully', () async {
      // Arrange
      when(mockClient.from('table')).thenThrow(Exception('Error'));

      // Act & Assert
      expect(
        () => repository.getData(),
        throwsException,
      );
    });
  });
}
```

### Widget Test Example

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('Button displays label', (WidgetTester tester) async {
    // Arrange & Act
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: MyButton(label: 'Click Me'),
        ),
      ),
    );

    // Assert
    expect(find.text('Click Me'), findsOneWidget);
  });

  testWidgets('Button calls onPressed', (WidgetTester tester) async {
    // Arrange
    var wasPressed = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: MyButton(
            label: 'Click Me',
            onPressed: () => wasPressed = true,
          ),
        ),
      ),
    );

    // Act
    await tester.tap(find.byType(MyButton));
    await tester.pumpAndSettle();

    // Assert
    expect(wasPressed, isTrue);
  });
}
```

### Integration Test Example

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Complete user flow', (WidgetTester tester) async {
    // Launch app
    await tester.pumpWidget(MyApp());
    await tester.pumpAndSettle();

    // Login
    await tester.enterText(find.byKey(Key('email')), 'test@example.com');
    await tester.enterText(find.byKey(Key('password')), 'password');
    await tester.tap(find.text('Login'));
    await tester.pumpAndSettle();

    // Verify logged in
    expect(find.text('Dashboard'), findsOneWidget);

    // Perform action
    await tester.tap(find.text('Announcements'));
    await tester.pumpAndSettle();

    // Verify result
    expect(find.byType(AnnouncementsPage), findsOneWidget);
  });
}
```

---

## Test Helpers

Use the provided test helpers in `test/helpers/test_helpers.dart`:

```dart
import 'package:core_data/test/helpers/test_helpers.dart';

void main() {
  test('uses mock community', () {
    final community = createMockCommunity(
      id: 'custom-id',
      name: 'Custom Community',
    );

    expect(community.name, equals('Custom Community'));
  });

  test('uses mock invoice', () {
    final invoice = createMockInvoice(
      amount: 200.0,
      paid: true,
    );

    expect(invoice.paidAt, isNotNull);
  });
}
```

---

## Mocking Supabase

Generate mocks for Supabase classes:

```dart
import 'package:mockito/annotations.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

@GenerateMocks([
  SupabaseClient,
  GoTrueClient,
  PostgrestQueryBuilder,
  PostgrestFilterBuilder,
  SupabaseStorageClient,
  StorageFileApi,
  RealtimeChannel,
])
import 'my_test.mocks.dart';

void main() {
  // Use generated mocks
  final mockClient = MockSupabaseClient();
  final mockAuth = MockGoTrueClient();

  when(mockClient.auth).thenReturn(mockAuth);
  when(mockAuth.currentUser).thenReturn(User(...));
}
```

Generate mocks with:
```bash
flutter pub run build_runner build
```

---

## Test Coverage Goals

| Component | Target Coverage | Current Status |
|-----------|----------------|----------------|
| Repositories | 80%+ | ⚠️ In Progress |
| Services | 80%+ | ⚠️ In Progress |
| Widgets | 70%+ | ⚠️ In Progress |
| Integration | Key Flows | ⚠️ Planned |

---

## Testing Best Practices

### 1. Follow AAA Pattern
```dart
test('example', () {
  // Arrange - Setup test data and mocks
  final data = createMockData();

  // Act - Execute the code being tested
  final result = performAction(data);

  // Assert - Verify the result
  expect(result, expectedValue);
});
```

### 2. Test Edge Cases
- Empty data
- Null values
- Network errors
- Invalid input
- Boundary conditions

### 3. Use Descriptive Names
```dart
// Good
test('createAnnouncement throws exception when user not authenticated')

// Bad
test('test1')
```

### 4. Keep Tests Independent
- Don't depend on other tests
- Use setUp() and tearDown()
- Clean up mocks

### 5. Mock External Dependencies
- Mock Supabase client
- Mock file system
- Mock network calls

### 6. Test User Behavior, Not Implementation
```dart
// Good - Tests what user sees
expect(find.text('Success'), findsOneWidget);

// Bad - Tests implementation detail
expect(controller.state.isSuccess, isTrue);
```

---

## Continuous Integration

Tests run automatically on:
- Pull requests
- Pushes to main branch
- Before deployment

CI configuration in `.github/workflows/test.yml`:
```yaml
name: Tests
on: [push, pull_request]

jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      - uses: subosito/flutter-action@v2
      - run: flutter pub get
      - run: flutter test --coverage
      - uses: codecov/codecov-action@v3
```

---

## Debugging Tests

### Run test with full output
```bash
flutter test --verbose
```

### Run single test
```dart
test('my test', () {
  // ...
}, solo: true);
```

### Debug with breakpoints
```bash
flutter test --start-paused
# Then attach debugger
```

### Print debug info
```dart
test('debug test', () {
  print('Debug value: $value');
  debugPrint('More details');
});
```

---

## Common Issues

### Issue: Mocks not generated
**Solution**: Run `flutter pub run build_runner build`

### Issue: Test timeout
**Solution**: Increase timeout or use `pumpAndSettleWithTimeout()`
```dart
await tester.pumpAndSettle(Duration(seconds: 30));
```

### Issue: File not found in test
**Solution**: Use `flutter test --update-goldens` for widget golden tests

### Issue: Supabase not mocked properly
**Solution**: Ensure all Supabase interactions use mocked client

---

## Next Steps

1. ✅ Unit tests for storage service
2. ✅ Unit tests for realtime service
3. ✅ Unit tests for PDF service
4. ✅ Widget tests for UI components
5. ⚠️ Complete repository tests
6. ⚠️ Add file upload widget tests
7. ⚠️ Implement integration tests
8. ⚠️ Add test coverage reporting
9. ⚠️ Setup CI/CD pipeline

---

## Resources

- [Flutter Testing Guide](https://docs.flutter.dev/testing)
- [Mockito Documentation](https://pub.dev/packages/mockito)
- [Integration Testing](https://docs.flutter.dev/testing/integration-tests)
- [Test Coverage](https://docs.flutter.dev/testing/code-coverage)
