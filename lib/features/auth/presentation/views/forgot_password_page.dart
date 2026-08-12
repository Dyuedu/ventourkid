import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../../../../shared/theme/app_theme.dart';
import '../widgets/auth_scaffold.dart';

class ForgotPasswordPage extends StatefulWidget {
  const ForgotPasswordPage({super.key});

  @override
  State<ForgotPasswordPage> createState() => _ForgotPasswordPageState();
}

class _ForgotPasswordPageState extends State<ForgotPasswordPage> {
  final _accountController = TextEditingController();
  final _otpControllers = List.generate(6, (_) => TextEditingController());
  bool _accountTouched = false;
  bool _otpSubmitted = false;

  @override
  void dispose() {
    _accountController.dispose();
    for (final controller in _otpControllers) {
      controller.dispose();
    }
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

  bool get _isOtpComplete {
    final otp = _otpControllers.map((controller) => controller.text).join();
    return RegExp(r'^\d{6}$').hasMatch(otp);
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      backgroundColor: AppTheme.surfaceLight,
      body: Column(
        children: [
          AuthTopBar(
            title: 'Khôi phục mật khẩu',
            onBack: () => context.go('/login'),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 24, 16, 24),
              child: AuthViewport(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    AuthField(
                      label: 'Email hoặc số điện thoại',
                      controller: _accountController,
                      placeholder: 'Nhập email hoặc SĐT',
                      icon: Icons.person,
                      keyboardType: TextInputType.emailAddress,
                      errorText: _accountTouched ? _accountError() : null,
                      onChanged: (_) {
                        setState(() => _accountTouched = true);
                      },
                    ),
                    const SizedBox(height: 24),
                    AuthActionButton(
                      label: 'Gửi mã xác minh',
                      onPressed: () {
                        setState(() => _accountTouched = true);
                      },
                    ),
                    const SizedBox(height: 16),
                    AuthActionButton(
                      label: 'Quay lại đăng nhập',
                      onPressed: () => context.go('/login'),
                      filled: false,
                    ),
                    Container(
                      margin: const EdgeInsets.only(top: 40),
                      padding: const EdgeInsets.only(top: 24),
                      decoration: const BoxDecoration(
                        border: Border(
                          top: BorderSide(color: AppTheme.surfaceVariant),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            'Nhập mã xác minh 6 chữ số',
                            style: textTheme.titleLarge?.copyWith(
                              color: AppTheme.navy,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Mã xác minh đã được gửi đến thiết bị của bạn.',
                            style: textTheme.bodySmall?.copyWith(
                              color: AppTheme.onSurfaceVariant,
                            ),
                          ),
                          const SizedBox(height: 24),
                          Row(
                            children: [
                              for (
                                var index = 0;
                                index < _otpControllers.length;
                                index++
                              ) ...[
                                Expanded(
                                  child: _OtpBox(
                                    controller: _otpControllers[index],
                                  ),
                                ),
                                if (index < _otpControllers.length - 1)
                                  const SizedBox(width: 8),
                              ],
                            ],
                          ),
                          if (_otpSubmitted && !_isOtpComplete) ...[
                            const SizedBox(height: 8),
                            Text(
                              'Vui lòng nhập đủ 6 chữ số xác minh.',
                              textAlign: TextAlign.center,
                              style: textTheme.bodySmall?.copyWith(
                                color: AppTheme.accentRed,
                              ),
                            ),
                          ],
                          const SizedBox(height: 16),
                          Center(
                            child: RichText(
                              text: TextSpan(
                                style: textTheme.bodySmall?.copyWith(
                                  color: AppTheme.onSurfaceVariant,
                                ),
                                children: const [
                                  TextSpan(text: 'Gửi lại mã sau '),
                                  TextSpan(
                                    text: '00:59',
                                    style: TextStyle(
                                      color: AppTheme.accentOrange,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 24),
                          AuthActionButton(
                            label: 'Xác minh mã',
                            onPressed: () {
                              setState(() => _otpSubmitted = true);
                            },
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 40),
                    Center(
                      child: TextButton.icon(
                        onPressed: () {},
                        icon: const Icon(Icons.support_agent, size: 18),
                        label: const Text('Cần trợ giúp? Liên hệ Hỗ trợ'),
                        style: TextButton.styleFrom(
                          foregroundColor: AppTheme.primary,
                        ),
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

class _OtpBox extends StatelessWidget {
  const _OtpBox({required this.controller});

  final TextEditingController controller;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 48,
      child: TextField(
        controller: controller,
        textAlign: TextAlign.center,
        maxLength: 1,
        keyboardType: TextInputType.number,
        inputFormatters: [
          FilteringTextInputFormatter.digitsOnly,
          LengthLimitingTextInputFormatter(1),
        ],
        style: Theme.of(context).textTheme.titleLarge?.copyWith(
          color: AppTheme.navy,
          fontWeight: FontWeight.w600,
        ),
        decoration: InputDecoration(
          counterText: '',
          filled: true,
          fillColor: AppTheme.surfaceLowest,
          contentPadding: EdgeInsets.zero,
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: AppTheme.outlineVariant),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: AppTheme.primary, width: 2),
          ),
        ),
      ),
    );
  }
}
