-- Add is_archived column to announcements table
ALTER TABLE announcements ADD COLUMN is_archived BOOLEAN NOT NULL DEFAULT false;

-- Index for filtering archived announcements
CREATE INDEX idx_announcements_archived ON announcements(community_id, is_archived);
