-- =============================================
-- SUPABASE STORAGE POLICIES (bucket: documents)
-- =============================================
-- Chạy file này trong Supabase Dashboard → SQL Editor
--
-- BỐI CẢNH / LÝ DO:
-- Ứng dụng xác thực người dùng bằng Firebase Auth, và CHƯA thiết lập
-- được phiên đăng nhập Supabase (Edge Function "verify-firebase-token"
-- không còn được deploy; project hiện dùng signing key ES256 nên cách
-- ký JWT HS256 bằng legacy secret không còn hiệu lực).
--
-- Vì vậy mọi request lên Supabase đều dùng anon/publishable key và
-- auth.uid() luôn là NULL. Policy cũ yêu cầu:
--     storage.foldername(name)[1] = auth.uid()::text
-- trong khi app upload theo đường dẫn:
--     users/{userId}/documents/{docId}/{uniqueName}
-- => foldername[1] = 'users' != NULL => "new row violates row-level security policy".
--
-- GIẢI PHÁP:
-- Cấp quyền CRUD trên bucket 'documents' cho role anon/authenticated.
-- Phân quyền theo chủ sở hữu tài liệu được thực hiện ở tầng ứng dụng
-- (bảng permissions). LƯU Ý: đây là mức bảo mật tương đương với các
-- bảng public hiện tại (documents/permissions/users đang TẮT RLS).
-- Khi thiết lập xong Supabase Auth thật (third-party auth với Firebase
-- hoặc custom JWT), hãy thay bằng policy kiểm tra auth.uid().

-- 1. Xóa policy cũ
DROP POLICY IF EXISTS "Users can upload own documents" ON storage.objects;
DROP POLICY IF EXISTS "Users can view own documents" ON storage.objects;
DROP POLICY IF EXISTS "Users can update own documents" ON storage.objects;
DROP POLICY IF EXISTS "Users can delete own documents" ON storage.objects;

-- 2. Policy mới cho bucket 'documents'
CREATE POLICY "App can upload documents"
  ON storage.objects FOR INSERT TO anon, authenticated
  WITH CHECK (bucket_id = 'documents');

CREATE POLICY "App can view documents"
  ON storage.objects FOR SELECT TO anon, authenticated
  USING (bucket_id = 'documents');

CREATE POLICY "App can update documents"
  ON storage.objects FOR UPDATE TO anon, authenticated
  USING (bucket_id = 'documents')
  WITH CHECK (bucket_id = 'documents');

CREATE POLICY "App can delete documents"
  ON storage.objects FOR DELETE TO anon, authenticated
  USING (bucket_id = 'documents');
