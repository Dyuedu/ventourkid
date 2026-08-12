import 'package:flutter/material.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../app/providers.dart';
import '../../../../shared/theme/app_theme.dart';
import '../../../../shared/utils/media_url.dart';
import '../../../../shared/widgets/app_back_leading.dart';
import '../../../../shared/widgets/parent_ui.dart';

/// Past-tour detail for a linked child: tour summary + approved media gallery.
class ParentTourHistoryDetailPage extends ConsumerStatefulWidget {
  const ParentTourHistoryDetailPage({
    super.key,
    required this.tourId,
    required this.rosterStudentId,
    this.childName,
    this.seededTour,
  });

  final String tourId;
  final String rosterStudentId;
  final String? childName;
  final Map<String, dynamic>? seededTour;

  @override
  ConsumerState<ParentTourHistoryDetailPage> createState() =>
      _ParentTourHistoryDetailPageState();
}

class _ParentTourHistoryDetailPageState
    extends ConsumerState<ParentTourHistoryDetailPage> {
  bool _loading = true;
  String? _error;
  String? _mediaError;
  String _childName = '';
  Map<String, dynamic>? _tour;
  List<Map<String, dynamic>> _media = const [];
  int _mediaTotal = 0;

  @override
  void initState() {
    super.initState();
    _childName = widget.childName?.trim() ?? '';
    _tour = widget.seededTour;
    Future.microtask(_load);
  }

  Future<void> _load() async {
    if (widget.tourId.isEmpty || widget.rosterStudentId.isEmpty) {
      setState(() {
        _loading = false;
        _error = 'Thiếu thông tin học sinh hoặc chuyến đi.';
      });
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
      _mediaError = null;
    });

    final remote = ref.read(parentDashboardRemoteDataSourceProvider);

    Map<String, dynamic>? matched = widget.seededTour;
    String childName = _childName;
    List<Map<String, dynamic>> media = const [];
    int mediaTotal = 0;
    String? mediaError;
    String? error;

    try {
      final children = await remote.getLinkedChildren();
      for (final child in children) {
        if (child.rosterStudentId == widget.rosterStudentId) {
          childName = child.displayLabel;
          break;
        }
      }
    } catch (_) {
      // Keep seeded child name.
    }

    try {
      final history = await remote.getTourHistory(
        rosterStudentId: widget.rosterStudentId,
      );
      for (final row in history) {
        final id = (row['tour_id'] ?? row['tourId'] ?? '').toString();
        if (id == widget.tourId) {
          matched = row;
          break;
        }
      }
    } catch (_) {
      // Fall back to listChildTours / seed.
    }

    if (matched == null) {
      try {
        final tours = await remote.listChildTours(
          rosterStudentId: widget.rosterStudentId,
        );
        final past = List<Map<String, dynamic>>.from(
          tours['past'] as List? ?? const [],
        );
        for (final row in past) {
          final id = (row['tour_id'] ?? row['tourId'] ?? '').toString();
          if (id == widget.tourId) {
            matched = row;
            break;
          }
        }
      } catch (_) {}
    }

    if (matched == null) {
      error = 'Không tìm thấy chuyến đi này trong lịch sử của học sinh.';
    }

    try {
      final payload = await remote.getChildMedia(
        rosterStudentId: widget.rosterStudentId,
        tourId: widget.tourId,
        page: 0,
        size: 48,
      );
      media = List<Map<String, dynamic>>.from(
        payload['media'] as List? ?? const [],
      );
      final total = payload['total'];
      mediaTotal = total is num ? total.toInt() : media.length;
    } catch (_) {
      media = const [];
      mediaTotal = 0;
      mediaError =
          'Không tải được media của chuyến này (có thể đã hết hạn lưu trữ).';
    }

    if (!mounted) return;
    setState(() {
      _loading = false;
      _childName = childName;
      _tour = matched;
      _media = media;
      _mediaTotal = mediaTotal;
      _mediaError = mediaError;
      _error = error;
    });
  }

  String get _tourName =>
      (_tour?['tour_name'] ??
              _tour?['tourName'] ??
              widget.seededTour?['tour_name'] ??
              widget.seededTour?['tourName'] ??
              'Chuyến đi trải nghiệm')
          .toString();

  String get _dateLabel {
    final raw = _tour?['date'] ??
        _tour?['planned_date'] ??
        _tour?['plannedDate'] ??
        _tour?['completed_at'];
    if (raw == null) return '—';
    final parsed = DateTime.tryParse(raw.toString());
    if (parsed == null) return raw.toString();
    return DateFormat('dd/MM/yyyy').format(parsed.toLocal());
  }

  String get _attendanceLabel {
    final raw = (_tour?['attendance_status'] ??
            _tour?['attendanceStatus'] ??
            'COMPLETED')
        .toString()
        .toUpperCase();
    return switch (raw) {
      'PRESENT' || 'CHECKED_IN' => 'Có mặt',
      'ABSENT' => 'Vắng',
      'PENDING' => 'Chưa điểm danh',
      'COMPLETED' || 'HOÀN TẤT' => 'Hoàn tất',
      _ => raw.isEmpty ? 'Hoàn tất' : raw,
    };
  }

  int? get _daysLeft {
    final value = _tour?['media_retention_days_remaining'] ??
        _tour?['mediaRetentionDaysRemaining'];
    return value is num ? value.toInt() : null;
  }

  bool get _showRetentionWarning {
    final show = _tour?['show_media_retention_banner'] == true ||
        _tour?['showMediaRetentionBanner'] == true;
    final days = _daysLeft;
    return show && days != null && days >= 0;
  }

  String _mediaUrl(Map<String, dynamic> item) {
    for (final key in [
      'url',
      'fileUrl',
      'file_url',
      'mediaUrl',
      'media_url',
      'thumbnailUrl',
      'thumbnail_url',
    ]) {
      final value = item[key]?.toString() ?? '';
      if (isViewableMediaUrl(value)) return resolveMediaUrl(value);
    }
    return '';
  }

  String _mediaTakenAt(Map<String, dynamic> item) {
    final raw = item['taken_at'] ?? item['capturedAt'] ?? item['created_at'];
    if (raw == null) return '';
    final parsed = DateTime.tryParse(raw.toString());
    if (parsed == null) return raw.toString();
    return DateFormat('dd/MM/yyyy HH:mm').format(parsed.toLocal());
  }

  void _openMediaViewer(Map<String, dynamic> item) {
    final url = _mediaUrl(item);
    if (url.isEmpty) return;
    showDialog<void>(
      context: context,
      builder: (context) {
        return Dialog(
          backgroundColor: const Color(0xFF0F172A),
          insetPadding: const EdgeInsets.all(16),
          child: Stack(
            children: [
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  AspectRatio(
                    aspectRatio: 1,
                    child: InteractiveViewer(
                      child: Image.network(
                        url,
                        fit: BoxFit.contain,
                        errorBuilder: (_, _, _) => const Center(
                          child: Icon(
                            Iconsax.gallery_slash,
                            color: Colors.white70,
                            size: 48,
                          ),
                        ),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          (item['caption']?.toString().trim().isNotEmpty ==
                                  true)
                              ? item['caption'].toString()
                              : 'Khoảnh khắc chuyến tham quan',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        if (_mediaTakenAt(item).isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(
                            _mediaTakenAt(item),
                            style: const TextStyle(color: Color(0xFF94A3B8)),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
              Positioned(
                top: 4,
                right: 4,
                child: IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Iconsax.close_circle, color: Colors.white),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _openFeedback() async {
    final uri = Uri(
      path: '/parent/feedback',
      queryParameters: {
        'tourId': widget.tourId,
        if (_tourName.trim().isNotEmpty) 'tourName': _tourName,
      },
    );
    await context.push(uri.toString());
  }

  @override
  Widget build(BuildContext context) {
    return ParentPageScaffold(
      title: 'Lịch sử chuyến đi',
      leading: buildAppBackLeading(context),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
                children: [
                  if (_error != null) ...[
                    ParentCard(
                      color: AppTheme.accentOrange.withValues(alpha: 0.12),
                      child: Text(
                        _error!,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
                  ParentCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'LỊCH SỬ CHUYẾN ĐI',
                          style:
                              Theme.of(context).textTheme.labelSmall?.copyWith(
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: 0.8,
                                    color: AppTheme.onSurfaceVariant,
                                  ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _tourName,
                          style: Theme.of(context)
                              .textTheme
                              .headlineSmall
                              ?.copyWith(fontWeight: FontWeight.w800),
                        ),
                        if (_childName.isNotEmpty) ...[
                          const SizedBox(height: 6),
                          Text(
                            'Học sinh: $_childName',
                            style: Theme.of(context)
                                .textTheme
                                .bodyMedium
                                ?.copyWith(color: AppTheme.onSurfaceVariant),
                          ),
                        ],
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            _Chip(label: 'Đã hoàn tất', emphasized: true),
                            _Chip(label: _attendanceLabel),
                          ],
                        ),
                        const SizedBox(height: 16),
                        _InfoTile(
                          icon: Iconsax.calendar_1,
                          label: 'Ngày tour',
                          value: _dateLabel,
                        ),
                        const SizedBox(height: 10),
                        _InfoTile(
                          icon: Iconsax.tick_circle,
                          label: 'Điểm danh',
                          value: _attendanceLabel,
                        ),
                        const SizedBox(height: 10),
                        _InfoTile(
                          icon: Iconsax.gallery,
                          label: 'Media đã duyệt',
                          value:
                              '${_mediaTotal > 0 ? _mediaTotal : (_tour?['media_count'] ?? _media.length)} ảnh/video',
                        ),
                        const SizedBox(height: 14),
                        if (_showRetentionWarning)
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: AppTheme.accentOrange.withValues(alpha: 0.14),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              'Ảnh tour còn $_daysLeft ngày trước khi xóa. Hãy xem và lưu lại những khoảnh khắc quan trọng.',
                              style: Theme.of(context)
                                  .textTheme
                                  .bodySmall
                                  ?.copyWith(fontWeight: FontWeight.w600),
                            ),
                          )
                        else
                          Text(
                            'Dữ liệu realtime và livestream live không còn khả dụng sau khi tour đóng. Chỉ còn lịch sử và media trong thời hạn lưu trữ.',
                            style: Theme.of(context)
                                .textTheme
                                .bodySmall
                                ?.copyWith(color: AppTheme.onSurfaceVariant),
                          ),
                        const SizedBox(height: 14),
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton.icon(
                            onPressed: widget.tourId.isEmpty
                                ? null
                                : () => context.push(
                                      '/livestream/replay',
                                      extra: {
                                        'tourId': widget.tourId,
                                        'title': _tourName,
                                      },
                                    ),
                            icon: const Icon(Iconsax.video_play),
                            label: const Text('Xem lại livestream (VOD)'),
                          ),
                        ),
                        const SizedBox(height: 10),
                        SizedBox(
                          width: double.infinity,
                          child: FilledButton.tonalIcon(
                            onPressed: widget.tourId.isEmpty
                                ? null
                                : _openFeedback,
                            icon: const Icon(Iconsax.star_1),
                            label: const Text('Đánh giá chuyến đi'),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  ParentSectionHeader(
                    title: 'Media của chuyến (${_media.length})',
                    subtitle:
                        'Ảnh/video đã duyệt gắn với học sinh trong chuyến này.',
                  ),
                  const SizedBox(height: 12),
                  if (_mediaError != null) ...[
                    ParentCard(
                      child: Text(
                        _mediaError!,
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
                  if (_media.isEmpty)
                    ParentCard(
                      child: Column(
                        children: [
                          const Icon(
                            Iconsax.image,
                            size: 44,
                            color: AppTheme.onSurfaceVariant,
                          ),
                          const SizedBox(height: 10),
                          Text(
                            'Chưa có media đã duyệt',
                            style: Theme.of(context)
                                .textTheme
                                .titleSmall
                                ?.copyWith(fontWeight: FontWeight.w800),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Ảnh/video gắn với học sinh sẽ hiện tại đây khi còn trong thời hạn lưu trữ.',
                            textAlign: TextAlign.center,
                            style: Theme.of(context)
                                .textTheme
                                .bodySmall
                                ?.copyWith(color: AppTheme.onSurfaceVariant),
                          ),
                        ],
                      ),
                    )
                  else
                    GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: _media.length,
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        mainAxisSpacing: 10,
                        crossAxisSpacing: 10,
                        childAspectRatio: 0.86,
                      ),
                      itemBuilder: (context, index) {
                        final item = _media[index];
                        final url = _mediaUrl(item);
                        final taken = _mediaTakenAt(item);
                        return Material(
                          color: AppTheme.surface,
                          borderRadius: BorderRadius.circular(14),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(14),
                            onTap: url.isEmpty
                                ? null
                                : () => _openMediaViewer(item),
                            child: Container(
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(color: AppTheme.neutral200),
                              ),
                              clipBehavior: Clip.antiAlias,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  Expanded(
                                    child: url.isEmpty
                                        ? const ColoredBox(
                                            color: AppTheme.neutral100,
                                            child: Center(
                                              child: Icon(
                                                Iconsax.image,
                                                color:
                                                    AppTheme.onSurfaceVariant,
                                              ),
                                            ),
                                          )
                                        : Image.network(
                                            url,
                                            fit: BoxFit.cover,
                                            errorBuilder: (_, _, _) =>
                                                const ColoredBox(
                                              color: AppTheme.neutral100,
                                              child: Center(
                                                child: Icon(
                                                  Iconsax.gallery_slash,
                                                  color: AppTheme
                                                      .onSurfaceVariant,
                                                ),
                                              ),
                                            ),
                                          ),
                                  ),
                                  Padding(
                                    padding: const EdgeInsets.all(10),
                                    child: Text(
                                      taken.isEmpty ? '—' : taken,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: Theme.of(context)
                                          .textTheme
                                          .labelSmall
                                          ?.copyWith(
                                            color: AppTheme.onSurfaceVariant,
                                          ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                ],
              ),
            ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.label, this.emphasized = false});

  final String label;
  final bool emphasized;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: emphasized
            ? AppTheme.primary.withValues(alpha: 0.12)
            : AppTheme.neutral100,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: emphasized
              ? AppTheme.primary.withValues(alpha: 0.35)
              : AppTheme.neutral200,
        ),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              fontWeight: FontWeight.w700,
              color: emphasized ? AppTheme.primary : AppTheme.onSurfaceVariant,
            ),
      ),
    );
  }
}

class _InfoTile extends StatelessWidget {
  const _InfoTile({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.surfaceLight,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.neutral200),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: AppTheme.neutral100,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 18, color: AppTheme.onSurfaceVariant),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: AppTheme.onSurfaceVariant,
                      ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  maxLines: 1,
                  softWrap: false,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
