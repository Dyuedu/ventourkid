class AiChatMessage {
  const AiChatMessage({
    required this.id,
    required this.role,
    required this.content,
  });

  final String id;
  final String role; // user | assistant
  final String content;

  AiChatMessage copyWith({String? content}) {
    return AiChatMessage(
      id: id,
      role: role,
      content: content ?? this.content,
    );
  }

  bool get isUser => role == 'user';
}

class AiChatbotConfig {
  const AiChatbotConfig({
    required this.enabled,
    required this.welcomeMessage,
    required this.disclaimer,
    required this.suggestedQuestions,
    this.audienceLabel,
  });

  final bool enabled;
  final String welcomeMessage;
  final String disclaimer;
  final List<String> suggestedQuestions;
  final String? audienceLabel;

  static const defaults = AiChatbotConfig(
    enabled: true,
    welcomeMessage: 'Xin chào! Tôi là trợ lý VentourKids. Bạn cần hỗ trợ gì?',
    disclaimer: 'Trợ lý AI chỉ trả lời dựa trên nội dung đã được phê duyệt.',
    suggestedQuestions: [
      'Tour có những điểm tham quan nào?',
      'Làm sao để theo dõi vị trí của con?',
      'Điểm danh khuôn mặt hoạt động như thế nào?',
    ],
  );
}

class AiConversationSummary {
  const AiConversationSummary({
    required this.id,
    required this.sessionId,
  });

  final String id;
  final String sessionId;
}

class AiConversationDetail {
  const AiConversationDetail({
    required this.id,
    required this.sessionId,
    required this.messages,
  });

  final String id;
  final String sessionId;
  final List<AiChatMessage> messages;
}
