import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/providers.dart';
import '../../../../shared/theme/app_theme.dart';
import '../widgets/auth_scaffold.dart';

class ForgotPasswordPage extends ConsumerStatefulWidget {
  const ForgotPasswordPage({super.key});

  @override
  ConsumerState<ForgotPasswordPage> createState() => _ForgotPasswordPageState();
}

class _ForgotPasswordPageState extends ConsumerState<ForgotPasswordPage> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _otpControllers = List.generate(6, (_) => TextEditingController());
  bool _emailTouched = false;
  bool _resetSubmitted = false;
  bool _otpSent = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    for (final controller in _otpControllers) {
      controller.dispose();
    }
    super.dispose();
  }

  String get _otp => _otpControllers.map((controller) => controller.text).join();

  String? get _emailError {
    final email = _emailController.text.trim();
    if (email.isEmpty) return 'Vui lòng nhập email.';
    if (!RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(email)) {
      return 'Email chưa đúng định dạng.';
    }
    return null;
  }

  String? get _otpError => RegExp(r'^\d{6}$').hasMatch(_otp)
      ? null
      : 'Vui lòng nhập đủ 6 chữ số xác minh.';

  String? get _passwordError {
    if (_passwordController.text.isEmpty) return 'Vui lòng nhập mật khẩu mới.';
    final password = _passwordController.text;
    if (password.length < 8 ||
        !RegExp(r'[A-Za-zÀ-ỹ]').hasMatch(password) ||
        !RegExp(r'\d').hasMatch(password) ||
        !RegExp(r'''[!@#$%^&*(),.?":{}|<>_\-+=/\\\[\];`~]''').hasMatch(password)) {
      return 'Mật khẩu cần từ 8 ký tự, gồm chữ, số và ký tự đặc biệt.';
    }
    return null;
  }

  String? get _confirmPasswordError {
    if (_confirmPasswordController.text.isEmpty) {
      return 'Vui lòng xác nhận mật khẩu mới.';
    }
    if (_confirmPasswordController.text != _passwordController.text) {
      return 'Mật khẩu xác nhận không khớp.';
    }
    return null;
  }

  Future<void> _sendOtp() async {
    setState(() => _emailTouched = true);
    if (_emailError != null) return;

    final viewModel = ref.read(authViewModelProvider.notifier);
    viewModel.clearError();
    final success = await viewModel.sendPasswordResetOtp(
      email: _emailController.text.trim(),
    );
    if (!mounted || !success) return;

    setState(() {
      _otpSent = true;
      _resetSubmitted = false;
      for (final controller in _otpControllers) {
        controller.clear();
      }
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Mã xác minh đã được gửi tới email của bạn.')),
    );
  }

  Future<void> _resetPassword() async {
    setState(() => _resetSubmitted = true);
    if (_emailError != null ||
        _otpError != null ||
        _passwordError != null ||
        _confirmPasswordError != null) {
      return;
    }

    final viewModel = ref.read(authViewModelProvider.notifier);
    viewModel.clearError();
    final success = await viewModel.resetPassword(
      email: _emailController.text.trim(),
      otpCode: _otp,
      newPassword: _passwordController.text,
      confirmPassword: _confirmPasswordController.text,
    );
    if (!mounted || !success) return;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Đặt lại mật khẩu thành công. Hãy đăng nhập lại.')),
    );
    context.go('/login');
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authViewModelProvider);
    final textTheme = Theme.of(context).textTheme;
    final errorMessage = authState.errorMessage;

    return Scaffold(
      backgroundColor: AppTheme.surfaceLight,
      body: Column(
        children: [
          AuthTopBar(title: 'Khôi phục mật khẩu', onBack: () => context.go('/login')),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 24, 16, 24),
              child: AuthViewport(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    AuthField(
                      label: 'Email',
                      controller: _emailController,
                      placeholder: 'Nhập email tài khoản',
                      icon: Icons.email_outlined,
                      keyboardType: TextInputType.emailAddress,
                      errorText: _emailTouched ? _emailError : null,
                      onChanged: (_) {
                        setState(() => _emailTouched = true);
                        ref.read(authViewModelProvider.notifier).clearError();
                      },
                    ),
                    const SizedBox(height: 16),
                    AuthActionButton(
                      label: _otpSent ? 'Gửi lại mã xác minh' : 'Gửi mã xác minh',
                      onPressed: _sendOtp,
                      isLoading: authState.isSendingPasswordResetOtp,
                    ),
                    if (_otpSent) ...[
                      const SizedBox(height: 32),
                      Text('Nhập mã và mật khẩu mới', style: textTheme.titleLarge?.copyWith(color: AppTheme.navy, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 6),
                      Text('Mã gồm 6 chữ số đã được gửi tới email của bạn.', style: textTheme.bodySmall?.copyWith(color: AppTheme.onSurfaceVariant)),
                      const SizedBox(height: 20),
                      Row(
                        children: [
                          for (var index = 0; index < _otpControllers.length; index++) ...[
                            Expanded(child: _OtpBox(controller: _otpControllers[index], onChanged: () => setState(() {}))),
                            if (index < _otpControllers.length - 1) const SizedBox(width: 8),
                          ],
                        ],
                      ),
                      if (_resetSubmitted && _otpError != null) _ErrorText(_otpError!),
                      const SizedBox(height: 16),
                      AuthField(label: 'Mật khẩu mới', controller: _passwordController, placeholder: 'Chữ, số và ký tự đặc biệt', icon: Icons.lock_outline, obscureText: true, errorText: _resetSubmitted ? _passwordError : null, onChanged: (_) => setState(() {})),
                      const SizedBox(height: 16),
                      AuthField(label: 'Xác nhận mật khẩu mới', controller: _confirmPasswordController, placeholder: 'Nhập lại mật khẩu mới', icon: Icons.lock_outline, obscureText: true, errorText: _resetSubmitted ? _confirmPasswordError : null, onChanged: (_) => setState(() {})),
                      if (errorMessage != null) _ErrorText(errorMessage),
                      const SizedBox(height: 20),
                      AuthActionButton(label: 'Đặt lại mật khẩu', onPressed: _resetPassword, isLoading: authState.isResettingPassword),
                    ] else if (errorMessage != null) ...[
                      _ErrorText(errorMessage),
                    ],
                    const SizedBox(height: 16),
                    AuthActionButton(label: 'Quay lại đăng nhập', onPressed: () => context.go('/login'), filled: false),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ErrorText extends StatelessWidget {
  const _ErrorText(this.message);
  final String message;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 8),
    child: Text(message, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppTheme.accentRed)),
  );
}

class _OtpBox extends StatelessWidget {
  const _OtpBox({required this.controller, required this.onChanged});
  final TextEditingController controller;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) => SizedBox(
    height: 48,
    child: TextField(
      controller: controller,
      textAlign: TextAlign.center,
      maxLength: 1,
      keyboardType: TextInputType.number,
      inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(1)],
      onChanged: (_) => onChanged(),
      decoration: InputDecoration(
        counterText: '',
        filled: true,
        fillColor: AppTheme.surfaceLowest,
        contentPadding: EdgeInsets.zero,
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppTheme.outlineVariant)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppTheme.primary, width: 2)),
      ),
    ),
  );
}
