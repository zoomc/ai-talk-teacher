import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:just_audio/just_audio.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/util/responsive.dart';
import '../../../../core/util/retry.dart';
import '../../../../core/i18n/app_localizations.dart';
import '../../../../core/runtime/runtime_mode_banner.dart';
import '../../../../shared/widgets/glass_widgets.dart';
import '../../../../shared/providers.dart';
import '../../data/chat_repository.dart';
import '../../data/chat_gateways.dart';
import '../../data/llm_streaming.dart';
import '../../data/recording_service.dart';
import '../../data/tts_playback_service.dart';
import '../../domain/app_error.dart';
import '../../domain/chat_models.dart';
import '../../domain/conversation_state.dart';
import '../../domain/phoneme_score.dart';
import '../../domain/tutor.dart';
import '../../domain/tutor_prompts.dart';
import '../../domain/tutor_emotion.dart';
import '../../../avatar/data/rhubarb_service.dart';
import '../../../avatar/presentation/widgets/avatar_stage.dart';
import '../../../../shared/widgets/virtual_character.dart' show CharacterState;
import '../../../profile/domain/guest_profiles.dart';
import '../../../../shared/widgets/virtual_character.dart';
import '../../../../widgets/chat/chat_bubble.dart';
import '../../../../widgets/chat/chat_input_bar.dart';
import '../../../../widgets/chat/chat_header.dart';
import '../../../../widgets/chat/chat_message_list.dart';
import '../../../../widgets/chat/chat_providers.dart';

/// P1 task 2 — ChatScreen is now a slim container that wires together the
/// extracted [ChatHeader], [ChatMessageList], and [ChatInputBar] widgets.
/// The _CharacterPanel stays here because it's tightly coupled to the
/// screen's character-state + speaking-text.
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
  final FocusNode _messageFocusNode = FocusNode();

  /// Phase 3 — key into the avatar stage so we can push viseme timelines
  /// produced by Rhubarb into the live widget.
  final GlobalKey<AvatarStageState> _avatarKey = GlobalKey<AvatarStageState>();
  final ConversationStateMachine _conversation = ConversationStateMachine();

  /// Phase 3 — Rhubarb Lip Sync service. Lazily probed; when the binary
  /// isn't installed the avatar stage silently falls back to the
  /// amplitude-driven mouth open path.
  RhubarbService? _rhubarbService;
  bool _rhubarbProbed = false;

  bool _isRecording = false;
  bool _isLoading = false;
  String? _playingMessageId;
  CharacterState _characterState = CharacterState.idle;
  StreamSubscription? _playerStateSub;
  int _playbackToken = 0;

  String? _speakingText;

  // P1 task 1 — live streaming text for progressive AI reply rendering.
  String? _streamingText;

  // P1 task 3 — retry progress hint shown in the input bar.
  String? _retryHint;

  // E14 — message IDs whose TTS playback failed, to show inline retry.
  final Set<String> _ttsFailedMessageIds = {};

  // P1 task 5 — current tutor emotion driven by TTS amplitude + keywords.
  TutorEmotion _tutorEmotion = TutorEmotion.neutral;
  TutorGestureCue _tutorGesture = TutorGestureCue.idle;
  StreamSubscription<double>? _amplitudeSub;

  // E7 — thinking filler loop timer.
  Timer? _thinkingFillerTimer;

  String _tutorName = TutorRepository.getDefaultTutor().name;
  String _tutorAvatar = TutorRepository.getDefaultTutor().avatar;

  bool _voiceConfigured = true;
  bool _continuousMode = false;

  Timer? _guestTimer;
  bool _isGuestSession = false;
  int _guestSecondsLeft = 0;
  bool _guestTrialEnded = false;

  @override
  void initState() {
    super.initState();
    // Wire the global TTS playback service used by the phoneme detail sheet.
    ttsPlaybackServiceGlobal = _ttsPlaybackService;
    _loadTutorIdentity();
    _loadTtsSpeed();
    _checkVoiceConfigured();
    _setupGuestTrialIfNeeded();
    // Phase 5 — on init, check for a session snapshot (crash recovery).
    // The conversation messages are already persisted in SQLite, so the
    // snapshot confirms the session was cleanly saved last time. If the
    // snapshot exists, we log recovery and clear it so a second crash
    // during this session doesn't replay the recovery path.
    _checkSnapshotRecovery();
    _ensureSessionExists();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (Responsive.isWide(context)) {
        _messageFocusNode.requestFocus();
      }
    });
  }

  Future<void> _loadTtsSpeed() async {
    try {
      final raw = await ref.read(profileRepoProvider).getSetting('tts_speed');
      if (raw == null) return;
      final speed = double.tryParse(raw);
      if (speed == null || speed <= 0 || speed > 3) return;
      await _ttsPlaybackService.setSpeed(speed);
    } catch (_) {}
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
    } catch (_) {}
  }

  Future<void> _checkVoiceConfigured() async {
    try {
      if (!ref.read(runtimeCapabilitiesProvider).requiresConfiguration) {
        if (mounted) setState(() => _voiceConfigured = true);
        return;
      }
      final profileRepo = ref.read(profileRepoProvider);
      final stt = await profileRepo.getActiveSttProfile();
      final tts = await profileRepo.getActiveTtsProfile();
      if (mounted) {
        setState(() => _voiceConfigured = stt != null && tts != null);
      }
    } catch (_) {}
  }

  /// Phase 5 — check whether the session has a recoverable snapshot from
  /// a previous incomplete session (crash / background-kill). If found,
  /// log recovery and clear the snapshot so a second crash doesn't replay
  /// the recovery path. The messages themselves are already persisted in
  /// SQLite — the snapshot just confirms where we left off.
  Future<void> _checkSnapshotRecovery() async {
    try {
      final repo = ref.read(chatRepoProvider);
      final hasSnapshot = await _hasSessionSnapshot(repo, widget.sessionId);
      if (!hasSnapshot) return;
      debugPrint(
        'Crash recovery: recovered snapshot for session ${widget.sessionId}',
      );
      // Clear the snapshot so a subsequent crash during this session
      // starts fresh instead of re-playing recovery.
      await repo.deleteSessionSnapshot(widget.sessionId);
    } catch (_) {
      // Best-effort — snapshot recovery must never block chat entry.
    }
  }

  /// Convenience: check if a session has a recoverable snapshot.
  Future<bool> _hasSessionSnapshot(
    ChatRepository repo,
    String sessionId,
  ) async {
    final snapshot = await repo.getSessionSnapshot(sessionId);
    return snapshot != null;
  }

  @override
  void dispose() {
    _conversation.interrupt();
    _playbackToken++;
    _guestTimer?.cancel();
    _playerStateSub?.cancel();
    _amplitudeSub?.cancel();
    _thinkingFillerTimer?.cancel();
    _messageController.dispose();
    _scrollController.dispose();
    _messageFocusNode.dispose();
    _recordingService.dispose();
    _ttsPlaybackService.dispose();
    super.dispose();
  }

  /// Ensure the session row exists before any downstream operation
  /// (seeded corrections, messages, etc.) references it. This makes
  /// deep-linking to `/chat/:sessionId` robust and prevents FK errors
  /// when E2E tests seed data for a session that has not been created yet.
  Future<void> _ensureSessionExists() async {
    try {
      final repo = ref.read(chatRepoProvider);
      final existing = await repo.getSession(widget.sessionId);
      if (existing != null) return;
      await repo.createSession(id: widget.sessionId);
    } catch (_) {
      // Best-effort: the chat surface can still render without a session row.
    }
  }

  Future<void> _setupGuestTrialIfNeeded() async {
    try {
      final repo = ref.read(chatRepoProvider);
      final session = await repo.getSession(widget.sessionId);
      if (session == null || !session.isGuest) return;
      final totalSeconds = GuestProfileConfig.guestTrialMinutes * 60;
      if (!mounted) return;
      setState(() {
        _isGuestSession = true;
        _guestSecondsLeft = totalSeconds;
      });
      _guestTimer = Timer.periodic(const Duration(seconds: 1), (t) {
        if (!mounted) {
          t.cancel();
          return;
        }
        setState(() => _guestSecondsLeft -= 1);
        if (_guestSecondsLeft <= 0) {
          t.cancel();
          _endGuestTrial();
        }
      });
    } catch (_) {}
  }

  Future<void> _endGuestTrial() async {
    if (_guestTrialEnded) return;
    _guestTrialEnded = true;
    try {
      _guestTimer?.cancel();
      _ttsPlaybackService.stop();
      if (_isRecording) {
        await _recordingService.cancelRecording();
        _isRecording = false;
      }
      final repo = ref.read(chatRepoProvider);
      final profileRepo = ref.read(profileRepoProvider);
      await repo.archiveSession(widget.sessionId);
      // Restore the user's own profiles that were active before the guest
      // trial started, so the post-trial onboarding doesn't overwrite them.
      final preGuestIds = GuestProfileConfig.lastNonGuestProfileIds;
      if (preGuestIds != null) {
        await profileRepo.restoreNonGuestProfiles(
          llmId: preGuestIds.llmId,
          sttId: preGuestIds.sttId,
          ttsId: preGuestIds.ttsId,
        );
      }
    } catch (_) {}
    if (!mounted) return;
    final l = AppLocalizations.of(context);
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: Text(l.t('guest.trial_ended_title')),
        content: Text(l.t('guest.trial_ended_body')),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(l.t('guest.set_up_keys')),
          ),
        ],
      ),
    );
    if (!mounted) return;
    context.go('/onboarding');
  }

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
    _setCharacterStateWithSemanticState(state);
  }

  void _setCharacterStateWithSemanticState(
    CharacterState state, {
    ConversationState? semanticState,
  }) {
    if (!mounted) return;
    _conversation.transition(
      semanticState ??
          switch (state) {
            CharacterState.idle => ConversationState.idle,
            CharacterState.listening => ConversationState.recording,
            CharacterState.thinking => ConversationState.generating,
            CharacterState.speaking => ConversationState.speaking,
          },
    );
    setState(() {
      _characterState = state;
      if (state == CharacterState.idle) {
        _tutorGesture = TutorGestureCue.idle;
      }
    });
    // E7 — start/stop thinking filler audio loop.
    if (state == CharacterState.thinking) {
      _startThinkingFiller();
    } else {
      _stopThinkingFiller();
    }
  }

  // E7 — use the avatar's thinking animation instead of repeatedly calling
  // TTS while the LLM is pending. This avoids overlapping speech and extra
  // provider cost; Demo uses the same local animation path.
  void _startThinkingFiller() {
    _thinkingFillerTimer?.cancel();
    _thinkingFillerTimer = null;
  }

  void _stopThinkingFiller() {
    _thinkingFillerTimer?.cancel();
    _thinkingFillerTimer = null;
  }

  /// P1 task 5 — update tutor emotion from text content (keyword mapping).
  void _updateEmotionFromText(String text) {
    final emotion = emotionFromText(text);
    if (emotion != _tutorEmotion && mounted) {
      setState(() => _tutorEmotion = emotion);
    }
  }

  /// P1 task 5 — subscribe to TTS amplitude stream to drive emotion.
  void _subscribeAmplitude() {
    _amplitudeSub?.cancel();
    _amplitudeSub = _ttsPlaybackService.amplitudeStream.listen((amp) {
      if (!mounted) return;
      final emotion = emotionFromAmplitude(amp, _tutorEmotion);
      if (emotion != _tutorEmotion) {
        setState(() => _tutorEmotion = emotion);
      }
    });
  }

  /// Phase 3 — lazily resolve the Rhubarb Lip Sync service. Returns null
  /// when the binary isn't installed (or the platform doesn't support
  /// running native binaries, e.g. Flutter Web). The avatar stage falls
  /// back to amplitude-driven mouth opening in that case.
  RhubarbService? _resolveRhubarb() {
    if (_rhubarbProbed) return _rhubarbService;
    _rhubarbProbed = true;
    final svc = RhubarbService();
    if (svc.isAvailable) {
      _rhubarbService = svc;
    }
    return _rhubarbService;
  }

  /// Phase 3 — kick off a Rhubarb Lip Sync analysis on [audioBytes] and
  /// push the resulting viseme timeline to the [AvatarStage] via
  /// [_avatarKey]. Runs async — never blocks TTS playback. Failures are
  /// swallowed because the amplitude fallback path is already running.
  Future<void> _maybeAnalyzeVisemes({
    required String text,
    required Uint8List audioBytes,
    required int playbackToken,
  }) async {
    final svc = _resolveRhubarb();
    if (svc == null) return;
    final audioHash = _ttsPlaybackService.cacheKeyFor(text);
    try {
      final timeline = await svc.analyze(
        audioBytes,
        audioHash: audioHash,
        formatExtension: 'mp3',
      );
      if (!mounted) return;
      // Only push the timeline when we're still speaking the same text —
      // avoids a stale timeline being applied to a newer reply.
      if (_playbackToken == playbackToken && _speakingText == text) {
        _avatarKey.currentState?.setVisemeTimeline(timeline);
      }
    } catch (e) {
      // Best-effort — the avatar stage keeps running on the amplitude
      // fallback path.
      debugPrint('Rhubarb analysis failed: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(messagesProvider(widget.sessionId), (_, _) => _scrollToBottom());

    final sideBySide = Responsive.shouldUseSideBySide(context);
    final hidePanel = Responsive.shouldHideStackedCharacterPanel(context);
    final lowBandwidth = ref.watch(lowBandwidthProvider);
    final dropPanel = hidePanel || lowBandwidth;

    final isLight = Theme.of(context).brightness == Brightness.light;
    return Focus(
      onKeyEvent: _handleKeyEvent,
      child: Scaffold(
        backgroundColor: isLight
            ? AppColors.lightBgPrimary
            : AppColors.bgPrimary,
        appBar: ChatHeader(
          tutorName: _tutorName,
          tutorAvatar: _tutorAvatar,
          characterState: _characterState,
          showStatusDot: dropPanel,
          onBack: _exitWithSummary,
          onPickTutor: () async {
            await context.push('/tutor-selection');
            if (mounted) _loadTutorIdentity();
          },
          onMoreOptions: () => _showSessionOptions(context),
        ),
        resizeToAvoidBottomInset: true,
        body: SafeArea(
          top: false,
          child: sideBySide && !lowBandwidth
              ? Row(
                  children: [
                    _CharacterPanel(
                      state: _characterState,
                      tutorName: _tutorName,
                      tutorAvatar: _tutorAvatar,
                      // The cinematic WebGL teacher is the production path;
                      // AvatarStage keeps the 2D painter as a safety fallback.
                      prefer3d: true,
                      speakingText: _speakingText,
                      emotion: _tutorEmotion,
                      gesture: _tutorGesture,
                      panelWidth: Responsive.sidePanelWidth(context),
                      avatarKey: _avatarKey,
                      amplitudeStream: _ttsPlaybackService.amplitudeStream,
                    ),
                    const VerticalDivider(
                      width: 1,
                      color: AppColors.glassBorder,
                    ),
                    Expanded(child: _chatColumn(context)),
                  ],
                )
              : dropPanel
              ? _chatColumn(context)
              : Column(
                  children: [
                    _CharacterPanel(
                      state: _characterState,
                      tutorName: _tutorName,
                      tutorAvatar: _tutorAvatar,
                      prefer3d: true,
                      speakingText: _speakingText,
                      emotion: _tutorEmotion,
                      gesture: _tutorGesture,
                      panelHeight: Responsive.characterPanelHeight(context),
                      compact: true,
                      avatarKey: _avatarKey,
                      amplitudeStream: _ttsPlaybackService.amplitudeStream,
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
    final isLight = Theme.of(context).brightness == Brightness.light;
    final warningColor = isLight ? AppColors.lightWarning : AppColors.warning;
    return Column(
      children: [
        const RuntimeModeBanner(),
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
                  color: warningColor.withValues(alpha: 0.15),
                  border: Border(
                    bottom: BorderSide(
                      color: warningColor.withValues(alpha: 0.3),
                      width: 0.5,
                    ),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(Icons.mic_off, size: 18, color: warningColor),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Text(
                        l.t('chat.voice_not_configured'),
                        style: Theme.of(
                          context,
                        ).textTheme.bodySmall?.copyWith(color: warningColor),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Icon(Icons.chevron_right, size: 16, color: warningColor),
                  ],
                ),
              ),
            ),
          ),
        if (_isGuestSession && !_guestTrialEnded)
          _GuestTimerBar(secondsLeft: _guestSecondsLeft),
        Expanded(
          child: Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: Responsive.contentMaxWidth(context),
              ),
              child: ChatMessageList(
                sessionId: widget.sessionId,
                scrollController: _scrollController,
                isAiThinking: _isLoading && _streamingText == null,
                playingMessageId: _playingMessageId,
                onPlayTts: _playTts,
                ttsPlaybackService: _ttsPlaybackService,
                streamingText: _streamingText,
                ttsFailedMessageIds: _ttsFailedMessageIds,
                onRetryTts: _retryTts,
                onStartTap: _handleStartTap,
                onSuggestionTap: _handleSuggestionTap,
              ),
            ),
          ),
        ),
        Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: Responsive.contentMaxWidth(context),
            ),
            child: ChatInputBar(
              controller: _messageController,
              focusNode: _messageFocusNode,
              isRecording: _isRecording,
              isLoading: _isLoading,
              continuousMode: _continuousMode,
              onSend: _handleSend,
              onRecordToggle: _handleRecordToggle,
              onToggleContinuous: (v) => setState(() => _continuousMode = v),
              retryHint: _retryHint,
            ),
          ),
        ),
      ],
    );
  }

  /// P1 task 1 + task 3 — send a message with SSE streaming + retry.
  Future<void> _handleSend({bool fromVoice = false}) async {
    final text = _messageController.text.trim();
    if (text.isEmpty || _isLoading) return;
    final l = AppLocalizations.of(context);
    // Sending a new text turn is also an explicit barge-in. This keeps the
    // text and voice paths governed by the same playback cancellation rule.
    if (_playingMessageId != null) await _interruptPlayback();
    final turnToken = _conversation.beginTurn(ConversationState.generating);

    setState(() {
      _isLoading = true;
      _streamingText = '';
    });
    _setCharacterState(CharacterState.thinking);
    _messageController.clear();

    final repo = ref.read(chatRepoProvider);
    final message = ChatMessage(
      sessionId: widget.sessionId,
      role: MessageRole.user,
      content: text,
      audioPath: fromVoice ? 'voice_transcript' : null,
    );
    await repo.saveMessage(message);
    ref.invalidate(messagesProvider(widget.sessionId));

    try {
      final profileRepo = ref.read(profileRepoProvider);

      final history = await repo.getMessages(widget.sessionId);
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
        } catch (_) {}
      }

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

      final llmGateway = ref.read(llmGatewayProvider);

      // P1 task 3 — retry the streaming call with exponential backoff.
      // NOTE: fullContent/correctionsJson are declared in the outer scope so
      // the post-stream code can read them, but they MUST be reset at the top
      // of each retry attempt — otherwise a failed attempt leaves partial
      // text that the retried stream appends to, producing a garbled reply.
      String fullContent = '';
      String? correctionsJson;
      TutorEmotion? semanticEmotion;
      TutorGestureCue? semanticGesture;

      await withRetry(
        () async {
          // Reset accumulated state so a retry starts clean.
          fullContent = '';
          correctionsJson = null;
          semanticEmotion = null;
          semanticGesture = null;
          if (mounted) setState(() => _streamingText = '');
          final stream = llmGateway.streamMessage(
            history: history,
            systemPrompt: systemPrompt,
          );
          await for (final chunk in stream) {
            if (!_conversation.isCurrent(turnToken)) break;
            if (chunk.isDelta && mounted) {
              fullContent += chunk.delta;
              setState(() => _streamingText = fullContent);
            }
            if (chunk.done) {
              correctionsJson = chunk.correctionsJson;
              if (chunk.emotionId != null) {
                semanticEmotion = TutorEmotionX.fromId(chunk.emotionId!);
              }
              if (chunk.gestureId != null) {
                semanticGesture = TutorGestureCueX.fromId(chunk.gestureId!);
              }
            }
          }
        },
        shouldRetry: isTransientRetryable,
        onProgress: (p) {
          if (mounted) {
            setState(
              () => _retryHint = l.tArg('retry.progress', {
                'attempt': p.nextAttempt.toString(),
                'max': p.maxAttempts.toString(),
              }),
            );
          }
        },
      );

      if (mounted) setState(() => _retryHint = null);
      if (!_conversation.isCurrent(turnToken)) return;

      // Clean the streamed content (strip corrections block).
      final cleanedContent = cleanStreamedReply(fullContent);

      // Phase 3 — parse the LLM emotion marker from the pre-strip reply so
      // the avatar expression follows the model's intent precisely, then
      // strip the marker so it never leaks into the saved message, the chat
      // bubble, or TTS speech. `cleanedContent` retains the marker for
      // emotion parsing; `displayContent` is the clean user-facing text.
      final displayContent = stripEmotionMarkers(cleanedContent);

      // Save AI response
      if (!_conversation.isCurrent(turnToken)) return;
      final aiResponse = ChatMessage(
        sessionId: widget.sessionId,
        role: MessageRole.assistant,
        content: displayContent,
      );
      await repo.saveMessage(aiResponse);
      if (!_conversation.isCurrent(turnToken)) return;

      // Parse + save corrections.
      var savedCorrectionCount = 0;
      if (correctionsJson != null) {
        final corrections = llmGateway.extractCorrections(
          '```corrections\n$correctionsJson\n```',
        );
        for (final correction in corrections) {
          if (!_conversation.isCurrent(turnToken)) return;
          final saved = correction.copyWith(
            messageId: message.id,
            sessionId: widget.sessionId,
          );
          await repo.saveCorrectionDedup(saved);
          if (!_conversation.isCurrent(turnToken)) return;
          // P1 task 4 — derive synthetic phoneme scores from pronunciation
          // corrections so the bubble colour-tagging + detail overlay
          // activate end-to-end. See PhonemeScorer for the rationale.
          if (correction.type == CorrectionType.pronunciation) {
            final set = PhonemeScorer.fromCorrection(
              messageId: message.id,
              sessionId: widget.sessionId,
              correction: saved,
              messageText: message.content,
            );
            if (set != null) {
              try {
                await repo.savePhonemeScores(set);
              } catch (_) {
                // Non-fatal: phoneme scores are a UX enhancement, not a
                // correctness requirement. Don't fail the turn over them.
              }
            }
          }
        }
        savedCorrectionCount = corrections.length;
      }

      // Brief success feedback so the user notices corrections were saved.
      if (mounted && savedCorrectionCount > 0) {
        final feedbackL = AppLocalizations.of(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.check_circle,
                  color: AppColors.success,
                  size: 18,
                ),
                const SizedBox(width: AppSpacing.sm),
                Text(
                  feedbackL.tArg('chat.corrections_saved', {
                    'count': savedCorrectionCount.toString(),
                  }),
                ),
              ],
            ),
            duration: const Duration(seconds: 2),
            backgroundColor: AppColors.bgTertiary,
          ),
        );
      }

      // P1 task 5 — update tutor emotion from the AI reply text. Uses the
      // pre-strip `cleanedContent` so an explicit `[emotion:id]` marker
      // (Phase 3) wins over keyword matching.
      if (mounted) {
        setState(() {
          _tutorEmotion = semanticEmotion ?? emotionFromText(cleanedContent);
          _tutorGesture = semanticGesture ?? gestureFromText(cleanedContent);
        });
      }

      ref.invalidate(messagesProvider(widget.sessionId));
      ref.invalidate(correctionsByMessageProvider(widget.sessionId));
      ref.invalidate(phonemeScoresProvider(widget.sessionId));

      if (mounted) {
        setState(() {
          _isLoading = false;
          _streamingText = null;
        });
      }

      _conversation.transition(ConversationState.synthesizing);
      // Auto-play TTS for the full AI reply. Uses the marker-stripped
      // `displayContent` so the TTS engine never speaks the marker aloud.
      _autoplayTts(aiResponse.id, displayContent);
    } on GatewayConfigurationException catch (e) {
      if (mounted && _conversation.isCurrent(turnToken)) {
        final service = e.service.toLowerCase();
        if (service == 'llm') {
          final l = AppLocalizations.of(context);
          _showConfigNeeded(
            l.t('chat.config_needed_llm_title'),
            l.t('chat.config_needed_llm_body'),
          );
        } else {
          _showAppError(e);
        }
        _conversation.transition(ConversationState.recoverableError);
      }
    } on RetryExhausted catch (e) {
      if (mounted && _conversation.isCurrent(turnToken)) {
        setState(() {
          _isLoading = false;
          _streamingText = null;
          _retryHint = null;
        });
        _conversation.transition(ConversationState.recoverableError);
        _showAppError(e.lastError);
      }
    } catch (e) {
      if (mounted && _conversation.isCurrent(turnToken)) {
        setState(() {
          _isLoading = false;
          _streamingText = null;
          _retryHint = null;
        });
        _conversation.transition(ConversationState.recoverableError);
        _showAppError(e);
      }
    } finally {
      if (mounted && _conversation.isCurrent(turnToken)) {
        setState(() => _isLoading = false);
        if (_characterState == CharacterState.thinking) {
          final semanticState = switch (_conversation.state) {
            ConversationState.recoverableError =>
              ConversationState.recoverableError,
            ConversationState.fatalError => ConversationState.fatalError,
            ConversationState.interrupted => ConversationState.interrupted,
            ConversationState.synthesizing => ConversationState.synthesizing,
            _ => ConversationState.idle,
          };
          _setCharacterStateWithSemanticState(
            CharacterState.idle,
            semanticState: semanticState,
          );
        }
      }
    }
  }

  Future<void> _handleStartTap() async {
    if (!_voiceConfigured) {
      if (mounted) await context.push('/service-config');
      return;
    }
    await _handleRecordToggle();
  }

  Future<void> _handleSuggestionTap(String text) async {
    if (_isLoading) return;
    _messageController.text = text;
    await _handleSend();
  }

  Future<void> _handleRecordToggle() async {
    // The primary voice control is also the barge-in control: a user can
    // stop the tutor immediately before starting the next recording.
    if (_playingMessageId != null) {
      await _interruptPlayback();
      return;
    }
    if (_isLoading) {
      await _interruptActiveTurn();
      return;
    }

    if (_isRecording) {
      final transcribeToken = _conversation.beginTurn(
        ConversationState.transcribing,
      );
      final l = AppLocalizations.of(context);
      setState(() => _isRecording = false);
      _setCharacterStateWithSemanticState(
        CharacterState.thinking,
        semanticState: ConversationState.transcribing,
      );

      try {
        final audioData = await _recordingService.stopRecording();
        if (!_conversation.isCurrent(transcribeToken)) return;
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

        final sttGateway = ref.read(sttGatewayProvider);

        // P1 task 3 — retry STT with exponential backoff.
        String transcribedText;
        try {
          transcribedText = await withRetry(
            () => sttGateway.transcribe(audioData),
            shouldRetry: isTransientRetryable,
            onProgress: (p) {
              if (mounted) {
                setState(
                  () => _retryHint = l.tArg('retry.progress', {
                    'attempt': p.nextAttempt.toString(),
                    'max': p.maxAttempts.toString(),
                  }),
                );
              }
            },
          );
        } on RetryExhausted catch (e) {
          if (mounted && _conversation.isCurrent(transcribeToken)) {
            setState(() => _retryHint = null);
            _showAppError(e.lastError);
            _setCharacterStateWithSemanticState(
              CharacterState.idle,
              semanticState: ConversationState.recoverableError,
            );
          }
          return;
        }

        if (!_conversation.isCurrent(transcribeToken)) return;
        if (mounted) setState(() => _retryHint = null);

        if (transcribedText.isNotEmpty) {
          _messageController.text = transcribedText;
          if (mounted) _messageFocusNode.requestFocus();
          await _handleSend(fromVoice: true);
        } else if (mounted) {
          final l = AppLocalizations.of(context);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(l.t('chat.transcribe_empty_hint'))),
          );
          _setCharacterState(CharacterState.idle);
        }
      } on GatewayConfigurationException catch (_) {
        if (mounted && _conversation.isCurrent(transcribeToken)) {
          final l = AppLocalizations.of(context);
          _showConfigNeeded(
            l.t('chat.config_needed_stt_title'),
            l.t('chat.config_needed_stt_body'),
          );
          _setCharacterStateWithSemanticState(
            CharacterState.idle,
            semanticState: ConversationState.recoverableError,
          );
        }
      } catch (e) {
        if (mounted && _conversation.isCurrent(transcribeToken)) {
          setState(() => _retryHint = null);
          _showAppError(e);
          _setCharacterStateWithSemanticState(
            CharacterState.idle,
            semanticState: ConversationState.recoverableError,
          );
        }
      }
    } else {
      if (_conversation.isBusy) {
        await _interruptActiveTurn();
        return;
      }
      // Start recording.
      // E9/E10 — backchanneling: show a "listening" nod while the user speaks.
      _conversation.beginTurn(ConversationState.recording);
      setState(() {
        _isRecording = true;
        _tutorEmotion = TutorEmotion.encouraging;
      });
      _setCharacterState(CharacterState.listening);
      try {
        await _recordingService.startRecording();
      } catch (e) {
        if (mounted) {
          setState(() => _isRecording = false);
          _showAppError(e);
          _setCharacterStateWithSemanticState(
            CharacterState.idle,
            semanticState: ConversationState.permissionRequired,
          );
        }
      }
    }
  }

  Future<void> _interruptPlayback() async {
    _conversation.interrupt();
    _playbackToken++;
    await _ttsPlaybackService.stop();
    await _playerStateSub?.cancel();
    _playerStateSub = null;
    _amplitudeSub?.cancel();
    _amplitudeSub = null;
    _avatarKey.currentState?.clearVisemeTimeline();
    if (!mounted) return;
    setState(() {
      _playingMessageId = null;
      _speakingText = null;
    });
    _setCharacterStateWithSemanticState(
      CharacterState.idle,
      semanticState: ConversationState.interrupted,
    );
  }

  /// Cancels an in-flight recording/STT/LLM turn. The monotonically
  /// increasing token invalidates late stream callbacks, while the UI is
  /// reset immediately so the next user action can start a fresh turn.
  Future<void> _interruptActiveTurn() async {
    await _interruptPlayback();
    if (!mounted) return;
    setState(() {
      _isLoading = false;
      _isRecording = false;
      _streamingText = null;
      _retryHint = null;
    });
  }

  Future<void> _autoplayTts(String messageId, String text) async {
    final playbackToken = ++_playbackToken;
    try {
      final ttsGateway = ref.read(ttsGatewayProvider);
      if (!mounted || playbackToken != _playbackToken) return;

      _setCharacterState(CharacterState.speaking);
      if (mounted) {
        setState(() {
          _playingMessageId = messageId;
          _speakingText = text;
        });
      }

      _attachPlayerStateListener(messageId, playbackToken);
      _subscribeAmplitude();

      if (!mounted || playbackToken != _playbackToken) return;
      final bytes = await _ttsPlaybackService.playCached(
        text,
        () => ttsGateway.synthesize(text),
        waitForCompletion: false,
      );
      if (!mounted || playbackToken != _playbackToken) return;
      _avatarKey.currentState?.setSpeechAudio(
        bytes,
        startedAt: _ttsPlaybackService.lastPlaybackStartedAt,
      );
      final simulationVisemes = ttsGateway.visemesFor(text);
      if (simulationVisemes != null &&
          mounted &&
          playbackToken == _playbackToken) {
        _avatarKey.currentState?.setVisemeTimeline(simulationVisemes);
      }
      // Phase 3 — analyse the just-played audio with Rhubarb and push the
      // timeline into the avatar stage. Runs in the background; the stage
      // falls back to amplitude-driven motion until the timeline lands.
      unawaited(
        _maybeAnalyzeVisemes(
          text: text,
          audioBytes: bytes,
          playbackToken: playbackToken,
        ),
      );
    } catch (e) {
      debugPrint('Auto TTS failed: $e');
      if (mounted && playbackToken == _playbackToken) {
        if (e.toString().contains('not configured')) {
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
        _avatarKey.currentState?.clearVisemeTimeline();
        if (_characterState == CharacterState.speaking) {
          _setCharacterStateWithSemanticState(
            CharacterState.idle,
            semanticState: ConversationState.recoverableError,
          );
        }
      }
    }
  }

  Future<void> _playTts(String messageId, String text) async {
    if (_playingMessageId == messageId) {
      await _interruptPlayback();
      return;
    }

    final playbackToken = ++_playbackToken;
    try {
      setState(() {
        _playingMessageId = messageId;
        _speakingText = text;
        _ttsFailedMessageIds.remove(messageId);
      });
      _setCharacterState(CharacterState.speaking);

      if (!mounted || playbackToken != _playbackToken) return;

      final ttsGateway = ref.read(ttsGatewayProvider);

      _attachPlayerStateListener(messageId, playbackToken);
      _subscribeAmplitude();
      _updateEmotionFromText(text);
      if (mounted) setState(() => _tutorGesture = gestureFromText(text));

      // P1 task 3 — retry TTS with exponential backoff.
      final l = AppLocalizations.of(context);
      try {
        final bytes = await withRetry(
          () => _ttsPlaybackService.playCached(
            text,
            () => ttsGateway.synthesize(text),
            waitForCompletion: false,
          ),
          shouldRetry: isTransientRetryable,
          onProgress: (p) {
            if (mounted) {
              setState(
                () => _retryHint = l.tArg('retry.progress', {
                  'attempt': p.nextAttempt.toString(),
                  'max': p.maxAttempts.toString(),
                }),
              );
            }
          },
        );
        if (mounted) setState(() => _retryHint = null);
        if (!mounted || playbackToken != _playbackToken) return;
        _avatarKey.currentState?.setSpeechAudio(
          bytes,
          startedAt: _ttsPlaybackService.lastPlaybackStartedAt,
        );
        final simulationVisemes = ttsGateway.visemesFor(text);
        if (simulationVisemes != null) {
          _avatarKey.currentState?.setVisemeTimeline(simulationVisemes);
        }
        // Phase 3 — Rhubarb viseme analysis runs after playback started so
        // it doesn't delay the retry loop. Best-effort.
        unawaited(
          _maybeAnalyzeVisemes(
            text: text,
            audioBytes: bytes,
            playbackToken: playbackToken,
          ),
        );
      } on RetryExhausted catch (e) {
        if (mounted && playbackToken == _playbackToken) {
          setState(() {
            _retryHint = null;
            _ttsFailedMessageIds.add(messageId);
            _playingMessageId = null;
            _speakingText = null;
          });
          _avatarKey.currentState?.clearVisemeTimeline();
          _setCharacterStateWithSemanticState(
            CharacterState.idle,
            semanticState: ConversationState.recoverableError,
          );
          _showAppError(e.lastError);
        }
      }
    } on GatewayConfigurationException catch (_) {
      if (mounted && playbackToken == _playbackToken) {
        final l = AppLocalizations.of(context);
        _showConfigNeeded(
          l.t('chat.config_needed_tts_title'),
          l.t('chat.config_needed_tts_body'),
        );
        setState(() {
          _playingMessageId = null;
          _speakingText = null;
        });
        _setCharacterStateWithSemanticState(
          CharacterState.idle,
          semanticState: ConversationState.recoverableError,
        );
      }
    } catch (e) {
      if (mounted && playbackToken == _playbackToken) {
        if (e.toString().contains('not configured')) {
          final l = AppLocalizations.of(context);
          _showConfigNeeded(
            l.t('chat.config_needed_tts_title'),
            l.t('chat.config_needed_tts_body'),
          );
        } else {
          _showAppError(e);
        }
        setState(() {
          _playingMessageId = null;
          _speakingText = null;
        });
        _avatarKey.currentState?.clearVisemeTimeline();
        _setCharacterStateWithSemanticState(
          CharacterState.idle,
          semanticState: ConversationState.recoverableError,
        );
      }
    }
  }

  /// E14 — retry TTS for a failed message.
  Future<void> _retryTts(String messageId, String text) async {
    _ttsFailedMessageIds.remove(messageId);
    await _playTts(messageId, text);
  }

  void _attachPlayerStateListener(String messageId, int playbackToken) {
    _playerStateSub?.cancel();
    _playerStateSub = _ttsPlaybackService.player.playerStateStream.listen((
      state,
    ) {
      if (state.processingState == ProcessingState.completed) {
        if (!mounted || playbackToken != _playbackToken) return;
        setState(() {
          _playingMessageId = null;
          _speakingText = null;
        });
        // Phase 3 — drop any active Rhubarb timeline so the avatar mouth
        // returns to idle.
        _avatarKey.currentState?.clearVisemeTimeline();
        if (_characterState == CharacterState.speaking) {
          _setCharacterStateWithSemanticState(
            CharacterState.idle,
            semanticState: ConversationState.completed,
          );
        }
        _amplitudeSub?.cancel();
        // E1: in continuous mode, auto-rearm the mic after the AI finishes.
        if (_continuousMode && !_isRecording && !_isLoading) {
          _handleRecordToggle();
        }
      }
    });
  }

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
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      elevation: 0,
      builder: (context) => GlassBottomSheet(
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
                Navigator.pop(context);
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
                        style: TextButton.styleFrom(
                          foregroundColor: AppColors.error,
                        ),
                        onPressed: () => Navigator.pop(ctx, true),
                        child: Text(l.t('common.delete')),
                      ),
                    ],
                  ),
                );
                if (confirmed != true || !mounted) return;
                try {
                  await ref
                      .read(chatRepoProvider)
                      .deleteSession(widget.sessionId);
                  if (context.mounted) {
                    final ll = AppLocalizations.of(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(ll.t('chat.deleted'))),
                    );
                    context.go('/');
                  }
                } catch (e) {
                  if (context.mounted) {
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
              break;
            case AppErrorAction.openSettings:
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

  Future<void> _exitWithSummary() async {
    try {
      if (_isGuestSession) {
        if (mounted) context.go('/');
        return;
      }
      final repo = ref.read(chatRepoProvider);
      final messages = await repo.getMessages(widget.sessionId);
      if (messages.length < 2) {
        if (mounted) context.go('/');
        return;
      }
      if (mounted) context.go('/summary/${widget.sessionId}');
    } catch (_) {
      if (mounted) context.go('/');
    }
  }
}

// ── Character panel (stays here — tightly coupled to screen state) ──────────

class _CharacterPanel extends StatelessWidget {
  final CharacterState state;
  final String tutorName;
  final String tutorAvatar;
  final String? speakingText;
  final double? panelWidth;
  final double? panelHeight;
  final bool compact;
  final bool prefer3d;

  /// P1 task 5 — emotion drives a subtle accent color shift on the panel.
  final TutorEmotion emotion;
  final TutorGestureCue gesture;

  /// Phase 3 — key into the avatar stage so the panel can pass through the
  /// parent screen's [AvatarStage] key (used by the screen to push Rhubarb
  /// viseme timelines into the live widget).
  final GlobalKey<AvatarStageState>? avatarKey;

  /// Phase 3 — TTS amplitude stream forwarded into the [AvatarStage] so the
  /// amplitude-driven mouth open fallback works without the screen having
  /// to push each sample manually.
  final Stream<double>? amplitudeStream;

  const _CharacterPanel({
    required this.state,
    required this.tutorName,
    required this.tutorAvatar,
    this.speakingText,
    this.panelWidth,
    this.panelHeight,
    this.compact = false,
    this.prefer3d = false,
    this.emotion = TutorEmotion.neutral,
    this.gesture = TutorGestureCue.idle,
    this.avatarKey,
    this.amplitudeStream,
  });

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
    final child = AvatarStage(
      key: avatarKey,
      tutorName: tutorName,
      tutorAvatar: tutorAvatar,
      phase: AvatarPhase.fromCharacterState(state),
      emotion: emotion,
      gesture: gesture,
      speakingText: speakingText,
      amplitudeStream: amplitudeStream,
      prefer3d: prefer3d,
      panelWidth: panelWidth,
      panelHeight: panelHeight,
    );

    final labelled = Semantics(
      liveRegion: true,
      label: _stateLabel(context, state),
      child: child,
    );

    if (compact) {
      return Container(
        height: panelHeight,
        margin: const EdgeInsets.fromLTRB(
          AppSpacing.sm,
          AppSpacing.xs,
          AppSpacing.sm,
          AppSpacing.xs,
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(AppRadius.xl),
          child: Stack(
            fit: StackFit.expand,
            children: [
              Positioned.fill(child: labelled),
              Positioned(
                top: AppSpacing.md,
                right: AppSpacing.sm,
                child: Column(
                  children: const [
                    _StageIcon(icon: Icons.settings_outlined),
                    SizedBox(height: AppSpacing.xs),
                    _StageIcon(icon: Icons.volume_up_outlined),
                    SizedBox(height: AppSpacing.xs),
                    _StageIcon(icon: Icons.keyboard_arrow_up_rounded),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Container(
      width: panelWidth,
      margin: const EdgeInsets.all(AppSpacing.md),
      child: GlassCard(
        glowColor: AppColors.accentPrimary,
        padding: EdgeInsets.zero,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(AppRadius.xl),
          child: labelled,
        ),
      ),
    );
  }
}

class _StageIcon extends StatelessWidget {
  final IconData icon;
  const _StageIcon({required this.icon});
  @override
  Widget build(BuildContext context) => Container(
    width: 36,
    height: 36,
    decoration: BoxDecoration(
      color: Colors.white.withValues(alpha: 0.76),
      shape: BoxShape.circle,
      border: Border.all(color: Colors.white),
    ),
    child: Icon(icon, size: 20, color: AppColors.lightTextPrimary),
  );
}

// Phase 3 — the legacy `_TutorLive2DPortrait` / `_TutorStageStatus` /
// `_TutorMouthOverlay` classes that previously rendered the placeholder
// image + discrete viseme overlay were replaced by the unified
// [AvatarStage] widget (see `lib/features/avatar/presentation/widgets/`).
// Their behaviour is preserved inside AvatarStage's fallback renderer, so
// the user-visible mouth motion stays the same — but now it composes with
// the idle + emotion + Rhubarb viseme timeline controllers.

/// Guest trial countdown banner.
///
/// Extracted from the chat screen as a lightweight widget so the 1-second
/// timer only rebuilds this banner instead of triggering `setState` on the
/// entire chat screen tree (~200+ widgets) every second.
class _GuestTimerBar extends StatelessWidget {
  final int secondsLeft;

  const _GuestTimerBar({required this.secondsLeft});

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final urgent = secondsLeft <= 30;
    final color = urgent ? AppColors.error : AppColors.accentSecondary;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.xs,
      ),
      color: color.withValues(alpha: 0.18),
      child: Row(
        children: [
          Icon(Icons.timer_outlined, size: 16, color: color),
          const SizedBox(width: AppSpacing.xs),
          Expanded(
            child: Text(
              l.tArg('guest.minutes_left', {
                'min': (secondsLeft ~/ 60).toString(),
                'sec': (secondsLeft % 60).toString().padLeft(2, '0'),
              }),
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: color,
                fontWeight: FontWeight.w600,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}
