import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:just_audio/just_audio.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/util/responsive.dart';
import '../../../../core/services/connectivity_check.dart';
import '../../../../core/i18n/app_localizations.dart';
import '../../../../shared/widgets/glass_widgets.dart';
import '../../../../shared/widgets/virtual_character.dart';
import '../../../../shared/widgets/virtual_character_3d.dart';
import '../../../../shared/providers.dart';
import '../../data/llm_service.dart';
import '../../data/stt_service.dart';
import '../../data/tts_service.dart';
import '../../data/recording_service.dart';
import '../../data/tts_playback_service.dart';
import '../../domain/app_error.dart';
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

  // The text the AI is currently speaking via TTS, passed to VirtualCharacter
  // for lip-sync. Set when TTS starts, cleared when playback completes/stops.
  String? _speakingText;

  // Active tutor identity — drives the character panel + AppBar title so
  // the UI reflects who the user picked on the TutorSelectionScreen.
  String _tutorName = 'AI Tutor';
  String _tutorAvatar = '👩‍🏫';

  // D11: whether STT+TTS are both configured. When false we show a persistent
  // banner above the chat (not a transient snackbar) so the user always knows
  // voice is unavailable and can tap to configure.
  bool _voiceConfigured = true;

  // E5: continuous conversation mode. When on, after the AI finishes speaking
  // (TTS completes) the mic auto-rearms so the user can reply hands-free
  // (E1). Also enables barge-in so tapping mic during TTS stops playback.
  bool _continuousMode = false;

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
    _checkVoiceConfigured();
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

  /// Check whether STT + TTS profiles exist so we can show a persistent
  /// banner when voice is unavailable (D11). We read once on screen entry;
  /// if the user configures a profile mid-session they can re-enter to clear
  /// the banner.
  Future<void> _checkVoiceConfigured() async {
    try {
      final profileRepo = ref.read(profileRepoProvider);
      final stt = await profileRepo.getActiveSttProfile();
      final tts = await profileRepo.getActiveTtsProfile();
      if (mounted) {
        setState(() => _voiceConfigured = stt != null && tts != null);
      }
    } catch (_) {
      // Best-effort — assume configured so we don't false-flag.
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

    // Layout regime:
    //   - sideBySide: iPad / desktop / wide browser → character panel
    //     beside the chat.
    //   - hidePanel: short landscape phone (~390pt tall) → no character
    //     panel at all, chat takes the full height.
    //   - stacked (default): phone portrait → character panel above chat.
    final sideBySide = Responsive.shouldUseSideBySide(context);
    final hidePanel = Responsive.shouldHideStackedCharacterPanel(context);

    // Wrap the Scaffold in a Focus node so hardware-key events (Esc to
    // cancel recording) are caught at the screen level even when the text
    // field isn't focused. The Focus widget manages its own internal node
    // when none is passed, so there's nothing to dispose.
    final l = AppLocalizations.of(context);
    final isLight = Theme.of(context).brightness == Brightness.light;
    return Focus(
      onKeyEvent: _handleKeyEvent,
      child: Scaffold(
        backgroundColor:
            isLight ? AppColors.lightBgPrimary : AppColors.bgPrimary,
        appBar: AppBar(
          leading: IconButton(
            tooltip: l.t('chat.back_home'),
            icon: const Icon(Icons.arrow_back_ios_new),
            onPressed: () => _exitWithSummary(),
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
            // On a short landscape phone the AppBar is the only place the
            // tutor's listening/thinking/speaking state can surface — show
            // a small status dot so the user still gets feedback when the
            // character panel is hidden.
            if (hidePanel)
              Padding(
                padding: const EdgeInsets.only(right: AppSpacing.sm),
                child: _AppBarStatusDot(state: _characterState),
              ),
            IconButton(
              tooltip: l.t('chat.pick_tutor'),
              icon: const Icon(Icons.swap_horiz),
              // Await the tutor-selection route so we can re-read the
              // persisted `selected_tutor_id` after the user picks one.
              // Without this, the AppBar title + character panel keep
              // showing the *old* tutor until the user leaves & re-enters
              // the chat.
              onPressed: () async {
                await context.push('/tutor-selection');
                if (mounted) _loadTutorIdentity();
              },
            ),
            IconButton(
              tooltip: l.t('chat.more_options'),
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
          child: sideBySide
              ? Row(
                  children: [
                    _CharacterPanel(
                      state: _characterState,
                      tutorName: _tutorName,
                      tutorAvatar: _tutorAvatar,
                      speakingText: _speakingText,
                      audioLevelStream: _ttsPlaybackService.amplitudeStream,
                      panelWidth: Responsive.sidePanelWidth(context),
                    ),
                    const VerticalDivider(
                      width: 1,
                      color: AppColors.glassBorder,
                    ),
                    Expanded(child: _chatColumn(context)),
                  ],
                )
              : hidePanel
              // Short landscape phone: chat fills the whole body.
              ? _chatColumn(context)
              : Column(
                  children: [
                    _CharacterPanel(
                      state: _characterState,
                      tutorName: _tutorName,
                      tutorAvatar: _tutorAvatar,
                      speakingText: _speakingText,
                      audioLevelStream: _ttsPlaybackService.amplitudeStream,
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
    final l = AppLocalizations.of(context);
    return Column(
      children: [
        // D11: persistent banner when voice services aren't configured.
        if (!_voiceConfigured)
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () => context.push('/service-config'),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.md,
                  vertical: AppSpacing.sm,
                ),
                decoration: BoxDecoration(
                  color: AppColors.warning.withValues(alpha: 0.15),
                  border: Border(
                    bottom: BorderSide(
                      color: AppColors.warning.withValues(alpha: 0.3),
                      width: 0.5,
                    ),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(Icons.mic_off,
                        size: 18, color: AppColors.warning),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Text(
                        l.t('chat.voice_not_configured'),
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: AppColors.warning,
                            ),
                      ),
                    ),
                    Icon(Icons.chevron_right,
                        size: 16, color: AppColors.warning),
                  ],
                ),
              ),
            ),
          ),
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
              continuousMode: _continuousMode,
              onSend: _handleSend,
              onRecordToggle: _handleRecordToggle,
              onToggleContinuous: (v) =>
                  setState(() => _continuousMode = v),
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
          final l = AppLocalizations.of(context);
          _showConfigNeeded(
            l.t('chat.config_needed_llm_title'),
            l.t('chat.config_needed_llm_body'),
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

      // E3: clear the loading state as soon as the AI message is saved so the
      // input bar is immediately usable. TTS is fire-and-forget — its state
      // is tracked independently via _playingMessageId / CharacterState.
      if (mounted) {
        setState(() => _isLoading = false);
      }

      // Auto-play TTS for the AI reply + animate speaking state.
      // Fire-and-forget (E3): don't block the finally block on TTS.
      _autoplayTts(aiResponse.id, response.content);
    } catch (e) {
      if (mounted) {
        _showAppError(e);
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
            final l = AppLocalizations.of(context);
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(SnackBar(content: Text(l.t('chat.no_audio'))));
            _setCharacterState(CharacterState.idle);
          }
          return;
        }

        final profileRepo = ref.read(profileRepoProvider);
        final sttProfile = await profileRepo.getActiveSttProfile();

        if (sttProfile == null) {
          if (mounted) {
            final l = AppLocalizations.of(context);
            _showConfigNeeded(
              l.t('chat.config_needed_stt_title'),
              l.t('chat.config_needed_stt_body'),
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
          // E13: empty transcript — give an actionable hint rather than a
          // bare "couldn't transcribe" so the user knows how to fix it.
          final l = AppLocalizations.of(context);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(l.t('chat.transcribe_empty_hint'))),
          );
          _setCharacterState(CharacterState.idle);
        }
      } catch (e) {
        if (mounted) {
          _showAppError(e);
          _setCharacterState(CharacterState.idle);
        }
      }
    } else {
      // E2 barge-in: if TTS is playing, stop it before starting to record so
      // the user can interrupt the AI mid-sentence (like a real conversation).
      if (_playingMessageId != null) {
        await _ttsPlaybackService.stop();
        if (mounted) {
          setState(() {
            _playingMessageId = null;
            _speakingText = null;
          });
        }
        if (_characterState == CharacterState.speaking) {
          _setCharacterState(CharacterState.idle);
        }
      }
      try {
        await _recordingService.startRecording();
        setState(() => _isRecording = true);
        _setCharacterState(CharacterState.listening);
      } catch (e) {
        if (mounted) {
          _showAppError(e);
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
      if (mounted) {
        setState(() {
          _playingMessageId = messageId;
          _speakingText = text;
        });
      }

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
        setState(() {
          _playingMessageId = null;
          _speakingText = null;
        });
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
      if (mounted) {
        setState(() {
          _playingMessageId = null;
          _speakingText = null;
        });
      }
      if (_characterState == CharacterState.speaking) {
        _setCharacterState(CharacterState.idle);
      }
      return;
    }

    try {
      setState(() {
        _playingMessageId = messageId;
        _speakingText = text;
      });
      _setCharacterState(CharacterState.speaking);

      final profileRepo = ref.read(profileRepoProvider);
      final ttsProfile = await profileRepo.getActiveTtsProfile();

      if (ttsProfile == null) {
        if (mounted) {
          final l = AppLocalizations.of(context);
          _showConfigNeeded(
            l.t('chat.config_needed_tts_title'),
            l.t('chat.config_needed_tts_body'),
          );
        }
        setState(() {
          _playingMessageId = null;
          _speakingText = null;
        });
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
        _showAppError(e);
        setState(() {
          _playingMessageId = null;
          _speakingText = null;
        });
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
        setState(() {
          _playingMessageId = null;
          _speakingText = null;
        });
        if (_characterState == CharacterState.speaking) {
          _setCharacterState(CharacterState.idle);
        }
        // E1: in continuous mode, auto-rearm the mic after the AI finishes
        // speaking so the user can reply hands-free — mirroring how real
        // conversation flows (Praktika/Speak both do this). Gated by the
        // toggle so users who prefer manual control aren't surprised.
        if (_continuousMode && !_isRecording && !_isLoading && _voiceConfigured) {
          _handleRecordToggle();
        }
      }
    });
  }

  /// Shows a snackbar with a "Configure" action that navigates to the
  /// service configuration screen. Used when an LLM/STT/TTS profile is
  /// missing during chat — gives the user a one-tap shortcut to fix it
  /// instead of leaving them stranded with a generic error.
  void _showConfigNeeded(String title, String body) {
    final l = AppLocalizations.of(context);
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
          label: l.t('common.configure'),
          onPressed: () => context.push('/service-config'),
        ),
      ),
    );
  }

  void _showSessionOptions(BuildContext context) {
    final l = AppLocalizations.of(context);
    final isLight = Theme.of(context).brightness == Brightness.light;
    showModalBottomSheet(
      context: context,
      backgroundColor:
          isLight ? AppColors.lightBgSecondary : AppColors.bgTertiary,
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
              title: Text(l.t('chat.archive_session')),
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
              title: Text(
                l.t('chat.delete_session'),
                style: const TextStyle(color: AppColors.error),
              ),
              onTap: () async {
                // Confirm before destructive action — deletes the session
                // and all related messages + corrections (transactional).
                Navigator.pop(context); // close the bottom sheet first
                final confirmed = await showDialog<bool>(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: Text(l.t('chat.delete_confirm_title')),
                    content: Text(l.t('chat.delete_confirm_body')),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(ctx, false),
                        child: Text(l.t('common.cancel')),
                      ),
                      TextButton(
                        style: TextButton.styleFrom(foregroundColor: AppColors.error),
                        onPressed: () => Navigator.pop(ctx, true),
                        child: Text(l.t('common.delete')),
                      ),
                    ],
                  ),
                );
                if (confirmed != true || !mounted) return;
                try {
                  await ref.read(chatRepoProvider).deleteSession(widget.sessionId);
                  if (mounted) {
                    final ll = AppLocalizations.of(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(ll.t('chat.deleted'))),
                    );
                    context.go('/');
                  }
                } catch (e) {
                  if (mounted) {
                    final ll = AppLocalizations.of(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          ll.tArg('chat.delete_failed', {
                            'error': AppError.redact(e.toString()),
                          }),
                        ),
                      ),
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

  /// E11/E12: map an arbitrary exception to a typed [AppError] and show a
  /// SnackBar with the appropriate localized message + action (Retry /
  /// Configure / Open Settings). Replaces the old generic `_safeError(e)`
  /// SnackBars so users always get an actionable error instead of a raw
  /// exception string (which could leak API keys).
  void _showAppError(Object e) {
    final l = AppLocalizations.of(context);
    final err = AppError.from(e);
    var message = l.t(err.messageKey);
    if (err.appendDetail) {
      final detail = AppError.redact(e.toString());
      if (detail.length > 120) {
        message = '$message\n${detail.substring(0, 120)}…';
      } else {
        message = '$message\n$detail';
      }
    }
    SnackBarAction? action;
    if (err.actionLabelKey != null) {
      final label = l.t(err.actionLabelKey!);
      action = SnackBarAction(
        label: label,
        onPressed: () {
          switch (err.action) {
            case AppErrorAction.configure:
              context.push('/service-config');
              break;
            case AppErrorAction.retry:
              // Retry is context-specific; the user re-triggers the failed
              // action manually (send / record / play). No-op here.
              break;
            case AppErrorAction.openSettings:
              // Open the app settings page (service-config is the closest
              // in-app equivalent for mic permission guidance).
              context.push('/service-config');
              break;
            case AppErrorAction.none:
              break;
          }
        },
      );
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        duration: const Duration(seconds: 5),
        action: action,
      ),
    );
  }

  /// Exit the chat screen, showing a session summary SnackBar when the
  /// user had a meaningful conversation (≥2 messages). Falls back to a
  /// plain navigation if anything goes wrong — never block the exit.
  Future<void> _exitWithSummary() async {
    try {
      final repo = ref.read(chatRepoProvider);
      final messages = await repo.getMessages(widget.sessionId);
      if (messages.length < 2) {
        if (mounted) context.go('/');
        return;
      }
      final corrections = await repo.getCorrectionsForSession(widget.sessionId);
      final session = await repo.getSession(widget.sessionId);
      final start = session?.createdAt ?? messages.first.createdAt;
      final end = DateTime.now();
      final minutes = end.difference(start).inMinutes.clamp(0, 999);
      final l = AppLocalizations.of(context);
      final msgCount = messages.length.toString();
      final corrCount = corrections.length.toString();
      final minutesStr = minutes.toString();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                l.t('chat.session_summary_title'),
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              Text(l.tArg('chat.session_summary_body', {
                'msgCount': msgCount,
                'corrCount': corrCount,
                'minutes': minutesStr,
              })),
              const SizedBox(height: 4),
              Text(l.t('chat.session_summary_encourage')),
            ],
          ),
          duration: const Duration(seconds: 4),
        ),
      );
      await Future<void>.delayed(const Duration(milliseconds: 250));
      if (mounted) context.go('/');
    } catch (_) {
      if (mounted) context.go('/');
    }
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
    final l = AppLocalizations.of(context);
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
                  l.t('chat.start_conversation'),
                  style: Theme.of(
                    context,
                  ).textTheme.bodyLarge?.copyWith(color: AppColors.textMuted),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  l.t('chat.start_hint'),
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
      error: (e, _) => Center(
        child: Text(l.tArg('chat.error', {'error': e.toString()})),
      ),
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
          color: Theme.of(context).brightness == Brightness.light
              ? AppColors.lightBubbleAi
              : AppColors.bubbleAi,
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
    final l = AppLocalizations.of(context);
    final isLight = Theme.of(context).brightness == Brightness.light;
    final bubbleColor = isUser
        ? (isLight ? AppColors.lightBubbleUser : AppColors.bubbleUser)
        : (isLight ? AppColors.lightBubbleAi : AppColors.bubbleAi);
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
                // Inline corrections for user messages — the LLM may return
                // grammar/vocabulary fixes for what the user said. Shown
                // right-aligned (the bubble itself is already right-aligned)
                // with a small "grammar suggestions" title above the list.
                if (isUser && corrections.isNotEmpty) ...[
                  const SizedBox(height: AppSpacing.sm),
                  Align(
                    alignment: Alignment.centerRight,
                    child: Text(
                      l.t('chat.suggestion_title'),
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
                  ...corrections.map((c) => _CorrectionInline(correction: c)),
                ],
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
                        // 44x44 meets the iOS HIG minimum touch target.
                        constraints: const BoxConstraints(
                          minWidth: Responsive.minTapTarget,
                          minHeight: Responsive.minTapTarget,
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
                              isPlaying ? l.t('chat.stop') : l.t('chat.listen'),
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

  String _typeLabel(BuildContext context, CorrectionType type) {
    switch (type) {
      case CorrectionType.grammar:
        return AppLocalizations.of(context).t('correction.type_grammar');
      case CorrectionType.vocabulary:
        return AppLocalizations.of(context).t('correction.type_vocabulary');
      case CorrectionType.pronunciation:
        return AppLocalizations.of(context).t('correction.type_pronunciation');
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
        color: Theme.of(context).brightness == Brightness.light
            ? AppColors.lightBubbleCorrection
            : AppColors.bubbleCorrection,
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
                  _typeLabel(context, correction.type),
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

/// Input mode for [_ChatInputBar]. Voice is the default — the user sees a
/// single large mic button; tapping it records, and on stop the transcript is
/// auto-sent (STT → text → send). Text mode restores the classic
/// TextField + record + send row for users who want to type or edit.
enum _InputMode { voice, text }

class _ChatInputBar extends ConsumerStatefulWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final bool isRecording;
  final bool isLoading;
  final bool continuousMode;
  final VoidCallback onSend;
  final VoidCallback onRecordToggle;
  final ValueChanged<bool> onToggleContinuous;

  const _ChatInputBar({
    required this.controller,
    required this.focusNode,
    required this.isRecording,
    required this.isLoading,
    required this.continuousMode,
    required this.onSend,
    required this.onRecordToggle,
    required this.onToggleContinuous,
  });

  @override
  ConsumerState<_ChatInputBar> createState() => _ChatInputBarState();
}

class _ChatInputBarState extends ConsumerState<_ChatInputBar>
    with SingleTickerProviderStateMixin {
  _InputMode _inputMode = _InputMode.voice;

  // Scale pulse for the big voice-mode mic button while recording.
  late final AnimationController _pulseController;
  late final Animation<double> _pulseScale;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _pulseScale = Tween<double>(begin: 1.0, end: 1.08).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
    if (widget.isRecording) _pulseController.repeat(reverse: true);
  }

  @override
  void didUpdateWidget(covariant _ChatInputBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isRecording != oldWidget.isRecording) {
      if (widget.isRecording) {
        _pulseController.repeat(reverse: true);
      } else {
        _pulseController.stop();
        _pulseController.value = 0.0;
      }
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final isLight = Theme.of(context).brightness == Brightness.light;
    // Bottom padding: the parent Scaffold has `resizeToAvoidBottomInset:
    // true`, which shrinks the body by `viewInsets.bottom` when the
    // keyboard opens — so the input bar already sits on top of the
    // keyboard. We only need to add safe-area bottom + a little extra
    // breathing room here. (Adding viewInsets.bottom too would push
    // the text field ~340pt above the keyboard on mobile web.)
    final safeBottom = MediaQuery.of(context).padding.bottom;
    final bottomPad = safeBottom + AppSpacing.md;
    final isOffline = ref.watch(isOfflineProvider);
    return Container(
      padding: EdgeInsets.only(
        left: AppSpacing.md,
        right: AppSpacing.md,
        top: AppSpacing.sm,
        bottom: bottomPad,
      ),
      decoration: BoxDecoration(
        color: isLight ? AppColors.lightBgSecondary : AppColors.bgSecondary,
        border: Border(
            top: BorderSide(
                color: isLight
                    ? AppColors.lightGlassBorder
                    : AppColors.glassBorder)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (isOffline) const _OfflineHint(),
          // Top row: continuous-mode toggle (left) + voice/text switch (right).
          // E5: continuous mode auto-rearms the mic after the AI replies for
          // hands-free conversation.
          Row(
            children: [
              // Continuous-mode toggle — only meaningful in voice mode.
              if (_inputMode == _InputMode.voice)
                _ContinuousToggle(
                  enabled: widget.continuousMode,
                  onChanged: widget.onToggleContinuous,
                ),
              const Spacer(),
              // Mode switch — Voice mode shows a keyboard icon (→ text),
              // text mode shows a mic icon (→ voice).
              IconButton(
                tooltip: _inputMode == _InputMode.voice
                    ? l.t('chat.switch_to_text')
                    : l.t('chat.switch_to_voice'),
                icon: Icon(
                  _inputMode == _InputMode.voice
                      ? Icons.keyboard_outlined
                      : Icons.mic_none,
                ),
                onPressed: () {
                  setState(() {
                    _inputMode = _inputMode == _InputMode.voice
                        ? _InputMode.text
                        : _InputMode.voice;
                  });
                },
              ),
            ],
          ),
          if (_inputMode == _InputMode.voice)
            _buildVoiceInput(l)
          else
            _buildTextInputRow(l),
        ],
      ),
    );
  }

  /// Voice-default mode: one large centered mic button. Tapping starts
  /// recording; tapping again stops → STT → transcript is filled into the
  /// (hidden) controller and auto-sent via [_handleRecordToggle] →
  /// [_handleSend]. The button turns red and pulses while recording.
  Widget _buildVoiceInput(AppLocalizations l) {
    final isRecording = widget.isRecording;
    final isLoading = widget.isLoading;
    final color =
        isRecording ? AppColors.error : AppColors.accentSecondary;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Semantics(
            button: true,
            enabled: !isLoading,
            label: isRecording
                ? l.t('chat.stop_recording')
                : l.t('chat.start_voice'),
            child: Tooltip(
              message: isRecording
                  ? l.t('chat.stop_recording')
                  : l.t('chat.tap_to_record'),
              child: GestureDetector(
                onTap: isLoading ? null : widget.onRecordToggle,
                child: AnimatedBuilder(
                  animation: _pulseScale,
                  builder: (context, _) {
                    final scale = isRecording ? _pulseScale.value : 1.0;
                    return Transform.scale(
                      scale: scale,
                      child: Container(
                        width: 72,
                        height: 72,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: color,
                          boxShadow: [
                            BoxShadow(
                              color: color.withValues(alpha: 0.4),
                              blurRadius: isRecording ? 24 : 12,
                              spreadRadius: isRecording ? 4 : 0,
                            ),
                          ],
                        ),
                        child: Icon(
                          isRecording ? Icons.stop : Icons.mic,
                          color: Colors.white,
                          size: 32,
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            isRecording
                ? l.t('chat.stop_recording')
                : l.t('chat.tap_to_record'),
            style: TextStyle(
              color: AppColors.textSecondary,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }

  /// Text mode: the classic record button + TextField + send button row.
  Widget _buildTextInputRow(AppLocalizations l) {
    final isRecording = widget.isRecording;
    final isLoading = widget.isLoading;
    final controller = widget.controller;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        // Record button — pulsing glow when recording, using GlowButton
        // (which has its own AnimationController). 48x48 meets the 44x44
        // minimum touch target. Semantics exposes the state to screen
        // readers; the Tooltip shows the same on hover for mouse users.
        Semantics(
          button: true,
          enabled: !isLoading,
          label: isRecording
              ? l.t('chat.stop_recording')
              : l.t('chat.start_voice'),
          hint: isRecording
              ? 'Double tap to stop and transcribe'
              : 'Double tap to record a voice message',
          child: Tooltip(
            message: isRecording
                ? l.t('chat.stop_recording')
                : l.t('chat.tap_to_record'),
            child: _RecordButton(
              isRecording: isRecording,
              onTap: isLoading ? null : widget.onRecordToggle,
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
              color: isLight
                  ? AppColors.lightBgSurface
                  : AppColors.bgTertiary,
              borderRadius: BorderRadius.circular(AppRadius.xl),
              border: Border.all(
                color: isRecording
                    ? AppColors.error.withValues(alpha: 0.6)
                    : (isLight
                        ? AppColors.lightGlassBorder
                        : AppColors.glassBorder),
              ),
            ),
            child: TextField(
              controller: controller,
              focusNode: widget.focusNode,
              enabled: !isLoading,
              style: TextStyle(
                  color: isLight
                      ? AppColors.lightTextPrimary
                      : AppColors.textPrimary),
              textInputAction: TextInputAction.send,
              maxLines: null,
              minLines: 1,
              decoration: InputDecoration(
                hintText: l.t('chat.type_message'),
                hintStyle: TextStyle(
                    color: isLight
                        ? AppColors.lightTextMuted
                        : AppColors.textMuted),
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
                if (canSubmit) widget.onSend();
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
              label: l.t('chat.send'),
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
                    onPressed: canSend ? widget.onSend : null,
                  ),
                ),
              ),
            );
          },
        ),
      ],
    );
  }
}

/// Compact offline banner shown above the chat input when the browser
/// reports no network. AI replies + STT/TTS need the network; everything
/// else (history, review, progress, settings, scenarios) keeps working.
class _OfflineHint extends StatelessWidget {
  const _OfflineHint();

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.xs + 2,
      ),
      decoration: BoxDecoration(
        color: AppColors.warning.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(
          color: AppColors.warning.withValues(alpha: 0.4),
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.cloud_off_rounded,
            size: 16,
            color: AppColors.warning,
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              l.t('chat.offline_hint'),
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppColors.warning,
                    height: 1.3,
                  ),
            ),
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

/// E5: a compact "Continuous conversation" toggle chip shown in the input
/// bar. When on, the mic auto-rearms after the AI finishes speaking so the
/// user can converse hands-free. Tapping flips the switch and persists
/// nothing (it's a per-session preference, reset on screen exit).
class _ContinuousToggle extends StatelessWidget {
  final bool enabled;
  final ValueChanged<bool> onChanged;

  const _ContinuousToggle({required this.enabled, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final isLight = Theme.of(context).brightness == Brightness.light;
    final active = enabled
        ? AppColors.accentPrimary
        : (isLight ? AppColors.lightTextMuted : AppColors.textMuted);
    return InkWell(
      borderRadius: BorderRadius.circular(AppRadius.full),
      onTap: () => onChanged(!enabled),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.sm,
          vertical: AppSpacing.xs,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              enabled ? Icons.graphic_eq : Icons.record_voice_over_outlined,
              size: 16,
              color: active,
            ),
            const SizedBox(width: AppSpacing.xs),
            Text(
              l.t('chat.continuous_mode'),
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: active,
                    fontWeight: enabled ? FontWeight.w600 : FontWeight.normal,
                  ),
            ),
          ],
        ),
      ),
    );
  }
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

  /// Text the avatar is currently "speaking" via TTS — passed straight to
  /// VirtualCharacter for lip-sync. Null when not speaking.
  final String? speakingText;

  /// TTS amplitude stream forwarded to the 3D avatar for audio-driven
  /// lip-sync (blended onto jawOpen on top of the text viseme).
  final Stream<double>? audioLevelStream;

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
    this.speakingText,
    this.audioLevelStream,
    this.panelWidth,
    this.panelHeight,
    this.compact = false,
  });

  /// Human-readable label for the current character state, used for the
  /// screen-reader live region so blind users can follow the voice flow
  /// (listening → thinking → speaking) without seeing the avatar.
  String _stateLabel(BuildContext context, CharacterState s) {
    final l = AppLocalizations.of(context);
    switch (s) {
      case CharacterState.idle:
        return '$tutorName · ${l.t('chat.ready')}';
      case CharacterState.listening:
        return l.t('chat.listening');
      case CharacterState.thinking:
        return l.t('chat.thinking');
      case CharacterState.speaking:
        return l.t('chat.speaking');
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = Responsive.characterSize(context) * (compact ? 0.8 : 1.0);

    final child = VirtualCharacter3D(
      tutorName: tutorName,
      tutorAvatar: tutorAvatar,
      state: state,
      size: size,
      showLabel: !compact,
      speakingText: speakingText,
      audioLevelStream: audioLevelStream,
    );

    // Live region: screen readers announce state changes (e.g. "Thinking",
    // "Speaking") without the user needing to focus the avatar.
    final labelled = Semantics(
      liveRegion: true,
      label: _stateLabel(context, state),
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

/// A tiny status indicator shown in the AppBar when the character panel
/// is hidden (short landscape phone). Mirrors the panel's state colors so
/// the user still gets listening/thinking/speaking feedback in a 12pt dot.
class _AppBarStatusDot extends StatelessWidget {
  final CharacterState state;
  const _AppBarStatusDot({required this.state});

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final color = switch (state) {
      CharacterState.idle => AppColors.textMuted,
      CharacterState.listening => AppColors.accentSecondary,
      CharacterState.thinking => AppColors.accentPrimary,
      CharacterState.speaking => AppColors.success,
    };
    return Semantics(
      liveRegion: true,
      label: switch (state) {
        CharacterState.idle => l.t('chat.ready'),
        CharacterState.listening => l.t('chat.listening'),
        CharacterState.thinking => l.t('chat.thinking'),
        CharacterState.speaking => l.t('chat.speaking'),
      },
      child: Container(
        width: 12,
        height: 12,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          boxShadow: state != CharacterState.idle
              ? [BoxShadow(color: color.withValues(alpha: 0.5), blurRadius: 6)]
              : null,
        ),
      ),
    );
  }
}
