import 'package:flutter/material.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../app/providers.dart';
import '../../../../shared/theme/app_theme.dart';
import '../../../../shared/widgets/parent_ui.dart';
import '../../data/models/parent_link_api_models.dart';
import '../../domain/entities/parent_dashboard.dart';
import '../viewmodels/parent_link_view_state.dart';

class ParentLinkChildFlow extends ConsumerStatefulWidget {
  const ParentLinkChildFlow({
    super.key,
    this.linkedChild,
    required this.onLinked,
  });

  final ParentChildSummary? linkedChild;
  final VoidCallback onLinked;

  @override
  ConsumerState<ParentLinkChildFlow> createState() =>
      _ParentLinkChildFlowState();
}

class _ParentLinkChildFlowState extends ConsumerState<ParentLinkChildFlow> {
  final _formKey = GlobalKey<FormState>();
  final _identityController = TextEditingController();
  final _fullNameController = TextEditingController();
  final _otpController = TextEditingController();
  DateTime? _birthDate;
  bool _useIdentity = false;

  @override
  void initState() {
    super.initState();
    _identityController.addListener(() {
      final next = _identityController.text.trim().isNotEmpty;
      if (next != _useIdentity) {
        setState(() => _useIdentity = next);
      }
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(parentLinkViewModelProvider.notifier).initialize();
    });
  }

  @override
  void dispose() {
    _identityController.dispose();
    _fullNameController.dispose();
    _otpController.dispose();
    super.dispose();
  }

  String _formatDate(String? value) {
    if (value == null || value.isEmpty) return '-';
    final parsed = DateTime.tryParse(value);
    if (parsed == null) return value;
    return DateFormat('dd/MM/yyyy').format(parsed);
  }

  String _apiDate(DateTime date) => DateFormat('yyyy-MM-dd').format(date);

  Future<void> _pickBirthDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _birthDate ?? DateTime(now.year - 10),
      firstDate: DateTime(now.year - 25),
      lastDate: now,
      locale: const Locale('vi'),
    );
    if (picked != null) {
      setState(() => _birthDate = picked);
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(parentLinkViewModelProvider, (previous, next) {
      if (next.step == ParentLinkStep.otpVerify &&
          previous?.step != ParentLinkStep.otpVerify) {
        _otpController.clear();
      }
      if (next.otpCode != _otpController.text) {
        _otpController.value = TextEditingValue(
          text: next.otpCode,
          selection: TextSelection.collapsed(offset: next.otpCode.length),
        );
      }
    });

    final state = ref.watch(parentLinkViewModelProvider);
    final notifier = ref.read(parentLinkViewModelProvider.notifier);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (widget.linkedChild != null) ...[
          ParentBanner(
            icon: Iconsax.info_circle,
            tone: ParentBannerTone.info,
            text:
                'Đang có học sinh đã liên kết: ${widget.linkedChild!.name}. Bạn có thể liên kết thêm hoạt động trải nghiệm khác.',
          ),
          const SizedBox(height: 12),
        ],
        if (state.errorMessage != null) ...[
          ParentBanner(
            icon: Iconsax.warning_2,
            tone: ParentBannerTone.warning,
            text: state.errorMessage!,
          ),
          const SizedBox(height: 12),
        ],
        if (state.infoMessage != null) ...[
          ParentBanner(
            icon: Iconsax.info_circle,
            tone: ParentBannerTone.info,
            text: state.infoMessage!,
          ),
          const SizedBox(height: 12),
        ],
        switch (state.step) {
          ParentLinkStep.loading => const _LoadingPanel(
            message: 'Đang kiểm tra điều kiện liên kết...',
          ),
          ParentLinkStep.profileGate => _ProfileGatePanel(
            message: state.errorMessage ??
                state.prerequisites?.message ??
                'Vui lòng cập nhật hồ sơ trước khi liên kết học sinh.',
          ),
          ParentLinkStep.selectActivity => _ActivityListPanel(
            activities: state.activities,
            selectedActivity: state.selectedActivity,
            onSelect: notifier.selectActivity,
          ),
          ParentLinkStep.studentForm => _StudentFormPanel(
            formKey: _formKey,
            activity: state.selectedActivity!,
            identityController: _identityController,
            fullNameController: _fullNameController,
            birthDate: _birthDate,
            useIdentity: _useIdentity,
            isSubmitting: state.isSubmitting,
            onPickBirthDate: _pickBirthDate,
            onBack: state.activities.length > 1 ? notifier.backToActivities : null,
            onSubmit: () {
              if (!(_formKey.currentState?.validate() ?? false)) return;
              if (_identityController.text.trim().isEmpty && _birthDate == null) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Vui lòng chọn ngày sinh khi không dùng mã định danh.'),
                  ),
                );
                return;
              }
              notifier.sendOtp(
                identityNumber: _identityController.text,
                fullName: _fullNameController.text,
                dateOfBirth: _birthDate == null ? '' : _apiDate(_birthDate!),
              );
            },
          ),
          ParentLinkStep.otpVerify => _OtpVerifyPanel(
            activity: state.selectedActivity,
            otpCandidate: state.otpCandidate,
            otpController: _otpController,
            isSubmitting: state.isSubmitting,
            formatDate: _formatDate,
            onOtpChanged: notifier.updateOtpCode,
            onBack: notifier.backToStudentForm,
            onVerify: () async {
              final success = await notifier.verifyOtp();
              if (success && mounted) {
                widget.onLinked();
              }
            },
          ),
        },
      ],
    );
  }
}

class _LoadingPanel extends StatelessWidget {
  const _LoadingPanel({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return ParentCard(
      child: Row(
        children: [
          const SizedBox(
            width: 22,
            height: 22,
            child: CircularProgressIndicator(strokeWidth: 2.4),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              message,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ProfileGatePanel extends StatelessWidget {
  const _ProfileGatePanel({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ParentBanner(
          icon: Iconsax.warning_2,
          tone: ParentBannerTone.warning,
          text: message,
        ),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: () => Navigator.of(context).pop(),
          icon: const Icon(Iconsax.user),
          label: const Text('Cập nhật hồ sơ sau'),
        ),
      ],
    );
  }
}

class _ActivityListPanel extends StatelessWidget {
  const _ActivityListPanel({
    required this.activities,
    required this.selectedActivity,
    required this.onSelect,
  });

  final List<TripLinkActivityModel> activities;
  final TripLinkActivityModel? selectedActivity;
  final ValueChanged<TripLinkActivityModel> onSelect;

  @override
  Widget build(BuildContext context) {
    if (activities.isEmpty) {
      return const ParentEmptyState(
        icon: Iconsax.calendar_remove,
        title: 'Chưa có hoạt động chờ liên kết',
        description:
            'Chưa có hoạt động trải nghiệm nào chờ liên kết theo số điện thoại trong hồ sơ phụ huynh.',
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            const ParentIconWell(icon: Iconsax.global_search),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Chọn hoạt động trải nghiệm',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Các hoạt động dưới đây có roster chứa số điện thoại của tài khoản hiện tại.',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppTheme.onSurfaceVariant,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        for (final activity in activities) ...[
          _ActivityCard(
            activity: activity,
            selected: selectedActivity?.activityLinkKey == activity.activityLinkKey,
            onTap: () => onSelect(activity),
          ),
          const SizedBox(height: 10),
        ],
      ],
    );
  }
}

class _ActivityCard extends StatelessWidget {
  const _ActivityCard({
    required this.activity,
    required this.selected,
    required this.onTap,
  });

  final TripLinkActivityModel activity;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ParentCard(
      onTap: onTap,
      emphasized: selected,
      color: selected ? AppTheme.primarySoft.withValues(alpha: 0.45) : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  activity.displayTourName,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              const ParentStatusChip(
                label: 'Chờ liên kết',
                color: AppTheme.accentOrange,
                icon: Iconsax.clock,
              ),
            ],
          ),
          const SizedBox(height: 8),
          _MetaRow(
            icon: Iconsax.building,
            label: activity.schoolName ?? 'Trường',
          ),
          const SizedBox(height: 4),
          _MetaRow(
            icon: Iconsax.calendar_1,
            label: _formatDate(activity.tourDate),
          ),
          const SizedBox(height: 4),
          _MetaRow(
            icon: Iconsax.mobile,
            label: activity.parentPhoneMasked ?? 'SĐT trong roster',
          ),
        ],
      ),
    );
  }

  String _formatDate(String? value) {
    if (value == null || value.isEmpty) return '-';
    final parsed = DateTime.tryParse(value);
    if (parsed == null) return value;
    return DateFormat('dd/MM/yyyy').format(parsed);
  }
}

class _StudentFormPanel extends StatelessWidget {
  const _StudentFormPanel({
    required this.formKey,
    required this.activity,
    required this.identityController,
    required this.fullNameController,
    required this.birthDate,
    required this.useIdentity,
    required this.isSubmitting,
    required this.onPickBirthDate,
    required this.onSubmit,
    this.onBack,
  });

  final GlobalKey<FormState> formKey;
  final TripLinkActivityModel activity;
  final TextEditingController identityController;
  final TextEditingController fullNameController;
  final DateTime? birthDate;
  final bool useIdentity;
  final bool isSubmitting;
  final VoidCallback onPickBirthDate;
  final VoidCallback onSubmit;
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) {
    return Form(
      key: formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (onBack != null) ...[
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: isSubmitting ? null : onBack,
                icon: const Icon(Iconsax.arrow_left),
                label: const Text('Chọn hoạt động khác'),
              ),
            ),
          ],
          _ActivitySummaryCard(activity: activity),
          const SizedBox(height: 14),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const ParentIconWell(icon: Iconsax.personalcard),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Nhập mã định danh riêng của học sinh',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Hệ thống đối chiếu với roster nhà trường. Nếu không có mã định danh, dùng họ tên và ngày sinh đúng như roster.',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppTheme.onSurfaceVariant,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          TextFormField(
            controller: identityController,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'Mã định danh học sinh (CCCD)',
              prefixIcon: Icon(Iconsax.personalcard),
            ),
            validator: (value) {
              final text = value?.trim() ?? '';
              if (text.isNotEmpty && text.length < 9) {
                return 'Nhập tối thiểu 9 chữ số định danh';
              }
              return null;
            },
          ),
          const SizedBox(height: 12),
          Text(
            'Không có mã định danh? Dùng thông tin fallback',
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
              fontWeight: FontWeight.w700,
              color: AppTheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 8),
          TextFormField(
            controller: fullNameController,
            enabled: !useIdentity && !isSubmitting,
            decoration: const InputDecoration(
              labelText: 'Họ và tên học sinh',
              prefixIcon: Icon(Iconsax.user),
            ),
            validator: (value) {
              if (identityController.text.trim().isNotEmpty) return null;
              if ((value ?? '').trim().isEmpty) {
                return 'Nhập họ tên hoặc mã định danh';
              }
              return null;
            },
          ),
          const SizedBox(height: 10),
          InputDecorator(
            decoration: InputDecoration(
              labelText: 'Ngày sinh',
              prefixIcon: const Icon(Iconsax.calendar),
              suffixIcon: IconButton(
                onPressed: useIdentity || isSubmitting ? null : onPickBirthDate,
                icon: const Icon(Iconsax.calendar_edit),
              ),
            ),
            child: Text(
              birthDate == null
                  ? 'Chọn ngày sinh'
                  : DateFormat('dd/MM/yyyy').format(birthDate!),
              style: Theme.of(context).textTheme.bodyLarge,
            ),
          ),
          const SizedBox(height: 14),
          const ParentBanner(
            icon: Iconsax.security_safe,
            tone: ParentBannerTone.info,
            text:
                'OTP chỉ được gửi sau khi thông tin học sinh khớp roster. Nếu không khớp, không có bản ghi nào được thay đổi.',
          ),
          const SizedBox(height: 14),
          FilledButton.icon(
            onPressed: isSubmitting ? null : onSubmit,
            icon: isSubmitting
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Iconsax.shield_tick),
            label: Text(isSubmitting ? 'Đang xác minh...' : 'Xác minh & gửi OTP'),
          ),
        ],
      ),
    );
  }
}

class _OtpVerifyPanel extends StatelessWidget {
  const _OtpVerifyPanel({
    required this.activity,
    required this.otpCandidate,
    required this.otpController,
    required this.isSubmitting,
    required this.formatDate,
    required this.onOtpChanged,
    required this.onBack,
    required this.onVerify,
  });

  final TripLinkActivityModel? activity;
  final TripLinkOtpResultModel? otpCandidate;
  final TextEditingController otpController;
  final bool isSubmitting;
  final String Function(String?) formatDate;
  final ValueChanged<String> onOtpChanged;
  final VoidCallback onBack;
  final Future<void> Function() onVerify;

  @override
  Widget build(BuildContext context) {
    final otpCode = otpController.text;
    final maskedPhone = otpCandidate?.parentPhoneMasked ??
        activity?.parentPhoneMasked ??
        'số điện thoại phụ huynh trong roster';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextButton.icon(
          onPressed: isSubmitting ? null : onBack,
          icon: const Icon(Iconsax.arrow_left),
          label: const Text('Nhập lại thông tin học sinh'),
        ),
        if (activity != null) ...[
          _ActivitySummaryCard(activity: activity!),
          const SizedBox(height: 12),
        ],
        ParentBanner(
          icon: Iconsax.tick_circle,
          tone: ParentBannerTone.success,
          text:
              'Học sinh đã xác minh trong hoạt động này. Vui lòng nhập OTP gửi tới $maskedPhone để hoàn tất liên kết.',
        ),
        const SizedBox(height: 14),
        TextFormField(
          controller: otpController,
          autofocus: true,
          keyboardType: TextInputType.number,
          maxLength: 6,
          decoration: const InputDecoration(
            labelText: 'Mã OTP (6 chữ số)',
            prefixIcon: Icon(Iconsax.lock),
            counterText: '',
          ),
          onChanged: onOtpChanged,
        ),
        const SizedBox(height: 8),
        FilledButton.icon(
          onPressed: isSubmitting || otpCode.length != 6 ? null : onVerify,
          icon: isSubmitting
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : const Icon(Iconsax.link_2),
          label: Text(isSubmitting ? 'Đang xác thực...' : 'Xác nhận liên kết'),
        ),
      ],
    );
  }
}

class _ActivitySummaryCard extends StatelessWidget {
  const _ActivitySummaryCard({required this.activity});

  final TripLinkActivityModel activity;

  @override
  Widget build(BuildContext context) {
    return ParentCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            activity.displayTourName,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 6),
          _MetaRow(icon: Iconsax.building, label: activity.schoolName ?? 'Trường'),
          const SizedBox(height: 4),
          _MetaRow(
            icon: Iconsax.calendar_1,
            label: _formatDate(activity.tourDate),
          ),
        ],
      ),
    );
  }

  String _formatDate(String? value) {
    if (value == null || value.isEmpty) return '-';
    final parsed = DateTime.tryParse(value);
    if (parsed == null) return value;
    return DateFormat('dd/MM/yyyy').format(parsed);
  }
}

class _MetaRow extends StatelessWidget {
  const _MetaRow({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 16, color: AppTheme.onSurfaceVariant),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            label,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: AppTheme.onSurfaceVariant,
            ),
          ),
        ),
      ],
    );
  }
}
