import '../../domain/entities/ai_chat.dart';

class AiAssistantViewState {
  const AiAssistantViewState({
    this.config = AiChatbotConfig.defaults,
    this.messages = const [],
    this.conversationId,
    this.isBootstrapping = true,
    this.isSending = false,
    this.errorMessage,
  });

  final AiChatbotConfig config;
  final List<AiChatMessage> messages;
  final String? conversationId;
  final bool isBootstrapping;
  final bool isSending;
  final String? errorMessage;

  bool get canSend =>
      !isBootstrapping &&
      !isSending &&
      conversationId != null &&
      config.enabled;

  AiAssistantViewState copyWith({
    AiChatbotConfig? config,
    List<AiChatMessage>? messages,
    String? conversationId,
    bool? isBootstrapping,
    bool? isSending,
    String? errorMessage,
    bool clearError = false,
  }) {
    return AiAssistantViewState(
      config: config ?? this.config,
      messages: messages ?? this.messages,
      conversationId: conversationId ?? this.conversationId,
      isBootstrapping: isBootstrapping ?? this.isBootstrapping,
      isSending: isSending ?? this.isSending,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }
}
