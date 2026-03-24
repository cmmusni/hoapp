-- ========================================
-- TRIGGERS: updated_at timestamp
-- ========================================

CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Apply to all mutable tables
CREATE TRIGGER update_profiles_updated_at BEFORE UPDATE ON profiles
  FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_announcements_updated_at BEFORE UPDATE ON announcements
  FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_violations_updated_at BEFORE UPDATE ON violations
  FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_tickets_updated_at BEFORE UPDATE ON tickets
  FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_amenities_updated_at BEFORE UPDATE ON amenities
  FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_amenity_bookings_updated_at BEFORE UPDATE ON amenity_bookings
  FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_invoices_updated_at BEFORE UPDATE ON invoices
  FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_payments_updated_at BEFORE UPDATE ON payments
  FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_pool_access_registrations_updated_at BEFORE UPDATE ON pool_access_registrations
  FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- ========================================
-- TRIGGER: Pool Access 3-month edit cadence
-- ========================================

CREATE OR REPLACE FUNCTION enforce_pool_edit_cadence()
RETURNS TRIGGER AS $$
DECLARE
  is_staff BOOLEAN;
BEGIN
  -- Check if user is staff (community_admin or hoa_officer)
  SELECT EXISTS (
    SELECT 1 FROM user_roles
    WHERE user_id = auth.uid()
      AND community_id = NEW.community_id
      AND role IN ('community_admin', 'hoa_officer')
  ) INTO is_staff;

  -- Staff can always edit
  IF is_staff THEN
    NEW.last_edited_at = now();
    RETURN NEW;
  END IF;

  -- Non-staff: enforce 3-month waiting period
  IF (now() - OLD.last_edited_at) < interval '3 months' THEN
    RAISE EXCEPTION 'Pool access registration can only be edited once every 3 months. Next edit available: %',
      (OLD.last_edited_at + interval '3 months')::date;
  END IF;

  -- Update last_edited_at
  NEW.last_edited_at = now();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER enforce_pool_access_edit_cadence
  BEFORE UPDATE ON pool_access_registrations
  FOR EACH ROW
  WHEN (OLD.user_id = auth.uid())
  EXECUTE FUNCTION enforce_pool_edit_cadence();
