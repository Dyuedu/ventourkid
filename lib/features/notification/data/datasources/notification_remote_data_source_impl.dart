import '../../../../core/network/dio_client.dart';
import '../models/notification_models.dart';
import 'notification_remote_data_source.dart';

class NotificationRemoteDataSourceImpl implements NotificationRemoteDataSource {
  NotificationRemoteDataSourceImpl(this._dio);

  final DioClient _dio;
  static const _base = '/v1/notifications';

  @override
  Future<NotificationPage> listInbox({
    String filter = 'ALL',
    int page = 0,
    int size = 30,
  }) async {
    final response = await _dio.dio.get(
      _base,
      queryParameters: {'filter': filter, 'page': page, 'size': size},
    );
    return NotificationPage.fromJson(
      Map<String, dynamic>.from(response.data['data'] as Map),
    );
  }

  @override
  Future<int> unreadCount() async {
    final response = await _dio.dio.get('$_base/unread-count');
    final data = Map<String, dynamic>.from(response.data['data'] as Map);
    return (data['unreadCount'] as num?)?.toInt() ?? 0;
  }

  @override
  Future<AppNotification> markRead(String recipientId) async {
    final response = await _dio.dio.patch('$_base/$recipientId/read');
    return AppNotification.fromJson(
      Map<String, dynamic>.from(response.data['data'] as Map),
    );
  }

  @override
  Future<int> markAllRead() async {
    final response = await _dio.dio.patch('$_base/read-all');
    final data = Map<String, dynamic>.from(response.data['data'] as Map);
    return (data['updatedCount'] as num?)?.toInt() ?? 0;
  }

  @override
  Future<void> registerDeviceToken({
    required String token,
    String platform = 'ANDROID',
    String? deviceId,
  }) async {
    await _dio.dio.post(
      '$_base/device-tokens',
      data: {
        'token': token,
        'platform': platform,
        if (deviceId != null && deviceId.isNotEmpty) 'deviceId': deviceId,
      },
    );
  }

  @override
  Future<void> unregisterDeviceToken(String token) async {
    await _dio.dio.delete(
      '$_base/device-tokens',
      queryParameters: {'token': token},
    );
  }
}
