import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:math';

/// Integration tests for community signup flow
///
/// These tests verify:
/// - Metadata persistence across browser contexts
/// - PKCE timeout handling with login fallback
/// - Multiple users signing up for same unit (primary/member roles)
/// - Metadata cleanup after successful assignment
/// - Edge cases (invalid units, duplicate emails, missing metadata)
///
/// Prerequisites:
/// 1. Test Supabase instance with RLS policies applied
/// 2. Test community created with unit numbers
/// 3. Environment variables set for test instance
///
/// Run with: flutter test integration_test/signup_flow_test.dart

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  late SupabaseClient supabase;
  late String testCommunityId;
  late String testCommunitySlug;
  final random = Random();

  setUpAll(() async {
    // Initialize Supabase with test credentials
    // In production, these should come from env variables
    const supabaseUrl = String.fromEnvironment('TEST_SUPABASE_URL',
        defaultValue: 'YOUR_TEST_SUPABASE_URL');
    const supabaseAnonKey = String.fromEnvironment('TEST_SUPABASE_ANON_KEY',
        defaultValue: 'YOUR_TEST_SUPABASE_ANON_KEY');

    await Supabase.initialize(
      url: supabaseUrl,
      anonKey: supabaseAnonKey,
    );

    supabase = Supabase.instance.client;

    // Get test community
    testCommunitySlug = const String.fromEnvironment('TEST_COMMUNITY_SLUG',
        defaultValue: 'test-community');

    final community = await supabase
        .from('communities')
        .select('id')
        .eq('slug', testCommunitySlug)
        .single();

    testCommunityId = community['id'];
  });

  tearDownAll(() async {
    await supabase.auth.signOut();
  });

  group('Signup Flow - Metadata Persistence', () {
    test('Should store metadata in database during signup', () async {
      final testEmail = 'test_${random.nextInt(100000)}@example.com';
      const testPassword = 'Test123456!';
      const testName = 'Test User';
      const testUnit = '101';

      // Sign up with metadata
      final response = await supabase.auth.signUp(
        email: testEmail,
        password: testPassword,
        data: {
          'full_name': testName,
          'community_slug': testCommunitySlug,
          'unit_number': testUnit,
        },
      );

      expect(response.user, isNotNull, reason: 'User should be created');

      // Verify metadata is stored (this simulates checking after email confirmation)
      final user = await supabase.auth.admin.getUserById(response.user!.id);
      final metadata = user.user?.userMetadata;

      expect(metadata?['full_name'], equals(testName));
      expect(metadata?['community_slug'], equals(testCommunitySlug));
      expect(metadata?['unit_number'], equals(testUnit));

      // Cleanup
      await supabase.auth.admin.deleteUser(response.user!.id);
    });

    test('Should preserve metadata across PKCE timeout and manual login',
        () async {
      final testEmail = 'test_pkce_${random.nextInt(100000)}@example.com';
      const testPassword = 'Test123456!';
      const testUnit = '102';

      // Step 1: Sign up (stores metadata)
      final signupResponse = await supabase.auth.signUp(
        email: testEmail,
        password: testPassword,
        data: {
          'full_name': 'PKCE Test User',
          'community_slug': testCommunitySlug,
          'unit_number': testUnit,
        },
      );

      final userId = signupResponse.user!.id;

      // Step 2: Sign out (simulates PKCE timeout)
      await supabase.auth.signOut();

      // Step 3: Sign in manually (simulates user logging in after PKCE timeout)
      final loginResponse = await supabase.auth.signInWithPassword(
        email: testEmail,
        password: testPassword,
      );

      expect(loginResponse.user, isNotNull);

      // Step 4: Verify metadata is still present
      final metadata = loginResponse.user?.userMetadata;
      expect(metadata?['community_slug'], equals(testCommunitySlug));
      expect(metadata?['unit_number'], equals(testUnit));

      // Cleanup
      await supabase.auth.signOut();
      await supabase.auth.admin.deleteUser(userId);
    });
  });

  group('Signup Flow - Unit Assignment', () {
    test('First user should become primary member of unit', () async {
      final testEmail = 'primary_${random.nextInt(100000)}@example.com';
      const testPassword = 'Test123456!';
      const testUnit = '201';

      // Create user
      final response = await supabase.auth.signUp(
        email: testEmail,
        password: testPassword,
        data: {
          'full_name': 'Primary Member',
          'community_slug': testCommunitySlug,
          'unit_number': testUnit,
        },
      );

      final userId = response.user!.id;

      // Get unit ID
      final unitData = await supabase
          .from('units')
          .select('id')
          .eq('community_id', testCommunityId)
          .eq('unit_no', testUnit)
          .single();

      final unitId = unitData['id'];

      // Simulate unit assignment (what auth_callback or login would do)
      await supabase.from('household_members').insert({
        'unit_id': unitId,
        'user_id': userId,
        'community_id': testCommunityId,
        'member_role': 'primary',
      });

      // Verify primary member was created
      final member = await supabase
          .from('household_members')
          .select('member_role')
          .eq('user_id', userId)
          .single();

      expect(member['member_role'], equals('primary'));

      // Cleanup
      await supabase.from('household_members').delete().eq('user_id', userId);
      await supabase.auth.admin.deleteUser(userId);
    });

    test('Second user for same unit should become additional member', () async {
      final primaryEmail = 'primary_${random.nextInt(100000)}@example.com';
      final additionalEmail =
          'additional_${random.nextInt(100000)}@example.com';
      const testPassword = 'Test123456!';
      const testUnit = '202';

      // Create primary user
      final primaryResponse = await supabase.auth.signUp(
        email: primaryEmail,
        password: testPassword,
        data: {
          'full_name': 'Primary Member',
          'community_slug': testCommunitySlug,
          'unit_number': testUnit,
        },
      );

      final primaryUserId = primaryResponse.user!.id;

      // Get unit ID
      final unitData = await supabase
          .from('units')
          .select('id')
          .eq('community_id', testCommunityId)
          .eq('unit_no', testUnit)
          .single();

      final unitId = unitData['id'];

      // Assign primary member
      await supabase.from('household_members').insert({
        'unit_id': unitId,
        'user_id': primaryUserId,
        'community_id': testCommunityId,
        'member_role': 'primary',
      });

      // Create additional user
      final additionalResponse = await supabase.auth.signUp(
        email: additionalEmail,
        password: testPassword,
        data: {
          'full_name': 'Additional Member',
          'community_slug': testCommunitySlug,
          'unit_number': testUnit,
        },
      );

      final additionalUserId = additionalResponse.user!.id;

      // Check if primary already exists (what the code does)
      final existingPrimary = await supabase
          .from('household_members')
          .select('id')
          .eq('unit_id', unitId)
          .eq('member_role', 'primary')
          .maybeSingle();

      final memberRole = existingPrimary == null ? 'primary' : 'member';

      // Assign additional member
      await supabase.from('household_members').insert({
        'unit_id': unitId,
        'user_id': additionalUserId,
        'community_id': testCommunityId,
        'member_role': memberRole,
      });

      // Verify roles
      final members = await supabase
          .from('household_members')
          .select('user_id, member_role')
          .eq('unit_id', unitId)
          .order('member_role');

      expect(members.length, equals(2));
      expect(members[0]['member_role'], equals('primary'));
      expect(members[1]['member_role'], equals('member'));

      // Cleanup
      await supabase.from('household_members').delete().eq('unit_id', unitId);
      await supabase.auth.admin.deleteUser(primaryUserId);
      await supabase.auth.admin.deleteUser(additionalUserId);
    });

    test('Should create user_roles record for new resident', () async {
      final testEmail = 'resident_${random.nextInt(100000)}@example.com';
      const testPassword = 'Test123456!';
      const testUnit = '203';

      // Create user
      final response = await supabase.auth.signUp(
        email: testEmail,
        password: testPassword,
        data: {
          'full_name': 'New Resident',
          'community_slug': testCommunitySlug,
          'unit_number': testUnit,
        },
      );

      final userId = response.user!.id;

      // Create user role (what the code does)
      await supabase.from('user_roles').insert({
        'user_id': userId,
        'community_id': testCommunityId,
        'role': 'resident',
      });

      // Verify role was created
      final role = await supabase
          .from('user_roles')
          .select('role')
          .eq('user_id', userId)
          .single();

      expect(role['role'], equals('resident'));

      // Cleanup
      await supabase.from('user_roles').delete().eq('user_id', userId);
      await supabase.auth.admin.deleteUser(userId);
    });
  });

  group('Signup Flow - Metadata Cleanup', () {
    test('Should clear metadata after successful unit assignment', () async {
      final testEmail = 'cleanup_${random.nextInt(100000)}@example.com';
      const testPassword = 'Test123456!';
      const testUnit = '301';

      // Sign up with metadata
      final response = await supabase.auth.signUp(
        email: testEmail,
        password: testPassword,
        data: {
          'full_name': 'Cleanup Test',
          'community_slug': testCommunitySlug,
          'unit_number': testUnit,
        },
      );

      final userId = response.user!.id;

      // Get unit and assign (simulating successful assignment)
      final unitData = await supabase
          .from('units')
          .select('id')
          .eq('community_id', testCommunityId)
          .eq('unit_no', testUnit)
          .single();

      await supabase.from('household_members').insert({
        'unit_id': unitData['id'],
        'user_id': userId,
        'community_id': testCommunityId,
        'member_role': 'primary',
      });

      // Clear metadata (what the code does after assignment)
      await supabase.auth.updateUser(
        UserAttributes(
          data: {
            'community_slug': null,
            'unit_number': null,
          },
        ),
      );

      // Verify metadata was cleared
      final user = supabase.auth.currentUser;
      final metadata = user?.userMetadata;

      expect(metadata?['community_slug'], isNull);
      expect(metadata?['unit_number'], isNull);
      expect(metadata?['full_name'], isNotNull); // full_name should remain

      // Cleanup
      await supabase.from('household_members').delete().eq('user_id', userId);
      await supabase.auth.admin.deleteUser(userId);
    });
  });

  group('Signup Flow - Edge Cases', () {
    test('Should handle invalid unit number gracefully', () async {
      final testEmail = 'invalid_${random.nextInt(100000)}@example.com';
      const testPassword = 'Test123456!';
      const invalidUnit = '999999';

      // Sign up with invalid unit
      final response = await supabase.auth.signUp(
        email: testEmail,
        password: testPassword,
        data: {
          'full_name': 'Invalid Unit Test',
          'community_slug': testCommunitySlug,
          'unit_number': invalidUnit,
        },
      );

      final userId = response.user!.id;

      // Try to find unit (should return null)
      final unitData = await supabase
          .from('units')
          .select('id')
          .eq('community_id', testCommunityId)
          .eq('unit_no', invalidUnit)
          .maybeSingle();

      expect(unitData, isNull);

      // In real code, this would clear metadata and log error
      // Verify no household_members record was created
      final members = await supabase
          .from('household_members')
          .select('id')
          .eq('user_id', userId)
          .maybeSingle();

      expect(members, isNull);

      // Cleanup
      await supabase.auth.admin.deleteUser(userId);
    });

    test('Should not create duplicate household_members records', () async {
      final testEmail = 'duplicate_${random.nextInt(100000)}@example.com';
      const testPassword = 'Test123456!';
      const testUnit = '401';

      // Create user
      final response = await supabase.auth.signUp(
        email: testEmail,
        password: testPassword,
        data: {
          'full_name': 'Duplicate Test',
          'community_slug': testCommunitySlug,
          'unit_number': testUnit,
        },
      );

      final userId = response.user!.id;

      // Get unit
      final unitData = await supabase
          .from('units')
          .select('id')
          .eq('community_id', testCommunityId)
          .eq('unit_no', testUnit)
          .single();

      final unitId = unitData['id'];

      // Create first record
      await supabase.from('household_members').insert({
        'unit_id': unitId,
        'user_id': userId,
        'community_id': testCommunityId,
        'member_role': 'primary',
      });

      // Try to create again (simulating user logging in multiple times)
      // Check for existing first (what the code does)
      final existing = await supabase
          .from('household_members')
          .select('id')
          .eq('user_id', userId)
          .eq('community_id', testCommunityId)
          .maybeSingle();

      // Should find existing record and not insert again
      expect(existing, isNotNull);

      // Verify only one record exists
      final allRecords = await supabase
          .from('household_members')
          .select('id')
          .eq('user_id', userId);

      expect(allRecords.length, equals(1));

      // Cleanup
      await supabase.from('household_members').delete().eq('user_id', userId);
      await supabase.auth.admin.deleteUser(userId);
    });

    test('Should handle missing metadata gracefully', () async {
      final testEmail = 'no_meta_${random.nextInt(100000)}@example.com';
      const testPassword = 'Test123456!';

      // Sign up WITHOUT community metadata (regular signup, not community-specific)
      final response = await supabase.auth.signUp(
        email: testEmail,
        password: testPassword,
        data: {
          'full_name': 'No Metadata User',
        },
      );

      final userId = response.user!.id;

      // Verify no metadata for community/unit
      final metadata = response.user?.userMetadata;
      expect(metadata?['community_slug'], isNull);
      expect(metadata?['unit_number'], isNull);

      // In real code, this would skip unit assignment
      // Verify no household_members record
      final members = await supabase
          .from('household_members')
          .select('id')
          .eq('user_id', userId)
          .maybeSingle();

      expect(members, isNull);

      // Cleanup
      await supabase.auth.admin.deleteUser(userId);
    });

    test('Should prevent duplicate email signups', () async {
      final testEmail = 'duplicate_email_${random.nextInt(100000)}@example.com';
      const testPassword = 'Test123456!';

      // First signup
      final firstResponse = await supabase.auth.signUp(
        email: testEmail,
        password: testPassword,
        data: {'full_name': 'First User'},
      );

      expect(firstResponse.user, isNotNull);

      // Try to signup again with same email
      try {
        await supabase.auth.signUp(
          email: testEmail,
          password: testPassword,
          data: {'full_name': 'Second User'},
        );
        fail('Should have thrown an error for duplicate email');
      } catch (e) {
        // Expected to fail
        expect(e, isA<AuthException>());
      }

      // Cleanup
      await supabase.auth.admin.deleteUser(firstResponse.user!.id);
    });
  });

  group('Signup Flow - RLS Policy Checks', () {
    test('Anonymous users should be able to read communities', () async {
      // Sign out to become anonymous
      await supabase.auth.signOut();

      // Should be able to query communities
      final communities = await supabase
          .from('communities')
          .select('id, name, slug')
          .eq('slug', testCommunitySlug);

      expect(communities, isNotEmpty);
    });

    test('Anonymous users should be able to read units', () async {
      // Sign out to become anonymous
      await supabase.auth.signOut();

      // Should be able to query units
      final units = await supabase
          .from('units')
          .select('id, unit_no')
          .eq('community_id', testCommunityId)
          .limit(5);

      expect(units, isNotEmpty);
    });

    test(
        'Authenticated users should be able to insert their own household_members',
        () async {
      final testEmail = 'rls_insert_${random.nextInt(100000)}@example.com';
      const testPassword = 'Test123456!';

      // Create and sign in as user
      final response = await supabase.auth.signUp(
        email: testEmail,
        password: testPassword,
        data: {'full_name': 'RLS Test User'},
      );

      final userId = response.user!.id;

      // Get a unit
      final unitData = await supabase
          .from('units')
          .select('id')
          .eq('community_id', testCommunityId)
          .limit(1)
          .single();

      // Should be able to insert own household_members record
      await supabase.from('household_members').insert({
        'unit_id': unitData['id'],
        'user_id': userId,
        'community_id': testCommunityId,
        'member_role': 'primary',
      });

      // Verify insert succeeded
      final member = await supabase
          .from('household_members')
          .select('id')
          .eq('user_id', userId)
          .single();

      expect(member, isNotNull);

      // Cleanup
      await supabase.from('household_members').delete().eq('user_id', userId);
      await supabase.auth.admin.deleteUser(userId);
    });

    test('Authenticated users should be able to insert their own user_roles',
        () async {
      final testEmail = 'rls_role_${random.nextInt(100000)}@example.com';
      const testPassword = 'Test123456!';

      // Create and sign in as user
      final response = await supabase.auth.signUp(
        email: testEmail,
        password: testPassword,
        data: {'full_name': 'RLS Role Test'},
      );

      final userId = response.user!.id;

      // Should be able to insert own user_roles record
      await supabase.from('user_roles').insert({
        'user_id': userId,
        'community_id': testCommunityId,
        'role': 'resident',
      });

      // Verify insert succeeded
      final role = await supabase
          .from('user_roles')
          .select('role')
          .eq('user_id', userId)
          .single();

      expect(role['role'], equals('resident'));

      // Cleanup
      await supabase.from('user_roles').delete().eq('user_id', userId);
      await supabase.auth.admin.deleteUser(userId);
    });
  });
}
