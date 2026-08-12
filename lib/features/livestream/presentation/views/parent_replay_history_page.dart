import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../app/providers.dart';
import '../../../../core/network/api_exception.dart';
import '../../../../shared/theme/app_theme.dart';
import '../../../../shared/widgets/app_back_leading.dart';
import '../../../../shared/widgets/parent_ui.dart';
import '../../data/models/livestream_replay_models.dart';

/// Danh sách VOD replay của một tour — W-LS-03 mobile.
class ParentReplayHistoryPage extends ConsumerStatefulWidget {
  const ParentReplayHistoryPage({super.key, required this.tourId, this.title});

  final String tourId;
  final String? title;

  @override
  ConsumerState<ParentReplayHistoryPage> createState() =>
      _ParentReplayHistoryPageState();
}

class _ParentReplayHistoryPageState
    extends ConsumerState<ParentReplayHistoryPage> {
  late Future<List<LivestreamReplaySession>> _sessionsFuture;

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    _sessionsFuture = ref
        .read(livestreamRepositoryProvider)
        .getReplaySessions(tourId: widget.tourId);
  }

  Future<void> _refresh() async {
    setState(_load);
    await _sessionsFuture;
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
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Xem lại livestream'),
            if (widget.title != null)
              Text(
                widget.title!,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppTheme.onSurfaceVariant,
                ),
              ),
          ],
        ),
      ),
      body: widget.tourId.isEmpty
          ? const _ReplayMessage(
              icon: Icons.info_outline_rounded,
              title: 'Thiếu mã tour',
              message: 'Không thể tải danh sách VOD khi chưa có tourId.',
            )
          : RefreshIndicator(
              onRefresh: _refresh,
              child: FutureBuilder<List<LivestreamReplaySession>>(
                future: _sessionsFuture,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (snapshot.hasError) {
                    final api = ApiException.maybeFrom(snapshot.error!);
                    return ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      children: [
                        _ReplayMessage(
                          icon: Icons.error_outline_rounded,
                          title: 'Không thể tải danh sách',
                          message: api?.message ?? 'Vui lòng thử lại sau.',
                          actionLabel: 'Thử lại',
                          onAction: _refresh,
                        ),
                      ],
                    );
                  }

                  final sessions = snapshot.data ?? [];
                  if (sessions.isEmpty) {
                    return ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      children: const [
                        _ReplayMessage(
                          icon: Icons.videocam_off_outlined,
                          title: 'Chưa có bản ghi',
                          message:
                              'Khi HDV kết thúc livestream, video sẽ xuất hiện tại đây sau khi hệ thống xử lý xong.',
                        ),
                      ],
                    );
                  }

                  return ListView.separated(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
                    itemCount: sessions.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      final session = sessions[index];
                      return _ReplaySessionCard(
                        session: session,
                        onTap: session.canWatch
                            ? () => context.push(
                                '/livestream/replay/${session.id}',
                                extra: {
                                  'tourId': widget.tourId,
                                  'title': session.displayTitle,
                                },
                              )
                            : () {
                                final message = session.isProcessing
                                    ? 'Video đang được xử lý. Kéo xuống để làm mới sau vài phút.'
                                    : 'Không có bản ghi để xem. Recording có thể chưa được cấu hình (AWS/LiveKit) hoặc upload thất bại.';
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text(message)),
                                );
                              },
                      );
                    },
                  );
                },
              ),
            ),
    );
  }
}

class _ReplaySessionCard extends StatelessWidget {
  const _ReplaySessionCard({required this.session, this.onTap});

  final LivestreamReplaySession session;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final dateLabel = _formatDate(session.endedAt ?? session.startedAt);

    return ParentCard(
      onTap: onTap,
      padding: EdgeInsets.zero,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AspectRatio(
              aspectRatio: 16 / 9,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  _ReplayThumbnail(thumbnailUrl: session.thumbnailUrl),
                  if (session.canWatch)
                    Container(
                      color: Colors.black26,
                      child: const Center(
                        child: Icon(
                          Icons.play_circle_fill_rounded,
                          color: Colors.white,
                          size: 52,
                        ),
                      ),
                    ),
                  if (session.durationSeconds > 0)
                    Positioned(
                      right: 8,
                      bottom: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.black87,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          _formatDuration(session.durationSeconds),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            fontFamily: 'monospace',
                          ),
                        ),
                      ),
                    ),
                  if (!session.canWatch)
                    Positioned(
                      left: 8,
                      top: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.black87,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          session.isProcessing ? 'Đang xử lý…' : 'Không có bản ghi',
                          style: const TextStyle(color: Colors.white70, fontSize: 11),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    session.displayTitle,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 15,
                      color: session.canWatch
                          ? AppTheme.onSurface
                          : AppTheme.onSurfaceVariant,
                    ),
                  ),
                  if (session.description?.trim().isNotEmpty == true) ...[
                    const SizedBox(height: 4),
                    Text(
                      session.description!.trim(),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppTheme.onSurfaceVariant,
                        fontSize: 13,
                      ),
                    ),
                  ],
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Icon(
                        Icons.schedule_rounded,
                        size: 14,
                        color: AppTheme.onSurfaceVariant,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        dateLabel,
                        style: const TextStyle(
                          color: AppTheme.onSurfaceVariant,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ReplayThumbnail extends StatelessWidget {
  const _ReplayThumbnail({this.thumbnailUrl});

  final String? thumbnailUrl;

  @override
  Widget build(BuildContext context) {
    if (thumbnailUrl != null && thumbnailUrl!.isNotEmpty) {
      try {
        return Image.memory(
          base64Decode(thumbnailUrl!),
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => const _ReplayThumbnailPlaceholder(),
        );
      } catch (_) {
        return const _ReplayThumbnailPlaceholder();
      }
    }
    return const _ReplayThumbnailPlaceholder();
  }
}

class _ReplayThumbnailPlaceholder extends StatelessWidget {
  const _ReplayThumbnailPlaceholder();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF0A0E1A), Color(0xFF1A2236)],
        ),
      ),
      child: const Center(
        child: Icon(
          Icons.ondemand_video_rounded,
          color: Colors.white24,
          size: 48,
        ),
      ),
    );
  }
}

class _ReplayMessage extends StatelessWidget {
  const _ReplayMessage({
    required this.icon,
    required this.title,
    required this.message,
    this.actionLabel,
    this.onAction,
  });

  final IconData icon;
  final String title;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 56, color: AppTheme.onSurfaceVariant),
          const SizedBox(height: 16),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: AppTheme.onSurfaceVariant,
              height: 1.5,
            ),
          ),
          if (actionLabel != null && onAction != null) ...[
            const SizedBox(height: 20),
            FilledButton(onPressed: onAction, child: Text(actionLabel!)),
          ],
        ],
      ),
    );
  }
}

String _formatDuration(int seconds) {
  if (seconds < 0) return '--:--';
  final h = seconds ~/ 3600;
  final m = (seconds % 3600) ~/ 60;
  final s = seconds % 60;
  if (h > 0) {
    return '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }
  return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
}

String _formatDate(String? iso) {
  if (iso == null || iso.isEmpty) return '—';
  final parsed = DateTime.tryParse(iso);
  if (parsed == null) return '—';
  return DateFormat('dd/MM/yyyy HH:mm').format(parsed.toLocal());
}
