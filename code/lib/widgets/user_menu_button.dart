import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import 'package:flutter/material.dart';

import '../colors.dart';
import '../functions.dart';

/// Menu tài khoản ở góc phải AppBar: thông tin người dùng và đăng xuất.
class UserMenuButton extends StatelessWidget {
  const UserMenuButton({super.key});

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
            if (value == 'logout') {
              await _confirmAndSignOut(context);
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

  Future<void> _confirmAndSignOut(BuildContext context) async {
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
    return CircleAvatar(
      radius: radius,
      backgroundColor: AppColors.primaryLight,
      backgroundImage: photoUrl != null ? NetworkImage(photoUrl) : null,
      child: photoUrl == null
          ? Text(
              initial,
              style: TextStyle(
                fontWeight: FontWeight.w700,
                color: AppColors.primaryDark,
                fontSize: radius * 0.9,
              ),
            )
          : null,
    );
  }
}
