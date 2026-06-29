import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:just_audio/just_audio.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/util/responsive.dart';
import '../../../../shared/widgets/glass_widgets.dart';
import '../../../../shared/widgets/virtual_character.dart';
import '../../../../shared/providers.dart';
import '../../data/llm_service.dart';
import '../../data/stt_service.dart';
import '../../data/tts_service.dart';
import '../../data/recording_service.dart';
import '../../data/tts_playback_service.dart';
import '../../domain/chat_models.dart';
import '../../domain/tutor.dart';
import '../../domain/tutor_prompts.dart';

class ChatScreen extends ConsumerStatefulWidget {
  final String sessionId;
  const ChatScreen({super.key, required this.sessionId});

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final RecordingService _recordingService = RecordingService();
  final TtsPlaybackService _ttsPlaybackService = TtsPlaybackService();
  // Dedicated focus node for the message input so we can programmatically
  // focus it (after STT transcription, on desktop entry) and so the Esc
  // handler can verify the field has focus before intercepting keys.
  final FocusNode _messageFocusNode = FocusNode();

  bool _isRecording = false;
  bool _isLoading = false;
  String? _playingMessageId;
  CharacterState _characterState = CharacterState.idle;
  StreamSubscription? _playerStateSub;

  // Active tutor identity — drives the character panel + AppBar title so
  // the UI reflects who the user picked on the TutorSelectionScreen.
  String _tutorName = 'AI Tutor';
  String _tutorAvatar = '👩‍🏫';

  @override
  void initState() {
    super.initState();
    // NOTE: We intentionally do NOT add a setState listener to the text
    // controller here. Doing so would rebuild the entire ChatScreen (and
    // its child message list) on every keystroke. Instead, _ChatInputBar
    // wraps the send button in a ValueListenableBuilder so only the button
    // opacity toggles when text becomes empty/non-empty.
    _loadTutorIdentity();
    _loadTtsSpeed();
    // Auto-focus the input on wide (desktop/web) layouts where there's no
    // risk of popping the soft keyboard unexpectedly. On mobile we leave
    // focus alone so the user controls when the keyboard appears.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (Responsive.isWide(context)) {
        _messageFocusNode.requestFocus();
      }
    });
  }

  /// Load the user's preferred TTS playback speed (0.75 / 1.0 / 1.25 / 1.5)
  /// from settings and apply it to the playback service. We do this once
  /// on screen entry; if the user changes the setting mid-session they can
  /// re-enter the chat to pick up the new value (acceptable trade-off vs.
  /// adding a settings listener just for this).
  Future<void> _loadTtsSpeed() async {
    try {
      final raw = await ref.read(profileRepoProvider).getSetting('tts_speed');
      if (raw == null) return;
      final speed = double.tryParse(raw);
      if (speed == null || speed <= 0 || speed > 3) return;
      await _ttsPlaybackService.setSpeed(speed);
    } catch (_) {
      // Best-effort — never block the screen on settings read.
    }
  }

  Future<void> _loadTutorIdentity() async {
    try {
      final profileRepo = ref.read(profileRepoProvider);
      final tutorId = await profileRepo.getSetting('selected_tutor_id');
      if (tutorId != null) {
        final tutor = TutorRepository.getTutorById(tutorId);
        if (mounted) {
          setState(() {
            _tutorName = tutor.name;
            _tutorAvatar = tutor.avatar;
          });
        }
      }
    } catch (_) {
      // Keep the default tutor identity on any error.
    }
  }

  @override
  void dispose() {
    _playerStateSub?.cancel();
    _messageController.dispose();
    _scrollController.dispose();
    _messageFocusNode.dispose();
    _recordingService.dispose();
    _ttsPlaybackService.dispose();
    super.dispose();
  }

  /// Screen-level key handler. Esc cancels an in-progress recording so the
  /// user isn't forced to tap the mic button again (useful on web/desktop
  /// where a hardware keyboard is the primary input). Returns whether the
  /// event was consumed.
  KeyEventResult _handleKeyEvent(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    final key = event.logicalKey;
    if (key == LogicalKeyboardKey.escape && _isRecording) {
      _handleRecordToggle();
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    });
  }

  void _setCharacterState(CharacterState state) {
    if (!mounted) return;
    setState(() => _characterState = state);
  }

  @override
  Widget build(BuildContext context) {
    // Auto-scroll when messages change.
    ref.listen(
      _messagesProvider(widget.sessionId),
      (_, _) => _scrollToBottom(),
    );

    final isWide = Responsive.isWide(context);

    // Wrap the Scaffold in a Focus node so hardware-key events (Esc to
    // cancel recording) are caught at the screen level even when the text
    // field isn't focused. The Focus widget manages its own internal node
    // when none is passed, so there's nothing to dispose.
    return Focus(
      onKeyEvent: _handleKeyEvent,
      child: Scaffold(
        backgroundColor: AppColors.bgPrimary,
        appBar: AppBar(
          leading: IconButton(
            tooltip: 'Back to home',
            icon: const Icon(Icons.arrow_back_ios_new),
            onPressed: () => context.go('/'),
          ),
          title: Row(
            children: [
              Text(_tutorAvatar, style: const TextStyle(fontSize: 20)),
              const SizedBox(width: AppSpacing.sm),
              Flexible(
                child: Text(_tutorName, overflow: TextOverflow.ellipsis),
              ),
            ],
          ),
          actions: [
            IconButton(
              tooltip: 'Pick a tutor',
              icon: const Icon(Icons.swap_horiz),
              onPressed: () => context.push('/tutor-selection'),
            ),
            IconButton(
              tooltip: 'More options',
              icon: const Icon(Icons.more_vert),
              onPressed: () => _showSessionOptions(context),
            ),
          ],
        ),
        // resizeToAvoidBottomInset keeps the input bar visible when the
        // soft keyboard appears on mobile / web.
        resizeToAvoidBottomInset: true,
        body: SafeArea(
          top: false,
          // On wide screens (tablet/desktop/browser), put the character panel
          // beside the chat. On mobile, stack them vertically.
          child: isWide
              ? Row(
                  children: [
                    _CharacterPanel(
                      state: _characterState,
                      tutorName: _tutorName,
                      tutorAvatar: _tutorAvatar,
                      panelWidth: Responsive.sidePanelWidth(context),
                    ),
                    const VerticalDivider(
                      width: 1,
                      color: AppColors.glassBorder,
                    ),
                    Expanded(child: _chatColumn(context)),
                  ],
                )
              : Column(
                  children: [
                    _CharacterPanel(
                      state: _characterState,
                      tutorName: _tutorName,
                      tutorAvatar: _tutorAvatar,
                      panelHeight: Responsive.characterPanelHeight(context),
                      compact: true,
                    ),
                    Expanded(child: _chatColumn(context)),
                  ],
                ),
        ),
      ),
    );
  }

  Widget _chatColumn(BuildContext context) {
    return Column(
      children: [
        // Chat messages area — constrained on wide screens for readability.
        Expanded(
          child: Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: Responsive.contentMaxWidth(context),
              ),
              child: _ChatMessageList(
                sessionId: widget.sessionId,
                scrollController: _scrollController,
                isAiThinking: _isLoading,
                playingMessageId: _playingMessageId,
                onPlayTts: _playTts,
              ),
            ),
          ),
        ),

        // Input area
        Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: Responsive.contentMaxWidth(context),
            ),
            child: _ChatInputBar(
              controller: _messageController,
              focusNode: _messageFocusNode,
              isRecording: _isRecording,
              isLoading: _isLoading,
              onSend: _handleSend,
              onRecordToggle: _handleRecordToggle,
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _handleSend() async {
    final text = _messageController.text.trim();
    if (text.isEmpty || _isLoading) return;

    setState(() => _isLoading = true);
    _setCharacterState(CharacterState.thinking);
    _messageController.clear();

    final repo = ref.read(chatRepoProvider);
    final message = ChatMessage(
      sessionId: widget.sessionId,
      role: MessageRole.user,
      content: text,
    );
    await repo.saveMessage(message);
    // Refresh the message list provider so the new user message appears.
    ref.invalidate(_messagesProvider(widget.sessionId));

    try {
      final profileRepo = ref.read(profileRepoProvider);
      final llmProfile = await profileRepo.getActiveLlmProfile();

      if (llmProfile == null) {
        if (mounted) {
          _showConfigNeeded(
            'AI Dialogue is not configured',
            'Add an LLM provider to start chatting with your AI tutor.',
          );
        }
        return;
      }

      // Fetch history AFTER saving the user message — the LLM needs the full
      // transcript. We do NOT pass `userMessage` separately, because that
      // would duplicate the user's turn.
      final history = await repo.getMessages(widget.sessionId);

      // Resolve the system prompt: scenario > tutor > default.
      final session = await repo.getSession(widget.sessionId);
      Scenario? scenario;
      if (session?.scenarioId != null) {
        scenario = await repo.getScenario(session!.scenarioId!);
      }

      Tutor? tutor;
      final tutorId = await profileRepo.getSetting('selected_tutor_id');
      if (tutorId != null) {
        try {
          tutor = TutorRepository.getTutorById(tutorId);
        } catch (_) {
          // Unknown tutor id — ignore.
        }
      }

      // Detect review / practice sessions (topics created by ReviewScreen).
      final topic = session?.topic;
      final isReviewSession =
          topic != null &&
          (topic.startsWith('AI Review Session') ||
              topic.startsWith('Practice:'));
      List<Correction> dueCorrections = const [];
      if (isReviewSession) {
        dueCorrections = await repo.getDueCorrections(limit: 10);
      }

      final userLevel = await profileRepo.getUserLevel();
      // correction_strength is saved by the settings screen (gentle/moderate/strict).
      // Defaults to 'moderate' for first-run users.
      final correctionStrength =
          await profileRepo.getSetting('correction_strength') ?? 'moderate';
      final systemPrompt = TutorPromptBuilder.build(
        tutor: tutor,
        scenario: scenario,
        userLevel: userLevel,
        isReviewSession: isReviewSession,
        dueCorrections: dueCorrections,
        sessionTopic: topic,
        correctionStrength: correctionStrength,
      );

      final llmService = LlmService(llmProfile);
      final response = await llmService.sendMessage(
        history: history,
        systemPrompt: systemPrompt,
      );

      // Save AI response
      final aiResponse = ChatMessage(
        sessionId: widget.sessionId,
        role: MessageRole.assistant,
        content: response.content,
      );
      await repo.saveMessage(aiResponse);

      // Save corrections tied to the AI message. Use the dedup path so the
      // same mistake flagged across sessions bumps occurrence_count instead
      // of producing duplicate review rows.
      for (final correction in response.corrections) {
        await repo.saveCorrectionDedup(
          correction.copyWith(
            messageId: aiResponse.id,
            sessionId: widget.sessionId,
          ),
        );
      }

      // Refresh UI
      ref.invalidate(_messagesProvider(widget.sessionId));
      // Invalidate the per-session corrections map so the inline
      // correction chips in the new AI bubble render without a manual reload.
      ref.invalidate(_correctionsByMessageProvider(widget.sessionId));

      // Auto-play TTS for the AI reply + animate speaking state.
      await _autoplayTts(aiResponse.id, response.content);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: ${_safeError(e)}')));
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
        if (_characterState == CharacterState.thinking) {
          _setCharacterState(CharacterState.idle);
        }
      }
    }
  }

  Future<void> _handleRecordToggle() async {
    if (_isLoading) return;

    if (_isRecording) {
      // Stop recording and transcribe
      setState(() => _isRecording = false);
      _setCharacterState(CharacterState.thinking);

      try {
        final audioData = await _recordingService.stopRecording();
        if (audioData == null || audioData.isEmpty) {
          if (mounted) {
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(const SnackBar(content: Text('No audio recorded')));
            _setCharacterState(CharacterState.idle);
          }
          return;
        }

        final profileRepo = ref.read(profileRepoProvider);
        final sttProfile = await profileRepo.getActiveSttProfile();

        if (sttProfile == null) {
          if (mounted) {
            _showConfigNeeded(
              'Speech Recognition is not configured',
              'Add an STT provider to use the microphone for voice input.',
            );
            _setCharacterState(CharacterState.idle);
          }
          return;
        }

        final sttService = SttService(sttProfile);
        final transcribedText = await sttService.transcribe(audioData);

        if (transcribedText.isNotEmpty) {
          _messageController.text = transcribedText;
          // After voice input, return keyboard focus to the text field so
          // the user can edit the transcript or hit Enter to send.
          if (mounted) _messageFocusNode.requestFocus();
          await _handleSend();
        } else if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Could not transcribe audio')),
          );
          _setCharacterState(CharacterState.idle);
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Recording error: ${_safeError(e)}')),
          );
          _setCharacterState(CharacterState.idle);
        }
      }
    } else {
      try {
        await _recordingService.startRecording();
        setState(() => _isRecording = true);
        _setCharacterState(CharacterState.listening);
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Cannot start recording: ${_safeError(e)}')),
          );
        }
      }
    }
  }

  /// Auto-play TTS for an AI message and drive the speaking state.
  Future<void> _autoplayTts(String messageId, String text) async {
    try {
      final profileRepo = ref.read(profileRepoProvider);
      final ttsProfile = await profileRepo.getActiveTtsProfile();
      if (ttsProfile == null) {
        // TTS not configured — silently skip rather than nag the user every
        // turn. They can still read the text.
        return;
      }

      _setCharacterState(CharacterState.speaking);
      if (mounted) setState(() => _playingMessageId = messageId);

      final ttsService = TtsService(ttsProfile);

      _attachPlayerStateListener(messageId);

      await _ttsPlaybackService.playCached(
        text,
        () => ttsService.synthesize(text),
      );
    } catch (e) {
      // Auto-play failures should not interrupt the conversation flow.
      debugPrint('Auto TTS failed: $e');
      if (mounted) {
        setState(() => _playingMessageId = null);
        if (_characterState == CharacterState.speaking) {
          _setCharacterState(CharacterState.idle);
        }
      }
    }
  }

  Future<void> _playTts(String messageId, String text) async {
    if (_playingMessageId == messageId) {
      // Stop playing
      await _ttsPlaybackService.stop();
      if (mounted) setState(() => _playingMessageId = null);
      if (_characterState == CharacterState.speaking) {
        _setCharacterState(CharacterState.idle);
      }
      return;
    }

    try {
      setState(() => _playingMessageId = messageId);
      _setCharacterState(CharacterState.speaking);

      final profileRepo = ref.read(profileRepoProvider);
      final ttsProfile = await profileRepo.getActiveTtsProfile();

      if (ttsProfile == null) {
        if (mounted) {
          _showConfigNeeded(
            'Text-to-Speech is not configured',
            'Add a TTS provider to hear the AI tutor speak aloud.',
          );
        }
        setState(() => _playingMessageId = null);
        _setCharacterState(CharacterState.idle);
        return;
      }

      final ttsService = TtsService(ttsProfile);

      _attachPlayerStateListener(messageId);
      await _ttsPlaybackService.playCached(
        text,
        () => ttsService.synthesize(text),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('TTS error: ${_safeError(e)}')));
        setState(() => _playingMessageId = null);
        _setCharacterState(CharacterState.idle);
      }
    }
  }

  void _attachPlayerStateListener(String messageId) {
    // Cancel any prior subscription so we never stack listeners (memory leak
    // fix — previously every play call added a new permanent listener).
    _playerStateSub?.cancel();
    _playerStateSub = _ttsPlaybackService.player.playerStateStream.listen((
      state,
    ) {
      if (state.processingState == ProcessingState.completed) {
        if (!mounted) return;
        setState(() => _playingMessageId = null);
        if (_characterState == CharacterState.speaking) {
          _setCharacterState(CharacterState.idle);
        }
      }
    });
  }

  /// Shows a snackbar with a "Configure" action that navigates to the
  /// service configuration screen. Used when an LLM/STT/TTS profile is
  /// missing during chat — gives the user a one-tap shortcut to fix it
  /// instead of leaving them stranded with a generic error.
  void _showConfigNeeded(String title, String body) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 2),
            Text(body, style: const TextStyle(fontSize: 13)),
          ],
        ),
        duration: const Duration(seconds: 6),
        action: SnackBarAction(
          label: 'Configure',
          onPressed: () => context.push('/service-config'),
        ),
      ),
    );
  }

  void _showSessionOptions(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.bgTertiary,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.xl)),
      ),
      builder: (context) => Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(
                Icons.archive,
                color: AppColors.textSecondary,
              ),
              title: const Text('Archive Session'),
              onTap: () async {
                final repo = ref.read(chatRepoProvider);
                await repo.archiveSession(widget.sessionId);
                if (context.mounted) {
                  Navigator.pop(context);
                  context.go('/');
                }
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete, color: AppColors.error),
              title: const Text(
                'Delete Session',
                style: TextStyle(color: AppColors.error),
              ),
              onTap: () async {
                // Confirm before destructive action — deletes the session
                // and all related messages + corrections (transactional).
                Navigator.pop(context); // close the bottom sheet first
                final confirmed = await showDialog<bool>(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: const Text('Delete this conversation?'),
                    content: const Text(
                      'All messages and corrections from this session will be permanently removed.',
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(ctx, false),
                        child: const Text('Cancel'),
                      ),
                      TextButton(
                        style: TextButton.styleFrom(foregroundColor: AppColors.error),
                        onPressed: () => Navigator.pop(ctx, true),
                        child: const Text('Delete'),
                      ),
                    ],
                  ),
                );
                if (confirmed != true || !mounted) return;
                try {
                  await ref.read(chatRepoProvider).deleteSession(widget.sessionId);
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Conversation deleted')),
                    );
                    context.go('/');
                  }
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Delete failed: ${_safeError(e)}')),
                    );
                  }
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  /// Strip verbose API response bodies from exception messages before
  /// surfacing them in a SnackBar — error.text may contain provider hints
  /// or partial payload we don't want to display.
  String _safeError(Object e) {
    final raw = e.toString();
    if (raw.length > 160) return '${raw.substring(0, 160)}...';
    return raw;
  }
}

class _ChatMessageList extends ConsumerWidget {
  final String sessionId;
  final ScrollController scrollController;
  final bool isAiThinking;
  final String? playingMessageId;
  final Future<void> Function(String messageId, String text) onPlayTts;

  const _ChatMessageList({
    required this.sessionId,
    required this.scrollController,
    required this.onPlayTts,
    this.isAiThinking = false,
    this.playingMessageId,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final messagesAsync = ref.watch(_messagesProvider(sessionId));
    // Watch the corrections-by-message provider in parallel so that when
    // _messagesProvider is invalidated (after the user sends a message +
    // after corrections are saved), the corrections map refreshes too.
    // Previously this was a FutureBuilder that re-ran getAllCorrections()
    // on every chat-screen rebuild (every keystroke via the now-removed
    // setState listener) — P0-7 fix.
    final correctionsAsync = ref.watch(_correctionsByMessageProvider(sessionId));

    return messagesAsync.when(
      data: (messages) {
        if (messages.isEmpty && !isAiThinking) {
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
                  'Start a conversation!',
                  style: Theme.of(
                    context,
                  ).textTheme.bodyLarge?.copyWith(color: AppColors.textMuted),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  'Type a message or tap the mic button',
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(color: AppColors.textMuted),
                ),
              ],
            ),
          );
        }

        // Use the cached corrections map; fall back to empty while the
        // first load is in flight so messages can render immediately.
        final correctionsByMsg = correctionsAsync.valueOrNull ?? const {};

        return ListView.builder(
          controller: scrollController,
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
          itemCount: messages.length + (isAiThinking ? 1 : 0),
          itemBuilder: (context, index) {
            if (index == messages.length) {
              // Typing indicator row
              return const _TypingBubble();
            }
            final msg = messages[index];
            final isUser = msg.role == MessageRole.user;
            return _ChatBubble(
              key: ValueKey(msg.id),
              message: msg.content,
              isUser: isUser,
              isPlaying: playingMessageId == msg.id,
              corrections: correctionsByMsg[msg.id] ?? const [],
              onPlayTts: isUser
                  ? null
                  : () => onPlayTts(msg.id, msg.content),
            );
          },
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Error: $e')),
    );
  }
}

final _messagesProvider = FutureProvider.family<List<ChatMessage>, String>((
  ref,
  sessionId,
) async {
  final repo = ref.watch(chatRepoProvider);
  return repo.getMessages(sessionId);
});

/// Per-session corrections grouped by AI message id, for inline display.
///
/// Cached by Riverpod and invalidated together with [_messagesProvider]
/// (the chat screen calls `ref.invalidate(_messagesProvider(sessionId))`
/// followed by `ref.invalidate(_correctionsByMessageProvider(sessionId))`
/// whenever a new AI message + its corrections are saved). This replaces
/// the previous FutureBuilder that re-ran `getAllCorrections()` on every
/// chat-screen rebuild, including on every keystroke.
final _correctionsByMessageProvider =
    FutureProvider.family<Map<String, List<Correction>>, String>((
  ref,
  sessionId,
) async {
  final repo = ref.watch(chatRepoProvider);
  // Filter by session_id so we don't pull the entire corrections table
  // for every other session the user has. The query is the same shape as
  // getAllCorrections() but scoped.
  final all = await repo.getCorrectionsForSession(sessionId);
  final map = <String, List<Correction>>{};
  for (final c in all) {
    final key = c.messageId;
    if (key == null) continue;
    map.putIfAbsent(key, () => []).add(c);
  }
  return map;
});

/// Lightweight typing indicator shown while the LLM is responding.
/// Dots bounce in sequence to make the "thinking" state feel alive.
class _TypingBubble extends StatefulWidget {
  const _TypingBubble();

  @override
  State<_TypingBubble> createState() => _TypingBubbleState();
}

class _TypingBubbleState extends State<_TypingBubble>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: AppSpacing.sm),
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.md,
        ),
        decoration: BoxDecoration(
          color: AppColors.bubbleAi,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(AppRadius.lg),
            topRight: Radius.circular(AppRadius.lg),
            bottomLeft: Radius.circular(AppRadius.xs),
            bottomRight: Radius.circular(AppRadius.lg),
          ),
          border: Border.all(
            color: AppColors.accentPrimary.withValues(alpha: 0.2),
          ),
        ),
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, _) {
            return Row(
              mainAxisSize: MainAxisSize.min,
              children: List.generate(3, (i) {
                // Stagger each dot's bounce — dot 0 starts at 0s, dot 1 at
                // 0.2s, dot 2 at 0.4s, looping every 1.2s.
                final t = (_controller.value - i * 0.15) % 1.0;
                // A bell-ish curve: peak in the middle of the cycle.
                final scale = 0.6 + 0.6 * (1 - (2 * t - 1).abs());
                return Transform.scale(
                  scale: scale,
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 2),
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: AppColors.accentPrimary.withValues(alpha: 0.6),
                      shape: BoxShape.circle,
                    ),
                  ),
                );
              }),
            );
          },
        ),
      ),
    );
  }
}

class _ChatBubble extends StatelessWidget {
  final String message;
  final bool isUser;
  final bool isPlaying;
  final List<Correction> corrections;
  final VoidCallback? onPlayTts;

  const _ChatBubble({
    super.key,
    required this.message,
    required this.isUser,
    this.isPlaying = false,
    this.corrections = const [],
    this.onPlayTts,
  });

  @override
  Widget build(BuildContext context) {
    final bubbleColor = isUser ? AppColors.bubbleUser : AppColors.bubbleAi;
    final accent = isUser ? AppColors.accentSecondary : AppColors.accentPrimary;

    // LayoutBuilder gives us the actual chat-column width (which on desktop
    // is constrained to contentMaxWidth), so bubbles stay readable instead
    // of stretching to fill the full window.
    return LayoutBuilder(
      builder: (context, constraints) {
        final maxWidth =
            constraints.maxWidth * Responsive.bubbleMaxWidthFraction(context);
        return Align(
          alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
          child: Container(
            margin: const EdgeInsets.only(bottom: AppSpacing.sm),
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.sm,
            ),
            constraints: BoxConstraints(maxWidth: maxWidth),
            decoration: BoxDecoration(
              color: bubbleColor,
              borderRadius: BorderRadius.only(
                topLeft: const Radius.circular(AppRadius.lg),
                topRight: const Radius.circular(AppRadius.lg),
                bottomLeft: Radius.circular(
                  isUser ? AppRadius.lg : AppRadius.xs,
                ),
                bottomRight: Radius.circular(
                  isUser ? AppRadius.xs : AppRadius.lg,
                ),
              ),
              border: Border.all(color: accent.withValues(alpha: 0.2)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(message, style: Theme.of(context).textTheme.bodyLarge),
                // Inline corrections for AI messages.
                if (!isUser && corrections.isNotEmpty) ...[
                  const SizedBox(height: AppSpacing.sm),
                  ...corrections.map((c) => _CorrectionInline(correction: c)),
                ],
                if (!isUser && onPlayTts != null) ...[
                  const SizedBox(height: AppSpacing.xs),
                  // Wrap in a 44x44 hit box so the small "Listen" affordance
                  // still meets touch-target minimums. Semantics announces
                  // the play/stop state for screen readers.
                  Semantics(
                    button: true,
                    label: isPlaying ? 'Stop playback' : 'Play this message',
                    hint: isPlaying
                        ? 'Double tap to stop audio'
                        : 'Double tap to hear the AI tutor say this',
                    child: InkWell(
                      onTap: onPlayTts,
                      borderRadius: BorderRadius.circular(AppRadius.sm),
                      child: Container(
                        constraints: const BoxConstraints(
                          minWidth: 44,
                          minHeight: 36,
                        ),
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.xs,
                          vertical: 4,
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              isPlaying ? Icons.stop_circle : Icons.play_circle,
                              color: AppColors.accentSecondary,
                              size: 20,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              isPlaying ? 'Stop' : 'Listen',
                              style: TextStyle(
                                color: AppColors.accentSecondary,
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}

/// Inline correction card rendered inside an AI chat bubble.
class _CorrectionInline extends StatelessWidget {
  final Correction correction;
  const _CorrectionInline({required this.correction});

  Color _typeColor(CorrectionType type) {
    switch (type) {
      case CorrectionType.grammar:
        return AppColors.error;
      case CorrectionType.vocabulary:
        return AppColors.warning;
      case CorrectionType.pronunciation:
        return AppColors.accentSecondary;
    }
  }

  String _typeLabel(CorrectionType type) {
    switch (type) {
      case CorrectionType.grammar:
        return 'Grammar';
      case CorrectionType.vocabulary:
        return 'Vocabulary';
      case CorrectionType.pronunciation:
        return 'Pronunciation';
    }
  }

  @override
  Widget build(BuildContext context) {
    final typeColor = _typeColor(correction.type);
    return Container(
      margin: const EdgeInsets.only(top: AppSpacing.xs),
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: AppColors.bubbleCorrection,
        borderRadius: BorderRadius.circular(AppRadius.sm),
        border: Border.all(
          color: AppColors.success.withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.xs,
                  vertical: 1,
                ),
                decoration: BoxDecoration(
                  color: typeColor.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(AppRadius.xs),
                ),
                child: Text(
                  _typeLabel(correction.type),
                  style: TextStyle(
                    color: typeColor,
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xxs),
          Row(
            children: [
              const Icon(Icons.close, color: AppColors.error, size: 14),
              const SizedBox(width: AppSpacing.xs),
              Expanded(
                child: Text(
                  correction.original,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppColors.error,
                    decoration: TextDecoration.lineThrough,
                  ),
                ),
              ),
            ],
          ),
          Row(
            children: [
              const Icon(Icons.check, color: AppColors.success, size: 14),
              const SizedBox(width: AppSpacing.xs),
              Expanded(
                child: Text(
                  correction.corrected,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppColors.success,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
          if (correction.explanation != null &&
              correction.explanation!.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.xxs),
            Text(
              correction.explanation!,
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
            ),
          ],
        ],
      ),
    );
  }
}

class _ChatInputBar extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final bool isRecording;
  final bool isLoading;
  final VoidCallback onSend;
  final VoidCallback onRecordToggle;

  const _ChatInputBar({
    required this.controller,
    required this.focusNode,
    required this.isRecording,
    required this.isLoading,
    required this.onSend,
    required this.onRecordToggle,
  });

  @override
  Widget build(BuildContext context) {
    // canSend is now derived inside the ValueListenableBuilder below so
    // that only the Send button + its Semantics wrapper rebuild on each
    // keystroke instead of the whole _ChatInputBar.
    // Bottom padding: prefer the MediaQuery viewInsets (soft keyboard /
    // browser IME) when present, otherwise fall back to safe-area padding.
    final viewInsets = MediaQuery.of(context).viewInsets.bottom;
    final safeBottom = MediaQuery.of(context).padding.bottom;
    final bottomPad = viewInsets > 0 ? viewInsets : safeBottom + AppSpacing.md;
    return Container(
      padding: EdgeInsets.only(
        left: AppSpacing.md,
        right: AppSpacing.md,
        top: AppSpacing.sm,
        bottom: bottomPad,
      ),
      decoration: BoxDecoration(
        color: AppColors.bgSecondary,
        border: Border(top: BorderSide(color: AppColors.glassBorder)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          // Record button — pulsing glow when recording, using GlowButton
          // (which has its own AnimationController). 48x48 meets the 44x44
          // minimum touch target. Semantics exposes the state to screen
          // readers; the Tooltip shows the same on hover for mouse users.
          Semantics(
            button: true,
            enabled: !isLoading,
            label: isRecording ? 'Stop recording' : 'Start voice recording',
            hint: isRecording
                ? 'Double tap to stop and transcribe'
                : 'Double tap to record a voice message',
            child: Tooltip(
              message: isRecording ? 'Stop recording' : 'Tap to record',
              child: _RecordButton(
                isRecording: isRecording,
                onTap: isLoading ? null : onRecordToggle,
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          // Text input — grows up to 5 lines on desktop/web so long
          // messages stay readable without scrolling the field itself.
          Expanded(
            child: Container(
              constraints: const BoxConstraints(maxHeight: 160),
              decoration: BoxDecoration(
                color: AppColors.bgTertiary,
                borderRadius: BorderRadius.circular(AppRadius.xl),
                border: Border.all(
                  color: isRecording
                      ? AppColors.error.withValues(alpha: 0.6)
                      : AppColors.glassBorder,
                ),
              ),
              child: TextField(
                controller: controller,
                focusNode: focusNode,
                enabled: !isLoading,
                style: const TextStyle(color: AppColors.textPrimary),
                textInputAction: TextInputAction.send,
                maxLines: null,
                minLines: 1,
                decoration: InputDecoration(
                  hintText: 'Type a message...',
                  hintStyle: TextStyle(color: AppColors.textMuted),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.md,
                    vertical: AppSpacing.sm + 4,
                  ),
                ),
                onSubmitted: (_) {
                  // Derive canSend directly from the controller so we don't
                  // rely on the parent rebuilding before onSubmitted fires.
                  final canSubmit =
                      controller.text.trim().isNotEmpty && !isLoading;
                  if (canSubmit) onSend();
                },
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          // Send button — wraps in a ValueListenableBuilder on the
          // TextEditingController (which is itself a ValueNotifier) so only
          // this button rebuilds when text changes. The whole
          // _ChatInputBar no longer needs a setState on each keystroke.
          ValueListenableBuilder<TextEditingValue>(
            valueListenable: controller,
            builder: (context, value, _) {
              final canSend = value.text.trim().isNotEmpty && !isLoading;
              return Semantics(
                button: true,
                enabled: canSend,
                label: 'Send message',
                hint: canSend
                    ? 'Double tap to send'
                    : 'Type a message first to send',
                child: Opacity(
                  opacity: canSend ? 1.0 : 0.4,
                  child: Container(
                    width: 48,
                    height: 48,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: AppColors.gradientPrimary,
                    ),
                    child: IconButton(
                      icon: const Icon(Icons.send, color: Colors.white),
                      onPressed: canSend ? onSend : null,
                    ),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

/// Record (mic) button with a pulsing glow while recording.
///
/// This is the runtime use of the previously dead-code GlowButton visual
/// pattern (P0-8 from the UI review): while recording, the button's outer
/// glow expands and contracts to give the user clear feedback that audio
/// capture is in progress. Idle state has a static, calmer glow.
class _RecordButton extends StatefulWidget {
  final bool isRecording;
  final VoidCallback? onTap;

  const _RecordButton({
    required this.isRecording,
    required this.onTap,
  });

  @override
  State<_RecordButton> createState() => _RecordButtonState();
}

class _RecordButtonState extends State<_RecordButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _pulse;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    );
    _pulse = Tween<double>(begin: 0.25, end: 0.55).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
    if (widget.isRecording) _controller.repeat(reverse: true);
  }

  @override
  void didUpdateWidget(covariant _RecordButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isRecording == oldWidget.isRecording) return;
    if (widget.isRecording) {
      _controller.repeat(reverse: true);
    } else {
      _controller.stop();
      // Jump back to the resting glow value so the button doesn't freeze
      // mid-pulse when recording stops.
      _controller.value = 0.0;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color =
        widget.isRecording ? AppColors.error : AppColors.accentSecondary;
    final baseGlow = widget.isRecording ? 0.4 : 0.25;

    return GestureDetector(
      onTap: widget.onTap,
      child: SizedBox(
        width: 48,
        height: 48,
        child: AnimatedBuilder(
          animation: _pulse,
          builder: (context, _) {
            final glowAlpha =
                widget.isRecording ? _pulse.value : baseGlow;
            return Stack(
              alignment: Alignment.center,
              children: [
                // Expanding ripple ring while recording — gives a sonar-like
                // "I am listening" feedback.
                if (widget.isRecording)
                  Positioned.fill(
                    child: CustomPaint(
                      painter: _RipplePainter(
                        progress: _controller.value,
                        color: color,
                      ),
                    ),
                  ),
                // Core button + glow.
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: color,
                    boxShadow: [
                      BoxShadow(
                        color: color.withValues(alpha: glowAlpha),
                        blurRadius: widget.isRecording ? 24 : 12,
                        spreadRadius: widget.isRecording ? 4 : 0,
                      ),
                    ],
                  ),
                  child: Icon(
                    widget.isRecording ? Icons.stop : Icons.mic,
                    color: Colors.white,
                    size: 22,
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

/// Draws one expanding ring (sonar pulse) for the recording state.
class _RipplePainter extends CustomPainter {
  final double progress; // 0.0 → 1.0
  final Color color;

  _RipplePainter({required this.progress, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final maxRadius = size.width / 2;
    // Ring expands outward and fades as it grows.
    final radius = maxRadius * (0.5 + progress * 0.9);
    final alpha = (1.0 - progress) * 0.5;
    final paint = Paint()
      ..color = color.withValues(alpha: alpha)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;
    canvas.drawCircle(center, radius, paint);
  }

  @override
  bool shouldRepaint(covariant _RipplePainter oldDelegate) =>
      oldDelegate.progress != progress || oldDelegate.color != color;
}

/// Adaptive wrapper around [VirtualCharacter].
///
/// On wide layouts it occupies a fixed-width column beside the chat and
/// stretches vertically. On compact layouts it sits in a fixed-height strip
/// above the chat with the avatar centered and labels hidden to save space.
class _CharacterPanel extends StatelessWidget {
  final CharacterState state;
  final String tutorName;
  final String tutorAvatar;

  /// Wide-layout only: forces a fixed column width.
  final double? panelWidth;

  /// Compact-layout only: forces a fixed strip height.
  final double? panelHeight;

  /// Compact mode — smaller avatar, no label, lighter container.
  final bool compact;

  const _CharacterPanel({
    required this.state,
    required this.tutorName,
    required this.tutorAvatar,
    this.panelWidth,
    this.panelHeight,
    this.compact = false,
  });

  /// Human-readable label for the current character state, used for the
  /// screen-reader live region so blind users can follow the voice flow
  /// (listening → thinking → speaking) without seeing the avatar.
  String _stateLabel(CharacterState s) {
    switch (s) {
      case CharacterState.idle:
        return '$tutorName is ready';
      case CharacterState.listening:
        return 'Listening to your voice';
      case CharacterState.thinking:
        return 'Thinking';
      case CharacterState.speaking:
        return 'Speaking';
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = Responsive.characterSize(context) * (compact ? 0.8 : 1.0);

    final child = VirtualCharacter(
      tutorName: tutorName,
      tutorAvatar: tutorAvatar,
      state: state,
      size: size,
      showLabel: !compact,
    );

    // Live region: screen readers announce state changes (e.g. "Thinking",
    // "Speaking") without the user needing to focus the avatar.
    final labelled = Semantics(
      liveRegion: true,
      label: _stateLabel(state),
      child: child,
    );

    if (compact) {
      // Stacked strip above chat on mobile.
      return Container(
        height: panelHeight,
        margin: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm,
        ),
        child: GlassCard(
          glowColor: AppColors.accentPrimary,
          padding: EdgeInsets.zero,
          child: Center(child: labelled),
        ),
      );
    }

    // Side panel beside chat on wide layouts.
    return Container(
      width: panelWidth,
      margin: const EdgeInsets.all(AppSpacing.md),
      child: GlassCard(
        glowColor: AppColors.accentPrimary,
        padding: EdgeInsets.zero,
        child: Center(child: labelled),
      ),
    );
  }
}
