# BÁO CÁO THỰC HIỆN NHIỆM VỤ — MINH

- **Ngày báo cáo:** 20/10/2026
- **Người thực hiện:** Minh (nhóm trưởng) — Nhóm 03, lớp 65KTPM
- **Nhánh làm việc:** `nhom/nhom03-65ktpm`
- **Commit gần nhất trước báo cáo:** `00469f1`
- **Môi trường:** Flutter 3.47.5 · Android 13 (Waydroid) · Chrome/Web

---

## 1. Nhiệm vụ được giao

Theo `task.pdf`, Minh đảm nhận:

1. **#1 — Kiến trúc và mô hình dữ liệu:** sơ đồ kiến trúc, schema + RLS, interface service, `ARCHITECTURE.md`, FCM.
2. **#2 — Giao diện Flutter đa nền tảng:** giao diện responsive cho Mobile và Web.

Nhiệm vụ trọng tâm được giao trong phiên này là **hoàn thiện phần #2 (UI responsive)** cùng luồng đăng nhập, điều hướng và các trạng thái loading/empty/error, đảm bảo chạy được trên Android và Web, đồng thời tuân thủ quy định nộp bài của môn học.

---

## 2. Kết quả thực hiện

### 2.1. Các màn hình đã hoàn thiện

| # | Màn hình / khối chức năng | Nội dung đã làm | Tệp chính |
|---|---|---|---|
| 1 | Đăng nhập / Đăng ký | Email + mật khẩu, đăng ký có nhập lại mật khẩu, Google, khách; validate; trạng thái loading và báo lỗi thân thiện | `lib/pages/login_page.dart` |
| 2 | AuthGate + khởi tạo phiên | Khôi phục phiên Firebase, đồng bộ người dùng sang Supabase, điều hướng vào app | `lib/pages/auth_gate.dart`, `lib/functions.dart` |
| 3 | Khung ứng dụng | BottomNavigationBar ở mobile ↔ NavigationRail ở tablet/desktop; giới hạn chiều rộng nội dung trên Web | `lib/pages/app_shell.dart`, `lib/widgets/responsive_scaffold.dart` |
| 4 | Trang chủ | Lời chào, 3 thẻ thống kê, tài liệu gần đây, thao tác nhanh | `lib/pages/home_page.dart` |
| 5 | Danh sách tài liệu | Tìm kiếm, lọc theo danh mục, chip lọc, lưới 1–4 cột, cập nhật realtime, empty/loading/error | `lib/pages/document_list_page.dart`, `lib/widgets/document_grid.dart` |
| 6 | Chi tiết tài liệu | Metadata, mở tệp, chỉnh sửa, chia sẻ, xóa, xử lý lỗi | `lib/pages/document_detail_page.dart` |
| 7 | Thêm / sửa tài liệu | Form 1↔2 cột, nút lưu cố định ở mobile, validate, tiến trình tải tệp | `lib/pages/document_form_page.dart` |
| 8 | Trạng thái dùng chung | Loading, empty, error kèm nút thử lại | `lib/widgets/state_views.dart`, `empty_component.dart` |
| 9 | Tài khoản | Menu người dùng, thông tin tài khoản, đăng xuất | `lib/widgets/user_menu_button.dart` |

### 2.2. Responsive

- **Breakpoint:** `< 600` compact · `600–1024` medium · `>= 1024` expanded.
- **Lưới tài liệu:** 1 / 2 / 3 / 4 cột (4 cột từ 1500px).
- **Điều hướng:** bottom navigation ↔ navigation rail.
- **Form:** 1 cột ở mobile, 2 cột từ medium; nút lưu dính đáy ở compact.
- **Padding:** 16 / 24 / 32 theo breakpoint; nội dung giới hạn tối đa 1200px trên Web.
- **Đã kiểm tra:** widget test ở 360 / 768 / 1440px; Flutter Web ở 390 / 720 / 900 / 1440px; Waydroid Android 13.

### 2.3. Đăng nhập và dữ liệu

- Firebase Auth: email/mật khẩu, Google, khách (anonymous).
- `syncSessionWithSupabase` đồng bộ người dùng sau khi đăng nhập.
- Ánh xạ lỗi Firebase sang thông báo tiếng Việt.
- Supabase: tài liệu, danh mục, quyền chia sẻ, Storage.

### 2.4. Kiểm thử và xác minh

| Hạng mục | Kết quả |
|---|---|
| `flutter analyze` | **0 error**, 1 warning (có sẵn: biến `uploadResult` không dùng), 30 info |
| `flutter test` | **9/9 test đạt** (kiến trúc + widget + responsive 360/768/1440 + form đăng ký) |
| Build Android | APK debug build thành công |
| Build Web | Chạy và kiểm tra bằng `flutter run -d web-server` |
| Triển khai | Cài và chạy trên Waydroid Android 13 (`com.example.code`) |
| Kiểm tra thực tế | Trang chủ 3 thẻ thống kê, danh sách/tìm kiếm/chip lọc, chi tiết, form sửa có nút lưu dính đáy |

Log chi tiết: `code/.run_reports/` (không đưa lên git).

### 2.5. Git và quy định nộp bài

- Làm việc đúng nhánh `nhom/nhom03-65ktpm`; **không push lên `main`**.
- Toàn bộ mã nguồn và tài liệu nằm trong `nhom03-65ktpm/`.
- Có `danhsachnhom.md` (còn thông tin `[Cập nhật]`).
- Không track `build/`, `.dart_tool/`, `.env`, keystore; không có tệp > 50MB.
- Commit đúng format, ví dụ:
  - `7a8d335 feat(nhom03-65ktpm): hoan thien giao dien responsive va chuyen ma nguon vao thu muc nhom`
  - `860d057 feat(nhom03-65ktpm): them script bao cao ket qua chay ra console`
  - `d5ea00d fix(nhom03-65ktpm): khoi phuc tai lieu huong dan trien khai`
  - `00469f1 feat(nhom03-65ktpm): them kiem tra quy dinh nop bai truoc khi push`
- Đã mở PR nội bộ #1: `nhom/nhom03-65ktpm` → `main` (repo `Minh-lab/document-management`).

Công cụ kiểm tra: `code/tool/check_submission.sh` — kiểm tra nhánh, thư mục nhóm, phạm vi thay đổi, file rác, file lớn và `danhsachnhom.md`.

---

## 3. Tồn đọng

| # | Hạng mục | Ghi chú |
|---|---|---|
| 1 | Thông tin thành viên trong `danhsachnhom.md` | Còn `[Cập nhật]`: họ tên đầy đủ, MSSV, giảng viên hướng dẫn |
| 2 | PR chính thức tới repo môn học | Chưa tạo fork/PR tới `oanhcuongdo/project-ptuddd`; PR #1 hiện chỉ trong repo nhóm |
| 3 | Phần #1 — schema v2 + RLS | Chưa có bảng `tags`, `document_tags`, `document_locations`, `borrow_requests`, `document_views`, `user_interests`, `device_tokens` |
| 4 | Phần #1 — tài liệu kiến trúc | Chưa viết `docs/ARCHITECTURE.md`, chưa công bố interface service, chưa có FCM |
| 5 | Cảnh báo analyzer | 1 warning có sẵn trong `supabase_storage_service.dart` |
| 6 | Kiểm thử đăng nhập/đăng xuất trên thiết bị | Chưa chạy end-to-end trên Waydroid (giữ phiên để tránh mất dữ liệu) |

---

## 4. Đề xuất bước tiếp theo

1. Bổ sung đầy đủ thông tin thành viên và giảng viên vào `danhsachnhom.md`.
2. Xác nhận nộp bài để tạo fork + PR chính thức tới `oanhcuongdo/project-ptuddd`.
3. Hoàn thiện #1: schema v2 + RLS cho các bảng mới, `ARCHITECTURE.md`, interface service, FCM.
4. Sửa warning analyzer và bổ sung kiểm thử đăng nhập/đăng xuất trên thiết bị.

---

## 5. Kết luận

Phần **#2 — giao diện Flutter đa nền tảng** đã hoàn thiện ở mức có thể review: đủ màn hình, điều hướng, responsive theo 3 breakpoint, các trạng thái loading/empty/error, chạy được trên Android và Web, test và analyze đạt yêu cầu. Phần **#1 — kiến trúc và mô hình dữ liệu** mới hoàn thành phần nền tảng (auth + schema hiện có), cần bổ sung schema v2, RLS, tài liệu kiến trúc và FCM.
