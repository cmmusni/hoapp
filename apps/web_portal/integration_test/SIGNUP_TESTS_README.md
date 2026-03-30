# Signup Flow Integration Tests

## Overview

Comprehensive integration tests for the community signup flow, covering:
- Metadata persistence across browser contexts
- PKCE timeout handling with login fallback
- Multiple users signing up for same unit (primary/secondary roles)
- Metadata cleanup after successful assignment
- Edge cases (invalid units, duplicate emails, missing metadata)
- RLS policy verification

## Prerequisites

### 1. Test Supabase Instance

Create a separate Supabase project for testing:
1. Go to https://supabase.com/dashboard
2. Create new project (e.g., "hoapp-test")
3. Apply all migrations from `/supabase/migrations/`
4. Note down the URL and anon key

### 2. Test Community Setup

Create a test community with units:

```sql
-- Create test community
INSERT INTO communities (id, name, slug, settings)
VALUES (
  gen_random_uuid(),
  'Test Community',
  'test-community',
  '{"brand": {"primary": "#215e3f", "surface": "#ECEFF1"}}'::jsonb
);

-- Create test units (adjust community_id)
INSERT INTO units (community_id, unit_no, unit_type, max_pax)
SELECT 
  'YOUR_COMMUNITY_ID'::uuid,
  unit_no::text,
  'standard',
  4
FROM generate_series(101, 410) as unit_no;
```

### 3. Environment Variables

Create `.env.test` file in project root:

```env
TEST_SUPABASE_URL=https://your-test-project.supabase.co
TEST_SUPABASE_ANON_KEY=your-anon-key
TEST_COMMUNITY_SLUG=test-community
```

## Running the Tests

### All Tests

```bash
cd apps/web_portal
flutter test integration_test/signup_flow_test.dart \
  --dart-define=TEST_SUPABASE_URL=https://your-test-project.supabase.co \
  --dart-define=TEST_SUPABASE_ANON_KEY=your-anon-key \
  --dart-define=TEST_COMMUNITY_SLUG=test-community
```

### Specific Test Group

```bash
flutter test integration_test/signup_flow_test.dart \
  --dart-define=TEST_SUPABASE_URL=... \
  --dart-define=TEST_SUPABASE_ANON_KEY=... \
  --dart-define=TEST_COMMUNITY_SLUG=test-community \
  --name "Metadata Persistence"
```

### With Verbose Output

```bash
flutter test integration_test/signup_flow_test.dart \
  --dart-define=TEST_SUPABASE_URL=... \
  --dart-define=TEST_SUPABASE_ANON_KEY=... \
  --dart-define=TEST_COMMUNITY_SLUG=test-community \
  --reporter expanded
```

## Test Coverage

### 1. Metadata Persistence Tests

**Test: Should store metadata in database during signup**
- Creates user with metadata
- Verifies metadata is stored in `auth.users.raw_user_meta_data`
- ✅ Confirms metadata survives in database

**Test: Should preserve metadata across PKCE timeout and manual login**
- Signs up user (stores metadata)
- Signs out (simulates PKCE timeout)
- Signs in manually (simulates login after timeout)
- ✅ Confirms metadata is still accessible

### 2. Unit Assignment Tests

**Test: First user should become primary member of unit**
- Creates first user for a unit
- Assigns to household_members
- ✅ Verifies member_role is 'primary'

**Test: Second user for same unit should become secondary member**
- Creates primary member for unit
- Creates second user for same unit
- Checks for existing primary
- ✅ Verifies second user gets 'secondary' role

**Test: Should create user_roles record for new resident**
- Creates user and assigns role
- ✅ Verifies 'resident' role is created

### 3. Metadata Cleanup Tests

**Test: Should clear metadata after successful unit assignment**
- Signs up with metadata
- Assigns to unit
- Clears metadata
- ✅ Verifies community_slug and unit_number are null
- ✅ Confirms full_name is preserved

### 4. Edge Cases Tests

**Test: Should handle invalid unit number gracefully**
- Signs up with non-existent unit number
- Attempts to find unit
- ✅ Verifies unit lookup returns null
- ✅ Confirms no household_members record created

**Test: Should not create duplicate household_members records**
- Creates user and assigns to unit
- Checks for existing before second insert
- ✅ Verifies only one record exists

**Test: Should handle missing metadata gracefully**
- Signs up without community/unit metadata
- ✅ Verifies no household_members record created
- ✅ Confirms system doesn't break

**Test: Should prevent duplicate email signups**
- Signs up with email
- Attempts second signup with same email
- ✅ Verifies AuthException is thrown

### 5. RLS Policy Tests

**Test: Anonymous users should be able to read communities**
- Signs out to become anonymous
- Queries communities table
- ✅ Verifies SELECT succeeds

**Test: Anonymous users should be able to read units**
- Signs out to become anonymous
- Queries units table
- ✅ Verifies SELECT succeeds

**Test: Authenticated users should be able to insert their own household_members**
- Signs in as user
- Inserts household_members record
- ✅ Verifies INSERT succeeds with RLS

**Test: Authenticated users should be able to insert their own user_roles**
- Signs in as user
- Inserts user_roles record
- ✅ Verifies INSERT succeeds with RLS

## Expected Results

All tests should pass with proper setup:

```
✓ Should store metadata in database during signup
✓ Should preserve metadata across PKCE timeout and manual login
✓ First user should become primary member of unit
✓ Second user for same unit should become secondary member
✓ Should create user_roles record for new resident
✓ Should clear metadata after successful unit assignment
✓ Should handle invalid unit number gracefully
✓ Should not create duplicate household_members records
✓ Should handle missing metadata gracefully
✓ Should prevent duplicate email signups
✓ Anonymous users should be able to read communities
✓ Anonymous users should be able to read units
✓ Authenticated users should be able to insert their own household_members
✓ Authenticated users should be able to insert their own user_roles

14 tests passed
```

## Cleanup

Tests automatically clean up after themselves by:
1. Deleting household_members records
2. Deleting user_roles records
3. Deleting auth users via admin API

However, if tests are interrupted, you may need to manually clean up:

```sql
-- Find test users
SELECT email FROM auth.users WHERE email LIKE 'test_%@example.com';

-- Delete test household_members
DELETE FROM household_members 
WHERE user_id IN (
  SELECT id FROM auth.users WHERE email LIKE 'test_%@example.com'
);

-- Delete test user_roles
DELETE FROM user_roles 
WHERE user_id IN (
  SELECT id FROM auth.users WHERE email LIKE 'test_%@example.com'
);

-- Delete test users (use Supabase Dashboard > Authentication > Users)
```

## Troubleshooting

### "Connection refused" or "Network error"
- Verify TEST_SUPABASE_URL is correct
- Check internet connection
- Confirm test Supabase project is running

### "JWT expired" or "Invalid API key"
- Verify TEST_SUPABASE_ANON_KEY is correct
- Check if key was rotated in Supabase dashboard

### "Row violates row-level security policy"
- Run `/supabase/migrations/` on test instance
- Verify RLS policies with `/supabase/manual-scripts/verify_and_fix_rls.sql`

### Tests timeout
- Increase timeout in test file
- Check Supabase project status
- Verify network latency

### Random failures
- May indicate race conditions
- Re-run tests to confirm
- Check test isolation (cleanup)

## CI/CD Integration

Add to `.github/workflows/test.yml`:

```yaml
name: Integration Tests

on: [push, pull_request]

jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      - uses: subosito/flutter-action@v2
        with:
          flutter-version: '3.x'
      - run: flutter pub get
      - name: Run integration tests
        run: |
          flutter test integration_test/signup_flow_test.dart \
            --dart-define=TEST_SUPABASE_URL=${{ secrets.TEST_SUPABASE_URL }} \
            --dart-define=TEST_SUPABASE_ANON_KEY=${{ secrets.TEST_SUPABASE_ANON_KEY }} \
            --dart-define=TEST_COMMUNITY_SLUG=test-community
```

## Next Steps

1. **Run tests locally** to verify setup
2. **Add to CI/CD** pipeline
3. **Monitor test coverage** and add new tests as features are added
4. **Set up test data fixtures** for consistent test state
5. **Create E2E tests** for full UI flow testing
