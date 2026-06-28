import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:just_audio/just_audio.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/constants/app_constants.dart';
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

  bool _isRecording = false;
  bool _isLoading = false;
  String? _playingMessageId;
  CharacterState _characterState = CharacterState.idle;
  StreamSubscription? _playerStateSub;

  @override
  void initState() {
    super.initState();
    _messageController.addListener(() {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _playerStateSub?.cancel();
    _messageController.dispose();
    _scrollController.dispose();
    _recordingService.dispose();
    _ttsPlaybackService.dispose();
    super.dispose();
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
    ref.listen(_messagesProvider(widget.sessionId), (_, _) => _scrollToBottom());

    return Scaffold(
      backgroundColor: AppColors.bgPrimary,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new),
          onPressed: () => context.go('/'),
        ),
        title: const Text('Practice'),
        actions: [
          IconButton(
            icon: const Icon(Icons.more_vert),
            onPressed: () => _showSessionOptions(context),
          ),
        ],
      ),
      body: Column(
        children: [
          // AI Character area
          Container(
            height: 220,
            margin: const EdgeInsets.all(AppSpacing.md),
            child: GlassCard(
              glowColor: AppColors.accentPrimary,
              child: VirtualCharacter(
                tutorName: 'AI Tutor',
                tutorAvatar: '👩‍🏫',
                state: _characterState,
              ),
            ),
          ),

          // Chat messages area
          Expanded(
            child: _ChatMessageList(
              sessionId: widget.sessionId,
              scrollController: _scrollController,
              isAiThinking: _isLoading,
              playingMessageId: _playingMessageId,
              onPlayTts: _playTts,
            ),
          ),

          // Input area
          _ChatInputBar(
            controller: _messageController,
            isRecording: _isRecording,
            isLoading: _isLoading,
            onSend: _handleSend,
            onRecordToggle: _handleRecordToggle,
          ),
        ],
      ),
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
        throw Exception(
            'No LLM profile configured. Please set up your AI service first.');
      }

      // Fetch history AFTER saving the user message — the LLM needs the full
      // transcript. We do NOT pass `userMessage` separately, because that
      // would duplicate the user's turn.
      final history = await repo.getMessages(widget.sessionId);

      // Resolve the system prompt: scenario > tutor > default.
      final session = await repo.getSession(widget.sessionId);
      String systemPrompt =
          'You are a friendly English tutor. Have a natural conversation with the student. Correct their errors naturally.';

      if (session?.scenarioId != null) {
        final scenario = await repo.getScenario(session!.scenarioId!);
        if (scenario != null) {
          systemPrompt = scenario.systemPrompt;
        }
      }

      // Append the user-selected tutor's prompt, if any.
      final tutorId = await profileRepo.getSetting('selected_tutor_id');
      if (tutorId != null) {
        try {
          final tutor = TutorRepository.getTutorById(tutorId);
          systemPrompt = '${tutor.systemPrompt}\n\n$systemPrompt';
        } catch (_) {
          // Unknown tutor id — ignore.
        }
      }

      // Inject review context if the session topic marks it as a review
      // session. ReviewScreen creates sessions with topics like
      // "AI Review Session" or "Practice: <orig> → <corrected>".
      if (session?.topic != null &&
          (session!.topic!.startsWith('AI Review Session') ||
              session.topic!.startsWith('Practice:'))) {
        final due = await repo.getDueCorrections(limit: 10);
        if (due.isNotEmpty) {
          final buffer = StringBuffer();
          buffer.writeln(
              'The student is here to review previous mistakes. Drive the conversation so they get to practice these specific corrections. Do NOT just list them — weave them naturally.');
          buffer.writeln('Corrections to practice:');
          for (final c in due) {
            buffer.writeln(
                '- They said: "${c.original}". Correct form: "${c.corrected}" (${c.type.name}). ${c.explanation ?? ''}');
          }
          systemPrompt = '$systemPrompt\n\n$buffer';
        }
      }

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

      // Save corrections tied to the AI message
      for (final correction in response.corrections) {
        await repo.saveCorrection(correction.copyWith(
          messageId: aiResponse.id,
          sessionId: widget.sessionId,
        ));
      }

      // Refresh UI
      ref.invalidate(_messagesProvider(widget.sessionId));

      // Auto-play TTS for the AI reply + animate speaking state.
      await _autoplayTts(aiResponse.id, response.content);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: ${_safeError(e)}')),
        );
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
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('No audio recorded')),
            );
            _setCharacterState(CharacterState.idle);
          }
          return;
        }

        final profileRepo = ref.read(profileRepoProvider);
        final sttProfile = await profileRepo.getActiveSttProfile();

        if (sttProfile == null) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                  content: Text(
                      'Please configure a Speech Recognition service first')),
          );
            _setCharacterState(CharacterState.idle);
          }
          return;
        }

        final sttService = SttService(sttProfile);
        final transcribedText = await sttService.transcribe(audioData);

        if (transcribedText.isNotEmpty) {
          _messageController.text = transcribedText;
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

      await _ttsPlaybackService.playCached(text, () => ttsService.synthesize(text));
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
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content: Text('Please configure a Text-to-Speech service first')),
          );
        }
        setState(() => _playingMessageId = null);
        _setCharacterState(CharacterState.idle);
        return;
      }

      final ttsService = TtsService(ttsProfile);

      _attachPlayerStateListener(messageId);
      await _ttsPlaybackService.playCached(text, () => ttsService.synthesize(text));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('TTS error: ${_safeError(e)}')),
        );
        setState(() => _playingMessageId = null);
        _setCharacterState(CharacterState.idle);
      }
    }
  }

  void _attachPlayerStateListener(String messageId) {
    // Cancel any prior subscription so we never stack listeners (memory leak
    // fix — previously every play call added a new permanent listener).
    _playerStateSub?.cancel();
    _playerStateSub = _ttsPlaybackService.player.playerStateStream.listen((state) {
      if (state.processingState == ProcessingState.completed) {
        if (!mounted) return;
        setState(() => _playingMessageId = null);
        if (_characterState == CharacterState.speaking) {
          _setCharacterState(CharacterState.idle);
        }
      }
    });
  }

  void _showSessionOptions(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.bgTertiary,
      shape: const RoundedRectangleBorder(
        borderRadius:
            BorderRadius.vertical(top: Radius.circular(AppRadius.xl)),
      ),
      builder: (context) => Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading:
                  const Icon(Icons.archive, color: AppColors.textSecondary),
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
              title: const Text('Delete Session',
                  style: TextStyle(color: AppColors.error)),
              onTap: () => Navigator.pop(context),
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

    return messagesAsync.when(
      data: (messages) {
        if (messages.isEmpty && !isAiThinking) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.chat_bubble_outline,
                    size: 48,
                    color: AppColors.textMuted.withValues(alpha: 0.3)),
                const SizedBox(height: AppSpacing.md),
                Text(
                  'Start a conversation!',
                  style: Theme.of(context)
                      .textTheme
                      .bodyLarge
                      ?.copyWith(color: AppColors.textMuted),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  'Type a message or tap the mic button',
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(color: AppColors.textMuted),
                ),
              ],
            ),
          );
        }

        // Load corrections per message so we can render them inline.
        return FutureBuilder<Map<String, List<Correction>>>(
          future: _loadCorrectionsByMessage(ref),
          builder: (context, snapshot) {
            final correctionsByMsg = snapshot.data ?? const {};
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
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Error: $e')),
    );
  }

  Future<Map<String, List<Correction>>> _loadCorrectionsByMessage(
      WidgetRef ref) async {
    final repo = ref.read(chatRepoProvider);
    final all = await repo.getAllCorrections();
    final map = <String, List<Correction>>{};
    for (final c in all) {
      final key = c.messageId;
      if (key == null) continue;
      map.putIfAbsent(key, () => []).add(c);
    }
    return map;
  }
}

final _messagesProvider =
    FutureProvider.family<List<ChatMessage>, String>((ref, sessionId) async {
  final repo = ref.watch(chatRepoProvider);
  return repo.getMessages(sessionId);
});

/// Lightweight typing indicator shown while the LLM is responding.
class _TypingBubble extends StatelessWidget {
  const _TypingBubble();

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: AppSpacing.sm),
        padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md, vertical: AppSpacing.md),
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
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(3, (i) {
            return Container(
              margin: const EdgeInsets.symmetric(horizontal: 2),
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: AppColors.accentPrimary.withValues(alpha: 0.6),
                shape: BoxShape.circle,
              ),
            );
          }),
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
    final bubbleColor =
        isUser ? AppColors.bubbleUser : AppColors.bubbleAi;
    final accent = isUser
        ? AppColors.accentSecondary
        : AppColors.accentPrimary;

    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: AppSpacing.sm),
        padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md, vertical: AppSpacing.sm),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.78,
        ),
        decoration: BoxDecoration(
          color: bubbleColor,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(AppRadius.lg),
            topRight: const Radius.circular(AppRadius.lg),
            bottomLeft:
                Radius.circular(isUser ? AppRadius.lg : AppRadius.xs),
            bottomRight:
                Radius.circular(isUser ? AppRadius.xs : AppRadius.lg),
          ),
          border: Border.all(color: accent.withValues(alpha: 0.2)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              message,
              style: Theme.of(context).textTheme.bodyLarge,
            ),
            // Inline corrections for AI messages.
            if (!isUser && corrections.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.sm),
              ...corrections.map((c) => _CorrectionInline(correction: c)),
            ],
            if (!isUser && onPlayTts != null) ...[
              const SizedBox(height: AppSpacing.xs),
              GestureDetector(
                onTap: onPlayTts,
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
            ],
          ],
        ),
      ),
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
          horizontal: AppSpacing.sm, vertical: AppSpacing.xs),
      decoration: BoxDecoration(
        color: AppColors.bubbleCorrection,
        borderRadius: BorderRadius.circular(AppRadius.sm),
        border: Border.all(
            color: AppColors.success.withValues(alpha: 0.3), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.xs, vertical: 1),
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
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppColors.textSecondary,
                  ),
            ),
          ],
        ],
      ),
    );
  }
}

class _ChatInputBar extends StatelessWidget {
  final TextEditingController controller;
  final bool isRecording;
  final bool isLoading;
  final VoidCallback onSend;
  final VoidCallback onRecordToggle;

  const _ChatInputBar({
    required this.controller,
    required this.isRecording,
    required this.isLoading,
    required this.onSend,
    required this.onRecordToggle,
  });

  @override
  Widget build(BuildContext context) {
    final canSend = controller.text.trim().isNotEmpty && !isLoading;
    return Container(
      padding: EdgeInsets.only(
        left: AppSpacing.md,
        right: AppSpacing.md,
        top: AppSpacing.sm,
        bottom: MediaQuery.of(context).padding.bottom + AppSpacing.md,
      ),
      decoration: BoxDecoration(
        color: AppColors.bgSecondary,
        border: Border(
          top: BorderSide(color: AppColors.glassBorder),
        ),
      ),
      child: Row(
        children: [
          // Record button
          Tooltip(
            message: isRecording ? 'Stop recording' : 'Tap to record',
            child: GestureDetector(
              onTap: isLoading ? null : onRecordToggle,
              child: Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isRecording
                      ? AppColors.error
                      : AppColors.accentSecondary,
                  boxShadow: [
                    BoxShadow(
                      color: (isRecording
                              ? AppColors.error
                              : AppColors.accentSecondary)
                          .withValues(alpha: 0.3),
                      blurRadius: isRecording ? 20 : 10,
                    ),
                  ],
                ),
                child: Icon(
                  isRecording ? Icons.stop : Icons.mic,
                  color: Colors.white,
                ),
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          // Text input
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: AppColors.bgTertiary,
                borderRadius: BorderRadius.circular(AppRadius.xl),
                border: Border.all(color: AppColors.glassBorder),
              ),
              child: TextField(
                controller: controller,
                enabled: !isLoading,
                style: const TextStyle(color: AppColors.textPrimary),
                textInputAction: TextInputAction.send,
                decoration: InputDecoration(
                  hintText: 'Type a message...',
                  hintStyle: TextStyle(color: AppColors.textMuted),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.md, vertical: AppSpacing.sm),
                ),
                onSubmitted: (_) {
                  if (canSend) onSend();
                },
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          // Send button
          Opacity(
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
        ],
      ),
    );
  }
}
