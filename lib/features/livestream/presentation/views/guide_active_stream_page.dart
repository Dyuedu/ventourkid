import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart' as rtc;
import 'package:go_router/go_router.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import 'package:livekit_client/livekit_client.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../../../../app/providers.dart';

class GuideActiveStreamPage extends ConsumerStatefulWidget {
  const GuideActiveStreamPage({
    super.key,
    required this.tourId,
    required this.title,
    this.preInitVideoTrack,
    this.preInitAudioTrack,
  });

  final String tourId;
  final String title;
  final LocalVideoTrack? preInitVideoTrack;
  final LocalAudioTrack? preInitAudioTrack;

  @override
  ConsumerState<GuideActiveStreamPage> createState() => _GuideActiveStreamPageState();
}

class _GuideActiveStreamPageState extends ConsumerState<GuideActiveStreamPage> {
  Room? _room;
  bool _isMicEnabled = true;
  bool _isCameraEnabled = true;
  bool _isEndingStream = false;
  bool _isChatVisible = true;
  Offset _chatTogglePosition = const Offset(300, 300); // Default position
  LocalVideoTrack? _localVideoTrack;
  LocalAudioTrack? _localAudioTrack;
  Timer? _durationTimer;
  int _secondsElapsed = 0;
  int _maxViewers = 0;
  late EventsListener<RoomEvent> _listener;
  final List<Map<String, dynamic>> _messages = [];
  final List<Map<String, dynamic>> _floatingReactions = [];
  final TextEditingController _chatController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _localVideoTrack = widget.preInitVideoTrack;
    _localAudioTrack = widget.preInitAudioTrack;
    WakelockPlus.enable();
    _connectToLiveKit();
    _durationTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        setState(() {
          _secondsElapsed++;
        });
      }
    });
  }

  @override
  void dispose() {
    _durationTimer?.cancel();
    _chatController.dispose();
    if (_room != null) {
      _listener.dispose();
    }
    _room?.disconnect();
    WakelockPlus.disable();
    super.dispose();
  }

  Future<void> _connectToLiveKit() async {
    final state = ref.read(livestreamViewModelProvider);
    if (state.token == null) return;

    try {
      _room = Room();
      
      final livekitUrl = state.wsUrl ?? 'ws://10.0.2.2:7880';
      
      await _room!.connect(livekitUrl, state.token!);
      
      if (_localVideoTrack != null) {
        await _room!.localParticipant?.publishVideoTrack(
          _localVideoTrack!,
          publishOptions: const VideoPublishOptions(
            videoEncoding: VideoEncoding(maxBitrate: 4000000, maxFramerate: 30),
            simulcast: false, // Tắt simulcast để ép server giữ nguyên 1080p
          ),
        );
      } else {
        await _room!.localParticipant?.setCameraEnabled(true);
      }
      
      if (_localAudioTrack != null) {
        await _room!.localParticipant?.publishAudioTrack(_localAudioTrack!);
      } else {
        await _room!.localParticipant?.setMicrophoneEnabled(true);
      }
      
      setState(() {
        final firstTrack = _room!.localParticipant?.videoTrackPublications.firstOrNull?.track;
        if (firstTrack is LocalVideoTrack) {
          _localVideoTrack ??= firstTrack;
        }
      });
      
      _room!.addListener(_onRoomStateChanged);
      _room!.localParticipant?.addListener(_onRoomStateChanged);
      
      _listener = _room!.createListener();
      _listener.on<DataReceivedEvent>((event) {
        final dataStr = utf8.decode(event.data);
        try {
          final data = jsonDecode(dataStr);
          if (data['type'] == 'CHAT') {
            setState(() {
              _messages.insert(0, data);
            });
          } else if (data['type'] == 'REACTION') {
            _triggerReaction(data['payload']);
          }
        } catch (e) {
          debugPrint('Failed to parse incoming data: $e');
        }
      });
    } catch (e) {
      debugPrint('LiveKit Connection Error: $e');
    }
  }

  void _onRoomStateChanged() {
    if (mounted) {
      setState(() {
        final firstTrack = _room?.localParticipant?.videoTrackPublications.firstOrNull?.track;
        if (firstTrack is LocalVideoTrack) {
          _localVideoTrack ??= firstTrack;
        }
        final currentViewers = _room?.remoteParticipants.length ?? 0;
        if (currentViewers > _maxViewers) {
          _maxViewers = currentViewers;
        }
      });
    }
  }

  void _triggerReaction(String emoji) {
    if (!mounted) return;
    final id = DateTime.now().millisecondsSinceEpoch.toString() + (DateTime.now().microsecond.toString());
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

  Future<void> _endStream() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Kết thúc phát sóng?'),
        content: const Text('Bạn có chắc chắn muốn dừng livestream ngay bây giờ không?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Hủy'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Kết thúc', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      setState(() {
        _isEndingStream = true;
      });
      await ref.read(livestreamViewModelProvider.notifier).stopLivestream(widget.tourId);
      if (mounted) {
        setState(() {
          _isEndingStream = false;
        });
        context.pushReplacement('/livestream/summary', extra: {
          'durationSeconds': _secondsElapsed,
          'title': widget.title,
          'maxViewers': _maxViewers,
          'tourId': widget.tourId,
        });
      }
    }
  }

  void _toggleMic() {
    if (_room?.localParticipant == null) return;
    setState(() {
      _isMicEnabled = !_isMicEnabled;
    });
    _room!.localParticipant!.setMicrophoneEnabled(_isMicEnabled);
  }

  void _toggleCamera() {
    if (_room?.localParticipant == null) return;
    setState(() {
      _isCameraEnabled = !_isCameraEnabled;
    });
    _room!.localParticipant!.setCameraEnabled(_isCameraEnabled);
  }
  
  void _switchCamera() async {
     if (_localVideoTrack != null && _localVideoTrack is LocalVideoTrack) {
        try {
          await rtc.Helper.switchCamera(_localVideoTrack!.mediaStreamTrack);
        } catch (e) {
          debugPrint('Switch camera error: $e');
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

  String _getRoleLabel(String? role) {
    if (role == null || role == 'PARENT' || role == 'ADMIN') return '';
    switch (role) {
      case 'TOUR_MANAGER': return ' (QUẢN LÝ TOUR)';
      case 'TOUR_GUIDE': return ' (HƯỚNG DẪN VIÊN)';
      case 'SALES_STAFF': return ' (NHÂN VIÊN SALE)';
      case 'TOUR_OPERATOR_STAFF': return ' (ĐIỀU HÀNH TOUR)';
      case 'TEACHER': return ' (GIÁO VIÊN)';
      default: return ' ($role)';
    }
  }

  Future<void> _sendChat() async {
    final text = _chatController.text.trim();
    if (text.isEmpty || _room == null) return;
    
    final senderName = 'Hướng dẫn viên';

    final payload = {
      'type': 'CHAT',
      'payload': text,
      'senderName': senderName,
      'senderRole': 'TOUR_GUIDE',
      'timeLabel': '${DateTime.now().hour.toString().padLeft(2, '0')}:${DateTime.now().minute.toString().padLeft(2, '0')}'
    };
    
    try {
      await _room!.localParticipant?.publishData(
        utf8.encode(jsonEncode(payload)),
        reliable: true,
        topic: 'chat',
      );
    } catch (e) {
      debugPrint('Failed to send data: $e');
    }
    
    ref.read(livestreamViewModelProvider.notifier).sendInteraction('CHAT', text, senderName: senderName, senderRole: 'TOUR_GUIDE');
    
    setState(() {
      _messages.insert(0, payload);
    });
    _chatController.clear();
    FocusScope.of(context).unfocus();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Camera Preview
          if (_localVideoTrack != null && _isCameraEnabled)
            VideoTrackRenderer(_localVideoTrack!)
          else
            const Center(
              child: Icon(Icons.videocam_off, size: 64, color: Colors.white54),
            ),

          // Overlays
          SafeArea(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Top Bar
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Bên trái: badge LIVE + thời gian + số người xem
                      Row(
                        children: [
                          // Badge LIVE + duration
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: Colors.redAccent,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.circle, color: Colors.white, size: 10),
                                const SizedBox(width: 6),
                                const Text(
                                  'LIVE',
                                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  _formatDuration(_secondsElapsed),
                                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w500),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          // Badge số người xem
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              color: Colors.black54,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: Colors.white24, width: 1),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.remove_red_eye_outlined, color: Colors.white70, size: 14),
                                const SizedBox(width: 5),
                                Text(
                                  '${_room?.remoteParticipants.length ?? 0}',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 13,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      // Bên phải: nút đổi camera
                      IconButton(
                        icon: const Icon(Icons.flip_camera_ios, color: Colors.white),
                        onPressed: _switchCamera,
                      ),
                    ],
                  ),
                ),

                // Bottom Controls
                Padding(
                  padding: const EdgeInsets.only(bottom: 32.0, left: 16, right: 16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _buildControlButton(
                        icon: _isMicEnabled ? Iconsax.microphone_2 : Iconsax.microphone_slash,
                        color: _isMicEnabled ? Colors.white24 : Colors.redAccent,
                        onPressed: _toggleMic,
                      ),
                      GestureDetector(
                        onTap: _endStream,
                        child: Container(
                          width: 64,
                          height: 64,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.redAccent, width: 4),
                          ),
                          child: Center(
                            child: Container(
                              width: 24,
                              height: 24,
                              decoration: BoxDecoration(
                                color: Colors.redAccent,
                                borderRadius: BorderRadius.circular(4),
                              ),
                            ),
                          ),
                        ),
                      ),
                      _buildControlButton(
                        icon: _isCameraEnabled ? Iconsax.video : Icons.videocam_off,
                        color: _isCameraEnabled ? Colors.white24 : Colors.redAccent,
                        onPressed: _toggleCamera,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Floating Reactions
          ..._floatingReactions.map((r) => Positioned(
            key: ValueKey(r['id']),
            bottom: 250,
            left: 20,
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: 0.0, end: 1.0),
              duration: const Duration(milliseconds: 1300),
              builder: (context, value, child) {
                return Transform.translate(
                  offset: Offset(0, -value * 100),
                  child: Opacity(
                    opacity: 1.0 - value,
                    child: child,
                  ),
                );
              },
              child: Text(r['emoji'], style: const TextStyle(fontSize: 40)),
            ),
          )),

          // Chat Visibility Toggle Button (Draggable)
          Positioned(
            left: _chatTogglePosition.dx,
            top: _chatTogglePosition.dy,
            child: GestureDetector(
              onPanUpdate: (details) {
                setState(() {
                  _chatTogglePosition += details.delta;
                });
              },
              child: Container(
                decoration: const BoxDecoration(
                  color: Colors.black45,
                  shape: BoxShape.circle,
                ),
                child: IconButton(
                  icon: Icon(
                    _isChatVisible ? Icons.speaker_notes_off : Icons.speaker_notes,
                    color: Colors.white,
                    size: 20,
                  ),
                  onPressed: () {
                    setState(() {
                      _isChatVisible = !_isChatVisible;
                    });
                  },
                ),
              ),
            ),
          ),

          // Chat Overlay
          Positioned(
            left: 16,
            right: 16,
            bottom: 120, // Above bottom controls
            height: 250,
            child: AnimatedSlide(
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeInOut,
              offset: _isChatVisible ? Offset.zero : const Offset(-1.5, 0),
              child: AnimatedOpacity(
                duration: const Duration(milliseconds: 300),
                opacity: _isChatVisible ? 1.0 : 0.0,
                child: IgnorePointer(
                  ignoring: !_isChatVisible,
                  child: Column(
                    children: [
                      Expanded(
                  child: ListView.builder(
                    reverse: true,
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    itemCount: _messages.length,
                    itemBuilder: (context, index) {
                      final msg = _messages[index];
                      return Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: Colors.black54,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${msg['senderRole'] == 'ADMIN' ? 'Quản trị viên' : msg['senderName'] == 'Hướng dẫn viên' && msg['senderRole'] == 'TOUR_GUIDE' ? 'Hướng dẫn viên' : '${msg['senderName']}${_getRoleLabel(msg['senderRole'])}'}: ',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: msg['senderRole'] == 'TOUR_GUIDE' 
                                    ? Colors.redAccent 
                                    : msg['senderRole'] == 'ADMIN' 
                                        ? Colors.orangeAccent 
                                        : Colors.white70,
                                fontSize: 13,
                              ),
                            ),
                            Expanded(
                              child: Text(
                                msg['payload'] ?? '',
                                style: const TextStyle(color: Colors.white, fontSize: 13),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
                // Chat input
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.transparent,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: Colors.white30),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _chatController,
                          style: const TextStyle(color: Colors.white, fontSize: 14),
                          decoration: const InputDecoration(
                            filled: false,
                            fillColor: Colors.transparent,
                            hintText: 'Nhập tin nhắn...',
                            hintStyle: TextStyle(color: Colors.white54),
                            border: InputBorder.none,
                            enabledBorder: InputBorder.none,
                            focusedBorder: InputBorder.none,
                            errorBorder: InputBorder.none,
                            focusedErrorBorder: InputBorder.none,
                            disabledBorder: InputBorder.none,
                            contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          ),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.send, color: Colors.blueAccent),
                        onPressed: _sendChat,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
      
      // Loading Overlay
          if (_isEndingStream)
            Container(
              color: Colors.black87,
              child: const Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(color: Colors.redAccent),
                    SizedBox(height: 16),
                    Text(
                      'Đang kết thúc luồng phát sóng...',
                      style: TextStyle(color: Colors.white, fontSize: 16),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildControlButton({
    required IconData icon,
    required Color color,
    required VoidCallback onPressed,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
      ),
      child: IconButton(
        icon: Icon(icon, color: Colors.white),
        onPressed: onPressed,
      ),
    );
  }
}
