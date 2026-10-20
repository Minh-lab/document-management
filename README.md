# Document Management

Ứng dụng quản lý tài liệu (Flutter) sử dụng Supabase + Firebase.

## Cấu trúc

```
.
├── code/   # Mã nguồn ứng dụng Flutter
└── docs/   # Tài liệu phân tích, đặc tả, báo cáo
```

## Yêu cầu môi trường

- Flutter SDK 3.x (Dart `^3.13.4`)
- Android Studio / VS Code + plugin Flutter
- Tài khoản Supabase (project đã cấu hình trong `code/lib/config/supabase_config.dart`)

## Cài đặt và chạy

```bash
cd code
flutter pub get
flutter run            # chọn thiết bị/emulator
flutter build apk --debug
```

Chi tiết cấu hình Supabase/Firebase xem tại [`code/SETUP_GUIDE.md`](code/SETUP_GUIDE.md).

## Cơ sở dữ liệu

Các file SQL nằm trong `code/`:

- `supabase_schema.sql` – tạo bảng
- `supabase_rls_policies.sql` – chính sách RLS
- `supabase_storage_policies.sql` – chính sách storage

## Quy trình làm việc nhóm

```bash
git clone <repo-url>
git checkout -b feature/ten-tinh-nang
# ... code ...
git add .
git commit -m "feat: mô tả ngắn gọn"
git push -u origin feature/ten-tinh-nang
```

Sau đó tạo Pull Request trên GitHub để review trước khi merge vào `main`.

Quy ước commit: `feat:`, `fix:`, `docs:`, `refactor:`, `test:`, `chore:`.

## Tài liệu

Xem thư mục [`docs/`](docs) và các báo cáo trong `code/` (`PROJECT_REPORT.md`, `TEST_PLAN.md`).
