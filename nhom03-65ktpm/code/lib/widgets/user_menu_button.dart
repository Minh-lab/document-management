import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import 'package:flutter/material.dart';

import '../colors.dart';
import '../functions.dart';

/// Menu tài khoản ở góc phải AppBar: thông tin người dùng và đăng xuất.
class UserMenuButton extends StatelessWidget {
  const UserMenuButton({super.key, this.onOpenSettings});

  /// Mở tab Cài đặt khi người dùng chọn mục tương ứng trong menu.
  final VoidCallback? onOpenSettings;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<firebase_auth.User?>(
      stream: authStateChanges,
      builder: (context, snapshot) {
        final user = snapshot.data ?? currentFirebaseUser;
        if (user == null) return const SizedBox.shrink();

        final name = _displayName(user);
        final initial = name.isNotEmpty ? name[0].toUpperCase() : 'U';

        return PopupMenuButton<String>(
          tooltip: 'Tài khoản',
          offset: const Offset(0, 48),
          onSelected: (value) async {
            if (value == 'settings') {
              onOpenSettings?.call();
            } else if (value == 'logout') {
              await confirmAndSignOut(context);
            } else if (value == 'upgrade_email') {
              if (!context.mounted) return;
              _showUpgradeDialog(context, isGoogle: false);
            } else if (value == 'upgrade_google') {
              if (!context.mounted) return;
              _showUpgradeDialog(context, isGoogle: true);
            }
          },
          itemBuilder: (context) => [
            PopupMenuItem<String>(
              enabled: false,
              child: Row(
                children: [
                  _Avatar(user: user, initial: initial, radius: 20),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          user.isAnonymous
                              ? 'Khách (dùng thử)'
                              : (user.email ?? 'Chưa có email'),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const PopupMenuDivider(),
            if (user.isAnonymous) ...[
              const PopupMenuItem<String>(
                value: 'upgrade_email',
                child: ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(
                    Icons.upgrade_outlined,
                    color: AppColors.primary,
                  ),
                  title: Text('Nâng cấp bằng Email'),
                ),
              ),
              const PopupMenuItem<String>(
                value: 'upgrade_google',
                child: ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(
                    Icons.g_mobiledata,
                    color: AppColors.primary,
                  ),
                  title: Text('Nâng cấp bằng Google'),
                ),
              ),
              const PopupMenuDivider(),
            ],
            if (onOpenSettings != null)
              const PopupMenuItem<String>(
                value: 'settings',
                child: ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(
                    Icons.settings_outlined,
                    color: AppColors.textPrimary,
                  ),
                  title: Text('Cài đặt tài khoản'),
                ),
              ),
            const PopupMenuItem<String>(
              value: 'logout',
              child: ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                leading: Icon(Icons.logout, color: AppColors.error),
                title: Text(
                  'Đăng xuất',
                  style: TextStyle(color: AppColors.error),
                ),
              ),
            ),
          ],
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: _Avatar(user: user, initial: initial, radius: 17),
          ),
        );
      },
    );
  }

  String _displayName(firebase_auth.User user) {
    final displayName = user.displayName?.trim();
    if (displayName != null && displayName.isNotEmpty) return displayName;
    final email = user.email;
    if (email != null && email.contains('@')) return email.split('@').first;
    return 'Người dùng';
  }
}

/// Hỏi xác nhận rồi đăng xuất khỏi ứng dụng.
Future<void> confirmAndSignOut(BuildContext context) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: const Text('Đăng xuất'),
      content: const Text('Bạn có chắc chắn muốn đăng xuất khỏi ứng dụng?'),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(false),
          child: const Text(
            'Hủy',
            style: TextStyle(color: AppColors.textSecondary),
          ),
        ),
        FilledButton(
          onPressed: () => Navigator.of(dialogContext).pop(true),
          style: FilledButton.styleFrom(backgroundColor: AppColors.error),
          child: const Text('Đăng xuất'),
        ),
      ],
    ),
  );

  if (confirmed != true) return;
  try {
    await signOut();
  } catch (error) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text('Không thể đăng xuất: $error')));
  }
}

class _Avatar extends StatelessWidget {
  const _Avatar({
    required this.user,
    required this.initial,
    required this.radius,
  });

  final firebase_auth.User user;
  final String initial;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final photoUrl = user.photoURL;
    final fallback = CircleAvatar(
      radius: radius,
      backgroundColor: AppColors.primaryLight,
      child: Text(
        initial,
        style: TextStyle(
          fontWeight: FontWeight.w700,
          color: AppColors.primaryDark,
          fontSize: radius * 0.9,
        ),
      ),
    );

    if (photoUrl == null || photoUrl.isEmpty) return fallback;

    return ClipOval(
      child: Image.network(
        photoUrl,
        width: radius * 2,
        height: radius * 2,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => fallback,
      ),
    );
  }
}

/// Dialog nâng cấp tài khoản ẩn danh
Future<void> _showUpgradeDialog(BuildContext context, {required bool isGoogle}) async {
  if (isGoogle) {
    // Nâng cấp bằng Google
    try {
      final credential = await upgradeAnonymousToGoogle();
      if (credential == null) return; // User cancelled
    } catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Nâng cấp thất bại: $error')),
      );
    }
    return;
  }

  // Nâng cấp bằng Email - hiển thị form nhập email/password
  final emailController = TextEditingController();
  final passwordController = TextEditingController();
  final confirmController = TextEditingController();
  final nameController = TextEditingController();
  bool obscure = true;
  bool isLoading = false;
  String? error;

  await showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (dialogContext) => StatefulBuilder(
      builder: (context, setState) => AlertDialog(
        title: const Text('Nâng cấp tài khoản'),
        content: SingleChildScrollView(
          child: Form(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Nhập thông tin để chuyển tài khoản dùng thử thành tài khoản chính thức.',
                  style: TextStyle(color: AppColors.textSecondary),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: nameController,
                  decoration: const InputDecoration(
                    labelText: 'Họ tên (tùy chọn)',
                    prefixIcon: Icon(Icons.person_outline),
                  ),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: emailController,
                  keyboardType: TextInputType.emailAddress,
                  autofillHints: const [AutofillHints.email],
                  decoration: const InputDecoration(
                    labelText: 'Email',
                    hintText: 'you@example.com',
                    prefixIcon: Icon(Icons.mail_outline),
                  ),
                  validator: (value) {
                    final email = value?.trim() ?? '';
                    if (email.isEmpty) return 'Vui lòng nhập email';
                    if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email)) {
                      return 'Email không hợp lệ';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: passwordController,
                  obscureText: obscure,
                  autofillHints: const [AutofillHints.newPassword],
                  decoration: InputDecoration(
                    labelText: 'Mật khẩu',
                    prefixIcon: const Icon(Icons.lock_outline),
                    suffixIcon: IconButton(
                      icon: Icon(obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined),
                      onPressed: () => setState(() => obscure = !obscure),
                    ),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) return 'Vui lòng nhập mật khẩu';
                    if (value.length < 6) return 'Mật khẩu ít nhất 6 ký tự';
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: confirmController,
                  obscureText: obscure,
                  decoration: const InputDecoration(
                    labelText: 'Nhập lại mật khẩu',
                    prefixIcon: Icon(Icons.lock_reset_outlined),
                  ),
                  validator: (value) {
                    if (value != passwordController.text) return 'Mật khẩu không khớp';
                    return null;
                  },
                ),
                if (error != null) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFDECEC),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFF5C2C2)),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.error_outline, color: AppColors.error, size: 20),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            error!,
                            style: const TextStyle(color: AppColors.error, fontSize: 13),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: isLoading ? null : () => Navigator.pop(context),
            child: const Text('Hủy'),
          ),
          FilledButton(
            onPressed: isLoading
                ? null
                : () async {
                    final formState = Form.of(context);
                    if (!formState.validate()) return;

                    setState(() => isLoading = true);
                    try {
                      await upgradeAnonymousToEmail(
                        email: emailController.text,
                        password: passwordController.text,
                        displayName: nameController.text.isNotEmpty ? nameController.text : null,
                      );
                      if (!context.mounted) return;
                      Navigator.pop(context);
                    } catch (e) {
                      setState(() => error = e.toString().replaceFirst('Exception: ', ''));
                    } finally {
                      if (context.mounted) setState(() => isLoading = false);
                    }
                  },
            child: isLoading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Nâng cấp'),
          ),
        ],
      ),
    ),
  );
}
