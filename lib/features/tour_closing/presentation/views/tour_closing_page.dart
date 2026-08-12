import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';

import '../../../../app/providers.dart';
import '../../../../core/network/api_exception.dart';
import '../../../../shared/theme/app_theme.dart';
import '../../data/datasources/tour_closing_remote_data_source.dart';
import 'closing_device_scanner_page.dart';

/// WF5 Phase D — Guide closing checklist (auto handover from DROPOFF, GPS QR return).
class TourClosingPage extends ConsumerStatefulWidget {
  const TourClosingPage({super.key, required this.tourId});

  final String tourId;

  @override
  ConsumerState<TourClosingPage> createState() => _TourClosingPageState();
}

class _TourClosingPageState extends ConsumerState<TourClosingPage> {
  Map<String, dynamic>? _checklist;
  Map<String, dynamic>? _ready;
  bool _loading = true;
  bool _busy = false;
  String? _error;
  final _deviceCtrl = TextEditingController();
  bool _showManualDeviceEntry = false;
  bool _completionDialogShown = false;
  bool _pendingCompleteHintShown = false;

  @override
  void initState() {
    super.initState();
    Future.microtask(_load);
  }

  @override
  void dispose() {
    _deviceCtrl.dispose();
    super.dispose();
  }

  String get _checklistStatus =>
      (_checklist?['status']?.toString() ?? '').toUpperCase();

  bool get _isCompleted => _checklistStatus == 'COMPLETED';

  bool get _isReadyToComplete =>
      _checklistStatus == 'READY_TO_COMPLETE' && _ready?['ready'] == true;

  Future<void> _load({bool fromAction = false}) async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final ds = ref.read(tourClosingRemoteDataSourceProvider);
      var checklist = await ds.getChecklist(widget.tourId);
      // Auto-complete runs afterCommit — poll briefly so UI can flip to COMPLETED.
      checklist = await _pollUntilCompletedOrSettle(ds, checklist);
      Map<String, dynamic>? ready;
      try {
        ready = await ds.getReadyCheck(widget.tourId);
      } catch (_) {
        ready = null;
      }
      if (!mounted) return;
      setState(() {
        _checklist = checklist;
        _ready = ready;
      });
      await _afterChecklistLoaded(fromAction: fromAction);
    } on Object catch (e) {
      if (!mounted) return;
      setState(() {
        _error = _friendlyErrorMessage(e);
      });
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<Map<String, dynamic>> _pollUntilCompletedOrSettle(
    TourClosingRemoteDataSource ds,
    Map<String, dynamic> checklist,
  ) async {
    var current = checklist;
    final status = (current['status']?.toString() ?? '').toUpperCase();
    if (status == 'COMPLETED' || status != 'READY_TO_COMPLETE') {
      return current;
    }
    for (var i = 0; i < 4; i++) {
      await Future<void>.delayed(Duration(milliseconds: 350 + i * 150));
      if (!mounted) return current;
      try {
        current = await ds.getChecklist(widget.tourId);
      } catch (_) {
        return current;
      }
      if ((current['status']?.toString() ?? '').toUpperCase() == 'COMPLETED') {
        return current;
      }
    }
    return current;
  }

  Future<void> _afterChecklistLoaded({required bool fromAction}) async {
    if (!mounted) return;
    if (_isCompleted) {
      if (!_completionDialogShown) {
        _completionDialogShown = true;
        await _showTourCompletedDialog();
      }
      return;
    }
    if (_isReadyToComplete && fromAction && !_pendingCompleteHintShown) {
      _pendingCompleteHintShown = true;
      await _showInfoPopup(
        title: 'Đang hoàn tất tour…',
        message:
            'Checklist đã đủ điều kiện. Hệ thống đang tự khóa tour. '
            'Nếu sau khi Refresh vẫn chưa thấy “Đã hoàn tất”, hãy liên hệ Operator trên Web.',
      );
    }
  }

  Future<void> _showTourCompletedDialog() async {
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        icon: Icon(
          Icons.check_circle_outline_rounded,
          color: Colors.green.shade700,
          size: 40,
        ),
        title: const Text('Tour đã hoàn tất', textAlign: TextAlign.center),
        content: const Text(
          'Checklist đóng tour đã khóa.\n'
          'Báo cáo / Word do Operator trên Web (tab Đóng tour).',
          textAlign: TextAlign.center,
        ),
        actionsAlignment: MainAxisAlignment.center,
        actions: [
          FilledButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              if (!mounted) return;
              context.go('/guide/dashboard');
            },
            child: const Text('Về màn hình chính'),
          ),
        ],
      ),
    );
  }

  Future<void> _run(
    Future<void> Function() action, {
    String? okSnackMsg,
    String? okPopupTitle,
    String? okPopupMessage,
  }) async {
    setState(() => _busy = true);
    try {
      await action();
      if (!mounted) return;
      await _load(fromAction: true);
      if (!mounted) return;
      if (_isCompleted) {
        // Success dialog handled in _afterChecklistLoaded.
        return;
      }
      if (okPopupTitle != null && okPopupMessage != null) {
        await _showInfoPopup(
          title: okPopupTitle,
          message: okPopupMessage,
          isError: false,
        );
      } else if (okSnackMsg != null) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(SnackBar(content: Text(okSnackMsg)));
      }
    } on Object catch (e) {
      if (!mounted) return;
      await _showErrorPopup(e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _scanDeviceQr() async {
    if (_isCompleted || _devicesFullyReturned()) return;
    final payload = await Navigator.of(context).push<String>(
      MaterialPageRoute(builder: (_) => const ClosingDeviceScannerPage()),
    );
    if (payload == null || payload.isEmpty || !mounted) return;
    await _run(
      () async {
        await ref
            .read(tourClosingRemoteDataSourceProvider)
            .returnDevices(widget.tourId, qrPayload: payload);
      },
      okPopupTitle: 'Thu hồi thành công',
      okPopupMessage: 'Đã thu hồi thiết bị GPS thành công.',
    );
  }

  Future<void> _returnManualCodes() async {
    if (_isCompleted || _devicesFullyReturned()) return;
    final codes = _deviceCtrl.text
        .split(RegExp(r'[,;\s]+'))
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();
    if (codes.isEmpty) {
      await _showInfoPopup(
        title: 'Chưa nhập mã',
        message: 'Vui lòng nhập mã thiết bị GPS trước khi thu hồi.',
      );
      return;
    }
    await _run(
      () async {
        await ref
            .read(tourClosingRemoteDataSourceProvider)
            .returnDevices(widget.tourId, deviceCodes: codes);
        _deviceCtrl.clear();
      },
      okPopupTitle: 'Thu hồi thành công',
      okPopupMessage: codes.length == 1
          ? 'Đã thu hồi thiết bị GPS thành công.'
          : 'Đã thu hồi ${codes.length} thiết bị GPS thành công.',
    );
  }

  ApiException? _asApiException(Object error) {
    final existing = ApiException.maybeFrom(error);
    if (existing != null) return existing;
    if (error is DioException) {
      return ApiException.fromDioException(error);
    }
    return null;
  }

  String? _apiErrorCode(ApiException? error) {
    final details = error?.details;
    if (details is Map) {
      return details['code']?.toString() ??
          details['errorCode']?.toString();
    }
    return null;
  }

  String _friendlyErrorMessage(Object error) {
    final api = _asApiException(error);
    final code = _apiErrorCode(api);
    final raw = (api?.message ?? error.toString())
        .replaceFirst(RegExp(r'^DioException\s*\[[^\]]*\]:\s*'), '')
        .replaceFirst('Exception: ', '')
        .trim();

    switch (code) {
      case 'CLS-007':
        return 'Tour chưa khởi hành nên chưa mở được phần đóng tour. '
            'Chức năng này chỉ dùng khi tour đang diễn ra hoặc đã hoàn thành.';
      case 'CLS-015':
        return 'Không nhận diện được mã QR thiết bị. '
            'Hãy quét lại mã trên thiết bị GPS hoặc nhập mã thủ công.';
      case 'CLS-016':
        return 'Thiết bị này không thuộc tour hiện tại. '
            'Chỉ quét / nhập mã GPS đã gắn cho xe trong tour này.';
      case 'CLS-005':
        return 'Vui lòng quét QR hoặc nhập mã thiết bị GPS.';
    }

    if (raw.toLowerCase().contains('không thuộc tour') ||
        raw.toLowerCase().contains('khong thuoc tour')) {
      return 'Thiết bị này không thuộc tour hiện tại. '
          'Chỉ quét / nhập mã GPS đã gắn cho xe trong tour này.';
    }
    if (raw.toLowerCase().contains('không hợp lệ') ||
        raw.toLowerCase().contains('không nhận diện')) {
      return 'Không nhận diện được mã QR thiết bị. '
          'Hãy quét lại hoặc nhập mã thủ công.';
    }
    if (raw.isNotEmpty) return raw;
    return 'Không thể thu hồi thiết bị. Vui lòng thử lại.';
  }

  String _errorTitle(Object error) {
    final api = _asApiException(error);
    final code = _apiErrorCode(api);
    final raw = (api?.message ?? error.toString()).toLowerCase();
    if (code == 'CLS-016' || raw.contains('không thuộc tour')) {
      return 'Thiết bị không thuộc tour';
    }
    if (code == 'CLS-015' ||
        raw.contains('không hợp lệ') ||
        raw.contains('không nhận diện')) {
      return 'Quét QR không thành công';
    }
    return 'Không thể thu hồi GPS';
  }

  Future<void> _showErrorPopup(Object error) async {
    await _showInfoPopup(
      title: _errorTitle(error),
      message: _friendlyErrorMessage(error),
      isError: true,
    );
  }

  Future<void> _showInfoPopup({
    required String title,
    required String message,
    bool isError = false,
  }) async {
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        icon: Icon(
          isError
              ? Icons.error_outline_rounded
              : Icons.check_circle_outline_rounded,
          color: isError ? Colors.red.shade700 : Colors.green.shade700,
          size: 40,
        ),
        title: Text(title, textAlign: TextAlign.center),
        content: Text(message, textAlign: TextAlign.center),
        actionsAlignment: MainAxisAlignment.center,
        actions: [
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(isError ? 'Đã hiểu' : 'OK'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final gates = (_checklist?['gates'] as Map?)?.cast<String, dynamic>() ?? {};
    final hard = (_ready?['hardGates'] as Map?)?.cast<String, dynamic>() ??
        {
          'finalAttendance': gates['finalAttendance']?['ok'] == true,
          'handover': gates['handover']?['ok'] == true,
          'devices': gates['devices']?['ok'] == true,
          'incidents': gates['incidents']?['ok'] == true,
        };
    final readOnly = _isCompleted;

    return Scaffold(
      backgroundColor: AppTheme.surfaceLight,
      appBar: AppBar(
        title: const Text('Đóng tour', style: TextStyle(fontWeight: FontWeight.w700)),
        backgroundColor: AppTheme.surface,
        actions: [
          IconButton(
            icon: const Icon(Iconsax.refresh),
            onPressed: _busy ? null : () => _load(fromAction: true),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: () => _load(fromAction: true),
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  if (_error != null)
                    Card(
                      color: Colors.red.shade50,
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Text(_error!, style: TextStyle(color: Colors.red.shade900)),
                      ),
                    ),
                  if (_isCompleted) ...[
                    _StatusBanner(
                      color: Colors.green,
                      title: 'Tour đã hoàn tất',
                      body:
                          'Checklist đóng tour đã khóa. Báo cáo / Word do Operator trên Web (tab Đóng tour).',
                      actionLabel: 'Về màn hình chính',
                      onAction: () => context.go('/guide/dashboard'),
                    ),
                    const SizedBox(height: 12),
                  ] else if (_isReadyToComplete) ...[
                    _StatusBanner(
                      color: Colors.orange,
                      title: 'Đang hoàn tất tour…',
                      body:
                          'Checklist đã xanh. Hệ thống đang tự Complete. '
                          'Bấm Refresh nếu chưa thấy trạng thái Đã hoàn tất — '
                          'nếu vẫn chưa, liên hệ Operator trên Web.',
                      actionLabel: 'Refresh',
                      onAction: _busy ? null : () => _load(fromAction: true),
                    ),
                    const SizedBox(height: 12),
                  ],
                  Text(
                    'Tour: ${widget.tourId}',
                    style: const TextStyle(fontSize: 12, color: Colors.black54),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Checklist: ${_checklist?['status'] ?? '—'} · Ready: ${_ready?['ready'] == true ? 'Có' : 'Chưa'}',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 12),
                  ..._displayGates(hard).entries.map(
                    (e) => ListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      leading: Icon(
                        e.value == true ? Iconsax.tick_circle : Iconsax.close_circle,
                        color: e.value == true ? Colors.green : Colors.orange,
                      ),
                      title: Text(_gateLabel(e.key)),
                      subtitle: Text(_gateSubtitle(e.key)),
                    ),
                  ),
                  const Divider(height: 32),
                  const Text(
                    'Bàn giao học sinh',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _handoverDetailText(),
                    style: const TextStyle(fontSize: 13, color: Colors.black54),
                  ),
                  const Divider(height: 32),
                  const Text('Thu hồi GPS', style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Text(
                    _devicesDetailText(),
                    style: const TextStyle(fontSize: 13, color: Colors.black54),
                  ),
                  const SizedBox(height: 12),
                  if (_devicesFullyReturned())
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.green.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.green.shade200),
                      ),
                      child: const Text(
                        'Đã thu hồi đủ thiết bị GPS — không cần quét QR hay nhập mã thêm.',
                        style: TextStyle(fontSize: 13, color: Colors.black87),
                      ),
                    )
                  else if (!readOnly) ...[
                    FilledButton.icon(
                      onPressed: _busy ? null : _scanDeviceQr,
                      icon: const Icon(Icons.qr_code_scanner),
                      label: const Text('Quét QR thiết bị'),
                    ),
                    const SizedBox(height: 8),
                    TextButton(
                      onPressed: _busy
                          ? null
                          : () => setState(
                                () => _showManualDeviceEntry =
                                    !_showManualDeviceEntry,
                              ),
                      child: Text(
                        _showManualDeviceEntry
                            ? 'Ẩn nhập mã thủ công'
                            : 'Không quét được? Nhập mã thiết bị',
                      ),
                    ),
                    if (_showManualDeviceEntry) ...[
                      const SizedBox(height: 8),
                      TextField(
                        controller: _deviceCtrl,
                        enabled: !_busy,
                        decoration: const InputDecoration(
                          labelText: 'Mã thiết bị (phẩy / xuống dòng)',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 8),
                      FilledButton.tonal(
                        onPressed: _busy ? null : _returnManualCodes,
                        child: const Text('Thu hồi theo mã'),
                      ),
                    ],
                  ],
                  if (!readOnly) ...[
                    const SizedBox(height: 8),
                    OutlinedButton(
                      onPressed: _busy
                          ? null
                          : () => _run(
                                () async {
                                  await ref
                                      .read(tourClosingRemoteDataSourceProvider)
                                      .refreshIncidents(widget.tourId);
                                },
                                okSnackMsg: 'Đã refresh sự cố',
                              ),
                      child: const Text('Refresh sự cố'),
                    ),
                  ],
                  const SizedBox(height: 24),
                  Text(
                    readOnly
                        ? 'Tour đã khóa. Báo cáo / Word do Operator trên Web (tab Đóng tour).'
                        : 'Tour tự Complete khi checklist xanh hết. Báo cáo / Word do Operator trên Web (tab Đóng tour).',
                    style: const TextStyle(fontSize: 12, color: Colors.black54),
                  ),
                ],
              ),
            ),
    );
  }

  /// Merge finalAttendance + handover into one UX gate.
  Map<String, bool> _displayGates(Map hard) {
    final handoverOk = hard['handover'] == true;
    final finalOk = hard['finalAttendance'] == true;
    return {
      'studentHandover': handoverOk && finalOk,
      'devices': hard['devices'] == true,
      'incidents': hard['incidents'] == true,
    };
  }

  String _gateSubtitle(String key) {
    switch (key) {
      case 'studentHandover':
        return _handoverSubtitle();
      case 'devices':
        return _devicesSubtitle();
      default:
        return '';
    }
  }

  String _handoverSubtitle() {
    final vehicles = _vehicleEntries();
    if (vehicles.isEmpty) return 'Chưa có xe trên checklist';
    final dropoffDone =
        vehicles.where((v) => _isDropoffConfirmed(v)).length;
    return '$dropoffDone/${vehicles.length} xe đã hoàn thành DROPOFF';
  }

  String _devicesSubtitle() {
    final devices = _deviceEntries();
    if (devices.isEmpty) {
      final expected = _expectedCodes();
      if (expected.isEmpty) return 'Không có GPS trên tour';
      final returned = _returnedCodes();
      return '${returned.length}/${expected.length} thiết bị đã thu hồi thành công';
    }
    final done = devices.where((d) => d['returned'] == true).length;
    return '$done/${devices.length} thiết bị đã thu hồi thành công';
  }

  /// True when devices gate is OK or every expected device is already returned.
  bool _devicesFullyReturned() {
    final gates = (_checklist?['gates'] as Map?)?.cast<String, dynamic>() ?? {};
    if (gates['devices']?['ok'] == true) return true;

    final devices = _deviceEntries();
    if (devices.isNotEmpty) {
      return devices.every((d) => d['returned'] == true);
    }
    final expected = _expectedCodes();
    if (expected.isEmpty) return true;
    final returned = _returnedCodes().toSet();
    return expected.every((c) => returned.contains(c.toUpperCase()));
  }

  String _handoverDetailText() {
    final vehicles = _vehicleEntries();
    if (vehicles.isEmpty) {
      return 'Chưa có xe. Gate sẽ tự xanh khi mọi Guide hoàn thành điểm danh + DROPOFF của xe mình.';
    }
    final lines = vehicles.map((v) {
      final label = _vehicleDisplayLabel(v);
      if (_isDropoffConfirmed(v)) return '✓ $label (DROPOFF)';
      if (v['confirmed'] == true) return '✓ $label (thủ công — không tính DROPOFF)';
      return '○ $label';
    });
    return 'Chỉ tích DROPOFF khi Guide hoàn thành mốc Trả HS:\n${lines.join('\n')}';
  }

  String _devicesDetailText() {
    final devices = _deviceEntries();
    if (devices.isEmpty) {
      final expected = _expectedCodes();
      if (expected.isEmpty) {
        return 'Tour không có thiết bị GPS — gate Thu hồi GPS tự đạt.';
      }
      final returned = _returnedCodes().toSet();
      final lines = expected.map((code) {
        return returned.contains(code.toUpperCase()) ? '✓ $code' : '○ $code';
      });
      return 'Quét QR (hoặc nhập mã) từng thiết bị của tour:\n${lines.join('\n')}';
    }
    final lines = devices.map((d) {
      final label = (d['label']?.toString().trim().isNotEmpty == true)
          ? d['label'].toString()
          : (d['deviceCode']?.toString() ?? 'Thiết bị');
      if (d['returned'] == true) {
        final source = d['returnedSource']?.toString().toUpperCase();
        final tag = source == 'QR' ? 'QR' : 'thủ công';
        return '✓ $label ($tag)';
      }
      return '○ $label';
    });
    return 'Quét QR thiết bị đúng tour để tự tích; nhập mã nếu không quét được:\n${lines.join('\n')}';
  }

  bool _isDropoffConfirmed(Map<String, dynamic> v) {
    final source = v['confirmedSource']?.toString().toUpperCase();
    return v['confirmed'] == true && source == 'DROPOFF';
  }

  String _vehicleDisplayLabel(Map<String, dynamic> v) {
    final label = v['label']?.toString().trim();
    final plate = v['plateNumber']?.toString().trim();
    if (label != null && label.isNotEmpty) {
      if (plate != null &&
          plate.isNotEmpty &&
          !label.toUpperCase().contains(plate.toUpperCase())) {
        return '$label: $plate';
      }
      return label;
    }
    if (plate != null && plate.isNotEmpty) return plate;
    return v['operationVehicleId']?.toString() ?? 'Xe';
  }

  List<Map<String, dynamic>> _vehicleEntries() {
    final gates = (_checklist?['gates'] as Map?)?.cast<String, dynamic>() ?? {};
    final raw = ((gates['handover'] as Map?)?['byVehicle'] as List?) ?? const [];
    return raw
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
  }

  List<Map<String, dynamic>> _deviceEntries() {
    final gates = (_checklist?['gates'] as Map?)?.cast<String, dynamic>() ?? {};
    final raw = ((gates['devices'] as Map?)?['byDevice'] as List?) ?? const [];
    return raw
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
  }

  List<String> _expectedCodes() {
    final gates = (_checklist?['gates'] as Map?)?.cast<String, dynamic>() ?? {};
    final raw = ((gates['devices'] as Map?)?['expectedCodes'] as List?) ?? const [];
    return raw.map((e) => e.toString()).toList();
  }

  List<String> _returnedCodes() {
    final gates = (_checklist?['gates'] as Map?)?.cast<String, dynamic>() ?? {};
    final raw = ((gates['devices'] as Map?)?['returnedCodes'] as List?) ?? const [];
    return raw.map((e) => e.toString().toUpperCase()).toList();
  }

  String _gateLabel(String code) {
    switch (code) {
      case 'studentHandover':
        return 'Bàn giao học sinh';
      case 'devices':
        return 'Thu hồi GPS';
      case 'incidents':
        return 'Sự cố đã chốt';
      default:
        return code;
    }
  }
}

class _StatusBanner extends StatelessWidget {
  const _StatusBanner({
    required this.color,
    required this.title,
    required this.body,
    this.actionLabel,
    this.onAction,
  });

  final MaterialColor color;
  final String title;
  final String body;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.shade50,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontWeight: FontWeight.w800,
              color: color.shade900,
              fontSize: 15,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            body,
            style: TextStyle(fontSize: 13, color: color.shade900, height: 1.35),
          ),
          if (actionLabel != null && onAction != null) ...[
            const SizedBox(height: 10),
            Align(
              alignment: Alignment.centerLeft,
              child: FilledButton(
                onPressed: onAction,
                style: FilledButton.styleFrom(
                  backgroundColor: color.shade700,
                ),
                child: Text(actionLabel!),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
