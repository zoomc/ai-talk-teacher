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

  /// Optional callback invoked when the empty-state primary CTA is tapped
  /// (VA-001, VA-211).
  final VoidCallback? onStartTap;

  /// Callback for quick-start suggestions. The selected prompt is sent as a
  /// real user turn instead of merely focusing an invisible text field.
  final Future<void> Function(String text)? onSuggestionTap;

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
    this.onStartTap,
    this.onSuggestionTap,
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
          return _EmptyConversation(
            l: l,
            onStartTap: onStartTap,
            onSuggestionTap: onSuggestionTap,
          );
        }

        final correctionsByMsg = correctionsAsync.valueOrNull ?? const {};
        final phonemeByMsg = phonemeAsync.valueOrNull ?? const {};

        // +1 for the typing indicator or streaming bubble.
        final extraCount = (isAiThinking || streamingText != null) ? 1 : 0;
        // Determine the latest AI message so only it shows the Listen button
        // by default (VA-064, VA-153).
        final latestAiIndex = messages.lastIndexWhere(
          (m) => m.role != MessageRole.user,
        );

        return ListView.builder(
          controller: scrollController,
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
          itemCount: messages.length + extraCount,
          reverse: false,
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
                  showTtsButton: false,
                );
              }
              return Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const TypingBubble(),
                  Padding(
                    padding: const EdgeInsets.only(
                      left: AppSpacing.md,
                      top: AppSpacing.xxs,
                    ),
                    child: Text(
                      l.t('chat.thinking'),
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.textMuted,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              );
            }
            final msg = messages[index];
            final isUser = msg.role == MessageRole.user;
            final phonemeSet = phonemeByMsg[msg.id];
            final prevIsUser =
                index > 0 && messages[index - 1].role == MessageRole.user;
            final gapTop = index == 0
                ? 0.0
                : (prevIsUser == isUser ? AppSpacing.xxs : AppSpacing.md);
            return Padding(
              padding: EdgeInsets.only(top: gapTop),
              child: ChatBubble(
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
                showTtsButton: !isUser && latestAiIndex == index,
              ),
            );
          },
        );
      },
      loading: () => const _LoadingConversation(),
      error: (e, _) => _ErrorConversation(l: l, error: e.toString()),
    );
  }
}

/// A richer empty state for the conversation surface.
class _EmptyConversation extends StatelessWidget {
  final AppLocalizations l;
  final VoidCallback? onStartTap;
  final Future<void> Function(String text)? onSuggestionTap;

  const _EmptyConversation({
    required this.l,
    this.onStartTap,
    this.onSuggestionTap,
  });

  @override
  Widget build(BuildContext context) {
    final isLight = Theme.of(context).brightness == Brightness.light;
    final iconColor = isLight
        ? AppColors.lightAccentPrimary
        : AppColors.accentPrimary;
    final suggestions = [
      l.t('chat.suggestion_1'),
      l.t('chat.suggestion_2'),
      l.t('chat.suggestion_3'),
    ];
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 96,
              height: 96,
              decoration: BoxDecoration(
                color: iconColor.withValues(alpha: 0.12),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: iconColor.withValues(alpha: 0.2),
                    blurRadius: 32,
                    spreadRadius: -4,
                  ),
                ],
              ),
              child: Icon(
                Icons.chat_bubble_outline,
                size: 48,
                color: iconColor,
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            Text(
              l.t('chat.start_conversation'),
              style: Theme.of(
                context,
              ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w600),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              l.t('chat.start_hint'),
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: isLight
                    ? AppColors.lightTextSecondary
                    : AppColors.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.lg),
            if (onStartTap != null)
              FilledButton.icon(
                onPressed: onStartTap,
                icon: const Icon(Icons.chat_bubble_outline, size: 18),
                label: Text(l.t('chat.start_button')),
              ),
            if (onStartTap != null) const SizedBox(height: AppSpacing.lg),
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              alignment: WrapAlignment.center,
              children: suggestions.map((text) {
                return ActionChip(
                  label: Text(text),
                  onPressed: onSuggestionTap == null
                      ? onStartTap
                      : () => onSuggestionTap!(text),
                  side: BorderSide(
                    color: isLight
                        ? AppColors.lightGlassBorder
                        : AppColors.glassBorder,
                  ),
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }
}

/// Rich loading state for the conversation surface.
///
/// Replaces a bare [CircularProgressIndicator] with a branded skeleton so
/// the chat panel never feels empty while messages are being fetched.
class _LoadingConversation extends StatelessWidget {
  const _LoadingConversation();

  @override
  Widget build(BuildContext context) {
    final isLight = Theme.of(context).brightness == Brightness.light;
    final iconColor = isLight
        ? AppColors.lightAccentPrimary
        : AppColors.accentPrimary;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(
              width: 64,
              height: 64,
              child: CircularProgressIndicator(
                strokeWidth: 3,
                valueColor: AlwaysStoppedAnimation<Color>(iconColor),
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            Text(
              AppLocalizations.of(context).t('common.loading'),
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: isLight
                    ? AppColors.lightTextSecondary
                    : AppColors.textSecondary,
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

/// Rich error state when the message list fails to load.
class _ErrorConversation extends StatelessWidget {
  final AppLocalizations l;
  final String error;

  const _ErrorConversation({required this.l, required this.error});

  @override
  Widget build(BuildContext context) {
    final isLight = Theme.of(context).brightness == Brightness.light;
    final iconColor = isLight ? AppColors.lightError : AppColors.error;
    final detail = error.length > 160 ? '${error.substring(0, 160)}…' : error;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: iconColor.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.error_outline, size: 36, color: iconColor),
            ),
            const SizedBox(height: AppSpacing.lg),
            Text(
              l.t('common.error'),
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              l.tArg('chat.error', {'error': detail}),
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: isLight
                    ? AppColors.lightTextSecondary
                    : AppColors.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              l.t('common.retry_hint'),
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: isLight ? AppColors.lightTextMuted : AppColors.textMuted,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
