import 'package:code/pages/login_page.dart';
import 'package:code/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Future<void> pumpLoginPage(WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(theme: AppTheme.light(), home: const LoginPage()),
    );
    await tester.pump();
  }

  testWidgets('Màn hình đăng nhập hiển thị đủ trường và lựa chọn', (
    tester,
  ) async {
    await pumpLoginPage(tester);

    expect(find.text('Chào mừng trở lại'), findsOneWidget);
    expect(find.text('Email'), findsOneWidget);
    expect(find.text('Mật khẩu'), findsOneWidget);
    expect(find.text('Đăng nhập bằng Google'), findsOneWidget);
    expect(find.text('Dùng thử không cần tài khoản'), findsOneWidget);
  });

  testWidgets('Báo lỗi validation khi bỏ trống email và mật khẩu', (
    tester,
  ) async {
    await pumpLoginPage(tester);

    await tester.tap(find.widgetWithText(FilledButton, 'Đăng nhập'));
    await tester.pump();

    expect(find.text('Vui lòng nhập email'), findsOneWidget);
    expect(find.text('Vui lòng nhập mật khẩu'), findsOneWidget);
  });

  testWidgets('Chuyển sang chế độ đăng ký hiển thị ô nhập lại mật khẩu', (
    tester,
  ) async {
    await pumpLoginPage(tester);

    await tester.tap(find.text('Đăng ký').first);
    await tester.pump();

    expect(find.text('Tạo tài khoản mới'), findsOneWidget);
    expect(find.text('Nhập lại mật khẩu'), findsOneWidget);
    expect(find.text('Họ tên (tùy chọn)'), findsOneWidget);
  });

  testWidgets('Bố cục đăng nhập thích ứng theo breakpoint', (tester) async {
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await pumpLoginPage(tester);
    expect(
      find.text('Tài liệu học tập,\ngọn gàng và dễ tìm.'),
      findsOneWidget,
      reason: 'Màn hình rộng phải hiển thị panel thương hiệu hai cột.',
    );
    expect(tester.takeException(), isNull);

    tester.view.physicalSize = const Size(360, 800);
    await tester.pumpAndSettle();

    expect(
      find.text('Tài liệu học tập,\ngọn gàng và dễ tìm.'),
      findsNothing,
      reason: 'Màn hình hẹp chỉ hiển thị một cột.',
    );
    expect(find.text('Quản lý tài liệu học tập của bạn'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Không tràn bố cục ở 360px, 768px và 1440px', (tester) async {
    for (final size in const [
      Size(360, 800),
      Size(768, 1024),
      Size(1440, 900),
    ]) {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1.0;

      await pumpLoginPage(tester);
      expect(
        tester.takeException(),
        isNull,
        reason: 'Bố cục bị tràn ở kích thước $size',
      );
    }
    addTearDown(tester.view.reset);
  });

  testWidgets('Form đăng ký trên màn hình rộng không bị tràn', (tester) async {
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await pumpLoginPage(tester);
    await tester.tap(find.text('Đăng ký').first);
    await tester.pumpAndSettle();

    expect(find.text('Tạo tài khoản mới'), findsOneWidget);
    expect(find.text('Nhập lại mật khẩu'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
