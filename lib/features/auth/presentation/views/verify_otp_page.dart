import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/providers.dart';
import '../../../../shared/theme/app_theme.dart';
import '../../domain/entities/register_draft.dart';
import '../widgets/auth_scaffold.dart';

class VerifyOtpPage extends ConsumerStatefulWidget {
  const VerifyOtpPage({super.key, this.draft, this.identifier});

  final RegisterDraft? draft;
  final String? identifier;

  @override
  ConsumerState<VerifyOtpPage> createState() => _VerifyOtpPageState();
}

class _VerifyOtpPageState extends ConsumerState<VerifyOtpPage> {
  static const _otpLength = 6;
  final _otpControllers = List.generate(
    _otpLength,
    (_) => TextEditingController(),
  );
  final _focusNodes = List.generate(_otpLength, (_) => FocusNode());
  Timer? _timer;
  int _secondsLeft = 59;
  bool _submitted = false;
  String? _validationError;

  @override
  void initState() {
    super.initState();
    _startTimer();
  }

  @override
  void dispose() {
    _timer?.cancel();
    for (final controller in _otpControllers) {
      controller.dispose();
    }
    for (final node in _focusNodes) {
      node.dispose();
    }
    super.dispose();
  }

  String get _otp =>
      _otpControllers.map((controller) => controller.text).join();
  bool get _isOtpComplete => RegExp(r'^\d{6}$').hasMatch(_otp);
  String get _timerText => '00:${_secondsLeft.toString().padLeft(2, '0')}';

  String get _identifierLabel {
    final value = widget.draft?.identifier.trim() ?? widget.identifier?.trim();
    if (value == null || value.isEmpty) {
      return 'email hoặc số điện thoại của bạn';
    }
    if (value.contains('@')) {
      final parts = value.split('@');
      final local = parts.first;
      final visible = local.length <= 2
          ? local.substring(0, 1)
          : local.substring(0, 2);
      return '$visible***@${parts.last}';
    }

    final digits = value.replaceAll(RegExp(r'\D'), '');
    if (digits.length < 6) {
      return value;
    }

    return '${digits.substring(0, 3)} *** ${digits.substring(digits.length - 4)}';
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_secondsLeft == 0) {
        timer.cancel();
        return;
      }
      setState(() => _secondsLeft--);
    });
  }

  Future<void> _resendCode() async {
    final identifier = widget.draft?.identifier ?? widget.identifier;
    if (identifier == null || identifier.trim().isEmpty) {
      setState(() {
        _validationError =
            'Thiếu email hoặc số điện thoại. Vui lòng đăng ký lại.';
      });
      return;
    }

    setState(() => _validationError = null);
    final viewModel = ref.read(authViewModelProvider.notifier);
    viewModel.clearError();
    final success = await viewModel.sendRegisterOtp(
      identifier: identifier.trim(),
    );

    if (mounted && success) {
      setState(() {
        _secondsLeft = 59;
        _submitted = false;
        for (final controller in _otpControllers) {
          controller.clear();
        }
      });
      _focusNodes.first.requestFocus();
      _startTimer();
    }
  }

  void _onOtpChanged(int index, String value) {
    setState(() {
      _submitted = false;
      _validationError = null;
    });
    ref.read(authViewModelProvider.notifier).clearError();
    if (value.isNotEmpty && index < _otpLength - 1) {
      _focusNodes[index + 1].requestFocus();
    }
    if (value.isEmpty && index > 0) {
      _focusNodes[index - 1].requestFocus();
    }
  }

  Future<void> _verify() async {
    setState(() {
      _submitted = true;
      _validationError = null;
    });
    final viewModel = ref.read(authViewModelProvider.notifier);
    viewModel.clearError();
    if (!_isOtpComplete) {
      return;
    }
    final draft = widget.draft;
    if (draft == null) {
      setState(() {
        _validationError = 'Thiếu thông tin đăng ký. Vui lòng đăng ký lại.';
      });
      return;
    }

    final success = await viewModel.register(draft, _otp);
    if (mounted && success) {
      await showDialog<void>(
        context: context,
        builder: (context) {
          return Dialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 80,
                    height: 80,
                    alignment: Alignment.center,
                    decoration: const BoxDecoration(
                      color: AppTheme.accentGreen,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.check_circle,
                      color: Colors.white,
                      size: 52,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Thành công!',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      color: AppTheme.onSurface,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Tài khoản của bạn đã được xác minh thành công.',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppTheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 20),
                  AuthActionButton(
                    label: 'Tiếp tục',
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),
          );
        },
      );

      if (mounted) {
        context.go('/login');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final authState = ref.watch(authViewModelProvider);
    final errorMessage = _validationError ?? authState.errorMessage;

    return Scaffold(
      backgroundColor: AppTheme.surfaceLight,
      body: Column(
        children: [
          AuthTopBar(
            title: 'Xác minh tài khoản',
            onBack: () => context.go('/register-parent'),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
              child: AuthViewport(
                child: Column(
                  children: [
                    const AuthOtpProgress(),
                    AuthVerificationCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const Center(child: VerificationIcon()),
                          const SizedBox(height: 16),
                          Text(
                            'Nhập mã xác minh',
                            textAlign: TextAlign.center,
                            style: textTheme.titleLarge?.copyWith(
                              color: AppTheme.onSurface,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 8),
                          RichText(
                            textAlign: TextAlign.center,
                            text: TextSpan(
                              style: textTheme.bodyMedium?.copyWith(
                                color: AppTheme.onSurfaceVariant,
                                height: 1.45,
                              ),
                              children: [
                                const TextSpan(
                                  text:
                                      'Nhập mã xác minh 6 chữ số đã được gửi đến ',
                                ),
                                TextSpan(
                                  text: _identifierLabel,
                                  style: const TextStyle(
                                    color: AppTheme.onSurface,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 32),
                          Row(
                            children: [
                              for (
                                var index = 0;
                                index < _otpLength;
                                index++
                              ) ...[
                                Expanded(
                                  child: _OtpInput(
                                    controller: _otpControllers[index],
                                    focusNode: _focusNodes[index],
                                    hasError: _submitted && !_isOtpComplete,
                                    onChanged: (value) =>
                                        _onOtpChanged(index, value),
                                  ),
                                ),
                                if (index < _otpLength - 1)
                                  const SizedBox(width: 8),
                              ],
                            ],
                          ),
                          if (_submitted && !_isOtpComplete) ...[
                            const SizedBox(height: 8),
                            Text(
                              'Vui lòng nhập đủ 6 chữ số xác minh.',
                              textAlign: TextAlign.center,
                              style: textTheme.bodySmall?.copyWith(
                                color: AppTheme.accentRed,
                              ),
                            ),
                          ],
                          if (errorMessage != null) ...[
                            const SizedBox(height: 8),
                            Text(
                              errorMessage,
                              textAlign: TextAlign.center,
                              style: textTheme.bodySmall?.copyWith(
                                color: AppTheme.accentRed,
                              ),
                            ),
                          ],
                          const SizedBox(height: 24),
                          Center(
                            child: _secondsLeft > 0
                                ? Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(
                                        Icons.schedule,
                                        size: 16,
                                        color: AppTheme.accentOrange,
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        'Gửi lại mã sau $_timerText',
                                        style: textTheme.bodySmall?.copyWith(
                                          color: AppTheme.accentOrange,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  )
                                : TextButton.icon(
                                    onPressed: authState.isSendingRegisterOtp
                                        ? null
                                        : _resendCode,
                                    icon: const Icon(Icons.refresh, size: 18),
                                    label: Text(
                                      authState.isSendingRegisterOtp
                                          ? 'Đang gửi lại...'
                                          : 'Gửi lại mã ngay',
                                    ),
                                  ),
                          ),
                          const SizedBox(height: 28),
                          AuthActionButton(
                            label: 'Xác minh mã',
                            onPressed: _verify,
                            isLoading: authState.isRegistering,
                            trailing: const Icon(Icons.arrow_forward, size: 18),
                          ),
                        ],
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

class _OtpInput extends StatelessWidget {
  const _OtpInput({
    required this.controller,
    required this.focusNode,
    required this.onChanged,
    required this.hasError,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final ValueChanged<String> onChanged;
  final bool hasError;

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 1,
      child: TextField(
        controller: controller,
        focusNode: focusNode,
        onChanged: onChanged,
        textAlign: TextAlign.center,
        keyboardType: TextInputType.number,
        inputFormatters: [
          FilteringTextInputFormatter.digitsOnly,
          LengthLimitingTextInputFormatter(1),
        ],
        style: Theme.of(context).textTheme.headlineSmall?.copyWith(
          color: AppTheme.onSurface,
          fontWeight: FontWeight.w700,
        ),
        decoration: InputDecoration(
          filled: true,
          fillColor: AppTheme.surface,
          contentPadding: EdgeInsets.zero,
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(
              color: hasError ? AppTheme.accentRed : AppTheme.outlineVariant,
              width: 2,
            ),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(
              color: hasError ? AppTheme.accentRed : AppTheme.primary,
              width: 2,
            ),
          ),
        ),
      ),
    );
  }
}
