import '../models/notification_models.dart';

abstract class NotificationRemoteDataSource {
  Future<NotificationPage> listInbox({
    String filter = 'ALL',
    int page = 0,
    int size = 30,
  });

  Future<int> unreadCount();

  Future<AppNotification> markRead(String recipientId);

  Future<int> markAllRead();

  Future<void> registerDeviceToken({
    required String token,
    String platform = 'ANDROID',
    String? deviceId,
  });

  Future<void> unregisterDeviceToken(String token);
}
