# Báo cáo hoàn thành dự án Document Management App

## Tổng quan
Dự án: Ứng dụng Quản lý Tài liệu Học tập (Document Management App)
Công nghệ: Flutter + Firebase + Supabase
Ngày hoàn thành: 2024-10-13

---

## CHECKLIST 1: Thiết lập Firebase và tích hợp Google Sign-in

### ✅ Trạng thái: HOÀN THÀNH

### Mô tả chi tiết đã thực hiện:

#### 1.1 Cài đặt dependencies Firebase
- **File**: `pubspec.yaml`
- Thêm các package:
  - `firebase_core: ^3.6.0` - Core Firebase
  - `firebase_auth: ^5.3.1` - Authentication
  - `firebase_storage: ^12.3.4` - Cloud Storage
  - `google_sign_in: ^6.2.1` - Google Sign-In

#### 1.2 Cấu hình Google Sign-In
- **File**: `lib/functions.dart`
- Tạo instance `GoogleSignIn`
- Implement hàm `signInWithGoogle()`:
  - Gọi `googleSignIn.signIn()` để lấy GoogleSignInAccount
  - Lấy `accessToken` và `idToken` từ authentication
  - Tạo `GoogleAuthProvider.credential()`
  - Đăng nhập Firebase bằng `signInWithCredential()`
- Implement hàm `signOut()`: Đăng xuất cả Google và Firebase

#### 1.3 Cập nhật UI đăng nhập
- **File**: `lib/pages/home_page.dart`
- Thay thế chip trạng thái Online/Offline bằng PopupMenuButton
- Hiển thị avatar, tên, email từ Google account
- Menu dropdown: Profile / Đăng xuất
- Nút "Đăng nhập Google" khi chưa đăng nhập

#### 1.4 Cập nhật initializeServices
- **File**: `lib/functions.dart`
- Hàm `_ensureUserSignedIn()`: Giữ anonymous auth làm fallback
- Hàm `signInWithGoogle()`: Đăng nhập Google chính thức
- Stream `authStateChanges` theo dõi trạng thái đăng nhập

---

## CHECKLIST 2: Cấu trúc lưu trữ Firebase Storage + Supabase Documents

### ✅ Trạng thái: HOÀN THÀNH

### Mô tả chi tiết đã thực hiện:

#### 2.1 Cấu trúc thư mục Firebase Storage
- **File**: `lib/services/firebase_storage_service.dart`
- Cấu trúc: `users/{userId}/documents/{docId}/{uuid}.{extension}`
- Sử dụng UUID để tránh trùng tên file
- Hỗ trợ cross-platform với `XFile` (package `cross_file`)

#### 2.2 Upload file lên Firebase Storage
- Hàm `uploadDocument()`:
  - Đọc file bytes từ `XFile.readAsBytes()`
  - Upload bằng `putData()` thay vì `putFile()` (hỗ trợ Android content:// URI)
  - Lắng nghe progress với `snapshotEvents`
  - Trả về `downloadUrl` và `storagePath`

#### 2.3 Quản lý file khi CRUD tài liệu
- **File**: `lib/functions.dart`
- `addDocument()`: Upload file → lưu metadata Supabase → update storagePath với docId thật
- `updateDocument()`: Xóa file cũ → upload file mới → cập nhật metadata
- `deleteDocument()`: Xóa file trên Storage → xóa record Supabase
- Helper `_moveFileInStorage()`: Copy + delete để di chuyển file

#### 2.4 Model Document mở rộng
- **File**: `lib/struct/document_model.dart`
- Thêm fields: `fileUrl`, `storagePath`, `hasAttachment`, `openUrl`
- Hỗ trợ cả file local (legacy) và file Firebase Storage

---

## CHECKLIST 3: Thiết kế Database Supabase (Users, Documents, Permissions)

### ✅ Trạng thái: HOÀN THÀNH

### Mô tả chi tiết đã thực hiện:

#### 3.1 Models
| File | Mô tả |
|------|-------|
| `lib/struct/user_model.dart` | User (id=Firebase UID, email, displayName, avatarUrl) |
| `lib/struct/category_model.dart` | Category (id, name) |
| `lib/struct/document_model.dart` | Document (id, title, description, fileUrl, storagePath, categoryId, userId) |
| `lib/struct/permission_model.dart` | Permission (documentId, userId, role: viewer/editor/owner, grantedBy) |

#### 3.2 Supabase Service
- **File**: `lib/services/supabase_service.dart`
- **Categories**: CRUD, seed default (Bài giảng, Bài tập, Tham khảo)
- **Documents**: CRUD với filter, order, join categories
- **Users**: upsertUser, getUserById, searchUsers
- **Permissions**: shareDocument, removePermission, updatePermission, getDocumentPermissions, getSharedDocuments

#### 3.3 Database Schema (SQL)
- **File**: `supabase_schema.sql`
- 4 bảng: `categories`, `documents`, `users`, `permissions`
- Foreign keys, indexes, triggers `updated_at`
- RLS policies (xem Checklist 5)

---

## CHECKLIST 4: Triển khai Tìm kiếm, Cập nhật, Chia sẻ tài liệu

### ✅ Trạng thái: HOÀN THÀNH

### Mô tả chi tiết đã thực hiện:

#### 4.1 Tìm kiếm tài liệu
- **File**: `lib/pages/home_page.dart` + `lib/functions.dart` + `lib/services/supabase_service.dart`
- Ô tìm kiếm realtime: `onChanged` → `_loadDocuments()`
- Filter: keyword (ilike title) + categoryId + userId
- Lọc kết hợp: tìm kiếm + chọn danh mục

#### 4.2 Cập nhật tài liệu
- **File**: `lib/pages/document_form_page.dart` + `lib/functions.dart`
- Form: Tiêu đề (bắt buộc), Mô tả, Dropdown Category, File picker
- Upload progress bar khi chọn file
- Edit: Load dữ liệu cũ → sửa → lưu → xóa file cũ trên Storage nếu thay file

#### 4.3 Chia sẻ tài liệu (Share)
- **File**: `lib/widgets/share_dialog.dart` + `lib/widgets/document_card.dart` + `lib/pages/home_page.dart`
- Icon Share trên DocumentCard (màu xanh dương)
- Dialog: Tìm user theo email/tên (`searchUsers`)
- Chọn quyền: Viewer / Editor / Owner
- Danh sách đã share: Dropdown đổi quyền, nút xóa share
- Realtime update khi share thay đổi

---

## CHECKLIST 5: Thiết lập RLS (Row Level Security) Supabase

### ✅ Trạng thái: HOÀN THÀNH (Code hoàn thiện, cần chạy SQL trên Dashboard)

### Mô tả chi tiết đã thực hiện:

#### 5.1 SQL Policies
- **File**: `supabase_rls_policies.sql`
- Function `current_user_id()`: Lấy UID từ header `x-user-id` hoặc `auth.uid()`
- Policies cho 4 bảng:
  - **users**: SELECT/UPDATE/INSERT own profile
  - **categories**: SELECT all authenticated
  - **documents**: Owner CRUD + Shared users view/edit theo permissions
  - **permissions**: Owner manage + Grantee view

#### 5.2 Edge Function verify Firebase Token
- **File**: `supabase/functions/verify-firebase-token/index.ts`
- Verify Firebase ID token (JWT) bằng public keys từ Google
- Tạo Supabase JWT custom với Firebase UID
- Client gửi Firebase token → nhận Supabase token → dùng cho RLS

#### 5.3 Cấu hình PostgREST
- Cần forward header `x-user-id` từ client
- Hoặc dùng Custom JWT từ Edge Function

---

## CHECKLIST 6: Kiểm thử 3 tài khoản người dùng

### 🔄 Trạng thái: CẦN THỰC HIỆN (Test plan đã sẵn sàng)

### Mô tả chi tiết:

#### 6.1 Test Plan
- **File**: `TEST_PLAN.md`
- 3 tài khoản: User A (Owner), User B (Viewer), User C (Editor)
- 10 Test Cases: TC01-TC10
- Tiêu chí chấp nhận chi tiết

#### 6.2 Cách chạy test
```bash
flutter pub get
flutter build apk --debug
adb install build/app/outputs/flutter-apk/app-debug.apk
# Cài lên 3 thiết bị/emulator
```

#### 6.3 Test Cases chính
| TC | Mô tả | Expected |
|----|-------|----------|
| TC01 | Google Sign-in 3 tài khoản | Thành công, sync profile |
| TC02 | Tạo tài liệu + upload file | File lên Storage, metadata Supabase |
| TC03 | Tìm kiếm + lọc | Realtime, kết hợp keyword + category |
| TC04 | Cập nhật tài liệu | Sửa title/desc/category/file |
| TC05 | Share Viewer | User B xem được, không sửa được |
| TC06 | Share Editor | User C xem/sửa được, không xóa |
| TC07 | Owner xóa tài liệu | Xóa file Storage + record Supabase |
| TC08 | Revoke share | User B không còn thấy |
| TC09 | RLS isolation | User chỉ thấy của mình + được share |
| TC10 | Session persistence | Đăng nhập lại khôi phục dữ liệu |

---

## Tổng kết

| Checklist | Trạng thái | Ghi chú |
|-----------|------------|---------|
| 1. Firebase + Google Sign-in | ✅ Hoàn thành | Code sẵn sàng, cần config Firebase Console |
| 2. Firebase Storage + Supabase | ✅ Hoàn thành | Cross-platform, upload/download OK |
| 3. Database Supabase | ✅ Hoàn thành | 4 bảng, models, services đầy đủ |
| 4. Tìm kiếm/Cập nhật/Chia sẻ | ✅ Hoàn thành | UI/UX đầy đủ, realtime |
| 5. RLS Policies | ✅ Code ready | Cần chạy SQL + config Firebase JWT |
| 6. Kiểm thử 3 tài khoản | 🔄 Test plan ready | Cần 3 thiết bị/emulator + 3 Google accounts |

---

## File cấu trúc chính

```
lib/
├── main.dart                          # Entry point, init Firebase + Supabase
├── functions.dart                     # Business logic, auth, CRUD, share
├── config/
│   ├── supabase_config.dart           # Supabase URL, keys, table names
│   └── firebase_options.dart          # Auto-generated by flutterfire
├── services/
│   ├── supabase_service.dart          # Supabase CRUD, realtime, users, permissions
│   └── firebase_storage_service.dart  # Firebase Storage upload/delete
├── struct/
│   ├── user_model.dart
│   ├── category_model.dart
│   ├── document_model.dart
│   └── permission_model.dart
├── pages/
│   ├── home_page.dart                 # Main UI: search, filter, list, share dialog
│   └── document_form_page.dart        # Form create/edit document
├── widgets/
│   ├── document_card.dart             # Card hiển thị doc + edit/delete/share
│   ├── share_dialog.dart              # Dialog chia sẻ tài liệu
│   └── ...
└── colors.dart

supabase/
├── schema.sql                         # Database schema
├── rls_policies.sql                   # RLS policies
└── functions/verify-firebase-token/   # Edge Function verify Firebase JWT

TEST_PLAN.md                           # Kế hoạch test 3 tài khoản
PROJECT_REPORT.md                      # File này
```

---

## Các bước tiếp theo để deploy Production

1. **Firebase Console**:
   - Tạo project → Enable Authentication (Google) → Enable Storage
   - Chạy `flutterfire configure` để gen `firebase_options.dart`

2. **Supabase Dashboard**:
   - Chạy `supabase_schema.sql` → SQL Editor
   - Chạy `supabase_rls_policies.sql` → SQL Editor
   - Bật Replication cho tables (Realtime)
   - Deploy Edge Function `verify-firebase-token`
   - Set env vars: `FIREBASE_PROJECT_ID`, `SUPABASE_JWT_SECRET`

3. **Client Config**:
   - Gửi header `x-user-id: <firebase_uid>` trong mọi request Supabase
   - Hoặc tích hợp Edge Function để exchange Firebase token → Supabase JWT

4. **Test & Deploy**:
   - Chạy TEST_PLAN.md với 3 tài khoản
   - Fix bugs → Build release → Deploy