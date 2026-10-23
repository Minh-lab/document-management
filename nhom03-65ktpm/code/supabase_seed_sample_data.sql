-- =============================================
-- DỮ LIỆU MẪU (SEED DATA) CHO ỨNG DỤNG QUẢN LÝ TÀI LIỆU
-- Chạy trong Supabase Dashboard → SQL Editor (sau khi đã chạy
-- supabase_schema.sql, supabase_notifications.sql và tạo bảng users/permissions).
--
-- Đặc điểm:
--   * Tự lấy user đầu tiên trong bảng public.users làm chủ sở hữu.
--   * Bỏ qua (không chèn trùng) nếu user đó đã có dữ liệu mẫu.
--   * Nếu có từ 2 user trở lên, tự chia sẻ vài tài liệu cho user thứ 2
--     để demo tính năng chia sẻ (viewer/editor).
--   * Có thể chạy lại nhiều lần mà không nhân đôi dữ liệu.
-- =============================================

do $$
declare
  v_uid        text;
  v_uid2       text;
  v_cat_bg     bigint;
  v_cat_bt     bigint;
  v_cat_tk     bigint;
  v_doc_bg1    bigint;
  v_doc_bg2    bigint;
  v_doc_bg3    bigint;
  v_doc_bg4    bigint;
  v_doc_bt1    bigint;
  v_doc_bt2    bigint;
  v_doc_bt3    bigint;
  v_doc_bt4    bigint;
  v_doc_tk1    bigint;
  v_doc_tk2    bigint;
  v_doc_tk3    bigint;
  v_doc_tk4    bigint;
begin
  -- ===========================================
  -- 1. XÁC ĐỊNH USER SỞ HỮU DỮ LIỆU MẪU
  -- ===========================================
  select id
    into v_uid
    from public.users
   order by created_at asc nulls last
   limit 1;

  if v_uid is null then
    raise exception
      'Bảng public.users đang trống. Hãy đăng nhập app ít nhất một lần (hoặc tạo user) rồi chạy lại script.';
  end if;

  raise notice 'Tạo dữ liệu mẫu cho user: %', v_uid;

  -- Chỉ bỏ qua khi dữ liệu mẫu đã tồn tại, để không chèn trùng.
  -- (Không chặn nếu user đã có tài liệu khác do người dùng tự tạo.)
  if exists (
    select 1 from public.documents
     where user_id = v_uid
       and title = 'Bài giảng Giải tích 1 - Chương 3: Tích phân'
  ) then
    raise notice 'User % đã có dữ liệu mẫu, bỏ qua.', v_uid;
    return;
  end if;

  -- ===========================================
  -- 2. DANH MỤC (đã có sẵn từ schema, đảm bảo tồn tại)
  -- ===========================================
  insert into public.categories (name) values
    ('Bài giảng'), ('Bài tập'), ('Tham khảo')
  on conflict (name) do nothing;

  select id into v_cat_bg from public.categories where name = 'Bài giảng';
  select id into v_cat_bt from public.categories where name = 'Bài tập';
  select id into v_cat_tk from public.categories where name = 'Tham khảo';

  -- ===========================================
  -- 3. TÀI LIỆU MẪU
  -- ===========================================
  -- ----- Bài giảng -----
  insert into public.documents
    (title, description, category_id, user_id, created_at, updated_at)
  values
    ('Bài giảng Giải tích 1 - Chương 3: Tích phân',
     'Tóm tắt định nghĩa tích phân, các phương pháp tính và ví dụ minh họa kèm bài tập tự luyện.',
     v_cat_bg, v_uid, now() - interval '18 days', now() - interval '18 days')
  returning id into v_doc_bg1;

  insert into public.documents
    (title, description, category_id, user_id, created_at, updated_at)
  values
    ('Slide Lập trình hướng đối tượng - Tuần 5',
     'Kế thừa, đa hình và interface trong Dart. Có ví dụ code minh họa trên lớp.',
     v_cat_bg, v_uid, now() - interval '14 days', now() - interval '13 days')
  returning id into v_doc_bg2;

  insert into public.documents
    (title, description, category_id, user_id, created_at, updated_at)
  values
    ('Bài giảng Cơ sở dữ liệu - Chuẩn hóa 3NF',
     'Quy trình chuẩn hóa dữ liệu từ 1NF đến 3NF, kèm bài tập chuyển đổi sơ đồ quan hệ.',
     v_cat_bg, v_uid, now() - interval '10 days', now() - interval '10 days')
  returning id into v_doc_bg3;

  insert into public.documents
    (title, description, category_id, user_id, created_at, updated_at)
  values
    ('Ghi chú Kiến trúc máy tính - Chương 2',
     'Cấu trúc CPU, tập lệnh và cơ chế pipeline. Tài liệu tự ghi chú khi học trên lớp.',
     v_cat_bg, v_uid, now() - interval '7 days', now() - interval '7 days')
  returning id into v_doc_bg4;

  -- ----- Bài tập -----
  insert into public.documents
    (title, description, category_id, user_id, created_at, updated_at)
  values
    ('Bài tập lớn Lập trình di động',
     'Yêu cầu xây dựng ứng dụng quản lý tài liệu bằng Flutter, nộp kèm báo cáo và video demo.',
     v_cat_bt, v_uid, now() - interval '12 days', now() - interval '5 days')
  returning id into v_doc_bt1;

  insert into public.documents
    (title, description, category_id, user_id, created_at, updated_at)
  values
    ('Đề cương ôn tập Giải tích giữa kỳ',
     'Tổng hợp dạng bài trọng tâm: giới hạn, đạo hàm, tích phân và ứng dụng.',
     v_cat_bt, v_uid, now() - interval '9 days', now() - interval '9 days')
  returning id into v_doc_bt2;

  insert into public.documents
    (title, description, category_id, user_id, created_at, updated_at)
  values
    ('Bài tập nhóm Cơ sở dữ liệu - Tuần 8',
     'Thiết kế ERD và viết truy vấn SQL cho hệ thống quản lý thư viện.',
     v_cat_bt, v_uid, now() - interval '6 days', now() - interval '4 days')
  returning id into v_doc_bt3;

  insert into public.documents
    (title, description, category_id, user_id, created_at, updated_at)
  values
    ('Đáp án bài tập Xác suất thống kê',
     'Lời giải chi tiết chương 4 và 5, dùng để đối chiếu sau khi tự làm bài.',
     v_cat_bt, v_uid, now() - interval '3 days', now() - interval '3 days')
  returning id into v_doc_bt4;

  -- ----- Tham khảo -----
  insert into public.documents
    (title, description, category_id, user_id, created_at, updated_at)
  values
    ('Giáo trình Kinh tế vĩ mô (PDF)',
     'Tài liệu tham khảo môn Kinh tế vĩ mô, bản PDF đầy đủ dùng cho học kỳ này.',
     v_cat_tk, v_uid, now() - interval '20 days', now() - interval '20 days')
  returning id into v_doc_tk1;

  insert into public.documents
    (title, description, category_id, user_id, created_at, updated_at)
  values
    ('Tài liệu tham khảo Flutter & Dart',
     'Tổng hợp link documentation, video hướng dẫn và các package hữu ích cho đồ án.',
     v_cat_tk, v_uid, now() - interval '8 days', now() - interval '2 days')
  returning id into v_doc_tk2;

  insert into public.documents
    (title, description, category_id, user_id, created_at, updated_at)
  values
    ('Đề thi mẫu Tiếng Anh B1',
     'Đề thi thử kèm đáp án, dùng để luyện kỹ năng đọc và nghe trước kỳ thi.',
     v_cat_tk, v_uid, now() - interval '5 days', now() - interval '5 days')
  returning id into v_doc_tk3;

  insert into public.documents
    (title, description, category_id, user_id, created_at, updated_at)
  values
    ('Sổ tay kỹ năng thuyết trình',
     'Mẹo chuẩn bị slide, luyện nói và xử lý câu hỏi khi báo cáo nhóm.',
     v_cat_tk, v_uid, now() - interval '1 day', now() - interval '1 day')
  returning id into v_doc_tk4;

  -- ===========================================
  -- 4. QUYỀN OWNER CHO CÁC TÀI LIỆU MẪU
  -- ===========================================
  if to_regclass('public.permissions') is not null then
    insert into public.permissions (document_id, user_id, role, granted_by)
    select d.id, v_uid, 'owner', v_uid
      from public.documents d
     where d.id in (
       v_doc_bg1, v_doc_bg2, v_doc_bg3, v_doc_bg4,
       v_doc_bt1, v_doc_bt2, v_doc_bt3, v_doc_bt4,
       v_doc_tk1, v_doc_tk2, v_doc_tk3, v_doc_tk4
     )
       and not exists (
         select 1 from public.permissions p
          where p.document_id = d.id and p.user_id = v_uid
       );
  else
    raise notice 'Không tìm thấy bảng public.permissions, bỏ qua bước tạo quyền owner.';
  end if;

  -- ===========================================
  -- 5. CHIA SẺ THỬ VỚI USER THỨ 2 (NẾU CÓ)
  -- ===========================================
  select id
    into v_uid2
    from public.users
   where id <> v_uid
   order by created_at asc nulls last
   limit 1;

  if v_uid2 is not null and to_regclass('public.permissions') is not null then
    insert into public.permissions (document_id, user_id, role, granted_by)
    values
      (v_doc_bt1, v_uid2, 'editor', v_uid),
      (v_doc_tk2, v_uid2, 'viewer', v_uid)
    on conflict (document_id, user_id) do nothing;
  end if;

  -- ===========================================
  -- 6. THÔNG BÁO MẪU
  -- ===========================================
  if to_regclass('public.notifications') is not null then
    insert into public.notifications
      (user_id, title, body, type, document_id, is_read, created_at)
    values
      (v_uid,
       'Tài liệu mới được thêm',
       'Bài giảng Giải tích 1 - Chương 3: Tích phân đã được thêm vào thư viện.',
       'document', v_doc_bg1, true, now() - interval '18 days'),
      (v_uid,
       'Nhắc nộp bài tập lớn',
       'Hạn nộp bài tập lớn Lập trình di động còn 3 ngày. Bạn nhớ kiểm tra lại báo cáo nhé!',
       'system', v_doc_bt1, false, now() - interval '5 days'),
      (v_uid,
       'Bài tập nhóm đã được cập nhật',
       'Bài tập nhóm Cơ sở dữ liệu - Tuần 8 vừa được chỉnh sửa nội dung.',
       'document', v_doc_bt3, false, now() - interval '4 days'),
      (v_uid,
       'Đề cương ôn tập giữa kỳ',
       'Đề cương ôn tập Giải tích giữa kỳ đã sẵn sàng để tải về.',
       'document', v_doc_bt2, true, now() - interval '9 days'),
      (v_uid,
       'Tài liệu tham khảo mới',
       'Tài liệu tham khảo Flutter & Dart vừa được thêm vào danh mục Tham khảo.',
       'document', v_doc_tk2, false, now() - interval '2 days'),
      (v_uid,
       'Chào mừng đến với ứng dụng',
       'Hãy bắt đầu bằng cách thêm tài liệu đầu tiên của bạn vào thư viện.',
       'system', null, true, now() - interval '21 days');

    if v_uid2 is not null then
      insert into public.notifications
        (user_id, title, body, type, document_id, is_read, created_at)
      values
        (v_uid2,
         'Bạn được chia sẻ tài liệu',
         'Bạn có quyền chỉnh sửa tài liệu "Bài tập lớn Lập trình di động".',
         'share', v_doc_bt1, false, now() - interval '1 day'),
        (v_uid2,
         'Bạn được chia sẻ tài liệu',
         'Bạn có quyền xem tài liệu "Tài liệu tham khảo Flutter & Dart".',
         'share', v_doc_tk2, false, now() - interval '1 day');
    end if;
  else
    raise notice 'Không tìm thấy bảng public.notifications, bỏ qua bước tạo thông báo.';
  end if;

  raise notice 'Đã tạo xong dữ liệu mẫu cho user %.', v_uid;
end $$;

-- =============================================
-- KIỂM TRA NHANH
-- =============================================
select c.name as danh_muc, count(d.id) as so_tai_lieu
  from public.categories c
  left join public.documents d on d.category_id = c.id
 group by c.name
 order by c.name;

select id, title, category_id, created_at
  from public.documents
 order by created_at desc
 limit 15;

-- =============================================
-- (TÙY CHỌN) XÓA DỮ LIỆU MẪU
-- Bỏ comment khối dưới và chạy nếu muốn dọn sạch dữ liệu mẫu.
-- Script chỉ xóa đúng các tiêu đề mẫu của user đầu tiên.
-- =============================================
-- do $$
-- declare
--   v_uid text;
-- begin
--   select id into v_uid from public.users order by created_at asc nulls last limit 1;
--   if v_uid is null then return; end if;
--
--   delete from public.documents
--    where user_id = v_uid
--      and title in (
--        'Bài giảng Giải tích 1 - Chương 3: Tích phân',
--        'Slide Lập trình hướng đối tượng - Tuần 5',
--        'Bài giảng Cơ sở dữ liệu - Chuẩn hóa 3NF',
--        'Ghi chú Kiến trúc máy tính - Chương 2',
--        'Bài tập lớn Lập trình di động',
--        'Đề cương ôn tập Giải tích giữa kỳ',
--        'Bài tập nhóm Cơ sở dữ liệu - Tuần 8',
--        'Đáp án bài tập Xác suất thống kê',
--        'Giáo trình Kinh tế vĩ mô (PDF)',
--        'Tài liệu tham khảo Flutter & Dart',
--        'Đề thi mẫu Tiếng Anh B1',
--        'Sổ tay kỹ năng thuyết trình'
--      );
-- end $$;
