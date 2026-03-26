-- Feedback table for all portal users
CREATE TABLE IF NOT EXISTS feedback (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  community_id UUID NOT NULL REFERENCES communities(id) ON DELETE CASCADE,
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  user_email TEXT NOT NULL,
  category TEXT NOT NULL CHECK (category IN ('bug', 'feature_request', 'improvement', 'general')),
  subject TEXT NOT NULL,
  description TEXT NOT NULL,
  status TEXT NOT NULL DEFAULT 'open' CHECK (status IN ('open', 'in_review', 'planned', 'resolved', 'closed')),
  admin_notes TEXT,
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now()
);

CREATE INDEX idx_feedback_community ON feedback(community_id);
CREATE INDEX idx_feedback_status ON feedback(status);
CREATE INDEX idx_feedback_user ON feedback(user_id);
CREATE INDEX idx_feedback_category ON feedback(category);

ALTER TABLE feedback ENABLE ROW LEVEL SECURITY;

-- Users can read their own feedback
CREATE POLICY "Users can read own feedback"
  ON feedback FOR SELECT
  USING (auth.uid() = user_id);

-- Users can insert their own feedback
CREATE POLICY "Users can create feedback"
  ON feedback FOR INSERT
  WITH CHECK (auth.uid() = user_id);

-- Staff (community_admin, hoa_officer) can read all feedback in their community
CREATE POLICY "Staff can read community feedback"
  ON feedback FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM user_roles
      WHERE user_roles.user_id = auth.uid()
        AND user_roles.community_id = feedback.community_id
        AND user_roles.role IN ('community_admin', 'hoa_officer')
    )
  );

-- Staff can update feedback (status, admin_notes)
CREATE POLICY "Staff can update community feedback"
  ON feedback FOR UPDATE
  USING (
    EXISTS (
      SELECT 1 FROM user_roles
      WHERE user_roles.user_id = auth.uid()
        AND user_roles.community_id = feedback.community_id
        AND user_roles.role IN ('community_admin', 'hoa_officer')
    )
  );

-- Platform admin can read all feedback
CREATE POLICY "Platform admin can read all feedback"
  ON feedback FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM platform_roles
      WHERE platform_roles.user_id = auth.uid()
        AND platform_roles.role = 'app_admin'
    )
  );

-- Platform admin can update all feedback
CREATE POLICY "Platform admin can update all feedback"
  ON feedback FOR UPDATE
  USING (
    EXISTS (
      SELECT 1 FROM platform_roles
      WHERE platform_roles.user_id = auth.uid()
        AND platform_roles.role = 'app_admin'
    )
  );
