# Database Reset Guide

This guide explains how to reset your HOApp database to a clean state with empty tables but all schema intact.

## ⚠️ WARNING

**These operations will DELETE ALL DATA permanently!**

Use only for:
- Development and testing
- Starting fresh after major mistakes
- Preparing demo environments

**Never use on production databases!**

---

## Quick Reset (Recommended)

The easiest way to reset your local database:

```bash
make db:reset
```

Or run the script directly:

```bash
./reset_database.sh
```

This will:
1. Stop Supabase
2. Remove database files
3. Start a fresh Supabase instance
4. Run all migrations
5. Set up all storage buckets and policies

### What You'll Have After Reset

✅ All tables created (empty)  
✅ All triggers installed  
✅ All RLS policies active  
✅ All storage buckets configured  
✅ Realtime enabled  
✅ No data in any table  

---

## Manual SQL Reset (Advanced)

If you prefer more control or need to reset a remote database:

### Step 1: Run the SQL Reset Script

```bash
supabase db execute -f supabase/reset_schema.sql
```

This will drop all tables and clean storage buckets.

### Step 2: Re-apply Migrations

For local development:

```bash
supabase db reset
```

Or apply migrations one by one:

```bash
supabase migration up
```

For remote databases:

```bash
supabase db push
```

---

## Alternative: Reset with Seed Data

If you want to reset AND add demo data:

```bash
make seed
```

This will:
1. Reset the database
2. Apply all migrations
3. Load demo data from `supabase/seed.sql`

---

## Troubleshooting

### Script Permission Issues

If you get a permission error, make the script executable:

```bash
chmod +x reset_database.sh
```

### Migration Errors

If migrations fail after reset:

1. Check that Supabase is running:
   ```bash
   supabase status
   ```

2. Check migration files are in correct order:
   ```bash
   ls supabase/migrations/
   ```

3. Try starting fresh:
   ```bash
   supabase stop
   supabase start
   supabase db reset
   ```

### Storage Bucket Issues

If storage policies fail:

1. Manually recreate buckets in Supabase Studio:
   - Go to http://localhost:54323
   - Navigate to Storage
   - Create buckets: `payment_proofs`, `receipts`, `pool_registrations`, `violation_photos`, `pool_access_docs`

2. Re-run migration:
   ```bash
   supabase db reset
   ```

---

## What Gets Reset

### Tables (All Data Deleted)
- communities
- buildings
- units
- profiles
- user_roles
- platform_roles
- invites
- household_members
- announcements
- violations
- tickets
- messages
- amenities
- amenity_bookings
- invoices
- payments
- pool_access_registrations
- audit_logs
- notification_tokens

### Storage Buckets (All Files Deleted)
- payment_proofs
- receipts
- pool_registrations
- violation_photos
- pool_access_docs

### What's Preserved
- Supabase auth.users table (unless using `supabase db reset`)
- Extensions (pgcrypto, btree_gist)
- Schema structure
- Triggers
- RLS policies
- Functions

---

## Recovery

There is **NO RECOVERY** from a database reset. All data is permanently deleted.

### Best Practices

Before resetting:

1. **Backup your data** if needed:
   ```bash
   pg_dump -h localhost -U postgres -p 54322 postgres > backup.sql
   ```

2. **Export important records** manually from Supabase Studio

3. **Notify team members** if working in shared environment

4. **Test reset process** on a separate branch first

---

## For Different Environments

### Local Development
```bash
make db:reset
```

### Staging/Testing Server
```bash
# 1. Link to remote project
supabase link --project-ref your-project-ref

# 2. Run SQL reset (careful!)
supabase db execute -f supabase/reset_schema.sql

# 3. Push migrations
supabase db push
```

### Production
**DO NOT RESET PRODUCTION DATABASES!**

If you absolutely must (e.g., starting over):
1. Take a full backup
2. Notify all users
3. Schedule maintenance window
4. Use the SQL script method with extreme caution
5. Test restore process beforehand

---

## Related Commands

```bash
# View current database status
supabase status

# View migration history
supabase migration list

# Create new migration
supabase migration new migration_name

# Rollback last migration (if needed)
supabase migration down

# View logs
supabase logs db
```

---

## Need Help?

If something goes wrong:

1. Check the error message carefully
2. Review migration files for syntax errors
3. Check Supabase documentation: https://supabase.com/docs
4. Inspect logs: `supabase logs db`
5. Try a complete restart: `supabase stop && supabase start`
