import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/providers.dart';
import '../../../../shared/theme/app_theme.dart';
import '../../domain/entities/register_draft.dart';
import '../widgets/auth_scaffold.dart';

enum _RegistrationChannel { phone, email }

class RegisterParentPage extends ConsumerStatefulWidget {
  const RegisterParentPage({super.key});

  @override
  ConsumerState<RegisterParentPage> createState() => _RegisterParentPageState();
}

class _RegisterParentPageState extends ConsumerState<RegisterParentPage> {
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _acceptTerms = false;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  bool _submitted = false;
  _RegistrationChannel _channel = _RegistrationChannel.phone;
  final Set<String> _touchedFields = {};

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  bool get _hasMinLength => _passwordController.text.length >= 8;
  bool get _hasLetterAndNumber =>
      RegExp(r'[A-Za-zÀ-ỹ]').hasMatch(_passwordController.text) &&
      RegExp(r'\d').hasMatch(_passwordController.text);
  bool get _hasSpecialChar => RegExp(
    r'[!@#$%^&*(),.?":{}|<>_\-+=/\\[\];`~]',
  ).hasMatch(_passwordController.text);
  bool get _isPasswordStrong =>
      _hasMinLength && _hasLetterAndNumber && _hasSpecialChar;

  String? _nameError() {
    final value = _nameController.text.trim();
    if (value.isEmpty) {
      return 'Vui lòng nhập họ và tên phụ huynh.';
    }
    if (value.length < 3) {
      return 'Họ và tên cần có ít nhất 3 ký tự.';
    }
    return null;
  }

  String? _phoneError() {
    final value = _phoneController.text.trim().replaceAll(
      RegExp(r'[\s.-]'),
      '',
    );
    if (value.isEmpty) {
      return 'Vui lòng nhập số điện thoại.';
    }
    if (!RegExp(r'^(0|\+84)[0-9]{9,10}$').hasMatch(value)) {
      return 'Số điện thoại chưa đúng định dạng.';
    }
    return null;
  }

  String? _emailError() {
    final value = _emailController.text.trim();
    if (value.isEmpty) {
      return 'Vui lòng nhập email.';
    }
    if (!RegExp(
      r'^[^\s@]+@[^\s@]+\.[^\s@]+$',
      caseSensitive: false,
    ).hasMatch(value)) {
      return 'Email chưa đúng định dạng.';
    }
    return null;
  }

  String? _passwordError() {
    if (_passwordController.text.isEmpty) {
      return 'Vui lòng nhập mật khẩu.';
    }
    if (!_isPasswordStrong) {
      return 'Mật khẩu chưa đáp ứng đủ yêu cầu.';
    }
    return null;
  }

  String? _confirmPasswordError() {
    if (_confirmPasswordController.text.isEmpty) {
      return 'Vui lòng xác nhận mật khẩu.';
    }
    if (_confirmPasswordController.text != _passwordController.text) {
      return 'Mật khẩu xác nhận chưa khớp.';
    }
    return null;
  }

  String? _visibleError(String field, String? Function() validator) {
    if (!_submitted && !_touchedFields.contains(field)) {
      return null;
    }
    return validator();
  }

  bool get _isFormValid =>
      _nameError() == null &&
      (_channel == _RegistrationChannel.phone
          ? _phoneError() == null
          : _emailError() == null) &&
      _passwordError() == null &&
      _confirmPasswordError() == null &&
      _acceptTerms;

  void _touch(String field) {
    ref.read(authViewModelProvider.notifier).clearError();
    setState(() => _touchedFields.add(field));
  }

  Future<void> _submit() async {
    setState(() => _submitted = true);
    ref.read(authViewModelProvider.notifier).clearError();
    if (!_isFormValid) {
      return;
    }

    final identifier = _channel == _RegistrationChannel.phone
        ? _phoneController.text.trim()
        : _emailController.text.trim();
    final draft = RegisterDraft(
      identifier: identifier,
      fullName: _nameController.text.trim(),
      password: _passwordController.text,
      termsAccepted: _acceptTerms,
    );

    final success = await ref
        .read(authViewModelProvider.notifier)
        .sendRegisterOtp(identifier: draft.identifier);

    if (mounted && success) {
      context.go('/verify-otp', extra: draft);
    }
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final authState = ref.watch(authViewModelProvider);

    return Scaffold(
      backgroundColor: AppTheme.surfaceLight,
      body: Column(
        children: [
          const AuthHeader(
            subtitle: 'Tạo tài khoản phụ huynh để theo dõi hành trình của con',
          ),
          const AuthStepper(currentStep: 1),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 24, 16, 24),
              child: AuthViewport(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    AuthField(
                      label: 'Họ và tên phụ huynh',
                      controller: _nameController,
                      placeholder: 'Nguyễn Minh Anh',
                      icon: Icons.person,
                      isRequired: true,
                      textInputAction: TextInputAction.next,
                      errorText: _visibleError('name', _nameError),
                      onChanged: (_) => _touch('name'),
                    ),
                    const SizedBox(height: 16),
                    SegmentedButton<_RegistrationChannel>(
                      segments: const [
                        ButtonSegment(
                          value: _RegistrationChannel.phone,
                          icon: Icon(Icons.sms_outlined),
                          label: Text('Số điện thoại'),
                        ),
                        ButtonSegment(
                          value: _RegistrationChannel.email,
                          icon: Icon(Icons.email_outlined),
                          label: Text('Email'),
                        ),
                      ],
                      selected: {_channel},
                      onSelectionChanged: (selection) {
                        setState(() {
                          _channel = selection.first;
                          _submitted = false;
                        });
                        ref.read(authViewModelProvider.notifier).clearError();
                      },
                    ),
                    const SizedBox(height: 16),
                    if (_channel == _RegistrationChannel.phone)
                      AuthField(
                        label: 'Số điện thoại nhận OTP',
                        controller: _phoneController,
                        placeholder: '090 123 4567',
                        icon: Icons.phone,
                        isRequired: true,
                        keyboardType: TextInputType.phone,
                        textInputAction: TextInputAction.next,
                        inputFormatters: [
                          FilteringTextInputFormatter.allow(
                            RegExp(r'[0-9+\s]'),
                          ),
                        ],
                        errorText: _visibleError('phone', _phoneError),
                        onChanged: (_) => _touch('phone'),
                      )
                    else
                      AuthField(
                        label: 'Email nhận OTP',
                        controller: _emailController,
                        placeholder: 'phuhuynh@email.com',
                        icon: Icons.email,
                        isRequired: true,
                        keyboardType: TextInputType.emailAddress,
                        textInputAction: TextInputAction.next,
                        errorText: _visibleError('email', _emailError),
                        onChanged: (_) => _touch('email'),
                      ),
                    const SizedBox(height: 16),
                    AuthField(
                      label: 'Mật khẩu',
                      controller: _passwordController,
                      placeholder: '••••••••',
                      icon: Icons.lock,
                      isRequired: true,
                      obscureText: _obscurePassword,
                      textInputAction: TextInputAction.next,
                      errorText: _visibleError('password', _passwordError),
                      onChanged: (_) {
                        _touch('password');
                        if (_confirmPasswordController.text.isNotEmpty) {
                          _touchedFields.add('confirmPassword');
                        }
                      },
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
                    const SizedBox(height: 16),
                    AuthField(
                      label: 'Xác nhận mật khẩu',
                      controller: _confirmPasswordController,
                      placeholder: '••••••••',
                      icon: Icons.lock,
                      isRequired: true,
                      obscureText: _obscureConfirmPassword,
                      textInputAction: TextInputAction.done,
                      errorText: _visibleError(
                        'confirmPassword',
                        _confirmPasswordError,
                      ),
                      onChanged: (_) => _touch('confirmPassword'),
                      suffix: IconButton(
                        tooltip: _obscureConfirmPassword
                            ? 'Hiện mật khẩu'
                            : 'Ẩn mật khẩu',
                        onPressed: () {
                          setState(
                            () => _obscureConfirmPassword =
                                !_obscureConfirmPassword,
                          );
                        },
                        icon: Icon(
                          _obscureConfirmPassword
                              ? Icons.visibility_off
                              : Icons.visibility,
                          color: AppTheme.neutral700,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Wrap(
                      spacing: 16,
                      runSpacing: 8,
                      children: [
                        RequirementChip(
                          label: 'Tối thiểu 8 ký tự',
                          isMet: _hasMinLength,
                        ),
                        RequirementChip(
                          label: 'Có chữ và số',
                          isMet: _hasLetterAndNumber,
                        ),
                        RequirementChip(
                          label: 'Có ký tự đặc biệt',
                          isMet: _hasSpecialChar,
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Checkbox(
                          value: _acceptTerms,
                          side: const BorderSide(
                            color: AppTheme.outlineVariant,
                          ),
                          activeColor: AppTheme.secondary,
                          onChanged: (value) {
                            setState(() => _acceptTerms = value ?? false);
                          },
                        ),
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.only(top: 10),
                            child: RichText(
                              text: TextSpan(
                                style: textTheme.bodySmall?.copyWith(
                                  color: AppTheme.onSurfaceVariant,
                                ),
                                children: const [
                                  TextSpan(text: 'Tôi đồng ý với '),
                                  TextSpan(
                                    text: 'Điều khoản sử dụng',
                                    style: TextStyle(
                                      color: AppTheme.secondary,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  TextSpan(text: ' và '),
                                  TextSpan(
                                    text: 'Chính sách quyền riêng tư',
                                    style: TextStyle(
                                      color: AppTheme.secondary,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  TextSpan(text: '.'),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (_submitted && !_acceptTerms) ...[
                      const SizedBox(height: 4),
                      Text(
                        'Vui lòng đồng ý điều khoản trước khi tạo tài khoản.',
                        style: textTheme.bodySmall?.copyWith(
                          color: AppTheme.accentRed,
                        ),
                      ),
                    ],
                    const SizedBox(height: 24),
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
                      label: 'Tạo tài khoản',
                      onPressed: _submit,
                      isLoading: authState.isSendingRegisterOtp,
                    ),
                    const SizedBox(height: 16),
                    Center(
                      child: TextButton(
                        onPressed: () => context.go('/login'),
                        child: const Text('Đã có tài khoản? Đăng nhập'),
                      ),
                    ),
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
