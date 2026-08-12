import 'package:flutter/material.dart';

/// Severity level of an incident (UC-INC-01, BR-101, BR-102).
enum IncidentSeverity {
  low,
  medium,
  high,
  critical;

  /// Human-readable Vietnamese label.
  String get label => switch (this) {
        IncidentSeverity.low => 'Thấp',
        IncidentSeverity.medium => 'Trung bình',
        IncidentSeverity.high => 'Cao',
        IncidentSeverity.critical => 'Khẩn cấp',
      };

  /// Color for severity chip UI.
  Color get color => switch (this) {
        IncidentSeverity.low => const Color(0xFF4CAF50),
        IncidentSeverity.medium => const Color(0xFFFF9800),
        IncidentSeverity.high => const Color(0xFFF44336),
        IncidentSeverity.critical => const Color(0xFF9C27B0),
      };

  static IncidentSeverity fromJson(String value) =>
      IncidentSeverity.values.firstWhere(
        (e) => e.name.toUpperCase() == value.toUpperCase(),
        orElse: () => IncidentSeverity.medium,
      );

  String toJson() => name.toUpperCase();
}
