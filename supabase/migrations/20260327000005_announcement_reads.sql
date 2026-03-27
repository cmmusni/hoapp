-- Track when users last read announcements (per community)
CREATE TABLE IF NOT EXISTS public.announcement_reads (
  id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
  user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  community_id uuid NOT NULL REFERENCES public.communities(id) ON DELETE CASCADE,
  last_read_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE (user_id, community_id)
);

CREATE INDEX idx_announcement_reads_user ON public.announcement_reads(user_id, community_id);

-- RLS
ALTER TABLE public.announcement_reads ENABLE ROW LEVEL SECURITY;

-- Users can read their own record
CREATE POLICY "Users can view own announcement reads"
  ON public.announcement_reads FOR SELECT
  USING (auth.uid() = user_id);

-- Users can insert their own record
CREATE POLICY "Users can insert own announcement reads"
  ON public.announcement_reads FOR INSERT
  WITH CHECK (auth.uid() = user_id);

-- Users can update their own record
CREATE POLICY "Users can update own announcement reads"
  ON public.announcement_reads FOR UPDATE
  USING (auth.uid() = user_id);
