import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/i18n/app_localizations.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/util/responsive.dart';
import '../../../../shared/widgets/glass_widgets.dart';
import '../../../../shared/providers.dart';

/// Quick English-level assessment shown after first-run onboarding.
///
/// Design notes:
/// - Question/option text stays in English on purpose — the user is here to
///   learn English, so the assessment content itself is English. Only the UI
///   chrome (title, counter, buttons, result) is localized.
/// - Skip is always available: skipping marks placement complete and lands
///   the user on Home (no chat session is auto-created here — D10).
/// - On completion we set the level + mark placement done, then go to Home.
///   The user opens a chat themselves when ready.
class PlacementScreen extends ConsumerStatefulWidget {
  const PlacementScreen({super.key});

  @override
  ConsumerState<PlacementScreen> createState() => _PlacementScreenState();
}

class _PlacementScreenState extends ConsumerState<PlacementScreen> {
  // TODO(placement-rewrite): The current placement is a short static
  // self-assessment quiz with a hand-tuned scoring heuristic. The spec
  // calls for an AI-conversation-based placement: open a short (3–5 turn)
  // voice chat with the active LlmProfile, then have the LLM emit a
  // `{"level": "beginner|intermediate|advanced"}` verdict. When that
  // lands, replace `_questions` + `_computeLevel` with a thin wrapper
  // around the chat flow and keep `setUserLevel` +
  // `setPlacementCompleted` + `createSession` as the post-flow side
  // effects. Tracked in projects.md under "Placement → AI assessment".
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
  bool _isComplete = false;

  AppLocalizations get _l => AppLocalizations.of(context);

  @override
  Widget build(BuildContext context) {
    if (_isComplete) {
      return _buildResultScreen();
    }

    final isLight = Theme.of(context).brightness == Brightness.light;
    final headingColor =
        isLight ? AppColors.lightTextPrimary : AppColors.textPrimary;
    final bodyColor =
        isLight ? AppColors.lightTextSecondary : AppColors.textSecondary;
    return Scaffold(
      backgroundColor:
          isLight ? AppColors.lightBgPrimary : AppColors.bgPrimary,
      body: SafeArea(
        child: Center(
          // Constrain on iPad so the question text + option cards don't
          // stretch edge-to-edge. Placement is a top-level route (no
          // MainShell), so without this iPad renders full-bleed.
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: Responsive.contentMaxWidth(context),
            ),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(AppSpacing.xl),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Top row: back/skip on the right.
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: _skip,
                      child: Text(_l.t('placement.skip')),
                    ),
                  ),

                  // Progress
                  Row(
                    children: List.generate(_questions.length, (i) {
                      return Expanded(
                        child: Container(
                          height: 4,
                          margin: const EdgeInsets.symmetric(horizontal: 2),
                          decoration: BoxDecoration(
                            color: i <= _currentQuestion
                                ? AppColors.accentPrimary
                                : (isLight
                                    ? AppColors.lightBgTertiary
                                    : AppColors.bgTertiary),
                            borderRadius: BorderRadius.circular(AppRadius.xs),
                          ),
                        ),
                      );
                    }),
                  ),
                  const SizedBox(height: AppSpacing.xxl),

                  // On a short landscape phone (~390pt tall), drop the
                  // title from displayLarge to headlineMedium so the
                  // question + option list have room. The whole column
                  // is now scrollable so nothing clips.
                  Text(
                    _l.t('placement.title'),
                    style: (Responsive.isShortViewport(context)
                            ? Theme.of(context).textTheme.headlineMedium
                            : Theme.of(context).textTheme.displayLarge)
                        ?.copyWith(color: headingColor),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    _l.tArg('placement.question', {
                      'n': '${_currentQuestion + 1}',
                      'total': '${_questions.length}',
                    }),
                    style: Theme.of(context)
                        .textTheme
                        .bodyLarge
                        ?.copyWith(color: bodyColor),
                  ),
                  const SizedBox(height: AppSpacing.xl),

                  Text(
                    _questions[_currentQuestion]['question'],
                    style: (Responsive.isShortViewport(context)
                        ? Theme.of(context).textTheme.titleLarge
                        : Theme.of(context).textTheme.headlineLarge)
                        ?.copyWith(color: headingColor),
                  ),
                  const SizedBox(height: AppSpacing.xl),

                  // Use a non-Expanded Column-friendly list: since the
                  // whole column scrolls now, we render the options
                  // inline instead of in an Expanded ListView (which
                  // needs a bounded height).
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
                                border: Border.all(
                                  color: AppColors.glassBorder,
                                ),
                                borderRadius: BorderRadius.circular(
                                  AppRadius.sm,
                                ),
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
                                style: Theme.of(context)
                                    .textTheme
                                    .bodyLarge
                                    ?.copyWith(color: headingColor),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _selectAnswer(String answer) {
    _answers.add(answer);

    if (_currentQuestion < _questions.length - 1) {
      setState(() => _currentQuestion++);
    } else {
      setState(() => _isComplete = true);
    }
  }

  String _computeLevel() {
    if (_answers.length < _questions.length) return 'intermediate';

    final indices = <int>[];
    for (var i = 0; i < _questions.length; i++) {
      final options = (_questions[i]['options'] as List<String>);
      final idx = options.indexOf(_answers[i]);
      indices.add(idx < 0 ? 2 : idx);
    }

    final q1Weight = 0.5;
    final otherWeight = 0.5 / (_questions.length - 1);
    double score = indices[0] * q1Weight;
    for (var i = 1; i < indices.length; i++) {
      score += indices[i] * otherWeight;
    }

    final q1Answer = _answers[0];
    if (q1Answer == 'Beginner' || q1Answer == 'Elementary') {
      return 'beginner';
    }
    if (score < 1.5) return 'beginner';
    if (score < 3.0) return 'intermediate';
    return 'advanced';
  }

  Widget _buildResultScreen() {
    final String level = _computeLevel();
    final String displayLevel = level[0].toUpperCase() + level.substring(1);

    final isLight = Theme.of(context).brightness == Brightness.light;
    final headingColor =
        isLight ? AppColors.lightTextPrimary : AppColors.textPrimary;
    final bodyColor =
        isLight ? AppColors.lightTextSecondary : AppColors.textSecondary;
    return Scaffold(
      backgroundColor:
          isLight ? AppColors.lightBgPrimary : AppColors.bgPrimary,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.xl),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(
                    color: AppColors.success.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(AppRadius.xxl),
                  ),
                  child: const Icon(
                    Icons.check_circle,
                    color: AppColors.success,
                    size: 50,
                  ),
                ),
                const SizedBox(height: AppSpacing.xl),
                Text(
                  _l.t('placement.complete_title'),
                  style: Theme.of(context)
                      .textTheme
                      .displayLarge
                      ?.copyWith(color: headingColor),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: AppSpacing.md),
                Text(
                  _l.tArg('placement.your_level', {'level': displayLevel}),
                  style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                    color: AppColors.accentSecondary,
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  _l.t('placement.adjust_hint'),
                  textAlign: TextAlign.center,
                  style: Theme.of(context)
                      .textTheme
                      .bodyLarge
                      ?.copyWith(color: bodyColor),
                ),
                const SizedBox(height: AppSpacing.xxl),
                ElevatedButton(
                  onPressed: _completeSetup,
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size(double.infinity, 56),
                  ),
                  child: Text(_l.t('placement.start_practicing')),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Skip the assessment — mark placement complete and go to Home. We don't
  /// set a level here; getUserLevel() already defaults to 'intermediate'
  /// when unset, so skipping is safe.
  Future<void> _skip() async {
    try {
      await ref.read(profileRepoProvider).setPlacementCompleted();
    } catch (_) {
      // Best-effort.
    }
    if (mounted) context.go('/');
  }

  /// Complete the assessment — save the computed level, mark placement done,
  /// and land on Home (NOT a chat session). D10: let the user open a chat
  /// themselves when ready.
  Future<void> _completeSetup() async {
    final repo = ref.read(profileRepoProvider);
    final String level = _computeLevel();
    try {
      await repo.setUserLevel(level);
      await repo.setPlacementCompleted();
    } catch (_) {
      // Best-effort — still proceed to Home.
    }

    if (mounted) {
      context.go('/');
    }
  }
}
