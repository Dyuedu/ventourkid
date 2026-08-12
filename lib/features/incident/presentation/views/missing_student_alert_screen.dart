import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:geolocator/geolocator.dart';

import '../../../../app/providers.dart';
import '../../../../shared/theme/app_theme.dart';
import '../../../../shared/widgets/app_back_leading.dart';
import '../../../../shared/widgets/parent_ui.dart';

/// Screen 3.2.39 — Missing Student Alert (UC-EMG-01, BR-103).
class MissingStudentAlertScreen extends ConsumerStatefulWidget {
  const MissingStudentAlertScreen({super.key, required this.tourId});

  final String tourId;

  @override
  ConsumerState<MissingStudentAlertScreen> createState() =>
      _MissingStudentAlertScreenState();
}

class _MissingStudentAlertScreenState
    extends ConsumerState<MissingStudentAlertScreen> {
  final _lastSeenController = TextEditingController();
  String? _selectedStudentId;
  bool _isSubmitting = false;

  List<Map<String, dynamic>> _students = const [];
  Map<String, dynamic>? _contextPreview;
  bool _loadingRoster = true;
  bool _loadingPreview = false;
  bool _shareLocation = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadRoster());
  }

  Future<void> _loadRoster() async {
    if (widget.tourId.isEmpty) return;
    try {
      final students = await ref.read(incidentRepositoryProvider).getMissingStudentCandidates(widget.tourId);
      if (mounted) setState(() { _students = students; _loadingRoster = false; });
    } catch (_) {
      if (mounted) setState(() => _loadingRoster = false);
    }
  }

  Future<void> _selectStudent(String? value) async {
    setState(() { _selectedStudentId = value; _contextPreview = null; _loadingPreview = value != null; });
    if (value == null) return;
    try {
      final preview = await ref.read(incidentRepositoryProvider).getMissingStudentContext(widget.tourId, value);
      if (mounted && _selectedStudentId == value) setState(() => _contextPreview = preview);
    } catch (_) {} finally {
      if (mounted && _selectedStudentId == value) setState(() => _loadingPreview = false);
    }
  }

  @override
  void dispose() {
    _lastSeenController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.surfaceLight,
      appBar: AppBar(
        leading: buildAppBackLeading(context, color: Colors.white),
        backgroundColor: AppTheme.accentRed,
        foregroundColor: Colors.white,
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.white),
            SizedBox(width: 8),
            Flexible(
              child: Text(
                'Báo cáo mất học sinh',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                  fontSize: 16,
                ),
              ),
            ),
          ],
        ),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 32),
          children: [
            const ParentBanner(
              icon: Icons.campaign_outlined,
              tone: ParentBannerTone.danger,
              text:
                  'Hành động này sẽ ngay lập tức thông báo khẩn cấp đến Tour Manager, giáo viên phụ trách và toàn bộ nhóm. Chỉ dùng khi thực sự không tìm thấy học sinh.',
            ),
            const SizedBox(height: 20),
            ParentCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Chọn học sinh *',
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                          color: AppTheme.onSurfaceVariant,
                        ),
                  ),
                  const SizedBox(height: 8),
                  Autocomplete<Map<String, dynamic>>(
                    displayStringForOption: (student) =>
                        student['display_name']?.toString() ?? 'Học sinh',
                    optionsBuilder: (textEditingValue) {
                      final keyword = textEditingValue.text.trim().toLowerCase();
                      if (keyword.isEmpty) return _students;
                      return _students.where((student) {
                        final name = student['display_name']
                                ?.toString()
                                .toLowerCase() ??
                            '';
                        return name.contains(keyword);
                      });
                    },
                    onSelected: (student) =>
                        _selectStudent(student['roster_student_id']?.toString()),
                    fieldViewBuilder:
                        (context, controller, focusNode, onFieldSubmitted) {
                      return TextFormField(
                        controller: controller,
                        focusNode: focusNode,
                        enabled: !_loadingRoster,
                        textInputAction: TextInputAction.search,
                        decoration: const InputDecoration(
                          hintText: 'Chọn hoặc tìm học sinh bị mất liên lạc',
                          prefixIcon: Icon(Icons.search),
                          suffixIcon: Icon(Icons.arrow_drop_down),
                        ),
                        onChanged: (_) {
                          if (_selectedStudentId != null) {
                            setState(() {
                              _selectedStudentId = null;
                              _contextPreview = null;
                            });
                          }
                        },
                      );
                    },
                    optionsViewBuilder: (context, onSelected, options) {
                      final choices = options.toList(growable: false);
                      return Align(
                        alignment: Alignment.topLeft,
                        child: Material(
                          elevation: 6,
                          borderRadius: BorderRadius.circular(12),
                          child: SizedBox(
                            width: MediaQuery.sizeOf(context).width - 64,
                            child: ConstrainedBox(
                              constraints: const BoxConstraints(maxHeight: 260),
                              child: ListView.builder(
                                padding: const EdgeInsets.symmetric(vertical: 4),
                                shrinkWrap: true,
                                itemCount: choices.length,
                                itemBuilder: (context, index) {
                                  final student = choices[index];
                                  return ListTile(
                                    leading: const Icon(Icons.person_outline),
                                    title: Text(
                                      student['display_name']?.toString() ??
                                          'Học sinh',
                                    ),
                                    onTap: () => onSelected(student),
                                  );
                                },
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                  if (_loadingRoster)
                    const Padding(padding: EdgeInsets.only(top: 8), child: LinearProgressIndicator()),
                  const SizedBox(height: 16),
                  Text(
                    'Nhìn thấy lần cuối ở đâu?',
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                          color: AppTheme.onSurfaceVariant,
                        ),
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _lastSeenController,
                    maxLines: 3,
                    decoration: const InputDecoration(
                      hintText:
                          'VD: Khu vực bãi biển số 2 lúc 10:30, mặc áo xanh…',
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Khoanh vùng hệ thống',
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                          color: AppTheme.onSurfaceVariant,
                        ),
                  ),
                  const SizedBox(height: 8),
                  if (_loadingPreview) const LinearProgressIndicator()
                  else if (_contextPreview != null) _ContextPreview(context: _contextPreview!),
                  const SizedBox(height: 10),
                  const Text('Hệ thống sẽ tự lấy xe, checkpoint và GPS khả dụng. GPS xe chỉ dùng để khoanh vùng, không phải vị trí của học sinh.'),
                  SwitchListTile.adaptive(
                    contentPadding: EdgeInsets.zero,
                    value: _shareLocation,
                    onChanged: (value) => setState(() => _shareLocation = value),
                    title: const Text('Chia sẻ vị trí hiện tại'),
                    subtitle: const Text('Chỉ lấy một lần khi gửi báo cáo.'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: _selectedStudentId == null || _isSubmitting
                  ? null
                  : _submit,
              style: FilledButton.styleFrom(
                backgroundColor: AppTheme.accentRed,
                foregroundColor: Colors.white,
                minimumSize: const Size.fromHeight(52),
              ),
              icon: const Icon(Icons.warning_rounded),
              label: Text(
                _isSubmitting ? 'Đang gửi…' : 'Gửi cảnh báo khẩn cấp',
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _submit() async {
    if (_selectedStudentId == null) return;

    if (widget.tourId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Không xác định được tour hiện tại. Vui lòng mở màn hình này từ tour đang chạy.',
          ),
          backgroundColor: AppTheme.accentOrange,
        ),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    Position? position;
    if (_shareLocation) {
      final permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.whileInUse ||
          permission == LocationPermission.always) {
        try {
          position = await Geolocator.getCurrentPosition();
        } catch (_) {
          // Location sharing is optional; reporting must still succeed.
        }
      }
    }

    if (!mounted) return;

    final success = await ref
        .read(incidentViewModelProvider.notifier)
        .handleMissingStudent(
          tourId: widget.tourId,
          missingStudentId: _selectedStudentId!,
          lastSeenDescription: _lastSeenController.text.trim().isEmpty
              ? null
              : _lastSeenController.text.trim(),
          reporterLatitude: position?.latitude,
          reporterLongitude: position?.longitude,
        );

    if (!mounted) return;

    setState(() => _isSubmitting = false);

    if (success) {
      _showSuccessDialog();
      return;
    }

    final errMsg = ref.read(incidentViewModelProvider).errorMessage;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(errMsg ?? 'Gửi cảnh báo thất bại, vui lòng thử lại'),
        backgroundColor: AppTheme.accentRed,
      ),
    );
  }

  void _showSuccessDialog() {
    if (!mounted) return;
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surface,
        title: const Row(
          children: [
            Icon(Icons.check_circle, color: AppTheme.accentGreen),
            SizedBox(width: 8),
            Expanded(child: Text('Đã gửi cảnh báo')),
          ],
        ),
        content: const Text(
          'Cảnh báo khẩn cấp đã được gửi đến Tour Manager và toàn bộ nhóm. '
          'Vui lòng tiếp tục tìm kiếm và chờ hướng dẫn.',
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              if (mounted) context.pop();
            },
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }
}

class _ContextPreview extends StatelessWidget {
  const _ContextPreview({required this.context});
  final Map<String, dynamic> context;

  @override
  Widget build(BuildContext context) {
    final attendance = this.context['lastAttendance'] as Map?;
    final vehicle = this.context['vehicleAssignment'] as Map?;
    final vehicleLocation = this.context['vehicleLocation'] as Map?;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('Xe/nhóm: ${vehicle?['label'] ?? 'Chưa phân xe'}'),
      Text('Điểm danh cuối: ${attendance?['checkpointName'] ?? 'Chưa có dữ liệu'}'),
      Text('GPS xe: ${vehicleLocation?['status'] == 'FOUND' ? 'Có dữ liệu' : 'Không có dữ liệu'}'),
      const Text('Vị trí xe không phải vị trí học sinh.', style: TextStyle(fontWeight: FontWeight.w600)),
    ]);
  }
}
