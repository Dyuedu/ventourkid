import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/error/app_failure.dart';
import '../../../../core/network/api_exception.dart';
import '../../../../core/storage/token_storage.dart';
import '../../data/ai_chat_session_store.dart';
import '../../data/datasources/ai_assistant_remote_data_source.dart';
import '../../domain/entities/ai_chat.dart';
import 'ai_assistant_view_state.dart';

const _minUsableAnswerLength = 12;

class AiAssistantViewModel extends StateNotifier<AiAssistantViewState> {
  AiAssistantViewModel({
    required AiAssistantRemoteDataSource remoteDataSource,
    required TokenStorage tokenStorage,
    AiChatSessionStore? sessionStore,
    Uuid? uuid,
  }) : _remote = remoteDataSource,
       _tokenStorage = tokenStorage,
       _sessionStore = sessionStore ?? AiChatSessionStore(),
       _uuid = uuid ?? const Uuid(),
       super(const AiAssistantViewState());

  final AiAssistantRemoteDataSource _remote;
  final TokenStorage _tokenStorage;
  final AiChatSessionStore _sessionStore;
  final Uuid _uuid;

  Future<void> bootstrap() async {
    state = state.copyWith(isBootstrapping: true, clearError: true);
    try {
      final accountId = await _tokenStorage.getAccountId();
      final configFuture = _remote.getConfig();
      final sessionId = await _sessionStore.resolveSessionId(accountId);
      final conversation = await _remote.createOrResumeConversation(sessionId);
      final detail = await _remote.getConversationBySession(sessionId);
      final config = await configFuture;

      state = AiAssistantViewState(
        config: config,
        messages: detail.messages,
        conversationId: conversation.id,
        isBootstrapping: false,
      );
    } on Object catch (_) {
      state = state.copyWith(
        isBootstrapping: false,
      );
    }
  }

  Future<void> resetConversation() async {
    state = state.copyWith(isBootstrapping: true, clearError: true);
    try {
      final accountId = await _tokenStorage.getAccountId();
      final sessionId = await _sessionStore.resetSession(accountId);
      final conversation = await _remote.createOrResumeConversation(sessionId);
      state = state.copyWith(
        messages: const [],
        conversationId: conversation.id,
        isBootstrapping: false,
      );
    } on Object catch (error) {
      state = state.copyWith(
        isBootstrapping: false,
        errorMessage: _mapError(error, 'Không thể tạo hội thoại mới.'),
      );
    }
  }

  Future<void> sendMessage(String rawQuestion) async {
    final question = rawQuestion.trim();
    if (question.isEmpty) {
      state = state.copyWith(errorMessage: 'Vui lòng nhập câu hỏi.');
      return;
    }
    if (question.length > 2000) {
      state = state.copyWith(errorMessage: 'Câu hỏi quá dài (tối đa 2000 ký tự).');
      return;
    }
    if (!state.canSend) return;

    final conversationId = state.conversationId!;
    final userMessage = AiChatMessage(
      id: _uuid.v4(),
      role: 'user',
      content: question,
    );
    final assistantId = _uuid.v4();
    final assistantMessage = AiChatMessage(
      id: assistantId,
      role: 'assistant',
      content: '',
    );

    state = state.copyWith(
      messages: [...state.messages, userMessage, assistantMessage],
      isSending: true,
      clearError: true,
    );

    var doneAnswer = '';
    var receivedDone = false;

    try {
      try {
        await _remote.streamMessage(
          conversationId: conversationId,
          question: question,
          // Do not paint token-by-token — final answer comes from "done" (or /query fallback).
          onToken: (_) {},
          onDone: (data) {
            receivedDone = true;
            doneAnswer = data['answer']?.toString().trim() ?? '';
          },
        );
      } on Object {
        // Stream failed — fall through to sync /query.
      }

      var answer = doneAnswer;
      if (!receivedDone || !_isUsableAnswer(answer)) {
        try {
          final sync = await _remote.askQuestion(question);
          final syncAnswer = sync.answer.trim();
          if (_isUsableAnswer(syncAnswer) && syncAnswer.length >= answer.length) {
            answer = syncAnswer;
          } else if (syncAnswer.isNotEmpty && answer.isEmpty) {
            answer = syncAnswer;
          }
        } on Object {
          // Keep stream answer if any.
        }
      }

      if (answer.trim().isEmpty) {
        throw StateError('Trợ lý AI không trả về nội dung. Vui lòng thử lại.');
      }

      final updated = state.messages.map((message) {
        if (message.id != assistantId) return message;
        return message.copyWith(content: answer);
      }).toList();
      state = state.copyWith(messages: updated, isSending: false);
    } on Object catch (error) {
      final message = _mapError(error, 'Không thể gửi câu hỏi. Vui lòng thử lại.');
      final updated = state.messages.map((item) {
        if (item.id != assistantId) return item;
        return item.copyWith(content: message);
      }).toList();
      state = state.copyWith(
        messages: updated,
        isSending: false,
        errorMessage: message,
      );
    }
  }

  bool _isUsableAnswer(String answer) {
    return answer.trim().length >= _minUsableAnswerLength;
  }

  String _mapError(Object error, String fallback) {
    if (error is AppFailure) return error.message;
    final api = ApiException.maybeFrom(error);
    if (api?.statusCode == 429) {
      return 'Bạn đang gửi câu hỏi quá nhanh. Vui lòng thử lại sau ít phút.';
    }
    if (api?.statusCode == 503) {
      return 'Trợ lý AI đang khởi tạo kiến thức. Vui lòng thử lại sau.';
    }
    if (error is StateError && error.message.isNotEmpty) {
      return error.message;
    }
    return api?.message ?? fallback;
  }
}
