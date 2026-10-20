import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import 'package:flutter/material.dart';

import '../colors.dart';
import '../functions.dart';
import '../struct/user_model.dart';
import '../utils/responsive.dart';
import '../widgets/state_views.dart';
import '../widgets/user_menu_button.dart';

/// Trang cài đặt: hiển thị và cập nhật thông tin tài khoản.
class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  firebase_auth.User? _user;
  UserModel? _profile;
  bool _saving = false;
  StreamSubscription<firebase_auth.User?>? _authSubscription;

  @override
  void initState() {
    super.initState();
    _user = currentFirebaseUser;
    _authSubscription = authStateChanges.listen((user) {
      if (!mounted) return;
      setState(() => _user = user);
      _loadProfile();
    });
    _loadProfile();
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    super.dispose();
  }

  Future<void> _loadProfile() async {
    if (currentUserId.isEmpty) return;
    try {
      final profile = await getCurrentUserProfile();
      if (!mounted) return;
      setState(() => _profile = profile);
    } catch (error) {
      // Không chặn trang cài đặt nếu Supabase tạm thời không phản hồi.
      debugPrint('Không tải được hồ sơ Supabase: $error');
    }
  }

  String get _displayName {
    final firebaseName = _user?.displayName?.trim();
    if (firebaseName != null && firebaseName.isNotEmpty) return firebaseName;

    final profileName = _profile?.displayName?.trim();
    if (profileName != null && profileName.isNotEmpty) return profileName;

    final email = _user?.email;
    if (email != null && email.contains('@')) return email.split('@').first;
    return 'Người dùng';
  }

  String get _email => _user?.email ?? _profile?.email ?? 'Không có email';

  String get _accountType {
    final user = _user;
    if (user == null) return 'Chưa đăng nhập';
    if (user.isAnonymous) return 'Khách (dùng thử)';
    for (final provider in user.providerData) {
      if (provider.providerId == 'google.com') return 'Google';
      if (provider.providerId == 'password') return 'Email & mật khẩu';
    }
    return 'Thành viên';
  }

  DateTime? get _joinedAt =>
      _user?.metadata.creationTime ?? _profile?.createdAt;

  String get _userId => _user?.uid ?? _profile?.id ?? '—';

  String _formatDate(DateTime? date) {
    if (date == null) return '—';
    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');
    return '$day/$month/${date.year}';
  }

  Future<void> _openEditor() async {
    final user = _user;
    if (user == null) return;

    final initialName = _displayName;
    final initialPhoto = user.photoURL ?? _profile?.avatarUrl ?? '';

    final draft = await (context.isCompact
        ? showModalBottomSheet<_ProfileDraft>(
            context: context,
            isScrollControlled: true,
            useSafeArea: true,
            showDragHandle: true,
            builder: (_) => _ProfileEditor(
              initialName: initialName,
              initialPhotoUrl: initialPhoto,
              isSheet: true,
            ),
          )
        : showDialog<_ProfileDraft>(
            context: context,
            builder: (_) => Dialog(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 460),
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: _ProfileEditor(
                    initialName: initialName,
                    initialPhotoUrl: initialPhoto,
                    isSheet: false,
                  ),
                ),
              ),
            ),
          ));

    if (draft == null || !mounted) return;
    await _saveProfile(draft);
  }

  Future<void> _saveProfile(_ProfileDraft draft) async {
    setState(() => _saving = true);
    try {
      final updated = await updateAccountProfile(
        displayName: draft.displayName,
        photoURL: draft.photoUrl,
      );
      if (!mounted) return;
      setState(() {
        _user = updated;
        _saving = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Đã cập nhật thông tin tài khoản')),
      );
    } catch (error) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Không thể cập nhật: ${friendlyAuthError(error)}'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_user == null) {
      return const AppErrorView(
        title: 'Chưa đăng nhập',
        message: 'Vui lòng đăng nhập để xem thông tin tài khoản.',
      );
    }

    final header = _ProfileHeaderCard(
      name: _displayName,
      email: _email,
      accountType: _accountType,
      photoUrl: _user?.photoURL ?? _profile?.avatarUrl,
      saving: _saving,
      onEdit: _openEditor,
    );

    final info = _AccountInfoCard(
      email: _email,
      accountType: _accountType,
      joinedAt: _formatDate(_joinedAt),
      userId: _userId,
      note: _accountType == 'Khách (dùng thử)'
          ? 'Bạn đang dùng tài khoản khách. Hãy đăng ký tài khoản để lưu dữ liệu lâu dài.'
          : 'Email dùng để đăng nhập và không thể thay đổi tại đây.',
    );

    final options = _AccountOptionsCard(
      onSignOut: () => confirmAndSignOut(context),
    );

    return SingleChildScrollView(
      padding: context.pagePadding,
      child: ContentWidth(
        maxWidth: 1000,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            header,
            const SizedBox(height: 16),
            if (context.isExpanded)
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(flex: 3, child: info),
                  const SizedBox(width: 16),
                  Expanded(flex: 2, child: options),
                ],
              )
            else ...[
              info,
              const SizedBox(height: 16),
              options,
            ],
            const SizedBox(height: 20),
            const Text(
              'StudyDocs • Nhóm 03 • 65KTPM',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}

class _ProfileHeaderCard extends StatelessWidget {
  const _ProfileHeaderCard({
    required this.name,
    required this.email,
    required this.accountType,
    required this.photoUrl,
    required this.saving,
    required this.onEdit,
  });

  final String name;
  final String email;
  final String accountType;
  final String? photoUrl;
  final bool saving;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    final padding = context.isCompact ? 16.0 : 24.0;

    return Card(
      child: Padding(
        padding: EdgeInsets.all(padding),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final compact = constraints.maxWidth < 560;

            final identity = Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                _ProfileAvatar(
                  photoUrl: photoUrl,
                  name: name,
                  radius: compact ? 30 : 36,
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.titleLarge
                            ?.copyWith(fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        email,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 13,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.primaryLight,
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          accountType,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: AppColors.primaryDark,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            );

            final editButton = FilledButton.tonalIcon(
              onPressed: saving ? null : onEdit,
              icon: saving
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.edit_outlined, size: 18),
              label: Text(saving ? 'Đang lưu...' : 'Chỉnh sửa'),
            );

            if (compact) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [identity, const SizedBox(height: 16), editButton],
              );
            }

            return Row(
              children: [
                Expanded(child: identity),
                const SizedBox(width: 16),
                editButton,
              ],
            );
          },
        ),
      ),
    );
  }
}

class _AccountInfoCard extends StatelessWidget {
  const _AccountInfoCard({
    required this.email,
    required this.accountType,
    required this.joinedAt,
    required this.userId,
    required this.note,
  });

  final String email;
  final String accountType;
  final String joinedAt;
  final String userId;
  final String note;

  @override
  Widget build(BuildContext context) {
    final items = [
      _InfoItem(icon: Icons.mail_outline, label: 'Email', value: email),
      _InfoItem(
        icon: Icons.verified_user_outlined,
        label: 'Loại tài khoản',
        value: accountType,
      ),
      _InfoItem(
        icon: Icons.calendar_today_outlined,
        label: 'Ngày tham gia',
        value: joinedAt,
      ),
      _InfoItem(icon: Icons.fingerprint, label: 'Mã người dùng', value: userId),
    ];

    return Card(
      child: Padding(
        padding: EdgeInsets.all(context.isCompact ? 16 : 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Thông tin tài khoản',
              style: Theme.of(context).textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 4),
            const Text(
              'Thông tin được đồng bộ giữa Firebase và Supabase.',
              style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 8),
            for (final item in items) ...[
              const Divider(height: 1),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(item.icon, size: 20, color: AppColors.primary),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item.label,
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.textSecondary,
                            ),
                          ),
                          const SizedBox(height: 2),
                          SelectableText(
                            item.value,
                            style: const TextStyle(
                              fontSize: 14,
                              color: AppColors.textPrimary,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const Divider(height: 1),
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.background,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.border),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(
                    Icons.info_outline,
                    size: 18,
                    color: AppColors.textSecondary,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      note,
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AccountOptionsCard extends StatelessWidget {
  const _AccountOptionsCard({required this.onSignOut});

  final VoidCallback onSignOut;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: EdgeInsets.all(context.isCompact ? 16 : 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Tùy chọn tài khoản',
              style: Theme.of(context).textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            const Text(
              'Quản lý phiên đăng nhập trên thiết bị này.',
              style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 12),
            InkWell(
              onTap: onSignOut,
              borderRadius: BorderRadius.circular(12),
              child: const Padding(
                padding: EdgeInsets.symmetric(vertical: 10),
                child: Row(
                  children: [
                    Icon(Icons.logout, color: AppColors.error, size: 20),
                    SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Đăng xuất',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: AppColors.error,
                            ),
                          ),
                          SizedBox(height: 2),
                          Text(
                            'Thoát khỏi tài khoản trên thiết bị này',
                            style: TextStyle(
                              fontSize: 12,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Icon(Icons.chevron_right, color: AppColors.textSecondary),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProfileAvatar extends StatelessWidget {
  const _ProfileAvatar({
    required this.photoUrl,
    required this.name,
    required this.radius,
  });

  final String? photoUrl;
  final String name;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final trimmedName = name.trim();
    final initial = trimmedName.isEmpty ? '?' : trimmedName[0].toUpperCase();

    final fallback = CircleAvatar(
      radius: radius,
      backgroundColor: AppColors.primaryLight,
      child: Text(
        initial,
        style: TextStyle(
          fontSize: radius * 0.8,
          fontWeight: FontWeight.w700,
          color: AppColors.primaryDark,
        ),
      ),
    );

    final url = photoUrl?.trim() ?? '';
    if (url.isEmpty) return fallback;

    return ClipOval(
      child: Image.network(
        url,
        width: radius * 2,
        height: radius * 2,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => fallback,
      ),
    );
  }
}

class _InfoItem {
  const _InfoItem({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;
}

class _ProfileDraft {
  const _ProfileDraft({required this.displayName, required this.photoUrl});

  final String displayName;
  final String photoUrl;
}

class _ProfileEditor extends StatefulWidget {
  const _ProfileEditor({
    required this.initialName,
    required this.initialPhotoUrl,
    required this.isSheet,
  });

  final String initialName;
  final String initialPhotoUrl;
  final bool isSheet;

  @override
  State<_ProfileEditor> createState() => _ProfileEditorState();
}

class _ProfileEditorState extends State<_ProfileEditor> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _photoController;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.initialName);
    _photoController = TextEditingController(text: widget.initialPhotoUrl);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _photoController.dispose();
    super.dispose();
  }

  void _submit() {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    Navigator.of(context).pop(
      _ProfileDraft(
        displayName: _nameController.text.trim(),
        photoUrl: _photoController.text.trim(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final content = Form(
      key: _formKey,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Chỉnh sửa thông tin',
            style: Theme.of(context).textTheme.titleLarge
                ?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 4),
          const Text(
            'Cập nhật tên hiển thị và ảnh đại diện của bạn.',
            style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 20),
          TextFormField(
            controller: _nameController,
            textCapitalization: TextCapitalization.words,
            textInputAction: TextInputAction.next,
            maxLength: 50,
            decoration: const InputDecoration(
              labelText: 'Tên hiển thị',
              prefixIcon: Icon(Icons.person_outline),
              counterText: '',
            ),
            validator: (value) {
              final name = value?.trim() ?? '';
              if (name.isEmpty) return 'Vui lòng nhập tên hiển thị';
              if (name.length < 2) return 'Tên phải có ít nhất 2 ký tự';
              return null;
            },
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _photoController,
            keyboardType: TextInputType.url,
            decoration: const InputDecoration(
              labelText: 'Ảnh đại diện (URL)',
              hintText: 'https://...',
              prefixIcon: Icon(Icons.image_outlined),
              helperText: 'Để trống để dùng chữ cái đầu của tên.',
            ),
            validator: (value) {
              final url = value?.trim() ?? '';
              if (url.isEmpty) return null;
              final uri = Uri.tryParse(url);
              if (uri == null ||
                  !(uri.isScheme('http') || uri.isScheme('https')) ||
                  uri.host.isEmpty) {
                return 'Liên kết ảnh không hợp lệ';
              }
              return null;
            },
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Hủy'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton(
                  onPressed: _submit,
                  child: const Text('Lưu thay đổi'),
                ),
              ),
            ],
          ),
        ],
      ),
    );

    if (!widget.isSheet) return content;

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        child: content,
      ),
    );
  }
}
