import 'package:flutter_test/flutter_test.dart';
import 'package:ventourkid_mobile/features/media/domain/entities/tour_media_item.dart';

void main() {
  test('parses parent media snake case response with image url', () {
    final item = TourMediaItem.fromJson({
      'media_id': 'media-1',
      'tour_id': 'tour-1',
      'activity_id': 'activity-1',
      'file_url': 'https://cdn.example.test/media.jpg',
      'thumbnail_url': 'https://cdn.example.test/thumb.jpg',
      'media_type': 'IMAGE',
      'face_processing_status': 'COMPLETED',
      'taken_at': '2026-08-02T10:15:00Z',
      'face_matches': [
        {
          'student_id': 'student-1',
          'studentDisplayName': 'An Nguyen',
          'confidence': 0.91,
          'matchStatus': 'MATCHED',
        },
      ],
    });

    expect(item.id, 'media-1');
    expect(item.tourId, 'tour-1');
    expect(item.activityId, 'activity-1');
    expect(item.fileUrl, 'https://cdn.example.test/media.jpg');
    expect(item.mediaType, 'IMAGE');
    expect(item.faceProcessingStatus, 'COMPLETED');
    expect(item.createdAt, DateTime.parse('2026-08-02T10:15:00Z'));
    expect(item.faceMatches.single.studentDisplayName, 'An Nguyen');
  });
}
