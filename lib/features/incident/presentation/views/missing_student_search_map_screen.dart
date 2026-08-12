import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:map4d_map/map4d_map.dart';

import '../../../../shared/theme/app_theme.dart';
import '../../../../shared/widgets/app_back_leading.dart';

/// Search map for a missing-student incident. A line is rendered only from a
/// personal tracker trail; vehicle/reporter locations are contextual markers.
class MissingStudentSearchMapScreen extends StatefulWidget {
  const MissingStudentSearchMapScreen({
    super.key,
    required this.studentName,
    required this.snapshot,
  });

  final String studentName;
  final Map<String, dynamic> snapshot;

  @override
  State<MissingStudentSearchMapScreen> createState() =>
      _MissingStudentSearchMapScreenState();
}

class _MissingStudentSearchMapScreenState
    extends State<MissingStudentSearchMapScreen> {
  List<MFLatLng> get _personalTrail {
    final trail = widget.snapshot['personalTrackerTrail'] as Map?;
    final points = trail?['points'] as List? ?? const [];
    return points
        .whereType<Map>()
        .map(_pointFromMap)
        .whereType<MFLatLng>()
        .toList(growable: false);
  }

  MFLatLng? _pointFromMap(Map value) {
    final latitude = _asDouble(value['latitude'] ?? value['lat']);
    final longitude = _asDouble(value['longitude'] ?? value['lng']);
    if (latitude == null || longitude == null) return null;
    return MFLatLng(latitude, longitude);
  }

  double? _asDouble(Object? value) => value is num
      ? value.toDouble()
      : double.tryParse(value?.toString() ?? '');

  MFLatLng? get _reporterLocation {
    final reporter = widget.snapshot['reporterLocation'] as Map?;
    return reporter == null ? null : _pointFromMap(reporter);
  }

  MFLatLng? get _vehicleLocation {
    final vehicle = widget.snapshot['vehicleLocation'] as Map?;
    final location = vehicle?['lastLocation'];
    return location is Map ? _pointFromMap(location) : null;
  }

  List<MFLatLng> get _allPoints => [
    ..._personalTrail,
    if (_reporterLocation != null) _reporterLocation!,
    if (_vehicleLocation != null) _vehicleLocation!,
  ];

  Set<MFMarker> get _markers {
    final markers = <MFMarker>{};
    final trail = _personalTrail;
    if (trail.isNotEmpty) {
      markers.add(
        MFMarker(
          markerId: const MFMarkerId('student-trail-start'),
          position: trail.first,
          icon: MFBitmap.defaultIcon,
          infoWindow: const MFInfoWindow(title: 'Điểm đầu dữ liệu GPS cá nhân'),
        ),
      );
      markers.add(
        MFMarker(
          markerId: const MFMarkerId('student-trail-last'),
          position: trail.last,
          icon: MFBitmap.defaultIcon,
          infoWindow: const MFInfoWindow(title: 'Điểm GPS cá nhân cuối cùng'),
        ),
      );
    }
    final reporter = _reporterLocation;
    if (reporter != null) {
      markers.add(MFMarker(
        markerId: const MFMarkerId('reporter-location'),
        position: reporter,
        icon: MFBitmap.defaultIcon,
        infoWindow: const MFInfoWindow(title: 'Vị trí người báo cáo'),
      ));
    }
    final vehicle = _vehicleLocation;
    if (vehicle != null) {
      markers.add(MFMarker(
        markerId: const MFMarkerId('vehicle-location'),
        position: vehicle,
        icon: MFBitmap.defaultIcon,
        infoWindow: const MFInfoWindow(title: 'Vị trí xe lúc báo cáo'),
      ));
    }
    return markers;
  }

  @override
  Widget build(BuildContext context) {
    final trail = _personalTrail;
    final allPoints = _allPoints;
    return Scaffold(
      backgroundColor: AppTheme.surfaceLight,
      appBar: AppBar(
        leading: buildAppBackLeading(context),
        title: const Text('Bản đồ tìm kiếm'),
      ),
      body: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            color: trail.isEmpty ? AppTheme.errorContainer : AppTheme.primarySoft,
            child: Text(
              trail.isEmpty
                  ? 'Học sinh chưa được gán GPS cá nhân: không có đường đi cá nhân để hiển thị. Các điểm trên bản đồ chỉ là dữ kiện hỗ trợ tìm kiếm.'
                  : 'Đường màu xanh là dữ liệu GPS của thiết bị cá nhân, không khẳng định tuyệt đối vị trí học sinh.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(height: 1.4),
            ),
          ),
          Expanded(
            child: allPoints.isEmpty
                ? const Center(child: Text('Chưa có tọa độ nào để hiển thị trên bản đồ.'))
                : kIsWeb
                ? _MapFallback(hasPersonalTrail: trail.isNotEmpty)
                : MFMapView(
                    initialCameraPosition: MFCameraPosition(
                      target: allPoints.last,
                      zoom: 15,
                    ),
                    buildingsEnabled: false,
                    markers: _markers,
                    polylines: trail.length < 2
                        ? const <MFPolyline>{}
                        : {
                            MFPolyline(
                              polylineId: const MFPolylineId('personal-trail'),
                              points: trail,
                              color: AppTheme.primary,
                              width: 7,
                            ),
                          },
                  ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
            child: Row(
              children: [
                _Legend(color: AppTheme.primary, label: 'Đường GPS cá nhân'),
                const SizedBox(width: 16),
                const _Legend(color: AppTheme.accentOrange, label: 'Điểm hỗ trợ'),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Legend extends StatelessWidget {
  const _Legend({required this.color, required this.label});
  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(width: 18, height: 4, color: color),
          const SizedBox(width: 6),
          Text(label, style: Theme.of(context).textTheme.labelSmall),
        ],
      );
}

class _MapFallback extends StatelessWidget {
  const _MapFallback({required this.hasPersonalTrail});
  final bool hasPersonalTrail;

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            hasPersonalTrail
                ? 'Bản đồ và đường GPS cá nhân hiển thị trên ứng dụng Android/iOS.'
                : 'Không có đường GPS cá nhân để hiển thị.',
            textAlign: TextAlign.center,
          ),
        ),
      );
}
