class AppNotification {
  const AppNotification({
    required this.recipientId,
    required this.notificationId,
    required this.type,
    required this.priority,
    required this.category,
    required this.title,
    required this.body,
    this.referenceId,
    this.referenceType,
    this.payload = const {},
    this.sourceEvent,
    required this.read,
    this.readAt,
    this.createdAt,
  });

  final String recipientId;
  final String notificationId;
  final String type;
  final String priority;
  final String category;
  final String title;
  final String body;
  final String? referenceId;
  final String? referenceType;
  final Map<String, dynamic> payload;
  final String? sourceEvent;
  final bool read;
  final DateTime? readAt;
  final DateTime? createdAt;

  String? get mobileActionPath {
    final value = payload['mobileActionPath'] ?? payload['actionPath'];
    return value?.toString();
  }

  String? get tourId => payload['tourId']?.toString() ??
      payload['operationPlanId']?.toString() ??
      referenceId;

  factory AppNotification.fromJson(Map<String, dynamic> json) {
    return AppNotification(
      recipientId: json['recipientId']?.toString() ?? '',
      notificationId: json['notificationId']?.toString() ?? '',
      type: json['type']?.toString() ?? 'SYSTEM',
      priority: json['priority']?.toString() ?? 'NORMAL',
      category: json['category']?.toString() ?? 'ACTIVITY',
      title: json['title']?.toString() ?? '',
      body: json['body']?.toString() ?? '',
      referenceId: json['referenceId']?.toString(),
      referenceType: json['referenceType']?.toString(),
      payload: json['payload'] is Map
          ? Map<String, dynamic>.from(json['payload'] as Map)
          : const {},
      sourceEvent: json['sourceEvent']?.toString(),
      read: json['read'] == true,
      readAt: _parseInstant(json['readAt']),
      createdAt: _parseInstant(json['createdAt']),
    );
  }

  AppNotification copyWith({bool? read, DateTime? readAt}) {
    return AppNotification(
      recipientId: recipientId,
      notificationId: notificationId,
      type: type,
      priority: priority,
      category: category,
      title: title,
      body: body,
      referenceId: referenceId,
      referenceType: referenceType,
      payload: payload,
      sourceEvent: sourceEvent,
      read: read ?? this.read,
      readAt: readAt ?? this.readAt,
      createdAt: createdAt,
    );
  }

  static DateTime? _parseInstant(dynamic value) {
    if (value == null) return null;
    return DateTime.tryParse(value.toString());
  }
}

class NotificationPage {
  const NotificationPage({
    required this.items,
    required this.totalElements,
    required this.totalPages,
    required this.page,
    required this.size,
    required this.unreadCount,
  });

  final List<AppNotification> items;
  final int totalElements;
  final int totalPages;
  final int page;
  final int size;
  final int unreadCount;

  factory NotificationPage.fromJson(Map<String, dynamic> json) {
    final rawItems = json['items'];
    final items = rawItems is List
        ? rawItems
            .whereType<Map>()
            .map((e) => AppNotification.fromJson(Map<String, dynamic>.from(e)))
            .toList()
        : <AppNotification>[];
    return NotificationPage(
      items: items,
      totalElements: (json['totalElements'] as num?)?.toInt() ?? items.length,
      totalPages: (json['totalPages'] as num?)?.toInt() ?? 1,
      page: (json['page'] as num?)?.toInt() ?? 0,
      size: (json['size'] as num?)?.toInt() ?? items.length,
      unreadCount: (json['unreadCount'] as num?)?.toInt() ?? 0,
    );
  }
}
