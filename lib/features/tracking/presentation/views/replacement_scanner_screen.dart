import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../../../core/network/api_exception.dart';
import '../../../../shared/widgets/app_back_leading.dart';
import '../../providers.dart';

class ReplacementScannerScreen extends ConsumerStatefulWidget {
  const ReplacementScannerScreen({
    super.key,
    required this.assignmentId,
    required this.targetLabel,
    required this.targetType,
  });

  final String assignmentId;
  final String targetLabel;
  final String targetType;

  @override
  ConsumerState<ReplacementScannerScreen> createState() =>
      _ReplacementScannerScreenState();
}

class _ReplacementScannerScreenState
    extends ConsumerState<ReplacementScannerScreen> {
  final _scanner = MobileScannerController(formats: const [BarcodeFormat.qrCode]);
  final _reasonController = TextEditingController();
  String? _qrPayload;
  Map<String, dynamic>? _preview;
  String? _error;
  bool _busy = false;

  @override
  void dispose() {
    _scanner.dispose();
    _reasonController.dispose();
    super.dispose();
  }

  Future<void> _detected(BarcodeCapture capture) async {
    if (_busy || _qrPayload != null) return;
    final payload = capture.barcodes.isEmpty
        ? null
        : capture.barcodes.first.rawValue?.trim();
    if (payload == null || payload.isEmpty) return;
    await _scanner.stop();
    if (!mounted) return;
    setState(() {
      _busy = true;
      _error = null;
      _qrPayload = payload;
    });
    try {
      final preview = await ref
          .read(trackingRemoteDataSourceProvider)
          .previewReplacement(widget.assignmentId, payload);
      if (!mounted) return;
      final compatible = preview['compatible'] == true;
      setState(() {
        _preview = preview;
        _busy = false;
        _error = compatible ? null : 'Thiết bị quét được không đủ điều kiện để thay thế.';
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = ApiException.userMessage(
          error,
          fallback: 'Không đọc được QR thiết bị. Vui lòng quét lại.',
        );
      });
    }
  }

  Future<void> _scanAgain() async {
    setState(() {
      _qrPayload = null;
      _preview = null;
      _error = null;
    });
    await _scanner.start();
  }

  Future<void> _confirm() async {
    final payload = _qrPayload;
    final compatible = _preview?['compatible'] == true;
    final reason = _reasonController.text.trim();
    if (payload == null || !compatible || reason.isEmpty) return;
    setState(() => _busy = true);
    try {
      await ref.read(trackingRemoteDataSourceProvider).replaceDevice(
            assignmentId: widget.assignmentId,
            qrPayload: payload,
            reason: reason,
          );
      if (mounted) Navigator.of(context).pop(true);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = ApiException.userMessage(
          error,
          fallback: 'Không thay được thiết bị. Vui lòng thử lại.',
        );
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final preview = _preview;
    final compatible = preview?['compatible'] == true;
    return Scaffold(
      appBar: AppBar(
        leading: buildAppBackLeading(context),
        title: const Text('Thay thiết bị GPS'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            'Đang thay GPS cho ${widget.targetType}: ${widget.targetLabel}',
            style: Theme.of(context).textTheme.titleSmall,
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: SizedBox(
              height: 260,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  MobileScanner(controller: _scanner, onDetect: _detected),
                  Center(
                    child: Container(
                      width: 190,
                      height: 190,
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.white, width: 3),
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (_busy)
            const Padding(
              padding: EdgeInsets.only(top: 12),
              child: LinearProgressIndicator(),
            ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
            ),
          if (preview != null) ...[
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Xác nhận thiết bị', style: TextStyle(fontWeight: FontWeight.w700)),
                    const SizedBox(height: 8),
                    Text('Thiết bị hiện tại: ${preview['currentDeviceCode'] ?? '-'}'),
                    Text('Thiết bị mới: ${preview['newDeviceCode'] ?? '-'}'),
                    Text(compatible ? 'Thiết bị sẵn sàng thay thế.' : 'Thiết bị mới không thể dùng.'),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _reasonController,
              maxLength: 500,
              minLines: 2,
              maxLines: 4,
              onChanged: (_) => setState(() {}),
              decoration: const InputDecoration(
                labelText: 'Lý do thay thiết bị',
                border: OutlineInputBorder(),
              ),
            ),
            FilledButton.icon(
              onPressed: _busy || !compatible || _reasonController.text.trim().isEmpty
                  ? null
                  : _confirm,
              icon: const Icon(Icons.swap_horiz),
              label: const Text('Xác nhận thay thiết bị'),
            ),
            TextButton.icon(
              onPressed: _busy ? null : _scanAgain,
              icon: const Icon(Icons.qr_code_scanner),
              label: const Text('Quét mã khác'),
            ),
          ],
        ],
      ),
    );
  }
}
