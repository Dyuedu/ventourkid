class LivestreamSetupCheckpointOption {
  const LivestreamSetupCheckpointOption({
    required this.id,
    required this.name,
    required this.sortOrder,
  });

  factory LivestreamSetupCheckpointOption.fromJson(Map<String, dynamic> json) {
    return LivestreamSetupCheckpointOption(
      id: json['id'] as String,
      name: json['name'] as String? ?? 'Địa điểm',
      sortOrder: json['sortOrder'] as int? ?? 0,
    );
  }

  final String id;
  final String name;
  final int sortOrder;
}

class LivestreamSetupVehicleOption {
  const LivestreamSetupVehicleOption({required this.id, required this.label});

  factory LivestreamSetupVehicleOption.fromJson(Map<String, dynamic> json) {
    return LivestreamSetupVehicleOption(
      id: json['id'] as String,
      label: json['label'] as String? ?? 'Xe',
    );
  }

  final String id;
  final String label;
}

class LivestreamSetupPlanItemOption {
  const LivestreamSetupPlanItemOption({
    required this.id,
    required this.checkpointId,
    required this.operationVehicleId,
    required this.title,
    required this.audienceScope,
    required this.audienceVehicleIds,
    this.plannedStart,
    this.plannedEnd,
  });

  factory LivestreamSetupPlanItemOption.fromJson(Map<String, dynamic> json) {
    return LivestreamSetupPlanItemOption(
      id: json['id']?.toString() ?? '',
      checkpointId: json['checkpointId']?.toString() ?? '',
      operationVehicleId: json['operationVehicleId']?.toString() ?? '',
      title: json['title']?.toString() ?? 'Livestream',
      audienceScope: json['audienceScope']?.toString() ?? 'VEHICLE',
      audienceVehicleIds: (json['audienceVehicleIds'] as List<dynamic>? ?? [])
          .map((value) => value.toString())
          .toList(),
      plannedStart: DateTime.tryParse(json['plannedStart']?.toString() ?? ''),
      plannedEnd: DateTime.tryParse(json['plannedEnd']?.toString() ?? ''),
    );
  }

  final String id;
  final String checkpointId;
  final String operationVehicleId;
  final String title;
  final String audienceScope;
  final List<String> audienceVehicleIds;
  final DateTime? plannedStart;
  final DateTime? plannedEnd;
}

class LivestreamSetupOptions {
  const LivestreamSetupOptions({
    required this.tourId,
    required this.checkpoints,
    required this.vehicles,
    required this.myVehicleIds,
    required this.planItems,
  });

  factory LivestreamSetupOptions.fromJson(Map<String, dynamic> json) {
    return LivestreamSetupOptions(
      tourId: json['tourId'] as String,
      checkpoints: (json['checkpoints'] as List<dynamic>? ?? [])
          .map(
            (e) => LivestreamSetupCheckpointOption.fromJson(
              Map<String, dynamic>.from(e as Map),
            ),
          )
          .toList(),
      vehicles: (json['vehicles'] as List<dynamic>? ?? [])
          .map(
            (e) => LivestreamSetupVehicleOption.fromJson(
              Map<String, dynamic>.from(e as Map),
            ),
          )
          .toList(),
      myVehicleIds: (json['myVehicleIds'] as List<dynamic>? ?? [])
          .map((e) => e.toString())
          .toList(),
      planItems: (json['planItems'] as List<dynamic>? ?? [])
          .map(
            (e) => LivestreamSetupPlanItemOption.fromJson(
              Map<String, dynamic>.from(e as Map),
            ),
          )
          .toList(),
    );
  }

  final String tourId;
  final List<LivestreamSetupCheckpointOption> checkpoints;
  final List<LivestreamSetupVehicleOption> vehicles;
  final List<String> myVehicleIds;
  final List<LivestreamSetupPlanItemOption> planItems;
}

class ParentActiveLivestream {
  const ParentActiveLivestream({
    required this.sessionId,
    required this.tourId,
    required this.tourName,
    this.operationVehicleId,
    this.vehicleLabel,
    this.checkpointId,
    this.checkpointName,
    this.audienceScope,
    this.title,
    this.startedAt,
  });

  factory ParentActiveLivestream.fromJson(Map<String, dynamic> json) {
    return ParentActiveLivestream(
      sessionId: json['sessionId'] as String,
      tourId: json['tourId'] as String,
      tourName: json['tourName'] as String? ?? 'Chuyến đi',
      operationVehicleId: json['operationVehicleId'] as String?,
      vehicleLabel: json['vehicleLabel'] as String?,
      checkpointId: json['checkpointId'] as String?,
      checkpointName: json['checkpointName'] as String?,
      audienceScope: json['audienceScope'] as String?,
      title: json['title'] as String?,
      startedAt: json['startedAt'] as String?,
    );
  }

  final String sessionId;
  final String tourId;
  final String tourName;
  final String? operationVehicleId;
  final String? vehicleLabel;
  final String? checkpointId;
  final String? checkpointName;
  final String? audienceScope;
  final String? title;
  final String? startedAt;

  String get subtitle {
    final parts = <String>[];
    if (checkpointName != null && checkpointName!.isNotEmpty) {
      parts.add(checkpointName!);
    }
    if (vehicleLabel != null && vehicleLabel!.isNotEmpty) {
      parts.add(vehicleLabel!);
    }
    return parts.isEmpty ? 'Đang phát sóng' : parts.join(' • ');
  }
}
