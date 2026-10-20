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

-- Indexes for better query performance
CREATE INDEX IF NOT EXISTS idx_documents_user_id ON documents(user_id);
CREATE INDEX IF NOT EXISTS idx_documents_category_id ON documents(category_id);
CREATE INDEX IF NOT EXISTS idx_documents_created_at ON documents(created_at DESC);

-- =============================================
-- ROW LEVEL SECURITY (RLS)
-- =============================================
ALTER TABLE categories ENABLE ROW LEVEL SECURITY;
ALTER TABLE documents ENABLE ROW LEVEL SECURITY;

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