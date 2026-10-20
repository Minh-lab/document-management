import 'package:flutter/material.dart';

import '../colors.dart';
import '../functions.dart';
import '../utils/responsive.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool _isRegister = false;
  bool _obscurePassword = true;
  bool _isLoading = false;
  String? _error;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      if (_isRegister) {
        await registerWithEmail(
          email: _emailController.text,
          password: _passwordController.text,
          displayName: _nameController.text,
        );
      } else {
        await signInWithEmail(
          email: _emailController.text,
          password: _passwordController.text,
        );
      }
      // AuthGate sẽ tự chuyển màn hình khi trạng thái đăng nhập thay đổi.
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = friendlyAuthError(error);
      });
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _signInWithGoogle() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final credential = await signInWithGoogle();
      if (credential == null && mounted) {
        // Người dùng hủy hộp thoại chọn tài khoản.
        setState(() => _isLoading = false);
      }
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = friendlyAuthError(error);
        _isLoading = false;
      });
    }
  }

  Future<void> _continueAsGuest() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      await signInAsGuest();
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = friendlyAuthError(error);
        _isLoading = false;
      });
    }
  }

  void _switchMode(bool register) {
    setState(() {
      _isRegister = register;
      _error = null;
      _formKey.currentState?.reset();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1120),
              child: context.isExpanded
                  ? ConstrainedBox(
                      constraints: const BoxConstraints(minHeight: 620),
                      child: IntrinsicHeight(
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            const Expanded(flex: 5, child: _BrandPanel()),
                            const SizedBox(width: 40),
                            Expanded(
                              flex: 4,
                              child: Center(child: _buildCard()),
                            ),
                          ],
                        ),
                      ),
                    )
                  : Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 440),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            _buildCompactHeader(),
                            const SizedBox(height: 24),
                            _buildCard(),
                          ],
                        ),
                      ),
                    ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCompactHeader() {
    return Column(
      children: [
        Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            color: AppColors.primary,
            borderRadius: BorderRadius.circular(16),
          ),
          child: const Icon(
            Icons.school_outlined,
            color: Colors.white,
            size: 30,
          ),
        ),
        const SizedBox(height: 14),
        const Text(
          'StudyDocs',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w800,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 4),
        const Text(
          'Quản lý tài liệu học tập của bạn',
          style: TextStyle(color: AppColors.textSecondary),
        ),
      ],
    );
  }

  Widget _buildCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SegmentedButton<bool>(
                segments: const [
                  ButtonSegment(value: false, label: Text('Đăng nhập')),
                  ButtonSegment(value: true, label: Text('Đăng ký')),
                ],
                selected: {_isRegister},
                onSelectionChanged: _isLoading
                    ? null
                    : (selection) => _switchMode(selection.first),
                showSelectedIcon: false,
              ),
              const SizedBox(height: 20),
              Text(
                _isRegister ? 'Tạo tài khoản mới' : 'Chào mừng trở lại',
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                _isRegister
                    ? 'Đăng ký để lưu và chia sẻ tài liệu của bạn.'
                    : 'Đăng nhập để tiếp tục quản lý tài liệu.',
                style: const TextStyle(color: AppColors.textSecondary),
              ),
              if (_error != null) ...[
                const SizedBox(height: 16),
                _ErrorBanner(message: _error!),
              ],
              const SizedBox(height: 20),
              if (_isRegister) ...[
                TextFormField(
                  controller: _nameController,
                  textInputAction: TextInputAction.next,
                  enabled: !_isLoading,
                  decoration: const InputDecoration(
                    labelText: 'Họ tên (tùy chọn)',
                    prefixIcon: Icon(Icons.person_outline),
                  ),
                ),
                const SizedBox(height: 14),
              ],
              TextFormField(
                controller: _emailController,
                enabled: !_isLoading,
                keyboardType: TextInputType.emailAddress,
                textInputAction: TextInputAction.next,
                autofillHints: const [AutofillHints.email],
                decoration: const InputDecoration(
                  labelText: 'Email',
                  hintText: 'you@example.com',
                  prefixIcon: Icon(Icons.mail_outline),
                ),
                validator: (value) {
                  final email = value?.trim() ?? '';
                  if (email.isEmpty) return 'Vui lòng nhập email';
                  final isValid = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$')
                      .hasMatch(email);
                  if (!isValid) return 'Email không hợp lệ';
                  return null;
                },
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _passwordController,
                enabled: !_isLoading,
                obscureText: _obscurePassword,
                textInputAction: _isRegister
                    ? TextInputAction.next
                    : TextInputAction.done,
                autofillHints: [
                  _isRegister
                      ? AutofillHints.newPassword
                      : AutofillHints.password,
                ],
                onFieldSubmitted: (_) {
                  if (!_isRegister) _submit();
                },
                decoration: InputDecoration(
                  labelText: 'Mật khẩu',
                  prefixIcon: const Icon(Icons.lock_outline),
                  suffixIcon: IconButton(
                    tooltip: _obscurePassword ? 'Hiện mật khẩu' : 'Ẩn mật khẩu',
                    icon: Icon(
                      _obscurePassword
                          ? Icons.visibility_outlined
                          : Icons.visibility_off_outlined,
                    ),
                    onPressed: () =>
                        setState(() => _obscurePassword = !_obscurePassword),
                  ),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Vui lòng nhập mật khẩu';
                  }
                  if (value.length < 6) {
                    return 'Mật khẩu phải có ít nhất 6 ký tự';
                  }
                  return null;
                },
              ),
              if (_isRegister) ...[
                const SizedBox(height: 14),
                TextFormField(
                  controller: _confirmPasswordController,
                  enabled: !_isLoading,
                  obscureText: _obscurePassword,
                  textInputAction: TextInputAction.done,
                  onFieldSubmitted: (_) => _submit(),
                  decoration: const InputDecoration(
                    labelText: 'Nhập lại mật khẩu',
                    prefixIcon: Icon(Icons.lock_reset_outlined),
                  ),
                  validator: (value) {
                    if (value != _passwordController.text) {
                      return 'Mật khẩu nhập lại không khớp';
                    }
                    return null;
                  },
                ),
              ],
              const SizedBox(height: 22),
              FilledButton(
                onPressed: _isLoading ? null : _submit,
                child: _isLoading
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.4,
                          color: Colors.white,
                        ),
                      )
                    : Text(_isRegister ? 'Đăng ký' : 'Đăng nhập'),
              ),
              const SizedBox(height: 18),
              const _OrDivider(),
              const SizedBox(height: 18),
              OutlinedButton(
                onPressed: _isLoading ? null : _signInWithGoogle,
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _GoogleMark(),
                    SizedBox(width: 10),
                    Flexible(
                      child: Text(
                        'Đăng nhập bằng Google',
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: _isLoading ? null : _continueAsGuest,
                child: const Text('Dùng thử không cần tài khoản'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BrandPanel extends StatelessWidget {
  const _BrandPanel();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(40),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.primaryDark, AppColors.primary],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(
                  Icons.school_outlined,
                  color: Colors.white,
                  size: 26,
                ),
              ),
              const SizedBox(width: 14),
              const Text(
                'StudyDocs',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const Spacer(),
          const Text(
            'Tài liệu học tập,\ngọn gàng và dễ tìm.',
            style: TextStyle(
              color: Colors.white,
              fontSize: 34,
              height: 1.2,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Lưu trữ, phân loại và chia sẻ tài liệu trên mọi thiết bị — '
            'đồng bộ tức thì giữa Mobile và Web.',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.86),
              fontSize: 15,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 32),
          const _BrandFeature(
            icon: Icons.cloud_done_outlined,
            text: 'Đồng bộ Supabase Storage',
          ),
          const SizedBox(height: 14),
          const _BrandFeature(
            icon: Icons.devices_outlined,
            text: 'Responsive cho Mobile và Web',
          ),
          const SizedBox(height: 14),
          const _BrandFeature(
            icon: Icons.share_outlined,
            text: 'Chia sẻ và phân quyền tài liệu',
          ),
          const Spacer(),
          Text(
            'Flutter · Firebase · Supabase',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.7),
              fontSize: 12,
              letterSpacing: 0.6,
            ),
          ),
        ],
      ),
    );
  }
}

class _BrandFeature extends StatelessWidget {
  const _BrandFeature({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: Colors.white.withValues(alpha: 0.9), size: 20),
        const SizedBox(width: 10),
        Text(
          text,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.92),
            fontSize: 14,
          ),
        ),
      ],
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
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
              message,
              style: const TextStyle(color: AppColors.error, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }
}

class _OrDivider extends StatelessWidget {
  const _OrDivider();

  @override
  Widget build(BuildContext context) {
    return const Row(
      children: [
        Expanded(child: Divider()),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 12),
          child: Text(
            'hoặc',
            style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
          ),
        ),
        Expanded(child: Divider()),
      ],
    );
  }
}

class _GoogleMark extends StatelessWidget {
  const _GoogleMark();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 20,
      height: 20,
      alignment: Alignment.center,
      decoration: const BoxDecoration(
        color: Color(0xFFF1F3F4),
        shape: BoxShape.circle,
      ),
      child: const Text(
        'G',
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w800,
          color: Color(0xFF4285F4),
        ),
      ),
    );
  }
}
