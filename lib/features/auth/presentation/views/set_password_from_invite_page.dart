import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/providers.dart';
import '../../../../core/error/app_failure.dart';
import '../../../../core/network/api_exception.dart';
import '../../../../shared/theme/app_theme.dart';
import '../../domain/mobile_roles.dart';
import '../widgets/auth_scaffold.dart';

/// Step 2 of invitation activation: choose password and enter full session.
class SetPasswordFromInvitePage extends ConsumerStatefulWidget {
  const SetPasswordFromInvitePage({
    required this.challengeToken,
    required this.phoneNumberMasked,
    this.fullName,
    super.key,
  });

  final String challengeToken;
  final String phoneNumberMasked;
  final String? fullName;

  @override
  ConsumerState<SetPasswordFromInvitePage> createState() =>
      _SetPasswordFromInvitePageState();
}

class _SetPasswordFromInvitePageState
    extends ConsumerState<SetPasswordFromInvitePage> {
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();
  bool _obscurePassword = true;
  bool _obscureConfirm = true;
  bool _submitting = false;
  bool _submitted = false;
  String? _serverError;

  @override
  void dispose() {
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  String? _passwordError() {
    final value = _passwordController.text;
    if (value.isEmpty) return 'Vui lòng nhập mật khẩu mới.';
    if (value.length < 8) return 'Mật khẩu cần ít nhất 8 ký tự.';
    if (!RegExp(r'[A-Za-zÀ-ỹ]').hasMatch(value)) {
      return 'Mật khẩu cần có chữ cái.';
    }
    if (!RegExp(r'\d').hasMatch(value)) return 'Mật khẩu cần có chữ số.';
    if (!RegExp(r'''[!@#$%^&*(),.?":{}|<>_\-+=/\\[\];`~]''').hasMatch(value)) {
      return 'Mật khẩu cần có ký tự đặc biệt.';
    }
    return null;
  }

  String? _confirmError() {
    if (_confirmController.text.isEmpty) {
      return 'Vui lòng nhập lại mật khẩu.';
    }
    if (_confirmController.text != _passwordController.text) {
      return 'Mật khẩu xác nhận không khớp.';
    }
    return null;
  }

  Future<void> _submit() async {
    setState(() {
      _submitted = true;
      _serverError = null;
    });
    if (_passwordError() != null || _confirmError() != null) return;

    setState(() => _submitting = true);
    try {
      await ref
          .read(authRepositoryProvider)
          .setInvitationPassword(
            challengeToken: widget.challengeToken,
            newPassword: _passwordController.text,
            confirmPassword: _confirmController.text,
          );
      if (!mounted) return;
      final role = await ref.read(authRepositoryProvider).getUserRole();
      if (!mounted) return;
      if (!mounted) return;
      if (!isMobileAllowedRole(role)) {
        final message = await ref
            .read(authViewModelProvider.notifier)
            .rejectIfMobileRoleBlocked();
        if (!mounted) return;
        setState(() {
          _submitting = false;
          _serverError = message ?? mobileRoleBlockedMessage(role);
        });
        return;
      }
      context.go(homePathForMobileRole(role));
    } on Object catch (error) {
      if (!mounted) return;
      final api = ApiException.maybeFrom(error);
      setState(() {
        _submitting = false;
        _serverError = error is AppFailure
            ? error.message
            : (api?.message ?? 'Không thể đặt mật khẩu. Vui lòng thử lại.');
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final passwordError = _submitted ? _passwordError() : null;
    final confirmError = _submitted ? _confirmError() : null;
    final greeting =
        (widget.fullName != null && widget.fullName!.trim().isNotEmpty)
        ? 'Xin chào ${widget.fullName}'
        : 'Tạo mật khẩu đăng nhập';
    final maskedPhone = widget.phoneNumberMasked.isEmpty
        ? '****'
        : widget.phoneNumberMasked;

    return AuthMediaScaffold(
      child: AuthViewport(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              AuthBrandHero(subtitle: greeting),
              const SizedBox(height: 24),
              AuthVerificationCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'Số điện thoại',
                      style: textTheme.labelSmall?.copyWith(
                        color: AppTheme.onSurfaceVariant,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Container(
                      height: 50,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      decoration: BoxDecoration(
                        color: AppTheme.neutral100,
                        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                        border: Border.all(color: AppTheme.neutral200),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.phone_outlined,
                            size: 20,
                            color: AppTheme.neutral700,
                          ),
                          const SizedBox(width: 12),
                          Text(
                            maskedPhone,
                            style: textTheme.bodyMedium?.copyWith(
                              color: AppTheme.neutral950,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    AuthField(
                      label: 'Mật khẩu mới',
                      controller: _passwordController,
                      placeholder: 'Nhập mật khẩu mới',
                      icon: Icons.lock_outline,
                      obscureText: _obscurePassword,
                      textInputAction: TextInputAction.next,
                      errorText: passwordError,
                      onChanged: (_) {
                        if (_submitted) setState(() {});
                      },
                      suffix: IconButton(
                        tooltip: _obscurePassword
                            ? 'Hiện mật khẩu'
                            : 'Ẩn mật khẩu',
                        onPressed: _submitting
                            ? null
                            : () => setState(
                                () => _obscurePassword = !_obscurePassword,
                              ),
                        icon: Icon(
                          _obscurePassword
                              ? Icons.visibility_off_outlined
                              : Icons.visibility_outlined,
                          color: AppTheme.neutral700,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    AuthField(
                      label: 'Xác nhận mật khẩu',
                      controller: _confirmController,
                      placeholder: 'Nhập lại mật khẩu',
                      icon: Icons.lock_outline,
                      obscureText: _obscureConfirm,
                      textInputAction: TextInputAction.done,
                      errorText: confirmError,
                      onChanged: (_) {
                        if (_submitted) setState(() {});
                      },
                      suffix: IconButton(
                        tooltip: _obscureConfirm
                            ? 'Hiện mật khẩu'
                            : 'Ẩn mật khẩu',
                        onPressed: _submitting
                            ? null
                            : () => setState(
                                () => _obscureConfirm = !_obscureConfirm,
                              ),
                        icon: Icon(
                          _obscureConfirm
                              ? Icons.visibility_off_outlined
                              : Icons.visibility_outlined,
                          color: AppTheme.neutral700,
                        ),
                      ),
                    ),
                    if (_serverError != null) ...[
                      const SizedBox(height: 12),
                      Text(
                        _serverError!,
                        style: textTheme.bodyMedium?.copyWith(
                          color: AppTheme.accentRed,
                        ),
                      ),
                    ],
                    const SizedBox(height: 20),
                    AuthActionButton(
                      label: 'Kích hoạt tài khoản',
                      onPressed: _submitting ? null : _submit,
                      isLoading: _submitting,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
