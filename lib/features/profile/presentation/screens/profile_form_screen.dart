import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/util/responsive.dart';
import '../../../../shared/providers.dart';
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

  String _providerId = '';
  double _selectedSpeed = 1.0;
  bool _isLoading = false;
  bool _isLoadingExisting = false;
  bool _isFetching = false; // models or voices
  bool _isTesting = false;
  // True when editing and the user can leave the key field blank to keep it.
  bool _hasExistingKey = false;

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

  String get _title {
    switch (widget.type) {
      case 'llm':
        return 'AI Dialogue Profile';
      case 'stt':
        return 'STT Profile';
      case 'tts':
        return 'TTS Profile';
      default:
        return 'Profile';
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
    return Scaffold(
      backgroundColor: AppColors.bgPrimary,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new),
          onPressed: () => context.pop(),
        ),
        title: Text(widget.profileId == null ? 'New $_title' : 'Edit $_title'),
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Profile Name', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: AppSpacing.xs),
        TextFormField(
          controller: _nameController,
          style: const TextStyle(color: AppColors.textPrimary),
          decoration: const InputDecoration(hintText: 'e.g., DeepSeek Main'),
          validator: (v) => (v == null || v.isEmpty) ? 'Required' : null,
        ),
      ],
    );
  }

  Widget _buildProviderPicker() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Provider', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: AppSpacing.xs),
        DropdownButtonFormField<String>(
          value: _providerId,
          dropdownColor: AppColors.bgTertiary,
          style: const TextStyle(color: AppColors.textPrimary),
          decoration: const InputDecoration(hintText: 'Select provider'),
          items: _buildProviderDropdownItems(),
          onChanged: (v) {
            if (v == null) return;
            setState(() {
              _providerId = v;
              _applyProviderDefaults(overwriteAll: true);
            });
          },
        ),
        if (_providerDef.docsUrl.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.xs),
          Text(
            'Docs: ${_providerDef.docsUrl}',
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: AppColors.accentSecondary),
          ),
        ],
      ],
    );
  }

  List<DropdownMenuItem<String>> _buildProviderDropdownItems() {
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _labelField(
          'API Base URL',
          _urlController,
          'https://api.deepseek.com/v1',
          required: true,
        ),
        const SizedBox(height: AppSpacing.lg),
        _labelField(
          'Model',
          _modelController,
          'deepseek-v4-flash',
          required: true,
        ),
        const SizedBox(height: AppSpacing.sm),
        _fetchButton(label: 'Fetch available models', onPressed: _fetchModels),
      ],
    );
  }

  Widget _buildSttFields() {
    final def = _providerDef;
    final showUrl = def.kind == ProviderKind.openaiCompatible;
    final showModel =
        def.kind == ProviderKind.openaiCompatible || _providerId == 'deepgram';
    final showRegion = _providerId == 'azure';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (showUrl)
          _labelField(
            'API Base URL',
            _urlController,
            'https://api.openai.com/v1',
            required: true,
          )
        else if (_providerId == 'custom')
          _labelField(
            'API Base URL',
            _urlController,
            'https://my-relay.example/v1',
            required: true,
          ),
        if (showUrl || _providerId == 'custom')
          const SizedBox(height: AppSpacing.lg),
        if (showModel) ...[
          _labelField('Model', _modelController, 'whisper-1'),
          const SizedBox(height: AppSpacing.lg),
        ],
        _labelField('Language (BCP-47)', _languageController, 'en-US'),
        const SizedBox(height: AppSpacing.lg),
        if (showRegion) ...[
          _labelField(
            'Azure Region',
            _regionController,
            'eastus',
            required: true,
          ),
          const SizedBox(height: AppSpacing.lg),
        ],
      ],
    );
  }

  Widget _buildTtsFields() {
    final def = _providerDef;
    final showUrl =
        def.kind == ProviderKind.openaiCompatible ||
        _providerId == 'custom' ||
        _providerId == 'fish_audio' ||
        _providerId == 'elevenlabs' ||
        _providerId == 'azure_tts' ||
        _providerId == 'google_tts' ||
        _providerId == 'aliyun_cosyvoice';
    final showRegion = _providerId == 'azure_tts';
    final canFetchVoices =
        _providerId == 'elevenlabs' ||
        _providerId == 'fish_audio' ||
        _providerId == 'azure_tts';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (showUrl)
          _labelField(
            'API Base URL',
            _urlController,
            def.defaultBaseUrl,
            required: true,
          ),
        if (showUrl) const SizedBox(height: AppSpacing.lg),
        _labelField('Model', _modelController, def.defaultModel ?? ''),
        const SizedBox(height: AppSpacing.lg),
        // Voice field + fetch button (or static dropdown for openai-compatible).
        Text('Voice', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: AppSpacing.xs),
        if (def.voices.isNotEmpty && def.kind == ProviderKind.openaiCompatible)
          _staticVoiceDropdown(def.voices)
        else
          TextFormField(
            controller: _voiceIdController,
            style: const TextStyle(color: AppColors.textPrimary),
            decoration: InputDecoration(
              hintText: def.defaultVoice ?? 'voice id',
            ),
          ),
        if (canFetchVoices) ...[
          const SizedBox(height: AppSpacing.sm),
          _fetchButton(label: 'Fetch voice list', onPressed: _fetchVoices),
        ],
        const SizedBox(height: AppSpacing.lg),
        if (showRegion) ...[
          _labelField(
            'Azure Region',
            _regionController,
            'eastus',
            required: true,
          ),
          const SizedBox(height: AppSpacing.lg),
        ],
        Text('TTS Speed', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: AppSpacing.xs),
        DropdownButtonFormField<double>(
          value: _selectedSpeed,
          dropdownColor: AppColors.bgTertiary,
          style: const TextStyle(color: AppColors.textPrimary),
          decoration: const InputDecoration(hintText: 'Select TTS speed'),
          items: const [
            DropdownMenuItem(value: 0.75, child: Text('0.75x (Slower)')),
            DropdownMenuItem(value: 1.0, child: Text('1.0x (Normal)')),
            DropdownMenuItem(value: 1.25, child: Text('1.25x (Faster)')),
            DropdownMenuItem(value: 1.5, child: Text('1.5x (Fastest)')),
          ],
          onChanged: (v) => setState(() => _selectedSpeed = v ?? 1.0),
        ),
      ],
    );
  }

  Widget _staticVoiceDropdown(List<String> voices) {
    // Keep the controller in sync with the dropdown.
    final current = _voiceIdController.text;
    final valid = voices.contains(current);
    return DropdownButtonFormField<String>(
      value: valid ? current : (voices.isNotEmpty ? voices.first : null),
      dropdownColor: AppColors.bgTertiary,
      style: const TextStyle(color: AppColors.textPrimary),
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
    String label,
    TextEditingController controller,
    String hint, {
    bool required = false,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: AppSpacing.xs),
        TextFormField(
          controller: controller,
          style: const TextStyle(color: AppColors.textPrimary),
          decoration: InputDecoration(hintText: hint),
          validator: (v) {
            if (!required) return null;
            return (v == null || v.isEmpty) ? 'Required' : null;
          },
        ),
      ],
    );
  }

  Widget _buildApiKeyField() {
    final def = _providerDef;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          def.apiKeyRequired
              ? 'API Key'
              : 'API Key (optional for this provider)',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: AppSpacing.xs),
        TextFormField(
          controller: _keyController,
          style: const TextStyle(color: AppColors.textPrimary),
          obscureText: true,
          decoration: InputDecoration(
            hintText: _hasExistingKey
                ? 'Enter new key to replace existing'
                : 'sk-...',
          ),
          validator: (v) {
            if (!def.apiKeyRequired) return null;
            if (_hasExistingKey) return null; // keep existing in edit mode
            return (v == null || v.isEmpty) ? 'Required' : null;
          },
        ),
      ],
    );
  }

  Widget _buildTestButton() {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: _isTesting ? null : _testConnection,
        icon: _isTesting
            ? const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Icon(Icons.network_check, size: 18),
        label: Text(_isTesting ? 'Testing...' : 'Test Connection'),
      ),
    );
  }

  Widget _buildSaveCancel() {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton(
            onPressed: () => context.pop(),
            child: const Text('Cancel'),
          ),
        ),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: ElevatedButton(
            onPressed: _isLoading ? null : _saveProfile,
            child: _isLoading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Save'),
          ),
        ),
      ],
    );
  }

  Widget _fetchButton({
    required String label,
    required VoidCallback onPressed,
  }) {
    return TextButton.icon(
      onPressed: _isFetching ? null : onPressed,
      icon: _isFetching
          ? const SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : const Icon(Icons.refresh, size: 16),
      label: Text(label),
    );
  }

  // ── Actions ──────────────────────────────────────────────────────────────

  Future<void> _fetchModels() async {
    final baseUrl = _urlController.text.trim();
    final apiKey = _keyController.text.trim();
    if (baseUrl.isEmpty || (apiKey.isEmpty && _providerDef.apiKeyRequired)) {
      _snack('Please fill Base URL and API Key first');
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
        _snack('No models returned. Your provider may not list models.');
        return;
      }
      final selected = await _pickFromList(
        title: 'Available Models',
        items: models,
        current: _modelController.text.trim(),
      );
      if (selected != null && mounted) {
        setState(() => _modelController.text = selected);
      }
    } catch (e) {
      if (mounted) _snack('Failed to fetch models: ${_safeError(e)}');
    } finally {
      if (mounted) setState(() => _isFetching = false);
    }
  }

  Future<void> _fetchVoices() async {
    final apiKey = _keyController.text.trim();
    if (apiKey.isEmpty && _providerDef.apiKeyRequired) {
      _snack('Please fill the API Key first');
      return;
    }
    setState(() => _isFetching = true);
    try {
      final tempProfile = _buildTempTtsProfile();
      final voices = await TtsService(tempProfile).fetchVoices();
      if (!mounted) return;
      if (voices.isEmpty) {
        _snack('No voices returned. You can still enter a voice id manually.');
        return;
      }
      final selected = await _pickFromList(
        title: 'Available Voices',
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
      if (mounted) _snack('Failed to fetch voices: ${_safeError(e)}');
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
        backgroundColor: AppColors.bgTertiary,
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
      // In edit mode with a blank key field, keep the existing key.
      String apiKey = _keyController.text;
      if (apiKey.isEmpty && _hasExistingKey && widget.profileId != null) {
        apiKey = await _existingKey();
      }
      final regionJson = _regionController.text.isEmpty
          ? null
          : '{"region":"${_regionController.text.trim()}"}';

      switch (widget.type) {
        case 'llm':
          await repo.saveLlmProfile(
            LlmProfile(
              id: widget.profileId,
              name: _nameController.text,
              providerId: _providerId,
              baseUrl: _urlController.text.trim(),
              apiKey: apiKey,
              model: _modelController.text.trim(),
            ),
          );
          break;
        case 'stt':
          await repo.saveSttProfile(
            SttProfile(
              id: widget.profileId,
              name: _nameController.text,
              providerId: _providerId,
              baseUrl: _urlController.text.trim(),
              apiKey: apiKey,
              model: _modelController.text.trim(),
              language: _languageController.text.trim().isEmpty
                  ? 'en-US'
                  : _languageController.text.trim(),
              extraConfig: regionJson,
            ),
          );
          break;
        case 'tts':
          await repo.saveTtsProfile(
            TtsProfile(
              id: widget.profileId,
              name: _nameController.text,
              providerId: _providerId,
              baseUrl: _urlController.text.trim(),
              apiKey: apiKey,
              model: _modelController.text.trim(),
              voiceId: _voiceIdController.text.trim().isEmpty
                  ? _providerDef.defaultVoice
                  : _voiceIdController.text.trim(),
              speed: _selectedSpeed,
              extraConfig: regionJson,
            ),
          );
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

  void _snack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  String _safeError(Object e) {
    final s = e.toString();
    return s.length > 160 ? '${s.substring(0, 160)}...' : s;
  }
}
