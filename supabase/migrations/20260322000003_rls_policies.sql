-- ========================================
-- ROW LEVEL SECURITY POLICIES
-- ========================================

-- Enable RLS on all tables
ALTER TABLE communities ENABLE ROW LEVEL SECURITY;
ALTER TABLE buildings ENABLE ROW LEVEL SECURITY;
ALTER TABLE units ENABLE ROW LEVEL SECURITY;
ALTER TABLE profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE user_roles ENABLE ROW LEVEL SECURITY;
ALTER TABLE platform_roles ENABLE ROW LEVEL SECURITY;
ALTER TABLE invites ENABLE ROW LEVEL SECURITY;
ALTER TABLE household_members ENABLE ROW LEVEL SECURITY;
ALTER TABLE announcements ENABLE ROW LEVEL SECURITY;
ALTER TABLE violations ENABLE ROW LEVEL SECURITY;
ALTER TABLE tickets ENABLE ROW LEVEL SECURITY;
ALTER TABLE messages ENABLE ROW LEVEL SECURITY;
ALTER TABLE amenities ENABLE ROW LEVEL SECURITY;
ALTER TABLE amenity_bookings ENABLE ROW LEVEL SECURITY;
ALTER TABLE invoices ENABLE ROW LEVEL SECURITY;
ALTER TABLE payments ENABLE ROW LEVEL SECURITY;
ALTER TABLE pool_access_registrations ENABLE ROW LEVEL SECURITY;
ALTER TABLE audit_logs ENABLE ROW LEVEL SECURITY;
ALTER TABLE notification_tokens ENABLE ROW LEVEL SECURITY;

-- ========================================
-- HELPER FUNCTIONS
-- ========================================

-- Check if user belongs to a community
CREATE OR REPLACE FUNCTION is_community_member(community_uuid UUID)
RETURNS BOOLEAN AS $$
BEGIN
  RETURN EXISTS (
    SELECT 1 FROM profiles
    WHERE user_id = auth.uid() AND community_id = community_uuid
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, auth;

-- Check if user has specific role in community
CREATE OR REPLACE FUNCTION has_community_role(community_uuid UUID, required_role TEXT)
RETURNS BOOLEAN AS $$
BEGIN
  RETURN EXISTS (
    SELECT 1 FROM user_roles
    WHERE user_id = auth.uid()
      AND community_id = community_uuid
      AND role = required_role
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, auth;

-- Check if user is staff (community_admin or hoa_officer) in community
CREATE OR REPLACE FUNCTION is_community_staff(community_uuid UUID)
RETURNS BOOLEAN AS $$
BEGIN
  RETURN EXISTS (
    SELECT 1 FROM user_roles
    WHERE user_id = auth.uid()
      AND community_id = community_uuid
      AND role IN ('community_admin', 'hoa_officer')
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, auth;

-- Check if user is member of a specific unit
CREATE OR REPLACE FUNCTION is_unit_member(unit_uuid UUID)
RETURNS BOOLEAN AS $$
BEGIN
  RETURN EXISTS (
    SELECT 1 FROM household_members
    WHERE user_id = auth.uid() AND unit_id = unit_uuid
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, auth;

-- ========================================
-- COMMUNITIES
-- ========================================

CREATE POLICY "Communities are viewable by members"
  ON communities FOR SELECT
  USING (is_community_member(id));

CREATE POLICY "Communities are insertable by authenticated users"
  ON communities FOR INSERT
  WITH CHECK (auth.uid() IS NOT NULL);

CREATE POLICY "Communities are updatable by admins"
  ON communities FOR UPDATE
  USING (has_community_role(id, 'community_admin'));

-- ========================================
-- BUILDINGS & UNITS
-- ========================================

CREATE POLICY "Buildings are viewable by community members"
  ON buildings FOR SELECT
  USING (is_community_member(community_id));

CREATE POLICY "Buildings are manageable by staff"
  ON buildings FOR ALL
  USING (is_community_staff(community_id));

CREATE POLICY "Units are viewable by community members"
  ON units FOR SELECT
  USING (is_community_member(community_id));

CREATE POLICY "Units are manageable by staff"
  ON units FOR INSERT
  WITH CHECK (is_community_staff(community_id));

CREATE POLICY "Units are updatable by staff"
  ON units FOR UPDATE
  USING (is_community_staff(community_id));

CREATE POLICY "Units are deletable by staff"
  ON units FOR DELETE
  USING (is_community_staff(community_id));

-- ========================================
-- PROFILES & ROLES
-- ========================================

CREATE POLICY "Profiles are viewable by community members"
  ON profiles FOR SELECT
  USING (is_community_member(community_id));

CREATE POLICY "Profiles are insertable by authenticated users"
  ON profiles FOR INSERT
  WITH CHECK (auth.uid() IS NOT NULL);

CREATE POLICY "Profiles are updatable by owner or staff"
  ON profiles FOR UPDATE
  USING (user_id = auth.uid() OR is_community_staff(community_id));

CREATE POLICY "User roles are viewable by community members"
  ON user_roles FOR SELECT
  USING (is_community_member(community_id));

CREATE POLICY "User roles are manageable by staff"
  ON user_roles FOR ALL
  USING (is_community_staff(community_id));

-- ========================================
-- INVITES
-- ========================================

CREATE POLICY "Invites are viewable by staff"
  ON invites FOR SELECT
  USING (is_community_staff(community_id));

CREATE POLICY "Invites are insertable by staff"
  ON invites FOR INSERT
  WITH CHECK (is_community_staff(community_id));

CREATE POLICY "Invites are updatable by staff"
  ON invites FOR UPDATE
  USING (is_community_staff(community_id));

CREATE POLICY "Invites are deletable by staff"
  ON invites FOR DELETE
  USING (is_community_staff(community_id));

-- ========================================
-- HOUSEHOLD MEMBERS
-- ========================================

CREATE POLICY "View household members in community"
  ON household_members FOR SELECT
  USING (
    community_id IN (
      SELECT community_id FROM user_roles WHERE user_id = auth.uid()
    )
  );

CREATE POLICY "Staff manage household members"
  ON household_members FOR ALL
  USING (
    community_id IN (
      SELECT community_id FROM user_roles 
      WHERE user_id = auth.uid() 
      AND role IN ('community_admin', 'hoa_officer')
    )
  );

-- ========================================
-- ANNOUNCEMENTS
-- ========================================

CREATE POLICY "Announcements are viewable by community members"
  ON announcements FOR SELECT
  USING (is_community_member(community_id));

CREATE POLICY "Announcements are insertable by staff"
  ON announcements FOR INSERT
  WITH CHECK (is_community_staff(community_id));

CREATE POLICY "Announcements are updatable by staff"
  ON announcements FOR UPDATE
  USING (is_community_staff(community_id));

CREATE POLICY "Announcements are deletable by staff"
  ON announcements FOR DELETE
  USING (is_community_staff(community_id));

-- ========================================
-- VIOLATIONS
-- ========================================

CREATE POLICY "Violations are viewable by community members"
  ON violations FOR SELECT
  USING (is_community_member(community_id));

CREATE POLICY "Violations are insertable by community members"
  ON violations FOR INSERT
  WITH CHECK (
    is_community_member(community_id) AND reporter_user_id = auth.uid()
  );

CREATE POLICY "Violations are updatable by staff"
  ON violations FOR UPDATE
  USING (is_community_staff(community_id));

CREATE POLICY "Violations are deletable by staff"
  ON violations FOR DELETE
  USING (is_community_staff(community_id));

-- ========================================
-- TICKETS & MESSAGES
-- ========================================

CREATE POLICY "Tickets are viewable by participants or staff"
  ON tickets FOR SELECT
  USING (
    created_by = auth.uid() OR is_community_staff(community_id)
  );

CREATE POLICY "Tickets are insertable by community members"
  ON tickets FOR INSERT
  WITH CHECK (
    is_community_member(community_id) AND created_by = auth.uid()
  );

CREATE POLICY "Tickets are updatable by staff"
  ON tickets FOR UPDATE
  USING (is_community_staff(community_id));

CREATE POLICY "Messages are viewable by ticket participants or staff"
  ON messages FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM tickets t
      WHERE t.id = messages.ticket_id
        AND (t.created_by = auth.uid() OR is_community_staff(t.community_id))
    )
  );

CREATE POLICY "Messages are insertable by ticket participants or staff"
  ON messages FOR INSERT
  WITH CHECK (
    sender_user_id = auth.uid() AND
    EXISTS (
      SELECT 1 FROM tickets t
      WHERE t.id = messages.ticket_id
        AND (t.created_by = auth.uid() OR is_community_staff(t.community_id))
    )
  );

-- ========================================
-- AMENITIES & BOOKINGS
-- ========================================

CREATE POLICY "Amenities are viewable by community members"
  ON amenities FOR SELECT
  USING (is_community_member(community_id));

CREATE POLICY "Amenities are manageable by staff"
  ON amenities FOR ALL
  USING (is_community_staff(community_id));

CREATE POLICY "Bookings are viewable by owner or staff"
  ON amenity_bookings FOR SELECT
  USING (
    user_id = auth.uid() OR is_community_staff(community_id)
  );

CREATE POLICY "Bookings are insertable by owner"
  ON amenity_bookings FOR INSERT
  WITH CHECK (
    user_id = auth.uid() AND is_community_member(community_id)
  );

CREATE POLICY "Bookings are updatable by owner or staff"
  ON amenity_bookings FOR UPDATE
  USING (
    user_id = auth.uid() OR is_community_staff(community_id)
  );

CREATE POLICY "Bookings are deletable by staff"
  ON amenity_bookings FOR DELETE
  USING (is_community_staff(community_id));

-- ========================================
-- INVOICES & PAYMENTS
-- ========================================

CREATE POLICY "Invoices are viewable by unit members or staff"
  ON invoices FOR SELECT
  USING (
    is_unit_member(unit_id) OR is_community_staff(community_id)
  );

CREATE POLICY "Invoices are manageable by staff"
  ON invoices FOR INSERT
  WITH CHECK (is_community_staff(community_id));

CREATE POLICY "Invoices are updatable by staff"
  ON invoices FOR UPDATE
  USING (is_community_staff(community_id));

CREATE POLICY "Invoices are deletable by staff"
  ON invoices FOR DELETE
  USING (is_community_staff(community_id));

CREATE POLICY "Payments are viewable by owner or staff"
  ON payments FOR SELECT
  USING (
    user_id = auth.uid() OR is_community_staff(community_id)
  );

CREATE POLICY "Payments are insertable by owner"
  ON payments FOR INSERT
  WITH CHECK (
    user_id = auth.uid() AND is_community_member(community_id)
  );

CREATE POLICY "Payments are updatable by staff"
  ON payments FOR UPDATE
  USING (is_community_staff(community_id));

CREATE POLICY "Payments are deletable by staff"
  ON payments FOR DELETE
  USING (is_community_staff(community_id));

-- ========================================
-- POOL ACCESS REGISTRATIONS
-- ========================================

CREATE POLICY "Pool access is viewable by owner or staff"
  ON pool_access_registrations FOR SELECT
  USING (
    user_id = auth.uid() OR is_community_staff(community_id)
  );

CREATE POLICY "Pool access is insertable by community members"
  ON pool_access_registrations FOR INSERT
  WITH CHECK (
    user_id = auth.uid() AND is_community_member(community_id)
  );

CREATE POLICY "Pool access is updatable by owner or staff"
  ON pool_access_registrations FOR UPDATE
  USING (
    user_id = auth.uid() OR is_community_staff(community_id)
  );

CREATE POLICY "Pool access is deletable by community admin"
  ON pool_access_registrations FOR DELETE
  USING (has_community_role(community_id, 'community_admin'));

-- ========================================
-- AUDIT LOGS
-- ========================================

CREATE POLICY "Audit logs are viewable by staff"
  ON audit_logs FOR SELECT
  USING (
    community_id IS NULL OR is_community_staff(community_id)
  );

CREATE POLICY "Audit logs are insertable by authenticated users"
  ON audit_logs FOR INSERT
  WITH CHECK (auth.uid() IS NOT NULL);

-- ========================================
-- NOTIFICATION TOKENS
-- ========================================

CREATE POLICY "Notification tokens are manageable by owner"
  ON notification_tokens FOR ALL
  USING (user_id = auth.uid());
