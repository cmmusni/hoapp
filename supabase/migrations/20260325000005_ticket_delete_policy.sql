-- Allow staff (community_admin, hoa_officer) to delete tickets
CREATE POLICY "Tickets are deletable by staff"
  ON tickets FOR DELETE
  USING (is_community_staff(community_id));
