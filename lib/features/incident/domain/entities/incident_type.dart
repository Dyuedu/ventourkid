/// Classifies the nature of an incident (UC-INC-01, BR-58).
enum IncidentType {
  /// Medical issue, injury or illness during the tour.
  medical,

  /// Behavioral or disciplinary issue.
  behavioral,

  /// Physical injury.
  injury,

  /// Student cannot be located — triggers UC-EMG-01 emergency path.
  lostStudent,

  /// Vehicle or transport delay.
  delay,

  /// Equipment or property damage.
  propertyDamage,

  /// Any incident not covered by the above types.
  other;

  /// Human-readable Vietnamese label for UI display.
  String get label => switch (this) {
        IncidentType.medical => 'Y tế',
        IncidentType.behavioral => 'Hành vi',
        IncidentType.injury => 'Chấn thương',
        IncidentType.lostStudent => '⚠ Mất học sinh',
        IncidentType.delay => 'Trễ lịch trình',
        IncidentType.propertyDamage => 'Hư hỏng tài sản',
        IncidentType.other => 'Khác',
      };

  static IncidentType fromJson(String value) =>
      IncidentType.values.firstWhere(
        (e) => e.name.toUpperCase() == value.toUpperCase().replaceAll('_', ''),
        orElse: () => IncidentType.other,
      );

  String toJson() => switch (this) {
        IncidentType.medical => 'MEDICAL',
        IncidentType.behavioral => 'BEHAVIORAL',
        IncidentType.injury => 'INJURY',
        IncidentType.lostStudent => 'LOST_STUDENT',
        IncidentType.delay => 'DELAY',
        IncidentType.propertyDamage => 'PROPERTY_DAMAGE',
        IncidentType.other => 'OTHER',
      };
}
