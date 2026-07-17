/// Chat message list widget, extracted from chat_screen.dart as part of
/// P1 task 2.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants/app_constants.dart';
import '../../core/i18n/app_localizations.dart';
import '../../core/theme/app_colors.dart';
import '../../features/chat/data/tts_playback_service.dart';
import '../../features/chat/domain/chat_models.dart';
import 'chat_bubble.dart';
import 'chat_providers.dart';

/// Scrollable list of chat messages with typing indicator and inline
/// corrections + phoneme score colour-tagging.
class ChatMessageList extends ConsumerWidget {
  final String sessionId;
  final ScrollController scrollController;
  final bool isAiThinking;
  final String? playingMessageId;
  final Future<void> Function(String messageId, String text) onPlayTts;
  final TtsPlaybackService ttsPlaybackService;

  /// P1 task 1 — live streaming text for the in-progress AI message.
  /// When non-null, a streaming bubble is appended after the last saved
  /// message.
  final String? streamingText;

  /// P1 task 3 — set of message IDs whose TTS playback failed, to show
  /// the inline retry button (E14).
  final Set<String> ttsFailedMessageIds;

  /// E14 — callback for the inline TTS retry button.
  final Future<void> Function(String messageId, String text)? onRetryTts;

  const ChatMessageList({
    super.key,
    required this.sessionId,
    required this.scrollController,
    required this.onPlayTts,
    required this.ttsPlaybackService,
    this.isAiThinking = false,
    this.playingMessageId,
    this.streamingText,
    this.ttsFailedMessageIds = const {},
    this.onRetryTts,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final messagesAsync = ref.watch(messagesProvider(sessionId));
    final correctionsAsync = ref.watch(correctionsByMessageProvider(sessionId));
    final phonemeAsync = ref.watch(phonemeScoresProvider(sessionId));

    return messagesAsync.when(
      data: (messages) {
        if (messages.isEmpty && !isAiThinking && streamingText == null) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.chat_bubble_outline,
                  size: 48,
                  color: AppColors.textMuted.withValues(alpha: 0.3),
                ),
                const SizedBox(height: AppSpacing.md),
                Text(
                  l.t('chat.start_conversation'),
                  style: Theme.of(context)
                      .textTheme
                      .bodyLarge
                      ?.copyWith(color: AppColors.textMuted),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  l.t('chat.start_hint'),
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(color: AppColors.textMuted),
                ),
              ],
            ),
          );
        }

        final correctionsByMsg = correctionsAsync.valueOrNull ?? const {};
        final phonemeByMsg = phonemeAsync.valueOrNull ?? const {};

        // +1 for the typing indicator or streaming bubble.
        final extraCount = (isAiThinking || streamingText != null) ? 1 : 0;
        return ListView.builder(
          controller: scrollController,
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
          itemCount: messages.length + extraCount,
          itemBuilder: (context, index) {
            if (index == messages.length) {
              // P1 task 1 — if we have streaming text, show the streaming
              // bubble instead of the typing dots.
              if (streamingText != null) {
                return ChatBubble(
                  key: const ValueKey('__streaming__'),
                  message: '',
                  streamingText: streamingText,
                  isUser: false,
                  ttsPlaybackService: ttsPlaybackService,
                );
              }
              return const TypingBubble();
            }
            final msg = messages[index];
            final isUser = msg.role == MessageRole.user;
            final phonemeSet = phonemeByMsg[msg.id];
            return ChatBubble(
              key: ValueKey(msg.id),
              message: msg.content,
              isUser: isUser,
              isVoiceTranscript: msg.audioPath == 'voice_transcript',
              isPlaying: playingMessageId == msg.id,
              corrections: correctionsByMsg[msg.id] ?? const [],
              phonemeScores: phonemeSet?.byPosition,
              onPlayTts: isUser ? null : () => onPlayTts(msg.id, msg.content),
              ttsFailed: ttsFailedMessageIds.contains(msg.id),
              onRetryTts: onRetryTts != null
                  ? () => onRetryTts!(msg.id, msg.content)
                  : null,
              ttsPlaybackService: ttsPlaybackService,
            );
          },
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) =>
          Center(child: Text(l.tArg('chat.error', {'error': e.toString()}))),
    );
  }
}
