import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../../../shared/theme/app_theme.dart';
import '../../../shared/widgets/app_back_leading.dart';
import '../../../shared/widgets/parent_ui.dart';

class PublicConsentPage extends ConsumerStatefulWidget {
  const PublicConsentPage({super.key, required this.token});
  final String token;
  @override
  ConsumerState<PublicConsentPage> createState() => _PublicConsentPageState();
}

class _PublicConsentPageState extends ConsumerState<PublicConsentPage> {
  static const _defaultMandatoryTerms =
      'Tham gia chuyến đi đồng nghĩa với việc chấp nhận xử lý các dữ liệu vận hành bắt buộc sau:\n'
      '1) Định vị GPS của xe trong thời gian diễn ra chuyến đi.\n'
      '2) Chụp, lưu ảnh và video nội bộ phục vụ phụ huynh, nhà trường và đội vận hành — không dùng cho quảng cáo công khai.\n'
      '3) Livestream nội bộ trong chuyến đi với phạm vi người xem được kiểm soát.\n'
      'Đây là điều kiện tham gia dịch vụ, không phải lựa chọn riêng.';

  final otp = TextEditingController();
  Map<String, dynamic>? data;
  bool faceAuthorized = false;
  bool acceptedTerms = false;
  bool loading = true;
  bool sending = false;
  bool submitting = false;
  bool otpSent = false;
  bool done = false;
  String? error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    otp.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final response = await ref
          .read(dioClientProvider)
          .dio
          .get('/v1/public/consents/${widget.token}');
      if (mounted) {
        setState(
          () => data = Map<String, dynamic>.from(response.data['data'] as Map),
        );
      }
    } catch (_) {
      if (mounted) setState(() => error = 'Link không hợp lệ hoặc đã hết hạn.');
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> _sendOtp() async {
    setState(() {
      sending = true;
      error = null;
    });
    try {
      await ref
          .read(dioClientProvider)
          .dio
          .post('/v1/public/consents/${widget.token}/otp');
      if (mounted) setState(() => otpSent = true);
    } catch (_) {
      if (mounted) setState(() => error = 'Không gửi được OTP.');
    } finally {
      if (mounted) setState(() => sending = false);
    }
  }

  Future<void> _submit() async {
    if (!acceptedTerms) {
      setState(() => error = 'Bạn cần chấp nhận điều khoản vận hành bắt buộc.');
      return;
    }
    if (otp.text.length != 6) {
      setState(() => error = 'OTP phải gồm 6 chữ số.');
      return;
    }
    setState(() {
      submitting = true;
      error = null;
    });
    try {
      await ref.read(dioClientProvider).dio.post(
        '/v1/public/consents/${widget.token}/submit',
        data: {
          'otpCode': otp.text,
          'scopes': {'FACE_ATTENDANCE': faceAuthorized},
          'acceptedMandatoryTerms': true,
        },
      );
      if (mounted) setState(() => done = true);
    } catch (_) {
      if (mounted) setState(() => error = 'OTP không đúng hoặc đã hết hạn.');
    } finally {
      if (mounted) setState(() => submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const Scaffold(
        backgroundColor: AppTheme.surfaceLight,
        body: Center(child: CircularProgressIndicator()),
      );
    }
    if (done) {
      return Scaffold(
        backgroundColor: AppTheme.surfaceLight,
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: ParentCard(
              emphasized: true,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ParentIconWell(
                    icon: Icons.check_circle_rounded,
                    size: 72,
                    iconSize: 40,
                    backgroundColor: const Color(0xFFD1FAE5),
                    iconColor: AppTheme.accentGreen,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Đã ghi nhận phản hồi',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.w800,
                          color: AppTheme.onSurface,
                        ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    faceAuthorized
                        ? 'Cảm ơn bạn đã xác nhận điều khoản chuyến và đồng ý điểm danh khuôn mặt.'
                        : 'Cảm ơn bạn đã xác nhận điều khoản chuyến. Điểm danh khuôn mặt chưa được đồng ý — giáo viên sẽ điểm danh thủ công.',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: AppTheme.onSurfaceVariant,
                        ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }
    if (data == null) {
      return Scaffold(
        backgroundColor: AppTheme.surfaceLight,
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: ParentEmptyState(
              icon: Icons.link_off_rounded,
              title: 'Không mở được liên kết',
              description: error ?? 'Không tải được nội dung.',
            ),
          ),
        ),
      );
    }
    final descriptions = Map<String, dynamic>.from(
      data!['scopeDescriptions'] as Map? ?? {},
    );
    final mandatoryTerms =
        data!['mandatoryTourTerms']?.toString() ?? _defaultMandatoryTerms;
    return ParentPageScaffold(
      title: 'Đồng thuận dữ liệu',
      leading: buildAppBackLeading(context),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 32),
        children: [
          ParentCard(
            emphasized: true,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  data!['title']?.toString() ??
                      'Đồng thuận dữ liệu chuyến đi',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                ),
                const SizedBox(height: 8),
                ParentStatusChip(
                  label: '${data!['studentName']} · ${data!['tourName']}',
                  color: AppTheme.primary,
                  icon: Icons.child_care_outlined,
                ),
                const SizedBox(height: 12),
                Text(
                  data!['noticeText']?.toString() ?? '',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppTheme.onSurfaceVariant,
                        height: 1.45,
                      ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
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
                Text(
                  mandatoryTerms,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppTheme.onSurfaceVariant,
                        height: 1.45,
                      ),
                ),
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  value: acceptedTerms,
                  onChanged: (value) =>
                      setState(() => acceptedTerms = value ?? false),
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
            emphasized: faceAuthorized,
            child: SwitchListTile(
              value: faceAuthorized,
              onChanged: (value) => setState(() => faceAuthorized = value),
              activeThumbColor: Colors.white,
              activeTrackColor: AppTheme.primary,
              secondary: ParentIconWell(
                icon: Icons.face_retouching_natural_rounded,
                backgroundColor:
                    faceAuthorized ? AppTheme.primarySoft : AppTheme.neutral100,
                iconColor: faceAuthorized
                    ? AppTheme.primary
                    : AppTheme.onSurfaceVariant,
              ),
              title: const Text(
                'Điểm danh khuôn mặt (tùy chọn)',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
              subtitle: Text(
                descriptions['FACE_ATTENDANCE']?.toString() ??
                    'Từ chối thì giáo viên điểm danh thủ công.',
              ),
            ),
          ),
          const SizedBox(height: 16),
          OutlinedButton.icon(
            onPressed: sending ? null : _sendOtp,
            icon: const Icon(Icons.sms_outlined),
            label: Text(
              sending
                  ? 'Đang gửi…'
                  : otpSent
                      ? 'Gửi lại OTP'
                      : 'Gửi OTP',
            ),
          ),
          if (otpSent) ...[
            const SizedBox(height: 10),
            ParentBanner(
              text:
                  'OTP đã gửi tới ${data!['phoneMasked'] ?? 'số điện thoại roster'}',
              tone: ParentBannerTone.success,
              icon: Icons.check_circle_outline,
            ),
          ],
          const SizedBox(height: 12),
          TextField(
            controller: otp,
            keyboardType: TextInputType.number,
            maxLength: 6,
            decoration: const InputDecoration(
              labelText: 'Mã OTP xác nhận',
              counterText: '',
            ),
          ),
          if (error != null) ...[
            const SizedBox(height: 8),
            ParentBanner(
              text: error!,
              tone: ParentBannerTone.danger,
              icon: Icons.error_outline,
            ),
          ],
          const SizedBox(height: 16),
          FilledButton(
            onPressed: !otpSent || !acceptedTerms || submitting ? null : _submit,
            child: Text(submitting ? 'Đang xác nhận…' : 'Xác nhận phản hồi'),
          ),
        ],
      ),
    );
  }
}
