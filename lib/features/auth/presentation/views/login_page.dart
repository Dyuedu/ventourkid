import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/providers.dart';
import '../../../../shared/theme/app_theme.dart';
import '../../data/datasources/google_sign_in_service.dart';
import '../widgets/auth_scaffold.dart';

class LoginPage extends ConsumerStatefulWidget {
  const LoginPage({super.key});

  @override
  ConsumerState<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends ConsumerState<LoginPage> {
  final _accountController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _rememberMe = false;
  bool _obscurePassword = true;
  bool _submitted = false;
  final Set<String> _touchedFields = {};

  @override
  void dispose() {
    _accountController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  String? _accountError() {
    final value = _accountController.text.trim();
    if (value.isEmpty) {
      return 'Vui lòng nhập email hoặc số điện thoại.';
    }

    final phone = value.replaceAll(RegExp(r'[\s.-]'), '');
    final isPhone = RegExp(r'^(0|\+84)[0-9]{9,10}$').hasMatch(phone);
    final isEmail = RegExp(
      r'^[^\s@]+@[^\s@]+\.[^\s@]+$',
      caseSensitive: false,
    ).hasMatch(value);

    if (!isPhone && !isEmail) {
      return 'Email hoặc số điện thoại chưa đúng định dạng.';
    }

    return null;
  }

  String? _passwordError() {
    final value = _passwordController.text;
    if (value.isEmpty) {
      return 'Vui lòng nhập mật khẩu.';
    }
    if (value.length < 6) {
      return 'Mật khẩu cần có ít nhất 6 ký tự.';
    }
    return null;
  }

  String? _visibleError(String field, String? Function() validator) {
    if (!_submitted && !_touchedFields.contains(field)) {
      return null;
    }
    return validator();
  }

  bool get _isFormValid => _accountError() == null && _passwordError() == null;

  Future<void> _signIn() async {
    setState(() => _submitted = true);
    ref.read(authViewModelProvider.notifier).clearError();
    if (!_isFormValid) {
      return;
    }

    final success = await ref
        .read(authViewModelProvider.notifier)
        .login(
          identifier: _accountController.text.trim(),
          password: _passwordController.text,
        );

    if (mounted && success) {
      await ref.read(notificationRealtimeProvider.notifier).start();
      await ref.read(pushNotificationServiceProvider).syncTokenWithBackend();
      if (mounted) context.go('/home');
    }
  }

  Future<void> _signInWithGoogle() async {
    ref.read(authViewModelProvider.notifier).clearError();
    try {
      final googleResult = await ref.read(googleSignInServiceProvider).signIn();

      final success = await ref
          .read(authViewModelProvider.notifier)
          .googleLogin(googleToken: googleResult.accessToken);

      if (mounted && success) {
        await ref.read(notificationRealtimeProvider.notifier).start();
        await ref.read(pushNotificationServiceProvider).syncTokenWithBackend();
        if (mounted) context.go('/home');
      }
    } on GoogleSignInCancelledException {
      // User pressed back / dismissed the picker — no error toast.
      return;
    } catch (e) {
      if (!mounted) return;
      final message = e is GoogleSignInServiceException
          ? e.message
          : 'Không thể đăng nhập Google. Vui lòng thử lại.';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
    }
  }

  void _touch(String field) {
    ref.read(authViewModelProvider.notifier).clearError();
    setState(() => _touchedFields.add(field));
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final authState = ref.watch(authViewModelProvider);

    return AuthMediaScaffold(
      child: AuthViewport(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(18, 36, 18, 24),
          child: Column(
            children: [
              const AuthBrandHero(
                subtitle: 'Theo dõi hành trình của con trong từng chuyến đi.',
              ),
              const SizedBox(height: 28),
              AuthFormCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'Đăng nhập',
                      style: textTheme.headlineSmall?.copyWith(
                        color: AppTheme.ink,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Truy cập thông tin tour, điểm danh và thông báo an toàn.',
                      style: textTheme.bodyMedium?.copyWith(
                        color: AppTheme.onSurfaceVariant,
                        height: 1.45,
                      ),
                    ),
                    const SizedBox(height: 20),
                    AuthField(
                      label: 'Email hoặc số điện thoại',
                      controller: _accountController,
                      placeholder: 'Nhập email hoặc số điện thoại',
                      icon: Icons.person,
                      keyboardType: TextInputType.emailAddress,
                      textInputAction: TextInputAction.next,
                      errorText: _visibleError('account', _accountError),
                      onChanged: (_) => _touch('account'),
                    ),
                    const SizedBox(height: 16),
                    AuthField(
                      label: 'Mật khẩu',
                      controller: _passwordController,
                      placeholder: '••••••••',
                      icon: Icons.lock,
                      obscureText: _obscurePassword,
                      textInputAction: TextInputAction.done,
                      errorText: _visibleError('password', _passwordError),
                      onChanged: (_) => _touch('password'),
                      suffix: IconButton(
                        tooltip: _obscurePassword
                            ? 'Hiện mật khẩu'
                            : 'Ẩn mật khẩu',
                        onPressed: () {
                          setState(() => _obscurePassword = !_obscurePassword);
                        },
                        icon: Icon(
                          _obscurePassword
                              ? Icons.visibility_off
                              : Icons.visibility,
                          color: AppTheme.neutral700,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      alignment: WrapAlignment.spaceBetween,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Checkbox(
                              value: _rememberMe,
                              side: const BorderSide(
                                color: AppTheme.neutral300,
                              ),
                              activeColor: AppTheme.cta,
                              checkColor: Colors.white,
                              onChanged: (value) {
                                setState(() => _rememberMe = value ?? false);
                              },
                            ),
                            Text(
                              'Ghi nhớ đăng nhập',
                              style: textTheme.bodySmall?.copyWith(
                                color: AppTheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                        TextButton(
                          onPressed: () => context.go('/forgot-password'),
                          child: const Text('Quên mật khẩu?'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    if (authState.errorMessage != null) ...[
                      Text(
                        authState.errorMessage!,
                        style: textTheme.bodySmall?.copyWith(
                          color: AppTheme.accentRed,
                        ),
                      ),
                      const SizedBox(height: 8),
                    ],
                    AuthActionButton(
                      label: 'Đăng nhập',
                      onPressed: _signIn,
                      pill: true,
                      isLoading: authState.isLoggingIn,
                    ),
                    const SizedBox(height: 16),
                    Center(
                      child: TextButton(
                        onPressed: () => context.go('/register-parent'),
                        child: const Text('Chưa có tài khoản? Đăng ký'),
                      ),
                    ),
                    const SizedBox(height: 12),
                    const AuthDivider(label: 'HOẶC'),
                    const SizedBox(height: 16),
                    AuthSocialButton(
                      label: 'Tiếp tục với Google',
                      onPressed: authState.isLoading ? null : _signInWithGoogle,
                      isLoading: authState.isGoogleLoggingIn,
                      leading: Container(
                        width: 20,
                        height: 20,
                        alignment: Alignment.center,
                        decoration: const BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                        ),
                        child: Text(
                          'G',
                          style: textTheme.labelLarge?.copyWith(
                            color: const Color(0xFFDB4437),
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 22),
              const TrustNote(
                text:
                    'Dữ liệu vị trí của trẻ được bảo vệ theo quyền riêng tư gia đình.',
              ),
            ],
          ),
        ),
      ),
    );
  }
}
