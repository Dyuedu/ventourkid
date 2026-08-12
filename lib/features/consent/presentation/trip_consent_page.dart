import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../../../shared/theme/app_theme.dart';
import '../../../shared/widgets/app_back_leading.dart';
import '../../../shared/widgets/parent_ui.dart';

class TripConsentPage extends ConsumerStatefulWidget {
  const TripConsentPage({
    super.key,
    required this.rosterStudentId,
    required this.operationPlanId,
    required this.studentName,
  });

  final String rosterStudentId;
  final String operationPlanId;
  final String studentName;

  @override
  ConsumerState<TripConsentPage> createState() => _TripConsentPageState();
}

class _TripConsentPageState extends ConsumerState<TripConsentPage> {
  static const _mandatoryTerms =
      'Tham gia chuyến đi bao gồm xử lý bắt buộc: GPS xe, ảnh/video nội bộ (không quảng cáo), và livestream nội bộ có kiểm soát người xem.';

  final _otpController = TextEditingController();
  bool _faceAuthorized = false;
  bool _acceptedTerms = false;
  bool _sendingOtp = false;
  bool _submitting = false;
  String? _otpDestination;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadCurrentChoices();
  }

  Future<void> _loadCurrentChoices() async {
    try {
      final choices = await ref
          .read(parentDashboardRemoteDataSourceProvider)
          .getTripConsents(
            rosterStudentId: widget.rosterStudentId,
            operationPlanId: widget.operationPlanId,
          );
      if (mounted && choices.containsKey('FACE_ATTENDANCE')) {
        setState(() => _faceAuthorized = choices['FACE_ATTENDANCE'] == true);
      }
    } catch (_) {
      // A history read failure must not prevent a parent from making a new choice.
    }
  }

  @override
  void dispose() {
    _otpController.dispose();
    super.dispose();
  }

  Future<void> _sendOtp() async {
    setState(() {
      _sendingOtp = true;
      _error = null;
    });
    try {
      final result = await ref
          .read(parentDashboardRemoteDataSourceProvider)
          .sendTripConsentOtp(
            rosterStudentId: widget.rosterStudentId,
            operationPlanId: widget.operationPlanId,
          );
      if (mounted) {
        setState(() => _otpDestination = result.maskedPhone);
      }
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'Không thể gửi OTP. Vui lòng thử lại sau.');
      }
    } finally {
      if (mounted) {
        setState(() => _sendingOtp = false);
      }
    }
  }

  Future<void> _submit() async {
    if (!_acceptedTerms) {
      setState(() => _error = 'Bạn cần chấp nhận điều khoản vận hành bắt buộc.');
      return;
    }
    if (_otpController.text.length != 6) {
      setState(() => _error = 'Vui lòng nhập mã OTP gồm 6 chữ số.');
      return;
    }
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      await ref.read(parentDashboardRemoteDataSourceProvider).submitTripConsents(
            rosterStudentId: widget.rosterStudentId,
            operationPlanId: widget.operationPlanId,
            otpCode: _otpController.text,
            scopes: {'FACE_ATTENDANCE': _faceAuthorized},
            acceptedMandatoryTerms: true,
          );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Đã lưu phản hồi đồng thuận.')),
        );
        Navigator.of(context).pop(true);
      }
    } catch (_) {
      if (mounted) {
        setState(
          () =>
              _error = 'OTP không đúng, hết hạn hoặc chưa thể lưu đồng thuận.',
        );
      }
    } finally {
      if (mounted) {
        setState(() => _submitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return ParentPageScaffold(
      title: 'Đồng thuận dữ liệu',
      leading: buildAppBackLeading(
        context,
        fallbackRoute: '/parent/dashboard',
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 32),
        children: [
          ParentSectionHeader(
            title: 'Xác nhận cho ${widget.studentName}',
            subtitle:
                'Chấp nhận điều khoản chuyến bắt buộc và lựa chọn điểm danh khuôn mặt.',
          ),
          const SizedBox(height: 12),
          ParentCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Điều khoản vận hành bắt buộc',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                ),
                const SizedBox(height: 8),
                const Text(_mandatoryTerms),
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  value: _acceptedTerms,
                  onChanged: (value) =>
                      setState(() => _acceptedTerms = value ?? false),
                  controlAffinity: ListTileControlAffinity.leading,
                  title: const Text(
                    'Tôi chấp nhận điều khoản GPS / media nội bộ / livestream.',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          ParentCard(
            padding: EdgeInsets.zero,
            emphasized: _faceAuthorized,
            child: CheckboxListTile(
              value: _faceAuthorized,
              onChanged: (value) =>
                  setState(() => _faceAuthorized = value ?? false),
              secondary: ParentIconWell(
                icon: Icons.face_retouching_natural_rounded,
                backgroundColor: _faceAuthorized
                    ? AppTheme.primarySoft
                    : AppTheme.neutral100,
                iconColor: _faceAuthorized
                    ? AppTheme.primary
                    : AppTheme.onSurfaceVariant,
              ),
              title: const Text(
                'Điểm danh khuôn mặt (tùy chọn)',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
              subtitle: const Text(
                'Nếu từ chối, giáo viên sẽ điểm danh thủ công.',
              ),
              activeColor: AppTheme.primary,
              controlAffinity: ListTileControlAffinity.trailing,
            ),
          ),
          const SizedBox(height: 16),
          OutlinedButton.icon(
            onPressed: _sendingOtp ? null : _sendOtp,
            icon: const Icon(Icons.sms_outlined),
            label: Text(
              _sendingOtp
                  ? 'Đang gửi…'
                  : _otpDestination == null
                      ? 'Gửi OTP'
                      : 'Gửi lại OTP',
            ),
          ),
          if (_otpDestination != null) ...[
            const SizedBox(height: 10),
            ParentBanner(
              text: 'Mã OTP đã gửi tới $_otpDestination.',
              tone: ParentBannerTone.success,
              icon: Icons.check_circle_outline,
            ),
          ],
          const SizedBox(height: 12),
          TextField(
            controller: _otpController,
            keyboardType: TextInputType.number,
            maxLength: 6,
            decoration: const InputDecoration(
              labelText: 'Mã OTP xác nhận',
              counterText: '',
            ),
          ),
          if (_error != null) ...[
            const SizedBox(height: 8),
            ParentBanner(
              text: _error!,
              tone: ParentBannerTone.danger,
              icon: Icons.error_outline,
            ),
          ],
          const SizedBox(height: 16),
          FilledButton(
            onPressed: !_acceptedTerms || _submitting ? null : _submit,
            child: Text(_submitting ? 'Đang lưu…' : 'Xác nhận phản hồi'),
          ),
        ],
      ),
    );
  }
}
