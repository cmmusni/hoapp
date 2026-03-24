# Household Member Name Support Migration

## Overview
This migration adds support for household members without requiring user accounts. Members can now be added either:
- **Registered users**: Selected from the search (linked via `user_id`)
- **Non-registered members**: Free-form names (stored in `member_name`)

## Steps to Apply

### 1. Run the Database Migration

Go to your Supabase Dashboard → SQL Editor and run the migration file:
`supabase/migrations/add_member_name_support.sql`

Or if using Supabase CLI:
```bash
supabase db push
```

### 2. Verify Changes

After running the migration, verify in your Supabase Table Editor:
- `household_members.user_id` should now be nullable
- `household_members.member_name` column should exist
- Check constraint should prevent both being null or both being set

### 3. Hot Reload Flutter App

The code changes are already applied. Just hot reload (`r`) or hot restart (`R`) your Flutter app.

## How it Works

### Adding Members

**For Registered Users:**
1. Type in the name field (at least 2 characters)
2. Wait for search results to appear
3. Click on a user from the dropdown
4. Submit the form → Uses `user_id`

**For Non-Registered Members:**
1. Type any name in the field
2. Don't select from search results (or no results appear)
3. Submit the form → Uses `member_name`

### Display Logic

The app uses `displayName` getter which returns:
- `member_name` for non-registered members
- `user_name` (from joined profiles) for registered members
- "Unknown" as fallback

## Rollback

If you need to rollback:

```sql
-- Remove the constraint
ALTER TABLE household_members DROP CONSTRAINT IF EXISTS household_members_user_or_name_check;

-- Remove the column
ALTER TABLE household_members DROP COLUMN IF EXISTS member_name;

-- Make user_id required again
ALTER TABLE household_members ALTER COLUMN user_id SET NOT NULL;
```

## Data Integrity

The database ensures:
- Either `user_id` OR `member_name` must be provided (not both, not neither)
- RLS policies updated to handle null `user_id`
- Index added for efficient querying by member_name
