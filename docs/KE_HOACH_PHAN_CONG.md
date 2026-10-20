# KẾ HOẠCH PHÂN CÔNG CÔNG VIỆC

**Dự án:** Ứng dụng Quản lý Tài liệu Học tập (Flutter + Firebase + Supabase)
**Nhóm:** 5 thành viên — Minh, Đạt, Hạnh, Quân, Đăng
**Thời gian:** 20/10 → **24/10** (5 ngày, ~22 ngày công)
**Repo:** https://github.com/Minh-lab/document-management

> ⚠️ Thời gian rất ngắn: mỗi hạng mục chỉ làm **bản MVP chạy được**, các phần "nếu còn thời gian" nằm ở mục 6.

---

## 1. Hiện trạng mã nguồn so với checklist

| # | Hạng mục checklist | Hiện trạng | Phần còn thiếu (MVP cần làm) |
|---|---|---|---|
| 1 | Kiến trúc + mô hình dữ liệu Firebase (Auth/Messaging) & Supabase (DB/Storage) | Firebase Auth (anonymous + Google), Edge Function `verify-firebase-token`, Supabase documents/categories/permissions, Storage | Bảng mới (tag, vị trí, borrow, interest), RLS, FCM, sơ đồ kiến trúc |
| 2 | UI Flutter đa nền tảng, responsive Mobile + Web | UI một cột, chưa có breakpoint | Breakpoint + `ResponsiveScaffold`, grid co giãn, form 2 cột, dialog/sheet |
| 3 | Tag + bản đồ/vị trí vật lý | Chưa có (chỉ `categories`) | `tags`, `document_tags`, `document_locations`, UI tag, bản đồ/chọn vị trí |
| 4 | Luồng mượn & chia sẻ quyền | Đã có chia sẻ viewer/editor/owner | Yêu cầu mượn → duyệt/từ chối → trả + thông báo |
| 5 | Recommendation theo sở thích/tag | Chưa có | `user_interests`, hàm scoring, khối "Gợi ý cho bạn" |
| 6 | Kiểm thử toàn diện + đóng gói | 2 test (architecture, widget), chưa CI | Test plan, unit/widget/integration, CI, build APK + Web |

---

## 2. Nguyên tắc phân chia

1. **1 hạng mục = 1 owner**, người khác chỉ góp ý qua PR.
2. **Schema + interface chốt trưa 20/10** (Minh) để 4 người còn lại code ngay, không chờ.
3. **UI của ai người đó làm**, Đạt lo design system + review responsive toàn bộ.
4. **Ai viết tính năng, người đó viết test**; Đăng chạy test tích hợp và chốt chất lượng.
5. **Mỗi ngày merge xong trước 22h**, `main` luôn chạy được, không push trực tiếp.

---

## 3. Bảng phân công

| Thành viên | Vai trò | Hạng mục | Ước lượng |
|---|---|---|---|
| **Minh** | Nhóm trưởng, kiến trúc & release | #1 (chính), #6 (CI + đóng gói) | ~5 ngày công |
| **Đạt** | Frontend/UI lead | #2 (chính), review UI | ~4,5 ngày công |
| **Hạnh** | Feature – Tag & vị trí | #3 (chính) | ~4,5 ngày công |
| **Quân** | Feature – nghiệp vụ chia sẻ | #4 (chính) | ~4,5 ngày công |
| **Đăng** | Recommendation + QA | #5 (chính), #6 (test) | ~4,5 ngày công |

---

## 4. Chi tiết từng thành viên

### 4.1. Minh — Kiến trúc & mô hình dữ liệu (checklist #1)

- Sơ đồ kiến trúc: Flutter → Firebase Auth → Edge Function → Supabase JWT → PostgREST/Storage; FCM cho thông báo.
- Schema v2 + RLS: `tags`, `document_tags`, `document_locations`, `borrow_requests`, `document_views`, `user_interests`, `device_tokens`.
- Tách `supabase_service.dart` (471 dòng) thành `document_service`, `share_service`, `tag_service`, `borrow_service`; công bố chữ ký hàm cho nhóm.
- Bật FCM (Android + Web), lưu `device_tokens`, Edge Function `notify` gửi thông báo.
- `docs/ARCHITECTURE.md` + cập nhật `docs/SPEC.md`.

**File:** `code/supabase_schema.sql`, `code/supabase_rls_policies.sql`, `code/supabase/functions/**`, `code/lib/services/supabase_service.dart`, `code/lib/config/**`, `docs/ARCHITECTURE.md`.

**DoD:** SQL chạy được trên Supabase; test âm (A không đọc được tài liệu private của B); gửi được 1 thông báo FCM thật.

---

### 4.2. Đạt — UI đa nền tảng & responsive (checklist #2)

- `lib/utils/responsive.dart`: `compact < 600`, `medium 600–1024`, `expanded ≥ 1024`.
- `ResponsiveScaffold`: BottomNavigationBar (mobile) ↔ NavigationRail (web/tablet), giới hạn `maxContentWidth`.
- `home_page.dart` → `SliverGrid` 1/2/3/4 cột; `document_card.dart` hỗ trợ hover trên web.
- Form 1 cột ↔ 2 cột; dialog chia sẻ: `Dialog` (web) / `BottomSheet` (mobile).
- Design token: `AppColors`, `AppTheme`, component dùng chung; `SafeArea`, text scale.
- Widget test layout 3 breakpoint.

**File:** `code/lib/pages/**`, `code/lib/widgets/**`, `code/lib/colors.dart`, `code/lib/main.dart` (theme), `code/lib/utils/responsive.dart`.

**DoD:** 3 ảnh chụp 360/768/1440px cho mỗi màn hình chính; không overflow; test layout pass.

---

### 4.3. Hạnh — Tag & bản đồ/vị trí (checklist #3)

- `TagModel` + `tag_service`: CRUD tag, gán/bỏ tag, lọc theo nhiều tag.
- UI: chip chọn tag trong form, thanh lọc tag ở trang chủ, màu tag.
- `document_locations`: latitude, longitude, place_name, shelf, note.
- Chọn vị trí: `flutter_map` + OpenStreetMap (không cần API key), marker + "Chỉ đường" qua `url_launcher`; nhập địa chỉ thủ công nếu từ chối quyền.
- Test: unit test lọc tag, widget test tag chip.

**File:** `code/lib/struct/tag_model.dart`, `code/lib/struct/location_model.dart`, `code/lib/services/tag_service.dart`, `code/lib/services/location_service.dart`, `code/lib/widgets/tag_chip.dart`, `code/lib/widgets/location_picker.dart`, phần tag/vị trí trong `document_form_page.dart`.

**DoD:** Gán ≥ 3 tag/tài liệu và lọc đúng; lưu/mở lại được vị trí; bản đồ render trên Android + Web; tài liệu cũ vẫn hiển thị bình thường.

---

### 4.4. Quân — Mượn & chia sẻ quyền (checklist #4)

- Trạng thái: `pending → approved → returned`, nhánh `rejected | cancelled`; `due_date`; chặn mượn trùng.
- `borrow_service`: tạo/duyệt/từ chối/huỷ/đánh dấu đã trả; "Tôi mượn" và "Chờ duyệt".
- Mở rộng `share_dialog.dart`: viewer/editor, thu hồi quyền, danh sách người có quyền.
- UI tab "Yêu cầu" + badge; dialog xác nhận.
- FCM: yêu cầu mới → `notify`; được duyệt → báo người mượn.
- Test: unit test state machine, test RLS (người ngoài không thấy yêu cầu).

**File:** `code/lib/services/borrow_service.dart`, `code/lib/services/notification_service.dart`, `code/lib/struct/borrow_request_model.dart`, `code/lib/widgets/share_dialog.dart`, `code/lib/pages/requests_page.dart`.

**DoD:** 1 vòng nghiệp vụ trên 2 tài khoản thật (A yêu cầu → B duyệt → A mở → A trả → quyền về như cũ); thông báo tới trong ≤ 10 giây; trạng thái sai bị chặn ở client và DB.

---

### 4.5. Đăng — Recommendation + kiểm thử (checklist #5, #6)

- `user_interests(user_id, tag_id, weight)` cập nhật khi mở/tag/lưu tài liệu.
- Công thức: `score = 0.5×tag_overlap + 0.3×độ_mới + 0.2×lượt_xem`, chuẩn hoá 0–1, loại tài liệu của mình và tài liệu vừa xem.
- Cold start: người dùng mới → tag phổ biến + tài liệu mới nhất.
- Khối "Gợi ý cho bạn" + lý do ("Vì bạn quan tâm #Giải tích").
- QA: test plan, unit test scoring, widget test, integration test, test RLS 2 tài khoản, checklist E2E thủ công, đo coverage, quản lý bug.

**File:** `code/lib/services/recommendation_service.dart`, thành phần gợi ý trong `home_page.dart` (phối hợp Đạt), `code/test/**`, `code/integration_test/**`, `docs/TEST_PLAN.md`.

**DoD:** Gợi ý chạy < 300ms với 200 tài liệu, có lý do; coverage service ≥ 60%; toàn bộ test pass trên CI; không còn bug P0/P1.

---

## 5. Lịch 5 ngày (20/10 → 24/10)

### Ngày 1 — 20/10: Chốt nền tảng

| Giờ | Việc | Người | Kết quả |
|---|---|---|---|
| 8h30 | Họp 30': chốt phạm vi MVP, nhánh, quy ước | Cả nhóm | Biên bản ngắn trong issue |
| 9h–12h | Schema v2 + RLS + công bố interface service | Minh | SQL chạy trên Supabase |
| 9h–12h | Khung `responsive.dart`, design token | Đạt | Breakpoint + theme |
| 9h–12h | Model + service tag/vị trí (chưa UI) | Hạnh | `tag_service` chạy với DB thật |
| 9h–12h | Model + state machine borrow (chưa UI) | Quân | Unit test state machine |
| 9h–12h | Hàm scoring + khung test plan | Đăng | Unit test scoring pass |
| 13h30–18h | Nối service vào UI, mỗi người 1 màn hình | Cả nhóm | PR đầu tiên |
| 18h–22h | Review + merge; Minh kiểm tra RLS | Cả nhóm | **M1: schema + interface + UI khung** |

### Ngày 2 — 21/10: Ba tính năng chạy được

| Người | Việc trong ngày | Mốc |
|---|---|---|
| Minh | FCM setup (Android + Web), Edge Function `notify`, review PR | Gửi được thông báo test |
| Đạt | Home grid responsive, card, form 2 cột | Chạy tốt 3 breakpoint |
| Hạnh | Tag chip, gán tag trong form, lọc tag trang chủ | Gán + lọc tag thật |
| Quân | UI gửi yêu cầu mượn, danh sách chờ duyệt | Tạo yêu cầu thật trên DB |
| Đăng | `user_interests`, khối gợi ý (stub nếu chưa có dữ liệu) | Gợi ý hiển thị theo tag |
| 22h | Merge hết, chạy `flutter analyze` + test | **M2: tag, mượn, gợi ý chạy end-to-end** |

### Ngày 3 — 22/10: Hoàn thiện + tích hợp

| Người | Việc trong ngày | Mốc |
|---|---|---|
| Minh | FCM end-to-end (duyệt → báo người mượn), fix RLS, viết `ARCHITECTURE.md` | Thông báo ≤ 10s |
| Đạt | Dialog/sheet responsive, rà soát toàn bộ màn hình trên Chrome | Không còn overflow |
| Hạnh | Bản đồ + chọn vị trí + chỉ đường, fallback nhập tay | Lưu/mở lại vị trí |
| Quân | Duyệt/từ chối/trả, thu hồi quyền, audit cơ bản | Trọn 1 vòng nghiệp vụ |
| Đăng | Test tích hợp 2 tài khoản, báo bug lên Issues | Danh sách bug P0/P1 |
| 23h | **Feature freeze** — không thêm tính năng | **M3** |

### Ngày 4 — 23/10: Kiểm thử toàn diện

| Người | Việc trong ngày |
|---|---|
| Đăng | Chạy full test, đo coverage, viết `TEST_PLAN.md`, điều phối bug |
| Minh | CI GitHub Actions (analyze + test), build thử APK + Web |
| Đạt | Fix bug UI, accessibility (tap ≥ 48dp, contrast) |
| Hạnh | Fix bug tag/vị trí, test trên Android thật |
| Quân | Fix bug luồng mượn, test 2 tài khoản |
| 23h | **M4: test pass, coverage ≥ 60%, hết bug P0/P1** |

### Ngày 5 — 24/10: Đóng gói & nộp

| Giờ | Việc | Người |
|---|---|---|
| 8h–12h | Build APK release + Web build, kiểm tra cài đặt máy sạch | Minh, Đăng |
| 8h–12h | Ảnh demo 3 breakpoint, slide | Đạt |
| 8h–12h | Tài liệu hướng dẫn tag/vị trí | Hạnh |
| 8h–12h | Tài liệu hướng dẫn chia sẻ/mượn | Quân |
| 13h30–16h | Báo cáo nhóm + phần từng người, video demo 3–5 phút | Cả nhóm |
| 16h–17h | Rà soát lần cuối, tag release `v1.0.0`, nộp | Minh |
| **17h** | **M5: Nộp bài** | |

---

## 6. Cắt giảm phạm vi (bắt buộc để kịp 24/10)

**Làm (MVP):** đăng nhập, CRUD tài liệu, tag + lọc tag, vị trí + bản đồ, chia sẻ viewer/editor, yêu cầu mượn → duyệt → trả, gợi ý theo tag, responsive 3 breakpoint, test + build.

**Cắt / để sau (ghi vào "Hướng phát triển" của báo cáo):**
- Dark mode, animation nâng cao.
- Audit log đầy đủ (chỉ log chia sẻ/thu hồi/duyệt).
- Deep link từ thông báo (chỉ mở app + tab Yêu cầu).
- Onboarding chọn tag (thay bằng cold-start đơn giản).
- E2E tự động (dùng checklist thủ công).
- Realtime cập nhật danh sách (dùng pull-to-refresh).
- Chat/bình luận trên tài liệu.

---

## 7. Phụ thuộc & điểm đồng bộ

| Phụ thuộc | Từ | Đến | Thời điểm |
|---|---|---|---|
| Schema `tags`, `document_tags`, `document_locations` | Minh | Hạnh | Trưa 20/10 |
| Interface `borrow_service` + bảng `borrow_requests` | Minh | Quân | Trưa 20/10 |
| `user_interests`, `document_views` | Minh | Đăng | Trưa 20/10 |
| Hàm `notify` (FCM) | Minh | Quân | Chiều 21/10 |
| Breakpoint + component dùng chung | Đạt | Cả nhóm | Chiều 20/10 |
| `TagModel` + API lọc tag | Hạnh | Đăng | Trưa 21/10 |

**Quy ước chặn:** chưa có API thật thì dùng stub đúng chữ ký đã chốt, không ngồi chờ.

---

## 8. Thay đổi dữ liệu (Minh chốt trưa 20/10)

| Bảng | Trường chính | Ghi chú |
|---|---|---|
| `tags` | id, name (unique), color | Dùng chung toàn hệ thống |
| `document_tags` | document_id, tag_id | PK ghép, cascade delete |
| `document_locations` | document_id (unique), latitude, longitude, place_name, shelf, note | 1 tài liệu ↔ 1 vị trí |
| `borrow_requests` | id, document_id, requester_id, owner_id, status, message, requested_at, responded_at, due_date | `status` enum + check constraint |
| `document_views` | id, document_id, user_id, viewed_at | Cho "lượt xem" + loại trừ đã xem |
| `user_interests` | user_id, tag_id, weight | PK ghép, weight tăng dần khi tương tác |
| `device_tokens` | user_id, token, platform | FCM token theo thiết bị |

**Bảo mật:** bật RLS mọi bảng mới; đọc dựa trên `auth.uid()` + bảng `permissions`; chỉ owner được xoá; service role chỉ trong Edge Function.

---

## 9. Git & Definition of Done

- Nhánh: `feature/<ten>-<viec>` (vd `feature/hanh-tag-location`), `fix/...`, `docs/...`.
- Commit: `feat:`, `fix:`, `docs:`, `test:`, `refactor:`, `chore:`.
- PR cần 1 review + CI xanh; **không push trực tiếp `main`**.
- DoD mỗi task: chạy trên Android **và** Web; có test; `architecture_test.dart` pass; cập nhật tài liệu; không commit secret.

---

## 10. Rủi ro & phương án (5 ngày)

| Rủi ro | Phương án |
|---|---|
| Schema đổi sau 20/10 làm 4 người sửa lại | Chốt trưa 20/10; mọi thay đổi phải báo nhóm ngay trong ngày |
| Bản đồ cần API key | Dùng `flutter_map` + OSM, không cần key |
| FCM trên Web cần service worker/HTTPS | Test trên `localhost` + bản deploy; fallback hiện thông báo trong app |
| RLS sai gây lộ dữ liệu | Test âm 2 tài khoản, review chéo policy |
| UI dồn vào Đạt | Owner tự dựng UI theo design system, Đạt chỉ review |
| Trượt tiến độ | Cắt ngay phần trong mục 6, giữ đủ 6 hạng mục ở mức MVP |
| Merge muộn gây vỡ `main` | Merge trước 22h mỗi ngày, PR nhỏ, ai làm vỡ `main` người đó sửa ngay |

---

## 11. Sản phẩm bàn giao (17h ngày 24/10)

- [ ] Mã nguồn trên GitHub, `main` sạch, CI xanh, tag `v1.0.0`.
- [ ] `docs/ARCHITECTURE.md` — sơ đồ kiến trúc + mô hình dữ liệu.
- [ ] `docs/TEST_PLAN.md` — kế hoạch + kết quả kiểm thử, coverage.
- [ ] `app-release.apk` + bản Web build.
- [ ] Báo cáo cuối kỳ (nhóm + phần từng thành viên).
- [ ] Slide + video demo 3–5 phút.
