-- =============================================
-- SUPABASE RLS POLICIES FOR FIREBASE AUTH
-- =============================================
-- Chạy file này trong Supabase Dashboard → SQL Editor
-- Lưu ý: Cần config Custom JWT hoặc dùng Supabase Auth để RLS hoạt động đầy đủ

-- =============================================
-- 1. TẠO FUNCTION LẤY CURRENT USER ID
-- =============================================
-- Function này lấy user_id từ request headers (gửi từ client)
-- Client cần gửi header: x-user-id: <firebase_uid>
CREATE OR REPLACE FUNCTION current_user_id()
RETURNS text LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
  uid text;
BEGIN
  -- Thử lấy từ request header (cần config PostgREST để forward header)
  uid := current_setting('request.headers.x-user-id', true);
  IF uid IS NOT NULL AND uid != '' THEN
    RETURN uid;
  END IF;
  
  -- Fallback: thử lấy từ auth.uid() (Supabase Auth)
  uid := auth.uid()::text;
  IF uid IS NOT NULL AND uid != '' THEN
    RETURN uid;
  END IF;
  
  RETURN NULL;
END;
$$;

-- =============================================
-- 2. ENABLE RLS
-- =============================================
ALTER TABLE users ENABLE ROW LEVEL SECURITY;
ALTER TABLE categories ENABLE ROW LEVEL SECURITY;
ALTER TABLE documents ENABLE ROW LEVEL SECURITY;
ALTER TABLE permissions ENABLE ROW LEVEL SECURITY;

-- =============================================
-- 3. XÓA POLICY CŨ
-- =============================================
DROP POLICY IF EXISTS "Users can view own profile" ON users;
DROP POLICY IF EXISTS "Users can update own profile" ON users;
DROP POLICY IF EXISTS "Users can insert own profile" ON users;

DROP POLICY IF EXISTS "Categories are viewable by authenticated users" ON categories;

DROP POLICY IF EXISTS "Owners can view own documents" ON documents;
DROP POLICY IF EXISTS "Owners can insert own documents" ON documents;
DROP POLICY IF EXISTS "Owners can update own documents" ON documents;
DROP POLICY IF EXISTS "Owners can delete own documents" ON documents;
DROP POLICY IF EXISTS "Shared users can view documents" ON documents;
DROP POLICY IF EXISTS "Shared editors can update documents" ON documents;

DROP POLICY IF EXISTS "Owners can manage permissions" ON permissions;
DROP POLICY IF EXISTS "Owners can view permissions" ON permissions;
DROP POLICY IF EXISTS "Owners can insert permissions" ON permissions;
DROP POLICY IF EXISTS "Owners can update permissions" ON permissions;
DROP POLICY IF EXISTS "Owners can delete permissions" ON permissions;
DROP POLICY IF EXISTS "Users can view own permissions" ON permissions;
DROP POLICY IF EXISTS "Grantees can view their permissions" ON permissions;

-- =============================================
-- 4. USERS TABLE POLICIES
-- =============================================
-- User xem profile của mình
CREATE POLICY "Users can view own profile" ON users
  FOR SELECT USING (id = current_user_id());

-- User cập nhật profile của mình
CREATE POLICY "Users can update own profile" ON users
  FOR UPDATE USING (id = current_user_id());

-- User tạo profile (sync từ Firebase Auth)
CREATE POLICY "Users can insert own profile" ON users
  FOR INSERT WITH CHECK (id = current_user_id());

-- =============================================
-- 5. CATEGORIES TABLE POLICIES
-- =============================================
-- Tất cả user đã auth đọc được categories
CREATE POLICY "Categories are viewable by authenticated users" ON categories
  FOR SELECT USING (current_user_id() IS NOT NULL);

-- =============================================
-- 6. DOCUMENTS TABLE POLICIES
-- =============================================
-- Owner CRUD tài liệu của mình
CREATE POLICY "Owners can view own documents" ON documents
  FOR SELECT USING (user_id = current_user_id());

CREATE POLICY "Owners can insert own documents" ON documents
  FOR INSERT WITH CHECK (user_id = current_user_id());

CREATE POLICY "Owners can update own documents" ON documents
  FOR UPDATE USING (user_id = current_user_id());

CREATE POLICY "Owners can delete own documents" ON documents
  FOR DELETE USING (user_id = current_user_id());

-- Shared users (viewer/editor) xem được tài liệu
CREATE POLICY "Shared users can view documents" ON documents
  FOR SELECT USING (
    id IN (
      SELECT document_id FROM permissions
      WHERE user_id = current_user_id()
      AND role IN ('viewer', 'editor', 'owner')
    )
  );

-- Shared editors cập nhật được tài liệu
CREATE POLICY "Shared editors can update documents" ON documents
  FOR UPDATE USING (
    id IN (
      SELECT document_id FROM permissions
      WHERE user_id = current_user_id()
      AND role IN ('editor', 'owner')
    )
  );

-- =============================================
-- 7. PERMISSIONS TABLE POLICIES
-- =============================================
-- Owner quản lý permissions (CRUD) của tài liệu mình sở hữu.
CREATE POLICY "Owners can view permissions" ON permissions
  FOR SELECT USING (
    document_id IN (
      SELECT id FROM documents WHERE user_id = current_user_id()
    )
  );

-- Chỉ được cấp quyền viewer/editor. Bản ghi owner chỉ hợp lệ khi
-- user_id trùng với chủ sở hữu thật của tài liệu (documents.user_id).
CREATE POLICY "Owners can insert permissions" ON permissions
  FOR INSERT WITH CHECK (
    document_id IN (
      SELECT id FROM documents WHERE user_id = current_user_id()
    )
    AND (
      role IN ('viewer', 'editor')
      OR (role = 'owner' AND user_id = (
        SELECT d.user_id FROM documents d WHERE d.id = permissions.document_id
      ))
    )
  );

CREATE POLICY "Owners can update permissions" ON permissions
  FOR UPDATE USING (
    document_id IN (
      SELECT id FROM documents WHERE user_id = current_user_id()
    )
  ) WITH CHECK (
    document_id IN (
      SELECT id FROM documents WHERE user_id = current_user_id()
    )
    AND (
      role IN ('viewer', 'editor')
      OR (role = 'owner' AND user_id = (
        SELECT d.user_id FROM documents d WHERE d.id = permissions.document_id
      ))
    )
  );

-- Không cho phép thu hồi bản ghi quyền chủ sở hữu.
CREATE POLICY "Owners can delete permissions" ON permissions
  FOR DELETE USING (
    document_id IN (
      SELECT id FROM documents WHERE user_id = current_user_id()
    )
    AND role <> 'owner'
  );

-- User xem permission của mình (để biết quyền gì)
CREATE POLICY "Users can view own permissions" ON permissions
  FOR SELECT USING (user_id = current_user_id());

-- Grantee xem permission mình được cấp
CREATE POLICY "Grantees can view their permissions" ON permissions
  FOR SELECT USING (user_id = current_user_id());

-- =============================================
-- 8. CẤU HÌNH POSTGREST ĐỂ FORWARD HEADER
-- =============================================
-- Chạy trong Supabase Dashboard → Settings → API → PostgREST
-- Thêm vào "Custom headers" hoặc config PostgREST:
-- pre-request hook để extract x-user-id header

-- Hoặc dùng Supabase Edge Function để verify Firebase token
-- Xem file: supabase_edge_function_verify_firebase.ts

-- =============================================
-- 9. TẮT RLS CHO DEVELOPMENT (NẾU CẦN)
-- =============================================
-- ALTER TABLE users DISABLE ROW LEVEL SECURITY;
-- ALTER TABLE categories DISABLE ROW LEVEL SECURITY;
-- ALTER TABLE documents DISABLE ROW LEVEL SECURITY;
-- ALTER TABLE permissions DISABLE ROW LEVEL SECURITY;

-- =============================================
-- 10. BẬT LẠI RLS KHI SẴN SÀNG
-- =============================================
-- ALTER TABLE users ENABLE ROW LEVEL SECURITY;
-- ALTER TABLE categories ENABLE ROW LEVEL SECURITY;
-- ALTER TABLE documents ENABLE ROW LEVEL SECURITY;
-- ALTER TABLE permissions ENABLE ROW LEVEL SECURITY;