-- Run this script in Supabase Dashboard -> SQL Editor for an existing project.

CREATE TABLE IF NOT EXISTS public.tags (
  id BIGSERIAL PRIMARY KEY,
  name TEXT NOT NULL UNIQUE,
  color TEXT
);

CREATE TABLE IF NOT EXISTS public.document_tags (
  document_id BIGINT NOT NULL
    REFERENCES public.documents(id) ON DELETE CASCADE,
  tag_id BIGINT NOT NULL
    REFERENCES public.tags(id) ON DELETE CASCADE,
  PRIMARY KEY (document_id, tag_id)
);

CREATE INDEX IF NOT EXISTS idx_document_tags_tag_id
  ON public.document_tags(tag_id);

ALTER TABLE public.tags ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.document_tags ENABLE ROW LEVEL SECURITY;

-- TẠM THỜI: ứng dụng đang dùng Firebase Auth + anon key nên chưa có auth.uid().
-- Cho phép anon đọc/ghi tag để tính năng hoạt động; khi tích hợp Supabase JWT
-- hoặc PostgREST x-user-id, thay các policy dưới đây bằng policy theo người dùng.
GRANT SELECT, INSERT, UPDATE, DELETE
  ON public.tags, public.document_tags TO anon, authenticated;
GRANT USAGE, SELECT ON SEQUENCE public.tags_id_seq TO anon, authenticated;

DROP POLICY IF EXISTS "Authenticated users can read tags" ON public.tags;
CREATE POLICY "Authenticated users can read tags" ON public.tags
  FOR SELECT TO anon, authenticated USING (true);

DROP POLICY IF EXISTS "Authenticated users can create tags" ON public.tags;
CREATE POLICY "Authenticated users can create tags" ON public.tags
  FOR INSERT TO anon, authenticated WITH CHECK (true);

DROP POLICY IF EXISTS "Authenticated users can update tags" ON public.tags;
CREATE POLICY "Authenticated users can update tags" ON public.tags
  FOR UPDATE TO anon, authenticated USING (true) WITH CHECK (true);

DROP POLICY IF EXISTS "Authenticated users can delete tags" ON public.tags;
CREATE POLICY "Authenticated users can delete tags" ON public.tags
  FOR DELETE TO anon, authenticated USING (true);

DROP POLICY IF EXISTS "Users can read tags on own documents" ON public.document_tags;
CREATE POLICY "Users can read tags on own documents" ON public.document_tags
  FOR SELECT TO anon, authenticated USING (true);

DROP POLICY IF EXISTS "Users can add tags to own documents" ON public.document_tags;
CREATE POLICY "Users can add tags to own documents" ON public.document_tags
  FOR INSERT TO anon, authenticated WITH CHECK (true);

DROP POLICY IF EXISTS "Users can remove tags from own documents" ON public.document_tags;
CREATE POLICY "Users can remove tags from own documents" ON public.document_tags
  FOR DELETE TO anon, authenticated USING (true);

NOTIFY pgrst, 'reload schema';
