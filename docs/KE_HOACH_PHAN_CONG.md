# KẾ HOẠCH PHÂN CÔNG CÔNG VIỆC

**Dự án:** Ứng dụng Quản lý Tài liệu Học tập (Flutter + Firebase + Supabase)
**Nhóm:** 5 thành viên — Minh, Đạt, Hạnh, Quân, Đăng
**Thời gian:** 6 tuần
**Repo:** https://github.com/Minh-lab/document-management

---

## 1. Hiện trạng mã nguồn so với checklist

| # | Hạng mục checklist | Hiện trạng | Cần làm |
|---|---|---|---|
| 1 | Kiến trúc + mô hình dữ liệu Firebase (Auth/Messaging) & Supabase (DB/Storage) | Đã có: Firebase Auth (anonymous + Google), Edge Function `verify-firebase-token`, Supabase documents/categories/permissions, Storage bucket | Chuẩn hoá sơ đồ kiến trúc, tách lớp service, thêm bảng mới (tag, vị trí, borrow, interest), bật FCM, viết tài liệu kiến trúc |
| 2 | UI Flutter đa nền tảng, responsive Mobile + Web | UI cơ bản chạy được, layout chủ yếu một cột, chưa có breakpoint | Design system, `ResponsiveScaffold`, NavigationRail (web) / BottomNav (mobile), grid co giãn |
| 3 | Tag + bản đồ/vị trí vật lý | Chưa có (chỉ có `categories`) | Bảng `tags`, `document_tags`, `document_locations`; UI chọn tag, lọc theo tag; bản đồ + chọn vị trí |
| 4 | Luồng mượn & chia sẻ quyền | Đã có chia sẻ viewer/editor/owner (`share_dialog.dart`, `permissions`) | Thêm luồng **yêu cầu mượn** (request → approve/reject → trả), thông báo đẩy, ghi log |
| 5 | Recommendation theo sở thích/tag | Chưa có | Lưu `user_interests`, chấm điểm tag overlap + độ mới + lượt xem, hiển thị "Gợi ý cho bạn" |
| 6 | Kiểm thử toàn diện + đóng gói | Có 2 test (architecture, widget); chưa có CI, chưa đóng gói bản phát hành | Test plan, unit/widget/integration/E2E, CI GitHub Actions, build APK + Web, tài liệu phát hành |

---

## 2. Nguyên tắc phân chia

1. **Mỗi hạng mục có đúng 1 người chịu trách nhiệm chính (owner)**, các thành viên khác chỉ đóng góp qua PR và review.
2. **Hợp đồng dữ liệu chốt ở tuần 1** (Minh công bố schema + interface service) để 4 người còn lại không bị chặn.
3. **UI của ai người đó làm**, Đạt chịu trách nhiệm chuẩn responsive và review toàn bộ màn hình.
4. **Ai viết tính năng, người đó viết test** cho tính năng mình; Đăng chịu trách nhiệm test tích hợp/E2E và báo cáo độ phủ.
5. **Không sửa file của người khác** khi chưa báo; mọi thay đổi vào `main` phải qua Pull Request + 1 review.

---

## 3. Bảng phân công tổng quan

| Thành viên | Vai trò | Hạng mục chính | Hạng mục phụ | Ước lượng |
|---|---|---|---|---|
| **Minh** | Nhóm trưởng, kiến trúc & release | #1 Kiến trúc + mô hình dữ liệu | #6 CI, đóng gói, báo cáo | ~22 ngày công |
| **Đạt** | Frontend/UI lead | #2 UI đa nền tảng + responsive | Review UI toàn bộ, design system | ~22 ngày công |
| **Hạnh** | Feature: Tag & vị trí | #3 Tag + bản đồ/vị trí | Migration dữ liệu tag, tìm kiếm theo tag | ~20 ngày công |
| **Quân** | Feature: nghiệp vụ chia sẻ | #4 Mượn & chia sẻ quyền | FCM consume (thông báo), audit log | ~20 ngày công |
| **Đăng** | Data/Recommendation + QA | #5 Recommendation | #6 Test plan, integration/E2E, độ phủ | ~21 ngày công |

---

## 4. Chi tiết từng thành viên

### 4.1. Minh — Kiến trúc hệ thống & mô hình dữ liệu (checklist #1)

**Mục tiêu:** Chốt kiến trúc Firebase + Supabase, schema v2, bảo mật RLS, và là người duy nhất merge các thay đổi schema.

**Công việc:**
- Vẽ sơ đồ kiến trúc tổng thể (Client Flutter → Firebase Auth → Edge Function → Supabase JWT → PostgREST/Storage; FCM cho thông báo).
- Chốt mô hình dữ liệu v2: `tags`, `document_tags`, `document_locations`, `borrow_requests`, `user_interests`, `document_views`, `notifications`, `device_tokens`.
- Viết migration SQL + RLS cho từng bảng (owner/editor/viewer; ai được đọc gì khi tài liệu được chia sẻ).
- Tách `lib/services/supabase_service.dart` (471 dòng) thành các service theo miền: `document_service`, `share_service`, `tag_service`, `borrow_service`, `recommendation_service` — công bố interface cho cả nhóm.
- Bật **Firebase Cloud Messaging**: cấu hình Android/Web, service worker web, lưu `device_tokens`, hàm gửi thông báo trong Edge Function (`notify`).
- Viết `docs/ARCHITECTURE.md` + cập nhật `docs/SPEC.md`.

**File phụ trách:** `code/supabase_schema.sql`, `code/supabase_rls_policies.sql`, `code/supabase/functions/**`, `code/lib/services/supabase_service.dart` (điều phối tách file), `code/lib/config/**`, `docs/ARCHITECTURE.md`.

**Bàn giao (DoD):** Schema chạy được trên Supabase; RLS có test âm (user A không đọc được tài liệu private của B); sơ đồ kiến trúc + bảng dữ liệu được nhóm review; FCM test gửi được 1 thông báo thật.

---

### 4.2. Đạt — Giao diện đa nền tảng & responsive (checklist #2)

**Mục tiêu:** Một codebase chạy tốt cả Mobile và Web, không vỡ layout ở 3 kích thước chuẩn.

**Công việc:**
- Xây `lib/utils/responsive.dart`: breakpoint `compact < 600`, `medium 600–1024`, `expanded ≥ 1024`.
- `ResponsiveScaffold`: BottomNavigationBar (mobile) ↔ NavigationRail (tablet/web) ↔ side drawer; `maxContentWidth` cho web.
- Chuyển `home_page.dart` sang `SliverGrid` co giãn (1/2/3/4 cột theo breakpoint), `document_card.dart` hỗ trợ hover/chuột phải trên web.
- Form (`document_form_page.dart`) 1 cột ↔ 2 cột; dialog chia sẻ dùng `Dialog` trên web, `BottomSheet` trên mobile.
- Design system: `AppColors`, typography, `AppTheme` (light/dark), component dùng chung (button, input, empty state).
- Xử lý bàn phím/scroll trên mobile, `SafeArea`, `MediaQuery` text scale; kiểm tra `flutter run -d chrome` + emulator.
- Viết widget test cho layout ở 3 breakpoint.

**File phụ trách:** `code/lib/pages/**`, `code/lib/widgets/**`, `code/lib/colors.dart`, `code/lib/main.dart` (theme), `code/lib/utils/responsive.dart`.

**DoD:** Ảnh chụp 3 breakpoint (360px, 768px, 1440px) cho mỗi màn hình chính; không có overflow warning; widget test layout pass; checklist accessibility cơ bản (tap target ≥ 48dp, contrast).

---

### 4.3. Hạnh — Tag & bản đồ/vị trí vật lý (checklist #3)

**Mục tiêu:** Phân loại tài liệu đa nhãn và ghi nhớ tài liệu đang nằm ở đâu (kệ, phòng, toạ độ).

**Công việc:**
- Model + service: `TagModel`, `tag_service` (CRUD tag, gán/bỏ tag, lọc theo nhiều tag).
- UI: chip chọn tag trong form tài liệu, thanh lọc tag ở trang chủ, màu tag, tìm kiếm theo tag.
- Vị trí: `document_locations` (latitude, longitude, place_name, shelf/note) + màn hình chọn vị trí.
- Tích hợp bản đồ: `flutter_map` + OpenStreetMap (không cần API key) hoặc `google_maps_flutter` (nếu nhóm có key) — chốt với Minh ở tuần 1.
- Xin quyền vị trí (`geolocator`), hiển thị marker, "Chỉ đường" qua `url_launcher`.
- Xử lý trường hợp không có GPS/quyền bị từ chối: cho phép nhập địa chỉ thủ công.
- Test: unit test cho lọc tag, widget test cho tag chip, test chọn vị trí với mock.

**File phụ trách:** `code/lib/struct/tag_model.dart`, `code/lib/struct/location_model.dart`, `code/lib/services/tag_service.dart`, `code/lib/services/location_service.dart`, `code/lib/pages/document_form_page.dart` (phần tag/vị trí), `code/lib/widgets/tag_chip.dart`, `code/lib/widgets/location_picker.dart`.

**DoD:** Gán được ≥ 3 tag/tài liệu và lọc đúng; lưu và mở lại được vị trí; bản đồ render trên cả Android và Web; dữ liệu cũ (chưa có tag) vẫn hiển thị bình thường.

---

### 4.4. Quân — Luồng mượn & chia sẻ quyền (checklist #4)

**Mục tiêu:** Nghiệp vụ đầy đủ: chủ tài liệu chia sẻ quyền, người khác gửi yêu cầu mượn, chủ duyệt/từ chối, hệ thống thông báo và ghi vết.

**Công việc:**
- Trạng thái yêu cầu: `pending → approved → returned` và `rejected | cancelled`; ràng buộc thời hạn mượn (`due_date`), không cho mượn trùng.
- Service `borrow_service`: tạo yêu cầu, duyệt/từ chối, huỷ, đánh dấu đã trả, danh sách "Tôi mượn" / "Yêu cầu chờ duyệt".
- Mở rộng `share_dialog.dart`: chọn viewer/editor, thời hạn, thu hồi quyền; hiển thị người đang có quyền.
- UI: tab "Yêu cầu" với badge số lượng chờ duyệt; chi tiết yêu cầu; dialog xác nhận.
- Kết nối FCM: khi có yêu cầu mới → gọi Edge Function `notify`; khi được duyệt → thông báo cho người mượn. Deep link mở đúng tài liệu.
- Audit log: ai chia sẻ/thu hồi/duyệt, lúc nào.
- Test: unit test state machine (không cho chuyển trạng thái sai), widget test luồng duyệt, test RLS: người ngoài không thấy yêu cầu của người khác.

**File phụ trách:** `code/lib/services/borrow_service.dart`, `code/lib/services/notification_service.dart`, `code/lib/struct/borrow_request_model.dart`, `code/lib/widgets/share_dialog.dart`, `code/lib/pages/requests_page.dart`, `code/lib/services/supabase_service.dart` (chỉ phần permissions, phối hợp Minh).

**DoD:** Đi hết 1 vòng nghiệp vụ trên 2 tài khoản thật (A yêu cầu → B duyệt → A mở được → A trả → quyền về như cũ); thông báo đến trong ≤ 10 giây; mọi chuyển trạng thái sai bị chặn ở cả client và DB.

---

### 4.5. Đăng — Recommendation + kiểm thử toàn diện (checklist #5, #6)

**Mục tiêu:** Gợi ý tài liệu "vừa sức" (dễ giải thích, không cần ML phức tạp) và đảm bảo chất lượng trước khi phát hành.

**Công việc Recommendation:**
- Lưu sở thích: `user_interests(user_id, tag_id, weight)` cập nhật khi người dùng mở/tag/lưu tài liệu.
- Công thức gợi ý (content-based, giải thích được):
  `score = 0.5 × tag_overlap + 0.3 × độ mới + 0.2 × lượt xem`
  chuẩn hoá 0–1, loại tài liệu đã xem gần đây và tài liệu của chính mình.
- Cold start: người dùng mới → gợi ý theo tag phổ biến + tài liệu mới nhất; cho phép chọn 3 tag quan tâm khi onboarding.
- Hiển thị: khối "Gợi ý cho bạn" + lý do ("Vì bạn quan tâm #Giải tích").
- Viết unit test cho hàm scoring (bảng case cố định), test cold start.

**Công việc QA (#6):**
- Viết `docs/TEST_PLAN.md` mở rộng: ma trận chức năng × nền tảng (Android/Web) × loại test.
- Unit test (service, scoring), widget test (form, list, dialog), integration test (`integration_test/`), test RLS/âm (dùng 2 tài khoản).
- E2E thủ công theo checklist: đăng nhập, CRUD, tag, vị trí, chia sẻ, mượn, gợi ý.
- Báo cáo độ phủ (`flutter test --coverage`), quản lý bug trên GitHub Issues, chốt "Definition of Done" cho từng hạng mục cùng Minh.
- Hỗ trợ Minh kiểm thử bản build APK/Web trước khi phát hành.

**File phụ trách:** `code/lib/services/recommendation_service.dart`, `code/lib/pages/recommendation_page.dart` (hoặc widget trong home), `code/test/**`, `code/integration_test/**`, `docs/TEST_PLAN.md`.

**DoD:** Trang chủ có khối gợi ý chạy < 300ms với 200 tài liệu; giải thích được lý do gợi ý; test coverage ≥ 60% cho lớp service; toàn bộ test pass trên CI; bug P0/P1 = 0 trước khi đóng gói.

---

## 5. Timeline 6 tuần

| Tuần | Minh (#1) | Đạt (#2) | Hạnh (#3) | Quân (#4) | Đăng (#5, #6) | Mốc |
|---|---|---|---|---|---|---|
| **1** | Chốt kiến trúc, schema v2, RLS, tách service, công bố interface | Design system + breakpoint + khung `ResponsiveScaffold` | Chốt model tag/vị trí, thư viện bản đồ | Chốt state machine mượn + quyền | Chốt công thức scoring + khung test | **M1: Schema + interface + design system** |
| **2** | Migration, RLS, FCM setup, Edge Function `notify` | Home responsive, card, form 2 cột | CRUD tag + gán tag trong form | Bảng borrow + service cơ bản | `user_interests`, hàm scoring + unit test | Schema chạy thật |
| **3** | Tách service xong, review PR | Dialog/sheet responsive, dark mode | Lọc tag, chip, tìm kiếm theo tag | UI yêu cầu mượn, danh sách chờ duyệt | Khối "Gợi ý cho bạn" + cold start | **M2: 3 tính năng chạy được end-to-end** |
| **4** | FCM gửi/nhận, audit log, tài liệu kiến trúc | Rà soát toàn bộ màn hình trên web | Bản đồ, chọn vị trí, chỉ đường | Duyệt/từ chối/trả + thông báo + deep link | Test tích hợp 2 tài khoản, test RLS | **M3: Feature freeze** |
| **5** | CI GitHub Actions, build APK/Web | Fix UI theo bug, accessibility | Fix bug tag/vị trí | Fix bug luồng mượn | Chạy full test, đo coverage, báo cáo bug | **M4: Test pass, coverage ≥ 60%** |
| **6** | Đóng gói APK + Web, release notes | Ảnh demo, slide | Tài liệu hướng dẫn dùng tag/vị trí | Tài liệu hướng dẫn chia sẻ/mượn | Báo cáo kiểm thử, UAT | **M5: Phát hành v1.0 + demo** |

---

## 6. Phụ thuộc & điểm đồng bộ

| Phụ thuộc | Từ | Đến | Thời điểm |
|---|---|---|---|
| Schema `tags`, `document_tags`, `document_locations` | Minh | Hạnh | Cuối tuần 1 (bản nháp), tuần 2 (chốt) |
| Interface `share_service` / `borrow_service` | Minh | Quân | Cuối tuần 1 |
| `user_interests`, `document_views` | Minh | Đăng | Cuối tuần 1 |
| Hàm `notify` (FCM) | Minh | Quân | Cuối tuần 2 |
| Breakpoint + widget dùng chung | Đạt | Hạnh, Quân, Đăng | Cuối tuần 1 |
| `TagModel` + API lọc tag | Hạnh | Đăng | Cuối tuần 2 (cho recommendation) |
| Bản build để test | Minh | Đăng | Cuối tuần 4 |

**Quy ước chặn:** nếu interface chưa có, dùng mock/stub theo đúng chữ ký đã chốt, không chờ.

---

## 7. Thay đổi dữ liệu đề xuất (Minh chốt ở tuần 1)

| Bảng | Trường chính | Ghi chú |
|---|---|---|
| `tags` | id, name (unique), color, created_by | Tag dùng chung toàn hệ thống |
| `document_tags` | document_id, tag_id | PK ghép, cascade delete |
| `document_locations` | document_id (unique), latitude, longitude, place_name, shelf, note | 1 tài liệu ↔ 1 vị trí |
| `borrow_requests` | id, document_id, requester_id, owner_id, status, message, requested_at, responded_at, due_date | `status` là enum, có check constraint |
| `document_views` | id, document_id, user_id, viewed_at | Nguồn cho "lượt xem" + loại trừ đã xem |
| `user_interests` | user_id, tag_id, weight | PK ghép, weight cập nhật tăng dần |
| `notifications` | id, user_id, type, payload jsonb, read_at | Lịch sử thông báo |
| `device_tokens` | user_id, token, platform | FCM token theo thiết bị |
| `audit_logs` | id, actor_id, action, target_type, target_id, created_at | Chia sẻ/thu hồi/duyệt |

**Bảo mật:** mọi bảng mới bật RLS; policy đọc dựa trên `auth.uid()` + bảng `permissions`; chỉ owner được xoá tài liệu; service role chỉ dùng trong Edge Function.

---

## 8. Quy trình Git & Definition of Done

### Nhánh
- `main` — luôn chạy được, được bảo vệ (không push trực tiếp).
- `feature/<ten>-<mo-ta>` ví dụ: `feature/hanh-tag-location`, `feature/quan-borrow-flow`.
- `fix/<mo-ta>`, `docs/<mo-ta>`.

### Commit
`feat:`, `fix:`, `docs:`, `test:`, `refactor:`, `chore:` + mô tả ngắn ở thể mệnh lệnh.

### PR
- Tiêu đề rõ, mô tả thay đổi + ảnh chụp UI (nếu có).
- Ít nhất **1 reviewer** (Minh hoặc owner hạng mục liên quan).
- CI xanh (analyze + test) mới được merge.
- Không merge PR còn TODO hoặc code commented-out.

### DoD chung cho mỗi task
1. Code chạy được trên Android **và** Web.
2. Có test cho logic mới (unit/widget).
3. Không vi phạm kiến trúc Cashew (UI không gọi DB trực tiếp) — `architecture_test.dart` phải pass.
4. Cập nhật tài liệu liên quan (`SPEC.md`, `TEST_PLAN.md`).
5. Không có secret/khóa mới bị commit.

---

## 9. Rủi ro & phương án

| Rủi ro | Mức | Phương án |
|---|---|---|
| Schema thay đổi muộn làm 4 người phải sửa lại | Cao | Chốt schema tuần 1, thay đổi sau đó phải qua Minh + thông báo nhóm |
| Bản đồ cần API key (Google Maps) | Trung bình | Mặc định dùng `flutter_map` + OSM (miễn phí); chỉ chuyển Google Maps nếu có key |
| FCM trên Web cần service worker + HTTPS | Trung bình | Test trên `localhost`/deploy thử; fallback hiển thị thông báo trong app |
| RLS viết sai gây lộ dữ liệu | Cao | Test âm với 2 tài khoản; review chéo mọi thay đổi policy |
| Khối lượng UI lớn dồn vào Đạt | Trung bình | Các owner tự làm UI phần mình theo design system của Đạt; Đạt chỉ review |
| Test coverage không đạt | Trung bình | Viết test song song, không dồn cuối; CI chặn merge nếu test fail |
| Tiến độ trượt | Trung bình | Mốc M1–M5 rõ ràng; họp 15 phút đầu tuần, cắt scope tính năng phụ trước |

---

## 10. Sản phẩm bàn giao cuối kỳ

- [ ] Mã nguồn trên GitHub, `main` sạch, có CI.
- [ ] `docs/ARCHITECTURE.md` — sơ đồ kiến trúc + mô hình dữ liệu.
- [ ] `docs/TEST_PLAN.md` — kế hoạch và kết quả kiểm thử.
- [ ] APK release (`app-release.apk`) + bản Web build.
- [ ] Báo cáo cuối kỳ (nhóm + phần của từng thành viên).
- [ ] Slide + video demo 3–5 phút.
