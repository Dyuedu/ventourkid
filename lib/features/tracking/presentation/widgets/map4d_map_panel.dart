import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import 'package:map4d_map/map4d_map.dart';
import 'marker_generator.dart';

import '../../domain/models/tracker_location_view_model.dart';
import '../../../../shared/theme/app_theme.dart';

class Map4dMapPanel extends StatefulWidget {
  const Map4dMapPanel({
    super.key,
    required this.locations,
    this.checkpoints = const [],
    this.selectedAssignmentId,
    this.onSelectAssignment,
  });

  final List<TrackerLocationViewModel> locations;
  final List<TrackingCheckpointViewModel> checkpoints;
  final String? selectedAssignmentId;
  final ValueChanged<String>? onSelectAssignment;

  @override
  State<Map4dMapPanel> createState() => _Map4dMapPanelState();
}

class _Map4dMapPanelState extends State<Map4dMapPanel> {
  MFMapViewController? _controller;
  TrackerLocationViewModel? _selectedLocation;
  final Map<String, MFBitmap> _markerBitmaps = {};
  bool _bitmapsGenerating = false;

  @override
  void initState() {
    super.initState();
    _generateBitmaps();
  }

  List<MFLatLng> get _coordinates => [
        ...widget.locations
            .where((item) => item.hasCoordinates)
            .map((item) => MFLatLng(item.latitude!, item.longitude!)),
        ...widget.checkpoints
            .where((item) => item.latitude != null && item.longitude != null)
            .map((item) => MFLatLng(item.latitude!, item.longitude!)),
      ];

  String _markerTitle(TrackerLocationViewModel location) => location.displayTitle;

  String _markerSnippet(TrackerLocationViewModel location) {
    final parts = <String>[
      if (!location.hasLiveSignal)
        location.hasCoordinates
            ? location.signalStatus
            : 'Chưa có tín hiệu'
      else
        location.signalStatus,
      if (location.deviceCode != null && location.deviceCode!.trim().isNotEmpty)
        location.deviceCode!.trim(),
      if (location.showsBattery) 'Pin ${location.batteryLevel}%',
      if (location.isVehicleProxy && location.vehicleLabel != null)
        'Xe ${location.vehicleLabel}',
    ];
    return parts.join(' · ');
  }

  Future<void> _generateBitmaps() async {
    if (_bitmapsGenerating) return;
    _bitmapsGenerating = true;
    bool changed = false;

    final orderedCheckpoints = [...widget.checkpoints]
      ..sort((a, b) => a.sequenceNo.compareTo(b.sequenceNo));

    final Map<String, List<TrackingCheckpointViewModel>> groupedCheckpoints = {};
    for (final checkpoint in orderedCheckpoints) {
      if (checkpoint.latitude == null || checkpoint.longitude == null) continue;
      final key = '${checkpoint.latitude!.toStringAsFixed(6)},${checkpoint.longitude!.toStringAsFixed(6)}';
      groupedCheckpoints.putIfAbsent(key, () => []).add(checkpoint);
    }

    int destinationNumber = 0;
    for (final group in groupedCheckpoints.values) {
      final lastCheckpoint = group.last;
      
      String label = group.map((c) => c.name).where((n) => n.isNotEmpty).join(' · ');
      if (label.isEmpty) label = 'Đ${++destinationNumber}';
      
      Color color = Colors.red;

      final types = group.map((c) => c.checkpointType.toUpperCase()).toSet();
      if (types.contains('PICKUP')) {
        color = const Color(0xFF2E7D32);
      } else if (types.contains('DROPOFF')) {
        color = const Color(0xFF64748B);
      } else {
        final status = lastCheckpoint.locationStatus?.toUpperCase() ?? '';
        if (status == 'COMPLETED') color = const Color(0xFF2E7D32);
        else if (status == 'ARRIVED') color = const Color(0xFFED6C02);
        else if (status == 'CURRENT') color = const Color(0xFF0288D1);
        else color = Colors.red;
      }

      final cacheKey = 'checkpoint_${lastCheckpoint.id}_$label\_${color.value}';
      if (!_markerBitmaps.containsKey(cacheKey)) {
        _markerBitmaps[cacheKey] = await createCustomMarkerBitmap(
          label,
          Icons.location_on,
          color,
          size: 110.0,
        );
        changed = true;
      }
    }

    for (var index = 0; index < widget.locations.length; index++) {
      final location = widget.locations[index];
      if (!location.hasCoordinates) continue;

      final isStudent = location.isStudent;
      final labelText = isStudent ? 'H' : 'X${index + 1}';
      final selected = location.assignmentId == widget.selectedAssignmentId;

      Color color = const Color(0xFF1976D2);
      if (location.signalStatus.contains('Mất tín hiệu')) color = Colors.grey;
      else if (location.signalStatus.contains('Cảnh báo')) color = Colors.red;

      final cacheKey = 'loc_${location.assignmentId}_${labelText}_${color.value}_$selected';
      if (!_markerBitmaps.containsKey(cacheKey)) {
        _markerBitmaps[cacheKey] = await createCustomMarkerBitmap(
          labelText,
          isStudent ? Icons.person : Icons.directions_bus,
          color,
          size: selected ? 120.0 : 96.0,
        );
        changed = true;
      }
    }

    _bitmapsGenerating = false;
    if (changed && mounted) {
      setState(() {});
    }
  }

  Set<MFMarker> get _markers {
    final markers = <MFMarker>{};
    final orderedCheckpoints = [...widget.checkpoints]
      ..sort((a, b) => a.sequenceNo.compareTo(b.sequenceNo));
      
    final Map<String, List<TrackingCheckpointViewModel>> groupedCheckpoints = {};
    for (final checkpoint in orderedCheckpoints) {
      if (checkpoint.latitude == null || checkpoint.longitude == null) continue;
      final key = '${checkpoint.latitude!.toStringAsFixed(6)},${checkpoint.longitude!.toStringAsFixed(6)}';
      groupedCheckpoints.putIfAbsent(key, () => []).add(checkpoint);
    }
      
    int destinationNumber = 0;
    int groupIndex = 0;
    for (final group in groupedCheckpoints.values) {
      final lastCheckpoint = group.last;
      
      String label = group.map((c) => c.name).where((n) => n.isNotEmpty).join(' · ');
      if (label.isEmpty) label = 'Đ${++destinationNumber}';
      
      Color color = Colors.red;
      final types = group.map((c) => c.checkpointType.toUpperCase()).toSet();
      if (types.contains('PICKUP')) { color = const Color(0xFF2E7D32); }
      else if (types.contains('DROPOFF')) { color = const Color(0xFF64748B); }
      else {
        final status = lastCheckpoint.locationStatus?.toUpperCase() ?? '';
        if (status == 'COMPLETED') color = const Color(0xFF2E7D32);
        else if (status == 'ARRIVED') color = const Color(0xFFED6C02);
        else if (status == 'CURRENT') color = const Color(0xFF0288D1);
        else color = Colors.red;
      }
      
      final cacheKey = 'checkpoint_${lastCheckpoint.id}_$label\_${color.value}';

      markers.add(MFMarker(
        markerId: MFMarkerId('checkpoint-${lastCheckpoint.id}'),
        position: MFLatLng(lastCheckpoint.latitude!, lastCheckpoint.longitude!),
        zIndex: 10 + groupIndex.toDouble(),
        icon: _markerBitmaps[cacheKey] ?? MFBitmap.defaultIcon,
        infoWindow: MFInfoWindow(
          title: groupIndex == 0 && types.contains('PICKUP') ? 'Trường xuất phát' : label,
          snippet: group.map((c) => c.address ?? c.checkpointType).where((s) => s.isNotEmpty).join(' · '),
        ),
      ));
      groupIndex++;
    }
    
    for (var index = 0; index < widget.locations.length; index++) {
      final location = widget.locations[index];
      if (!location.hasCoordinates) continue;
      
      final isStudent = location.isStudent;
      final labelText = isStudent ? 'H' : 'X${index + 1}';
      final selected = location.assignmentId == widget.selectedAssignmentId;

      Color color = const Color(0xFF1976D2);
      if (location.signalStatus.contains('Mất tín hiệu')) color = Colors.grey;
      else if (location.signalStatus.contains('Cảnh báo')) color = Colors.red;

      final cacheKey = 'loc_${location.assignmentId}_${labelText}_${color.value}_$selected';

      markers.add(MFMarker(
        markerId: MFMarkerId('tracker-${location.assignmentId}'),
        position: MFLatLng(location.latitude!, location.longitude!),
        zIndex: (selected ? 200 : 100) + index.toDouble(),
        consumeTapEvents: true,
        icon: _markerBitmaps[cacheKey] ?? MFBitmap.defaultIcon,
        infoWindow: MFInfoWindow(
          title: _markerTitle(location),
          snippet: _markerSnippet(location),
        ),
        onTap: () {
          setState(() => _selectedLocation = location);
          widget.onSelectAssignment?.call(location.assignmentId);
        },
      ));
    }
    return markers;
  }

  @override
  void didUpdateWidget(covariant Map4dMapPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.locations != widget.locations ||
        oldWidget.checkpoints != widget.checkpoints ||
        oldWidget.selectedAssignmentId != widget.selectedAssignmentId) {
      _generateBitmaps();
    }
    if (oldWidget.locations != widget.locations ||
        oldWidget.checkpoints != widget.checkpoints) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _fitAll());
    }
    if (widget.selectedAssignmentId != null &&
        widget.selectedAssignmentId != oldWidget.selectedAssignmentId) {
      TrackerLocationViewModel? match;
      for (final location in widget.locations) {
        if (location.assignmentId == widget.selectedAssignmentId) {
          match = location;
          break;
        }
      }
      if (match != null) {
        setState(() => _selectedLocation = match);
      }
    }
  }

  Future<void> _fitAll() async {
    final controller = _controller;
    final points = _coordinates;
    if (controller == null || points.isEmpty) return;
    if (points.length == 1) {
      await controller.animateCamera(MFCameraUpdate.newLatLngZoom(points.first, 15));
      return;
    }
    var minLat = points.first.latitude;
    var maxLat = points.first.latitude;
    var minLng = points.first.longitude;
    var maxLng = points.first.longitude;
    for (final point in points.skip(1)) {
      minLat = math.min(minLat, point.latitude);
      maxLat = math.max(maxLat, point.latitude);
      minLng = math.min(minLng, point.longitude);
      maxLng = math.max(maxLng, point.longitude);
    }
    await controller.animateCamera(MFCameraUpdate.newLatLngBounds(
      MFLatLngBounds(
        southwest: MFLatLng(minLat, minLng),
        northeast: MFLatLng(maxLat, maxLng),
      ),
      64,
    ));
  }

  @override
  Widget build(BuildContext context) {
    if (_coordinates.isEmpty) {
      final pendingTrackers = widget.locations.where((item) => !item.hasCoordinates);
      if (pendingTrackers.isNotEmpty) {
        return Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              'Đã gán ${pendingTrackers.length} thiết bị GPS nhưng chưa có tín hiệu vị trí.\n'
              'Thiết bị sẽ hiện trên bản đồ khi bắt đầu gửi tọa độ.',
              textAlign: TextAlign.center,
            ),
          ),
        );
      }
      return const Center(child: Text('Chưa có vị trí hợp lệ.'));
    }
    if (kIsWeb) {
      return _WebFallback(locations: widget.locations, checkpoints: widget.checkpoints);
    }
    final center = _coordinates.first;
    return Stack(
      children: [
        MFMapView(
          initialCameraPosition: MFCameraPosition(target: center, zoom: 13),
          markers: _markers,
          buildingsEnabled: false,
          onMapCreated: (controller) {
            _controller = controller;
            _fitAll();
          },
        ),
        Positioned(
          right: 12,
          bottom: 98,
          child: FloatingActionButton.small(
            heroTag: 'tracking-map-fit',
            onPressed: _fitAll,
            tooltip: 'Hiển thị toàn bộ điểm',
            child: const Icon(Icons.center_focus_strong),
          ),
        ),
        if (_selectedLocation != null)
          Positioned(
            left: 12,
            right: 12,
            top: 12,
            child: _LocationPanel(
              location: _selectedLocation!,
              onClose: () => setState(() => _selectedLocation = null),
            ),
          ),
      ],
    );
  }
}

class _LocationPanel extends StatelessWidget {
  const _LocationPanel({required this.location, required this.onClose});

  final TrackerLocationViewModel location;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final code = location.deviceCode?.trim();
    final statusParts = <String>[
      if (!location.hasLiveSignal)
        location.hasCoordinates
            ? location.signalStatus
            : 'Chưa có tín hiệu vị trí'
      else
        location.signalStatus,
      if (code != null && code.isNotEmpty) code,
      if (location.showsBattery) 'Pin ${location.batteryLevel}%',
      if (location.isVehicleProxy && location.vehicleLabel != null)
        'Xe ${location.vehicleLabel}',
    ];

    return Material(
      elevation: 4,
      borderRadius: BorderRadius.circular(8),
      color: Theme.of(context).colorScheme.surface,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 10, 6, 10),
        child: Row(
          children: [
            Icon(
              location.isStudent ? Iconsax.profile_2user : Iconsax.bus,
              color: AppTheme.primary,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    location.displayTitle,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  Text(
                    statusParts.join(' · '),
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: location.hasLiveSignal
                          ? null
                          : const Color(0xFFEA580C),
                    ),
                  ),
                ],
              ),
            ),
            IconButton(
              onPressed: onClose,
              icon: const Icon(Iconsax.close_circle),
              tooltip: 'Đóng',
            ),
          ],
        ),
      ),
    );
  }
}

class _WebFallback extends StatelessWidget {
  const _WebFallback({required this.locations, required this.checkpoints});

  final List<TrackerLocationViewModel> locations;
  final List<TrackingCheckpointViewModel> checkpoints;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: Theme.of(context).colorScheme.surfaceContainerLowest,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text(
            'Map4D Mobile SDK hỗ trợ Android và iOS.',
            style: TextStyle(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 12),
          ...checkpoints.map(
            (item) => ListTile(
              leading: const Icon(Icons.location_on_outlined),
              title: Text(item.name),
              subtitle: Text(item.address ?? item.checkpointType),
            ),
          ),
          ...locations.map(
            (item) => ListTile(
              leading: Icon(
                item.isStudent
                    ? Icons.person_pin_circle_outlined
                    : Icons.directions_bus_outlined,
              ),
              title: Text(item.displayTitle),
              subtitle: Text(
                item.hasCoordinates
                    ? '${item.latitude}, ${item.longitude}'
                    : (item.deviceCode != null && item.deviceCode!.trim().isNotEmpty
                        ? 'Chưa có tín hiệu vị trí · ${item.deviceCode}'
                        : 'Chưa có tín hiệu vị trí'),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
