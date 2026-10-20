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
}
