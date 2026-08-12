import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/providers.dart';
import '../../../../core/network/api_exception.dart';
import '../../../../shared/theme/app_theme.dart';
import '../../../../shared/widgets/app_back_leading.dart';
import '../../../../shared/widgets/app_button.dart';
import '../../domain/vehicle_inspection_checklist.dart';

/// Teacher confirmation of vehicle safety checklist, signed with OTP.
class VehicleInspectionConfirmPage extends ConsumerStatefulWidget {
  const VehicleInspectionConfirmPage({
    super.key,
    required this.tourId,
    required this.planItemId,
    this.operationVehicleId,
    this.vehicleLabel,
    this.itemTitle,
  });

  final String tourId;
  final String planItemId;
  final String? operationVehicleId;
  final String? vehicleLabel;
  final String? itemTitle;

  @override
  ConsumerState<VehicleInspectionConfirmPage> createState() =>
      _VehicleInspectionConfirmPageState();
}

class _VehicleInspectionConfirmPageState
    extends ConsumerState<VehicleInspectionConfirmPage> {
  static const _otpLength = 6;

  final Map<String, bool> _checks = {
    for (final item in kVehicleInspectionChecklist) item.key: false,
  };
  final _otpControllers = List.generate(
    _otpLength,
    (_) => TextEditingController(),
  );
  final _focusNodes = List.generate(_otpLength, (_) => FocusNode());

  Timer? _timer;
  int _secondsLeft = 0;
  bool _sendingOtp = false;
  bool _submitting = false;
  bool _otpSent = false;
  bool _submitted = false;
  String? _maskedDestination;
  String _deliveryChannel = 'EMAIL';
  String? _error;

  @override
  void dispose() {
    _timer?.cancel();
    for (final c in _otpControllers) {
      c.dispose();
    }
    for (final n in _focusNodes) {
      n.dispose();
    }
    super.dispose();
  }

  bool get _allChecked => _checks.values.every((v) => v);
  int get _checkedCount => _checks.values.where((v) => v).length;
  String get _otp => _otpControllers.map((c) => c.text).join();
  bool get _isOtpComplete => RegExp(r'^\d{6}$').hasMatch(_otp);
  String get _timerText => '00:${_secondsLeft.toString().padLeft(2, '0')}';
  bool get _canSubmit => _allChecked && _otpSent && _isOtpComplete && !_submitting;

  void _toggleCheck(String key, bool? value) {
    setState(() {
      _checks[key] = value ?? false;
      _error = null;
    });
  }

  void _startCooldown([int seconds = 59]) {
    _timer?.cancel();
    setState(() => _secondsLeft = seconds);
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_secondsLeft <= 0) {
        timer.cancel();
        return;
      }
      setState(() => _secondsLeft--);
    });
  }

  void _onOtpChanged(int index, String value) {
    setState(() {
      _submitted = false;
      _error = null;
    });
    if (value.length > 1) {
      final digits = value.replaceAll(RegExp(r'\D'), '');
      for (var i = 0; i < _otpLength; i++) {
        _otpControllers[i].text = i < digits.length ? digits[i] : '';
      }
      final focusIndex = digits.length.clamp(0, _otpLength - 1);
      _focusNodes[focusIndex].requestFocus();
      setState(() {});
      return;
    }
    if (value.isNotEmpty && index < _otpLength - 1) {
      _focusNodes[index + 1].requestFocus();
    }
    if (value.isEmpty && index > 0) {
      _focusNodes[index - 1].requestFocus();
    }
  }

  Future<void> _sendOtp() async {
    if (!_allChecked) {
      setState(() {
        _error = 'Vui lòng xác nhận đủ các mục an toàn trước khi gửi OTP.';
      });
      return;
    }
    setState(() {
      _sendingOtp = true;
      _error = null;
    });
    try {
      final result = await ref
          .read(offlineAttendanceRepositoryProvider)
          .sendVehicleInspectionOtp(
            tourId: widget.tourId,
            planItemId: widget.planItemId,
            operationVehicleId: widget.operationVehicleId,
          );
      if (!mounted) return;
      setState(() {
        _otpSent = true;
        _maskedDestination = result.maskedDestination;
        _deliveryChannel = result.deliveryChannel;
        _sendingOtp = false;
      });
      _startCooldown(result.cooldownSeconds > 0 ? result.cooldownSeconds : 59);
      for (final c in _otpControllers) {
        c.clear();
      }
      _focusNodes.first.requestFocus();
    } on Object catch (error) {
      if (!mounted) return;
      final api = ApiException.maybeFrom(error);
      setState(() {
        _sendingOtp = false;
        _error =
            api?.message ??
            error.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  Future<void> _confirm() async {
    setState(() {
      _submitted = true;
      _error = null;
    });
    if (!_allChecked) {
      setState(() {
        _error = 'Cần đánh dấu đủ checklist an toàn xe.';
      });
      return;
    }
    if (!_otpSent) {
      setState(() {
        _error = 'Vui lòng gửi mã OTP để ký xác nhận.';
      });
      return;
    }
    if (!_isOtpComplete) {
      setState(() {
        _error = 'Vui lòng nhập đủ 6 chữ số OTP.';
      });
      return;
    }

    setState(() => _submitting = true);
    try {
      await ref.read(offlineAttendanceRepositoryProvider).confirmVehicleInspection(
            tourId: widget.tourId,
            planItemId: widget.planItemId,
            operationVehicleId: widget.operationVehicleId,
            otpCode: _otp,
            checks: Map<String, bool>.from(_checks),
          );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Đã xác nhận kiểm tra xe thành công.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      context.pop(true);
    } on Object catch (error) {
      if (!mounted) return;
      final api = ApiException.maybeFrom(error);
      setState(() {
        _submitting = false;
        _error =
            api?.message ??
            error.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final title = (widget.itemTitle ?? '').trim().isEmpty
        ? 'Kiểm tra tình trạng xe'
        : widget.itemTitle!.trim();
    final vehicle = (widget.vehicleLabel ?? '').trim();
    final progress = _checkedCount / kVehicleInspectionChecklist.length;

    return Scaffold(
      backgroundColor: AppTheme.surfaceLight,
      appBar: AppBar(
        backgroundColor: AppTheme.surface,
        foregroundColor: AppTheme.ink,
        elevation: 0,
        scrolledUnderElevation: 0.5,
        leading: buildAppBackLeading(context),
        title: const Text(
          'Xác nhận kiểm tra xe',
          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 17),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(
                AppTheme.spaceMd,
                AppTheme.spaceMd,
                AppTheme.spaceMd,
                AppTheme.spaceLg,
              ),
              children: [
                _HeroHeader(
                  title: title,
                  vehicleLabel: vehicle.isEmpty ? null : vehicle,
                  progress: progress,
                  checkedCount: _checkedCount,
                  total: kVehicleInspectionChecklist.length,
                ),
                const SizedBox(height: AppTheme.spaceLg),
                Text(
                  'Checklist an toàn',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: AppTheme.ink,
                        fontWeight: FontWeight.w700,
                      ),
                ),
                const SizedBox(height: AppTheme.spaceXs),
                Text(
                  'Giáo viên xác nhận từng hạng mục trước khi ký bằng OTP.',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppTheme.onSurfaceVariant,
                        height: 1.4,
                      ),
                ),
                const SizedBox(height: AppTheme.spaceMd),
                for (final item in kVehicleInspectionChecklist) ...[
                  _ChecklistTile(
                    item: item,
                    checked: _checks[item.key] ?? false,
                    onChanged: (value) => _toggleCheck(item.key, value),
                  ),
                  const SizedBox(height: AppTheme.spaceSm),
                ],
                const SizedBox(height: AppTheme.spaceMd),
                _OtpSignatureSection(
                  unlocked: _allChecked,
                  otpSent: _otpSent,
                  sendingOtp: _sendingOtp,
                  secondsLeft: _secondsLeft,
                  timerText: _timerText,
                  maskedDestination: _maskedDestination,
                  deliveryChannel: _deliveryChannel,
                  otpControllers: _otpControllers,
                  focusNodes: _focusNodes,
                  submitted: _submitted,
                  isOtpComplete: _isOtpComplete,
                  onSendOtp: _sendOtp,
                  onOtpChanged: _onOtpChanged,
                ),
                if (_error != null) ...[
                  const SizedBox(height: AppTheme.spaceMd),
                  Semantics(
                    liveRegion: true,
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(AppTheme.spaceMd),
                      decoration: BoxDecoration(
                        color: AppTheme.errorContainer,
                        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                        border: Border.all(
                          color: AppTheme.accentRed.withValues(alpha: 0.35),
                        ),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(
                            Icons.error_outline,
                            color: AppTheme.accentRed,
                            size: 20,
                          ),
                          const SizedBox(width: AppTheme.spaceSm),
                          Expanded(
                            child: Text(
                              _error!,
                              style: const TextStyle(
                                color: AppTheme.accentRed,
                                fontWeight: FontWeight.w600,
                                height: 1.35,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          _BottomConfirmBar(
            enabled: _canSubmit,
            isLoading: _submitting,
            allChecked: _allChecked,
            otpReady: _otpSent && _isOtpComplete,
            onConfirm: _confirm,
          ),
        ],
      ),
    );
  }
}

class _HeroHeader extends StatelessWidget {
  const _HeroHeader({
    required this.title,
    required this.progress,
    required this.checkedCount,
    required this.total,
    this.vehicleLabel,
  });

  final String title;
  final String? vehicleLabel;
  final double progress;
  final int checkedCount;
  final int total;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppTheme.spaceLg),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFEFF6FF), Color(0xFFFFF7ED)],
        ),
        borderRadius: BorderRadius.circular(AppTheme.radiusXl),
        border: Border.all(color: AppTheme.primarySoft),
        boxShadow: AppTheme.shadowSm,
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
                  color: AppTheme.surface,
                  borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                  border: Border.all(color: AppTheme.primarySoft),
                ),
                child: const Icon(
                  Icons.directions_bus_filled_outlined,
                  color: AppTheme.primary,
                ),
              ),
              const SizedBox(width: AppTheme.spaceMd),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                            color: AppTheme.ink,
                          ),
                    ),
                    if (vehicleLabel != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        'Xe: $vehicleLabel',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: AppTheme.onSurfaceVariant,
                              fontWeight: FontWeight.w600,
                            ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppTheme.spaceMd),
          ClipRRect(
            borderRadius: BorderRadius.circular(AppTheme.radiusPill),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 8,
              backgroundColor: AppTheme.neutral200,
              color: progress >= 1 ? AppTheme.accentGreen : AppTheme.primary,
            ),
          ),
          const SizedBox(height: AppTheme.spaceSm),
          Text(
            '$checkedCount/$total hạng mục đã xác nhận',
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: AppTheme.onSurfaceVariant,
                  fontWeight: FontWeight.w700,
                ),
          ),
        ],
      ),
    );
  }
}

class _ChecklistTile extends StatelessWidget {
  const _ChecklistTile({
    required this.item,
    required this.checked,
    required this.onChanged,
  });

  final VehicleInspectionCheckItem item;
  final bool checked;
  final ValueChanged<bool?> onChanged;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: AppTheme.motionNormal,
      curve: Curves.easeOut,
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        border: Border.all(
          color: checked
              ? AppTheme.accentGreen.withValues(alpha: 0.45)
              : AppTheme.neutral200,
          width: checked ? 1.5 : 1,
        ),
        boxShadow: checked ? AppTheme.shadowSm : null,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(AppTheme.radiusLg),
          onTap: () => onChanged(!checked),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppTheme.spaceSm,
              vertical: AppTheme.spaceSm,
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AnimatedContainer(
                  duration: AppTheme.motionFast,
                  width: 44,
                  height: 44,
                  margin: const EdgeInsets.only(
                    left: AppTheme.spaceXs,
                    top: AppTheme.spaceXs,
                  ),
                  decoration: BoxDecoration(
                    color: checked
                        ? AppTheme.accentGreen.withValues(alpha: 0.12)
                        : AppTheme.primarySoft,
                    borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                  ),
                  child: Icon(
                    item.icon,
                    color: checked ? AppTheme.accentGreen : AppTheme.primary,
                    size: 22,
                  ),
                ),
                Expanded(
                  child: CheckboxListTile(
                    value: checked,
                    onChanged: onChanged,
                    contentPadding: const EdgeInsets.only(
                      left: AppTheme.spaceSm,
                      right: AppTheme.spaceXs,
                    ),
                    controlAffinity: ListTileControlAffinity.trailing,
                    activeColor: AppTheme.accentGreen,
                    title: Text(
                      item.title,
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: AppTheme.ink,
                        decoration:
                            checked ? TextDecoration.lineThrough : null,
                        decorationColor:
                            AppTheme.onSurfaceVariant.withValues(alpha: 0.5),
                      ),
                    ),
                    subtitle: Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        item.subtitle,
                        style: const TextStyle(
                          color: AppTheme.onSurfaceVariant,
                          height: 1.35,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _OtpSignatureSection extends StatelessWidget {
  const _OtpSignatureSection({
    required this.unlocked,
    required this.otpSent,
    required this.sendingOtp,
    required this.secondsLeft,
    required this.timerText,
    required this.otpControllers,
    required this.focusNodes,
    required this.submitted,
    required this.isOtpComplete,
    required this.onSendOtp,
    required this.onOtpChanged,
    required this.deliveryChannel,
    this.maskedDestination,
  });

  final bool unlocked;
  final bool otpSent;
  final bool sendingOtp;
  final int secondsLeft;
  final String timerText;
  final String? maskedDestination;
  final String deliveryChannel;
  final List<TextEditingController> otpControllers;
  final List<FocusNode> focusNodes;
  final bool submitted;
  final bool isOtpComplete;
  final VoidCallback onSendOtp;
  final void Function(int index, String value) onOtpChanged;

  bool get _viaEmail => deliveryChannel.toUpperCase() == 'EMAIL';

  @override
  Widget build(BuildContext context) {
    return AnimatedOpacity(
      duration: AppTheme.motionNormal,
      opacity: unlocked ? 1 : 0.55,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(AppTheme.spaceLg),
        decoration: BoxDecoration(
          color: AppTheme.surface,
          borderRadius: BorderRadius.circular(AppTheme.radiusXl),
          border: Border.all(
            color: unlocked
                ? AppTheme.cta.withValues(alpha: 0.35)
                : AppTheme.neutral200,
          ),
          boxShadow: AppTheme.shadowSm,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF7ED),
                    borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                  ),
                  child: const Icon(
                    Icons.draw_outlined,
                    color: AppTheme.cta,
                    size: 22,
                  ),
                ),
                const SizedBox(width: AppTheme.spaceMd),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Chữ ký xác nhận bằng OTP',
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w700,
                              color: AppTheme.ink,
                            ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        unlocked
                            ? 'Mã OTP ưu tiên gửi email; nếu lỗi sẽ gửi SMS dự phòng.'
                            : 'Hoàn tất checklist để mở bước ký OTP.',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: AppTheme.onSurfaceVariant,
                              height: 1.35,
                            ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppTheme.spaceMd),
            AppButton(
              label: sendingOtp
                  ? 'Đang gửi…'
                  : otpSent
                      ? 'Gửi lại mã OTP'
                      : 'Gửi mã OTP xác nhận',
              onPressed: (!unlocked || sendingOtp || secondsLeft > 0)
                  ? null
                  : onSendOtp,
              isLoading: sendingOtp,
              variant: AppButtonVariant.tonal,
              icon: Icons.mark_email_read_outlined,
            ),
            if (secondsLeft > 0) ...[
              const SizedBox(height: AppTheme.spaceSm),
              Row(
                children: [
                  const Icon(
                    Icons.schedule,
                    size: 16,
                    color: AppTheme.cta,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'Gửi lại sau $timerText',
                    style: const TextStyle(
                      color: AppTheme.cta,
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ],
            if (otpSent && maskedDestination != null) ...[
              const SizedBox(height: AppTheme.spaceMd),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(AppTheme.spaceMd),
                decoration: BoxDecoration(
                  color: AppTheme.accentGreen.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                  border: Border.all(
                    color: AppTheme.accentGreen.withValues(alpha: 0.25),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      _viaEmail
                          ? Icons.mark_email_read_outlined
                          : Icons.sms_outlined,
                      color: AppTheme.accentGreen,
                      size: 18,
                    ),
                    const SizedBox(width: AppTheme.spaceSm),
                    Expanded(
                      child: Text(
                        _viaEmail
                            ? 'Đã gửi mã OTP qua email tới $maskedDestination'
                            : 'Đã gửi mã OTP qua SMS tới $maskedDestination',
                        style: const TextStyle(
                          color: AppTheme.ink,
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            if (otpSent) ...[
              const SizedBox(height: AppTheme.spaceLg),
              Text(
                'Nhập mã 6 số',
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      color: AppTheme.ink,
                    ),
              ),
              const SizedBox(height: AppTheme.spaceSm),
              Row(
                children: [
                  for (var i = 0; i < otpControllers.length; i++) ...[
                    Expanded(
                      child: _OtpBox(
                        controller: otpControllers[i],
                        focusNode: focusNodes[i],
                        hasError: submitted && !isOtpComplete,
                        onChanged: (value) => onOtpChanged(i, value),
                      ),
                    ),
                    if (i < otpControllers.length - 1)
                      const SizedBox(width: 8),
                  ],
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _OtpBox extends StatelessWidget {
  const _OtpBox({
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
      aspectRatio: 0.9,
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
        style: Theme.of(context).textTheme.titleLarge?.copyWith(
              color: AppTheme.ink,
              fontWeight: FontWeight.w700,
            ),
        decoration: InputDecoration(
          filled: true,
          fillColor: AppTheme.surfaceLow,
          contentPadding: EdgeInsets.zero,
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppTheme.radiusSm),
            borderSide: BorderSide(
              color: hasError ? AppTheme.accentRed : AppTheme.neutral200,
              width: 1.5,
            ),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppTheme.radiusSm),
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

class _BottomConfirmBar extends StatelessWidget {
  const _BottomConfirmBar({
    required this.enabled,
    required this.isLoading,
    required this.allChecked,
    required this.otpReady,
    required this.onConfirm,
  });

  final bool enabled;
  final bool isLoading;
  final bool allChecked;
  final bool otpReady;
  final VoidCallback onConfirm;

  @override
  Widget build(BuildContext context) {
    final hint = !allChecked
        ? 'Đánh dấu đủ checklist để tiếp tục'
        : !otpReady
            ? 'Nhập OTP để hoàn tất chữ ký xác nhận'
            : 'Sẵn sàng gửi xác nhận kiểm tra xe';

    return Material(
      elevation: 8,
      color: AppTheme.surface,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            AppTheme.spaceMd,
            AppTheme.spaceMd,
            AppTheme.spaceMd,
            AppTheme.spaceMd,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                hint,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppTheme.onSurfaceVariant,
                      fontWeight: FontWeight.w600,
                    ),
              ),
              const SizedBox(height: AppTheme.spaceSm),
              FilledButton.icon(
                onPressed: enabled ? onConfirm : null,
                style: FilledButton.styleFrom(
                  backgroundColor: AppTheme.cta,
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: AppTheme.neutral200,
                  minimumSize: const Size.fromHeight(52),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                  ),
                ),
                icon: isLoading
                    ? const SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.verified_user_outlined),
                label: Text(
                  isLoading ? 'Đang xác nhận…' : 'Xác nhận kiểm tra xe',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
