import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../app/providers.dart';
import '../../../../shared/theme/app_theme.dart';
import '../../../../shared/widgets/app_back_leading.dart';
import '../../../attendance/domain/entities/offline_attendance.dart';
import '../../domain/entities/incident_severity.dart';
import '../../domain/entities/incident_type.dart';
import '../../../livestream/data/models/livestream_setup_models.dart';

/// Screen 3.2.50 — Report Incidents (UC-INC-01, UC-GUI-03).
class CreateIncidentScreen extends ConsumerStatefulWidget {
  const CreateIncidentScreen({
    super.key,
    required this.tourId,
    this.reporterRole = 'TOUR_GUIDE',
    this.initialAffectedStudentIds = const [],
  });

  final String tourId;
  final String reporterRole;
  final List<String> initialAffectedStudentIds;

  @override
  ConsumerState<CreateIncidentScreen> createState() =>
      _CreateIncidentScreenState();
}

class _PendingImage {
  const _PendingImage({required this.path, required this.name});

  final String path;
  final String name;
}

class _CreateIncidentScreenState extends ConsumerState<CreateIncidentScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _locationController = TextEditingController();
  final _studentSearchController = TextEditingController();
  final _picker = ImagePicker();

  IncidentType _selectedType = IncidentType.medical;
  IncidentSeverity _selectedSeverity = IncidentSeverity.medium;
  DateTime _incidentTime = DateTime.now();
  bool _isSubmitting = false;

  bool _hasAffectedStudents = false;
  List<AttendanceStudent> _rosterStudents = [];
  List<LivestreamSetupVehicleOption> _vehicles = [];
  bool _loadingRoster = false;
  String? _rosterError;
  String? _selectedVehicleFilter;
  String? _selectedClassFilter;
  final Set<String> _selectedStudentIds = {};
  final List<_PendingImage> _pendingImages = [];

  @override
  void initState() {
    super.initState();
    if (widget.initialAffectedStudentIds.isNotEmpty) {
      _hasAffectedStudents = true;
      _selectedStudentIds.addAll(widget.initialAffectedStudentIds);
    }
    _studentSearchController.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _locationController.dispose();
    _studentSearchController.dispose();
    super.dispose();
  }

  Future<void> _loadRosterData() async {
    if (_loadingRoster) return;
    setState(() {
      _loadingRoster = true;
      _rosterError = null;
    });
    try {
      final results = await Future.wait([
        ref
            .read(attendanceRemoteDataSourceProvider)
            .listStudents(widget.tourId),
        ref
            .read(livestreamRepositoryProvider)
            .getGuideSetupOptions(tourId: widget.tourId),
      ]);
      if (!mounted) return;
      setState(() {
        _rosterStudents = results[0] as List<AttendanceStudent>;
        _vehicles = (results[1] as LivestreamSetupOptions).vehicles;
        _loadingRoster = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loadingRoster = false;
        _rosterError = 'Không tải được danh sách học sinh';
      });
    }
  }

  void _onAffectedStudentsToggled(bool? value) {
    final enabled = value ?? false;
    setState(() {
      _hasAffectedStudents = enabled;
      if (!enabled) {
        _selectedStudentIds.clear();
        _selectedVehicleFilter = null;
        _selectedClassFilter = null;
        _studentSearchController.clear();
      }
    });
    if (enabled && _rosterStudents.isEmpty && _rosterError == null) {
      _loadRosterData();
    }
  }

  List<String> get _classOptions {
    final classes =
        _rosterStudents
            .map((s) => s.className?.trim())
            .whereType<String>()
            .where((name) => name.isNotEmpty)
            .toSet()
            .toList()
          ..sort();
    return classes;
  }

  List<AttendanceStudent> get _filteredStudents {
    final query = _studentSearchController.text.trim().toLowerCase();
    return _rosterStudents.where((student) {
      if (_selectedVehicleFilter != null &&
          student.operationVehicleId != _selectedVehicleFilter) {
        return false;
      }
      if (_selectedClassFilter != null &&
          (student.className ?? '') != _selectedClassFilter) {
        return false;
      }
      if (query.isEmpty) return true;
      final haystack = [
        student.fullName,
        student.studentCode ?? '',
        student.className ?? '',
      ].join(' ').toLowerCase();
      return haystack.contains(query);
    }).toList();
  }

  String _vehicleLabel(String? vehicleId) {
    if (vehicleId == null || vehicleId.isEmpty) return 'Chưa phân xe';
    for (final vehicle in _vehicles) {
      if (vehicle.id == vehicleId) return vehicle.label;
    }
    return 'Xe';
  }

  Future<void> _pickImage(ImageSource source) async {
    final file = await _picker.pickImage(
      source: source,
      imageQuality: 85,
      maxWidth: 1600,
    );
    if (file == null) return;
    setState(() {
      _pendingImages.add(
        _PendingImage(
          path: file.path,
          name: file.name.isNotEmpty ? file.name : 'evidence.jpg',
        ),
      );
    });
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    if (_hasAffectedStudents && _selectedStudentIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Vui lòng chọn ít nhất một học sinh liên quan'),
          backgroundColor: AppTheme.accentOrange,
        ),
      );
      return;
    }

    if (widget.tourId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text(
            'Không xác định được tour hiện tại. Vui lòng mở màn hình này từ tour đang chạy.',
          ),
          backgroundColor: AppTheme.accentOrange,
        ),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final repository = ref.read(incidentRepositoryProvider);
      final evidences = <Map<String, dynamic>>[];

      for (final image in _pendingImages) {
        final uploaded = await repository.uploadEvidenceFile(
          tourId: widget.tourId,
          path: image.path,
          filename: image.name,
        );
        evidences.add({
          'evidenceType': 'IMAGE',
          'fileUrl': uploaded.fileUrl,
          'documentMetadataId': uploaded.documentMetadataId,
          'description': 'Ảnh hiện trường',
        });
      }

      final success = await ref
          .read(incidentViewModelProvider.notifier)
          .createIncident(
            tourId: widget.tourId,
            tourInstanceId: widget.tourId,
            reporterRole: widget.reporterRole,
            incidentType: _selectedType,
            severity: _selectedSeverity,
            title: _titleController.text.trim(),
            description: _descriptionController.text.trim().isEmpty
                ? null
                : _descriptionController.text.trim(),
            incidentTime: _incidentTime,
            locationText: _locationController.text.trim().isEmpty
                ? null
                : _locationController.text.trim(),
            affectedStudentIds:
                !_hasAffectedStudents || _selectedStudentIds.isEmpty
                ? null
                : _selectedStudentIds.toList(),
            evidences: evidences.isEmpty ? null : evidences,
          );

      if (!mounted) return;
      setState(() => _isSubmitting = false);

      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Báo cáo sự cố đã được gửi thành công'),
            backgroundColor: AppTheme.accentGreen,
          ),
        );
        context.pop();
      } else {
        final errMsg = ref.read(incidentViewModelProvider).errorMessage;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errMsg ?? 'Gửi báo cáo thất bại, vui lòng thử lại'),
            backgroundColor: AppTheme.accentRed,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSubmitting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Gửi báo cáo thất bại: $e'),
          backgroundColor: AppTheme.accentRed,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.surfaceLight,
      appBar: AppBar(
        leading: buildAppBackLeading(context, color: AppTheme.primary),
        title: const Text('Báo cáo sự cố'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _EmergencyBanner(tourId: widget.tourId),
              const SizedBox(height: 20),
              _buildLabel('Tiêu đề sự cố *'),
              const SizedBox(height: 8),
              _buildTextField(
                controller: _titleController,
                hint: 'VD: Học sinh bị ngã tại khu vực A',
                validator: (v) => (v == null || v.trim().isEmpty)
                    ? 'Vui lòng nhập tiêu đề'
                    : null,
              ),
              const SizedBox(height: 16),
              _buildLabel('Loại sự cố *'),
              const SizedBox(height: 8),
              _buildDropdown<IncidentType>(
                value: _selectedType,
                items: IncidentType.values,
                label: (t) => t.label,
                onChanged: (t) => setState(() => _selectedType = t!),
              ),
              const SizedBox(height: 16),
              _buildLabel('Mức độ nghiêm trọng *'),
              const SizedBox(height: 8),
              _SeveritySelector(
                selected: _selectedSeverity,
                onChanged: (s) => setState(() => _selectedSeverity = s),
              ),
              const SizedBox(height: 16),
              _buildLabel('Thời gian xảy ra *'),
              const SizedBox(height: 8),
              _DateTimePicker(
                initialDateTime: _incidentTime,
                onChanged: (dt) => setState(() => _incidentTime = dt),
              ),
              const SizedBox(height: 16),
              _buildLabel('Vị trí'),
              const SizedBox(height: 8),
              _buildTextField(
                controller: _locationController,
                hint: 'VD: Bãi đỗ xe khu A, điểm tham quan B',
              ),
              const SizedBox(height: 16),
              _buildStudentsSection(),
              const SizedBox(height: 16),
              _buildEvidenceSection(),
              const SizedBox(height: 16),
              _buildLabel('Mô tả chi tiết'),
              const SizedBox(height: 8),
              _buildTextField(
                controller: _descriptionController,
                hint: 'Mô tả đầy đủ những gì đã xảy ra...',
                maxLines: 5,
              ),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _isSubmitting ? null : _submit,
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: _isSubmitting
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : const Text(
                          'Gửi báo cáo',
                          style: TextStyle(fontSize: 16),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStudentsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildLabel('Học sinh liên quan'),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: AppTheme.surface,
            borderRadius: BorderRadius.circular(AppTheme.radiusMd),
            border: Border.all(
              color: _hasAffectedStudents
                  ? AppTheme.primary.withValues(alpha: 0.4)
                  : AppTheme.neutral200,
            ),
            boxShadow: AppTheme.shadowSm,
          ),
          child: Column(
            children: [
              SwitchListTile(
                value: _hasAffectedStudents,
                onChanged: _isSubmitting ? null : _onAffectedStudentsToggled,
                activeThumbColor: Colors.white,
                activeTrackColor: AppTheme.primary,
                title: Text(
                  'Có học sinh liên quan',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                subtitle: Text(
                  'Bật nếu sự cố liên quan đến học sinh',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppTheme.onSurfaceVariant,
                  ),
                ),
              ),
              if (_hasAffectedStudents) ...[
                Divider(height: 1, color: AppTheme.neutral200),
                Padding(
                  padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
                  child: _buildStudentPickerPanel(),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildStudentPickerPanel() {
    if (_loadingRoster) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 12),
        child: Center(
          child: SizedBox(
            height: 24,
            width: 24,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      );
    }

    if (_rosterError != null) {
      return Column(
        children: [
          Text(
            _rosterError!,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: AppTheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: _loadRosterData,
              icon: const Icon(Icons.refresh, size: 16),
              label: const Text('Thử lại'),
            ),
          ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildStudentFilters(),
        if (_selectedStudentIds.isNotEmpty) ...[
          const SizedBox(height: 12),
          _buildSelectedStudentChips(),
        ],
        const SizedBox(height: 12),
        _buildStudentPickerList(),
      ],
    );
  }

  Widget _buildSelectedStudentChips() {
    final selected = _rosterStudents
        .where((s) => _selectedStudentIds.contains(s.rosterStudentId))
        .toList();
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: selected.map((student) {
        return InputChip(
          label: Text(
            student.fullName,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: AppTheme.primary,
              fontWeight: FontWeight.w700,
            ),
          ),
          deleteIconColor: AppTheme.primary,
          onDeleted: _isSubmitting
              ? null
              : () => setState(
                  () => _selectedStudentIds.remove(student.rosterStudentId),
                ),
          backgroundColor: AppTheme.primarySoft,
          side: BorderSide(color: AppTheme.primary.withValues(alpha: 0.35)),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppTheme.radiusPill),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildStudentFilters() {
    final classes = _classOptions;
    final hasVehicleFilter = _vehicles.isNotEmpty;
    final hasClassFilter = classes.isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (hasVehicleFilter || hasClassFilter)
          Row(
            children: [
              if (hasVehicleFilter)
                Expanded(
                  child: _buildFilterSelect<String?>(
                    label: 'Xe',
                    value: _selectedVehicleFilter,
                    displayText: _selectedVehicleFilter == null
                        ? 'Tất cả'
                        : _vehicleLabel(_selectedVehicleFilter),
                    items: [
                      _SelectOption<String?>(null, 'Tất cả xe'),
                      ..._vehicles.map(
                        (v) => _SelectOption<String?>(v.id, v.label),
                      ),
                    ],
                    onChanged: (value) =>
                        setState(() => _selectedVehicleFilter = value),
                  ),
                ),
              if (hasVehicleFilter && hasClassFilter) const SizedBox(width: 10),
              if (hasClassFilter)
                Expanded(
                  child: _buildFilterSelect<String?>(
                    label: 'Lớp',
                    value: _selectedClassFilter,
                    displayText: _selectedClassFilter ?? 'Tất cả',
                    items: [
                      const _SelectOption<String?>(null, 'Tất cả lớp'),
                      ...classes.map(
                        (name) => _SelectOption<String?>(name, name),
                      ),
                    ],
                    onChanged: (value) =>
                        setState(() => _selectedClassFilter = value),
                  ),
                ),
            ],
          ),
        if (hasVehicleFilter || hasClassFilter) const SizedBox(height: 10),
        TextField(
          controller: _studentSearchController,
          enabled: !_isSubmitting,
          decoration: InputDecoration(
            hintText: 'Tìm theo tên hoặc mã học sinh',
            prefixIcon: Icon(
              Icons.search,
              color: AppTheme.onSurfaceVariant,
              size: 20,
            ),
            isDense: true,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 12,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildFilterSelect<T>({
    required String label,
    required T value,
    required String displayText,
    required List<_SelectOption<T>> items,
    required void Function(T?) onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
            color: AppTheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 4),
        Container(
          decoration: BoxDecoration(
            color: AppTheme.surfaceLow,
            borderRadius: BorderRadius.circular(AppTheme.radiusSm),
            border: Border.all(color: AppTheme.neutral200),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 10),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<T>(
              value: value,
              isExpanded: true,
              isDense: true,
              icon: Icon(
                Icons.keyboard_arrow_down_rounded,
                color: AppTheme.onSurfaceVariant,
                size: 20,
              ),
              style: Theme.of(context).textTheme.bodySmall,
              items: items
                  .map(
                    (opt) => DropdownMenuItem<T>(
                      value: opt.value,
                      child: Text(opt.label, overflow: TextOverflow.ellipsis),
                    ),
                  )
                  .toList(),
              selectedItemBuilder: (context) => items
                  .map(
                    (_) => Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        displayText,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ),
                  )
                  .toList(),
              onChanged: _isSubmitting ? null : onChanged,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStudentPickerList() {
    final students = _filteredStudents;

    if (_rosterStudents.isEmpty) {
      return _buildEmptyStudentState(
        icon: Icons.people_outline,
        message: 'Tour chưa có danh sách học sinh.',
      );
    }

    if (students.isEmpty) {
      return _buildEmptyStudentState(
        icon: Icons.search_off,
        message: 'Không tìm thấy học sinh phù hợp.',
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '${students.length} học sinh • đã chọn ${_selectedStudentIds.length}',
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
            color: AppTheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          constraints: const BoxConstraints(maxHeight: 240),
          decoration: BoxDecoration(
            color: AppTheme.surfaceLow,
            borderRadius: BorderRadius.circular(AppTheme.radiusSm),
            border: Border.all(color: AppTheme.neutral200),
          ),
          child: ListView.separated(
            shrinkWrap: true,
            padding: const EdgeInsets.symmetric(vertical: 4),
            itemCount: students.length,
            separatorBuilder: (_, __) => Divider(
              height: 1,
              color: AppTheme.neutral200,
              indent: 12,
              endIndent: 12,
            ),
            itemBuilder: (context, index) {
              final student = students[index];
              final selected = _selectedStudentIds.contains(
                student.rosterStudentId,
              );
              final classLabel = student.className?.isNotEmpty == true
                  ? student.className!
                  : '—';
              final vehicleLabel = _vehicleLabel(student.operationVehicleId);

              return Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: _isSubmitting
                      ? null
                      : () => setState(() {
                          if (selected) {
                            _selectedStudentIds.remove(student.rosterStudentId);
                          } else {
                            _selectedStudentIds.add(student.rosterStudentId);
                          }
                        }),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    child: Row(
                      children: [
                        _StudentCheckBox(selected: selected),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                student.fullName,
                                style: Theme.of(context).textTheme.bodyMedium
                                    ?.copyWith(
                                      fontWeight: selected
                                          ? FontWeight.w700
                                          : FontWeight.normal,
                                    ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '$classLabel • $vehicleLabel',
                                style: Theme.of(context).textTheme.labelSmall
                                    ?.copyWith(
                                      color: AppTheme.onSurfaceVariant,
                                    ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyStudentState({
    required IconData icon,
    required String message,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 12),
      decoration: BoxDecoration(
        color: AppTheme.surfaceLow,
        borderRadius: BorderRadius.circular(AppTheme.radiusSm),
        border: Border.all(color: AppTheme.neutral200),
      ),
      child: Column(
        children: [
          Icon(icon, color: AppTheme.neutral400, size: 28),
          const SizedBox(height: 8),
          Text(
            message,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: AppTheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEvidenceSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildLabel('Ảnh bằng chứng'),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _isSubmitting
                    ? null
                    : () => _pickImage(ImageSource.camera),
                icon: const Icon(Icons.photo_camera_outlined),
                label: const Text('Chụp ảnh'),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _isSubmitting
                    ? null
                    : () => _pickImage(ImageSource.gallery),
                icon: const Icon(Icons.photo_library_outlined),
                label: const Text('Thư viện'),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
          ],
        ),
        if (_pendingImages.isEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              'Tùy chọn — chụp ảnh hiện trường để Tour Manager xem sau.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: AppTheme.onSurfaceVariant,
              ),
            ),
          )
        else
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: SizedBox(
              height: 88,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: _pendingImages.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (context, index) {
                  final image = _pendingImages[index];
                  return Stack(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(
                          AppTheme.radiusSm,
                        ),
                        child: Image.file(
                          File(image.path),
                          width: 88,
                          height: 88,
                          fit: BoxFit.cover,
                        ),
                      ),
                      Positioned(
                        top: 2,
                        right: 2,
                        child: GestureDetector(
                          onTap: _isSubmitting
                              ? null
                              : () => setState(
                                  () => _pendingImages.removeAt(index),
                                ),
                          child: Container(
                            decoration: BoxDecoration(
                              color: AppTheme.ink.withValues(alpha: 0.6),
                              shape: BoxShape.circle,
                            ),
                            padding: const EdgeInsets.all(2),
                            child: const Icon(
                              Icons.close,
                              color: Colors.white,
                              size: 16,
                            ),
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildLabel(String text) => Text(
        text,
    style: Theme.of(context).textTheme.labelLarge?.copyWith(
      color: AppTheme.onSurfaceVariant,
      fontWeight: FontWeight.w600,
    ),
      );

  Widget _buildTextField({
    required TextEditingController controller,
    required String hint,
    String? Function(String?)? validator,
    int maxLines = 1,
  }) => TextFormField(
        controller: controller,
        maxLines: maxLines,
        validator: validator,
    decoration: InputDecoration(hintText: hint),
      );

  Widget _buildDropdown<T>({
    required T value,
    required List<T> items,
    required String Function(T) label,
    required void Function(T?) onChanged,
  }) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(AppTheme.radiusMd),
      border: Border.all(color: AppTheme.neutral200),
        ),
        child: DropdownButton<T>(
          value: value,
          isExpanded: true,
          underline: const SizedBox(),
      style: Theme.of(context).textTheme.bodyMedium,
          onChanged: onChanged,
          items: items
          .map(
            (item) => DropdownMenuItem(value: item, child: Text(label(item))),
          )
              .toList(),
        ),
      );
}

class _EmergencyBanner extends StatelessWidget {
  const _EmergencyBanner({required this.tourId});
  final String tourId;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => context.push('/incident/missing?tourId=$tourId'),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppTheme.errorContainer,
          borderRadius: BorderRadius.circular(AppTheme.radiusMd),
          border: Border.all(color: AppTheme.accentRed.withValues(alpha: 0.3)),
        ),
        child: Row(
          children: [
            Icon(
              Icons.warning_amber_rounded,
              color: AppTheme.accentRed,
              size: 28,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Mất liên lạc học sinh?',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      color: AppTheme.accentRed,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  Text(
                    'Nhấn để báo cáo khẩn cấp ngay lập tức',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppTheme.accentRed.withValues(alpha: 0.85),
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.arrow_forward_ios,
              color: AppTheme.accentRed.withValues(alpha: 0.7),
              size: 16,
            ),
          ],
        ),
      ),
    );
  }
}

class _SeveritySelector extends StatelessWidget {
  const _SeveritySelector({required this.selected, required this.onChanged});
  final IncidentSeverity selected;
  final void Function(IncidentSeverity) onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: IncidentSeverity.values.map((s) {
        final isSelected = s == selected;
        return Expanded(
          child: Padding(
            padding: const EdgeInsets.only(right: 8),
            child: GestureDetector(
              onTap: () => onChanged(s),
              child: Container(
                constraints: const BoxConstraints(minHeight: 44),
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: isSelected
                      ? s.color.withValues(alpha: 0.14)
                      : AppTheme.surfaceLow,
                  borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                  border: Border.all(
                    color: isSelected ? s.color : AppTheme.neutral200,
                    width: 1.5,
                  ),
                ),
                child: Center(
                  child: Text(
                    s.label,
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: isSelected ? s.color : AppTheme.onSurfaceVariant,
                      fontWeight: isSelected
                          ? FontWeight.bold
                          : FontWeight.normal,
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}

class _DateTimePicker extends StatelessWidget {
  const _DateTimePicker({
    required this.initialDateTime,
    required this.onChanged,
  });
  final DateTime initialDateTime;
  final void Function(DateTime) onChanged;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () async {
        final date = await showDatePicker(
          context: context,
          initialDate: initialDateTime,
          firstDate: DateTime.now().subtract(const Duration(days: 7)),
          lastDate: DateTime.now(),
        );
        if (date == null || !context.mounted) return;
        final time = await showTimePicker(
          context: context,
          initialTime: TimeOfDay.fromDateTime(initialDateTime),
        );
        if (time == null) return;
        onChanged(
          DateTime(date.year, date.month, date.day, time.hour, time.minute),
        );
      },
      child: Container(
        constraints: const BoxConstraints(minHeight: 44),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(AppTheme.radiusMd),
          border: Border.all(color: AppTheme.neutral200),
        ),
        child: Row(
          children: [
            Icon(Icons.schedule_rounded, color: AppTheme.primary, size: 20),
            const SizedBox(width: 10),
            Text(
              '${initialDateTime.day.toString().padLeft(2, '0')}/'
              '${initialDateTime.month.toString().padLeft(2, '0')}/'
              '${initialDateTime.year}  '
              '${initialDateTime.hour.toString().padLeft(2, '0')}:'
              '${initialDateTime.minute.toString().padLeft(2, '0')}',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const Spacer(),
            Icon(
              Icons.edit_rounded,
              color: AppTheme.onSurfaceVariant,
              size: 16,
            ),
          ],
        ),
      ),
    );
  }
}

class _SelectOption<T> {
  const _SelectOption(this.value, this.label);

  final T value;
  final String label;
}

class _StudentCheckBox extends StatelessWidget {
  const _StudentCheckBox({required this.selected});

  final bool selected;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 22,
      height: 22,
      decoration: BoxDecoration(
        color: selected ? AppTheme.primarySoft : Colors.transparent,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: selected ? AppTheme.primary : AppTheme.neutral300,
          width: 1.5,
        ),
      ),
      child: selected
          ? Icon(Icons.check_rounded, size: 16, color: AppTheme.primary)
          : null,
    );
  }
}
