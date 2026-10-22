-- =============================================
-- SUPABASE DATABASE SCHEMA
-- =============================================
-- Chạy script này trong Supabase Dashboard → SQL Editor

-- =============================================
-- CATEGORIES TABLE
-- =============================================
CREATE TABLE IF NOT EXISTS categories (
  id BIGSERIAL PRIMARY KEY,
  name TEXT NOT NULL UNIQUE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- =============================================
-- DOCUMENTS TABLE
-- =============================================
CREATE TABLE IF NOT EXISTS documents (
  id BIGSERIAL PRIMARY KEY,
  title TEXT NOT NULL,
  description TEXT,
  file_path TEXT,           -- Local file path (optional)
  file_url TEXT,            -- Firebase Storage download URL
  storage_path TEXT,        -- Firebase Storage path (e.g., users/{uid}/documents/{docId}/{filename})
  category_id BIGINT NOT NULL REFERENCES categories(id),
  user_id TEXT NOT NULL,    -- Firebase Auth UID
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- =============================================
-- TAGS AND DOCUMENT-TAG RELATION
-- =============================================
CREATE TABLE IF NOT EXISTS tags (
  id BIGSERIAL PRIMARY KEY,
  name TEXT NOT NULL UNIQUE,
  color TEXT
);

CREATE TABLE IF NOT EXISTS document_tags (
  document_id BIGINT NOT NULL REFERENCES documents(id) ON DELETE CASCADE,
  tag_id BIGINT NOT NULL REFERENCES tags(id) ON DELETE CASCADE,
  PRIMARY KEY (document_id, tag_id)
);

CREATE INDEX IF NOT EXISTS idx_document_tags_tag_id
  ON document_tags(tag_id);

-- Indexes for better query performance
CREATE INDEX IF NOT EXISTS idx_documents_user_id ON documents(user_id);
CREATE INDEX IF NOT EXISTS idx_documents_category_id ON documents(category_id);
CREATE INDEX IF NOT EXISTS idx_documents_created_at ON documents(created_at DESC);

-- =============================================
-- ROW LEVEL SECURITY (RLS)
-- =============================================
ALTER TABLE categories ENABLE ROW LEVEL SECURITY;
ALTER TABLE documents ENABLE ROW LEVEL SECURITY;
ALTER TABLE tags ENABLE ROW LEVEL SECURITY;
ALTER TABLE document_tags ENABLE ROW LEVEL SECURITY;

-- Categories: everyone can read, only authenticated can insert (admin only in practice)
CREATE POLICY "Categories are viewable by everyone" ON categories
  FOR SELECT USING (true);

-- Documents: users can only access their own documents
CREATE POLICY "Users can view own documents" ON documents
  FOR SELECT USING (auth.uid()::text = user_id);

CREATE POLICY "Users can insert own documents" ON documents
  FOR INSERT WITH CHECK (auth.uid()::text = user_id);

CREATE POLICY "Users can update own documents" ON documents
  FOR UPDATE USING (auth.uid()::text = user_id);

CREATE POLICY "Users can delete own documents" ON documents
  FOR DELETE USING (auth.uid()::text = user_id);

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

-- =============================================
-- TRIGGERS FOR updated_at
-- =============================================
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ language 'plpgsql';

CREATE TRIGGER update_documents_updated_at
  BEFORE UPDATE ON documents
  FOR EACH ROW
  EXECUTE FUNCTION update_updated_at_column();

-- =============================================
-- SEED DEFAULT CATEGORIES
-- =============================================
INSERT INTO categories (name) VALUES 
  ('Bài giảng'),
  ('Bài tập'),
  ('Tham khảo')
ON CONFLICT (name) DO NOTHING;

-- =============================================
-- REALTIME PUBLICATION (for live updates)
-- =============================================
ALTER PUBLICATION supabase_realtime ADD TABLE documents;
ALTER PUBLICATION supabase_realtime ADD TABLE categories;

-- =============================================
-- STORAGE BUCKET SETUP (run in Supabase Storage)
-- =============================================
-- Tạo bucket 'documents' với cấu trúc:
-- buckets/documents/users/{userId}/documents/{docId}/{filename}
-- 
-- CORS config cho Firebase Storage cross-origin:
-- [
--   {
--     "origin": "*",
--     "method": ["GET", "POST", "PUT", "DELETE"],
--     "responseHeader": ["Content-Type", "Authorization"],
--     "maxAgeSeconds": 3600
--   }
-- ]