import 'package:flutter_test/flutter_test.dart';
import 'package:ventourkid_mobile/features/incident/domain/entities/incident_type.dart';

void main() {
  test('toJson emits backend enum names', () {
    expect(IncidentType.propertyDamage.toJson(), 'PROPERTY_DAMAGE');
    expect(IncidentType.lostStudent.toJson(), 'LOST_STUDENT');
    expect(IncidentType.medical.toJson(), 'MEDICAL');
  });

  test('fromJson accepts backend enum names', () {
    expect(IncidentType.fromJson('PROPERTY_DAMAGE'), IncidentType.propertyDamage);
    expect(IncidentType.fromJson('LOST_STUDENT'), IncidentType.lostStudent);
  });
}
