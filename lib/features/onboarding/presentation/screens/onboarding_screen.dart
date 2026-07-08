import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/i18n/app_localizations.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/util/responsive.dart';
import '../../../../shared/providers.dart';
import '../../../profile/domain/profile_models.dart';
import '../../../profile/domain/provider_catalog.dart';
import '../../../profile/domain/services/connection_tester.dart';

/// First-run wizard. The user picks a provider for each of LLM / STT / TTS,
/// pastes an API key, and we auto-fill the rest from the catalog. Only the API
/// key is strictly required; everything else has sane catalog defaults.
///
/// Each page offers a "Skip for now" affordance — the user can defer all
/// configuration to Settings later. The TTS page additionally offers a
/// "Use same provider & key as STT" shortcut.
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
  final _sttUrlController = TextEditingController();

  // TTS
  String _ttsProviderId = 'fish_audio';
  final _ttsKeyController = TextEditingController();

  bool _isSaving = false;

  // Tracks which service (llm/stt/tts) is currently being connection-tested,
  // so the matching button shows a spinner and the others are disabled.
  String? _testingService;

  @override
  void initState() {
    super.initState();
    _applyLlmDefaults();
    _applySttDefaults();
    _applyTtsDefaults();
  }

  @override
  void dispose() {
    _pageController.dispose();
    _llmKeyController.dispose();
    _llmUrlController.dispose();
    _llmModelController.dispose();
    _sttKeyController.dispose();
    _sttUrlController.dispose();
    _ttsKeyController.dispose();
    super.dispose();
  }

  void _applyLlmDefaults() {
    final def = LlmProviderCatalog.byId(_llmProviderId);
    _llmUrlController.text = def.defaultBaseUrl;
    _llmModelController.text = def.defaultModel ?? '';
  }

  void _applySttDefaults() {
    final def = SttProviderCatalog.byId(_sttProviderId);
    _sttUrlController.text = def.defaultBaseUrl;
  }

  void _applyTtsDefaults() {
    final def = TtsProviderCatalog.byId(_ttsProviderId);
    // TTS base URL is read straight from the catalog at save time, but we
    // keep the controller in sync so the "reuse STT" button can overwrite
    // it cleanly.
    _ttsKeyController.text = '';
  }

  AppLocalizations get _l => AppLocalizations.of(context);

  @override
  Widget build(BuildContext context) {
    // Use theme-aware background so the light theme no longer shows the
    // old deep-navy gradient (which had poor contrast against dark text).
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
    final isLight = Theme.of(context).brightness == Brightness.light;
    final headingColor =
        isLight ? AppColors.lightTextPrimary : AppColors.textPrimary;
    final bodyColor =
        isLight ? AppColors.lightTextSecondary : AppColors.textSecondary;
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
            _l.t('onboarding.welcome_title'),
            style: Theme.of(context).textTheme.displayLarge?.copyWith(
                  color: headingColor,
                ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            _l.t('onboarding.welcome_body'),
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: bodyColor,
                  height: 1.6,
                ),
          ),
          const SizedBox(height: AppSpacing.xxl),
          ElevatedButton(
            onPressed: () => _next(),
            style: ElevatedButton.styleFrom(
              minimumSize: const Size(double.infinity, 56),
            ),
            child: Text(_l.t('onboarding.get_started')),
          ),
          const SizedBox(height: AppSpacing.sm),
          // "Skip for now" — completes onboarding with no profiles saved.
          // The user can configure everything from Settings later.
          TextButton(
            onPressed: _isSaving ? null : _skipAll,
            child: Text(_l.t('common.skip_for_now')),
          ),
        ],
      ),
    );
  }

  Widget _buildLlmPage() {
    return _buildServicePage(
      emoji: '🧠',
      titleKey: 'onboarding.llm_title',
      subtitleKey: 'onboarding.llm_subtitle',
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
      extraFields: _buildLlmExtraFields(),
    );
  }

  List<Widget> _buildLlmExtraFields() {
    final isLight = Theme.of(context).brightness == Brightness.light;
    final labelColor =
        isLight ? AppColors.lightTextPrimary : AppColors.textPrimary;
    return [
      _buildTestButton('llm', () async {
        final def = LlmProviderCatalog.byId(_llmProviderId);
        final profile = LlmProfile(
          name: '_temp',
          providerId: _llmProviderId,
          baseUrl: _llmUrlController.text.trim().isEmpty
              ? def.defaultBaseUrl
              : _llmUrlController.text.trim(),
          apiKey: _llmKeyController.text,
          model: _llmModelController.text.trim().isEmpty
              ? (def.defaultModel ?? 'gpt-3.5-turbo')
              : _llmModelController.text.trim(),
          isActive: true,
        );
        return ConnectionTester.testLlm(profile);
      }),
      const SizedBox(height: AppSpacing.md),
      Text(
        _l.t('onboarding.base_url'),
        style: Theme.of(context)
            .textTheme
            .titleMedium
            ?.copyWith(color: labelColor),
      ),
      const SizedBox(height: AppSpacing.xs),
      TextFormField(
        controller: _llmUrlController,
        style: TextStyle(color: labelColor),
        decoration: InputDecoration(
          hintText: 'https://api.deepseek.com/v1',
          hintStyle: TextStyle(
            color: isLight ? AppColors.lightTextMuted : AppColors.textMuted,
          ),
        ),
      ),
      const SizedBox(height: AppSpacing.md),
      Text(
        _l.t('onboarding.model'),
        style: Theme.of(context)
            .textTheme
            .titleMedium
            ?.copyWith(color: labelColor),
      ),
      const SizedBox(height: AppSpacing.xs),
      TextFormField(
        controller: _llmModelController,
        style: TextStyle(color: labelColor),
        decoration: InputDecoration(
          hintText: 'deepseek-v4-flash',
          hintStyle: TextStyle(
            color: isLight ? AppColors.lightTextMuted : AppColors.textMuted,
          ),
        ),
      ),
    ];
  }

  Widget _buildSttPage() {
    return _buildServicePage(
      emoji: '🎤',
      titleKey: 'onboarding.stt_title',
      subtitleKey: 'onboarding.stt_subtitle',
      providerId: _sttProviderId,
      onProviderChanged: (v) {
        setState(() {
          _sttProviderId = v;
          _applySttDefaults();
        });
      },
      providers: SttProviderCatalog.all,
      keyController: _sttKeyController,
      keyHint: 'dg-...',
      extraFields: _buildSttExtraFields(),
    );
  }

  List<Widget> _buildSttExtraFields() {
    final isLight = Theme.of(context).brightness == Brightness.light;
    final labelColor =
        isLight ? AppColors.lightTextPrimary : AppColors.textPrimary;
    return [
      _buildTestButton('stt', () async {
        final def = SttProviderCatalog.byId(_sttProviderId);
        final profile = SttProfile(
          name: '_temp',
          providerId: _sttProviderId,
          baseUrl: _sttUrlController.text.trim().isEmpty
              ? def.defaultBaseUrl
              : _sttUrlController.text.trim(),
          apiKey: _sttKeyController.text,
          model: def.defaultModel ?? '',
          language: 'en-US',
          isActive: true,
        );
        return ConnectionTester.testStt(profile);
      }),
      const SizedBox(height: AppSpacing.md),
      Text(
        _l.t('onboarding.base_url'),
        style: Theme.of(context)
            .textTheme
            .titleMedium
            ?.copyWith(color: labelColor),
      ),
      const SizedBox(height: AppSpacing.xs),
      TextFormField(
        controller: _sttUrlController,
        style: TextStyle(color: labelColor),
        decoration: InputDecoration(
          hintText: 'https://api.deepgram.com',
          hintStyle: TextStyle(
            color: isLight ? AppColors.lightTextMuted : AppColors.textMuted,
          ),
        ),
      ),
    ];
  }

  Widget _buildTtsPage() {
    return _buildServicePage(
      emoji: '🔊',
      titleKey: 'onboarding.tts_title',
      subtitleKey: 'onboarding.tts_subtitle',
      providerId: _ttsProviderId,
      onProviderChanged: (v) => setState(() => _ttsProviderId = v),
      providers: TtsProviderCatalog.all,
      keyController: _ttsKeyController,
      keyHint: _l.t('onboarding.api_key'),
      extraFields: _buildTtsExtraFields(),
      isLast: true,
      onNext: _saveAndContinue,
    );
  }

  List<Widget> _buildTtsExtraFields() {
    return [
      _buildTestButton('tts', () async {
        final def = TtsProviderCatalog.byId(_ttsProviderId);
        final profile = TtsProfile(
          name: '_temp',
          providerId: _ttsProviderId,
          baseUrl: def.defaultBaseUrl,
          apiKey: _ttsKeyController.text,
          model: def.defaultModel ?? '',
          voiceId: def.defaultVoice,
          voiceName: def.defaultVoice,
          speed: 1.0,
          isActive: true,
        );
        return ConnectionTester.testTts(profile);
      }),
      const SizedBox(height: AppSpacing.md),
      // "Reuse STT provider & key" shortcut — copies the STT provider,
      // base URL and API key into the TTS form (with a provider-id
      // mapping when the STT id differs from the TTS id, e.g. deepgram
      // → deepgram_tts).
      Align(
        alignment: Alignment.centerLeft,
        child: TextButton.icon(
          onPressed: _reuseSttForTts,
          icon: const Icon(Icons.copy, size: 18),
          label: Text(_l.t('onboarding.use_same_as_stt')),
        ),
      ),
    ];
  }

  Future<void> _reuseSttForTts() async {
    final repo = ref.read(profileRepoProvider);
    try {
      final sttProfiles = await repo.getAllSttProfiles();
      final active =
          sttProfiles.where((p) => p.isActive).firstOrNull ?? sttProfiles.firstOrNull;
      // Onboarding hasn't saved anything yet — fall back to the in-form
      // STT values the user is currently editing.
      final sttId = active?.providerId ?? _sttProviderId;
      final sttKey = active?.apiKey.isNotEmpty == true
          ? active!.apiKey
          : _sttKeyController.text;
      final sttUrl = active?.baseUrl.isNotEmpty == true
          ? active!.baseUrl
          : _sttUrlController.text;
      if (sttKey.isEmpty && sttUrl.isEmpty) {
        if (!mounted) return;
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(_l.t('onboarding.no_active_stt'))));
        return;
      }
      const mapping = <String, String>{
        'deepgram': 'deepgram_tts',
        'azure': 'azure_tts',
        'google': 'google_tts',
        'siliconflow_stt': 'siliconflow_tts',
        'openai_whisper': 'openai_tts',
        'custom': 'custom',
      };
      final mapped = mapping[sttId] ?? 'custom';
      final exists =
          TtsProviderCatalog.all.any((p) => p.id == mapped) ? mapped : 'custom';
      setState(() {
        _ttsProviderId = exists;
        _ttsKeyController.text = sttKey;
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(_l.t('onboarding.copied_from_stt'))));
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(_l.t('onboarding.no_active_stt'))));
    }
  }

  /// Builds the "Test Connection" button shown below the API key field on
  /// each service page. [serviceId] identifies which button is active (so
  /// only the matching one shows a spinner); [builder] constructs the
  /// temporary profile from current form values and runs the probe.
  Widget _buildTestButton(
    String serviceId,
    Future<ConnectionTestResult> Function() builder,
  ) {
    return Align(
      alignment: Alignment.centerLeft,
      child: TextButton.icon(
        onPressed: _isSaving || _testingService != null
            ? null
            : () => _runTest(serviceId, builder),
        icon: _testingService == serviceId
            ? const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Icon(Icons.wifi_tethering, size: 18),
        label: Text(_l.t('common.test_connection')),
      ),
    );
  }

  Future<void> _runTest(
    String service,
    Future<ConnectionTestResult> Function() builder,
  ) async {
    setState(() => _testingService = service);
    try {
      final result = await builder();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(result.message)),
        );
      }
    } finally {
      if (mounted) setState(() => _testingService = null);
    }
  }

  Widget _buildServicePage({
    required String emoji,
    required String titleKey,
    required String subtitleKey,
    required String providerId,
    required ValueChanged<String> onProviderChanged,
    required List<ProviderDef> providers,
    required TextEditingController keyController,
    required String keyHint,
    List<Widget> extraFields = const [],
    bool isLast = false,
    VoidCallback? onNext,
  }) {
    final isLight = Theme.of(context).brightness == Brightness.light;
    final headingColor =
        isLight ? AppColors.lightTextPrimary : AppColors.textPrimary;
    final bodyColor =
        isLight ? AppColors.lightTextSecondary : AppColors.textSecondary;
    final fieldColor =
        isLight ? AppColors.lightTextPrimary : AppColors.textPrimary;
    final hintColor =
        isLight ? AppColors.lightTextMuted : AppColors.textMuted;
    final def = providers.firstWhere(
      (p) => p.id == providerId,
      orElse: () => providers.first,
    );
    final keyRequired = def.apiKeyRequired;
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
                    color: i <= _currentPage
                        ? AppColors.accentPrimary
                        : (isLight
                            ? AppColors.lightGlassBorder
                            : AppColors.bgTertiary),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              );
            }),
          ),
          const SizedBox(height: AppSpacing.xxl),

          Text(emoji, style: const TextStyle(fontSize: 48)),
          const SizedBox(height: AppSpacing.md),
          Text(
            _l.t(titleKey),
            style: Theme.of(context)
                .textTheme
                .displayLarge
                ?.copyWith(color: headingColor),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            _l.t(subtitleKey),
            style: Theme.of(context)
                .textTheme
                .bodyLarge
                ?.copyWith(color: bodyColor, height: 1.6),
          ),
          const SizedBox(height: AppSpacing.xl),

          // Provider picker
          Text(
            _l.t('onboarding.provider'),
            style: Theme.of(context)
                .textTheme
                .titleMedium
                ?.copyWith(color: headingColor),
          ),
          const SizedBox(height: AppSpacing.xs),
          DropdownButtonFormField<String>(
            value: providerId,
            dropdownColor:
                isLight ? AppColors.lightBgSecondary : AppColors.bgTertiary,
            style: TextStyle(color: fieldColor),
            decoration: InputDecoration(
              hintText: _l.t('onboarding.provider'),
              hintStyle: TextStyle(color: hintColor),
            ),
            items: _groupedItems(providers),
            onChanged: (v) {
              if (v != null && !v.startsWith('_header_')) onProviderChanged(v);
            },
          ),
          if (def.note != null) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(
              def.note!,
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: bodyColor, height: 1.4),
            ),
          ],
          if (def.docsUrl.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.xs),
            Text(
              '${_l.t('onboarding.docs')}: ${def.docsUrl}',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppColors.accentSecondary,
                  ),
            ),
          ],
          const SizedBox(height: AppSpacing.lg),

          // API Key
          Text(
            keyRequired
                ? _l.t('onboarding.api_key')
                : _l.t('onboarding.api_key_optional'),
            style: Theme.of(context)
                .textTheme
                .titleMedium
                ?.copyWith(color: headingColor),
          ),
          const SizedBox(height: AppSpacing.xs),
          TextFormField(
            controller: keyController,
            style: TextStyle(color: fieldColor),
            obscureText: true,
            decoration: InputDecoration(
              hintText: keyHint,
              hintStyle: TextStyle(color: hintColor),
            ),
          ),

          ...extraFields,

          const SizedBox(height: AppSpacing.xl),

          Row(
            children: [
              if (_currentPage > 0)
                TextButton(
                  onPressed: _back,
                  child: Text(_l.t('common.back')),
                ),
              const Spacer(),
              // Per-page skip — only on service pages (LLM/STT/TTS).
              // Lets the user defer configuration of THIS service while
              // still continuing the wizard.
              TextButton(
                onPressed: _isSaving ? null : _skipCurrent,
                child: Text(_l.t('common.skip_for_now')),
              ),
              const SizedBox(width: AppSpacing.sm),
              ElevatedButton(
                onPressed: _isSaving ? null : (onNext ?? _next),
                child: _isSaving
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(isLast
                        ? _l.t('onboarding.start_learning')
                        : _l.t('common.next')),
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
        return _l.t('onboarding.region_cn');
      case ProviderRegion.global:
        return _l.t('onboarding.region_global');
      case ProviderRegion.local:
        return _l.t('onboarding.region_local');
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

  /// Skip the current service page (advances to the next page, or completes
  /// onboarding if already on the last page). The skipped service is simply
  /// not saved — the user can configure it later from Settings.
  void _skipCurrent() {
    if (_currentPage < 3) {
      _next();
    } else {
      _saveAndContinue();
    }
  }

  /// Skip the entire wizard — completes onboarding with no profiles saved.
  Future<void> _skipAll() async {
    final repo = ref.read(profileRepoProvider);
    setState(() => _isSaving = true);
    try {
      await repo.setOnboardingCompleted();
      final hasPlacement = await repo.hasCompletedPlacement();
      if (!mounted) return;
      context.go(hasPlacement ? '/' : '/placement');
    } catch (_) {
      // Best-effort — let the user retry.
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _saveAndContinue() async {
    final repo = ref.read(profileRepoProvider);

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
      final proceed = await _confirmMissingService(
        title: _l.t('onboarding.missing_llm_title'),
        body: _l.t('onboarding.missing_llm_body'),
        confirmLabel: _l.t('common.skip_for_now'),
      );
      if (proceed != true) return;
    } else if (!sttWillSave || !ttsWillSave) {
      final missing = <String>[];
      if (!sttWillSave) missing.add(_l.t('onboarding.stt_title'));
      if (!ttsWillSave) missing.add(_l.t('onboarding.tts_title'));
      final proceed = await _confirmMissingService(
        title: _l.tArg(
          'onboarding.missing_aux_title',
          {'missing': missing.join(' & ')},
        ),
        body: _l.t('onboarding.missing_aux_body'),
        confirmLabel: _l.t('common.continue'),
      );
      if (proceed != true) return;
    }

    setState(() => _isSaving = true);

    try {
      if (llmWillSave) {
        final llm = LlmProfile(
          name: _l.t('common.default_profile_name'),
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

      if (sttWillSave) {
        final stt = SttProfile(
          name: _l.t('common.default_profile_name'),
          providerId: _sttProviderId,
          baseUrl: _sttUrlController.text.trim().isEmpty
              ? sttDef.defaultBaseUrl
              : _sttUrlController.text.trim(),
          apiKey: _sttKeyController.text,
          model: sttDef.defaultModel ?? '',
          language: 'en-US',
          isActive: true,
        );
        await repo.saveSttProfile(stt);
        await repo.setActiveSttProfile(stt.id);
      }

      if (ttsWillSave) {
        final tts = TtsProfile(
          name: _l.t('common.default_profile_name'),
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

      final hasPlacement = await repo.hasCompletedPlacement();
      if (mounted) {
        context.go(hasPlacement ? '/' : '/placement');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(_l.tArg('chat.error', {'error': e.toString()}))));
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<bool?> _confirmMissingService({
    required String title,
    required String body,
    required String confirmLabel,
  }) {
    final isLight = Theme.of(context).brightness == Brightness.light;
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor:
            isLight ? AppColors.lightBgSecondary : AppColors.bgTertiary,
        title: Text(title),
        content: Text(body),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(_l.t('onboarding.go_back')),
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
