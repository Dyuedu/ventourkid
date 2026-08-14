import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

import '../../../../app/providers.dart';
import '../../../../features/attendance/domain/entities/offline_attendance.dart';
import '../../../../features/media/domain/entities/tour_media_item.dart';
import '../../../../shared/theme/app_theme.dart';
import '../../../../shared/utils/media_url.dart';
import '../../../../shared/widgets/app_back_leading.dart';
import '../../domain/entities/newsfeed_item.dart';

enum _NewsfeedFilter { all, media, blog }

class NewsfeedPage extends ConsumerStatefulWidget {
  const NewsfeedPage({
    super.key,
    this.tourId,
    this.title,
    this.actorLabel,
    this.studentId,
    this.studentName,
  });

  final String? tourId;
  final String? title;
  final String? actorLabel;
  final String? studentId;
  final String? studentName;

  @override
  ConsumerState<NewsfeedPage> createState() => _NewsfeedPageState();
}

class _NewsfeedPageState extends ConsumerState<NewsfeedPage> {
  List<NewsfeedItem> _items = const [];
  bool _loading = true;
  bool _loadFailed = false;
  _NewsfeedFilter _filter = _NewsfeedFilter.all;
  AttendanceStudent? _selectedStudent;
  String? _mediaError;
  List<AttendanceCheckpoint> _checkpoints = const [];
  String? _selectedCheckpointId;

  /// Chỉ giáo viên và hướng dẫn viên được tra cứu media của mọi học sinh trong tour;
  /// phụ huynh bị backend giới hạn ở chính con mình (MED-022) nên không hiện ô chọn.
  bool _canSearchAllStudents = false;

  bool get _hasTourId => widget.tourId != null && widget.tourId!.isNotEmpty;

  /// Học sinh do luồng gọi trang truyền vào (phụ huynh xem con mình) — không đổi được.
  bool get _hasLockedStudent =>
      widget.studentId?.trim().isNotEmpty == true ||
      widget.studentName?.trim().isNotEmpty == true;

  /// Giáo viên/hướng dẫn viên tự chọn học sinh trong tour để lọc ảnh.
  bool get _canPickStudent =>
      _hasTourId && !_hasLockedStudent && _canSearchAllStudents;

  bool get _hasMediaFilter => _selectedCheckpointId != null;

  String? get _filterStudentId =>
      _selectedStudent?.rosterStudentId ?? widget.studentId;

  String? get _filterStudentName =>
      _selectedStudent == null ? widget.studentName : null;

  bool get _hasChildFilter =>
      _filterStudentId?.trim().isNotEmpty == true ||
      _filterStudentName?.trim().isNotEmpty == true;

  @override
  void initState() {
    super.initState();
    Future.microtask(_reload);
    Future.microtask(_loadActorScope);
    if (_hasTourId) {
      Future.microtask(_loadFilterOptions);
    }
  }

  Future<void> _loadActorScope() async {
    final role = await ref.read(routeGuardsProvider).userRole;
    if (!mounted) return;
    setState(() {
      _canSearchAllStudents = role == 'TEACHER' || role == 'TOUR_GUIDE';
    });
  }

  /// Checkpoint lấy từ lịch trình trên server; hoạt động di chuyển là bản ghi cục bộ
  /// mà thiết bị đã tag khi upload, nên có thể rỗng và khi đó dropdown được ẩn.
  Future<void> _loadFilterOptions() async {
    final repository = ref.read(offlineAttendanceRepositoryProvider);
    final tourId = widget.tourId!;
    var checkpoints = const <AttendanceCheckpoint>[];
    try {
      checkpoints = await repository.getCachedCheckpoints(tourId);
    } on Object catch (_) {
      // Không có cache thì chờ refresh bên dưới.
    }
    try {
      checkpoints = await repository.refreshCheckpoints(tourId);
    } on Object catch (_) {
      // Offline: dùng checkpoint đã cache.
    }
    if (!mounted) return;
    setState(() {
      _checkpoints = checkpoints;
      if (_selectedCheckpointId != null &&
          !checkpoints.any(
            (checkpoint) => checkpoint.checkpointId == _selectedCheckpointId,
          )) {
        _selectedCheckpointId = null;
      }
    });
  }

  Future<void> _reload() async {
    setState(() {
      _loading = true;
      _loadFailed = false;
    });
    try {
      final items = await _load();
      if (!mounted) return;
      setState(() {
        _items = items;
        _loading = false;
      });
    } on Object catch (_) {
      if (!mounted) return;
      setState(() {
        _loadFailed = true;
        _loading = false;
      });
    }
  }

  Future<List<NewsfeedItem>> _load() async {
    _mediaError = null;
    final mediaOnly = _hasChildFilter || _hasMediaFilter;
    final mediaFuture = _hasTourId
        ? _loadMedia()
        : Future<List<NewsfeedItem>>.value(const []);
    // Đang lọc media (học sinh/checkpoint/hoạt động) thì không trộn blog vào kết quả.
    final blogFuture = mediaOnly
        ? Future<List<NewsfeedItem>>.value(const [])
        : ref
              .read(newsfeedRemoteDataSourceProvider)
              .listPublishedBlogs()
              .then((posts) => posts.map((post) => post.toFeedItem()).toList())
              .catchError((_) => <NewsfeedItem>[]);

    final results = await Future.wait([mediaFuture, blogFuture]);
    final items = [...results[0], ...results[1]];
    items.sort((left, right) {
      final leftDate =
          left.publishedAt ?? DateTime.fromMillisecondsSinceEpoch(0);
      final rightDate =
          right.publishedAt ?? DateTime.fromMillisecondsSinceEpoch(0);
      return rightDate.compareTo(leftDate);
    });
    return items;
  }

  Future<List<NewsfeedItem>> _loadMedia() async {
    try {
      final items = await ref
          .read(mediaRemoteDataSourceProvider)
          .getTimeline(
            tourId: widget.tourId!,
            filter: _hasChildFilter ? 'MY_CHILD' : 'ALL',
            studentId: _filterStudentId,
            studentName: _filterStudentName,
            checkpointId: _selectedCheckpointId,
          );
      return items.map(NewsfeedItem.fromMedia).toList();
    } on Object catch (error) {
      _mediaError = _mediaErrorMessage(error);
      return const [];
    }
  }

  String _mediaErrorMessage(Object error) {
    if (error is! DioException) {
      return 'Chưa tải được ảnh chuyến đi. Kéo xuống để thử lại.';
    }
    final body = error.response?.data;
    final code = body is Map ? body['code']?.toString() : null;
    switch (code) {
      case 'MED-022':
        // Client hiện ô chọn học sinh theo role, backend lại chặn theo permission —
        // hai thứ này lệch nhau khi tài khoản chưa được cấp MEDIA_SEARCH_ALL_STUDENTS.
        return _canSearchAllStudents
            ? 'Tài khoản chưa được cấp quyền tìm media của mọi học sinh trong tour '
                  '(MEDIA_SEARCH_ALL_STUDENTS). Liên hệ quản trị viên để được cấp quyền.'
            : 'Bạn chỉ có thể tìm ảnh của con mình trong chuyến đi này.';
      case 'MED-023':
        return 'Bạn có nhiều con trong chuyến đi này, hãy chọn đúng một em để xem ảnh.';
      case 'MED-AUTHZ-001':
        return 'Ảnh của học sinh này chỉ hiển thị khi phụ huynh đã ủy quyền sử dụng '
            'hình ảnh cho chuyến đi.';
    }
    if (error.response?.statusCode == 403) {
      return _hasChildFilter
          ? 'Chưa được phép xem ảnh của học sinh này.'
          : 'Tài khoản chưa có quyền xem ảnh chuyến đi.';
    }
    return 'Chưa tải được ảnh chuyến đi. Kéo xuống để thử lại.';
  }

  Future<void> _refresh() => _reload();

  Future<void> _pickStudent() async {
    final selected = await showModalBottomSheet<AttendanceStudent>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: AppTheme.surfaceLowest,
      builder: (context) => _StudentPickerSheet(tourId: widget.tourId!),
    );
    if (!mounted || selected == null) return;
    setState(() {
      _selectedStudent = selected;
      _filter = _NewsfeedFilter.media;
    });
    unawaited(_reload());
  }

  void _clearStudent() {
    setState(() {
      _selectedStudent = null;
      if (!_hasMediaFilter) _filter = _NewsfeedFilter.all;
    });
    unawaited(_reload());
  }

  void _setCheckpoint(String? checkpointId) {
    setState(() {
      _selectedCheckpointId = checkpointId;
      if (checkpointId != null) _filter = _NewsfeedFilter.media;
    });
    unawaited(_reload());
  }

  void _resetFilters() {
    setState(() {
      _selectedStudent = null;
      _selectedCheckpointId = null;
      _filter = _NewsfeedFilter.all;
    });
    unawaited(_reload());
  }

  /// Thay bản ghi trong danh sách đang hiển thị bằng bản mới server trả về,
  /// không tải lại cả feed để tránh nhảy vị trí cuộn.
  void _replaceItem(NewsfeedItem updated) {
    setState(() {
      _items = _items
          .map((item) => item.id == updated.id ? updated : item)
          .toList();
    });
  }

  Future<NewsfeedItem> _sendToggleLike(NewsfeedItem item) async {
    if (item.kind == NewsfeedItemKind.media) {
      final media = await ref
          .read(mediaRemoteDataSourceProvider)
          .toggleLike(mediaId: item.serverId);
      return item.copyWith(
        interactions: NewsfeedInteractions.fromMedia(media.interactions),
      );
    }
    final post = await ref
        .read(newsfeedRemoteDataSourceProvider)
        .toggleBlogLike(postId: item.serverId);
    return item.copyWith(interactions: post.interactions);
  }

  Future<NewsfeedItem> _sendComment(NewsfeedItem item, String text) async {
    if (item.kind == NewsfeedItemKind.media) {
      final media = await ref
          .read(mediaRemoteDataSourceProvider)
          .addComment(mediaId: item.serverId, content: text);
      return item.copyWith(
        interactions: NewsfeedInteractions.fromMedia(media.interactions),
      );
    }
    final post = await ref
        .read(newsfeedRemoteDataSourceProvider)
        .addBlogComment(postId: item.serverId, content: text);
    return item.copyWith(interactions: post.interactions);
  }

  Future<void> _toggleLike(NewsfeedItem item) async {
    try {
      final updated = await _sendToggleLike(item);
      if (!mounted) return;
      _replaceItem(updated);
    } on Object catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(content: Text('Không gửi được lượt thích.')),
        );
    }
  }

  Future<void> _shareItem(NewsfeedItem item) async {
    final urls = item.mediaAttachments
        .map((attachment) => resolveMediaUrl(attachment.url))
        .where((url) => url.isNotEmpty)
        .toList();
    if (urls.isEmpty && item.imageUrl != null) {
      final url = resolveMediaUrl(item.imageUrl!);
      if (url.isNotEmpty) urls.add(url);
    }
    await SharePlus.instance.share(
      ShareParams(
        subject: item.title,
        text: [
          item.title,
          if (item.body != null && item.body!.isNotEmpty) item.body!,
          ...urls,
        ].join('\n\n'),
      ),
    );
  }

  Future<void> _showComments(NewsfeedItem item) async {
    final updated = await showModalBottomSheet<NewsfeedItem>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: AppTheme.surfaceLowest,
      builder: (context) => _CommentsSheet(
        item: item,
        onSubmit: (text) => _sendComment(item, text),
      ),
    );
    if (!mounted || updated == null) return;
    _replaceItem(updated);
  }

  List<NewsfeedItem> _applyFilter(List<NewsfeedItem> items) {
    return switch (_filter) {
      _NewsfeedFilter.all => items,
      _NewsfeedFilter.media =>
        items.where((item) => item.kind == NewsfeedItemKind.media).toList(),
      _NewsfeedFilter.blog =>
        items.where((item) => item.kind == NewsfeedItemKind.blog).toList(),
    };
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.surfaceLight,
      appBar: AppBar(
        leading: buildAppBackLeading(
          context,
          fallbackRoute: '/parent/dashboard',
        ),
        title: Text(widget.title ?? 'Bảng tin'),
        backgroundColor: AppTheme.surface,
        elevation: 0,
      ),
      body: SafeArea(child: _buildBody()),
    );
  }

  Widget _buildBody() {
    if (_loading && _items.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    final items = _applyFilter(_items);
    return RefreshIndicator(
      onRefresh: _refresh,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
        children: [
          _NewsfeedTabs(
            selected: _filter,
            onChanged: (value) => setState(() => _filter = value),
          ),
          if (_hasTourId) ...[
            const SizedBox(height: 12),
            _MediaFilterPanel(
              checkpoints: _checkpoints,
              selectedCheckpointId: _selectedCheckpointId,
              student: _selectedStudent,
              canPickStudent: _canPickStudent,
              onCheckpointChanged: _setCheckpoint,
              onPickStudent: _pickStudent,
              onClearStudent: _clearStudent,
              onResetAll: _resetFilters,
            ),
          ],
          const SizedBox(height: 14),
          if (_loadFailed)
            const _FeedBanner(
              icon: Icons.wifi_off_outlined,
              text: 'Chưa tải được newsfeed. Kéo xuống để thử lại.',
            ),
          if (_mediaError != null)
            _FeedBanner(
              icon: Icons.no_photography_outlined,
              text: _mediaError!,
            ),
          if (!_hasTourId)
            const _FeedBanner(
              icon: Icons.info_outline_rounded,
              text: 'Chưa có tour đang hoạt động, đang hiển thị blog.',
            ),
          if (items.isEmpty && _selectedStudent != null)
            _FeedBanner(
              icon: Icons.face_retouching_natural_outlined,
              text:
                  'Chưa có ảnh nào nhận diện được ${_selectedStudent!.fullName} '
                  'trong chuyến đi này.',
            )
          else if (items.isEmpty)
            const _EmptyNewsfeed()
          else
            for (final item in items) ...[
              _NewsfeedCard(
                item: item,
                onLike: () => _toggleLike(item),
                onShare: () => _shareItem(item),
                onComment: () => _showComments(item),
              ),
              const SizedBox(height: 12),
            ],
        ],
      ),
    );
  }
}

class _MediaFilterPanel extends StatelessWidget {
  const _MediaFilterPanel({
    required this.checkpoints,
    required this.selectedCheckpointId,
    required this.student,
    required this.canPickStudent,
    required this.onCheckpointChanged,
    required this.onPickStudent,
    required this.onClearStudent,
    required this.onResetAll,
  });

  final List<AttendanceCheckpoint> checkpoints;
  final String? selectedCheckpointId;
  final AttendanceStudent? student;
  final bool canPickStudent;
  final ValueChanged<String?> onCheckpointChanged;
  final VoidCallback onPickStudent;
  final VoidCallback onClearStudent;
  final VoidCallback onResetAll;

  int get _activeCount => [
    selectedCheckpointId,
    student?.rosterStudentId,
  ].where((value) => value != null).length;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(AppTheme.radiusMd),
      child: Container(
        decoration: BoxDecoration(
          color: AppTheme.surface,
          borderRadius: BorderRadius.circular(AppTheme.radiusMd),
          border: Border.all(color: AppTheme.neutral200),
          boxShadow: AppTheme.shadowSm,
        ),
        clipBehavior: Clip.antiAlias,
        child: ExpansionTile(
          shape: const Border(),
          collapsedShape: const Border(),
          leading: const Icon(Icons.filter_alt_outlined),
          title: const Text('Bộ lọc media'),
          subtitle: Text(
            _activeCount == 0
                ? 'Theo điểm dừng hoặc học sinh'
                : 'Đang áp dụng $_activeCount bộ lọc',
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: AppTheme.onSurfaceVariant),
          ),
          initiallyExpanded: _activeCount > 0,
          childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          children: [
            DropdownButtonFormField<String?>(
              isExpanded: true,
              initialValue:
                  selectedCheckpointId != null &&
                      checkpoints.any(
                        (checkpoint) =>
                            checkpoint.checkpointId == selectedCheckpointId,
                      )
                  ? selectedCheckpointId
                  : null,
              decoration: const InputDecoration(
                labelText: 'Điểm dừng',
                prefixIcon: Icon(Icons.place_outlined),
              ),
              items: [
                const DropdownMenuItem<String?>(
                  child: Text('Tất cả điểm dừng'),
                ),
                ...checkpoints.map(
                  (checkpoint) => DropdownMenuItem<String?>(
                    value: checkpoint.checkpointId,
                    child: Text(
                      '${checkpoint.sortOrder + 1}. ${checkpoint.name}',
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
              ],
              onChanged: checkpoints.isEmpty ? null : onCheckpointChanged,
            ),
            if (canPickStudent) ...[
              const SizedBox(height: 12),
              if (student == null)
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: onPickStudent,
                    icon: const Icon(Icons.person_search_outlined),
                    label: const Text('Tìm ảnh theo học sinh trong tour'),
                  ),
                )
              else
                Align(
                  alignment: Alignment.centerLeft,
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      InputChip(
                        avatar: const Icon(
                          Icons.face_retouching_natural_outlined,
                          size: 18,
                        ),
                        label: Text(student!.fullName),
                        onPressed: onPickStudent,
                        onDeleted: onClearStudent,
                        deleteIcon: const Icon(Icons.close_rounded, size: 18),
                      ),
                      Text(
                        'Chỉ hiện ảnh nhận diện được em này',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppTheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
            if (_activeCount > 0) ...[
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: onResetAll,
                  icon: const Icon(Icons.filter_alt_off_outlined),
                  label: const Text('Xóa bộ lọc'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _StudentPickerSheet extends ConsumerStatefulWidget {
  const _StudentPickerSheet({required this.tourId});

  final String tourId;

  @override
  ConsumerState<_StudentPickerSheet> createState() =>
      _StudentPickerSheetState();
}

class _StudentPickerSheetState extends ConsumerState<_StudentPickerSheet> {
  final _searchController = TextEditingController();
  List<AttendanceStudent> _students = const [];
  bool _loading = true;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    Future.microtask(_loadStudents);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadStudents() async {
    final repository = ref.read(offlineAttendanceRepositoryProvider);
    var cached = const <AttendanceStudent>[];
    try {
      cached = await repository.getCachedStudents(widget.tourId);
    } on Object catch (_) {
      // Không có cache thì vẫn thử tải từ server bên dưới.
    }
    if (mounted && cached.isNotEmpty) {
      setState(() {
        _students = cached;
        _loading = false;
      });
    }
    try {
      final students = await repository.refreshStudents(widget.tourId);
      if (!mounted) return;
      setState(() {
        _students = students;
        _loading = false;
        _failed = false;
      });
    } on Object catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _failed = _students.isEmpty;
      });
    }
  }

  List<AttendanceStudent> get _visibleStudents {
    final query = _searchController.text.trim().toLowerCase();
    if (query.isEmpty) return _students;
    return _students.where((student) {
      return student.fullName.toLowerCase().contains(query) ||
          (student.className?.toLowerCase().contains(query) ?? false);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final students = _visibleStudents;
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: SizedBox(
          height: MediaQuery.of(context).size.height * 0.72,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                child: TextField(
                  controller: _searchController,
                  autofocus: true,
                  decoration: const InputDecoration(
                    labelText: 'Tìm học sinh trong tour',
                    helperText: 'Nhập tên hoặc lớp của học sinh.',
                    prefixIcon: Icon(Icons.search_rounded),
                  ),
                  onChanged: (_) => setState(() {}),
                ),
              ),
              Expanded(
                child: _loading
                    ? const Center(child: CircularProgressIndicator())
                    : _failed
                    ? const Center(
                        child: Padding(
                          padding: EdgeInsets.all(24),
                          child: Text(
                            'Không tải được danh sách học sinh của tour.',
                            textAlign: TextAlign.center,
                          ),
                        ),
                      )
                    : students.isEmpty
                    ? const Center(
                        child: Padding(
                          padding: EdgeInsets.all(24),
                          child: Text('Không tìm thấy học sinh phù hợp.'),
                        ),
                      )
                    : ListView.separated(
                        itemCount: students.length,
                        separatorBuilder: (context, index) =>
                            const Divider(height: 1),
                        itemBuilder: (context, index) {
                          final student = students[index];
                          return ListTile(
                            leading: const Icon(
                              Icons.face_retouching_natural_outlined,
                            ),
                            title: Text(student.fullName),
                            subtitle: Text(
                              student.className ?? 'Học sinh trong tour',
                            ),
                            onTap: () => Navigator.of(context).pop(student),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NewsfeedTabs extends StatelessWidget {
  const _NewsfeedTabs({required this.selected, required this.onChanged});

  final _NewsfeedFilter selected;
  final ValueChanged<_NewsfeedFilter> onChanged;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: SegmentedButton<_NewsfeedFilter>(
        style: SegmentedButton.styleFrom(
          backgroundColor: AppTheme.primarySoft,
          foregroundColor: AppTheme.primary,
          selectedBackgroundColor: AppTheme.primary,
          selectedForegroundColor: Colors.white,
          side: const BorderSide(color: AppTheme.primarySoft),
        ),
        selected: {selected},
        onSelectionChanged: (values) {
          if (values.isEmpty) return;
          onChanged(values.first);
        },
        segments: const [
          ButtonSegment(
            value: _NewsfeedFilter.all,
            icon: Icon(Icons.dynamic_feed_outlined),
            label: Text('Tất cả'),
          ),
          ButtonSegment(
            value: _NewsfeedFilter.media,
            icon: Icon(Icons.photo_library_outlined),
            label: Text('Ảnh & video'),
          ),
          ButtonSegment(
            value: _NewsfeedFilter.blog,
            icon: Icon(Icons.article_outlined),
            label: Text('Bài viết'),
          ),
        ],
      ),
    );
  }
}

class _NewsfeedCard extends StatelessWidget {
  const _NewsfeedCard({
    required this.item,
    required this.onLike,
    required this.onShare,
    required this.onComment,
  });

  final NewsfeedItem item;
  NewsfeedInteractions get interactions => item.interactions;
  final VoidCallback onLike;
  final VoidCallback onShare;
  final VoidCallback onComment;

  @override
  Widget build(BuildContext context) {
    final isVideo = item.mediaType?.toUpperCase() == 'VIDEO';
    final imageUrl = item.imageUrl == null
        ? ''
        : resolveMediaUrl(item.imageUrl!);
    final attachments = item.mediaAttachments;
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(AppTheme.radiusMd),
      child: Container(
        decoration: BoxDecoration(
          color: AppTheme.surface,
          borderRadius: BorderRadius.circular(AppTheme.radiusMd),
          border: Border.all(color: AppTheme.neutral200),
          boxShadow: AppTheme.shadowSm,
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (attachments.isNotEmpty)
              _FeedMediaGallery(attachments: attachments, title: item.title)
            else if (isViewableMediaUrl(imageUrl))
              _FeedImage(
                url: imageUrl,
                isVideo: isVideo,
                onTap: isVideo
                    ? null
                    : () => _openFullscreenImage(
                        context,
                        NewsfeedMediaAttachment(
                          id: '${item.id}-image',
                          url: imageUrl,
                          mediaType: 'IMAGE',
                        ),
                        item.title,
                      ),
              )
            else if (isVideo)
              const _VideoPlaceholder(),
            Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      _KindBadge(kind: item.kind),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _dateLabel(item.publishedAt),
                          textAlign: TextAlign.right,
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(color: AppTheme.onSurfaceVariant),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(
                    item.title,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: AppTheme.onSurface,
                    ),
                  ),
                  if (item.subtitle != null && item.subtitle!.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      item.subtitle!,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppTheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                  if (item.body != null && item.body!.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(
                      item.body!,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppTheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                  const SizedBox(height: 12),
                  _InteractionSummary(interactions: interactions),
                  const Divider(height: 20),
                  Row(
                    children: [
                      Expanded(
                        child: _InteractionButton(
                          icon: interactions.likedByCurrentUser
                              ? Icons.favorite_rounded
                              : Icons.favorite_border_rounded,
                          label: 'Thích',
                          active: interactions.likedByCurrentUser,
                          onPressed: onLike,
                        ),
                      ),
                      Expanded(
                        child: _InteractionButton(
                          icon: Icons.mode_comment_outlined,
                          label: 'Bình luận',
                          onPressed: onComment,
                        ),
                      ),
                      Expanded(
                        child: _InteractionButton(
                          icon: Icons.ios_share_rounded,
                          label: 'Chia sẻ',
                          onPressed: onShare,
                        ),
                      ),
                    ],
                  ),
                  if (interactions.comments.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    _CommentPreview(comment: interactions.comments.last),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InteractionSummary extends StatelessWidget {
  const _InteractionSummary({required this.interactions});

  final NewsfeedInteractions interactions;

  @override
  Widget build(BuildContext context) {
    // Không còn "lượt chia sẻ": con số đó trước đây chỉ đếm trên máy, server không lưu.
    final parts = [
      '${interactions.likeCount} lượt thích',
      '${interactions.commentCount} bình luận',
    ];
    return Text(
      parts.join(' · '),
      style: Theme.of(
        context,
      ).textTheme.bodySmall?.copyWith(color: AppTheme.onSurfaceVariant),
    );
  }
}

class _InteractionButton extends StatelessWidget {
  const _InteractionButton({
    required this.icon,
    required this.label,
    required this.onPressed,
    this.active = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onPressed;
  final bool active;

  @override
  Widget build(BuildContext context) {
    final color = active ? AppTheme.accentRed : AppTheme.onSurfaceVariant;
    return TextButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 18, color: color),
      label: Text(
        label,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(color: color, fontWeight: FontWeight.w700),
      ),
    );
  }
}

class _CommentPreview extends StatelessWidget {
  const _CommentPreview({required this.comment});

  final NewsfeedComment comment;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppTheme.surfaceContainer,
        borderRadius: BorderRadius.circular(8),
      ),
      child: RichText(
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        text: TextSpan(
          style: Theme.of(
            context,
          ).textTheme.bodySmall?.copyWith(color: AppTheme.onSurface),
          children: [
            TextSpan(
              text: '${comment.displayAuthor}: ',
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
            TextSpan(text: comment.content),
          ],
        ),
      ),
    );
  }
}

class _CommentsSheet extends StatefulWidget {
  const _CommentsSheet({required this.item, required this.onSubmit});

  final NewsfeedItem item;
  final Future<NewsfeedItem> Function(String text) onSubmit;

  @override
  State<_CommentsSheet> createState() => _CommentsSheetState();
}

class _CommentsSheetState extends State<_CommentsSheet> {
  final _controller = TextEditingController();
  late NewsfeedItem _item;
  bool _submitting = false;

  List<NewsfeedComment> get _comments => _item.interactions.comments;

  @override
  void initState() {
    super.initState();
    _item = widget.item;
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final text = _controller.text.trim();
    if (text.isEmpty || _submitting) return;
    setState(() => _submitting = true);
    try {
      final updated = await widget.onSubmit(text);
      if (!mounted) return;
      setState(() {
        _item = updated;
        _controller.clear();
      });
    } on Object catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(content: Text('Không gửi được bình luận.')),
        );
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(16, 0, 16, bottomInset + 16),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.82,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Bình luận',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Đóng',
                    onPressed: () => Navigator.of(context).pop(_item),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
              Text(
                widget.item.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppTheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 12),
              Flexible(
                child: _comments.isEmpty
                    ? const Center(child: Text('Chưa có bình luận.'))
                    : ListView.separated(
                        shrinkWrap: true,
                        itemCount: _comments.length,
                        separatorBuilder: (context, index) =>
                            const SizedBox(height: 8),
                        itemBuilder: (context, index) =>
                            _CommentTile(comment: _comments[index]),
                      ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      minLines: 1,
                      maxLines: 3,
                      textInputAction: TextInputAction.send,
                      onSubmitted: (_) => _submit(),
                      decoration: InputDecoration(
                        hintText: 'Viết bình luận...',
                        border: const OutlineInputBorder(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.filled(
                    tooltip: 'Gửi bình luận',
                    onPressed: _submitting ? null : _submit,
                    icon: _submitting
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
      ),
    );
  }
}

class _CommentTile extends StatelessWidget {
  const _CommentTile({required this.comment});

  final NewsfeedComment comment;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppTheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  comment.displayAuthor,
                  style: Theme.of(
                    context,
                  ).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w800),
                ),
              ),
              Text(
                _dateLabel(comment.createdAt),
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppTheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(comment.content),
        ],
      ),
    );
  }
}

class _FeedMediaGallery extends StatelessWidget {
  const _FeedMediaGallery({required this.attachments, required this.title});

  final List<NewsfeedMediaAttachment> attachments;
  final String title;

  @override
  Widget build(BuildContext context) {
    final visibleAttachments = attachments.take(4).toList();
    final extraCount = attachments.length - visibleAttachments.length;
    if (visibleAttachments.length == 1) {
      return AspectRatio(
        aspectRatio: 16 / 9,
        child: _FeedMediaTile(
          attachment: visibleAttachments.first,
          title: title,
        ),
      );
    }
    return GridView.builder(
      padding: EdgeInsets.zero,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: visibleAttachments.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 2,
        mainAxisSpacing: 2,
      ),
      itemBuilder: (context, index) {
        return _FeedMediaTile(
          attachment: visibleAttachments[index],
          title: title,
          extraCount: index == visibleAttachments.length - 1 ? extraCount : 0,
        );
      },
    );
  }
}

class _FeedMediaTile extends StatelessWidget {
  const _FeedMediaTile({
    required this.attachment,
    required this.title,
    this.extraCount = 0,
  });

  final NewsfeedMediaAttachment attachment;
  final String title;
  final int extraCount;

  @override
  Widget build(BuildContext context) {
    final url = resolveMediaUrl(attachment.displayUrl);
    final hasThumbnail = attachment.thumbnailUrl?.trim().isNotEmpty == true;
    final canPreview =
        isViewableMediaUrl(url) && (!attachment.isVideo || hasThumbnail);
    final canOpenImage = canPreview && !attachment.isVideo;
    final badge = _mediaAttachmentBadge(attachment);
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: canOpenImage
          ? () => _openFullscreenImage(context, attachment, title)
          : null,
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (canPreview)
            Image.network(
              url,
              fit: BoxFit.cover,
              loadingBuilder: (context, child, progress) {
                if (progress == null) return child;
                return const _ImageLoading();
              },
              errorBuilder: (context, error, stackTrace) =>
                  const _ImageFallback(),
            )
          else
            const _MediaFallback(),
          if (attachment.isVideo)
            const Center(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: Colors.black45,
                  shape: BoxShape.circle,
                ),
                child: Padding(
                  padding: EdgeInsets.all(8),
                  child: Icon(
                    Icons.play_arrow_rounded,
                    color: Colors.white,
                    size: 38,
                  ),
                ),
              ),
            ),
          if (canOpenImage)
            const Positioned(
              right: 8,
              top: 8,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: Colors.black45,
                  shape: BoxShape.circle,
                ),
                child: Padding(
                  padding: EdgeInsets.all(6),
                  child: Icon(
                    Icons.fullscreen_rounded,
                    color: Colors.white,
                    size: 18,
                  ),
                ),
              ),
            ),
          if (badge != null)
            Positioned(
              left: 8,
              right: 8,
              bottom: 8,
              child: _MediaBadge(label: badge),
            ),
          if (extraCount > 0)
            Positioned.fill(
              child: ColoredBox(
                color: Colors.black54,
                child: Center(
                  child: Text(
                    '+$extraCount',
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _MediaBadge extends StatelessWidget {
  const _MediaBadge({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.62),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
        child: Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
            color: Colors.white,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }
}

class _FeedImage extends StatelessWidget {
  const _FeedImage({required this.url, required this.isVideo, this.onTap});

  final String url;
  final bool isVideo;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AspectRatio(
        aspectRatio: 16 / 9,
        child: Stack(
          fit: StackFit.expand,
          children: [
            Image.network(
              url,
              fit: BoxFit.cover,
              loadingBuilder: (context, child, progress) {
                if (progress == null) return child;
                return const _ImageLoading();
              },
              errorBuilder: (context, error, stackTrace) =>
                  const _ImageFallback(),
            ),
            if (isVideo)
              const Center(
                child: Icon(
                  Icons.play_circle_fill_rounded,
                  color: Colors.white,
                  size: 56,
                ),
              ),
            if (onTap != null)
              const Positioned(
                right: 8,
                top: 8,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: Colors.black45,
                    shape: BoxShape.circle,
                  ),
                  child: Padding(
                    padding: EdgeInsets.all(6),
                    child: Icon(
                      Icons.fullscreen_rounded,
                      color: Colors.white,
                      size: 18,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _FullscreenImagePage extends StatelessWidget {
  const _FullscreenImagePage({
    required this.url,
    required this.title,
    required this.attachment,
  });

  final String url;
  final String title;
  final NewsfeedMediaAttachment attachment;

  @override
  Widget build(BuildContext context) {
    final details = [
      if (attachment.caption?.trim().isNotEmpty == true)
        attachment.caption!.trim(),
      if (_mediaAttachmentBadge(attachment) != null)
        _mediaAttachmentBadge(attachment)!,
    ];
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        leading: buildAppBackLeading(context, color: Colors.white),
        title: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis),
      ),
      body: SafeArea(
        child: Stack(
          children: [
            Positioned.fill(
              child: InteractiveViewer(
                minScale: 0.8,
                maxScale: 4,
                child: Center(
                  child: Image.network(
                    url,
                    fit: BoxFit.contain,
                    loadingBuilder: (context, child, progress) {
                      if (progress == null) return child;
                      return const _ImageLoading();
                    },
                    errorBuilder: (context, error, stackTrace) =>
                        const _ImageFallback(),
                  ),
                ),
              ),
            ),
            if (details.isNotEmpty)
              Positioned(
                left: 16,
                right: 16,
                bottom: 16,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.68),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Text(
                      details.join('\n'),
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

void _openFullscreenImage(
  BuildContext context,
  NewsfeedMediaAttachment attachment,
  String title,
) {
  final url = resolveMediaUrl(attachment.displayUrl);
  if (!isViewableMediaUrl(url) || attachment.isVideo) return;
  Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (_) =>
          _FullscreenImagePage(url: url, title: title, attachment: attachment),
    ),
  );
}

String? _mediaAttachmentBadge(NewsfeedMediaAttachment attachment) {
  final label = attachment.studentLabel;
  TourMediaFaceMatch? match;
  for (final item in attachment.faceMatches) {
    if (item.matchStatus.toUpperCase() == 'MATCHED') {
      match = item;
      break;
    }
  }
  final confidence = match == null ? null : _formatConfidence(match.confidence);
  if (label == null || label.isEmpty) {
    return confidence == null ? null : 'Khuôn mặt trùng khớp $confidence';
  }
  return confidence == null ? label : '$label • trùng khớp $confidence';
}

String? _formatConfidence(double value) {
  if (value <= 0) return null;
  final percent = value > 1 ? value.round() : (value * 100).round();
  return '$percent%';
}

class _VideoPlaceholder extends StatelessWidget {
  const _VideoPlaceholder();

  @override
  Widget build(BuildContext context) {
    return const AspectRatio(
      aspectRatio: 16 / 9,
      child: ColoredBox(
        color: Colors.black12,
        child: Center(child: Icon(Icons.play_circle_outline_rounded, size: 54)),
      ),
    );
  }
}

class _MediaFallback extends StatelessWidget {
  const _MediaFallback();

  @override
  Widget build(BuildContext context) {
    return const ColoredBox(
      color: Colors.black12,
      child: Center(child: Icon(Icons.perm_media_outlined)),
    );
  }
}

class _ImageFallback extends StatelessWidget {
  const _ImageFallback();

  @override
  Widget build(BuildContext context) {
    return const ColoredBox(
      color: Colors.black12,
      child: Center(child: Icon(Icons.broken_image_outlined)),
    );
  }
}

class _ImageLoading extends StatelessWidget {
  const _ImageLoading();

  @override
  Widget build(BuildContext context) {
    return const ColoredBox(
      color: Colors.black12,
      child: Center(
        child: SizedBox.square(
          dimension: 22,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      ),
    );
  }
}

class _KindBadge extends StatelessWidget {
  const _KindBadge({required this.kind});

  final NewsfeedItemKind kind;

  @override
  Widget build(BuildContext context) {
    final isBlog = kind == NewsfeedItemKind.blog;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: (isBlog ? AppTheme.secondary : AppTheme.accentGreen).withValues(
          alpha: 0.12,
        ),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        isBlog ? 'Bài viết' : 'Ảnh & video',
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: isBlog ? AppTheme.secondary : AppTheme.accentGreen,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _FeedBanner extends StatelessWidget {
  const _FeedBanner({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.surfaceContainer,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(icon, color: AppTheme.onSurfaceVariant),
          const SizedBox(width: 10),
          Expanded(child: Text(text)),
        ],
      ),
    );
  }
}

class _EmptyNewsfeed extends StatelessWidget {
  const _EmptyNewsfeed();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        border: Border.all(color: AppTheme.neutral200),
        boxShadow: AppTheme.shadowSm,
      ),
      child: const Column(
        children: [
          Icon(Icons.dynamic_feed_outlined, size: 40),
          SizedBox(height: 10),
          Text(
            'Chưa có bài đăng',
            style: TextStyle(fontWeight: FontWeight.w800),
          ),
          SizedBox(height: 4),
          Text(
            'Media chuyến đi và bài viết blog sẽ xuất hiện tại đây.',
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

String _dateLabel(DateTime? value) {
  if (value == null) return '';
  final local = value.toLocal();
  return '${local.day.toString().padLeft(2, '0')}/${local.month.toString().padLeft(2, '0')}/${local.year}';
}
