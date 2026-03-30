# Manual SQL Scripts

This directory contains helper SQL scripts for database maintenance and debugging. These are **not** migrations and should be run manually in Supabase Studio SQL Editor as needed.

## User Management Scripts

### `delete_test_user.sql`
Delete a specific test user and all their related data.
- **Usage:** Edit the email address in the script, then run in SQL Editor
- **Purpose:** Clean up test accounts during development

### `delete_users_without_community.sql`
Delete all users who have no community or household assignment.
- **Usage:** Review preview in Step 1, then uncomment Step 2 to delete
- **Warning:** Permanently deletes user accounts

### `diagnose_all_users.sql`
Show the status of all users in the system.
- **Usage:** Run to see which users have communities, units, and roles
- **Purpose:** Debugging user assignment issues

## Role & Assignment Fixes

### `fix_all_users_missing_roles.sql`
Add missing `resident` roles to all users who have household_members but no user_roles.
- **Usage:** Run to fix all affected users at once
- **Purpose:** Fix users who signed up before RLS policies were complete

### `fix_missing_role.sql`
Add missing `resident` role to a specific user.
- **Usage:** Edit the email address in the script, then run
- **Purpose:** Fix individual users with missing roles

### `check_user_status.sql`
Check the detailed status of a specific user.
- **Usage:** Edit the email address, then run to see their assignments
- **Purpose:** Debug specific user issues

## RLS Policy Scripts

### `verify_and_fix_rls.sql`
Verify and fix all RLS (Row Level Security) policies for community signup.
- **Usage:** Run to ensure all necessary policies exist
- **Purpose:** Set up or repair RLS policies for communities, units, household_members, and user_roles

### `add_user_roles_select_policy.sql`
Add SELECT policies for user_roles and household_members tables.
- **Usage:** Run if users can't see their roles or unit assignments
- **Purpose:** Allow authenticated users to read their own data

## General Tips

- Always run the **preview/diagnostic** queries first before making changes
- Make backups before deleting data
- Test with a single user before applying fixes to all users
- Run these in **Supabase Studio SQL Editor**, not as migrations
