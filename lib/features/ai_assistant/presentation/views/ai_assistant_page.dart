import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/providers.dart';
import '../../../../shared/theme/app_theme.dart';
import '../../../../shared/widgets/app_back_leading.dart';
import '../../domain/entities/ai_chat.dart';

class AiAssistantPage extends ConsumerStatefulWidget {
  const AiAssistantPage({super.key});

  @override
  ConsumerState<AiAssistantPage> createState() => _AiAssistantPageState();
}

class _AiAssistantPageState extends ConsumerState<AiAssistantPage> {
  final _composerController = TextEditingController();
  final _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(aiAssistantViewModelProvider.notifier).bootstrap();
    });
  }

  @override
  void dispose() {
    _composerController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _send([String? preset]) async {
    final text = (preset ?? _composerController.text).trim();
    if (text.isEmpty) return;
    _composerController.clear();
    await ref.read(aiAssistantViewModelProvider.notifier).sendMessage(text);
    _scrollToBottom();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent + 80,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(aiAssistantViewModelProvider);
    ref.listen(aiAssistantViewModelProvider, (previous, next) {
      final prevLen = previous?.messages.length ?? 0;
      final nextLen = next.messages.length;
      final prevTail = previous?.messages.isNotEmpty == true
          ? previous!.messages.last.content
          : null;
      final nextTail =
          next.messages.isNotEmpty ? next.messages.last.content : null;
      if (prevLen != nextLen || (next.isSending && prevTail != nextTail)) {
        _scrollToBottom();
      }
    });

    return Scaffold(
      backgroundColor: AppTheme.surfaceLight,
      appBar: AppBar(
        leading: buildAppBackLeading(
          context,
          fallbackRoute: '/parent/dashboard',
        ),
        title: const Text('Trợ lý VentourKid'),
        actions: [
          IconButton(
            tooltip: 'Hội thoại mới',
            onPressed: state.isBootstrapping || state.isSending
                ? null
                : () => ref
                    .read(aiAssistantViewModelProvider.notifier)
                    .resetConversation(),
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: Column(
        children: [
          if (!state.config.enabled)
            MaterialBanner(
              backgroundColor: AppTheme.primarySoft,
              content: const Text('Trợ lý AI hiện đang tạm tắt.'),
              actions: [
                TextButton(
                  onPressed: () => ref
                      .read(aiAssistantViewModelProvider.notifier)
                      .bootstrap(),
                  child: const Text('Thử lại'),
                ),
              ],
            ),
          if (state.config.disclaimer.isNotEmpty)
            Container(
              width: double.infinity,
              color: AppTheme.primarySoft.withValues(alpha: 0.65),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: Text(
                state.config.disclaimer,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppTheme.onSurfaceVariant,
                    ),
              ),
            ),
          Expanded(
            child: state.isBootstrapping
                ? const Center(child: CircularProgressIndicator())
                : _MessageList(
                    messages: state.messages,
                    welcomeMessage: state.config.welcomeMessage,
                    suggestedQuestions: state.config.suggestedQuestions,
                    isSending: state.isSending,
                    scrollController: _scrollController,
                    onSuggestionTap: state.canSend ? (q) => _send(q) : null,
                  ),
          ),
          if (state.errorMessage != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Text(
                state.errorMessage!,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppTheme.accentRed,
                    ),
              ),
            ),
          SafeArea(
            top: false,
            child: Container(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
              decoration: BoxDecoration(
                color: AppTheme.surface,
                border: const Border(
                  top: BorderSide(color: AppTheme.neutral200),
                ),
                boxShadow: AppTheme.shadowSm,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _composerController,
                      minLines: 1,
                      maxLines: 4,
                      textInputAction: TextInputAction.send,
                      enabled: state.canSend,
                      onSubmitted: (_) => _send(),
                      decoration: InputDecoration(
                        hintText: 'Nhập câu hỏi của bạn…',
                        filled: true,
                        fillColor: AppTheme.surfaceLow,
                        border: OutlineInputBorder(
                          borderRadius:
                              BorderRadius.circular(AppTheme.radiusLg),
                          borderSide:
                              const BorderSide(color: AppTheme.neutral200),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius:
                              BorderRadius.circular(AppTheme.radiusLg),
                          borderSide:
                              const BorderSide(color: AppTheme.neutral200),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius:
                              BorderRadius.circular(AppTheme.radiusLg),
                          borderSide: const BorderSide(
                            color: AppTheme.primary,
                            width: 1.5,
                          ),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 12,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.filled(
                    onPressed: state.canSend ? () => _send() : null,
                    style: IconButton.styleFrom(
                      backgroundColor: AppTheme.cta,
                      foregroundColor: Colors.white,
                      disabledBackgroundColor: AppTheme.neutral300,
                      minimumSize: const Size(48, 48),
                    ),
                    icon: state.isSending
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.send_rounded),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MessageList extends StatelessWidget {
  const _MessageList({
    required this.messages,
    required this.welcomeMessage,
    required this.suggestedQuestions,
    required this.isSending,
    required this.scrollController,
    required this.onSuggestionTap,
  });

  final List<AiChatMessage> messages;
  final String welcomeMessage;
  final List<String> suggestedQuestions;
  final bool isSending;
  final ScrollController scrollController;
  final ValueChanged<String>? onSuggestionTap;

  @override
  Widget build(BuildContext context) {
    final showWelcome = messages.isEmpty;

    return ListView(
      controller: scrollController,
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
      children: [
        if (showWelcome) ...[
          _Bubble(
            message: AiChatMessage(
              id: 'welcome',
              role: 'assistant',
              content: welcomeMessage,
            ),
          ),
          if (suggestedQuestions.isNotEmpty) ...[
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: suggestedQuestions
                  .map(
                    (question) => ActionChip(
                      label: Text(question),
                      onPressed: onSuggestionTap == null
                          ? null
                          : () => onSuggestionTap!(question),
                    ),
                  )
                  .toList(),
            ),
          ],
        ],
        ...messages.map((message) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _Bubble(message: message),
            )),
        if (isSending &&
            messages.isNotEmpty &&
            messages.last.role == 'assistant' &&
            messages.last.content.isEmpty)
          const Padding(
            padding: EdgeInsets.only(top: 4),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text('Đang soạn câu trả lời…'),
            ),
          ),
      ],
    );
  }
}

class _Bubble extends StatelessWidget {
  const _Bubble({required this.message});

  final AiChatMessage message;

  @override
  Widget build(BuildContext context) {
    final isUser = message.isUser;
    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.sizeOf(context).width * 0.82,
        ),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: isUser ? AppTheme.primary : AppTheme.surface,
            borderRadius: BorderRadius.only(
              topLeft: const Radius.circular(16),
              topRight: const Radius.circular(16),
              bottomLeft: Radius.circular(isUser ? 16 : 4),
              bottomRight: Radius.circular(isUser ? 4 : 16),
            ),
            border: isUser ? null : Border.all(color: AppTheme.neutral200),
            boxShadow: isUser ? null : AppTheme.shadowSm,
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            child: Text(
              message.content.isEmpty && !isUser ? '…' : message.content,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: isUser ? Colors.white : AppTheme.onSurface,
                    height: 1.4,
                  ),
            ),
          ),
        ),
      ),
    );
  }
}
