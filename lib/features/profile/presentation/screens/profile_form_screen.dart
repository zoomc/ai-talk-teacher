import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/i18n/app_localizations.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/util/responsive.dart';
import '../../../../shared/providers.dart';
import '../../data/profile_repository.dart';
import '../../domain/profile_models.dart';
import '../../domain/provider_catalog.dart';
import '../../../chat/data/llm_service.dart';
import '../../../chat/data/stt_service.dart';
import '../../../chat/data/tts_service.dart';

/// Create / edit a single LLM / STT / TTS profile.
///
/// The user picks a provider from the catalog → base URL, model and default
/// voice are auto-filled. They only need to paste an API key (and optionally a
/// region for Azure, or fetch the remote model/voice list). Test-connection and
/// fetch-models/voices buttons call the corresponding service.
class ProfileFormScreen extends ConsumerStatefulWidget {
  final String type;
  final String? profileId;
  const ProfileFormScreen({super.key, required this.type, this.profileId});

  @override
  ConsumerState<ProfileFormScreen> createState() => _ProfileFormScreenState();
}

class _ProfileFormScreenState extends ConsumerState<ProfileFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _urlController = TextEditingController();
  final _keyController = TextEditingController();
  final _modelController = TextEditingController();
  final _voiceIdController = TextEditingController();
  final _languageController = TextEditingController(text: 'en-US');
  final _regionController = TextEditingController();

  final _nameFocus = FocusNode();
  final _urlFocus = FocusNode();
  final _modelFocus = FocusNode();
  final _voiceFocus = FocusNode();
  final _languageFocus = FocusNode();
  final _regionFocus = FocusNode();
  final _keyFocus = FocusNode();

  String _providerId = '';
  double _selectedSpeed = 1.0;
  bool _isLoading = false;
  bool _isLoadingExisting = false;
  bool _isFetching = false; // models or voices
  bool _isTesting = false;
  // True when editing and the user can leave the key field blank to keep it.
  bool _hasExistingKey = false;
  bool _obscureKey = true;

  @override
  void initState() {
    super.initState();
    _providerId = _defaultProviderIdForType();
    if (widget.profileId != null) {
      _loadExistingProfile();
    } else {
      _applyProviderDefaults(overwriteAll: true);
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _urlController.dispose();
    _keyController.dispose();
    _modelController.dispose();
    _voiceIdController.dispose();
    _languageController.dispose();
    _regionController.dispose();
    _nameFocus.dispose();
    _urlFocus.dispose();
    _modelFocus.dispose();
    _voiceFocus.dispose();
    _languageFocus.dispose();
    _regionFocus.dispose();
    _keyFocus.dispose();
    super.dispose();
  }

  String _defaultProviderIdForType() {
    switch (widget.type) {
      case 'llm':
        return 'deepseek';
      case 'stt':
        return 'deepgram';
      case 'tts':
        return 'fish_audio';
      default:
        return 'custom';
    }
  }

  ProviderDef get _providerDef {
    switch (widget.type) {
      case 'llm':
        return LlmProviderCatalog.byId(_providerId);
      case 'stt':
        return SttProviderCatalog.byId(_providerId);
      case 'tts':
        return TtsProviderCatalog.byId(_providerId);
      default:
        return LlmProviderCatalog.byId(LlmProviderCatalog.customId);
    }
  }

  String _title(AppLocalizations l) {
    switch (widget.type) {
      case 'llm':
        return l.t('profile.llm_title');
      case 'stt':
        return l.t('profile.stt_title');
      case 'tts':
        return l.t('profile.tts_title');
      default:
        return l.t('profile.profile_name');
    }
  }

  /// Apply the current provider's catalog defaults to the form fields.
  ///
  /// When [overwriteAll] is true (provider change / new profile), every
  /// catalog-controlled field is reset. When false (loading an existing
  /// profile), nothing is overwritten — the profile's stored values win.
  void _applyProviderDefaults({required bool overwriteAll}) {
    if (!overwriteAll) return;
    final def = _providerDef;
    _urlController.text = def.defaultBaseUrl;
    _modelController.text = def.defaultModel ?? '';
    if (widget.type == 'tts') {
      _voiceIdController.text = def.defaultVoice ?? '';
    }
    // Region placeholder for Azure.
    if (_providerId == 'azure' || _providerId == 'azure_tts') {
      if (_regionController.text.isEmpty) _regionController.text = 'eastus';
    } else {
      _regionController.clear();
    }
  }

  Future<void> _loadExistingProfile() async {
    setState(() => _isLoadingExisting = true);
    final repo = ref.read(profileRepoProvider);
    try {
      switch (widget.type) {
        case 'llm':
          final all = await repo.getAllLlmProfiles();
          final p = all.where((x) => x.id == widget.profileId).firstOrNull;
          if (p != null && mounted) {
            _nameController.text = p.name;
            _providerId = p.providerId;
            _urlController.text = p.baseUrl;
            _modelController.text = p.model;
            _keyController.text = p.apiKey;
            _hasExistingKey = p.apiKey.isNotEmpty;
          }
          break;
        case 'stt':
          final all = await repo.getAllSttProfiles();
          final p = all.where((x) => x.id == widget.profileId).firstOrNull;
          if (p != null && mounted) {
            _nameController.text = p.name;
            _providerId = p.providerId;
            _urlController.text = p.baseUrl;
            _modelController.text = p.model;
            _languageController.text = p.language;
            _regionController.text = p.region;
            _keyController.text = p.apiKey;
            _hasExistingKey = p.apiKey.isNotEmpty;
          }
          break;
        case 'tts':
          final all = await repo.getAllTtsProfiles();
          final p = all.where((x) => x.id == widget.profileId).firstOrNull;
          if (p != null && mounted) {
            _nameController.text = p.name;
            _providerId = p.providerId;
            _urlController.text = p.baseUrl;
            _modelController.text = p.model;
            _voiceIdController.text = p.voiceId ?? '';
            _regionController.text = p.region;
            _selectedSpeed = p.speed;
            _keyController.text = p.apiKey;
            _hasExistingKey = p.apiKey.isNotEmpty;
          }
          break;
      }
    } catch (_) {
      // Ignore load errors — user can still fill the form manually.
    } finally {
      if (mounted) setState(() => _isLoadingExisting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isLight = Theme.of(context).brightness == Brightness.light;
    return Scaffold(
      backgroundColor: isLight ? AppColors.lightBgPrimary : AppColors.bgPrimary,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new),
          onPressed: () => context.pop(),
        ),
        title: Builder(
          builder: (context) {
            final l = AppLocalizations.of(context);
            return Text(
              widget.profileId == null
                  ? l.tArg('profile.new_title', {'title': _title(l)})
                  : l.tArg('profile.edit_title', {'title': _title(l)}),
            );
          },
        ),
      ),
      body: _isLoadingExisting
          ? const Center(child: CircularProgressIndicator())
          : SafeArea(
              // bottom:true keeps Save/Cancel out from behind the home
              // indicator; the keyboard inset (below) keeps them above
              // the soft keyboard.
              top: false,
              child: Center(
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    maxWidth: Responsive.contentMaxWidth(context),
                  ),
                  child: SingleChildScrollView(
                    // Scaffold's `resizeToAvoidBottomInset: true` (the
                    // default) already shrinks the body to clear the
                    // soft keyboard, so we just need normal bottom
                    // padding here — adding viewInsets.bottom would
                    // double-count and leave the Save button floating
                    // ~300pt above the keyboard.
                    padding: const EdgeInsets.all(AppSpacing.lg),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildNameField(),
                          const SizedBox(height: AppSpacing.lg),
                          _buildProviderPicker(),
                          if (_providerDef.note != null) ...[
                            const SizedBox(height: AppSpacing.sm),
                            _buildNote(_providerDef.note!),
                          ],
                          const SizedBox(height: AppSpacing.lg),
                          _buildTypeSpecificFields(),
                          const SizedBox(height: AppSpacing.lg),
                          _buildApiKeyField(),
                          const SizedBox(height: AppSpacing.lg),
                          _buildTestButton(),
                          const SizedBox(height: AppSpacing.xxl),
                          _buildSaveCancel(),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
    );
  }

  // ── Field builders ───────────────────────────────────────────────────────

  Widget _buildNameField() {
    final l = AppLocalizations.of(context);
    return TextFormField(
      controller: _nameController,
      focusNode: _nameFocus,
      textInputAction: TextInputAction.next,
      onFieldSubmitted: (_) => _urlFocus.requestFocus(),
      style: const TextStyle(color: AppColors.textPrimary),
      decoration: InputDecoration(
        labelText: l.t('profile.profile_name'),
        hintText: l.t('profile.name_hint'),
      ),
      validator: (v) {
        if (v == null || v.isEmpty) return l.t('profile.name_required');
        return null;
      },
    );
  }

  Widget _buildProviderPicker() {
    final l = AppLocalizations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        DropdownButtonFormField<String>(
          value: _providerId,
          dropdownColor: Theme.of(context).brightness == Brightness.light
              ? AppColors.lightBgTertiary
              : AppColors.bgTertiary,
          style: TextStyle(
            color: Theme.of(context).brightness == Brightness.light
                ? AppColors.lightTextPrimary
                : AppColors.textPrimary,
          ),
          decoration: InputDecoration(
            labelText: l.t('profile.provider'),
            hintText: l.t('profile.select_provider'),
          ),
          items: _buildProviderDropdownItems(),
          onChanged: (v) {
            if (v == null) return;
            setState(() {
              _providerId = v;
              _applyProviderDefaults(overwriteAll: true);
            });
            // BL-098: warn when the user picks an experimental provider that
            // needs a custom relay adapter.
            if (_providerDef.experimental && mounted) {
              _snack(l.t('profile.experimental_provider'));
            }
          },
        ),
        if (_providerDef.docsUrl.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.xs),
          Text(
            l.tArg('profile.docs_prefix', {'url': _providerDef.docsUrl}),
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: AppColors.accentSecondary),
          ),
        ],
      ],
    );
  }

  List<DropdownMenuItem<String>> _buildProviderDropdownItems() {
    final l = AppLocalizations.of(context);
    final List<ProviderDef> defs;
    switch (widget.type) {
      case 'llm':
        defs = LlmProviderCatalog.all;
        break;
      case 'stt':
        defs = SttProviderCatalog.all;
        break;
      case 'tts':
        defs = TtsProviderCatalog.all;
        break;
      default:
        defs = LlmProviderCatalog.all;
    }
    // Group by region for readability.
    final byRegion = <ProviderRegion, List<ProviderDef>>{};
    for (final d in defs) {
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
      // UX-031: use a non-selectable header with a divider so it is visually
      // distinct from real provider options.
      items.add(
        DropdownMenuItem<String>(
          enabled: false,
          value: '_header_${region.name}',
          child: IgnorePointer(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  l.t('provider_region.${region.name}'),
                  style: TextStyle(
                    color: AppColors.accentSecondary,
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                  ),
                ),
                const Divider(height: 8),
              ],
            ),
          ),
        ),
      );
      for (final d in list) {
        items.add(
          DropdownMenuItem<String>(
            value: d.id,
            child: Text(
              d.experimental ? '${d.displayName} ⚠️' : d.displayName,
              style: d.experimental
                  ? const TextStyle(color: AppColors.warning)
                  : null,
            ),
          ),
        );
      }
    }
    return items;
  }

  Widget _buildNote(String note) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: BoxDecoration(
        color: AppColors.accentPrimary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(AppRadius.sm),
        border: Border.all(
          color: AppColors.accentPrimary.withValues(alpha: 0.2),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline, size: 16, color: AppColors.accentPrimary),
          const SizedBox(width: AppSpacing.xs),
          Expanded(
            child: Text(
              note,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: AppColors.textSecondary,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTypeSpecificFields() {
    switch (widget.type) {
      case 'llm':
        return _buildLlmFields();
      case 'stt':
        return _buildSttFields();
      case 'tts':
        return _buildTtsFields();
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _buildLlmFields() {
    final l = AppLocalizations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _labelField(
          'profile.base_url',
          _urlController,
          hintText: l.t('profile.custom_url_hint'),
          required: true,
          focusNode: _urlFocus,
          textInputAction: TextInputAction.next,
          onSubmitted: () => _modelFocus.requestFocus(),
          keyboardType: TextInputType.url,
          autocorrect: false,
          requiredKey: 'profile.base_url_required',
        ),
        const SizedBox(height: AppSpacing.lg),
        _labelField(
          'profile.model',
          _modelController,
          hintText: 'deepseek-v4-flash',
          required: true,
          focusNode: _modelFocus,
          textInputAction: TextInputAction.next,
          onSubmitted: () => _keyFocus.requestFocus(),
          requiredKey: 'profile.required',
        ),
        const SizedBox(height: AppSpacing.sm),
        _fetchButton(labelKey: 'profile.fetch_models', onPressed: _fetchModels),
      ],
    );
  }

  Widget _buildSttFields() {
    final l = AppLocalizations.of(context);
    final def = _providerDef;
    final showModel =
        def.kind == ProviderKind.openaiCompatible || _providerId == 'deepgram';
    final showRegion = _providerId == 'azure';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _labelField(
          'profile.base_url',
          _urlController,
          hintText: l.t('profile.custom_url_hint'),
          required: true,
          focusNode: _urlFocus,
          textInputAction: TextInputAction.next,
          onSubmitted: () => _modelFocus.requestFocus(),
          keyboardType: TextInputType.url,
          autocorrect: false,
          requiredKey: 'profile.base_url_required',
        ),
        const SizedBox(height: AppSpacing.lg),
        if (showModel) ...[
          _labelField(
            'profile.model',
            _modelController,
            hintText: 'whisper-1',
            focusNode: _modelFocus,
            textInputAction: TextInputAction.next,
            onSubmitted: () => _languageFocus.requestFocus(),
          ),
          const SizedBox(height: AppSpacing.lg),
        ],
        _labelField(
          'profile.language_bcp47',
          _languageController,
          hintText: 'en-US',
          focusNode: _languageFocus,
          textInputAction: TextInputAction.next,
          onSubmitted: () {
            if (showRegion) {
              _regionFocus.requestFocus();
            } else {
              _keyFocus.requestFocus();
            }
          },
        ),
        const SizedBox(height: AppSpacing.lg),
        if (showRegion) ...[
          _labelField(
            'profile.azure_region',
            _regionController,
            hintText: 'eastus',
            required: true,
            focusNode: _regionFocus,
            textInputAction: TextInputAction.next,
            onSubmitted: () => _keyFocus.requestFocus(),
            requiredKey: 'profile.required',
          ),
          const SizedBox(height: AppSpacing.lg),
        ],
      ],
    );
  }

  Widget _buildTtsFields() {
    final l = AppLocalizations.of(context);
    final def = _providerDef;
    final showRegion = _providerId == 'azure_tts';
    final canFetchVoices =
        _providerId == 'elevenlabs' ||
        _providerId == 'fish_audio' ||
        _providerId == 'azure_tts';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildReuseSttButton(),
        const SizedBox(height: AppSpacing.lg),
        _labelField(
          'profile.base_url',
          _urlController,
          hintText: l.t('profile.custom_url_hint'),
          required: true,
          focusNode: _urlFocus,
          textInputAction: TextInputAction.next,
          onSubmitted: () => _modelFocus.requestFocus(),
          keyboardType: TextInputType.url,
          autocorrect: false,
          requiredKey: 'profile.base_url_required',
        ),
        const SizedBox(height: AppSpacing.lg),
        _labelField(
          'profile.model',
          _modelController,
          hintText: def.defaultModel ?? '',
          focusNode: _modelFocus,
          textInputAction: TextInputAction.next,
          onSubmitted: () => _voiceFocus.requestFocus(),
        ),
        const SizedBox(height: AppSpacing.lg),
        // Voice field + fetch button (or static dropdown for openai-compatible).
        Text(
          l.t('profile.voice'),
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: AppSpacing.xs),
        if (def.voices.isNotEmpty && def.kind == ProviderKind.openaiCompatible)
          _staticVoiceDropdown(def.voices)
        else
          TextFormField(
            controller: _voiceIdController,
            focusNode: _voiceFocus,
            textInputAction: TextInputAction.next,
            onFieldSubmitted: (_) {
              if (showRegion) {
                _regionFocus.requestFocus();
              } else {
                _keyFocus.requestFocus();
              }
            },
            style: const TextStyle(color: AppColors.textPrimary),
            decoration: InputDecoration(
              hintText: def.defaultVoice ?? 'voice id',
            ),
          ),
        if (canFetchVoices) ...[
          const SizedBox(height: AppSpacing.sm),
          _fetchButton(
            labelKey: 'profile.fetch_voices',
            onPressed: _fetchVoices,
          ),
        ],
        const SizedBox(height: AppSpacing.lg),
        if (showRegion) ...[
          _labelField(
            'profile.azure_region',
            _regionController,
            hintText: 'eastus',
            required: true,
            focusNode: _regionFocus,
            textInputAction: TextInputAction.next,
            onSubmitted: () => _keyFocus.requestFocus(),
            requiredKey: 'profile.required',
          ),
          const SizedBox(height: AppSpacing.lg),
        ],
        Text(
          l.t('profile.tts_speed'),
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: AppSpacing.xs),
        DropdownButtonFormField<double>(
          value: _selectedSpeed,
          dropdownColor: Theme.of(context).brightness == Brightness.light
              ? AppColors.lightBgTertiary
              : AppColors.bgTertiary,
          style: TextStyle(
            color: Theme.of(context).brightness == Brightness.light
                ? AppColors.lightTextPrimary
                : AppColors.textPrimary,
          ),
          decoration: InputDecoration(
            labelText: l.t('profile.tts_speed'),
            hintText: l.t('profile.select_provider'),
          ),
          items: [
            DropdownMenuItem(
              value: 0.75,
              child: Text(l.t('profile.speed_slower')),
            ),
            DropdownMenuItem(
              value: 1.0,
              child: Text(l.t('profile.speed_normal')),
            ),
            DropdownMenuItem(
              value: 1.25,
              child: Text(l.t('profile.speed_faster')),
            ),
            DropdownMenuItem(
              value: 1.5,
              child: Text(l.t('profile.speed_fastest')),
            ),
          ],
          onChanged: (v) => setState(() => _selectedSpeed = v ?? 1.0),
        ),
      ],
    );
  }

  Widget _buildReuseSttButton() {
    final l = AppLocalizations.of(context);
    return Align(
      alignment: Alignment.centerLeft,
      child: TextButton.icon(
        style: TextButton.styleFrom(minimumSize: const Size.fromHeight(44)),
        onPressed: _reuseSttConfig,
        icon: const Icon(Icons.copy, size: 18),
        label: Text(l.t('profile.reuse_stt')),
      ),
    );
  }

  Future<void> _reuseSttConfig() async {
    final l = AppLocalizations.of(context);
    final repo = ref.read(profileRepoProvider);
    try {
      final all = await repo.getAllSttProfiles();
      final stt = all.where((p) => p.isActive).firstOrNull;
      if (stt == null) {
        if (mounted) _snack(l.t('profile.reuse_stt_none'));
        return;
      }
      const sttToTts = {
        'deepgram': 'deepgram_tts',
        'azure': 'azure_tts',
        'google': 'google_tts',
        'siliconflow_stt': 'siliconflow_tts',
        'openai_whisper': 'openai_tts',
        'custom': 'custom',
      };
      final mapped = sttToTts[stt.providerId] ?? 'custom';
      final exists = TtsProviderCatalog.all.any((p) => p.id == mapped);
      final newProviderId = exists ? mapped : 'custom';
      setState(() {
        _providerId = newProviderId;
        _urlController.text = stt.baseUrl;
        _keyController.text = stt.apiKey;
        _applyProviderDefaults(overwriteAll: false);
      });
      if (mounted) _snack(l.t('profile.reuse_stt_copied'));
    } catch (e) {
      if (mounted)
        _snack(l.tArg('profile.reuse_stt_failed', {'error': _safeError(e)}));
    }
  }

  Widget _staticVoiceDropdown(List<String> voices) {
    // Keep the controller in sync with the dropdown.
    final current = _voiceIdController.text;
    final valid = voices.contains(current);
    return DropdownButtonFormField<String>(
      initialValue: valid ? current : (voices.isNotEmpty ? voices.first : null),
      dropdownColor: Theme.of(context).brightness == Brightness.light
          ? AppColors.lightBgTertiary
          : AppColors.bgTertiary,
      style: TextStyle(
        color: Theme.of(context).brightness == Brightness.light
            ? AppColors.lightTextPrimary
            : AppColors.textPrimary,
      ),
      decoration: const InputDecoration(hintText: 'Select voice'),
      items: voices
          .map((v) => DropdownMenuItem<String>(value: v, child: Text(v)))
          .toList(),
      onChanged: (v) {
        if (v != null) setState(() => _voiceIdController.text = v);
      },
    );
  }

  Widget _labelField(
    String labelKey,
    TextEditingController controller, {
    String? hintText,
    bool required = false,
    FocusNode? focusNode,
    TextInputAction? textInputAction,
    VoidCallback? onSubmitted,
    TextInputType? keyboardType,
    bool autocorrect = true,
    String? requiredKey,
  }) {
    final l = AppLocalizations.of(context);
    return TextFormField(
      controller: controller,
      focusNode: focusNode,
      textInputAction: textInputAction,
      onFieldSubmitted: (_) => onSubmitted?.call(),
      keyboardType: keyboardType,
      autocorrect: autocorrect,
      style: const TextStyle(color: AppColors.textPrimary),
      decoration: InputDecoration(labelText: l.t(labelKey), hintText: hintText),
      validator: (v) {
        if (!required) return null;
        if (v == null || v.isEmpty) {
          return requiredKey == null
              ? l.t('profile.required')
              : l.t(requiredKey);
        }
        return null;
      },
    );
  }

  Widget _buildApiKeyField() {
    final l = AppLocalizations.of(context);
    final def = _providerDef;
    return TextFormField(
      controller: _keyController,
      focusNode: _keyFocus,
      textInputAction: TextInputAction.done,
      onFieldSubmitted: (_) => _saveProfile(),
      style: const TextStyle(color: AppColors.textPrimary),
      obscureText: _obscureKey,
      decoration: InputDecoration(
        labelText: def.apiKeyRequired
            ? l.t('profile.api_key')
            : l.t('profile.api_key_optional'),
        hintText: _hasExistingKey
            ? l.t('profile.replace_key_hint')
            : l.t('profile.api_key_hint'),
        suffixIcon: IconButton(
          icon: Icon(
            _obscureKey
                ? Icons.visibility_outlined
                : Icons.visibility_off_outlined,
          ),
          tooltip: _obscureKey
              ? l.t('profile.show_key')
              : l.t('profile.hide_key'),
          onPressed: () => setState(() => _obscureKey = !_obscureKey),
        ),
      ),
      validator: (v) {
        if (!def.apiKeyRequired) return null;
        if (_hasExistingKey) return null; // keep existing in edit mode
        if (v == null || v.isEmpty) return l.t('profile.api_key_required');
        return null;
      },
    );
  }

  Widget _buildTestButton() {
    final l = AppLocalizations.of(context);
    return SizedBox(
      width: double.infinity,
      height: 44,
      child: OutlinedButton.icon(
        onPressed: _isTesting ? null : _testConnection,
        icon: _isTesting
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2.5),
              )
            : const Icon(Icons.network_check, size: 18),
        label: Text(
          _isTesting ? l.t('profile.testing') : l.t('service.test_connection'),
        ),
      ),
    );
  }

  Widget _buildSaveCancel() {
    final l = AppLocalizations.of(context);
    return Row(
      children: [
        Expanded(
          child: SizedBox(
            height: 48,
            child: OutlinedButton(
              onPressed: () => context.pop(),
              child: Text(l.t('profile.cancel')),
            ),
          ),
        ),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: SizedBox(
            height: 48,
            child: ElevatedButton(
              onPressed: _isLoading ? null : _saveProfile,
              child: _isLoading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(l.t('profile.save')),
            ),
          ),
        ),
      ],
    );
  }

  Widget _fetchButton({
    required String labelKey,
    required VoidCallback onPressed,
  }) {
    final l = AppLocalizations.of(context);
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 44),
      child: TextButton.icon(
        onPressed: _isFetching ? null : onPressed,
        icon: _isFetching
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Icon(Icons.refresh, size: 18),
        label: Text(l.t(labelKey)),
      ),
    );
  }

  // ── Actions ──────────────────────────────────────────────────────────────

  Future<void> _fetchModels() async {
    final l = AppLocalizations.of(context);
    final baseUrl = _urlController.text.trim();
    final apiKey = _keyController.text.trim();
    if (baseUrl.isEmpty || (apiKey.isEmpty && _providerDef.apiKeyRequired)) {
      _snack(l.t('profile.fill_base_url_and_key'));
      return;
    }
    setState(() => _isFetching = true);
    try {
      final tempProfile = LlmProfile(
        name: '_temp',
        providerId: _providerId,
        baseUrl: baseUrl,
        apiKey: apiKey,
        model: _modelController.text.trim().isEmpty
            ? 'gpt-3.5-turbo'
            : _modelController.text.trim(),
      );
      final models = await LlmService(tempProfile).fetchModels();
      if (!mounted) return;
      if (models.isEmpty) {
        _snack(l.t('profile.no_models'));
        return;
      }
      final selected = await _pickFromList(
        title: l.t('profile.available_models'),
        items: models,
        current: _modelController.text.trim(),
      );
      if (selected != null && mounted) {
        setState(() => _modelController.text = selected);
      }
    } catch (e) {
      if (mounted)
        _snack(l.tArg('profile.fetch_models_failed', {'error': _safeError(e)}));
    } finally {
      if (mounted) setState(() => _isFetching = false);
    }
  }

  Future<void> _fetchVoices() async {
    final l = AppLocalizations.of(context);
    final apiKey = _keyController.text.trim();
    if (apiKey.isEmpty && _providerDef.apiKeyRequired) {
      _snack(l.t('profile.fill_api_key'));
      return;
    }
    setState(() => _isFetching = true);
    try {
      final tempProfile = _buildTempTtsProfile();
      final voices = await TtsService(tempProfile).fetchVoices();
      if (!mounted) return;
      if (voices.isEmpty) {
        _snack(l.t('profile.no_voices'));
        return;
      }
      final selected = await _pickFromList(
        title: l.t('profile.available_voices'),
        items: voices.map((v) => v.name).toList(),
        current: _voiceIdController.text.trim(),
      );
      if (selected != null && mounted) {
        final match = voices.firstWhere(
          (v) => v.name == selected,
          orElse: () => voices.first,
        );
        setState(() {
          _voiceIdController.text = match.id;
        });
      }
    } catch (e) {
      if (mounted)
        _snack(l.tArg('profile.fetch_voices_failed', {'error': _safeError(e)}));
    } finally {
      if (mounted) setState(() => _isFetching = false);
    }
  }

  TtsProfile _buildTempTtsProfile() {
    return TtsProfile(
      name: '_temp',
      providerId: _providerId,
      baseUrl: _urlController.text.trim(),
      apiKey: _keyController.text.trim(),
      model: _modelController.text.trim(),
      voiceId: _voiceIdController.text.trim().isEmpty
          ? _providerDef.defaultVoice
          : _voiceIdController.text.trim(),
      speed: _selectedSpeed,
      extraConfig: _regionController.text.isEmpty
          ? null
          : '{"region":"${_regionController.text.trim()}"}',
    );
  }

  Future<String?> _pickFromList({
    required String title,
    required List<String> items,
    required String current,
  }) {
    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Theme.of(context).brightness == Brightness.light
            ? AppColors.lightBgTertiary
            : AppColors.bgTertiary,
        title: Text(title),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: items.length,
            itemBuilder: (ctx, i) {
              final m = items[i];
              return ListTile(
                title: Text(m),
                trailing: current == m
                    ? const Icon(
                        Icons.check,
                        color: AppColors.accentPrimary,
                        size: 18,
                      )
                    : null,
                onTap: () => Navigator.pop(ctx, m),
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }

  Future<void> _testConnection() async {
    final baseUrl = _urlController.text.trim();
    final apiKey = _keyController.text.trim();
    if (baseUrl.isEmpty && _providerDef.kind == ProviderKind.openaiCompatible) {
      _snack('Please fill the Base URL first');
      return;
    }
    if (apiKey.isEmpty && _providerDef.apiKeyRequired && !_hasExistingKey) {
      _snack('Please fill the API Key first');
      return;
    }
    setState(() => _isTesting = true);
    final stopwatch = Stopwatch()..start();
    String result;
    try {
      final effectiveKey = apiKey.isEmpty && _hasExistingKey
          ? await _existingKey()
          : apiKey;
      switch (widget.type) {
        case 'llm':
          final tempProfile = LlmProfile(
            name: '_temp',
            providerId: _providerId,
            baseUrl: baseUrl,
            apiKey: effectiveKey,
            model: _modelController.text.trim().isEmpty
                ? 'gpt-3.5-turbo'
                : _modelController.text.trim(),
          );
          final count = await LlmService(tempProfile).testConnection();
          result =
              '✓ Connected (${stopwatch.elapsedMilliseconds}ms, $count models)';
          break;
        case 'stt':
          final tempProfile = SttProfile(
            name: '_temp',
            providerId: _providerId,
            baseUrl: baseUrl,
            apiKey: effectiveKey,
            model: _modelController.text.trim(),
            language: _languageController.text.trim().isEmpty
                ? 'en-US'
                : _languageController.text.trim(),
            extraConfig: _regionController.text.isEmpty
                ? null
                : '{"region":"${_regionController.text.trim()}"}',
          );
          await SttService(tempProfile).testConnection();
          result = '✓ Connected (${stopwatch.elapsedMilliseconds}ms)';
          break;
        case 'tts':
          await TtsService(_buildTempTtsProfile()).testConnection();
          result = '✓ Connected (${stopwatch.elapsedMilliseconds}ms)';
          break;
        default:
          result = '✗ Unknown profile type';
      }
    } catch (e) {
      result = '✗ ${_safeError(e)}';
    } finally {
      if (mounted) setState(() => _isTesting = false);
    }
    if (mounted) _snack(result);
  }

  Future<String> _existingKey() async {
    final repo = ref.read(profileRepoProvider);
    switch (widget.type) {
      case 'llm':
        final all = await repo.getAllLlmProfiles();
        return all.where((x) => x.id == widget.profileId).firstOrNull?.apiKey ??
            '';
      case 'stt':
        final all = await repo.getAllSttProfiles();
        return all.where((x) => x.id == widget.profileId).firstOrNull?.apiKey ??
            '';
      case 'tts':
        final all = await repo.getAllTtsProfiles();
        return all.where((x) => x.id == widget.profileId).firstOrNull?.apiKey ??
            '';
      default:
        return '';
    }
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);
    final repo = ref.read(profileRepoProvider);
    try {
      // Trim user input to avoid leading/trailing spaces or pasted newlines
      // breaking subsequent API calls (BL-084).
      final name = _nameController.text.trim();
      final baseUrl = _urlController.text.trim();
      final model = _modelController.text.trim();
      final voiceId = _voiceIdController.text.trim();
      final language = _languageController.text.trim();
      final region = _regionController.text.trim();

      // In edit mode with a blank key field, keep the existing key.
      String apiKey = _keyController.text.trim();
      if (apiKey.isEmpty && _hasExistingKey && widget.profileId != null) {
        apiKey = await _existingKey();
      }

      // Build extraConfig with proper JSON escaping (BL-089).
      final regionJson = region.isEmpty ? null : jsonEncode({'region': region});

      switch (widget.type) {
        case 'llm':
          final profile = LlmProfile(
            id: widget.profileId,
            name: name,
            providerId: _providerId,
            baseUrl: baseUrl,
            apiKey: apiKey,
            model: model,
          );
          await repo.saveLlmProfile(profile);
          await _maybeActivateOnFirstSave(repo, profile.id);
          break;
        case 'stt':
          final profile = SttProfile(
            id: widget.profileId,
            name: name,
            providerId: _providerId,
            baseUrl: baseUrl,
            apiKey: apiKey,
            model: model,
            language: language.isEmpty ? 'en-US' : language,
            extraConfig: regionJson,
          );
          await repo.saveSttProfile(profile);
          await _maybeActivateOnFirstSave(repo, profile.id);
          break;
        case 'tts':
          final profile = TtsProfile(
            id: widget.profileId,
            name: name,
            providerId: _providerId,
            baseUrl: baseUrl,
            apiKey: apiKey,
            model: model,
            voiceId: voiceId.isEmpty ? _providerDef.defaultVoice : voiceId,
            speed: _selectedSpeed,
            extraConfig: regionJson,
          );
          await repo.saveTtsProfile(profile);
          await _maybeActivateOnFirstSave(repo, profile.id);
          break;
      }
      if (mounted) {
        _snack('Profile saved!');
        context.pop();
      }
    } catch (e) {
      if (mounted) _snack('Error: ${_safeError(e)}');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  /// If this is the first profile of its type, automatically activate it
  /// so the user isn't left with no active service (BL-085).
  Future<void> _maybeActivateOnFirstSave(
    ProfileRepository repo,
    String id,
  ) async {
    switch (widget.type) {
      case 'llm':
        final active = await repo.getActiveLlmProfile();
        if (active == null) await repo.setActiveLlmProfile(id);
        break;
      case 'stt':
        final active = await repo.getActiveSttProfile();
        if (active == null) await repo.setActiveSttProfile(id);
        break;
      case 'tts':
        final active = await repo.getActiveTtsProfile();
        if (active == null) await repo.setActiveTtsProfile(id);
        break;
    }
  }

  void _snack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  String _safeError(Object e) {
    final s = e.toString();
    return s.length > 160 ? '${s.substring(0, 160)}...' : s;
  }
}
