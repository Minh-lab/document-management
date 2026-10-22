# Hướng dẫn Setup Firebase + Supabase cho Document Management App

## 1. FIREBASE SETUP

### 1.1 Tạo Firebase Project
1. Vào [Firebase Console](https://console.firebase.google.com/)
2. Tạo project mới → đặt tên (ví dụ: `doc-manager-app`)
3. Enable **Authentication** → Sign-in method → **Anonymous** (cho demo)
4. Enable **Storage** → Get started → Chọn region gần Việt Nam (asia-southeast1)

### 1.2 Cấu hình Firebase cho Flutter
```bash
# Cài đặt FlutterFire CLI
dart pub global activate flutterfire_cli

# Login Firebase
firebase login

# Cấu hình Flutter app
flutterfire configure
```
- Chọn project Firebase vừa tạo
- Chọn platforms: Android, iOS, Web, Windows, Linux, macOS
- Sẽ generate file `lib/firebase_options.dart` (thay thế `lib/config/firebase_config.dart`)

### 1.3 Firebase Storage Rules
Vào Firebase Console → Storage → Rules:
```javascript
rules_version = '2';
service firebase.storage {
  match /b/{bucket}/o {
    match /users/{userId}/documents/{docId}/{fileName} {
      allow read, write: if request.auth != null && request.auth.uid == userId;
    }
  }
}
```

### 1.4 Lấy config cho Web (index.html)
Firebase Console → Project Settings → General → Your apps → Web app → Config
Thêm vào `web/index.html` trước `</head>`:
```html
<script type="module">
  import { initializeApp } from "https://www.gstatic.com/firebasejs/10.12.2/firebase-app.js";
  import { getAuth } from "https://www.gstatic.com/firebasejs/10.12.2/firebase-auth.js";
  import { getStorage } from "https://www.gstatic.com/firebasejs/10.12.2/firebase-storage.js";

  const firebaseConfig = {
    apiKey: "YOUR_API_KEY",
    authDomain: "YOUR_PROJECT.firebaseapp.com",
    projectId: "YOUR_PROJECT_ID",
    storageBucket: "YOUR_PROJECT.appspot.com",
    messagingSenderId: "YOUR_SENDER_ID",
    appId: "YOUR_APP_ID"
  };

  const app = initializeApp(firebaseConfig);
  const auth = getAuth(app);
  const storage = getStorage(app);
</script>
```

---

## 2. SUPABASE SETUP

### 2.1 Tạo Supabase Project
1. Vào [Supabase Dashboard](https://supabase.com/dashboard)
2. New Project → Organization → đặt tên (ví dụ: `doc-manager-db`)
3. Database Password: đặt password mạnh
4. Region: Singapore (ap-southeast-1) - gần Việt Nam nhất
5. Chờ ~2 phút để provision

### 2.2 Chạy SQL Schema
1. Vào SQL Editor → New Query
2. Copy nội dung từ file `supabase_schema.sql` vào
3. Run → Kiểm tra không có lỗi

> Nếu database đã được tạo trước đó và bạn chỉ cần bổ sung chức năng tag, chạy
> file `supabase_tags_schema.sql` trong SQL Editor. Script tạo `tags`,
> `document_tags`, bật RLS và tạm cấp quyền thao tác tag cho `anon`/`authenticated`
> (do app đang dùng Firebase Auth + anon key, chưa có Supabase JWT).

### 2.3 Lấy API Keys
Settings → API:
- **Project URL**: `https://lwebnjcszbldlqwjrcan.supabase.co` (đã có)
- **anon/public key**: `sb_publishable_2tJzWH1c8Z1Lm9Vud2hJyw_9f99nrwM` (đã có)

> ⚠️ **Không bao giờ dùng service_role key trong client app!**

### 2.4 Cấu hình Auth (Optional)
Authentication → Providers → Email → Enable
Authentication → URL Configuration:
- Site URL: `http://localhost:3000` (dev) / `https://yourdomain.com` (prod)
- Redirect URLs: thêm deep link scheme nếu có

### 2.5 Enable Realtime
Database → Replication → Enable cho tables: `documents`, `categories`

---

## 3. FLUTTER APP CONFIGURATION

### 3.1 Cài đặt dependencies
```bash
flutter pub get
```

### 3.2 Code đã cập nhật
Các file chính đã được sửa:
- `lib/main.dart` - Khởi tạo Firebase + Supabase
- `lib/functions.dart` - Business logic (upload, CRUD)
- `lib/services/supabase_service.dart` - Supabase client
- `lib/services/firebase_storage_service.dart` - Firebase Storage client
- `lib/pages/home_page.dart` - UI với realtime
- `lib/pages/document_form_page.dart` - Form với upload progress
- `lib/struct/document_model.dart` - Model mở rộng (fileUrl, storagePath)

### 3.3 Chạy app
```bash
# Debug
flutter run -d chrome          # Web
flutter run -d android         # Android
flutter run -d ios             # iOS
flutter run -d windows         # Windows
flutter run -d linux           # Linux
flutter run -d macos           # macOS

# Release
flutter build apk --release
flutter build ios --release
flutter build web --release
```

---

## 4. KIỂM TRA HOẠT ĐỘNG

### 4.1 Test Checklist
- [ ] App khởi động không lỗi
- [ ] Đăng nhập anonymous Firebase thành công (chip "Online" xanh)
- [ ] Load categories từ Supabase
- [ ] Thêm tài liệu mới không file
- [ ] Thêm tài liệu có file → upload Firebase Storage
- [ ] Mở file từ URL Firebase Storage
- [ ] Sửa tài liệu (thay file, đổi category)
- [ ] Xóa tài liệu → xóa luôn file trên Storage
- [ ] Realtime: mở 2 tab, thêm/sửa/xóa trên tab 1 → tab 2 cập nhật ngay
- [ ] Tìm kiếm, lọc theo category
- [ ] Tạo/sửa/xóa tag; gán nhiều tag trong form tài liệu
- [ ] Tìm theo tên tag và lọc tài liệu theo nhiều tag

### 4.2 Debug común issues
| Lỗi | Nguyên nhân | Khắc phục |
|-----|-------------|-----------|
| `FirebaseAppNotInitialized` | Chưa call `Firebase.initializeApp()` | Check `main.dart` |
| `Supabase not initialized` | Chưa call `Supabase.initialize()` | Check `main.dart` |
| `Permission denied` Storage | Sai Storage Rules | Check Rules Firebase |
| `RLS policy violation` | Sai user_id hoặc RLS | Check Supabase RLS policies |
| `CORS error` web | Chưa config CORS Storage | Config CORS Firebase/Supabase |
| `Realtime not working` | Chưa enable replication | Database → Replication |

---

## 5. CẤU TRÚC LƯU TRỮ

```
Firebase Storage:
└── users/
    └── {userId}/          # Firebase Auth UID
        └── documents/
            └── {docId}/   # Supabase Document ID
                └── {uuid}.{ext}

Supabase Database:
└── documents table:
    ├── id (BIGSERIAL)
    ├── title, description
    ├── file_url (Firebase download URL)
    ├── storage_path (Firebase path: users/{uid}/documents/{docId}/{file})
    ├── category_id (FK → categories)
    ├── user_id (Firebase Auth UID)
    └── created_at, updated_at
```

---

## 6. TRIỂN KHAI PRODUCTION

### 6.1 Firebase
- Upgrade plan Blaze (pay-as-you-go)
- Config custom domain
- Enable App Check
- Setup monitoring/alerts

### 6.2 Supabase
- Upgrade Pro plan
- Config custom domain
- Enable Point-in-Time Recovery
- Setup read replicas nếu cần

### 6.3 Flutter Build
```bash
# Android
flutter build appbundle --release

# iOS
flutter build ipa --release

# Web
flutter build web --release --web-renderer canvaskit
```

---

## 7. FILES QUAN TRỌNG

| File | Mô tả |
|------|-------|
| `lib/main.dart` | Entry point, init Firebase + Supabase |
| `lib/functions.dart` | Business logic (CRUD + upload) |
| `lib/services/supabase_service.dart` | Supabase client wrapper |
| `lib/services/firebase_storage_service.dart` | Firebase Storage wrapper |
| `lib/config/supabase_config.dart` | Supabase config (URL, anon key) |
| `lib/firebase_options.dart` | Firebase config (auto-generated) |
| `supabase_schema.sql` | Database schema + RLS + Realtime |
| `SETUP_GUIDE.md` | File này |

---

## 8. HỖ TRỢ

Nếu gặp lỗi:
1. Check Flutter console logs
2. Check Firebase Console → Authentication/Storage logs
3. Check Supabase Dashboard → Logs → API/Database/Realtime
4. Xem Network tab trong DevTools (F12) cho web

**Happy coding! 🚀**