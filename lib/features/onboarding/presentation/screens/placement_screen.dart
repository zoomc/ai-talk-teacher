import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/i18n/app_localizations.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/util/retry.dart';
import '../../../../core/util/responsive.dart';
import '../../../../shared/widgets/glass_widgets.dart';
import '../../../../shared/providers.dart';
import '../../../chat/data/llm_service.dart';
import '../../../chat/data/llm_streaming.dart';
import '../../../chat/data/recording_service.dart';
import '../../../chat/data/stt_service.dart';
import '../../../chat/domain/chat_models.dart';
import '../../domain/placement_result.dart';
import '../widgets/placement_radar_chart.dart';

/// P1 task 6 — AI-driven placement assessment.
///
/// Replaces the previous static self-assessment quiz with a 5-turn voice/text
/// conversation against the active LLM. After the 5th turn the model is asked
/// to emit a strict-JSON verdict covering:
///   * five-dim scores (vocab / fluency / grammar / pronunciation / confidence)
///   * an overall level: beginner | intermediate | advanced
///   * a personalised 4-week learning path
///
/// The result is rendered as a radar chart + week-by-week plan, then
/// persisted via [ProfileRepository.setUserLevel] +
/// [ProfileRepository.setLearningPath] + [ProfileRepository.setPlacementCompleted].
///
/// Fallbacks:
///   * If no LLM profile is configured, fall back to the legacy 4-question
///     self-assessment quiz (kept in [_LegacyQuiz]) so first-run isn't blocked
///     behind service configuration.
///   * On LLM/STT failure (after retry exhaustion) the user can still skip
///     placement and configure providers later.
class PlacementScreen extends ConsumerStatefulWidget {
  const PlacementScreen({super.key});

  @override
  ConsumerState<PlacementScreen> createState() => _PlacementScreenState();
}

class _PlacementScreenState extends ConsumerState<PlacementScreen> {
  _PlacementPhase _phase = _PlacementPhase.intro;

  // Conversation state.
  final List<ChatMessage> _history = [];
  final TextEditingController _textController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final RecordingService _recordingService = RecordingService();
  bool _isRecording = false;
  bool _isAiThinking = false;
  String? _streamingText;
  String? _retryHint;
  String? _errorMessage;
  int _currentTurn = 0; // 0..5; 5 means the AI verdict turn is in flight.

  static const int _kTotalTurns = 5;

  // Result.
  PlacementResult? _result;

  AppLocalizations get _l => AppLocalizations.of(context);

  @override
  void dispose() {
    _textController.dispose();
    _scrollController.dispose();
    _recordingService.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
      );
    });
  }

  // ── Phase transitions ───────────────────────────────────────────────

  Future<void> _startAiAssessment() async {
    final profileRepo = ref.read(profileRepoProvider);
    final llmProfile = await profileRepo.getActiveLlmProfile();
    if (llmProfile == null) {
      // No LLM configured — fall back to the legacy quiz so first-run
      // isn't blocked. The user can re-take placement from settings once
      // they've configured a provider.
      if (mounted) {
        setState(() => _phase = _PlacementPhase.legacyQuiz);
      }
      return;
    }
    if (mounted) {
      setState(() => _phase = _PlacementPhase.chat);
    }
    // Kick off the first AI turn.
    await _sendUserTurn('__intro__', isIntro: true);
  }

  /// Send one user turn (or the intro signal) and stream the AI reply.
  Future<void> _sendUserTurn(String text, {bool isIntro = false}) async {
    if (_isAiThinking) return;

    setState(() {
      _isAiThinking = true;
      _streamingText = '';
      _errorMessage = null;
      _retryHint = null;
    });

    if (!isIntro && text.trim().isNotEmpty) {
      _history.add(ChatMessage(
        sessionId: 'placement',
        role: MessageRole.user,
        content: text,
      ));
      _scrollToBottom();
    }

    final profileRepo = ref.read(profileRepoProvider);
    final llmProfile = await profileRepo.getActiveLlmProfile();
    if (llmProfile == null) {
      if (mounted) {
        setState(() {
          _isAiThinking = false;
          _errorMessage = _l.t('placement.error_no_llm');
        });
      }
      return;
    }

    final llmService = LlmService(llmProfile);
    final isFinalTurn = _currentTurn + 1 >= _kTotalTurns;
    final systemPrompt = _buildSystemPrompt(isFinalTurn: isFinalTurn);

    String fullContent = '';
    final l = _l;

    try {
      await withRetry(
        () async {
          // Reset accumulated state so a retry starts clean (mirrors
          // chat_screen.dart — otherwise partial text from a failed
          // attempt corrupts the retried reply + placement verdict).
          fullContent = '';
          if (mounted) setState(() => _streamingText = '');
          final stream = llmService.streamMessage(
            history: _history,
            systemPrompt: systemPrompt,
          );
          await for (final chunk in stream) {
            if (chunk.isDelta && mounted) {
              fullContent += chunk.delta;
              setState(() => _streamingText = fullContent);
            }
            // The final-turn JSON verdict is parsed by _finalizeResult
            // from the accumulated reply, not from chunk.done.
          }
        },
        shouldRetry: isTransientRetryable,
        onProgress: (p) {
          if (mounted) {
            setState(() => _retryHint = l.tArg('retry.progress', {
                  'attempt': p.nextAttempt.toString(),
                  'max': p.maxAttempts.toString(),
                }));
          }
        },
      );

      // Clean + persist AI reply.
      final cleaned = cleanStreamedReply(fullContent);
      _history.add(ChatMessage(
        sessionId: 'placement',
        role: MessageRole.assistant,
        content: cleaned,
      ));
      _scrollToBottom();

      if (mounted) {
        setState(() {
          _isAiThinking = false;
          _streamingText = null;
          _retryHint = null;
          _currentTurn += 1;
        });
      }

      // On the final turn, parse the JSON verdict.
      if (isFinalTurn) {
        await _finalizeResult(cleaned);
      }
    } on RetryExhausted catch (e) {
      if (mounted) {
        setState(() {
          _isAiThinking = false;
          _streamingText = null;
          _retryHint = null;
          _errorMessage = l.tArg('retry.exhausted_body', {
            'max': kRetryMaxAttempts.toString(),
            'reason': e.lastError.toString(),
          });
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isAiThinking = false;
          _streamingText = null;
          _retryHint = null;
          _errorMessage = e.toString();
        });
      }
    }
  }

  /// Build the placement system prompt. On the final turn the prompt asks
  /// the model to emit the strict-JSON verdict; on earlier turns it asks
  /// for a short conversational reply.
  String _buildSystemPrompt({required bool isFinalTurn}) {
    final base = '''
You are SpeakFlow's English placement tutor. Your job is to assess the \
learner's spoken English across 5 short turns.

Conversation rules:
- Keep each reply to 1–3 sentences.
- Be warm and encouraging.
- Adjust difficulty naturally to probe the learner's level: start easy, then \
introduce slightly more complex vocabulary or grammar if the learner seems \
strong.
- Stay in English; do not translate.''';

    if (!isFinalTurn) {
      return base;
    }

    return '''$base

This is the FINAL turn. After your natural-language reply, emit a STRICT JSON \
verdict inside a ```placement``` fence with EXACTLY this shape:

```placement
{
  "vocabulary": <0-100 int>,
  "fluency": <0-100 int>,
  "grammar": <0-100 int>,
  "pronunciation": <0-100 int>,
  "confidence": <0-100 int>,
  "level": "beginner" | "intermediate" | "advanced",
  "path": [
    {"week": 1, "focus": "<short focus theme>", "tasks": ["task 1", "task 2", "task 3"]},
    {"week": 2, "focus": "...", "tasks": ["...","...","..."]},
    {"week": 3, "focus": "...", "tasks": ["...","...","..."]},
    {"week": 4, "focus": "...", "tasks": ["...","...","..."]}
  ]
}
```

Score each dimension 0–100 based on what you observed. The `path` must contain \
exactly 4 weeks, each with 2–3 concrete tasks tailored to the learner's \
weakest dimensions. Return ONLY the JSON inside the fence.''';
  }

  /// Parse the final-turn reply, extract the ```placement``` JSON, build the
  /// [PlacementResult], persist it, and switch to the result phase.
  Future<void> _finalizeResult(String reply) async {
    final jsonStr = _extractPlacementJson(reply);
    if (jsonStr == null) {
      if (mounted) {
        setState(() {
          _errorMessage = _l.t('placement.error_failed');
        });
      }
      return;
    }
    try {
      final decoded = jsonDecode(jsonStr) as Map<String, dynamic>;
      final result = PlacementResult.fromMap(decoded);
      final profileRepo = ref.read(profileRepoProvider);
      await profileRepo.setUserLevel(result.level);
      await profileRepo.setLearningPath(jsonEncode(result.toMap()));
      await profileRepo.setPlacementCompleted();
      if (mounted) {
        setState(() {
          _result = result;
          _phase = _PlacementPhase.result;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = _l.t('placement.error_failed');
        });
      }
    }
  }

  /// Pull the trailing ```placement\n...\n``` JSON block out of the reply.
  String? _extractPlacementJson(String content) {
    final regex = RegExp(r'```placement\s*\n([\s\S]*?)\n```');
    final match = regex.firstMatch(content);
    return match?.group(1);
  }

  // ── Voice input ─────────────────────────────────────────────────────

  Future<void> _handleRecordToggle() async {
    if (_isAiThinking) return;

    if (_isRecording) {
      setState(() => _isRecording = false);
      try {
        final audio = await _recordingService.stopRecording();
        if (audio == null || audio.isEmpty) return;
        await _transcribeAndSend(audio);
      } catch (e) {
        if (mounted) {
          setState(() => _errorMessage = e.toString());
        }
      }
    } else {
      try {
        await _recordingService.startRecording();
        if (mounted) setState(() => _isRecording = true);
      } catch (e) {
        if (mounted) {
          setState(() => _errorMessage = e.toString());
        }
      }
    }
  }

  Future<void> _transcribeAndSend(Uint8List audio) async {
    final profileRepo = ref.read(profileRepoProvider);
    final sttProfile = await profileRepo.getActiveSttProfile();
    if (sttProfile == null) {
      // No STT — fall back to typed input.
      if (mounted) {
        setState(() => _errorMessage = _l.t('placement.error_no_llm'));
      }
      return;
    }
    final stt = SttService(sttProfile);
    final l = _l;
    try {
      final text = await withRetry(
        () => stt.transcribe(audio),
        shouldRetry: isTransientRetryable,
        onProgress: (p) {
          if (mounted) {
            setState(() => _retryHint = l.tArg('retry.progress', {
                  'attempt': p.nextAttempt.toString(),
                  'max': p.maxAttempts.toString(),
                }));
          }
        },
      );
      if (text.trim().isEmpty) return;
      await _sendUserTurn(text);
    } on RetryExhausted catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = l.tArg('retry.exhausted_body', {
            'max': kRetryMaxAttempts.toString(),
            'reason': e.lastError.toString(),
          });
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _errorMessage = e.toString());
      }
    }
  }

  // ── Skip / finish ───────────────────────────────────────────────────

  Future<void> _skip() async {
    final profileRepo = ref.read(profileRepoProvider);
    try {
      // Default to 'beginner' so downstream screens (chat scenario picker,
      // tutor prompt builder) get a usable level. Without this, skip would
      // leave user_level unset and TutorPromptBuilder would receive null.
      final existing = await profileRepo.getUserLevel();
      if (existing == null || existing.isEmpty) {
        await profileRepo.setUserLevel('beginner');
      }
      await profileRepo.setPlacementCompleted();
    } catch (_) {}
    if (mounted) context.go('/');
  }

  Future<void> _finishAndGoHome() async {
    if (mounted) context.go('/');
  }

  // ── Build ───────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final isLight = Theme.of(context).brightness == Brightness.light;
    return Scaffold(
      backgroundColor:
          isLight ? AppColors.lightBgPrimary : AppColors.bgPrimary,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: Responsive.contentMaxWidth(context),
            ),
            child: switch (_phase) {
              _PlacementPhase.intro => _buildIntro(),
              _PlacementPhase.chat => _buildChat(),
              _PlacementPhase.result => _buildResult(),
              _PlacementPhase.legacyQuiz => _LegacyQuiz(
                onCompleted: () => context.go('/'),
                onSkipped: _skip,
              ),
            },
          ),
        ),
      ),
    );
  }

  // ── Intro ───────────────────────────────────────────────────────────

  Widget _buildIntro() {
    final l = _l;
    final isLight = Theme.of(context).brightness == Brightness.light;
    final headingColor =
        isLight ? AppColors.lightTextPrimary : AppColors.textPrimary;
    final bodyColor =
        isLight ? AppColors.lightTextSecondary : AppColors.textSecondary;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: _skip,
              child: Text(l.t('placement.skip')),
            ),
          ),
          const SizedBox(height: AppSpacing.xxl),
          Text(
            l.t('placement.ai_title'),
            style: Theme.of(context).textTheme.displayLarge?.copyWith(
                  color: headingColor,
                ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            l.t('placement.ai_subtitle'),
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: bodyColor,
                ),
          ),
          const SizedBox(height: AppSpacing.xxl),
          FilledButton.icon(
            onPressed: _startAiAssessment,
            icon: const Icon(Icons.mic),
            label: Text(l.t('common.start')),
            style: FilledButton.styleFrom(
              minimumSize: const Size(double.infinity, 56),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          OutlinedButton(
            onPressed: _skip,
            style: OutlinedButton.styleFrom(
              minimumSize: const Size(double.infinity, 48),
            ),
            child: Text(l.t('placement.skip')),
          ),
        ],
      ),
    );
  }

  // ── Chat ────────────────────────────────────────────────────────────

  Widget _buildChat() {
    final l = _l;
    final isLight = Theme.of(context).brightness == Brightness.light;
    final headingColor =
        isLight ? AppColors.lightTextPrimary : AppColors.textPrimary;
    return Column(
      children: [
        // Header
        Padding(
          padding: const EdgeInsets.fromLTRB(
              AppSpacing.md, AppSpacing.md, AppSpacing.md, AppSpacing.xs),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  l.tArg('placement.turn', {
                    'n': (_currentTurn + 1).clamp(1, _kTotalTurns).toString(),
                    'total': _kTotalTurns.toString(),
                  }),
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: headingColor,
                        fontWeight: FontWeight.w600,
                      ),
                ),
              ),
              TextButton(
                onPressed: _skip,
                child: Text(l.t('placement.skip_to_chat')),
              ),
            ],
          ),
        ),
        // Progress
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
          child: Row(
            children: List.generate(_kTotalTurns, (i) {
              return Expanded(
                child: Container(
                  height: 4,
                  margin: const EdgeInsets.symmetric(horizontal: 2),
                  decoration: BoxDecoration(
                    color: i < _currentTurn
                        ? AppColors.accentPrimary
                        : (i == _currentTurn
                            ? AppColors.accentPrimary.withValues(alpha: 0.5)
                            : AppColors.glassBorder),
                    borderRadius: BorderRadius.circular(AppRadius.xs),
                  ),
                ),
              );
            }),
          ),
        ),
        // Transcript
        Expanded(
          child: ListView.builder(
            controller: _scrollController,
            padding: const EdgeInsets.all(AppSpacing.md),
            itemCount: _history.length + (_streamingText != null ? 1 : 0),
            itemBuilder: (context, i) {
              if (i < _history.length) {
                final m = _history[i];
                return _PlacementBubble(
                  text: m.content,
                  isUser: m.role == MessageRole.user,
                );
              }
              return _PlacementBubble(
                text: _streamingText ?? '',
                isUser: false,
                isStreaming: true,
              );
            },
          ),
        ),
        if (_retryHint != null || _errorMessage != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(
                AppSpacing.md, 0, AppSpacing.md, AppSpacing.xs),
            child: Text(
              _errorMessage ?? _retryHint ?? '',
              style: TextStyle(
                color: _errorMessage != null
                    ? AppColors.error
                    : AppColors.warning,
                fontSize: 12,
              ),
            ),
          ),
        _buildInputBar(),
      ],
    );
  }

  Widget _buildInputBar() {
    final l = _l;
    final hasStt = true; // best-effort; failure surfaces inline
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Row(
          children: [
            if (hasStt)
              Semantics(
                button: true,
                label: _isRecording
                    ? l.t('chat.stop_recording')
                    : l.t('placement.tap_to_speak'),
                child: IconButton.filled(
                  onPressed: _isAiThinking ? null : _handleRecordToggle,
                  icon: Icon(_isRecording ? Icons.stop : Icons.mic),
                  color: AppColors.error,
                ),
              ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: TextField(
                controller: _textController,
                enabled: !_isAiThinking,
                decoration: InputDecoration(
                  hintText: _isAiThinking
                      ? l.t('placement.thinking')
                      : l.t('placement.listening'),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppRadius.xl),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.md,
                    vertical: AppSpacing.sm,
                  ),
                ),
                onSubmitted: (text) {
                  if (text.trim().isEmpty) return;
                  _textController.clear();
                  _sendUserTurn(text);
                },
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Semantics(
              button: true,
              label: l.t('placement.tap_to_send'),
              child: FilledButton(
                onPressed: _isAiThinking
                    ? null
                    : () {
                        final text = _textController.text.trim();
                        if (text.isEmpty) return;
                        _textController.clear();
                        _sendUserTurn(text);
                      },
                child: const Icon(Icons.send),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Result ──────────────────────────────────────────────────────────

  Widget _buildResult() {
    final l = _l;
    final isLight = Theme.of(context).brightness == Brightness.light;
    final headingColor =
        isLight ? AppColors.lightTextPrimary : AppColors.textPrimary;
    final bodyColor =
        isLight ? AppColors.lightTextSecondary : AppColors.textSecondary;
    final result = _result;
    if (result == null) {
      // Defensive — should never happen because we only switch to result
      // after assigning _result. Show the failure fallback.
      return Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(l.t('placement.error_failed'),
              style: TextStyle(color: AppColors.error)),
          const SizedBox(height: AppSpacing.md),
          ElevatedButton(
            onPressed: _skip,
            child: Text(l.t('placement.skip_to_chat')),
          ),
        ],
      );
    }

    final displayLevel =
        result.level[0].toUpperCase() + result.level.substring(1);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: AppSpacing.xl),
          Center(
            child: Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: AppColors.success.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(AppRadius.xxl),
              ),
              child: const Icon(Icons.check_circle,
                  color: AppColors.success, size: 44),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Center(
            child: Text(
              l.t('placement.complete_title'),
              style: Theme.of(context).textTheme.displayLarge?.copyWith(
                    color: headingColor,
                  ),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Center(
            child: Text(
              l.tArg('placement.your_level', {'level': displayLevel}),
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    color: AppColors.accentSecondary,
                  ),
            ),
          ),
          const SizedBox(height: AppSpacing.xxl),

          // Radar chart.
          Text(l.t('placement.radar_title'),
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: headingColor,
                  )),
          const SizedBox(height: AppSpacing.sm),
          Center(
            child: PlacementRadarChart(
              values: result.scores.values,
              labels: PlacementScores.dimensionKeys
                  .map((k) => l.t(k))
                  .toList(),
            ),
          ),
          const SizedBox(height: AppSpacing.md),

          // Score table.
          _ScoreTable(scores: result.scores, bodyColor: bodyColor),
          const SizedBox(height: AppSpacing.xxl),

          // 4-week plan.
          Text(l.t('placement.path_title'),
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: headingColor,
                  )),
          const SizedBox(height: AppSpacing.xs),
          Text(
            l.t('placement.path_generated'),
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: bodyColor,
                ),
          ),
          const SizedBox(height: AppSpacing.md),
          ...result.path.map((w) => _LearningPathCard(week: w)),

          const SizedBox(height: AppSpacing.xl),
          FilledButton(
            onPressed: _finishAndGoHome,
            style: FilledButton.styleFrom(
              minimumSize: const Size(double.infinity, 56),
            ),
            child: Text(l.t('placement.start_practicing')),
          ),
          const SizedBox(height: AppSpacing.lg),
        ],
      ),
    );
  }
}

/// Phases of the placement flow.
enum _PlacementPhase {
  intro,
  chat,
  result,
  legacyQuiz,
}

/// Single chat bubble for the placement transcript.
class _PlacementBubble extends StatelessWidget {
  final String text;
  final bool isUser;
  final bool isStreaming;

  const _PlacementBubble({
    required this.text,
    required this.isUser,
    this.isStreaming = false,
  });

  @override
  Widget build(BuildContext context) {
    final isLight = Theme.of(context).brightness == Brightness.light;
    final bubbleColor = isUser
        ? (isLight ? AppColors.lightBubbleUser : AppColors.bubbleUser)
        : (isLight ? AppColors.lightBubbleAi : AppColors.bubbleAi);
    final accent =
        isUser ? AppColors.accentSecondary : AppColors.accentPrimary;
    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: AppSpacing.sm),
        padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md, vertical: AppSpacing.sm),
        constraints: BoxConstraints(
          maxWidth: Responsive.contentMaxWidth(context) * 0.78,
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
        child: Text(
          text + (isStreaming ? '▌' : ''),
          style: Theme.of(context).textTheme.bodyLarge,
        ),
      ),
    );
  }
}

/// Compact score table rendered below the radar chart.
class _ScoreTable extends StatelessWidget {
  final PlacementScores scores;
  final Color bodyColor;
  const _ScoreTable({required this.scores, required this.bodyColor});

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final rows = List.generate(PlacementScores.dimensionKeys.length, (i) {
      final label = l.t(PlacementScores.dimensionKeys[i]);
      final value = scores.values[i];
      return TableRow(children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Text(label, style: TextStyle(color: bodyColor)),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Text('$value',
              textAlign: TextAlign.end,
              style: const TextStyle(fontWeight: FontWeight.w600)),
        ),
      ]);
    });
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
      child: Table(
        columnWidths: const {
          0: FlexColumnWidth(2),
          1: FlexColumnWidth(1),
        },
        children: rows,
      ),
    );
  }
}

/// A single week card in the 4-week plan.
class _LearningPathCard extends StatelessWidget {
  final LearningPathWeek week;
  const _LearningPathCard({required this.week});

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final isLight = Theme.of(context).brightness == Brightness.light;
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: GlassCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: AppColors.accentPrimary.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(AppRadius.sm),
                  ),
                  child: Center(
                    child: Text(
                      '${week.week}',
                      style: const TextStyle(
                        color: AppColors.accentPrimary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    week.focus.isEmpty
                        ? l.tArg('placement.week', {'n': '${week.week}'})
                        : week.focus,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          color: isLight
                              ? AppColors.lightTextPrimary
                              : AppColors.textPrimary,
                        ),
                  ),
                ),
              ],
            ),
            if (week.tasks.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.xs),
              ...week.tasks.map((t) => Padding(
                    padding: const EdgeInsets.only(
                        left: AppSpacing.md, top: 2),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('• ',
                            style: TextStyle(color: AppColors.accentPrimary)),
                        Expanded(child: Text(t)),
                      ],
                    ),
                  )),
            ],
          ],
        ),
      ),
    );
  }
}

/// Legacy 4-question self-assessment quiz, kept as a fallback when no LLM
/// profile is configured. Mirrors the pre-P1 placement flow so first-run
/// users without provider keys can still complete onboarding.
class _LegacyQuiz extends ConsumerStatefulWidget {
  final VoidCallback onCompleted;
  final VoidCallback onSkipped;
  const _LegacyQuiz({
    required this.onCompleted,
    required this.onSkipped,
  });

  @override
  ConsumerState<_LegacyQuiz> createState() => _LegacyQuizState();
}

class _LegacyQuizState extends ConsumerState<_LegacyQuiz> {
  final List<Map<String, dynamic>> _questions = [
    {
      'question': 'How would you describe your English speaking level?',
      'options': [
        'Beginner',
        'Elementary',
        'Intermediate',
        'Upper-Intermediate',
        'Advanced',
      ],
    },
    {
      'question': 'How often do you speak English?',
      'options': ['Never', 'Rarely', 'Sometimes', 'Often', 'Every day'],
    },
    {
      'question': 'What\'s your biggest challenge?',
      'options': [
        'Vocabulary',
        'Grammar',
        'Pronunciation',
        'Confidence',
        'Understanding native speakers',
      ],
    },
    {
      'question': 'What topics interest you most?',
      'options': [
        'Daily life',
        'Travel',
        'Business',
        'Technology',
        'Culture & Entertainment',
      ],
    },
  ];

  int _currentQuestion = 0;
  final List<String> _answers = [];

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final isLight = Theme.of(context).brightness == Brightness.light;
    final headingColor =
        isLight ? AppColors.lightTextPrimary : AppColors.textPrimary;
    final bodyColor =
        isLight ? AppColors.lightTextSecondary : AppColors.textSecondary;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: widget.onSkipped,
              child: Text(l.t('placement.skip')),
            ),
          ),
          Row(
            children: List.generate(_questions.length, (i) {
              return Expanded(
                child: Container(
                  height: 4,
                  margin: const EdgeInsets.symmetric(horizontal: 2),
                  decoration: BoxDecoration(
                    color: i <= _currentQuestion
                        ? AppColors.accentPrimary
                        : AppColors.glassBorder,
                    borderRadius: BorderRadius.circular(AppRadius.xs),
                  ),
                ),
              );
            }),
          ),
          const SizedBox(height: AppSpacing.xxl),
          Text(
            l.t('placement.title'),
            style: Theme.of(context).textTheme.displayLarge?.copyWith(
                  color: headingColor,
                ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            l.tArg('placement.question', {
              'n': '${_currentQuestion + 1}',
              'total': '${_questions.length}',
            }),
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: bodyColor,
                ),
          ),
          const SizedBox(height: AppSpacing.xl),
          Text(
            _questions[_currentQuestion]['question'],
            style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                  color: headingColor,
                ),
          ),
          const SizedBox(height: AppSpacing.xl),
          ...(_questions[_currentQuestion]['options'] as List<String>)
              .asMap()
              .entries
              .map((entry) {
            final index = entry.key;
            final option = entry.value;
            return Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.sm),
              child: GlassCard(
                onTap: () => _selectAnswer(option),
                child: Row(
                  children: [
                    Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        border: Border.all(color: AppColors.glassBorder),
                        borderRadius: BorderRadius.circular(AppRadius.sm),
                      ),
                      child: Center(
                        child: Text(
                          String.fromCharCode(65 + index),
                          style: TextStyle(
                            color: bodyColor,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Flexible(
                      child: Text(
                        option,
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                              color: headingColor,
                            ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          }),
        ],
      ),
    );
  }

  void _selectAnswer(String answer) {
    _answers.add(answer);
    if (_currentQuestion < _questions.length - 1) {
      setState(() => _currentQuestion++);
    } else {
      _completeSetup();
    }
  }

  Future<void> _completeSetup() async {
    final repo = ref.read(profileRepoProvider);
    final q1 = _answers.isNotEmpty ? _answers[0] : '';
    String level = 'intermediate';
    if (q1 == 'Beginner' || q1 == 'Elementary') {
      level = 'beginner';
    } else if (q1 == 'Advanced' || q1 == 'Upper-Intermediate') {
      level = 'advanced';
    }
    try {
      await repo.setUserLevel(level);
      await repo.setPlacementCompleted();
    } catch (_) {}
    widget.onCompleted();
  }
}
