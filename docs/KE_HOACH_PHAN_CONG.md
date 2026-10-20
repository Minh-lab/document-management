# KẾ HOẠCH PHÂN CÔNG CÔNG VIỆC

**Dự án:** Ứng dụng Quản lý Tài liệu Học tập (Flutter + Firebase + Supabase)
**Nhóm:** Minh, Đạt, Hạnh, Quân, Đăng
**Repo:** https://github.com/Minh-lab/document-management
**Dùng chung:** Firebase `document-management-f7883` · Supabase `lwebnjcszbldlqwjrcan`

Tài liệu hướng dẫn clone và triển khai: [`HUONG_DAN_TRIEN_KHAI.pdf`](HUONG_DAN_TRIEN_KHAI.pdf)

---

## 1. Hiện trạng so với checklist

| # | Hạng mục | Đã có | Còn thiếu |
|---|---|---|---|
| 1 | Kiến trúc + mô hình dữ liệu Firebase/Supabase | Firebase Auth (anonymous, Google), Supabase documents/categories/permissions, Storage bucket | Bảng cho tag, vị trí, mượn, sở thích; RLS; FCM; tài liệu kiến trúc |
| 2 | UI Flutter đa nền tảng, responsive | UI cơ bản, chạy Android + Web | Breakpoint, layout co giãn, form/dialog responsive |
| 3 | Tag + bản đồ/vị trí | Chỉ có `categories` | `tags`, `document_tags`, `document_locations`, UI tag, bản đồ |
| 4 | Mượn và chia sẻ quyền | Chia sẻ viewer/editor/owner | Luồng yêu cầu mượn, duyệt/từ chối/trả, thông báo |
| 5 | Recommendation | Chưa có | `user_interests`, hàm chấm điểm, khối gợi ý |
| 6 | Kiểm thử + đóng gói | 2 test, chưa có CI | Test plan, test tích hợp, CI, build APK/Web |

---

## 2. Phân công

| Thành viên | Phụ trách | Công việc cụ thể | Khối lượng |
|---|---|---|---|
| **Minh** (nhóm trưởng) | **#1** Kiến trúc và mô hình dữ liệu | Thiết kế sơ đồ kiến trúc; viết schema và RLS; công bố interface service; viết `ARCHITECTURE.md`; review PR; duyệt phát hành. **Không nhận UI và tính năng.** | Ít hơn (thiết kế, review) |
| **Đạt** | **#2** Giao diện đa nền tảng | Breakpoint và `ResponsiveScaffold`; design system; home grid, form, dialog responsive; review UI; build bản Web | Trung bình |
| **Hạnh** | **#3** Tag và vị trí vật lý | Model/service tag; gán và lọc tag; bảng vị trí; bản đồ, chọn vị trí, chỉ đường; xử lý khi mất quyền vị trí | Trung bình |
| **Quân** | **#4** Mượn và chia sẻ quyền | State machine yêu cầu mượn; service và màn hình yêu cầu; mở rộng chia sẻ; tích hợp FCM và thông báo; audit cơ bản | Cao |
| **Đăng** | **#5** Recommendation, **#6** Kiểm thử và đóng gói | Lưu sở thích theo tag; công thức gợi ý; khối "Gợi ý cho bạn"; test plan, unit/widget/integration test; CI; build APK; báo cáo kiểm thử | Cao nhất |

### 2.1. Chi tiết theo người

**Minh — #1**
- Sơ đồ kiến trúc: Flutter → Firebase Auth → Supabase JWT → PostgREST/Storage; FCM cho thông báo.
- Schema v2 + RLS: `tags`, `document_tags`, `document_locations`, `borrow_requests`, `document_views`, `user_interests`, `device_tokens`.
- Công bố interface cho `document`, `tag`, `borrow`, `recommendation` để cả nhóm code song song.
- Review PR, xử lý thay đổi schema, viết `docs/ARCHITECTURE.md`.
- Bàn giao hàm gửi thông báo (Edge Function) cho Quân.

**Đạt — #2**
- `lib/utils/responsive.dart`: `compact < 600`, `medium 600–1024`, `expanded ≥ 1024`.
- `ResponsiveScaffold`: BottomNavigationBar ↔ NavigationRail, giới hạn chiều rộng nội dung trên Web.
- Home grid 1/2/3/4 cột; card hover trên Web; form 1↔2 cột; dialog (Web) ↔ bottom sheet (Mobile).
- Design token, theme, component dùng chung; review UI toàn bộ; build bản Web.

**Hạnh — #3**
- `TagModel`, `tag_service`: CRUD tag, gán/bỏ tag, lọc theo nhiều tag.
- UI chip chọn tag, thanh lọc ở trang chủ, màu tag.
- `document_locations`: latitude, longitude, place_name, shelf, note.
- Bản đồ `flutter_map` + OpenStreetMap, marker, chỉ đường; fallback nhập địa chỉ tay.

**Quân — #4**
- Trạng thái `pending → approved → returned`, nhánh `rejected | cancelled`; `due_date`; chặn mượn trùng.
- `borrow_service`, màn hình "Yêu cầu" kèm badge, chi tiết yêu cầu.
- Mở rộng `share_dialog.dart`: viewer/editor, thu hồi quyền, danh sách người có quyền.
- Tích hợp FCM: yêu cầu mới và kết quả duyệt; audit cơ bản.

**Đăng — #5, #6**
- `user_interests(user_id, tag_id, weight)` cập nhật khi mở/tag/lưu tài liệu.
- Công thức: `0.5×tag_overlap + 0.3×độ_mới + 0.2×lượt_xem`, loại tài liệu của mình và vừa xem.
- Cold start: tag phổ biến + tài liệu mới nhất; khối "Gợi ý cho bạn" kèm lý do.
- Test plan, unit/widget/integration test, test RLS hai tài khoản; CI; build APK; báo cáo kiểm thử.

---

## 3. Phụ thuộc

| Hạng mục chờ | Từ | Đến |
|---|---|---|
| Schema `tags`, `document_tags`, `document_locations` | Minh | Hạnh |
| Bảng `borrow_requests` + interface `borrow_service` | Minh | Quân |
| `user_interests`, `document_views` | Minh | Đăng |
| Breakpoint và component dùng chung | Đạt | Cả nhóm |
| `TagModel` và API lọc tag | Hạnh | Đăng |
| Hàm gửi thông báo (FCM) | Minh | Quân |

Chưa có API thật thì dùng stub đúng chữ ký đã chốt, không chờ nhau.

---

## 4. Dữ liệu mới

| Bảng | Trường chính | Ghi chú |
|---|---|---|
| `tags` | id, name (unique), color | Dùng chung toàn hệ thống |
| `document_tags` | document_id, tag_id | Khóa ghép, cascade delete |
| `document_locations` | document_id (unique), latitude, longitude, place_name, shelf, note | Một tài liệu một vị trí |
| `borrow_requests` | id, document_id, requester_id, owner_id, status, message, requested_at, responded_at, due_date | `status` là enum có check constraint |
| `document_views` | id, document_id, user_id, viewed_at | Nguồn cho lượt xem và loại trừ đã xem |
| `user_interests` | user_id, tag_id, weight | Khóa ghép, weight tăng khi tương tác |
| `device_tokens` | user_id, token, platform | FCM token theo thiết bị |

Bật RLS cho mọi bảng mới; đọc dựa trên `auth.uid()` và bảng `permissions`; chỉ chủ sở hữu được xóa.

---

## 5. Definition of Done

1. Chạy được trên Android **và** Web.
2. Có test cho logic mới; `architecture_test.dart` pass.
3. `flutter analyze` không lỗi.
4. Cập nhật tài liệu liên quan.
5. Không commit secret, `build/`, `.dart_tool/`, `.idea/`.

**Git:** nhánh `feature/<ten>-<viec>`, `fix/<mo-ta>`; commit `feat|fix|docs|test|refactor|chore:`; mọi thay đổi vào `main` qua Pull Request có ít nhất một review.

---

## 6. Rủi ro

| Rủi ro | Phương án |
|---|---|
| Schema thay đổi muộn | Minh chốt sớm, thay đổi phải thông báo ngay trong ngày |
| RLS sai gây lộ dữ liệu | Test âm với hai tài khoản, review chéo policy |
| Khối lượng dồn vào Đăng (recommendation + QA) | Đạt hỗ trợ build Web; mỗi owner tự viết test cho phần mình |
| Minh là điểm nghẽn review | PR nhỏ, review trong ngày; Đạt review UI thay Minh |
| Bản đồ cần API key | Dùng `flutter_map` + OSM, không cần key |
| FCM trên Web cần service worker | Test trên localhost, fallback thông báo trong app |
