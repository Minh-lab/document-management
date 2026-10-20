import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import 'package:flutter/material.dart';

import '../colors.dart';
import '../functions.dart';
import '../widgets/state_views.dart';
import 'app_shell.dart';
import 'login_page.dart';

/// Quyết định hiển thị màn hình đăng nhập hay ứng dụng dựa trên phiên Firebase.
class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<firebase_auth.User?>(
      stream: authStateChanges,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const _SplashScreen();
        }

        final user = snapshot.data;
        if (user == null) {
          return const LoginPage();
        }

        return SessionBootstrap(key: ValueKey(user.uid));
      },
    );
  }
}

/// Đồng bộ người dùng sang Supabase và nạp dữ liệu khởi tạo trước khi vào app.
class SessionBootstrap extends StatefulWidget {
  const SessionBootstrap({super.key});

  @override
  State<SessionBootstrap> createState() => _SessionBootstrapState();
}

class _SessionBootstrapState extends State<SessionBootstrap> {
  bool _isReady = false;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _prepare();
  }

  Future<void> _prepare() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      await initializeServices();
      if (!mounted) return;
      setState(() {
        _isReady = true;
        _isLoading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error.toString().replaceFirst('Exception: ', '');
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isReady) return const AppShell();

    if (_isLoading) {
      return const _SplashScreen(message: 'Đang chuẩn bị dữ liệu...');
    }

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: AppErrorView(
                title: 'Không thể đồng bộ dữ liệu',
                message: _error ?? 'Đã có lỗi xảy ra khi kết nối Supabase.',
                onRetry: _prepare,
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(bottom: 24),
              child: TextButton(
                onPressed: () => setState(() => _isReady = true),
                child: const Text('Tiếp tục với dữ liệu hiện có'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SplashScreen extends StatelessWidget {
  const _SplashScreen({this.message = 'Đang kiểm tra đăng nhập...'});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: AppColors.primary,
                borderRadius: BorderRadius.circular(18),
              ),
              child: const Icon(
                Icons.school_outlined,
                color: Colors.white,
                size: 34,
              ),
            ),
            const SizedBox(height: 24),
            const SizedBox(
              width: 26,
              height: 26,
              child: CircularProgressIndicator(strokeWidth: 2.6),
            ),
            const SizedBox(height: 14),
            Text(
              message,
              style: const TextStyle(color: AppColors.textSecondary),
            ),
          ],
        ),
      ),
    );
  }
}
