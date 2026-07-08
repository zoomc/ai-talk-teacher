import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/util/responsive.dart';
import '../../../../shared/widgets/glass_widgets.dart';
import '../../../../shared/providers.dart';

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

  @override
  Widget build(BuildContext context) {
    if (_isComplete) {
      return _buildResultScreen();
    }

    return Scaffold(
      backgroundColor: AppColors.bgPrimary,
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
                                : AppColors.bgTertiary,
                            borderRadius: BorderRadius.circular(2),
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
                    'Quick Assessment',
                    style: Responsive.isShortViewport(context)
                        ? Theme.of(context).textTheme.headlineMedium
                        : Theme.of(context).textTheme.displayLarge,
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    'Question ${_currentQuestion + 1} of ${_questions.length}',
                    style: Theme.of(
                      context,
                    ).textTheme.bodyLarge?.copyWith(color: AppColors.textSecondary),
                  ),
                  const SizedBox(height: AppSpacing.xl),

                  Text(
                    _questions[_currentQuestion]['question'],
                    style: Responsive.isShortViewport(context)
                        ? Theme.of(context).textTheme.titleLarge
                        : Theme.of(context).textTheme.headlineLarge,
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
                                  style: const TextStyle(
                                    color: AppColors.textSecondary,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: AppSpacing.md),
                            Flexible(
                              child: Text(
                                option,
                                style: Theme.of(context).textTheme.bodyLarge,
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

    return Scaffold(
      backgroundColor: AppColors.bgPrimary,
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
                  'Assessment Complete!',
                  style: Theme.of(context).textTheme.displayLarge,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: AppSpacing.md),
                Text(
                  'Your level: $displayLevel',
                  style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                    color: AppColors.accentSecondary,
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  'We\'ll adjust the conversation difficulty to match your level.',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: AppSpacing.xxl),
                ElevatedButton(
                  onPressed: _completeSetup,
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size(double.infinity, 56),
                  ),
                  child: const Text('Start Practicing'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _completeSetup() async {
    final repo = ref.read(profileRepoProvider);
    final chatRepo = ref.read(chatRepoProvider);

    // Save level
    final String level = _computeLevel();
    await repo.setUserLevel(level);
    await repo.setPlacementCompleted();

    // Create first session
    final session = await chatRepo.createSession(
      topic: 'Free Talk',
      levelTag: level,
    );

    if (mounted) {
      context.go('/chat/${session.id}');
    }
  }
}
