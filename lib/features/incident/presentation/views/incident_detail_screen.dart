import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/providers.dart';
import '../../../../shared/theme/app_theme.dart';
import '../../../../shared/widgets/app_back_leading.dart';
import '../../../../shared/widgets/parent_ui.dart';
import '../../../attendance/domain/entities/offline_attendance.dart';
import '../../domain/entities/incident_report.dart';
import '../../domain/entities/incident_severity.dart';
import '../../domain/entities/incident_status.dart';
import '../widgets/incident_status_badge.dart';

/// Incident detail screen — shown when tapping an item in the list.
class IncidentDetailScreen extends ConsumerStatefulWidget {
  const IncidentDetailScreen({
    super.key,
    required this.incidentId,
    this.readOnly = false,
  });

  final String incidentId;
  final bool readOnly;

  @override
  ConsumerState<IncidentDetailScreen> createState() =>
      _IncidentDetailScreenState();
}

class _IncidentDetailScreenState extends ConsumerState<IncidentDetailScreen> {
  List<AttendanceStudent> _rosterStudents = [];
  bool _rosterLoaded = false;
  Map<String, dynamic>? _missingStudentSnapshot;
  String? _snapshotRequestedFor;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref
          .read(incidentViewModelProvider.notifier)
          .loadIncidentDetail(widget.incidentId);
    });
  }

  Future<void> _loadMissingStudentSnapshot(String incidentId) async {
    if (_snapshotRequestedFor == incidentId) return;
    _snapshotRequestedFor = incidentId;
    try {
      final snapshot = await ref.read(incidentRepositoryProvider).getMissingStudentSnapshot(incidentId);
      if (mounted) setState(() => _missingStudentSnapshot = snapshot);
    } catch (_) {
      // Closed incidents and ordinary parents intentionally cannot read this context.
    }
  }

  Future<void> _loadRosterIfNeeded(String tourId) async {
    if (_rosterLoaded || tourId.isEmpty) return;
    _rosterLoaded = true;
    try {
      final students = await ref
          .read(attendanceRemoteDataSourceProvider)
          .listStudents(tourId);
      if (mounted) setState(() => _rosterStudents = students);
    } catch (_) {
      _rosterLoaded = false;
    }
  }

  String _studentLabel(String studentId) {
    for (final student in _rosterStudents) {
      if (student.rosterStudentId == studentId) {
        if (student.className?.isNotEmpty == true) {
          return '${student.fullName} (${student.className})';
        }
        return student.fullName;
      }
    }
    final snapshotStudentId = _missingStudentSnapshot?['rosterStudentId']?.toString();
    final snapshotStudentName = _missingStudentSnapshot?['studentDisplayName']?.toString();
    if (snapshotStudentId == studentId &&
        snapshotStudentName != null &&
        snapshotStudentName.trim().isNotEmpty) {
      return snapshotStudentName;
    }

    // An internal UUID is never a meaningful label for a field user. The
    // roster request can legitimately be unavailable for a resolved incident.
    return 'Học sinh đã chọn';
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(incidentViewModelProvider);
    final incident = state.selectedIncident;

    if (incident != null) {
      final rosterTourId = incident.tourInstanceId ?? incident.tourId;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _loadRosterIfNeeded(rosterTourId);
        if (incident.incidentType.name == 'lostStudent') {
          _loadMissingStudentSnapshot(incident.id);
        }
      });
    }

    return Scaffold(
      backgroundColor: AppTheme.surfaceLight,
      appBar: AppBar(
        leading: buildAppBackLeading(context, color: AppTheme.primary),
        title: const Text('Chi tiết sự cố'),
      ),
      body: state.isLoadingDetail && incident == null
          ? const Center(child: CircularProgressIndicator())
          : state.errorMessage != null && incident == null
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      state.errorMessage!,
                      textAlign: TextAlign.center,
                      style: TextStyle(color: AppTheme.onSurfaceVariant),
                    ),
                    const SizedBox(height: 16),
                    OutlinedButton(
                      onPressed: () => ref
                          .read(incidentViewModelProvider.notifier)
                          .loadIncidentDetail(widget.incidentId),
                      child: const Text('Thử lại'),
                    ),
                  ],
                ),
              ),
            )
          : incident == null
          ? Center(
              child: Text(
                'Không tìm thấy sự cố.',
                style: TextStyle(color: AppTheme.onSurfaceVariant),
              ),
            )
          : RefreshIndicator(
              onRefresh: () => ref
                  .read(incidentViewModelProvider.notifier)
                  .loadIncidentDetail(widget.incidentId),
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(20),
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          incident.title,
                          style: Theme.of(context).textTheme.titleLarge
                              ?.copyWith(fontWeight: FontWeight.w800),
                        ),
                      ),
                      IncidentStatusBadge(status: incident.status),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _Chip(
                        label: incident.incidentType.label,
                        color: AppTheme.primary,
                      ),
                      _Chip(
                        label: incident.severity.label,
                        color: incident.severity.color,
                      ),
                      if (incident.offlineCreated)
                        _Chip(label: 'Offline', color: AppTheme.accentOrange),
                    ],
                  ),
                  const SizedBox(height: 20),
                  _InfoCard(
                    children: [
                      if (incident.tourName != null &&
                          incident.tourName!.trim().isNotEmpty)
                        _InfoRow(
                          label: 'Tour',
                          value: incident.schoolName?.trim().isNotEmpty == true
                              ? '${incident.tourName} · ${incident.schoolName}'
                              : incident.tourName!,
                        ),
                      _InfoRow(
                        label: 'Thời gian',
                        value: _formatDateTime(incident.incidentTime),
                      ),
                      _InfoRow(
                        label: incident.incidentType.name == 'lostStudent'
                            ? 'Nơi thấy lần cuối'
                            : 'Vị trí',
                        value: incident.locationText ?? 'Không rõ',
                      ),
                      if (incident.latitude != null &&
                          incident.longitude != null)
                        _InfoRow(
                          label: incident.incidentType.name == 'lostStudent'
                              ? 'GPS người báo cáo'
                              : 'GPS',
                          value:
                              '${incident.latitude!.toStringAsFixed(5)}, ${incident.longitude!.toStringAsFixed(5)}',
                        ),
                      if (incident.acknowledgedAt != null)
                        _InfoRow(
                          label: 'Tiếp nhận lúc',
                          value: _formatDateTime(incident.acknowledgedAt!),
                        ),
                      if (incident.resolvedAt != null)
                        _InfoRow(
                          label: 'Giải quyết lúc',
                          value: _formatDateTime(incident.resolvedAt!),
                        ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _buildStudentsSection(incident),
                  if (incident.incidentType.name == 'lostStudent' &&
                      _missingStudentSnapshot != null) ...[
                    const SizedBox(height: 16),
                    _buildMissingStudentTrail(incident, _missingStudentSnapshot!),
                  ],
                  if (incident.description != null &&
                      incident.description!.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    _SectionLabel('Mô tả'),
                    const SizedBox(height: 8),
                    Text(
                      incident.description!,
                      style: Theme.of(
                        context,
                      ).textTheme.bodyMedium?.copyWith(height: 1.4),
                    ),
                  ],
                  if (incident.resolutionNote != null &&
                      incident.resolutionNote!.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    _SectionLabel('Ghi chú giải quyết'),
                    const SizedBox(height: 8),
                    Text(
                      incident.resolutionNote!,
                      style: Theme.of(
                        context,
                      ).textTheme.bodyMedium?.copyWith(height: 1.4),
                    ),
                  ],
                  const SizedBox(height: 16),
                  _buildEvidenceSection(incident),
                  if (incident.severity == IncidentSeverity.critical) ...[
                    const SizedBox(height: 24),
                    const ParentBanner(
                      text:
                          'Sự cố mức khẩn cấp. Tiếp tục theo dõi và chờ hướng dẫn từ Tour Manager.',
                      icon: Icons.warning_amber_rounded,
                      tone: ParentBannerTone.danger,
                    ),
                  ],
                  if (_canResolve(incident)) ...[
                    const SizedBox(height: 24),
                    FilledButton.icon(
                      onPressed: state.isSubmitting
                          ? null
                          : () => _showResolveDialog(incident),
                      icon: state.isSubmitting
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.check_circle_outline),
                      label: const Text('Đã giải quyết'),
                    ),
                  ],
                ],
              ),
            ),
    );
  }

  bool _canResolve(IncidentReport incident) {
    if (widget.readOnly) return false;
    return incident.status == IncidentStatus.open ||
        incident.status == IncidentStatus.acknowledged ||
        incident.status == IncidentStatus.escalated;
  }

  Future<void> _showResolveDialog(IncidentReport incident) async {
    final note = await showDialog<String>(
      context: context,
      builder: (context) => const _ResolveNoteDialog(),
    );
    if (note == null || !mounted) return;

    final tourId = incident.tourInstanceId ?? incident.tourId;
    final ok = await ref.read(incidentViewModelProvider.notifier).resolveIncident(
          incidentId: incident.id,
          resolutionNote: note,
          tourId: tourId,
        );
    if (!mounted) return;
    final error = ref.read(incidentViewModelProvider).errorMessage;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(ok
            ? 'Đã đánh dấu sự cố là đã giải quyết.'
            : (error ?? 'Không thể giải quyết sự cố.')),
      ),
    );
  }

  Widget _buildStudentsSection(IncidentReport incident) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionLabel(
          'Học sinh liên quan (${incident.affectedStudentIds.length})',
        ),
        const SizedBox(height: 8),
        if (incident.affectedStudentIds.isEmpty)
          ParentCard(
            child: Text(
              'Không có học sinh nào được chọn trong báo cáo này.',
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: AppTheme.onSurfaceVariant),
            ),
          )
        else
          ...incident.affectedStudentIds.map(
            (id) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: ParentCard(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.person_outline,
                      color: AppTheme.primary,
                      size: 18,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _studentLabel(id),
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildMissingStudentTrail(IncidentReport incident, Map<String, dynamic> snapshot) {
    final attendance = snapshot['lastAttendance'] as Map?;
    final vehicle = snapshot['vehicleAssignment'] as Map?;
    final vehicleLocation = snapshot['vehicleLocation'] as Map?;
    final trail = snapshot['personalTrackerTrail'] as Map?;
    final points = (trail?['points'] as List? ?? const []);
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const _SectionLabel('Dấu vết vận hành khi báo cáo'),
      const SizedBox(height: 8),
      ParentCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Xe/nhóm: ${vehicle?['label'] ?? 'Chưa phân xe'}'),
        Text('Điểm danh cuối: ${attendance?['checkpointName'] ?? 'Không có dữ liệu'}'),
        Text('GPS xe: ${vehicleLocation?['status'] == 'FOUND' ? 'Có dữ liệu' : 'Không có dữ liệu'}'),
        const SizedBox(height: 6),
        const Text('Vị trí xe không phải vị trí học sinh.', style: TextStyle(fontWeight: FontWeight.w700)),
      ])),
      const SizedBox(height: 10),
      FilledButton.icon(
        onPressed: () => context.push(
          '/incident/${incident.id}/search-map',
          extra: {
            'studentName': incident.affectedStudentIds.isEmpty
                ? 'Học sinh'
                : _studentLabel(incident.affectedStudentIds.first),
            'snapshot': snapshot,
          },
        ),
        icon: const Icon(Icons.map_outlined),
        label: Text(points.isEmpty ? 'Mở bản đồ tìm kiếm' : 'Xem đường GPS cá nhân trên bản đồ'),
      ),
      const SizedBox(height: 10),
      if (points.isEmpty)
        const Text('Không có lịch sử vị trí thiết bị cá nhân.')
      else
        ParentCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Lộ trình thiết bị cá nhân — 60 phút trước báo cáo', style: TextStyle(fontWeight: FontWeight.w800)),
          const SizedBox(height: 6),
          ...points.reversed.take(8).map((point) {
            final item = point as Map;
            return Padding(
              padding: const EdgeInsets.only(bottom: 5),
              child: Text('• ${item['recordedAt'] ?? ''} — ${item['latitude']}, ${item['longitude']}'),
            );
          }),
          const SizedBox(height: 4),
          const Text('Đây là lộ trình thiết bị, không khẳng định tuyệt đối vị trí học sinh.', style: TextStyle(fontSize: 12)),
        ])),
    ]);
  }

  Widget _buildEvidenceSection(IncidentReport incident) {
    final evidenceTourId = incident.tourInstanceId ?? incident.tourId;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: _SectionLabel('Bằng chứng (${incident.evidences.length})'),
            ),
            TextButton.icon(
              onPressed: () async {
                final query = Uri(
                  queryParameters: {'tourId': evidenceTourId},
                ).query;
                await context.push('/incident/${incident.id}/evidence?$query');
                if (mounted) {
                  await ref
                      .read(incidentViewModelProvider.notifier)
                      .loadIncidentDetail(incident.id);
                }
              },
              icon: const Icon(Icons.add_photo_alternate_outlined, size: 18),
              label: const Text('Thêm'),
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (incident.evidences.isEmpty)
          ParentCard(
            child: Text(
              'Chưa có ảnh hoặc ghi chú đính kèm.',
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: AppTheme.onSurfaceVariant),
            ),
          )
        else
          ...incident.evidences.map((evidence) {
            final isImage =
                evidence.evidenceType == 'IMAGE' &&
                evidence.fileUrl != null &&
                evidence.fileUrl!.isNotEmpty;
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: ParentCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (isImage)
                      ClipRRect(
                        borderRadius: BorderRadius.circular(
                          AppTheme.radiusSm,
                        ),
                        child: Image.network(
                          evidence.fileUrl!,
                          height: 160,
                          width: double.infinity,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) => Text(
                            'Không tải được ảnh',
                            style: TextStyle(color: AppTheme.onSurfaceVariant),
                          ),
                        ),
                      )
                    else
                      Text(
                        evidence.noteContent ??
                            evidence.fileUrl ??
                            evidence.evidenceType,
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                  ],
                ),
              ),
            );
          }),
      ],
    );
  }

  String _formatDateTime(DateTime dt) =>
      '${dt.day.toString().padLeft(2, '0')}/'
      '${dt.month.toString().padLeft(2, '0')}/'
      '${dt.year}  '
      '${dt.hour.toString().padLeft(2, '0')}:'
      '${dt.minute.toString().padLeft(2, '0')}';
}

class _ResolveNoteDialog extends StatefulWidget {
  const _ResolveNoteDialog();

  @override
  State<_ResolveNoteDialog> createState() => _ResolveNoteDialogState();
}

class _ResolveNoteDialogState extends State<_ResolveNoteDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Xác nhận đã giải quyết'),
      content: Form(
        key: _formKey,
        child: TextFormField(
          controller: _controller,
          maxLines: 4,
          maxLength: 3000,
          decoration: const InputDecoration(
            labelText: 'Ghi chú xử lý *',
            hintText:
                'Mô tả cách đã xử lý tại hiện trường (tối thiểu 10 ký tự).',
            alignLabelWithHint: true,
          ),
          validator: (value) {
            final note = value?.trim() ?? '';
            if (note.isEmpty) return 'Vui lòng nhập ghi chú xử lý.';
            if (note.length < 10) {
              return 'Ghi chú cần tối thiểu 10 ký tự.';
            }
            return null;
          },
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Hủy'),
        ),
        FilledButton(
          onPressed: () {
            if (_formKey.currentState?.validate() != true) return;
            Navigator.of(context).pop(_controller.text.trim());
          },
          child: const Text('Xác nhận'),
        ),
      ],
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: Theme.of(
        context,
      ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppTheme.radiusPill),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return ParentCard(child: Column(children: children));
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 130,
            child: Text(
              label,
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: AppTheme.onSurfaceVariant),
            ),
          ),
          Expanded(
            child: Text(value, style: Theme.of(context).textTheme.bodySmall),
          ),
        ],
      ),
    );
  }
}
