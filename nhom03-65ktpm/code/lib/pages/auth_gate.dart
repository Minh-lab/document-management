import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import 'package:flutter/material.dart';

import '../colors.dart';
import '../functions.dart';
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
  String? _syncWarning;
  bool _warningShown = false;

  @override
  void initState() {
    super.initState();
    _prepare();
  }

  Future<void> _prepare() async {
    try {
      await initializeServices();
      if (!mounted || _syncWarning == null) return;
      setState(() {
        _syncWarning = null;
        _warningShown = false;
      });
    } catch (error) {
      if (!mounted) return;
      debugPrint('Không đồng bộ được phiên Supabase: $error');
      setState(() {
        _syncWarning = error.toString().replaceFirst('Exception: ', '');
        _warningShown = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Builder(
      builder: (context) {
        final warning = _syncWarning;
        if (warning != null && !_warningShown) {
          _warningShown = true;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                duration: const Duration(seconds: 8),
                content: Text(
                  'Đăng nhập thành công nhưng đồng bộ dữ liệu thất bại: '
                  '$warning',
                ),
                action: SnackBarAction(label: 'Thử lại', onPressed: _prepare),
              ),
            );
          });
        }
        return const AppShell();
      },
    );
  }
}

class _SplashScreen extends StatelessWidget {
  const _SplashScreen();

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
              'Đang kiểm tra đăng nhập...',
              style: const TextStyle(color: AppColors.textSecondary),
            ),
          ],
        ),
      ),
    );
  }
}
