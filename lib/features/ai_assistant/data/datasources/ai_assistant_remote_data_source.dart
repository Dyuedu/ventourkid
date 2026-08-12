import 'dart:convert';

import 'package:dio/dio.dart';

import '../../../../core/network/dio_client.dart';
import '../../domain/entities/ai_chat.dart';

abstract interface class AiAssistantRemoteDataSource {
  Future<AiChatbotConfig> getConfig();

  Future<AiConversationSummary> createOrResumeConversation(String sessionId);

  Future<AiConversationDetail> getConversationBySession(String sessionId);

  Future<AiQueryAnswer> askQuestion(String question);

  Future<void> streamMessage({
    required String conversationId,
    required String question,
    void Function(String text)? onToken,
    void Function(Map<String, dynamic> data)? onDone,
  });
}

class AiQueryAnswer {
  const AiQueryAnswer({required this.answer});

  final String answer;
}

class AiAssistantRemoteDataSourceImpl implements AiAssistantRemoteDataSource {
  AiAssistantRemoteDataSourceImpl(this._dioClient);

  final DioClient _dioClient;

  @override
  Future<AiChatbotConfig> getConfig() async {
    final response = await _dioClient.dio.get<dynamic>('/v1/ai/config');
    final data = _asMap(response.data);
    final suggestions = data['suggestedQuestions'];
    return AiChatbotConfig(
      enabled: data['enabled'] as bool? ?? true,
      welcomeMessage:
          (data['welcomeMessage'] as String?)?.trim().isNotEmpty == true
          ? data['welcomeMessage'] as String
          : AiChatbotConfig.defaults.welcomeMessage,
      disclaimer: (data['disclaimer'] as String?)?.trim().isNotEmpty == true
          ? data['disclaimer'] as String
          : AiChatbotConfig.defaults.disclaimer,
      suggestedQuestions: suggestions is List && suggestions.isNotEmpty
          ? suggestions.map((e) => e.toString()).where((e) => e.isNotEmpty).toList()
          : AiChatbotConfig.defaults.suggestedQuestions,
      audienceLabel: data['audienceLabel']?.toString(),
    );
  }

  @override
  Future<AiConversationSummary> createOrResumeConversation(String sessionId) async {
    final response = await _dioClient.dio.post<dynamic>(
      '/v1/ai/conversations',
      data: {'sessionId': sessionId},
    );
    final data = _asMap(response.data);
    return AiConversationSummary(
      id: data['id']?.toString() ?? '',
      sessionId: data['sessionId']?.toString() ?? sessionId,
    );
  }

  @override
  Future<AiConversationDetail> getConversationBySession(String sessionId) async {
    final response = await _dioClient.dio.get<dynamic>(
      '/v1/ai/conversations/${Uri.encodeComponent(sessionId)}',
    );
    final data = _asMap(response.data);
    final rawMessages = data['messages'];
    final messages = <AiChatMessage>[];
    if (rawMessages is List) {
      for (final item in rawMessages) {
        final map = _asMap(item);
        final role = (map['role']?.toString() ?? 'assistant').toLowerCase();
        messages.add(
          AiChatMessage(
            id: map['id']?.toString() ?? DateTime.now().microsecondsSinceEpoch.toString(),
            role: role == 'user' ? 'user' : 'assistant',
            content: map['content']?.toString() ?? '',
          ),
        );
      }
    }
    return AiConversationDetail(
      id: data['id']?.toString() ?? '',
      sessionId: data['sessionId']?.toString() ?? sessionId,
      messages: messages,
    );
  }

  @override
  Future<AiQueryAnswer> askQuestion(String question) async {
    final response = await _dioClient.dio.post<dynamic>(
      '/v1/ai/query',
      data: {'question': question},
      options: Options(
        receiveTimeout: const Duration(seconds: 60),
        sendTimeout: const Duration(seconds: 30),
      ),
    );
    final data = _asMap(response.data);
    return AiQueryAnswer(answer: data['answer']?.toString().trim() ?? '');
  }

  @override
  Future<void> streamMessage({
    required String conversationId,
    required String question,
    void Function(String text)? onToken,
    void Function(Map<String, dynamic> data)? onDone,
  }) async {
    final response = await _dioClient.dio.post<ResponseBody>(
      '/v1/ai/messages/stream',
      data: {
        'conversationId': conversationId,
        'question': question,
      },
      options: Options(
        responseType: ResponseType.stream,
        headers: const {
          'Accept': 'text/event-stream',
          'Cache-Control': 'no-cache',
        },
        receiveTimeout: const Duration(minutes: 2),
        sendTimeout: const Duration(seconds: 30),
      ),
    );

    final body = response.data;
    if (body == null) {
      throw StateError('Không nhận được luồng phản hồi từ trợ lý AI.');
    }

    final buffer = StringBuffer();
    await for (final chunk in body.stream) {
      buffer.write(utf8.decode(chunk, allowMalformed: true));
      final parsed = _takeCompleteSseBlocks(buffer.toString());
      buffer
        ..clear()
        ..write(parsed.remainder);

      for (final event in parsed.events) {
        _dispatchSseEvent(event, onToken: onToken, onDone: onDone);
      }
    }

    final leftover = buffer.toString();
    if (leftover.trim().isNotEmpty) {
      final parsed = _takeCompleteSseBlocks('$leftover\n\n');
      for (final event in parsed.events) {
        _dispatchSseEvent(event, onToken: onToken, onDone: onDone);
      }
    }
  }

  void _dispatchSseEvent(
    _SseEvent event, {
    void Function(String text)? onToken,
    void Function(Map<String, dynamic> data)? onDone,
  }) {
    if (event.name == 'token') {
      final text = event.data is Map ? event.data['text']?.toString() : event.data?.toString();
      if (text != null && text.isNotEmpty) onToken?.call(text);
    } else if (event.name == 'done') {
      if (event.data is Map<String, dynamic>) {
        onDone?.call(event.data as Map<String, dynamic>);
      } else if (event.data is Map) {
        onDone?.call(Map<String, dynamic>.from(event.data as Map));
      }
    } else if (event.name == 'error') {
      final message = event.data is Map
          ? event.data['message']?.toString()
          : event.data?.toString();
      throw StateError(message ?? 'Luồng phản hồi AI gặp lỗi.');
    }
  }

  Map<String, dynamic> _asMap(dynamic value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) return Map<String, dynamic>.from(value);
    return const {};
  }

  _SseParseResult _takeCompleteSseBlocks(String buffer) {
    final normalized = buffer.replaceAll('\r\n', '\n').replaceAll('\r', '\n');
    final parts = normalized.split('\n\n');
    final remainder = parts.isEmpty ? '' : parts.removeLast();
    final events = <_SseEvent>[];
    for (final block in parts) {
      final event = _parseSseBlock(block);
      if (event != null) events.add(event);
    }
    return _SseParseResult(events, remainder);
  }

  _SseEvent? _parseSseBlock(String block) {
    if (block.trim().isEmpty) return null;
    var eventName = 'message';
    final dataLines = <String>[];
    for (final rawLine in block.split('\n')) {
      final line = rawLine.replaceFirst(RegExp(r'^\uFEFF'), '');
      if (line.startsWith('event:')) {
        eventName = line.substring('event:'.length).trim();
      } else if (line.startsWith('data:')) {
        var value = line.substring('data:'.length);
        if (value.startsWith(' ')) value = value.substring(1);
        dataLines.add(value);
      }
    }
    if (dataLines.isEmpty) return null;
    final dataRaw = dataLines.join('\n');
    try {
      return _SseEvent(eventName, jsonDecode(dataRaw));
    } catch (_) {
      return _SseEvent(eventName, dataRaw);
    }
  }
}

class _SseEvent {
  const _SseEvent(this.name, this.data);
  final String name;
  final dynamic data;
}

class _SseParseResult {
  const _SseParseResult(this.events, this.remainder);
  final List<_SseEvent> events;
  final String remainder;
}
