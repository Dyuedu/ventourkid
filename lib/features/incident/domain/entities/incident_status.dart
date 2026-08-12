import 'package:flutter/material.dart';

/// Lifecycle status of an incident report (UC-INC-01 → UC-INC-05, BR-58).
enum IncidentStatus {
  open,
  acknowledged,
  escalated,
  resolved,
  closed;

  /// Human-readable Vietnamese label.
  String get label => switch (this) {
        IncidentStatus.open => 'Mới',
        IncidentStatus.acknowledged => 'Đã tiếp nhận',
        IncidentStatus.escalated => 'Đã leo thang',
        IncidentStatus.resolved => 'Đã giải quyết',
        IncidentStatus.closed => 'Đã đóng',
      };

  /// Color for status chip UI.
  Color get color => switch (this) {
        IncidentStatus.open => const Color(0xFF2196F3),
        IncidentStatus.acknowledged => const Color(0xFFFF9800),
        IncidentStatus.escalated => const Color(0xFFF44336),
        IncidentStatus.resolved => const Color(0xFF4CAF50),
        IncidentStatus.closed => const Color(0xFF9E9E9E),
      };

  static IncidentStatus fromJson(String value) =>
      IncidentStatus.values.firstWhere(
        (e) => e.name.toUpperCase() == value.toUpperCase(),
        orElse: () => IncidentStatus.open,
      );

  String toJson() => name.toUpperCase();
}
