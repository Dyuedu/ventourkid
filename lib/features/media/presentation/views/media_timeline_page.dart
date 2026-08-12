import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../app/providers.dart';
import '../../../../features/attendance/domain/entities/offline_attendance.dart';
import '../../../../shared/theme/app_theme.dart';
import '../../../../shared/utils/media_url.dart';
import '../../../../shared/widgets/app_back_leading.dart';
import '../../data/datasources/media_remote_data_source.dart';
import '../../domain/entities/tour_media_item.dart';

class MediaTimelinePage extends ConsumerStatefulWidget {
  const MediaTimelinePage({
    super.key,
    required this.tourId,
    this.studentId,
    this.studentName,
    this.activityId,
    this.readOnlyUpload = false,
  });

  final String tourId;
  final String? studentId;
  final String? studentName;
  final String? activityId;

  /// When true (tour COMPLETED / history), capture & upload are locked; view-only.
  final bool readOnlyUpload;

  @override
  ConsumerState<MediaTimelinePage> createState() => _MediaTimelinePageState();
}

class _MediaTimelinePageState extends ConsumerState<MediaTimelinePage> {
  static const _parentFilters = ['ALL', 'MY_CHILD', 'PHOTOS', 'VIDEOS'];
  static const _staffFilters = ['ALL', 'PHOTOS', 'VIDEOS'];
  static const _allowedMediaExtensions = [
    'jpg',
    'jpeg',
    'png',
    'webp',
    'mp4',
    'mov',
    'webm',
  ];
  final _picker = ImagePicker();
  final _tourIdController = TextEditingController();
  final _activityIdFilterController = TextEditingController();
  final _studentNameController = TextEditingController();
  final _searchController = TextEditingController();
  final _captionController = TextEditingController();
  Timer? _studentSearchDebounce;
  String _filter = 'ALL';
  late Future<List<TourMediaItem>> _future;
  bool _uploading = false;
  bool _loadingUploadContext = false;
  List<AttendanceCheckpoint> _checkpoints = const [];
  String? _selectedCheckpointId;
  List<_SelectedMediaFile> _selectedFiles = const [];
  String? _userRole;

  String? get _linkedStudentId {
    final value = widget.studentId?.trim();
    return value == null || value.isEmpty ? null : value;
  }

  String? get _linkedStudentName {
    final value = widget.studentName?.trim();
    return value == null || value.isEmpty ? null : value;
  }

  bool get _isFieldStaff {
    final role = (_userRole ?? '').toUpperCase();
    return role == 'TOUR_GUIDE' || role == 'TEACHER';
  }

  /// Parent filter "Con của tôi" — ẩn với HDV/GV (trừ khi mở kèm studentId từ luồng phụ huynh).
  bool get _showMyChildFilter {
    if (!_isFieldStaff) return true;
    return _linkedStudentId != null;
  }

  List<String> get _filters =>
      _showMyChildFilter ? _parentFilters : _staffFilters;

  bool get _uploadsEnabled => !widget.readOnlyUpload;

  String get _fallbackRoute {
    final role = (_userRole ?? '').toUpperCase();
    if (role == 'TOUR_GUIDE' || role == 'TEACHER') {
      return '/guide/dashboard';
    }
    return '/parent/dashboard';
  }

  String get _activeTourId => _tourIdController.text.trim();
  String get _activityFilterId => _activityIdFilterController.text.trim();
  String get _studentFilterName => _studentNameController.text.trim();
  String get _searchTerm => _searchController.text.trim().toLowerCase();
  bool get _hasValidTourId =>
      _isValidUuid(_activeTourId) && !_isZeroUuid(_activeTourId);

  @override
  void initState() {
    super.initState();
    _tourIdController.text = widget.tourId.trim();
    final initialActivityId = widget.activityId?.trim();
    if (initialActivityId != null && initialActivityId.isNotEmpty) {
      _activityIdFilterController.text = initialActivityId;
    }
    final linkedStudentName = _linkedStudentName;
    if (linkedStudentName != null) {
      _studentNameController.text = linkedStudentName;
    }
    if (_showMyChildFilter &&
        (_linkedStudentId != null || linkedStudentName != null)) {
      _filter = 'MY_CHILD';
    }
    _future = _load();
    Future.microtask(() async {
      await _resolveUserRole();
      if (!mounted) return;
      await _loadUploadContext();
    });
  }

  Future<void> _resolveUserRole() async {
    final role = await ref.read(routeGuardsProvider).userRole;
    if (!mounted) return;
    setState(() {
      _userRole = role;
      // Role resolved after first frame — drop MY_CHILD if staff without linked child.
      if (!_showMyChildFilter && _filter == 'MY_CHILD') {
        _filter = 'ALL';
        _future = _load();
      }
    });
  }

  @override
  void dispose() {
    _studentSearchDebounce?.cancel();
    _tourIdController.dispose();
    _activityIdFilterController.dispose();
    _studentNameController.dispose();
    _searchController.dispose();
    _captionController.dispose();
    super.dispose();
  }

  Future<List<TourMediaItem>> _load() {
    if (!_hasValidTourId) {
      return Future.value(const []);
    }
    if (_filter == 'MY_CHILD' &&
        _linkedStudentId == null &&
        _studentFilterName.isEmpty) {
      return Future.value(const []);
    }
    return ref
        .read(mediaRemoteDataSourceProvider)
        .getTimeline(
          tourId: _activeTourId,
          activityId: _activityFilterId.isEmpty ? null : _activityFilterId,
          filter: _filter,
          studentId: _filter == 'MY_CHILD' ? _linkedStudentId : null,
          studentName: _filter == 'MY_CHILD' && _studentFilterName.isNotEmpty
              ? _studentFilterName
              : null,
        );
  }

  void _reload() {
    setState(() {
      _future = _load();
    });
  }

  void _scheduleStudentSearch() {
    _studentSearchDebounce?.cancel();
    _studentSearchDebounce = Timer(const Duration(milliseconds: 350), () {
      if (!mounted || _filter != 'MY_CHILD') return;
      _reload();
    });
  }

  void _scheduleTimelineReload({bool refreshUploadContext = false}) {
    _studentSearchDebounce?.cancel();
    _studentSearchDebounce = Timer(const Duration(milliseconds: 450), () {
      if (!mounted) return;
      _reload();
      if (refreshUploadContext) {
        unawaited(_loadUploadContext());
      }
    });
  }

  List<TourMediaItem> _applyLocalSearch(List<TourMediaItem> items) {
    final activityId = _activityFilterId.toLowerCase();
    final query = _searchTerm;
    if (query.isEmpty && activityId.isEmpty) return items;
    return items.where((item) {
      if (activityId.isNotEmpty &&
          item.activityId?.toLowerCase() != activityId) {
        return false;
      }
      if (query.isEmpty) return true;
      final values = <String?>[
        item.caption,
        item.tourId,
        item.activityId,
        item.checkpointId,
        item.groupId,
        item.mediaType,
        item.faceProcessingStatus,
        _dateLabel(item.createdAt),
        ...item.faceMatches.map(
          (match) => match.studentDisplayName ?? match.studentId ?? '',
        ),
      ];
      return values.any(
        (value) => value?.toLowerCase().contains(query) == true,
      );
    }).toList();
  }

  Future<void> _openMediaDetail(TourMediaItem item) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.black,
      builder: (context) => _MediaDetailSheet(item: item),
    );
    if (mounted) {
      _reload();
    }
  }

  Future<void> _loadUploadContext() async {
    if (!_hasValidTourId) {
      return;
    }
    setState(() => _loadingUploadContext = true);
    final attendanceRepository = ref.read(offlineAttendanceRepositoryProvider);
    try {
      var checkpoints = await attendanceRepository.getCachedCheckpoints(
        _activeTourId,
      );
      try {
        checkpoints = await attendanceRepository.refreshCheckpoints(
          _activeTourId,
        );
      } catch (_) {
        // Cached checkpoints are still useful for tagging uploads.
      }
      if (!mounted) return;
      setState(() {
        _checkpoints = checkpoints;
        _selectedCheckpointId = _keepOrFirst(
          _selectedCheckpointId,
          checkpoints.map((checkpoint) => checkpoint.checkpointId),
        );
      });
    } finally {
      if (mounted) setState(() => _loadingUploadContext = false);
    }
  }

  Future<void> _pickGallery() async {
    if (!_ensureUploadsEnabled()) return;
    final result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: _allowedMediaExtensions,
      allowMultiple: true,
    );
    final files = result?.files ?? const <PlatformFile>[];
    if (files.isEmpty) return;
    final selectedFiles = <_SelectedMediaFile>[];
    for (final file in files) {
      if (file.path == null || file.path!.isEmpty) {
        continue;
      }
      selectedFiles.add(
        _SelectedMediaFile(
          path: file.path!,
          name: file.name,
          isVideo: _isVideoName(file.name),
        ),
      );
    }
    if (selectedFiles.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Không thể đọc tệp media đã chọn.')),
      );
      return;
    }
    _addSelectedFiles(selectedFiles);
  }

  Future<void> _pickCamera() async {
    if (!_ensureUploadsEnabled()) return;
    final file = await _picker.pickImage(source: ImageSource.camera);
    _selectXFile(file, isVideo: false);
  }

  Future<void> _recordVideo() async {
    if (!_ensureUploadsEnabled()) return;
    final file = await _picker.pickVideo(
      source: ImageSource.camera,
      maxDuration: const Duration(minutes: 2),
    );
    _selectXFile(file, isVideo: true);
  }

  bool _ensureUploadsEnabled() {
    if (_uploadsEnabled) return true;
    if (!mounted) return false;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Tour đã hoàn tất — chỉ xem thư viện. Không thể chụp/quay/tải media mới.',
        ),
      ),
    );
    return false;
  }

  void _selectXFile(XFile? file, {required bool isVideo}) {
    if (file == null) return;
    _addSelectedFiles([
      _SelectedMediaFile(
        path: file.path,
        name: file.name.isNotEmpty ? file.name : _filenameFromPath(file.path),
        isVideo: isVideo,
      ),
    ]);
  }

  void _addSelectedFiles(List<_SelectedMediaFile> files) {
    if (files.isEmpty) return;
    setState(() => _selectedFiles = [..._selectedFiles, ...files]);
  }

  void _removeSelectedFileAt(int index) {
    if (index < 0 || index >= _selectedFiles.length) return;
    setState(() {
      _selectedFiles = [..._selectedFiles]..removeAt(index);
    });
  }

  String _filenameFromPath(String path) {
    final segments = File(path).uri.pathSegments;
    final name = segments.isEmpty ? 'media-upload' : segments.last;
    if (_isVideoName(name)) {
      return name;
    }
    final lower = name.toLowerCase();
    if (lower.endsWith('.jpg') ||
        lower.endsWith('.jpeg') ||
        lower.endsWith('.png') ||
        lower.endsWith('.webp')) {
      return name;
    }
    return '$name.jpg';
  }

  bool _isVideoName(String name) {
    final lower = name.toLowerCase();
    return lower.endsWith('.mp4') ||
        lower.endsWith('.mov') ||
        lower.endsWith('.webm');
  }

  Future<void> _uploadSelectedFile() async {
    if (!_ensureUploadsEnabled()) return;
    if (!_hasValidTourId) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Chưa xác định được tour để tải media lên.'),
        ),
      );
      return;
    }
    final files = _selectedFiles;
    if (files.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Vui lòng chọn media trước khi tải lên.')),
      );
      return;
    }
    setState(() => _uploading = true);
    try {
      await ref
          .read(mediaRemoteDataSourceProvider)
          .uploadBatch(
            tourId: _activeTourId,
            files: files
                .map(
                  (file) =>
                      MediaUploadFile(path: file.path, filename: file.name),
                )
                .toList(),
            caption: _captionController.text.trim(),
            checkpointId: _selectedCheckpointId,
          );
      if (!mounted) return;
      setState(() {
        _selectedFiles = const [];
        _captionController.clear();
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Đã tải lên ${files.length} mục và hiển thị ngay. '
            'InsightFace đang nhận diện học sinh trong ảnh.',
          ),
        ),
      );
      _reload();
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Không thể tải media lên. Vui lòng thử lại.'),
        ),
      );
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  Future<void> _refreshTimeline() async {
    final next = _load();
    setState(() {
      _future = next;
    });
    await next;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.surfaceLight,
      appBar: AppBar(
        leading: buildAppBackLeading(
          context,
          fallbackRoute: _fallbackRoute,
        ),
        title: const Text('Thư viện ảnh chuyến đi'),
        actions: [
          IconButton(
            tooltip: 'Làm mới',
            onPressed: _reload,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 760),
            child: _buildLibraryTab(),
          ),
        ),
      ),
    );
  }

  Widget _buildLibraryTab() {
    return FutureBuilder<List<TourMediaItem>>(
      future: _future,
      builder: (context, snapshot) {
        final isWaiting = snapshot.connectionState == ConnectionState.waiting;
        final allItems = snapshot.data ?? const <TourMediaItem>[];
        final items = _applyLocalSearch(allItems);
        return RefreshIndicator(
          onRefresh: _refreshTimeline,
          child: CustomScrollView(
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              SliverToBoxAdapter(
                child: _Toolbar(
                  filters: _filters,
                  selected: _filter,
                  tourIdController: _tourIdController,
                  activityIdFilterController: _activityIdFilterController,
                  studentNameController: _studentNameController,
                  searchController: _searchController,
                  captionController: _captionController,
                  linkedStudentName: _linkedStudentName,
                  hasLinkedStudent: _linkedStudentId != null,
                  uploadsEnabled: _uploadsEnabled,
                  myChildFilterLabel: (_userRole ?? '').toUpperCase() == 'TEACHER'
                      ? 'Học sinh'
                      : 'Con của tôi',
                  selectedFiles: _selectedFiles,
                  checkpoints: _checkpoints,
                  selectedCheckpointId: _selectedCheckpointId,
                  uploading: _uploading,
                  loadingUploadContext: _loadingUploadContext,
                  onFilterChanged: (value) {
                    setState(() => _filter = value);
                    _reload();
                  },
                  onStudentChanged: _scheduleStudentSearch,
                  onSearchChanged: () => setState(() {}),
                  onTourChanged: () =>
                      _scheduleTimelineReload(refreshUploadContext: true),
                  onActivityFilterChanged: _scheduleTimelineReload,
                  onCheckpointChanged: (value) =>
                      setState(() => _selectedCheckpointId = value),
                  onRefreshUploadContext: _loadUploadContext,
                  onPickGallery: _pickGallery,
                  onPickCamera: _pickCamera,
                  onRecordVideo: _recordVideo,
                  onRemoveSelectedFile: _removeSelectedFileAt,
                  onClearSelectedFiles: () =>
                      setState(() => _selectedFiles = const []),
                  onUpload: _uploadSelectedFile,
                ),
              ),
              if (isWaiting)
                const SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (items.isEmpty)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(
                        _filter == 'MY_CHILD' &&
                                _linkedStudentId == null &&
                                _studentFilterName.isEmpty
                            ? 'Nhập tên học sinh để tìm ảnh đã được InsightFace nhận diện.'
                            : 'Chưa có ảnh nào trong chuyến đi này.',
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.all(16),
                  sliver: SliverGrid.builder(
                    gridDelegate:
                        const SliverGridDelegateWithMaxCrossAxisExtent(
                          maxCrossAxisExtent: 240,
                          mainAxisSpacing: 12,
                          crossAxisSpacing: 12,
                          childAspectRatio: 0.78,
                        ),
                    itemCount: items.length,
                    itemBuilder: (context, index) => _MediaTile(
                      item: items[index],
                      onTap: () => _openMediaDetail(items[index]),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

class _Toolbar extends StatelessWidget {
  const _Toolbar({
    required this.filters,
    required this.selected,
    required this.tourIdController,
    required this.activityIdFilterController,
    required this.studentNameController,
    required this.searchController,
    required this.captionController,
    required this.linkedStudentName,
    required this.hasLinkedStudent,
    required this.uploadsEnabled,
    required this.myChildFilterLabel,
    required this.selectedFiles,
    required this.checkpoints,
    required this.selectedCheckpointId,
    required this.uploading,
    required this.loadingUploadContext,
    required this.onFilterChanged,
    required this.onStudentChanged,
    required this.onSearchChanged,
    required this.onTourChanged,
    required this.onActivityFilterChanged,
    required this.onCheckpointChanged,
    required this.onRefreshUploadContext,
    required this.onPickGallery,
    required this.onPickCamera,
    required this.onRecordVideo,
    required this.onRemoveSelectedFile,
    required this.onClearSelectedFiles,
    required this.onUpload,
  });

  final List<String> filters;
  final String selected;
  final TextEditingController tourIdController;
  final TextEditingController activityIdFilterController;
  final TextEditingController studentNameController;
  final TextEditingController searchController;
  final TextEditingController captionController;
  final String? linkedStudentName;
  final bool hasLinkedStudent;
  final bool uploadsEnabled;
  final String myChildFilterLabel;
  final List<_SelectedMediaFile> selectedFiles;
  final List<AttendanceCheckpoint> checkpoints;
  final String? selectedCheckpointId;
  final bool uploading;
  final bool loadingUploadContext;
  final ValueChanged<String> onFilterChanged;
  final VoidCallback onStudentChanged;
  final VoidCallback onSearchChanged;
  final VoidCallback onTourChanged;
  final VoidCallback onActivityFilterChanged;
  final ValueChanged<String?> onCheckpointChanged;
  final VoidCallback onRefreshUploadContext;
  final VoidCallback onPickGallery;
  final VoidCallback onPickCamera;
  final VoidCallback onRecordVideo;
  final ValueChanged<int> onRemoveSelectedFile;
  final VoidCallback onClearSelectedFiles;
  final VoidCallback onUpload;

  String _filterLabel(String filter) => switch (filter) {
    'ALL' => 'Tất cả',
    'MY_CHILD' => myChildFilterLabel,
    'PHOTOS' => 'Ảnh',
    'VIDEOS' => 'Video',
    _ => filter,
  };

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        border: Border.all(color: AppTheme.neutral200),
        boxShadow: AppTheme.shadowSm,
      ),
      child: Column(
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: filters
                  .map(
                    (filter) => ChoiceChip(
                      label: Text(_filterLabel(filter)),
                      selected: selected == filter,
                      selectedColor: AppTheme.primary,
                      backgroundColor: AppTheme.primarySoft,
                      labelStyle: TextStyle(
                        color: selected == filter
                            ? Colors.white
                            : AppTheme.primary,
                        fontWeight: FontWeight.w700,
                      ),
                      side: BorderSide.none,
                      onSelected: (_) => onFilterChanged(filter),
                    ),
                  )
                  .toList(),
            ),
          ),
          if (selected == 'MY_CHILD' &&
              hasLinkedStudent &&
              linkedStudentName != null) ...[
            const SizedBox(height: 10),
            Align(
              alignment: Alignment.centerLeft,
              child: Chip(
                avatar: const Icon(Icons.verified_user_outlined, size: 18),
                label: Text(linkedStudentName!),
              ),
            ),
          ],
          if (selected == 'MY_CHILD' && !hasLinkedStudent) ...[
            const SizedBox(height: 10),
            TextField(
              controller: studentNameController,
              decoration: const InputDecoration(
                labelText: 'Tên học sinh',
                helperText:
                    'Tự tìm trong các ảnh đã được InsightFace nhận diện.',
                prefixIcon: Icon(Icons.face_retouching_natural_outlined),
                suffixIcon: Icon(Icons.search_rounded),
              ),
              onChanged: (_) => onStudentChanged(),
              onSubmitted: (_) => onStudentChanged(),
            ),
          ],
          const SizedBox(height: 10),
          TextField(
            controller: searchController,
            decoration: const InputDecoration(
              labelText: 'Tìm media',
              prefixIcon: Icon(Icons.search_rounded),
            ),
            onChanged: (_) => onSearchChanged(),
          ),
          const SizedBox(height: 6),
          Theme(
            data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
            child: ExpansionTile(
              tilePadding: EdgeInsets.zero,
              childrenPadding: const EdgeInsets.only(top: 4, bottom: 4),
              iconColor: AppTheme.primary,
              collapsedIconColor: AppTheme.onSurfaceVariant,
              leading: const Icon(Icons.tune_rounded),
              title: const Text('Bộ lọc & gắn thẻ nâng cao'),
              subtitle: Text(
                'Tour, hoạt động, checkpoint và chú thích media',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppTheme.onSurfaceVariant,
                ),
              ),
              children: [
                TextField(
                  controller: tourIdController,
                  decoration: const InputDecoration(
                    labelText: 'Tour ID',
                    prefixIcon: Icon(Icons.route_outlined),
                  ),
                  onChanged: (_) => onTourChanged(),
                  onSubmitted: (_) => onTourChanged(),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: activityIdFilterController,
                  decoration: const InputDecoration(
                    labelText: 'Activity ID',
                    prefixIcon: Icon(Icons.directions_run_outlined),
                  ),
                  onChanged: (_) => onActivityFilterChanged(),
                  onSubmitted: (_) => onActivityFilterChanged(),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: captionController,
                  decoration: const InputDecoration(
                    labelText: 'Chú thích media',
                    prefixIcon: Icon(Icons.notes_rounded),
                  ),
                ),
                const SizedBox(height: 10),
                DropdownButtonFormField<String>(
                  isExpanded: true,
                  initialValue:
                      selectedCheckpointId != null &&
                          checkpoints.any(
                            (checkpoint) =>
                                checkpoint.checkpointId == selectedCheckpointId,
                          )
                      ? selectedCheckpointId
                      : null,
                  decoration: InputDecoration(
                    labelText: 'Checkpoint',
                    prefixIcon: loadingUploadContext
                        ? const Padding(
                            padding: EdgeInsets.all(12),
                            child: SizedBox.square(
                              dimension: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                          )
                        : const Icon(Icons.place_outlined),
                  ),
                  items: checkpoints
                      .map(
                        (checkpoint) => DropdownMenuItem(
                          value: checkpoint.checkpointId,
                          child: Text(
                            '${checkpoint.sortOrder + 1}. ${checkpoint.name}',
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      )
                      .toList(),
                  onChanged: uploading || loadingUploadContext
                      ? null
                      : onCheckpointChanged,
                ),
                const SizedBox(height: 10),
                Align(
                  alignment: Alignment.centerRight,
                  child: IconButton.outlined(
                    tooltip: 'Tải lại checkpoint',
                    onPressed: uploading || loadingUploadContext
                        ? null
                        : onRefreshUploadContext,
                    icon: loadingUploadContext
                        ? const SizedBox.square(
                            dimension: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.refresh_rounded),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 4),
          if (!uploadsEnabled) ...[
            Container(
              width: double.infinity,
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.neutral100,
                borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                border: Border.all(color: AppTheme.neutral200),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.lock_outline_rounded,
                    size: 20,
                    color: AppTheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Tour đã hoàn tất — thư viện chỉ xem. Không thể chụp ảnh, quay video hay tải media mới.',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppTheme.onSurfaceVariant,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
          if (selectedFiles.isNotEmpty && uploadsEnabled) ...[
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Đã chọn ${selectedFiles.length} mục',
                    style: Theme.of(context).textTheme.labelLarge,
                  ),
                ),
                TextButton.icon(
                  onPressed: uploading ? null : onClearSelectedFiles,
                  icon: const Icon(Icons.delete_outline_rounded, size: 18),
                  label: const Text('Xóa tất cả'),
                ),
              ],
            ),
            const SizedBox(height: 4),
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 220),
              child: ListView.separated(
                shrinkWrap: true,
                itemCount: selectedFiles.length,
                separatorBuilder: (_, _) => const SizedBox(height: 8),
                itemBuilder: (context, index) => _SelectedMediaPreview(
                  file: selectedFiles[index],
                  // Mỗi thẻ chỉ bỏ đúng mục của nó; trước đây nút X xoá sạch cả danh sách.
                  onClear: uploading ? null : () => onRemoveSelectedFile(index),
                ),
              ),
            ),
            const SizedBox(height: 10),
          ],
          if (uploadsEnabled) ...[
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: uploading ? null : onPickGallery,
                    icon: const Icon(Icons.photo_library_outlined),
                    label: const Text('Thư viện'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: uploading ? null : onPickCamera,
                    icon: const Icon(Icons.photo_camera_outlined),
                    label: const Text('Chụp ảnh'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: uploading ? null : onRecordVideo,
                icon: const Icon(Icons.videocam_outlined),
                label: const Text('Quay video'),
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: uploading || selectedFiles.isEmpty ? null : onUpload,
                icon: uploading
                    ? const SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.cloud_upload_outlined),
                label: Text(
                  uploading
                      ? 'Đang tải ${selectedFiles.length} mục...'
                      : selectedFiles.isEmpty
                      ? 'Tải media lên'
                      : 'Tải lên ${selectedFiles.length} mục',
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _SelectedMediaFile {
  const _SelectedMediaFile({
    required this.path,
    required this.name,
    required this.isVideo,
  });

  final String path;
  final String name;
  final bool isVideo;
}

class _SelectedMediaPreview extends StatelessWidget {
  const _SelectedMediaPreview({required this.file, required this.onClear});

  final _SelectedMediaFile file;
  final VoidCallback? onClear;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: Stack(
        children: [
          AspectRatio(
            aspectRatio: 16 / 9,
            child: file.isVideo
                ? ColoredBox(
                    color: Colors.black12,
                    child: Center(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.play_circle_outline_rounded,
                              size: 48,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              file.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                    ),
                  )
                : Image.file(
                    File(file.path),
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) =>
                        const ColoredBox(
                          color: Colors.black12,
                          child: Center(
                            child: Icon(Icons.broken_image_outlined),
                          ),
                        ),
                  ),
          ),
          Positioned(
            right: 8,
            top: 8,
            child: IconButton.filledTonal(
              tooltip: 'Bỏ media đã chọn',
              onPressed: onClear,
              icon: const Icon(Icons.close_rounded),
            ),
          ),
        ],
      ),
    );
  }
}

class _MediaDetailSheet extends ConsumerStatefulWidget {
  const _MediaDetailSheet({required this.item});

  final TourMediaItem item;

  @override
  ConsumerState<_MediaDetailSheet> createState() => _MediaDetailSheetState();
}

class _MediaDetailSheetState extends ConsumerState<_MediaDetailSheet> {
  final _commentController = TextEditingController();
  late TourMediaItem _item;
  bool _savingLike = false;
  bool _savingComment = false;

  @override
  void initState() {
    super.initState();
    _item = widget.item;
  }

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  Future<void> _toggleLike() async {
    if (_savingLike) return;
    setState(() => _savingLike = true);
    try {
      final updated = await ref
          .read(mediaRemoteDataSourceProvider)
          .toggleLike(mediaId: _item.id);
      if (!mounted) return;
      setState(() => _item = updated);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Không cập nhật được lượt thích.')),
      );
    } finally {
      if (mounted) setState(() => _savingLike = false);
    }
  }

  Future<void> _addComment() async {
    final content = _commentController.text.trim();
    if (content.isEmpty || _savingComment) return;
    setState(() => _savingComment = true);
    try {
      final updated = await ref
          .read(mediaRemoteDataSourceProvider)
          .addComment(mediaId: _item.id, content: content);
      if (!mounted) return;
      _commentController.clear();
      FocusScope.of(context).unfocus();
      setState(() => _item = updated);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Không lưu được bình luận.')),
      );
    } finally {
      if (mounted) setState(() => _savingComment = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isVideo = _item.mediaType.toUpperCase() == 'VIDEO';
    final imageUrl = resolveMediaUrl(_item.fileUrl);
    final title = _item.caption?.trim().isNotEmpty == true
        ? _item.caption!.trim()
        : isVideo
        ? 'Video chuyến đi'
        : 'Ảnh chuyến đi';
    final interactions = _item.interactions;
    return SizedBox(
      height: MediaQuery.of(context).size.height * 0.94,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 6, 8),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                IconButton(
                  tooltip: 'Đóng',
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close_rounded, color: Colors.white),
                ),
              ],
            ),
          ),
          Expanded(
            child: isVideo
                ? const Center(
                    child: Icon(
                      Icons.play_circle_outline_rounded,
                      color: Colors.white70,
                      size: 72,
                    ),
                  )
                : _FaceOverlayImage(url: imageUrl, matches: _item.faceMatches),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 6),
            child: Row(
              children: [
                FilledButton.tonalIcon(
                  onPressed: _savingLike ? null : _toggleLike,
                  icon: _savingLike
                      ? const SizedBox.square(
                          dimension: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Icon(
                          interactions.likedByCurrentUser
                              ? Icons.favorite_rounded
                              : Icons.favorite_border_rounded,
                        ),
                  label: Text('${interactions.likeCount}'),
                ),
                const SizedBox(width: 10),
                Icon(
                  Icons.mode_comment_outlined,
                  color: Colors.white.withValues(alpha: 0.72),
                  size: 20,
                ),
                const SizedBox(width: 6),
                Text(
                  '${interactions.commentCount}',
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: Colors.white.withValues(alpha: 0.86),
                  ),
                ),
              ],
            ),
          ),
          if (_item.faceMatches.isNotEmpty)
            Flexible(
              flex: 0,
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
                child: Row(
                  children: _item.faceMatches
                      .map(
                        (match) => Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: Chip(
                            side: BorderSide(
                              color: _faceBoxColor(match.matchStatus),
                            ),
                            label: Text(_matchLabel(match)),
                          ),
                        ),
                      )
                      .toList(),
                ),
              ),
            ),
          _MediaCommentsPanel(
            comments: interactions.comments,
            controller: _commentController,
            saving: _savingComment,
            onSubmit: _addComment,
          ),
        ],
      ),
    );
  }
}

class _MediaCommentsPanel extends StatelessWidget {
  const _MediaCommentsPanel({
    required this.comments,
    required this.controller,
    required this.saving,
    required this.onSubmit,
  });

  final List<TourMediaComment> comments;
  final TextEditingController controller;
  final bool saving;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.06),
        border: Border(
          top: BorderSide(color: Colors.white.withValues(alpha: 0.12)),
        ),
      ),
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          12,
          10,
          12,
          10 + MediaQuery.of(context).viewInsets.bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 150),
              child: comments.isEmpty
                  ? Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Text(
                        'Chưa có bình luận',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Colors.white.withValues(alpha: 0.64),
                        ),
                      ),
                    )
                  : ListView.separated(
                      shrinkWrap: true,
                      itemCount: comments.length,
                      separatorBuilder: (_, _) => Divider(
                        color: Colors.white.withValues(alpha: 0.10),
                        height: 12,
                      ),
                      itemBuilder: (context, index) {
                        final comment = comments[index];
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              comment.content,
                              style: Theme.of(context).textTheme.bodyMedium
                                  ?.copyWith(color: Colors.white),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              comment.accountId,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context).textTheme.bodySmall
                                  ?.copyWith(
                                    color: Colors.white.withValues(alpha: 0.56),
                                  ),
                            ),
                          ],
                        );
                      },
                    ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: controller,
                    minLines: 1,
                    maxLines: 3,
                    maxLength: 500,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      counterText: '',
                      hintText: 'Them binh luan',
                      hintStyle: TextStyle(
                        color: Colors.white.withValues(alpha: 0.52),
                      ),
                      filled: true,
                      fillColor: Colors.white.withValues(alpha: 0.10),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide.none,
                      ),
                    ),
                    textInputAction: TextInputAction.send,
                    onSubmitted: (_) => onSubmit(),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton.filledTonal(
                  tooltip: 'Gui binh luan',
                  onPressed: saving ? null : onSubmit,
                  icon: saving
                      ? const SizedBox.square(
                          dimension: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.send_rounded),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _FaceOverlayImage extends StatefulWidget {
  const _FaceOverlayImage({required this.url, required this.matches});

  final String url;
  final List<TourMediaFaceMatch> matches;

  @override
  State<_FaceOverlayImage> createState() => _FaceOverlayImageState();
}

class _FaceOverlayImageState extends State<_FaceOverlayImage> {
  ImageStream? _stream;
  ImageStreamListener? _listener;
  Size? _imageSize;

  @override
  void initState() {
    super.initState();
    _resolveImage();
  }

  @override
  void didUpdateWidget(covariant _FaceOverlayImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.url != widget.url) {
      _resolveImage();
    }
  }

  @override
  void dispose() {
    final listener = _listener;
    if (listener != null) {
      _stream?.removeListener(listener);
    }
    super.dispose();
  }

  void _resolveImage() {
    final listener = _listener;
    if (listener != null) {
      _stream?.removeListener(listener);
    }
    if (!isViewableMediaUrl(widget.url)) {
      setState(() => _imageSize = null);
      _stream = null;
      _listener = null;
      return;
    }
    final provider = NetworkImage(widget.url);
    final stream = provider.resolve(const ImageConfiguration());
    final nextListener = ImageStreamListener((info, _) {
      if (!mounted) return;
      setState(() {
        _imageSize = Size(
          info.image.width.toDouble(),
          info.image.height.toDouble(),
        );
      });
    });
    _stream = stream;
    _listener = nextListener;
    stream.addListener(nextListener);
  }

  @override
  Widget build(BuildContext context) {
    if (!isViewableMediaUrl(widget.url)) {
      return const _ImageFallback(color: Colors.white70);
    }
    return InteractiveViewer(
      minScale: 1,
      maxScale: 4,
      child: Stack(
        fit: StackFit.expand,
        children: [
          Image.network(
            widget.url,
            fit: BoxFit.contain,
            loadingBuilder: (context, child, progress) {
              if (progress == null) return child;
              return const _ImageLoading(color: Colors.white70);
            },
            errorBuilder: (context, error, stackTrace) =>
                const _ImageFallback(color: Colors.white70),
          ),
          if (_imageSize != null)
            CustomPaint(
              painter: _FaceBoxPainter(
                matches: widget.matches,
                imageSize: _imageSize!,
              ),
            ),
        ],
      ),
    );
  }
}

class _FaceBoxPainter extends CustomPainter {
  const _FaceBoxPainter({required this.matches, required this.imageSize});

  final List<TourMediaFaceMatch> matches;
  final Size imageSize;

  @override
  void paint(Canvas canvas, Size size) {
    final fitted = applyBoxFit(BoxFit.contain, imageSize, size);
    final output = Alignment.center.inscribe(
      fitted.destination,
      Offset.zero & size,
    );
    for (final match in matches) {
      final normalized = _parseFaceBox(match.boundingBox, imageSize);
      if (normalized == null) continue;
      final color = _faceBoxColor(match.matchStatus);
      final rect = Rect.fromLTRB(
        output.left + normalized.left * output.width,
        output.top + normalized.top * output.height,
        output.left + normalized.right * output.width,
        output.top + normalized.bottom * output.height,
      );
      final paint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..color = color;
      canvas.drawRRect(
        RRect.fromRectAndRadius(rect, const Radius.circular(10)),
        paint,
      );
      _drawLabel(canvas, size, rect, match, color);
    }
  }

  void _drawLabel(
    Canvas canvas,
    Size size,
    Rect rect,
    TourMediaFaceMatch match,
    Color color,
  ) {
    final label = _matchLabel(match);
    final span = TextSpan(
      text: label,
      style: const TextStyle(
        color: Colors.white,
        fontSize: 12,
        fontWeight: FontWeight.w800,
      ),
    );
    final painter = TextPainter(
      text: span,
      maxLines: 1,
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: size.width * 0.72);
    final labelSize = Size(painter.width + 16, painter.height + 8);
    final hasTopRoom = rect.top >= labelSize.height + 6;
    final dy = hasTopRoom ? rect.top - labelSize.height - 6 : rect.bottom + 6;
    final left = rect.left.clamp(6.0, size.width - labelSize.width - 6);
    final top = dy.clamp(6.0, size.height - labelSize.height - 6);
    final background = RRect.fromRectAndRadius(
      Rect.fromLTWH(left, top, labelSize.width, labelSize.height),
      const Radius.circular(8),
    );
    canvas.drawRRect(
      background,
      Paint()..color = color.withValues(alpha: 0.92),
    );
    painter.paint(canvas, Offset(left + 8, top + 4));
  }

  @override
  bool shouldRepaint(covariant _FaceBoxPainter oldDelegate) {
    return oldDelegate.matches != matches || oldDelegate.imageSize != imageSize;
  }
}

class _MediaTile extends StatelessWidget {
  const _MediaTile({required this.item, required this.onTap});

  final TourMediaItem item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final bestMatch = item.faceMatches.isEmpty ? null : item.faceMatches.first;
    final imageUrl = resolveMediaUrl(item.fileUrl);
    return Material(
      color: AppTheme.surfaceLowest,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: AppTheme.outlineVariant),
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: item.mediaType == 'VIDEO'
                    ? const ColoredBox(
                        color: Colors.black12,
                        child: Icon(
                          Icons.play_circle_outline_rounded,
                          size: 48,
                        ),
                      )
                    : isViewableMediaUrl(imageUrl)
                    ? Image.network(
                        imageUrl,
                        fit: BoxFit.cover,
                        loadingBuilder: (context, child, progress) {
                          if (progress == null) return child;
                          return const _ImageLoading();
                        },
                        errorBuilder: (context, error, stackTrace) =>
                            const _ImageFallback(),
                      )
                    : const _ImageFallback(),
              ),
              Padding(
                padding: const EdgeInsets.all(10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.caption?.isNotEmpty == true
                          ? item.caption!
                          : item.mediaType == 'VIDEO'
                          ? 'Video chuyến đi'
                          : 'Ảnh chuyến đi',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.labelLarge,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      bestMatch == null
                          ? _faceStatusLabel(item.faceProcessingStatus)
                          : '${bestMatch.studentDisplayName ?? bestMatch.studentId} ${(bestMatch.confidence * 100).round()}%',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppTheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Icon(
                          item.interactions.likedByCurrentUser
                              ? Icons.favorite_rounded
                              : Icons.favorite_border_rounded,
                          size: 16,
                          color: item.interactions.likedByCurrentUser
                              ? AppTheme.accentRed
                              : AppTheme.onSurfaceVariant,
                        ),
                        const SizedBox(width: 3),
                        Text(
                          '${item.interactions.likeCount}',
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(color: AppTheme.onSurfaceVariant),
                        ),
                        const SizedBox(width: 10),
                        const Icon(
                          Icons.mode_comment_outlined,
                          size: 16,
                          color: AppTheme.onSurfaceVariant,
                        ),
                        const SizedBox(width: 3),
                        Text(
                          '${item.interactions.commentCount}',
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(color: AppTheme.onSurfaceVariant),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _faceStatusLabel(String status) => switch (status) {
    'PROCESSING' => 'Đang phân loại khuôn mặt',
    'COMPLETED' => 'Đã phân loại khuôn mặt',
    'FAILED' => 'Không phân loại được khuôn mặt',
    _ => 'Chưa yêu cầu phân loại',
  };
}

class _ImageLoading extends StatelessWidget {
  const _ImageLoading({this.color});

  final Color? color;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: Colors.black12,
      child: Center(
        child: SizedBox.square(
          dimension: 22,
          child: CircularProgressIndicator(strokeWidth: 2, color: color),
        ),
      ),
    );
  }
}

class _ImageFallback extends StatelessWidget {
  const _ImageFallback({this.color});

  final Color? color;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: Colors.black12,
      child: Center(child: Icon(Icons.broken_image_outlined, color: color)),
    );
  }
}

Color _faceBoxColor(String status) => switch (status) {
  'MATCHED' => AppTheme.accentGreen,
  'LOW_CONFIDENCE' => AppTheme.accentOrange,
  _ => Colors.white70,
};

String _matchLabel(TourMediaFaceMatch match) {
  final name = match.studentDisplayName?.trim().isNotEmpty == true
      ? match.studentDisplayName!.trim()
      : match.studentId?.trim().isNotEmpty == true
      ? match.studentId!.trim()
      : 'Unknown';
  final confidence = match.confidence > 0
      ? ' ${(match.confidence * 100).round()}%'
      : '';
  return '$name$confidence';
}

Rect? _parseFaceBox(String? value, Size imageSize) {
  final raw = _parseRawFaceBox(value);
  if (raw == null) return null;
  final values = [raw.left, raw.top, raw.right, raw.bottom];
  final isNormalized = values.every((item) => item >= 0 && item <= 1);
  final imageWidth = isNormalized ? 1.0 : imageSize.width;
  final imageHeight = isNormalized ? 1.0 : imageSize.height;
  if (imageWidth <= 0 || imageHeight <= 0) return null;

  final rawLeft = raw.left < raw.right ? raw.left : raw.right;
  final rawTop = raw.top < raw.bottom ? raw.top : raw.bottom;
  final rawRight = raw.left > raw.right ? raw.left : raw.right;
  final rawBottom = raw.top > raw.bottom ? raw.top : raw.bottom;
  final clampedLeft = rawLeft.clamp(0.0, imageWidth).toDouble();
  final clampedTop = rawTop.clamp(0.0, imageHeight).toDouble();
  final clampedRight = rawRight.clamp(0.0, imageWidth).toDouble();
  final clampedBottom = rawBottom.clamp(0.0, imageHeight).toDouble();
  final rawWidth = clampedRight - clampedLeft;
  final rawHeight = clampedBottom - clampedTop;
  if (rawWidth <= 0 || rawHeight <= 0) return null;

  final horizontalPadding = rawWidth * 0.22 > imageWidth * 0.008
      ? rawWidth * 0.22
      : imageWidth * 0.008;
  final verticalPadding = rawHeight * 0.22 > imageHeight * 0.01
      ? rawHeight * 0.22
      : imageHeight * 0.01;
  final left = (clampedLeft - horizontalPadding)
      .clamp(0.0, imageWidth)
      .toDouble();
  final top = (clampedTop - verticalPadding).clamp(0.0, imageHeight).toDouble();
  final right = (clampedRight + horizontalPadding)
      .clamp(0.0, imageWidth)
      .toDouble();
  final bottom = (clampedBottom + verticalPadding)
      .clamp(0.0, imageHeight)
      .toDouble();
  if (right <= left || bottom <= top) return null;

  return Rect.fromLTRB(
    left / imageWidth,
    top / imageHeight,
    right / imageWidth,
    bottom / imageHeight,
  );
}

Rect? _parseRawFaceBox(String? value) {
  if (value == null || value.trim().isEmpty) return null;
  final trimmed = value.trim();
  Object? parsed;
  try {
    parsed = jsonDecode(trimmed);
  } catch (_) {
    final numbers = RegExp(r'-?\d+(?:\.\d+)?')
        .allMatches(trimmed)
        .map((match) => double.tryParse(match.group(0)!))
        .toList();
    if (numbers.length < 4 || numbers.take(4).any((item) => item == null)) {
      return null;
    }
    parsed = numbers.take(4).cast<double>().toList();
  }

  if (parsed is List && parsed.length >= 4) {
    final first = _asDouble(parsed[0]);
    final second = _asDouble(parsed[1]);
    final third = _asDouble(parsed[2]);
    final fourth = _asDouble(parsed[3]);
    if (first == null || second == null || third == null || fourth == null) {
      return null;
    }
    if (third > first && fourth > second) {
      return Rect.fromLTRB(first, second, third, fourth);
    }
    return Rect.fromLTRB(first, second, first + third, second + fourth);
  }

  if (parsed is Map<String, dynamic>) {
    final left =
        _asDouble(parsed['x1']) ??
        _asDouble(parsed['left']) ??
        _asDouble(parsed['xMin']) ??
        _asDouble(parsed['x_min']) ??
        _asDouble(parsed['x']);
    final top =
        _asDouble(parsed['y1']) ??
        _asDouble(parsed['top']) ??
        _asDouble(parsed['yMin']) ??
        _asDouble(parsed['y_min']) ??
        _asDouble(parsed['y']);
    final right =
        _asDouble(parsed['x2']) ??
        _asDouble(parsed['right']) ??
        _asDouble(parsed['xMax']) ??
        _asDouble(parsed['x_max']);
    final bottom =
        _asDouble(parsed['y2']) ??
        _asDouble(parsed['bottom']) ??
        _asDouble(parsed['yMax']) ??
        _asDouble(parsed['y_max']);
    final width = _asDouble(parsed['width']) ?? _asDouble(parsed['w']);
    final height = _asDouble(parsed['height']) ?? _asDouble(parsed['h']);
    if (left == null || top == null) return null;
    if (right != null && bottom != null) {
      return Rect.fromLTRB(left, top, right, bottom);
    }
    if (width != null && height != null) {
      return Rect.fromLTRB(left, top, left + width, top + height);
    }
  }
  return null;
}

double? _asDouble(Object? value) {
  if (value is num) return value.toDouble();
  return double.tryParse(value?.toString() ?? '');
}

String _dateLabel(DateTime? value) {
  if (value == null) return '';
  final local = value.toLocal();
  return '${local.day.toString().padLeft(2, '0')}/${local.month.toString().padLeft(2, '0')}/${local.year}';
}

String? _keepOrFirst(String? current, Iterable<String> values) {
  final list = values.where((value) => value.isNotEmpty).toList();
  if (current != null && list.contains(current)) return current;
  return list.isEmpty ? null : list.first;
}

bool _isValidUuid(String value) {
  return RegExp(
    r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
  ).hasMatch(value);
}

bool _isZeroUuid(String value) {
  return value.toLowerCase() == '00000000-0000-0000-0000-000000000000';
}
