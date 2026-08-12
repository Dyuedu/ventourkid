import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../../../shared/widgets/app_back_leading.dart';

/// Scans a GPS device QR and returns the raw payload to the caller.
class ClosingDeviceScannerPage extends StatefulWidget {
  const ClosingDeviceScannerPage({super.key});

  @override
  State<ClosingDeviceScannerPage> createState() =>
      _ClosingDeviceScannerPageState();
}

class _ClosingDeviceScannerPageState extends State<ClosingDeviceScannerPage> {
  final _scanner = MobileScannerController(
    formats: const [BarcodeFormat.qrCode],
  );
  bool _handled = false;

  @override
  void dispose() {
    _scanner.dispose();
    super.dispose();
  }

  Future<void> _onDetect(BarcodeCapture capture) async {
    if (_handled) return;
    final value =
        capture.barcodes.isEmpty ? null : capture.barcodes.first.rawValue;
    if (value == null || value.isEmpty) return;
    _handled = true;
    await _scanner.stop();
    if (!mounted) return;
    Navigator.of(context).pop(value);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: buildAppBackLeading(context),
        title: const Text('Quét QR thiết bị GPS'),
      ),
      body: Column(
        children: [
          Expanded(
            child: Stack(
              fit: StackFit.expand,
              children: [
                MobileScanner(controller: _scanner, onDetect: _onDetect),
                Center(
                  child: Container(
                    width: 220,
                    height: 220,
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.white, width: 3),
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const Padding(
            padding: EdgeInsets.all(16),
            child: Text(
              'Hướng camera vào mã QR trên thiết bị GPS của xe trong tour.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.black54),
            ),
          ),
        ],
      ),
    );
  }
}
