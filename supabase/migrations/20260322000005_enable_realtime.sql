-- Migration: Enable Realtime
-- Description: Enable Supabase Realtime for live updates on key tables
-- Created: 2024-03-22

-- Enable realtime on key tables for live updates
ALTER PUBLICATION supabase_realtime ADD TABLE announcements;
ALTER PUBLICATION supabase_realtime ADD TABLE violations;
ALTER PUBLICATION supabase_realtime ADD TABLE tickets;
ALTER PUBLICATION supabase_realtime ADD TABLE messages;
ALTER PUBLICATION supabase_realtime ADD TABLE amenity_bookings;
ALTER PUBLICATION supabase_realtime ADD TABLE invoices;
ALTER PUBLICATION supabase_realtime ADD TABLE payments;
ALTER PUBLICATION supabase_realtime ADD TABLE pool_access_registrations;
ALTER PUBLICATION supabase_realtime ADD TABLE household_members;

-- Note: RLS policies will still apply to realtime subscriptions
-- Users will only receive updates for rows they have permission to view
