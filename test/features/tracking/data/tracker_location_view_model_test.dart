import 'package:flutter_test/flutter_test.dart';
import 'package:ventourkid_mobile/features/tracking/domain/models/tracker_location_view_model.dart';

void main() {
  group('TrackerLocationViewModel', () {
    test('parses production backend DTO fields', () {
      final model = TrackerLocationViewModel.fromJson({
        'assignmentId': 'cccccccc-2000-4000-8000-000000000001',
        'targetType': 'VEHICLE',
        'targetId': null,
        'deviceId': null,
        'latitude': 21.028511,
        'longitude': 105.852598,
        'accuracyMeters': 5.0,
        'signalStatus': 'ONLINE',
        'batteryLevel': 85,
        'signalQuality': 90,
        'sourceType': 'GPS',
        'recordedAt': '2026-07-07T03:00:00Z',
        'lastSeenAgeSeconds': 12,
        'locationSource': 'DEVICE',
      });

      expect(model.latitude, 21.028511);
      expect(model.longitude, 105.852598);
      expect(model.signalStatus, 'ONLINE');
      expect(model.deviceId, isNull);
      expect(model.locationSource, 'DEVICE');
      expect(model.recordedAt.toUtc(), DateTime.parse('2026-07-07T03:00:00Z'));
    });

    test('parses student proxy fields and checkpoint/alert aliases', () {
      final student = TrackerLocationViewModel.fromJson({
        'assignmentId': 'student-1',
        'targetType': 'SELECTED_STUDENT',
        'latitude': 10.76,
        'longitude': 106.66,
        'signalStatus': 'ONLINE',
        'studentName': 'N***n',
        'locationSource': 'VEHICLE_PROXY',
        'coLocatedVehicleId': 'vehicle-1',
        'vehicleLabel': '51A-12345',
        'recordedAt': '2026-07-07T03:00:00Z',
      });
      expect(student.isVehicleProxy, isTrue);
      expect(student.displayTitle, contains('theo xe'));

      final checkpoint = TrackingCheckpointViewModel.fromJson({
        'id': 'cp-1',
        'name': 'Điểm A',
        'kind': 'ACTIVITY',
        'sortOrder': 2,
        'latitude': 10.8,
        'longitude': 106.7,
      });
      expect(checkpoint.checkpointType, 'ACTIVITY');
      expect(checkpoint.sequenceNo, 2);

      final alert = TrackingAlertViewModel.fromJson({
        'id': 'alert-1',
        'alertType': 'ETA_DELAY',
        'severity': 'WARNING',
        'status': 'OPEN',
        'title': 'Trễ',
        'message': 'Xe đang trễ',
      });
      expect(alert.type, 'ETA_DELAY');

      final snapshot = TrackingSnapshotViewModel.fromJson({
        'locations': [
          {
            'assignmentId': 'vehicle-1',
            'targetType': 'VEHICLE',
            'latitude': 10.76,
            'longitude': 106.66,
            'signalStatus': 'ONLINE',
            'recordedAt': '2026-07-07T03:00:00Z',
          },
          {
            'assignmentId': 'broken',
            'targetType': 'VEHICLE',
            'signalStatus': 'ONLINE',
          },
        ],
        'checkpoints': [
          {'id': 'cp-1', 'name': 'A', 'kind': 'SCHOOL', 'sortOrder': 0},
        ],
        'activeAlerts': [
          {
            'id': 'a1',
            'alertType': 'OFFLINE',
            'severity': 'WARNING',
            'status': 'OPEN',
            'title': 'Offline',
            'message': 'Mất tín hiệu',
          },
        ],
        'etas': [
          {
            'assignmentId': 'vehicle-1',
            'checkpointId': 'cp-1',
            'distanceMeters': 1200,
            'durationSeconds': 300,
            'delayed': false,
          },
        ],
      });
      // Keep tracker assignments with no fix so the UI can show their offline
      // state instead of silently hiding them.
      expect(snapshot.locations, hasLength(2));
      expect(snapshot.locations.last.hasCoordinates, isFalse);
      expect(snapshot.etas, hasLength(1));
      expect(snapshot.etas.first.distanceLabel, '1.2 km');
    });

    test('keeps an assignment without a location fix', () {
      final model = TrackerLocationViewModel.fromJson({
        'assignmentId': 'assignment-001',
        'signalStatus': 'ONLINE',
        'recordedAt': '2026-07-07T03:00:00Z',
      });
      expect(model.hasCoordinates, isFalse);
      expect(
        TrackerLocationViewModel.tryParse({
          'assignmentId': 'assignment-001',
          'signalStatus': 'ONLINE',
        }),
        isNotNull,
      );
    });
  });
}
