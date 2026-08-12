import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';
import 'package:livekit_client/livekit_client.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../../../app/providers.dart';
import '../../../../shared/widgets/app_back_leading.dart';
import '../../data/models/livestream_setup_models.dart';

class GuideLiveSetupPage extends ConsumerStatefulWidget {
  const GuideLiveSetupPage({
    super.key,
    required this.tourId,
    this.initialPlanItemId,
    this.fromItinerary = false,
    this.retryStream = false,
  });

  final String tourId;
  final String? initialPlanItemId;
  final bool fromItinerary;
  final bool retryStream;

  @override
  ConsumerState<GuideLiveSetupPage> createState() => _GuideLiveSetupPageState();
}

class _GuideLiveSetupPageState extends ConsumerState<GuideLiveSetupPage> {
  bool _permissionsGranted = false;
  bool _isRequesting = true;
  bool _loadingOptions = true;
  String? _optionsError;

  LivestreamSetupOptions? _options;
  String? _selectedPlanItemId;
  String? _selectedVehicleId;
  String? _selectedCheckpointId;
  String _audienceScope = 'VEHICLE';
  final Set<String> _selectedAudienceVehicleIds = {};

  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  LocalVideoTrack? _previewVideoTrack;
  LocalAudioTrack? _previewAudioTrack;

  String? _thumbnailBase64;
  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    await Future.wait([_requestPermissions(), _loadSetupOptions()]);
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _loadSetupOptions() async {
    setState(() {
      _loadingOptions = true;
      _optionsError = null;
    });
    try {
      final options = await ref
          .read(livestreamRepositoryProvider)
          .getGuideSetupOptions(tourId: widget.tourId);
      if (!mounted) return;
      setState(() {
        _options = options;
        final preferredId = widget.initialPlanItemId;
        final preferredItem = preferredId != null && preferredId.isNotEmpty
            ? options.planItems
                .where((item) => item.id == preferredId)
                .firstOrNull
            : null;
        final item = preferredItem ??
            (options.planItems.isNotEmpty ? options.planItems.first : null);
        _selectedPlanItemId = item?.id;
        _selectedVehicleId = item?.operationVehicleId;
        _selectedCheckpointId = item?.checkpointId;
        _audienceScope = item?.audienceScope ?? 'VEHICLE';
        _titleController.text = item?.title ?? '';
        _selectedAudienceVehicleIds
          ..clear()
          ..addAll(item?.audienceVehicleIds ?? const []);
        if (_selectedVehicleId != null) {
          _selectedAudienceVehicleIds.add(_selectedVehicleId!);
        }
        _loadingOptions = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _optionsError = e.toString();
        _loadingOptions = false;
      });
    }
  }

  void _selectPlanItem(String? planItemId) {
    final options = _options;
    if (options == null || planItemId == null) return;
    final matches = options.planItems.where((item) => item.id == planItemId);
    if (matches.isEmpty) return;
    final item = matches.first;
    setState(() {
      _selectedPlanItemId = item.id;
      _selectedVehicleId = item.operationVehicleId;
      _selectedCheckpointId = item.checkpointId;
      _audienceScope = item.audienceScope;
      _titleController.text = item.title;
      _selectedAudienceVehicleIds
        ..clear()
        ..addAll(item.audienceVehicleIds);
      if (item.operationVehicleId.isNotEmpty) {
        _selectedAudienceVehicleIds.add(item.operationVehicleId);
      }
    });
  }

  Future<void> _requestPermissions() async {
    setState(() => _isRequesting = true);
    final statuses = await [Permission.camera, Permission.microphone].request();

    if (statuses[Permission.camera] == PermissionStatus.permanentlyDenied ||
        statuses[Permission.microphone] == PermissionStatus.permanentlyDenied) {
      await openAppSettings();
    }

    final granted =
        statuses[Permission.camera] == PermissionStatus.granted &&
        statuses[Permission.microphone] == PermissionStatus.granted;

    if (granted && _previewVideoTrack == null) {
      try {
        _previewVideoTrack = await LocalVideoTrack.createCameraTrack(
          const CameraCaptureOptions(params: VideoParametersPresets.h1080_169),
        );
        _previewAudioTrack = await LocalAudioTrack.create();
      } catch (e) {
        debugPrint('Cannot start camera preview: $e');
      }
    }

    if (mounted) {
      setState(() {
        _permissionsGranted = granted;
        _isRequesting = false;
      });
    }
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final XFile? image = await _picker.pickImage(source: source);
      if (image == null) return;

      setState(() => _isRequesting = true);

      final bytes = await File(image.path).readAsBytes();
      final decodedImage = img.decodeImage(bytes);
      if (decodedImage == null) {
        setState(() => _isRequesting = false);
        return;
      }

      final resizedImage = img.copyResize(decodedImage, width: 640);
      final compressedBytes = img.encodeJpg(resizedImage, quality: 60);
      final base64String = base64Encode(compressedBytes);

      setState(() {
        _thumbnailBase64 = base64String;
        _isRequesting = false;
      });
    } catch (e) {
      debugPrint('Error picking image: $e');
      setState(() => _isRequesting = false);
    }
  }

  List<String>? _audienceVehicleIdsForStart() {
    if (_audienceScope == 'SELECTED_VEHICLES') {
      return _selectedAudienceVehicleIds.toList();
    }
    return null;
  }

  Future<void> _startStream() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedPlanItemId == null ||
        _selectedVehicleId == null ||
        _selectedCheckpointId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Vui lòng chọn mốc livestream, xe và địa điểm'),
        ),
      );
      return;
    }
    if (_audienceScope == 'SELECTED_VEHICLES' &&
        _selectedAudienceVehicleIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Chọn ít nhất một xe cho phạm vi xem')),
      );
      return;
    }

    final success = await ref
        .read(livestreamViewModelProvider.notifier)
        .startLivestream(
          _selectedPlanItemId!,
          widget.tourId,
          _selectedVehicleId!,
          _selectedCheckpointId!,
          _titleController.text.trim(),
          _descriptionController.text.trim().isEmpty
              ? null
              : _descriptionController.text.trim(),
          _thumbnailBase64,
          audienceScope: _audienceScope,
          audienceVehicleIds: _audienceVehicleIdsForStart(),
        );

    if (success && mounted) {
      context.pushReplacement(
        '/livestream/active',
        extra: {
          'tourId': widget.tourId,
          'title': _titleController.text.trim(),
          'videoTrack': _previewVideoTrack,
          'audioTrack': _previewAudioTrack,
        },
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(livestreamViewModelProvider);

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        leading: buildAppBackLeading(context, color: Colors.white),
        title: Text(
          widget.retryStream
              ? 'Livestream lần 2+'
              : 'Chuẩn bị Livestream',
          style: const TextStyle(color: Colors.white),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      extendBodyBehindAppBar: true,
      body: Stack(
        fit: StackFit.expand,
        children: [
          if (_previewVideoTrack != null)
            VideoTrackRenderer(_previewVideoTrack!)
          else
            Container(color: Colors.black),
          SafeArea(
            child: Center(
              child: _isRequesting || _loadingOptions
                  ? const CircularProgressIndicator(color: Colors.white)
                  : _optionsError != null
                  ? _buildOptionsError()
                  : _buildSetupPreview(state),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOptionsError() {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Iconsax.warning_2_copy, color: Colors.orange, size: 48),
          const SizedBox(height: 12),
          Text(
            'Không tải được cấu hình tour',
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(color: Colors.white),
          ),
          const SizedBox(height: 8),
          Text(
            _optionsError!,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white70, fontSize: 12),
          ),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: _loadSetupOptions,
            child: const Text('Thử lại'),
          ),
        ],
      ),
    );
  }

  String _planItemLabel(LivestreamSetupOptions options) {
    for (final item in options.planItems) {
      if (item.id == _selectedPlanItemId) return item.title;
    }
    return '—';
  }

  String _vehicleLabel(LivestreamSetupOptions options) {
    for (final vehicle in options.vehicles) {
      if (vehicle.id == _selectedVehicleId) return vehicle.label;
    }
    return '—';
  }

  String _locationLabel(LivestreamSetupOptions options) {
    for (final location in options.checkpoints) {
      if (location.id == _selectedCheckpointId) return location.name;
    }
    return '—';
  }

  Widget _buildSetupPreview(dynamic state) {
    final options = _options!;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
      child: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (_previewVideoTrack == null)
                      const Icon(
                        Iconsax.video_circle_copy,
                        size: 72,
                        color: Colors.blue,
                      ),
                    const SizedBox(height: 12),
                    Text(
                      widget.retryStream
                          ? 'Phát sóng lại (phiên mới)'
                          : 'Chuẩn bị phát sóng',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    if (widget.retryStream) ...[
                      const SizedBox(height: 10),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.deepOrange.withValues(alpha: 0.22),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: Colors.deepOrange.shade200.withValues(
                              alpha: 0.7,
                            ),
                          ),
                        ),
                        child: const Text(
                          'Đây là livestream lần tiếp theo tại mốc lịch trình này — '
                          'không phải tiếp tục phiên cũ.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            height: 1.35,
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(height: 20),
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.62),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: Colors.white24),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          if (widget.fromItinerary)
                            _buildReadOnlyField(
                              label: 'Mốc livestream trong kế hoạch',
                              value: _planItemLabel(options),
                              icon: Iconsax.video_play_copy,
                            )
                          else
                            _buildPlanItemDropdown(options),
                          const SizedBox(height: 12),
                          _buildReadOnlyField(
                            label: 'Xe phát sóng',
                            value: _vehicleLabel(options),
                            icon: Iconsax.bus_copy,
                          ),
                          const SizedBox(height: 12),
                          _buildReadOnlyField(
                            label: 'Địa điểm',
                            value: _locationLabel(options),
                            icon: Iconsax.location_copy,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    IgnorePointer(child: _buildAudienceScopeSelector(options)),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _titleController,
                      readOnly: widget.fromItinerary,
                      style: const TextStyle(color: Colors.white),
                      decoration: _inputDecoration(
                        'Tiêu đề livestream *',
                        'Ví dụ: Khám phá bảo tàng...',
                      ),
                      validator: (value) =>
                          value == null || value.trim().isEmpty
                          ? 'Vui lòng nhập tiêu đề'
                          : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _descriptionController,
                      style: const TextStyle(color: Colors.white),
                      decoration: _inputDecoration(
                        'Mô tả ngắn (tùy chọn)',
                        null,
                      ),
                      maxLines: 2,
                    ),
                    const SizedBox(height: 16),
                    _buildThumbnailPicker(),
                    const SizedBox(height: 16),
                    _buildPermissionBanner(),
                    if (state.errorMessage != null) ...[
                      const SizedBox(height: 12),
                      Text(
                        state.errorMessage!,
                        style: const TextStyle(color: Colors.redAccent),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
          SizedBox(
            width: double.infinity,
            height: 56,
            child: FilledButton(
              onPressed:
                  (_permissionsGranted &&
                      !state.isLoading &&
                      _selectedVehicleId != null &&
                      _selectedCheckpointId != null &&
                      _selectedPlanItemId != null)
                  ? _startStream
                  : null,
              style: FilledButton.styleFrom(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: state.isLoading
                  ? const CircularProgressIndicator(color: Colors.white)
                  : Text(
                      widget.retryStream
                          ? 'Bắt đầu phát lần 2+'
                          : 'Bắt đầu phát',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPlanItemDropdown(LivestreamSetupOptions options) {
    return DropdownButtonFormField<String>(
      key: ValueKey('livestream-plan-$_selectedPlanItemId'),
      initialValue: _selectedPlanItemId,
      items: options.planItems
          .map(
            (item) => DropdownMenuItem(
              value: item.id,
              child: Text(
                item.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: Colors.black),
              ),
            ),
          )
          .toList(),
      onChanged: _selectPlanItem,
      isExpanded: true,
      dropdownColor: Colors.white,
      decoration: _inputDecoration('Mốc livestream trong kế hoạch *', null),
      style: const TextStyle(color: Colors.white),
    );
  }

  Widget _buildReadOnlyField({
    required String label,
    required String value,
    required IconData icon,
  }) {
    final displayValue = value.trim().isEmpty ? '—' : value.trim();
    return IgnorePointer(
      child: InputDecorator(
        decoration: _inputDecoration(label, null).copyWith(
          prefixIcon: Icon(icon, color: Colors.white70, size: 22),
        ),
        child: Text(
          displayValue,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(color: Colors.white, height: 1.3),
        ),
      ),
    );
  }

  InputDecoration _inputDecoration(String label, String? hint) {
    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(color: Colors.white70),
      hintText: hint,
      hintStyle: const TextStyle(color: Colors.white30),
      filled: true,
      fillColor: Colors.black38,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Colors.white24),
      ),
      disabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Colors.white24),
      ),
    );
  }

  Widget _buildAudienceScopeSelector(LivestreamSetupOptions options) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.black54,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Ai được xem?',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
          ),
          RadioListTile<String>(
            value: 'VEHICLE',
            groupValue: _audienceScope,
            onChanged: (v) => setState(() => _audienceScope = v!),
            title: const Text(
              'Chỉ xe của tôi',
              style: TextStyle(color: Colors.white),
            ),
            activeColor: Colors.white,
            contentPadding: EdgeInsets.zero,
          ),
          RadioListTile<String>(
            value: 'TOUR',
            groupValue: _audienceScope,
            onChanged: (v) => setState(() => _audienceScope = v!),
            title: const Text('Cả đoàn', style: TextStyle(color: Colors.white)),
            activeColor: Colors.white,
            contentPadding: EdgeInsets.zero,
          ),
          RadioListTile<String>(
            value: 'SELECTED_VEHICLES',
            groupValue: _audienceScope,
            onChanged: (v) => setState(() => _audienceScope = v!),
            title: const Text('Chọn xe', style: TextStyle(color: Colors.white)),
            activeColor: Colors.white,
            contentPadding: EdgeInsets.zero,
          ),
          if (_audienceScope == 'SELECTED_VEHICLES') ...[
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: options.vehicles.map((vehicle) {
                final selected = _selectedAudienceVehicleIds.contains(
                  vehicle.id,
                );
                return FilterChip(
                  label: Text(vehicle.label),
                  selected: selected,
                  onSelected: (on) {
                    setState(() {
                      if (on) {
                        _selectedAudienceVehicleIds.add(vehicle.id);
                      } else {
                        _selectedAudienceVehicleIds.remove(vehicle.id);
                      }
                    });
                  },
                );
              }).toList(),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildPermissionBanner() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.black54,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white24),
      ),
      child: Row(
        children: [
          Icon(
            _permissionsGranted
                ? Iconsax.tick_circle_copy
                : Iconsax.warning_2_copy,
            color: _permissionsGranted ? Colors.green : Colors.orange,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              _permissionsGranted
                  ? 'Đã cấp quyền Camera & Micro'
                  : 'Chưa cấp đủ quyền!',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: _permissionsGranted
                    ? Colors.green[200]
                    : Colors.orange[200],
              ),
            ),
          ),
          if (!_permissionsGranted)
            TextButton(
              onPressed: _requestPermissions,
              child: const Text('Cấp lại'),
            ),
        ],
      ),
    );
  }

  Widget _buildThumbnailPicker() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Ảnh Thumbnail (tùy chọn)',
          style: TextStyle(color: Colors.white70, fontSize: 14),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => _pickImage(ImageSource.gallery),
                icon: const Icon(Iconsax.gallery_copy, color: Colors.white),
                label: const Text(
                  'Thư viện',
                  style: TextStyle(color: Colors.white),
                ),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Colors.white30),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => _pickImage(ImageSource.camera),
                icon: const Icon(Iconsax.camera_copy, color: Colors.white),
                label: const Text(
                  'Chụp ảnh',
                  style: TextStyle(color: Colors.white),
                ),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Colors.white30),
                ),
              ),
            ),
          ],
        ),
        if (_thumbnailBase64 != null) ...[
          const SizedBox(height: 16),
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Image.memory(
              base64Decode(_thumbnailBase64!),
              height: 150,
              width: double.infinity,
              fit: BoxFit.cover,
            ),
          ),
        ],
      ],
    );
  }
}
