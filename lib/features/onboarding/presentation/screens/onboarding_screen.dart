import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/util/responsive.dart';
import '../../../../shared/providers.dart';
import '../../../profile/domain/profile_models.dart';
import '../../../profile/domain/provider_catalog.dart';

/// First-run wizard. The user picks a provider for each of LLM / STT / TTS,
/// pastes an API key, and we auto-fill the rest from the catalog. Only the API
/// key is strictly required; everything else has sane catalog defaults.
class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  // LLM
  String _llmProviderId = 'deepseek';
  final _llmKeyController = TextEditingController();
  final _llmUrlController = TextEditingController();
  final _llmModelController = TextEditingController();

  // STT
  String _sttProviderId = 'deepgram';
  final _sttKeyController = TextEditingController();

  // TTS
  String _ttsProviderId = 'fish_audio';
  final _ttsKeyController = TextEditingController();

  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _applyLlmDefaults();
  }

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

  void _applyLlmDefaults() {
    final def = LlmProviderCatalog.byId(_llmProviderId);
    _llmUrlController.text = def.defaultBaseUrl;
    _llmModelController.text = def.defaultModel ?? '';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgPrimary,
      body: SafeArea(
        child: Center(
          // Constrain onboarding content on wide screens so the form
          // stays centered and readable on desktop browsers.
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: Responsive.contentMaxWidth(context),
            ),
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
            'Your AI English speaking practice companion.\n\n'
            'To get started, configure 3 services. Pick a provider and paste '
            'an API key — the rest is filled in automatically. You can use a '
            'relay station (中转站) or a self-hosted local model too.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
              color: AppColors.textSecondary,
              height: 1.6,
            ),
          ),
          const SizedBox(height: AppSpacing.xxl),
          ElevatedButton(
            onPressed: () => _next(),
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
      subtitle: 'Powers the conversation with your AI tutor.',
      providerId: _llmProviderId,
      onProviderChanged: (v) {
        setState(() {
          _llmProviderId = v;
          _applyLlmDefaults();
        });
      },
      providers: LlmProviderCatalog.all,
      keyController: _llmKeyController,
      keyHint: 'sk-...',
      extraFields: [
        const SizedBox(height: AppSpacing.md),
        Text('API Base URL', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: AppSpacing.xs),
        TextFormField(
          controller: _llmUrlController,
          style: const TextStyle(color: AppColors.textPrimary),
          decoration: const InputDecoration(
            hintText: 'https://api.deepseek.com/v1',
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        Text('Model', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: AppSpacing.xs),
        TextFormField(
          controller: _llmModelController,
          style: const TextStyle(color: AppColors.textPrimary),
          decoration: const InputDecoration(hintText: 'deepseek-v4-flash'),
        ),
      ],
    );
  }

  Widget _buildSttPage() {
    return _buildServicePage(
      emoji: '🎤',
      title: 'Speech Recognition',
      subtitle:
          'Converts your speech to text. Cloud services handle accents far better than on-device options.',
      providerId: _sttProviderId,
      onProviderChanged: (v) => setState(() => _sttProviderId = v),
      providers: SttProviderCatalog.all,
      keyController: _sttKeyController,
      keyHint: 'dg-...',
    );
  }

  Widget _buildTtsPage() {
    return _buildServicePage(
      emoji: '🔊',
      title: 'Text-to-Speech',
      subtitle: 'Reads the AI tutor\'s responses aloud with natural voices.',
      providerId: _ttsProviderId,
      onProviderChanged: (v) => setState(() => _ttsProviderId = v),
      providers: TtsProviderCatalog.all,
      keyController: _ttsKeyController,
      keyHint: 'Enter your API key',
      isLast: true,
      onNext: _saveAndContinue,
    );
  }

  Widget _buildServicePage({
    required String emoji,
    required String title,
    required String subtitle,
    required String providerId,
    required ValueChanged<String> onProviderChanged,
    required List<ProviderDef> providers,
    required TextEditingController keyController,
    required String keyHint,
    List<Widget> extraFields = const [],
    bool isLast = false,
    VoidCallback? onNext,
  }) {
    final def = providers.firstWhere(
      (p) => p.id == providerId,
      orElse: () => providers.first,
    );
    final keyRequired = def.apiKeyRequired;
    return SingleChildScrollView(
      // Scaffold's `resizeToAvoidBottomInset: true` (the default) already
      // shrinks the body to clear the soft keyboard, so we just need
      // normal bottom padding here — adding viewInsets.bottom would
      // double-count and leave the Next/Start button floating ~300pt
      // above the keyboard when fully scrolled.
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
                    color: i <= _currentPage
                        ? AppColors.accentPrimary
                        : AppColors.bgTertiary,
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
          Text(
            subtitle,
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
              color: AppColors.textSecondary,
              height: 1.6,
            ),
          ),
          const SizedBox(height: AppSpacing.xl),

          // Provider picker
          Text('Provider', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: AppSpacing.xs),
          DropdownButtonFormField<String>(
            value: providerId,
            dropdownColor: AppColors.bgTertiary,
            style: const TextStyle(color: AppColors.textPrimary),
            decoration: const InputDecoration(hintText: 'Select provider'),
            items: _groupedItems(providers),
            onChanged: (v) {
              if (v != null && !v.startsWith('_header_')) onProviderChanged(v);
            },
          ),
          if (def.note != null) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(
              def.note!,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: AppColors.textSecondary,
                height: 1.4,
              ),
            ),
          ],
          if (def.docsUrl.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.xs),
            Text(
              'Docs: ${def.docsUrl}',
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: AppColors.accentSecondary),
            ),
          ],
          const SizedBox(height: AppSpacing.lg),

          // API Key
          Text(
            keyRequired ? 'API Key' : 'API Key (optional)',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: AppSpacing.xs),
          TextFormField(
            controller: keyController,
            style: const TextStyle(color: AppColors.textPrimary),
            obscureText: true,
            decoration: InputDecoration(hintText: keyHint),
          ),

          ...extraFields,

          const SizedBox(height: AppSpacing.xl),

          Row(
            children: [
              if (_currentPage > 0)
                TextButton(onPressed: _back, child: const Text('Back')),
              const Spacer(),
              ElevatedButton(
                onPressed: _isSaving ? null : (onNext ?? _next),
                child: _isSaving
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(isLast ? 'Start Learning' : 'Next'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  List<DropdownMenuItem<String>> _groupedItems(List<ProviderDef> providers) {
    final byRegion = <ProviderRegion, List<ProviderDef>>{};
    for (final d in providers) {
      byRegion.putIfAbsent(d.region, () => []).add(d);
    }
    final order = [
      ProviderRegion.cn,
      ProviderRegion.global,
      ProviderRegion.local,
    ];
    final items = <DropdownMenuItem<String>>[];
    for (final region in order) {
      final list = byRegion[region];
      if (list == null || list.isEmpty) continue;
      items.add(
        DropdownMenuItem<String>(
          enabled: false,
          value: '_header_${region.name}',
          child: Text(
            _regionLabel(region),
            style: TextStyle(
              color: AppColors.accentSecondary,
              fontWeight: FontWeight.w600,
              fontSize: 12,
            ),
          ),
        ),
      );
      for (final d in list) {
        items.add(
          DropdownMenuItem<String>(value: d.id, child: Text(d.displayName)),
        );
      }
    }
    return items;
  }

  String _regionLabel(ProviderRegion r) {
    switch (r) {
      case ProviderRegion.cn:
        return '— China (国内) —';
      case ProviderRegion.global:
        return '— Global (国外) —';
      case ProviderRegion.local:
        return '— Local / Self-hosted —';
    }
  }

  void _next() {
    _pageController.nextPage(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  void _back() {
    _pageController.previousPage(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  Future<void> _saveAndContinue() async {
    final repo = ref.read(profileRepoProvider);

    // Validate before save — the LLM is essential; STT/TTS are recommended.
    // Previously, an empty API key silently skipped saving, leaving the user
    // stranded on the home screen with no service to talk to. Now we warn
    // clearly and let them choose: configure now, or skip with explicit
    // acknowledgement.
    final llmDef = LlmProviderCatalog.byId(_llmProviderId);
    final sttDef = SttProviderCatalog.byId(_sttProviderId);
    final ttsDef = TtsProviderCatalog.byId(_ttsProviderId);

    final llmWillSave =
        _llmKeyController.text.isNotEmpty || !llmDef.apiKeyRequired;
    final sttWillSave =
        _sttKeyController.text.isNotEmpty || !sttDef.apiKeyRequired;
    final ttsWillSave =
        _ttsKeyController.text.isNotEmpty || !ttsDef.apiKeyRequired;

    if (!llmWillSave) {
      // LLM is mandatory — chat literally cannot work without it.
      final proceed = await _confirmMissingService(
        title: 'AI Dialogue is required',
        body:
            'You haven\'t entered an API key for the AI Dialogue service. '
            'You won\'t be able to chat with the AI tutor without it.\n\n'
            'Continue anyway? You can configure it later in Settings.',
        confirmLabel: 'Skip for now',
      );
      if (proceed != true) return;
    } else if (!sttWillSave || !ttsWillSave) {
      // STT/TTS missing — warn but make it easy to continue.
      final missing = <String>[];
      if (!sttWillSave) missing.add('Speech Recognition');
      if (!ttsWillSave) missing.add('Text-to-Speech');
      final proceed = await _confirmMissingService(
        title: '${missing.join(" and ")} not configured',
        body:
            'Without these, voice input and AI spoken replies won\'t work. '
            'You can still chat by typing.\n\n'
            'Continue and configure later?',
        confirmLabel: 'Continue',
      );
      if (proceed != true) return;
    }

    setState(() => _isSaving = true);

    try {
      // Save LLM profile (only if a key was entered OR the provider needs none).
      if (llmWillSave) {
        final llm = LlmProfile(
          name: 'Default',
          providerId: _llmProviderId,
          baseUrl: _llmUrlController.text.trim().isEmpty
              ? llmDef.defaultBaseUrl
              : _llmUrlController.text.trim(),
          apiKey: _llmKeyController.text,
          model: _llmModelController.text.trim().isEmpty
              ? (llmDef.defaultModel ?? '')
              : _llmModelController.text.trim(),
          isActive: true,
        );
        await repo.saveLlmProfile(llm);
        await repo.setActiveLlmProfile(llm.id);
      }

      // Save STT profile.
      if (sttWillSave) {
        final stt = SttProfile(
          name: 'Default',
          providerId: _sttProviderId,
          baseUrl: sttDef.defaultBaseUrl,
          apiKey: _sttKeyController.text,
          model: sttDef.defaultModel ?? '',
          language: 'en-US',
          isActive: true,
        );
        await repo.saveSttProfile(stt);
        await repo.setActiveSttProfile(stt.id);
      }

      // Save TTS profile.
      if (ttsWillSave) {
        final tts = TtsProfile(
          name: 'Default',
          providerId: _ttsProviderId,
          baseUrl: ttsDef.defaultBaseUrl,
          apiKey: _ttsKeyController.text,
          model: ttsDef.defaultModel ?? '',
          voiceId: ttsDef.defaultVoice,
          voiceName: ttsDef.defaultVoice,
          speed: 1.0,
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
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  /// Shows a confirmation dialog when a critical service is missing from
  /// the onboarding setup. Returns `true` if the user chose to proceed.
  Future<bool?> _confirmMissingService({
    required String title,
    required String body,
    required String confirmLabel,
  }) {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.bgTertiary,
        title: Text(title),
        content: Text(body),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Go back'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(confirmLabel),
          ),
        ],
      ),
    );
  }
}
