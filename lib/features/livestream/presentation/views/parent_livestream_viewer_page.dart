import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import 'package:livekit_client/livekit_client.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../../../../app/providers.dart';
import '../../../../core/network/api_exception.dart';
import '../../../../shared/theme/app_theme.dart';

enum _ViewerPhase { connecting, waitingVideo, live, ended, error }

/// Màn xem livestream dành cho phụ huynh (viewer).
class ParentLivestreamViewerPage extends ConsumerStatefulWidget {
  const ParentLivestreamViewerPage({
    super.key,
    required this.tourId,
    required this.sessionId,
    this.title,
    this.viewerRole,
    this.viewerName,
  });

  final String tourId;
  final String sessionId;
  final String? title;
  final String? viewerRole;
  final String? viewerName;

  @override
  ConsumerState<ParentLivestreamViewerPage> createState() =>
      _ParentLivestreamViewerPageState();
}

class _ParentLivestreamViewerPageState
    extends ConsumerState<ParentLivestreamViewerPage> {
  Room? _room;
  EventsListener<RoomEvent>? _listener;
  Timer? _durationTimer;

  _ViewerPhase _phase = _ViewerPhase.connecting;
  String? _errorMessage;
  bool _isForbidden = false;
  bool _muted = false;
  bool _chatVisible = false;
  int _secondsElapsed = 0;
  String? _resolvedSessionId;

  VideoTrack? _remoteVideoTrack;
  final List<Map<String, dynamic>> _messages = [];
  final List<Map<String, dynamic>> _floatingReactions = [];
  final TextEditingController _chatController = TextEditingController();

  String get _viewerRole =>
      widget.viewerRole == 'TEACHER' ? 'TEACHER' : 'PARENT';

  String get _viewerName {
    final explicit = widget.viewerName?.trim();
    if (explicit != null && explicit.isNotEmpty) return explicit;
    return _viewerRole == 'TEACHER' ? 'Giáo viên' : 'Phụ huynh';
  }

  static const _reactions = {
    'heart': '❤️',
    'wow': '😮',
    'clap': '👏',
    'thumbup': '👍',
  };

  @override
  void initState() {
    super.initState();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    WakelockPlus.enable();
    _connect();
  }

  @override
  void dispose() {
    _durationTimer?.cancel();
    _chatController.dispose();
    _listener?.dispose();
    _room?.removeListener(_onRoomChanged);
    _room?.disconnect();
    WakelockPlus.disable();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }

  Future<void> _connect() async {
    if (widget.tourId.isEmpty || widget.sessionId.isEmpty) {
      _setError(
        'Thiếu thông tin phiên livestream. Vui lòng quay lại và chọn lại.',
      );
      return;
    }

    setState(() {
      _phase = _ViewerPhase.connecting;
      _errorMessage = null;
      _isForbidden = false;
    });

    try {
      final tokenModel = await ref
          .read(livestreamRepositoryProvider)
          .getViewerToken(tourId: widget.tourId, sessionId: widget.sessionId);

      final room = Room();
      await room.connect(tokenModel.wsUrl, tokenModel.token);

      if (!mounted) {
        await room.disconnect();
        return;
      }

      _resolvedSessionId = tokenModel.sessionId;
      _room = room;
      _listener = room.createListener()
        ..on<TrackSubscribedEvent>((_) => _syncRemoteTracks())
        ..on<TrackUnsubscribedEvent>((_) => _syncRemoteTracks())
        ..on<ParticipantConnectedEvent>((_) => _onRoomChanged())
        ..on<ParticipantDisconnectedEvent>((_) => _onRoomChanged())
        ..on<DataReceivedEvent>(_onDataReceived)
        ..on<RoomDisconnectedEvent>((_) {
          if (mounted && _phase != _ViewerPhase.error) {
            setState(() => _phase = _ViewerPhase.ended);
          }
        });

      room.addListener(_onRoomChanged);
      _syncRemoteTracks();
      _startDurationTimer();

      setState(() {
        _phase = _remoteVideoTrack == null
            ? _ViewerPhase.waitingVideo
            : _ViewerPhase.live;
      });
    } catch (e) {
      if (!mounted) return;
      final api = ApiException.maybeFrom(e);
      final statusCode = api?.statusCode;
      _setError(
        statusCode == 403
            ? 'Bạn chưa được ủy quyền xem livestream này. Vui lòng kiểm tra ủy quyền phụ huynh hoặc phạm vi audience của tour.'
            : statusCode == 404
            ? 'Phiên livestream không còn hoạt động hoặc đã kết thúc.'
            : api?.message ?? 'Không thể kết nối livestream. Vui lòng thử lại.',
        forbidden: statusCode == 403,
      );
    }
  }

  void _setError(String message, {bool forbidden = false}) {
    setState(() {
      _phase = _ViewerPhase.error;
      _errorMessage = message;
      _isForbidden = forbidden;
    });
  }

  void _startDurationTimer() {
    _durationTimer?.cancel();
    _durationTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) {
        setState(() => _secondsElapsed++);
      }
    });
  }

  void _onRoomChanged() {
    _syncRemoteTracks();
    if (!mounted) return;
    setState(() {
      if (_remoteVideoTrack != null && _phase == _ViewerPhase.waitingVideo) {
        _phase = _ViewerPhase.live;
      }
      if (_room?.remoteParticipants.isEmpty == true &&
          _phase == _ViewerPhase.live) {
        _phase = _ViewerPhase.ended;
      }
    });
  }

  void _syncRemoteTracks() {
    VideoTrack? nextVideo;
    final participants = _room?.remoteParticipants.values;
    if (participants != null) {
      for (final participant in participants) {
        for (final publication in participant.videoTrackPublications) {
          final track = publication.track;
          if (track is VideoTrack && publication.subscribed) {
            nextVideo = track;
            break;
          }
        }
        if (nextVideo != null) break;
      }
    }
    _remoteVideoTrack = nextVideo;
    _applyMuteState();
  }

  void _applyMuteState() {
    final participants = _room?.remoteParticipants.values;
    if (participants == null) return;
    for (final participant in participants) {
      for (final publication in participant.audioTrackPublications) {
        final track = publication.track;
        if (track != null) {
          if (_muted) {
            track.disable();
          } else {
            track.enable();
          }
        }
      }
    }
  }

  void _onDataReceived(DataReceivedEvent event) {
    try {
      final data = jsonDecode(utf8.decode(event.data)) as Map<String, dynamic>;
      if (data['type'] == 'CHAT') {
        setState(() {
          _messages.insert(0, data);
        });
      } else if (data['type'] == 'REACTION') {
        _triggerReaction(data['payload']?.toString() ?? '👍');
      }
    } catch (_) {}
  }

  void _triggerReaction(String emoji) {
    if (!mounted) return;
    final id = '${DateTime.now().microsecondsSinceEpoch}';
    setState(() {
      _floatingReactions.add({'id': id, 'emoji': emoji});
    });
    Future.delayed(const Duration(milliseconds: 1300), () {
      if (mounted) {
        setState(() {
          _floatingReactions.removeWhere((r) => r['id'] == id);
        });
      }
    });
  }

  Future<void> _sendChat() async {
    final text = _chatController.text.trim();
    final sessionId = _resolvedSessionId;
    if (text.isEmpty || _room == null || sessionId == null) return;

    final senderName = _viewerName;
    final senderRole = _viewerRole;
    final payload = {
      'id': 'local-${DateTime.now().millisecondsSinceEpoch}',
      'type': 'CHAT',
      'payload': text,
      'senderName': senderName,
      'senderRole': senderRole,
      'timeLabel': _formatClock(DateTime.now()),
    };

    try {
      await _room!.localParticipant?.publishData(
        utf8.encode(jsonEncode(payload)),
        reliable: true,
        topic: 'chat',
      );
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Không gửi được tin nhắn realtime: $error')),
        );
      }
    }

    try {
      await ref.read(livestreamRepositoryProvider).sendInteraction(
            sessionId: sessionId,
            type: 'CHAT',
            payload: text,
            senderName: senderName,
            senderRole: senderRole,
          );
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Không lưu được tin nhắn: $error')),
        );
      }
    }

    setState(() => _messages.insert(0, payload));
    _chatController.clear();
    if (mounted) {
      FocusScope.of(context).unfocus();
    }
  }

  Future<void> _sendReaction(String reactionKey) async {
    final sessionId = _resolvedSessionId;
    if (_room == null || sessionId == null) return;

    final emoji = _reactions[reactionKey] ?? '👍';
    _triggerReaction(emoji);

    final payload = {
      'id': 'local-${DateTime.now().millisecondsSinceEpoch}',
      'type': 'REACTION',
      'payload': emoji,
      'senderName': _viewerName,
      'senderRole': _viewerRole,
      'timeLabel': _formatClock(DateTime.now()),
    };

    try {
      await _room!.localParticipant?.publishData(
        utf8.encode(jsonEncode(payload)),
        reliable: true,
        topic: 'chat',
      );
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Không gửi được reaction realtime: $error')),
        );
      }
    }

    try {
      await ref.read(livestreamRepositoryProvider).sendInteraction(
            sessionId: sessionId,
            type: 'REACTION',
            payload: reactionKey,
            senderName: _viewerName,
            senderRole: _viewerRole,
          );
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Không lưu được reaction: $error')),
        );
      }
    }
  }

  String _formatDuration(int seconds) {
    final h = seconds ~/ 3600;
    final m = (seconds % 3600) ~/ 60;
    final s = seconds % 60;
    if (h > 0) {
      return '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
    }
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  String _formatClock(DateTime time) {
    return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
  }

  int get _viewerCount => _room?.remoteParticipants.length ?? 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          _buildVideoLayer(),
          if (_phase == _ViewerPhase.connecting) _buildConnectingOverlay(),
          if (_phase == _ViewerPhase.waitingVideo) _buildWaitingOverlay(),
          if (_phase == _ViewerPhase.ended) _buildEndedOverlay(),
          if (_phase == _ViewerPhase.error) _buildErrorOverlay(),
          if (_phase == _ViewerPhase.live ||
              _phase == _ViewerPhase.waitingVideo)
            _buildControlsOverlay(),
          ..._buildFloatingReactions(),
          if (_chatVisible &&
              (_phase == _ViewerPhase.live ||
                  _phase == _ViewerPhase.waitingVideo))
            _buildChatPanel(),
        ],
      ),
    );
  }

  Widget _buildVideoLayer() {
    final track = _remoteVideoTrack;
    if (track == null) {
      return const ColoredBox(color: Color(0xFF0A0E1A));
    }
    return VideoTrackRenderer(track, fit: VideoViewFit.cover);
  }

  Widget _buildConnectingOverlay() {
    return const ColoredBox(
      color: Color(0xFF0A0E1A),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(color: AppTheme.primary),
            SizedBox(height: 16),
            Text(
              'Đang xác thực quyền xem…',
              style: TextStyle(color: Colors.white70, fontSize: 14),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWaitingOverlay() {
    return ColoredBox(
      color: Colors.black.withValues(alpha: 0.55),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(
              width: 48,
              height: 48,
              child: CircularProgressIndicator(
                strokeWidth: 2.5,
                color: Colors.white54,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              widget.title ?? 'Livestream',
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Đang chờ video từ Hướng dẫn viên…',
              style: TextStyle(color: Colors.white60, fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEndedOverlay() {
    return ColoredBox(
      color: const Color(0xFF0A0E1A),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.videocam_off_outlined,
                color: Colors.white38,
                size: 56,
              ),
              const SizedBox(height: 16),
              const Text(
                'Livestream đã kết thúc',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                widget.title ?? 'Phiên phát sóng',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white60, fontSize: 14),
              ),
              const SizedBox(height: 24),
              if (widget.tourId.isNotEmpty)
                FilledButton.icon(
                  onPressed: () {
                    context.pushReplacement(
                      '/livestream/replay',
                      extra: {
                        'tourId': widget.tourId,
                        'title': widget.title ?? 'Livestream',
                      },
                    );
                  },
                  icon: const Icon(Icons.replay_rounded),
                  label: const Text('Xem lại (VOD)'),
                ),
              if (widget.tourId.isNotEmpty) const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: () => context.pop(),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.white70,
                  side: const BorderSide(color: Colors.white24),
                ),
                icon: const Icon(Icons.arrow_back_rounded),
                label: const Text('Quay lại'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildErrorOverlay() {
    return ColoredBox(
      color: const Color(0xFF0A0E1A),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              Align(
                alignment: Alignment.centerLeft,
                child: IconButton(
                  onPressed: () => context.pop(),
                  icon: const Icon(
                    Icons.arrow_back_rounded,
                    color: Colors.white70,
                  ),
                ),
              ),
              const Spacer(),
              Icon(
                _isForbidden
                    ? Icons.lock_outline_rounded
                    : Icons.wifi_off_rounded,
                color: _isForbidden
                    ? AppTheme.accentOrange
                    : AppTheme.accentRed,
                size: 56,
              ),
              const SizedBox(height: 16),
              Text(
                _isForbidden ? 'Không có quyền xem' : 'Không thể kết nối',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                _errorMessage ?? 'Đã xảy ra lỗi không xác định.',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white60,
                  fontSize: 14,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 28),
              if (!_isForbidden)
                FilledButton.icon(
                  onPressed: _connect,
                  icon: const Icon(Icons.refresh_rounded),
                  label: const Text('Thử lại'),
                ),
              const SizedBox(height: 12),
              OutlinedButton(
                onPressed: () => context.pop(),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.white70,
                  side: const BorderSide(color: Colors.white24),
                ),
                child: const Text('Quay lại'),
              ),
              const Spacer(flex: 2),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildControlsOverlay() {
    return SafeArea(
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 8, 16, 0),
            child: Row(
              children: [
                IconButton(
                  onPressed: () => context.pop(),
                  icon: const Icon(
                    Icons.arrow_back_rounded,
                    color: Colors.white,
                  ),
                ),
                Expanded(
                  child: Text(
                    widget.title ?? 'Livestream',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                    ),
                  ),
                ),
                _LiveBadge(duration: _formatDuration(_secondsElapsed)),
                const SizedBox(width: 8),
                _ViewerBadge(count: _viewerCount),
              ],
            ),
          ),
          const Spacer(),
          Padding(
            padding: EdgeInsets.fromLTRB(
              16,
              0,
              16,
              _chatVisible
                  ? MediaQuery.sizeOf(context).height * 0.42 + 12
                  : 20,
            ),
            child: Row(
              children: [
                _CircleControl(
                  icon: _muted ? Iconsax.volume_slash : Iconsax.volume_high,
                  onPressed: () {
                    setState(() => _muted = !_muted);
                    _applyMuteState();
                  },
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: _reactions.entries
                          .map(
                            (entry) => Padding(
                              padding: const EdgeInsets.only(right: 8),
                              child: _ReactionChip(
                                emoji: entry.value,
                                onTap: () => _sendReaction(entry.key),
                              ),
                            ),
                          )
                          .toList(),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                _CircleControl(
                  icon: _chatVisible ? Iconsax.message_text_1 : Iconsax.message,
                  onPressed: () => setState(() => _chatVisible = !_chatVisible),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChatPanel() {
    return Positioned(
      left: 0,
      right: 0,
      bottom: 0,
      child: AnimatedSlide(
        duration: const Duration(milliseconds: 280),
        curve: Curves.easeOutCubic,
        offset: Offset.zero,
        child: Container(
          height: MediaQuery.sizeOf(context).height * 0.42,
          decoration: const BoxDecoration(
            color: Color(0xF0101010),
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
            border: Border(top: BorderSide(color: Colors.white12)),
          ),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 8, 4),
                child: Row(
                  children: [
                    const Text(
                      'Trò chuyện',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        fontSize: 15,
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      onPressed: () => setState(() => _chatVisible = false),
                      icon: const Icon(
                        Icons.keyboard_arrow_down_rounded,
                        color: Colors.white70,
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: _messages.isEmpty
                    ? const Center(
                        child: Text(
                          'Chưa có tin nhắn. Hãy gửi lời chào!',
                          style: TextStyle(color: Colors.white70, fontSize: 13),
                        ),
                      )
                    : ListView.builder(
                        reverse: true,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        itemCount: _messages.length,
                        itemBuilder: (context, index) {
                          final msg = _messages[index];
                          final role = msg['senderRole'] as String?;
                          final isGuide = role == 'TOUR_GUIDE';
                          return Container(
                            margin: const EdgeInsets.only(bottom: 8),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: RichText(
                              text: TextSpan(
                                style: const TextStyle(
                                  fontSize: 13,
                                  height: 1.35,
                                ),
                                children: [
                                  TextSpan(
                                    text: '${_senderLabel(msg)}: ',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w700,
                                      color: isGuide
                                          ? AppTheme.cta
                                          : Colors.white70,
                                    ),
                                  ),
                                  TextSpan(
                                    text: msg['payload']?.toString() ?? '',
                                    style: const TextStyle(color: Colors.white),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
              ),
              Padding(
                padding: EdgeInsets.fromLTRB(
                  16,
                  0,
                  16,
                  12 + MediaQuery.viewPaddingOf(context).bottom,
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _chatController,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                        ),
                        textInputAction: TextInputAction.send,
                        onSubmitted: (_) => _sendChat(),
                        decoration: InputDecoration(
                          hintText: 'Nhập tin nhắn…',
                          hintStyle: const TextStyle(color: Colors.white70),
                          filled: true,
                          fillColor: Colors.white.withValues(alpha: 0.14),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(24),
                            borderSide: BorderSide.none,
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 10,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton.filled(
                      onPressed: _sendChat,
                      icon: const Icon(Icons.send_rounded, size: 20),
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

  List<Widget> _buildFloatingReactions() {
    return _floatingReactions.map((reaction) {
      return Positioned(
        key: ValueKey(reaction['id']),
        left: 24,
        bottom: 180,
        child: TweenAnimationBuilder<double>(
          tween: Tween(begin: 0, end: 1),
          duration: const Duration(milliseconds: 1300),
          builder: (context, value, child) {
            return Transform.translate(
              offset: Offset(0, -value * 120),
              child: Opacity(opacity: 1 - value, child: child),
            );
          },
          child: Text(
            reaction['emoji'] as String,
            style: const TextStyle(fontSize: 42),
          ),
        ),
      );
    }).toList();
  }

  String _senderLabel(Map<String, dynamic> msg) {
    if (msg['senderRole'] == 'TEACHER') return 'Giáo viên';
    if (msg['senderRole'] == 'TOUR_GUIDE') return 'Hướng dẫn viên';
    if (msg['senderRole'] == 'ADMIN') return 'Quản trị viên';
    return msg['senderName']?.toString() ?? 'Khán giả';
  }
}

class _LiveBadge extends StatelessWidget {
  const _LiveBadge({required this.duration});

  final String duration;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: AppTheme.cta,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.circle, color: Colors.white, size: 8),
          const SizedBox(width: 5),
          const Text(
            'LIVE',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w800,
              fontSize: 11,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            duration,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _ViewerBadge extends StatelessWidget {
  const _ViewerBadge({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.black54,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white24),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.remove_red_eye_outlined,
            color: Colors.white70,
            size: 14,
          ),
          const SizedBox(width: 4),
          Text(
            '$count',
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w700,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}

class _CircleControl extends StatelessWidget {
  const _CircleControl({required this.icon, required this.onPressed});

  final IconData icon;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.black54,
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onPressed,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Icon(icon, color: Colors.white, size: 22),
        ),
      ),
    );
  }
}

class _ReactionChip extends StatelessWidget {
  const _ReactionChip({required this.emoji, required this.onTap});

  final String emoji;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.black45,
      borderRadius: BorderRadius.circular(24),
      child: InkWell(
        borderRadius: BorderRadius.circular(24),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Text(emoji, style: const TextStyle(fontSize: 22)),
        ),
      ),
    );
  }
}
