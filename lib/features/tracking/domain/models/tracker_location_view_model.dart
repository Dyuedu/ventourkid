class TrackerLocationViewModel {
  const TrackerLocationViewModel({
    required this.assignmentId,
    required this.targetType,
    required this.signalStatus,
    this.latitude,
    this.longitude,
    this.deviceStatus,
    this.vehicleLabel,
    this.driverName,
    this.driverPhone,
    this.studentName,
    this.deviceCode,
    this.locationSource = 'DEVICE',
    this.coLocatedVehicleId,
    required this.recordedAt,
    this.targetId,
    this.deviceId,
    this.accuracyMeters,
    this.qualityStatus,
    this.receivedAt,
    this.batteryLevel,
    this.signalQuality,
    this.sourceType,
    this.lastSeenAgeSeconds,
  });

  final String assignmentId;
  final String targetType;
  final String? targetId;
  final String? deviceId;
  final String? deviceCode;
  final double? latitude;
  final double? longitude;
  final double? accuracyMeters;

  final String? qualityStatus;
  final String signalStatus;
  final String? deviceStatus;
  final String? vehicleLabel;
  final String? driverName;
  final String? driverPhone;
  final String? studentName;
  final String locationSource;
  final String? coLocatedVehicleId;
  final int? batteryLevel;
  final int? signalQuality;
  final String? sourceType;
  final DateTime recordedAt;
  final DateTime? receivedAt;
  final int? lastSeenAgeSeconds;

  bool get isStudent => targetType == 'SELECTED_STUDENT';
  bool get isVehicle => targetType == 'VEHICLE';
  bool get isVehicleProxy => locationSource == 'VEHICLE_PROXY';
  bool get hasCoordinates => latitude != null && longitude != null;

  /// Live fix with a non-offline signal — battery/% only makes sense then.
  bool get hasLiveSignal {
    if (!hasCoordinates) return false;
    final status = signalStatus.trim().toUpperCase();
    return status.isNotEmpty &&
        status != 'OFFLINE' &&
        status != 'UNKNOWN' &&
        status != 'NO_SIGNAL' &&
        status != 'LOST' &&
        status != 'INACTIVE' &&
        status != 'DISCONNECTED';
  }

  bool get showsBattery => hasLiveSignal && batteryLevel != null;

  String get displayTitle {
    if (isStudent) {
      final name = studentName?.trim();
      if (name != null && name.isNotEmpty) {
        return isVehicleProxy ? '$name (theo xe)' : name;
      }
      final code = deviceCode?.trim();
      if (code != null && code.isNotEmpty) {
        return code;
      }
      return isVehicleProxy ? 'Học sinh (theo xe)' : 'Thiết bị học sinh';
    }
    return vehicleLabel?.trim().isNotEmpty == true
        ? vehicleLabel!.trim()
        : 'Xe tour';
  }

  factory TrackerLocationViewModel.fromJson(Map<String, dynamic> json) {
    final latitude = json['latitude'];
    final longitude = json['longitude'];
    final recordedRaw = json['recordedAt']?.toString();
    final recordedAt = DateTime.tryParse(recordedRaw ?? '') ?? DateTime.now();

    return TrackerLocationViewModel(
      assignmentId: json['assignmentId']?.toString() ?? '',
      targetType: json['targetType']?.toString() ?? 'UNKNOWN',
      targetId: json['targetId']?.toString(),
      deviceId: json['deviceId']?.toString(),
      deviceCode: json['deviceCode']?.toString(),
      latitude: latitude is num ? latitude.toDouble() : null,
      longitude: longitude is num ? longitude.toDouble() : null,
      accuracyMeters: (json['accuracyMeters'] as num?)?.toDouble(),
      qualityStatus: json['qualityStatus']?.toString(),
      signalStatus: json['signalStatus']?.toString() ?? 'UNKNOWN',
      deviceStatus: json['deviceStatus']?.toString(),
      vehicleLabel: json['vehicleLabel']?.toString(),
      driverName: json['driverName']?.toString(),
      driverPhone: json['driverPhone']?.toString(),
      studentName: json['studentName']?.toString(),
      locationSource: json['locationSource']?.toString() ?? 'DEVICE',
      coLocatedVehicleId: json['coLocatedVehicleId']?.toString(),
      batteryLevel: (json['batteryLevel'] as num?)?.toInt(),
      signalQuality: (json['signalQuality'] as num?)?.toInt(),
      sourceType: json['sourceType']?.toString(),
      recordedAt: recordedAt,
      receivedAt: DateTime.tryParse(json['receivedAt']?.toString() ?? ''),
      lastSeenAgeSeconds: (json['lastSeenAgeSeconds'] as num?)?.toInt(),
    );
  }

  static TrackerLocationViewModel? tryParse(Map<String, dynamic> json) {
    try {
      final parsed = TrackerLocationViewModel.fromJson(json);
      if (parsed.assignmentId.isEmpty) return null;
      return parsed;
    } on Object {
      return null;
    }
  }

  TrackerLocationViewModel copyWith({
    String? signalStatus,
    String? deviceStatus,
    String? locationSource,
    String? studentName,
    String? vehicleLabel,
    String? deviceCode,
    String? coLocatedVehicleId,
    double? latitude,
    double? longitude,
  }) {
    return TrackerLocationViewModel(
      assignmentId: assignmentId,
      targetType: targetType,
      targetId: targetId,
      deviceId: deviceId,
      deviceCode: deviceCode ?? this.deviceCode,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      accuracyMeters: accuracyMeters,
      qualityStatus: qualityStatus,
      signalStatus: signalStatus ?? this.signalStatus,
      deviceStatus: deviceStatus ?? this.deviceStatus,
      vehicleLabel: vehicleLabel ?? this.vehicleLabel,
      driverName: driverName,
      driverPhone: driverPhone,
      studentName: studentName ?? this.studentName,
      locationSource: locationSource ?? this.locationSource,
      coLocatedVehicleId: coLocatedVehicleId ?? this.coLocatedVehicleId,
      batteryLevel: batteryLevel,
      signalQuality: signalQuality,
      sourceType: sourceType,
      recordedAt: recordedAt,
      receivedAt: receivedAt,
      lastSeenAgeSeconds: lastSeenAgeSeconds,
    );
  }

  TrackerLocationViewModel mergeRealtime(Map<String, dynamic> json) {
    final merged = <String, dynamic>{
      'assignmentId': assignmentId,
      'targetType': targetType,
      'targetId': targetId,
      'deviceId': deviceId,
      'deviceCode': deviceCode,
      'latitude': latitude,
      'longitude': longitude,
      'accuracyMeters': accuracyMeters,
      'qualityStatus': qualityStatus,
      'signalStatus': signalStatus,
      'deviceStatus': deviceStatus,
      'vehicleLabel': vehicleLabel,
      'driverName': driverName,
      'driverPhone': driverPhone,
      'studentName': studentName,
      'locationSource': locationSource,
      'coLocatedVehicleId': coLocatedVehicleId,
      'batteryLevel': batteryLevel,
      'signalQuality': signalQuality,
      'sourceType': sourceType,
      'recordedAt': recordedAt.toIso8601String(),
      'receivedAt': receivedAt?.toIso8601String(),
      'lastSeenAgeSeconds': lastSeenAgeSeconds,
      ...json,
    };
    final next = TrackerLocationViewModel.fromJson(merged);
    // Stale telemetry can still carry battery% while signal is OFFLINE — drop it.
    if (!next.hasLiveSignal && next.batteryLevel != null) {
      return TrackerLocationViewModel(
        assignmentId: next.assignmentId,
        targetType: next.targetType,
        targetId: next.targetId,
        deviceId: next.deviceId,
        deviceCode: next.deviceCode,
        latitude: next.latitude,
        longitude: next.longitude,
        accuracyMeters: next.accuracyMeters,
        qualityStatus: next.qualityStatus,
        signalStatus: next.signalStatus,
        deviceStatus: next.deviceStatus,
        vehicleLabel: next.vehicleLabel,
        driverName: next.driverName,
        driverPhone: next.driverPhone,
        studentName: next.studentName,
        locationSource: next.locationSource,
        coLocatedVehicleId: next.coLocatedVehicleId,
        batteryLevel: null,
        signalQuality: null,
        sourceType: next.sourceType,
        recordedAt: next.recordedAt,
        receivedAt: next.receivedAt,
        lastSeenAgeSeconds: next.lastSeenAgeSeconds,
      );
    }
    return next;
  }
}

class TrackingCheckpointViewModel {
  const TrackingCheckpointViewModel({
    required this.id,
    required this.name,
    required this.checkpointType,
    required this.sequenceNo,
    this.address,
    this.latitude,
    this.longitude,
    this.locationStatus,
    this.plannedStart,
  });

  final String id;
  final String name;
  final String checkpointType;
  final int sequenceNo;
  final String? address;
  final double? latitude;
  final double? longitude;
  final String? locationStatus;
  final DateTime? plannedStart;

  factory TrackingCheckpointViewModel.fromJson(Map<String, dynamic> json) {
    var latitude = (json['latitude'] as num?)?.toDouble();
    var longitude = (json['longitude'] as num?)?.toDouble();
    // A legacy checkpoint import stored some school coordinates as lng/lat.
    // Latitude outside ±90 is invalid, so this correction is unambiguous.
    if (latitude != null &&
        longitude != null &&
        latitude.abs() > 90 &&
        longitude.abs() <= 90) {
      final originalLatitude = latitude;
      latitude = longitude;
      longitude = originalLatitude;
    }
    return TrackingCheckpointViewModel(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? 'Checkpoint',
      checkpointType:
          json['kind']?.toString() ??
          json['checkpointType']?.toString() ??
          'DESTINATION',
      sequenceNo:
          (json['sortOrder'] as num?)?.toInt() ??
          (json['sequenceNo'] as num?)?.toInt() ??
          0,
      address: json['address']?.toString(),
      latitude: latitude,
      longitude: longitude,
      locationStatus: json['progressStatus']?.toString() ?? json['locationStatus']?.toString(),
      plannedStart: DateTime.tryParse(json['plannedStart']?.toString() ?? ''),
    );
  }
}

class TrackingAlertViewModel {
  const TrackingAlertViewModel({
    required this.id,
    required this.type,
    required this.severity,
    required this.status,
    required this.title,
    required this.message,
    this.assignmentId,
  });

  final String id;
  final String type;
  final String severity;
  final String status;
  final String title;
  final String message;
  final String? assignmentId;

  factory TrackingAlertViewModel.fromJson(Map<String, dynamic> json) {
    return TrackingAlertViewModel(
      id: json['id']?.toString() ?? '',
      type:
          json['alertType']?.toString() ??
          json['type']?.toString() ??
          'UNKNOWN',
      severity: json['severity']?.toString() ?? 'INFO',
      status: json['status']?.toString() ?? 'OPEN',
      title: json['title']?.toString() ?? 'Cảnh báo',
      message: json['message']?.toString() ?? '',
      assignmentId: json['assignmentId']?.toString(),
    );
  }
}

class TrackingSnapshotViewModel {
  const TrackingSnapshotViewModel({
    required this.locations,
    required this.checkpoints,
    required this.alerts,
  });

  final List<TrackerLocationViewModel> locations;
  final List<TrackingCheckpointViewModel> checkpoints;
  final List<TrackingAlertViewModel> alerts;

  factory TrackingSnapshotViewModel.fromJson(Map<String, dynamic> json) {
    List<T> parseList<T>(
      String key,
      T? Function(Map<String, dynamic>) parser,
    ) {
      return (json[key] as List? ?? const [])
          .whereType<Map>()
          .map((item) => parser(Map<String, dynamic>.from(item)))
          .whereType<T>()
          .toList(growable: false);
    }

    return TrackingSnapshotViewModel(
      locations: parseList('locations', TrackerLocationViewModel.tryParse),
      checkpoints: parseList(
        'checkpoints',
        (map) => TrackingCheckpointViewModel.fromJson(map),
      ),
      alerts: parseList(
        'activeAlerts',
        (map) => TrackingAlertViewModel.fromJson(map),
      ),
    );
  }
}

class TrackingOperationViewModel {
  const TrackingOperationViewModel({
    required this.operationPlanId,
    required this.status,
    this.schoolName,
    this.tourName,
    this.tourDate,
    this.vehicleCount = 0,
  });

  final String operationPlanId;
  final String status;
  final String? schoolName;
  final String? tourName;
  final DateTime? tourDate;
  final int vehicleCount;

  factory TrackingOperationViewModel.fromJson(Map<String, dynamic> json) {
    return TrackingOperationViewModel(
      operationPlanId: json['operationPlanId']?.toString() ?? '',
      status: json['status']?.toString() ?? 'UNKNOWN',
      schoolName: json['schoolName']?.toString(),
      tourName: json['tourName']?.toString(),
      tourDate: DateTime.tryParse(json['tourDate']?.toString() ?? ''),
      vehicleCount: (json['vehicleCount'] as num?)?.toInt() ?? 0,
    );
  }
}
