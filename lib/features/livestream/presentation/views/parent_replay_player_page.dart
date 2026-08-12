import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:video_player/video_player.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../../../../app/providers.dart';
import '../../../../core/network/api_exception.dart';
import '../../../../shared/theme/app_theme.dart';
import '../../../../shared/widgets/app_back_leading.dart';
import '../../data/models/livestream_replay_models.dart';

/// Phát VOD một phiên livestream — W-LS-04 mobile.
class ParentReplayPlayerPage extends ConsumerStatefulWidget {
  const ParentReplayPlayerPage({
    super.key,
    required this.tourId,
    required this.sessionId,
    this.title,
  });

  final String tourId;
  final String sessionId;
  final String? title;

  @override
  ConsumerState<ParentReplayPlayerPage> createState() =>
      _ParentReplayPlayerPageState();
}

class _ParentReplayPlayerPageState
    extends ConsumerState<ParentReplayPlayerPage> {
  VideoPlayerController? _controller;
  LivestreamReplayUrl? _replay;
  String? _errorMessage;
  bool _loading = true;
  bool _isRecordingMissing = false;

  @override
  void initState() {
    super.initState();
    WakelockPlus.enable();
    _load();
  }

  @override
  void dispose() {
    _controller?.dispose();
    WakelockPlus.disable();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _errorMessage = null;
      _isRecordingMissing = false;
    });

    try {
      final replay = await ref
          .read(livestreamRepositoryProvider)
          .getReplayPresignedUrl(sessionId: widget.sessionId);
      final controller = VideoPlayerController.networkUrl(
        Uri.parse(replay.presignedUrl),
      );
      await controller.initialize();
      controller.addListener(() {
        if (mounted) setState(() {});
      });

      if (!mounted) {
        await controller.dispose();
        return;
      }

      await _controller?.dispose();
      _controller = controller;
      _replay = replay;
      setState(() => _loading = false);
    } catch (e) {
      if (!mounted) return;
      final api = ApiException.maybeFrom(e);
      setState(() {
        _loading = false;
        _isRecordingMissing = api?.statusCode == 404;
        if (_isRecordingMissing) {
          _errorMessage =
              'Video chưa sẵn sàng. Vui lòng thử lại sau vài phút.';
        } else if (api?.statusCode == 403) {
          _errorMessage =
              'Bạn không có quyền xem bản ghi này. Liên hệ điều hành nếu đây là chuyến của con bạn.';
        } else {
          _errorMessage =
              api?.message ?? 'Không thể tải video. Vui lòng thử lại.';
        }
      });
    }
  }

  void _togglePlay() {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) return;
    if (controller.value.isPlaying) {
      controller.pause();
    } else {
      controller.play();
    }
    setState(() {});
  }

  String _formatTime(Duration duration) {
    final seconds = duration.inSeconds;
    final h = seconds ~/ 3600;
    final m = (seconds % 3600) ~/ 60;
    final s = seconds % 60;
    if (h > 0) {
      return '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
    }
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final replay = _replay;
    final controller = _controller;

    return Scaffold(
      backgroundColor: AppTheme.surfaceLight,
      appBar: AppBar(
        leading: buildAppBackLeading(
          context,
          fallbackRoute: '/parent/dashboard',
        ),
        title: Text(widget.title ?? replay?.title ?? 'Xem lại'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
          ? _buildError()
          : controller == null || !controller.value.isInitialized
          ? const Center(child: Text('Không thể khởi tạo trình phát.'))
          : Column(
              children: [
                AspectRatio(
                  aspectRatio: controller.value.aspectRatio == 0
                      ? 16 / 9
                      : controller.value.aspectRatio,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      VideoPlayer(controller),
                      if (!controller.value.isPlaying)
                        IconButton.filled(
                          style: IconButton.styleFrom(
                            backgroundColor: AppTheme.primary.withValues(alpha: 0.85),
                            foregroundColor: Colors.white,
                            iconSize: 48,
                          ),
                          onPressed: _togglePlay,
                          icon: const Icon(Icons.play_arrow_rounded),
                        ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      VideoProgressIndicator(
                        controller,
                        allowScrubbing: true,
                        colors: VideoProgressColors(
                          playedColor: AppTheme.primary,
                          bufferedColor: AppTheme.primary.withValues(alpha: 0.4),
                          backgroundColor: AppTheme.outlineVariant,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          IconButton(
                            onPressed: _togglePlay,
                            icon: Icon(
                              controller.value.isPlaying
                                  ? Icons.pause_rounded
                                  : Icons.play_arrow_rounded,
                            ),
                          ),
                          Text(
                            '${_formatTime(controller.value.position)} / ${_formatTime(controller.value.duration)}',
                            style: const TextStyle(
                              fontFamily: 'monospace',
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                      if (replay != null) ...[
                        const SizedBox(height: 8),
                        Text(
                          replay.title?.trim().isNotEmpty == true
                              ? replay.title!.trim()
                              : 'Phiên phát sóng',
                          style: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 6),
                        if (replay.startedAt != null)
                          Text(
                            'Phát sóng: ${_formatDate(replay.startedAt!)}',
                            style: const TextStyle(
                              color: AppTheme.onSurfaceVariant,
                            ),
                          ),
                        if (replay.expiresAt != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text(
                              'Link phát hết hạn lúc ${DateFormat('HH:mm').format(DateTime.parse(replay.expiresAt!).toLocal())}',
                              style: const TextStyle(
                                color: AppTheme.accentOrange,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildError() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              _isRecordingMissing
                  ? Icons.hourglass_empty_rounded
                  : Icons.error_outline_rounded,
              size: 56,
              color: AppTheme.onSurfaceVariant,
            ),
            const SizedBox(height: 16),
            Text(
              _isRecordingMissing ? 'Video đang xử lý' : 'Không thể phát video',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            Text(
              _errorMessage!,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: AppTheme.onSurfaceVariant,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 20),
            if (!_isRecordingMissing)
              FilledButton.icon(
                onPressed: _load,
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Thử lại'),
              ),
            const SizedBox(height: 8),
            OutlinedButton(
              onPressed: () => context.pop(),
              child: const Text('Quay lại'),
            ),
          ],
        ),
      ),
    );
  }

  String _formatDate(String iso) {
    final parsed = DateTime.tryParse(iso);
    if (parsed == null) return iso;
    return DateFormat('dd/MM/yyyy HH:mm').format(parsed.toLocal());
  }
}
