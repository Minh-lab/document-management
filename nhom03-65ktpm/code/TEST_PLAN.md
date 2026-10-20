# Kế hoạch kiểm thử (Test Plan) - Document Management App

## 📋 Checklist hoàn thành

| # | Tính năng | Trạng thái | Ghi chú |
|---|-----------|------------|---------|
| 1 | Thiết lập Firebase + Google Sign-in | ✅ Hoàn thành | Đã thêm google_sign_in, cập nhật functions.dart, home_page.dart |
| 2 | Firebase Storage + Supabase Documents | ✅ Hoàn thành | Cấu trúc users/{uid}/documents/{docId}/{file} |
| 3 | Database Supabase (Users, Documents, Permissions) | ✅ Hoàn thành | 4 bảng: users, categories, documents, permissions |
| 4 | Tìm kiếm, Cập nhật, Chia sẻ tài liệu | ✅ Hoàn thành | Search realtime, update form, share dialog |
| 5 | RLS Policies Supabase | ✅ Hoàn thành | File supabase_rls_policies.sql, Edge Function verify Firebase |
| 6 | Kiểm thử 3 tài khoản | 🔄 Cần thực hiện | Chưa chạy test |

---

## 🧪 Kịch bản kiểm thử (Test Cases)

### Tài khoản test
| Tài khoản | Email | Vai trò test |
|-----------|-------|--------------|
| User A | test1@example.com | Owner tài liệu |
| User B | test2@example.com | Viewer (được share view) |
| User C | test3@example.com | Editor (được share edit) |

### TC01: Đăng nhập Google
- [ ] User A đăng nhập Google thành công
- [ ] User B đăng nhập Google thành công  
- [ ] User C đăng nhập Google thành công
- [ ] Thông tin user hiển thị đúng (avatar, tên, email)
- [ ] Sync user profile lên Supabase users table

### TC02: Tạo tài liệu (Owner)
- [ ] User A tạo tài liệu mới có file PDF
- [ ] File upload lên Firebase Storage đúng path: users/{uid}/documents/{docId}/
- [ ] Metadata lưu vào Supabase documents table
- [ ] User A xem được tài liệu vừa tạo

### TC03: Tìm kiếm tài liệu
- [ ] Tìm theo từ khóa trong tiêu đề
- [ ] Lọc theo danh mục
- [ ] Kết hợp tìm kiếm + lọc
- [ ] Kết quả realtime khi gõ

### TC04: Cập nhật tài liệu
- [ ] User A sửa tiêu đề, mô tả, danh mục
- [ ] User A thay file đính kèm (file cũ bị xóa trên Storage)
- [ ] Lưu thay đổi thành công

### TC05: Chia sẻ tài liệu (Share)
- [ ] User A chia sẻ cho User B với quyền "Viewer"
- [ ] User B thấy tài liệu trong danh sách
- [ ] User B MỞ ĐƯỢC file
- [ ] User B KHÔNG SỬA ĐƯỢC (nút edit ẩn/bị chặn)

### TC06: Chia sẻ tài liệu (Editor)
- [ ] User A chia sẻ cho User C với quyền "Editor"
- [ ] User C thấy tài liệu
- [ ] User C MỞ ĐƯỢC file
- [ ] User C SỬA ĐƯỢC tiêu đề, mô tả, file
- [ ] User C KHÔNG XÓA ĐƯỢC tài liệu

### TC07: Xóa tài liệu (Owner)
- [ ] User A xóa tài liệu
- [ ] File bị xóa trên Firebase Storage
- [ ] Record bị xóa trên Supabase
- [ ] Permissions liên quan bị xóa (CASCADE)

### TC08: Xóa chia sẻ (Revoke)
- [ ] User A xóa chia sẻ cho User B
- [ ] User B không còn thấy tài liệu
- [ ] Permission record bị xóa

### TC09: Phân quyền RLS
- [ ] User A chỉ thấy tài liệu của mình + được share
- [ ] User B chỉ thấy tài liệu được share
- [ ] User C chỉ thấy tài liệu của mình + được share
- [ ] Không user nào thấy tài liệu của người khác (chưa share)

### TC10: Đăng xuất / Đăng nhập lại
- [ ] Đăng xuất thành công
- [ ] Đăng nhập lại Google khôi phục session
- [ ] Dữ liệu tài liệu vẫn đúng

---

## 🚀 Cách chạy test

### 1. Chuẩn bị
```bash
# Cài dependencies
flutter pub get

# Build APK debug
flutter build apk --debug

# Cài lên 3 thiết bị/emulator
adb install build/app/outputs/flutter-apk/app-debug.apk
```

### 2. Chạy test thủ công
Mở app trên 3 thiết bị, đăng nhập 3 tài khoản Google khác nhau, thực hiện theo test cases TC01-TC10.

### 3. Kiểm tra log
```bash
# Xem log realtime
adb logcat | grep -E "(flutter|Error|Exception|I/flutter|share|sync)"
```

### 4. Kiểm tra Supabase Dashboard
- Table Editor → users: 3 records
- Table Editor → documents: records của 3 user
- Table Editor → permissions: records share
- Storage → users/{uid}/documents/: files upload

### 5. Kiểm tra Firebase Console
- Authentication → Users: 3 Firebase users
- Storage → Files: cấu trúc users/{uid}/documents/

---

## ✅ Tiêu chí chấp nhận (Acceptance Criteria)

| Tiêu chí | Pass/Fail |
|----------|-----------|
| 3 tài khoản đăng nhập Google thành công | [ ] |
| Tạo/sửa/xóa tài liệu hoạt động | [ ] |
| Tìm kiếm, lọc realtime | [ ] |
| Chia sẻ Viewer: xem được, không sửa được | [ ] |
| Chia sẻ Editor: xem được, sửa được, không xóa được | [ ] |
| Owner xóa được tài liệu | [ ] |
| RLS: User chỉ thấy tài liệu của mình + được share | [ ] |
| File upload/download Firebase Storage đúng | [ ] |
| Metadata Supabase đồng bộ đúng | [ ] |
| Không có lỗi crash/uncaught exception | [ ] |

---

## 📝 Báo cáo kết quả

Sau khi chạy test, điền kết quả:

| Test Case | User A | User B | User C | Ghi chú |
|-----------|--------|--------|--------|---------|
| TC01: Google Sign-in | | | | |
| TC02: Tạo tài liệu | | | | |
| TC03: Tìm kiếm | | | | |
| TC04: Cập nhật | | | | |
| TC05: Share Viewer | | | | |
| TC06: Share Editor | | | | |
| TC07: Xóa tài liệu | | | | |
| TC08: Revoke share | | | | |
| TC09: RLS隔离 | | | | |
| TC10: Session persistence | | | | |

**Kết quả tổng thể**: [ ] PASS / [ ] FAIL

**Bugs phát hiện**:
1.
2.
3.

**Đề xuất cải tiến**:
1.
2.