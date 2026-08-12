import 'package:flutter_test/flutter_test.dart';
import 'package:ventourkid_mobile/features/attendance/domain/entities/offline_attendance.dart';

void main() {
  test('GuideTourItineraryCheckpoint parses ARRIVED status and arrivedAt', () {
    final checkpoint = GuideTourItineraryCheckpoint.fromJson({
      'id': 'cp-1',
      'sortOrder': 1,
      'kind': 'NORMAL',
      'name': 'Điểm tham quan',
      'progressStatus': 'ARRIVED',
      'arrivedAt': '2026-08-06T07:30:00Z',
    });

    expect(checkpoint.isArrived, isTrue);
    expect(checkpoint.isCurrent, isFalse);
    expect(checkpoint.canComplete, isTrue);
    expect(checkpoint.arrivedAt, isNotNull);
  });
}
