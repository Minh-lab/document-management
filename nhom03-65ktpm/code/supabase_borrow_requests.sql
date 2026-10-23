-- =============================================
-- UC-08 / UC-09 / UC-10: QUYỀN CHO LUỒNG MƯỢN & CHIA SẺ
-- Chạy trong Supabase Dashboard → SQL Editor
-- =============================================
-- Bối cảnh:
--   * Ứng dụng đăng nhập bằng Firebase Auth. Edge Function
--     `verify-firebase-token` ký Supabase JWT với `sub` = Firebase UID
--     (ví dụ: FK4uswn0fqgdvscYjA2aEV7QBU22 – KHÔNG phải UUID).
--   * `auth.uid()` của Supabase ép kiểu `sub` sang uuid nên sẽ báo lỗi
--     "invalid input syntax for type uuid" với UID kiểu Firebase.
--   * Các policy/trigger của bảng `borrow_requests` đang dùng auth.uid()
--     nên toàn bộ luồng mượn tài liệu bị chặn.
--
-- Cách xử lý: thêm hàm lấy danh tính dạng TEXT (không ép uuid), rồi
-- cho policy + trigger dùng hàm này.
--
-- Hàm trả về theo thứ tự ưu tiên:
--   1. `request.jwt.claim.sub`  (Supabase JWT do Edge Function phát hành)
--   2. `request.jwt.claims` -> 'sub'
--   3. Header `x-user-id` (nếu client gửi trực tiếp)
-- =============================================

-- ---------------------------------------------
-- 1. HÀM DANH TÍNH DẠNG TEXT (Firebase UID)
-- ---------------------------------------------
CREATE OR REPLACE FUNCTION public.current_firebase_uid()
RETURNS text
LANGUAGE sql
STABLE
AS $$
  SELECT COALESCE(
    NULLIF(current_setting('request.jwt.claim.sub', true), ''),
    NULLIF(current_setting('request.jwt.claims', true), '')::jsonb ->> 'sub',
    NULLIF(current_setting('request.headers.x-user-id', true), '')
  );
$$;

GRANT EXECUTE ON FUNCTION public.current_firebase_uid() TO anon, authenticated;

-- Sửa current_user_id() để không còn gọi auth.uid() (tránh lỗi ép uuid).
CREATE OR REPLACE FUNCTION public.current_user_id()
RETURNS text
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT public.current_firebase_uid();
$$;

GRANT EXECUTE ON FUNCTION public.current_user_id() TO anon, authenticated;

-- ---------------------------------------------
-- 2. BẢO ĐẢM RLS ĐƯỢC BẬT
-- ---------------------------------------------
ALTER TABLE public.borrow_requests ENABLE ROW LEVEL SECURITY;

-- ---------------------------------------------
-- 3. XOÁ POLICY CŨ
-- ---------------------------------------------
DROP POLICY IF EXISTS "Borrow requests are visible to participants" ON public.borrow_requests;
DROP POLICY IF EXISTS "Borrow requests are readable" ON public.borrow_requests;
DROP POLICY IF EXISTS "Borrow requests are insertable" ON public.borrow_requests;
DROP POLICY IF EXISTS "Borrow requests are updatable" ON public.borrow_requests;
DROP POLICY IF EXISTS "Borrow requests are deletable" ON public.borrow_requests;

-- ---------------------------------------------
-- 4. POLICY CHO NGƯỜI THAM GIA (borrower / owner)
-- ---------------------------------------------
-- Vẫn cho phép khi chưa có danh tính (giai đoạn dev, client chưa gửi JWT).
CREATE POLICY "Borrow requests are readable"
  ON public.borrow_requests FOR SELECT
  USING (
    public.current_firebase_uid() IS NULL
    OR borrower_id = public.current_firebase_uid()
    OR owner_id = public.current_firebase_uid()
  );

CREATE POLICY "Borrow requests are insertable"
  ON public.borrow_requests FOR INSERT
  WITH CHECK (
    public.current_firebase_uid() IS NULL
    OR borrower_id = public.current_firebase_uid()
  );

CREATE POLICY "Borrow requests are updatable"
  ON public.borrow_requests FOR UPDATE
  USING (
    public.current_firebase_uid() IS NULL
    OR borrower_id = public.current_firebase_uid()
    OR owner_id = public.current_firebase_uid()
  )
  WITH CHECK (
    public.current_firebase_uid() IS NULL
    OR borrower_id = public.current_firebase_uid()
    OR owner_id = public.current_firebase_uid()
  );

CREATE POLICY "Borrow requests are deletable"
  ON public.borrow_requests FOR DELETE
  USING (
    public.current_firebase_uid() IS NULL
    OR borrower_id = public.current_firebase_uid()
    OR owner_id = public.current_firebase_uid()
  );

-- ---------------------------------------------
-- 5. STATE MACHINE: dùng danh tính TEXT thay auth.uid()
-- ---------------------------------------------
CREATE OR REPLACE FUNCTION public.validate_borrow_request_transition()
RETURNS trigger
LANGUAGE plpgsql
AS $function$
BEGIN
  IF TG_OP = 'INSERT' THEN
    IF NEW.status <> 'pending' THEN
      RAISE EXCEPTION 'Yêu cầu mượn mới phải ở trạng thái chờ duyệt';
    END IF;
    RETURN NEW;
  END IF;

  IF NEW.status = OLD.status THEN
    RETURN NEW;
  END IF;

  IF OLD.status = 'pending' AND NEW.status IN ('approved', 'rejected') THEN
    IF public.current_firebase_uid() IS DISTINCT FROM OLD.owner_id THEN
      RAISE EXCEPTION 'Chỉ chủ tài liệu mới được duyệt yêu cầu';
    END IF;
  ELSIF OLD.status = 'pending' AND NEW.status = 'cancelled' THEN
    IF public.current_firebase_uid() IS DISTINCT FROM OLD.borrower_id THEN
      RAISE EXCEPTION 'Chỉ người mượn mới được hủy yêu cầu';
    END IF;
  ELSIF OLD.status = 'approved' AND NEW.status = 'return_requested' THEN
    IF public.current_firebase_uid() IS DISTINCT FROM OLD.borrower_id THEN
      RAISE EXCEPTION 'Chỉ người mượn mới được báo đã trả';
    END IF;
  ELSIF OLD.status = 'return_requested' AND NEW.status = 'returned' THEN
    IF public.current_firebase_uid() IS DISTINCT FROM OLD.owner_id THEN
      RAISE EXCEPTION 'Chỉ chủ tài liệu mới được xác nhận đã nhận lại';
    END IF;
  ELSIF OLD.status IN ('approved', 'return_requested')
    AND NEW.status = 'expired' THEN
    IF OLD.due_at > NOW() THEN
      RAISE EXCEPTION 'Chỉ yêu cầu đã đến hạn mới được đánh dấu quá hạn';
    END IF;
  ELSE
    RAISE EXCEPTION 'Không thể chuyển trạng thái yêu cầu mượn từ % sang %',
      OLD.status, NEW.status;
  END IF;

  RETURN NEW;
END;
$function$;

-- ---------------------------------------------
-- 6. TỰ ĐỘNG CẬP NHẬT updated_at
-- ---------------------------------------------
CREATE OR REPLACE FUNCTION public.set_borrow_requests_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_borrow_requests_updated_at ON public.borrow_requests;
CREATE TRIGGER trg_borrow_requests_updated_at
  BEFORE UPDATE ON public.borrow_requests
  FOR EACH ROW
  EXECUTE FUNCTION public.set_borrow_requests_updated_at();

-- ---------------------------------------------
-- 7. CẤP QUYỀN BẢNG + SEQUENCE
-- ---------------------------------------------
GRANT SELECT, INSERT, UPDATE, DELETE
  ON public.borrow_requests TO anon, authenticated;

GRANT USAGE, SELECT
  ON SEQUENCE public.borrow_requests_id_seq TO anon, authenticated;

-- Luồng chia sẻ (UC-08) và thông báo (UC-10) dùng các bảng đã có sẵn.
GRANT SELECT, INSERT, UPDATE, DELETE ON public.permissions TO anon, authenticated;
GRANT SELECT, INSERT, UPDATE ON public.notifications TO anon, authenticated;
GRANT SELECT ON public.users TO anon, authenticated;
GRANT SELECT ON public.documents TO anon, authenticated;

-- ---------------------------------------------
-- 8. BẢNG device_tokens (UC-10 – FCM)
-- ---------------------------------------------
CREATE TABLE IF NOT EXISTS public.device_tokens (
  id          bigint GENERATED BY DEFAULT AS IDENTITY PRIMARY KEY,
  user_id     text NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
  token       text NOT NULL,
  platform    text NOT NULL DEFAULT 'unknown'
              CHECK (platform IN ('android', 'ios', 'web', 'unknown')),
  created_at  timestamptz NOT NULL DEFAULT NOW(),
  updated_at  timestamptz NOT NULL DEFAULT NOW(),
  UNIQUE (user_id, token)
);

CREATE INDEX IF NOT EXISTS idx_device_tokens_user_id
  ON public.device_tokens (user_id);

ALTER TABLE public.device_tokens ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Device tokens are readable" ON public.device_tokens;
DROP POLICY IF EXISTS "Device tokens are writable" ON public.device_tokens;
DROP POLICY IF EXISTS "Device tokens are updatable" ON public.device_tokens;
DROP POLICY IF EXISTS "Device tokens are deletable" ON public.device_tokens;

CREATE POLICY "Device tokens are readable"
  ON public.device_tokens FOR SELECT
  USING (
    public.current_firebase_uid() IS NULL
    OR user_id = public.current_firebase_uid()
  );

CREATE POLICY "Device tokens are writable"
  ON public.device_tokens FOR INSERT
  WITH CHECK (
    public.current_firebase_uid() IS NULL
    OR user_id = public.current_firebase_uid()
  );

CREATE POLICY "Device tokens are updatable"
  ON public.device_tokens FOR UPDATE
  USING (
    public.current_firebase_uid() IS NULL
    OR user_id = public.current_firebase_uid()
  );

CREATE POLICY "Device tokens are deletable"
  ON public.device_tokens FOR DELETE
  USING (
    public.current_firebase_uid() IS NULL
    OR user_id = public.current_firebase_uid()
  );

GRANT SELECT, INSERT, UPDATE, DELETE
  ON public.device_tokens TO anon, authenticated;

GRANT USAGE, SELECT
  ON SEQUENCE public.device_tokens_id_seq TO anon, authenticated;

-- ---------------------------------------------
-- 9. REALTIME CHO TRẠNG THÁI YÊU CẦU (tuỳ chọn)
-- ---------------------------------------------
DO $$
BEGIN
  ALTER PUBLICATION supabase_realtime ADD TABLE public.borrow_requests;
EXCEPTION
  WHEN duplicate_object THEN NULL;
END $$;
