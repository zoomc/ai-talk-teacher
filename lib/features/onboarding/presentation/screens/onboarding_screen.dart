import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../shared/widgets/glass_widgets.dart';
import '../../../../shared/providers.dart';
import '../../../profile/domain/profile_models.dart';

class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  final _llmKeyController = TextEditingController();
  final _llmUrlController = TextEditingController(text: 'https://api.deepseek.com');
  final _llmModelController = TextEditingController(text: 'deepseek-chat');
  final _sttKeyController = TextEditingController();
  final _ttsKeyController = TextEditingController();

  bool _isSaving = false;

  @override
  void dispose() {
    _pageController.dispose();
    _llmKeyController.dispose();
    _llmUrlController.dispose();
    _llmModelController.dispose();
    _sttKeyController.dispose();
    _ttsKeyController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgPrimary,
      body: SafeArea(
        child: PageView(
          controller: _pageController,
          physics: const NeverScrollableScrollPhysics(),
          onPageChanged: (i) => setState(() => _currentPage = i),
          children: [
            _buildWelcomePage(),
            _buildLlmPage(),
            _buildSttPage(),
            _buildTtsPage(),
          ],
        ),
      ),
    );
  }

  Widget _buildWelcomePage() {
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.xl),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              gradient: AppColors.gradientPrimary,
              borderRadius: BorderRadius.circular(AppRadius.xxl),
              boxShadow: [
                BoxShadow(
                  color: AppColors.accentPrimary.withValues(alpha: 0.4),
                  blurRadius: 30,
                  spreadRadius: -5,
                ),
              ],
            ),
            child: const Icon(Icons.mic, size: 50, color: Colors.white),
          ),
          const SizedBox(height: AppSpacing.xl),
          Text(
            'Welcome to SpeakFlow',
            style: Theme.of(context).textTheme.displayLarge,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            'Your AI English speaking practice companion.\n\nTo get started, you need API keys for 3 services. All are free to sign up.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
              color: AppColors.textSecondary,
              height: 1.6,
            ),
          ),
          const SizedBox(height: AppSpacing.xxl),
          ElevatedButton(
            onPressed: () => _pageController.nextPage(
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeInOut,
            ),
            style: ElevatedButton.styleFrom(
              minimumSize: const Size(double.infinity, 56),
            ),
            child: const Text('Get Started'),
          ),
        ],
      ),
    );
  }

  Widget _buildLlmPage() {
    return _buildServicePage(
      emoji: '🧠',
      title: 'AI Dialogue',
      subtitle: 'This powers the conversation with your AI tutor',
      recommendedService: 'DeepSeek',
      recommendedUrl: 'https://platform.deepseek.com',
      hint: 'sk-...',
      keyController: _llmKeyController,
      extraFields: [
        const SizedBox(height: AppSpacing.md),
        Text('API Base URL', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: AppSpacing.xs),
        TextFormField(
          controller: _llmUrlController,
          style: const TextStyle(color: AppColors.textPrimary),
          decoration: const InputDecoration(hintText: 'https://api.deepseek.com'),
        ),
        const SizedBox(height: AppSpacing.md),
        Text('Model', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: AppSpacing.xs),
        TextFormField(
          controller: _llmModelController,
          style: const TextStyle(color: AppColors.textPrimary),
          decoration: const InputDecoration(hintText: 'deepseek-chat'),
        ),
      ],
      onNext: () => _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      ),
    );
  }

  Widget _buildSttPage() {
    return _buildServicePage(
      emoji: '🎤',
      title: 'Speech Recognition',
      subtitle: 'Converts your speech to text. Cloud services handle accents and errors much better than built-in options.',
      recommendedService: 'Deepgram',
      recommendedUrl: 'https://console.deepgram.com',
      hint: 'dg-...',
      keyController: _sttKeyController,
      onNext: () => _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      ),
    );
  }

  Widget _buildTtsPage() {
    return _buildServicePage(
      emoji: '🔊',
      title: 'Text-to-Speech',
      subtitle: 'Reads the AI tutor\'s responses aloud. Natural voices make learning more engaging.',
      recommendedService: 'Fish Audio',
      recommendedUrl: 'https://fish.audio',
      hint: 'Enter your API key',
      keyController: _ttsKeyController,
      onNext: _saveAndContinue,
      isLast: true,
    );
  }

  Widget _buildServicePage({
    required String emoji,
    required String title,
    required String subtitle,
    required String recommendedService,
    required String recommendedUrl,
    required String hint,
    required TextEditingController keyController,
    List<Widget> extraFields = const [],
    required VoidCallback onNext,
    bool isLast = false,
  }) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Progress indicator
          Row(
            children: List.generate(4, (i) {
              return Expanded(
                child: Container(
                  height: 4,
                  margin: const EdgeInsets.symmetric(horizontal: 2),
                  decoration: BoxDecoration(
                    color: i <= _currentPage ? AppColors.accentPrimary : AppColors.bgTertiary,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              );
            }),
          ),
          const SizedBox(height: AppSpacing.xxl),

          Text(emoji, style: const TextStyle(fontSize: 48)),
          const SizedBox(height: AppSpacing.md),
          Text(title, style: Theme.of(context).textTheme.displayLarge),
          const SizedBox(height: AppSpacing.sm),
          Text(subtitle, style: Theme.of(context).textTheme.bodyLarge?.copyWith(
            color: AppColors.textSecondary,
            height: 1.6,
          )),
          const SizedBox(height: AppSpacing.xl),

          // Recommendation
          GlassCard(
            child: Row(
              children: [
                const Icon(Icons.recommend, color: AppColors.accentSecondary),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Recommended: $recommendedService', style: Theme.of(context).textTheme.titleMedium),
                      const SizedBox(height: 2),
                      Text(recommendedUrl, style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.accentSecondary,
                      )),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.lg),

          // API Key
          Text('API Key', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: AppSpacing.xs),
          TextFormField(
            controller: keyController,
            style: const TextStyle(color: AppColors.textPrimary),
            obscureText: true,
            decoration: InputDecoration(hintText: hint),
          ),

          ...extraFields,

          const SizedBox(height: AppSpacing.xl),

          Row(
            children: [
              if (_currentPage > 0)
                TextButton(
                  onPressed: () => _pageController.previousPage(
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeInOut,
                  ),
                  child: const Text('Back'),
                ),
              const Spacer(),
              ElevatedButton(
                onPressed: _isSaving ? null : onNext,
                child: _isSaving
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                    : Text(isLast ? 'Start Learning' : 'Next'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _saveAndContinue() async {
    setState(() => _isSaving = true);
    final repo = ref.read(profileRepoProvider);

    try {
      // Save LLM profile
      if (_llmKeyController.text.isNotEmpty) {
        final llm = LlmProfile(
          name: 'Default',
          baseUrl: _llmUrlController.text,
          apiKey: _llmKeyController.text,
          model: _llmModelController.text,
          isActive: true,
        );
        await repo.saveLlmProfile(llm);
        await repo.setActiveLlmProfile(llm.id);
      }

      // Save STT profile
      if (_sttKeyController.text.isNotEmpty) {
        final stt = SttProfile(
          name: 'Default',
          provider: SttProvider.deepgram,
          apiKey: _sttKeyController.text,
          isActive: true,
        );
        await repo.saveSttProfile(stt);
        await repo.setActiveSttProfile(stt.id);
      }

      // Save TTS profile
      if (_ttsKeyController.text.isNotEmpty) {
        final tts = TtsProfile(
          name: 'Default',
          provider: TtsProvider.fishAudio,
          apiKey: _ttsKeyController.text,
          isActive: true,
        );
        await repo.saveTtsProfile(tts);
        await repo.setActiveTtsProfile(tts.id);
      }

      await repo.setOnboardingCompleted();

      if (mounted) {
        context.go('/placement');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }
}
