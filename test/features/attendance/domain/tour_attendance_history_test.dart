import 'package:flutter_test/flutter_test.dart';
import 'package:ventourkid_mobile/features/attendance/domain/entities/tour_attendance_history.dart';

void main() {
  test('parses tour attendance history grouped by activity', () {
    final history = TourAttendanceHistory.fromJson({
      'tourId': 'tour-1',
      'tourName': 'Tham quan bảo tàng',
      'status': 'IN_PROGRESS',
      'tourDate': '2026-08-13',
      'schoolName': 'TH Nguyễn Du',
      'rosterCount': 2,
      'activities': [
        {
          'planItemId': 'item-1',
          'title': 'Điểm danh lên xe',
          'legType': 'BOARDING',
          'summary': {'total': 2, 'present': 1, 'absent': 0, 'pending': 1},
          'sessions': [
            {
              'sessionId': 'session-1',
              'status': 'OPEN',
              'startedByName': 'Cô Hoa',
            },
          ],
          'students': [
            {
              'rosterStudentId': 'st-1',
              'fullName': 'Nguyễn An',
              'className': '4A',
              'status': 'PRESENT',
              'method': 'FACE_RECOGNITION',
              'recordedAt': '2026-08-13T01:15:00Z',
              'markedByName': 'Cô Hoa',
            },
            {
              'rosterStudentId': 'st-2',
              'fullName': 'Trần Bình',
              'status': 'PENDING',
            },
          ],
        },
      ],
    });

    expect(history.tourName, 'Tham quan bảo tàng');
    expect(history.activities, hasLength(1));
    expect(history.activities.first.displayTitle, 'Điểm danh lên xe');
    expect(history.activities.first.countOf('present'), 1);
    expect(history.activities.first.students.first.normalizedStatus, 'PRESENT');
    expect(history.activities.first.students.first.markedByName, 'Cô Hoa');
  });

  test('scopedToPlanItem keeps only the opened attendance stop', () {
    final history = TourAttendanceHistory.fromJson({
      'tourId': 'tour-1',
      'tourName': 'Tham quan',
      'status': 'IN_PROGRESS',
      'rosterCount': 1,
      'activities': [
        {
          'planItemId': 'item-dest-a',
          'title': 'Xuống xe',
          'destinationName': 'Bảo tàng',
          'summary': {'total': 1, 'present': 1, 'absent': 0, 'pending': 0},
          'sessions': [
            {'sessionId': 's-a', 'status': 'CLOSED'},
          ],
          'students': [
            {
              'rosterStudentId': 'st-1',
              'fullName': 'Nguyễn An',
              'status': 'PRESENT',
            },
          ],
        },
        {
          'planItemId': 'item-dest-b',
          'title': 'Xuống xe',
          'destinationName': 'Công viên',
          'summary': {'total': 1, 'present': 0, 'absent': 0, 'pending': 1},
          'students': [
            {
              'rosterStudentId': 'st-1',
              'fullName': 'Nguyễn An',
              'status': 'PENDING',
            },
          ],
        },
      ],
    });

    final scoped = history.scopedToPlanItem('item-dest-b');
    expect(scoped.activities, hasLength(1));
    expect(scoped.activities.first.planItemId, 'item-dest-b');
    expect(scoped.activities.first.destinationName, 'Công viên');
    expect(samePlanItemId('item-dest-a', 'ITEM-DEST-A'), isTrue);
  });
}
