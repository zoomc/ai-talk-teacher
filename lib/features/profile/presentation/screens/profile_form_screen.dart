import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../shared/providers.dart';
import '../../domain/profile_models.dart';
import '../../../chat/data/llm_service.dart';

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

  SttProvider? _selectedSttProvider;
  TtsProvider? _selectedTtsProvider;
  bool _isLoading = false;
  bool _isLoadingExisting = false;
  bool _isFetchingModels = false;
  double _selectedSpeed = 1.0;
  // Track whether we have an existing API key (so user can keep it unchanged)
  bool _hasExistingKey = false;

  @override
  void initState() {
    super.initState();
    if (widget.type == 'llm') {
      _urlController.text = 'https://api.deepseek.com';
    }
    if (widget.profileId != null) {
      _loadExistingProfile();
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _urlController.dispose();
    _keyController.dispose();
    _modelController.dispose();
    super.dispose();
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

  // B5: Load existing profile data when editing.
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
            _selectedSttProvider = p.provider;
            _keyController.text = p.apiKey;
            _hasExistingKey = p.apiKey.isNotEmpty;
          }
          break;
        case 'tts':
          final all = await repo.getAllTtsProfiles();
          final p = all.where((x) => x.id == widget.profileId).firstOrNull;
          if (p != null && mounted) {
            _nameController.text = p.name;
            _selectedTtsProvider = p.provider;
            _keyController.text = p.apiKey;
            _hasExistingKey = p.apiKey.isNotEmpty;
            _selectedSpeed = p.speed;
          }
          break;
      }
    } catch (e) {
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
          : SingleChildScrollView(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Name
                    Text('Profile Name', style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: AppSpacing.xs),
                    TextFormField(
                      controller: _nameController,
                      style: const TextStyle(color: AppColors.textPrimary),
                      decoration: const InputDecoration(hintText: 'e.g., DeepSeek Main'),
                      validator: (v) => v == null || v.isEmpty ? 'Required' : null,
                    ),

                    if (widget.type == 'llm') ...[
                      const SizedBox(height: AppSpacing.lg),
                      Text('API Base URL', style: Theme.of(context).textTheme.titleMedium),
                      const SizedBox(height: AppSpacing.xs),
                      TextFormField(
                        controller: _urlController,
                        style: const TextStyle(color: AppColors.textPrimary),
                        decoration: const InputDecoration(hintText: 'https://api.deepseek.com'),
                        validator: (v) => v == null || v.isEmpty ? 'Required' : null,
                      ),
                    ],

                    if (widget.type == 'stt') ...[
                      const SizedBox(height: AppSpacing.lg),
                      Text('Provider', style: Theme.of(context).textTheme.titleMedium),
                      const SizedBox(height: AppSpacing.xs),
                      DropdownButtonFormField<SttProvider>(
                        initialValue: _selectedSttProvider,
                        dropdownColor: AppColors.bgTertiary,
                        style: const TextStyle(color: AppColors.textPrimary),
                        decoration: const InputDecoration(hintText: 'Select STT provider'),
                        items: SttProvider.values.map((p) {
                          String label;
                          switch (p) {
                            case SttProvider.deepgram:
                              label = 'Deepgram (Recommended)';
                              break;
                            case SttProvider.openaiWhisper:
                              label = 'OpenAI Whisper';
                              break;
                            case SttProvider.googleCloud:
                              label = 'Google Cloud Speech';
                              break;
                            case SttProvider.azure:
                              label = 'Azure Speech';
                              break;
                          }
                          return DropdownMenuItem(value: p, child: Text(label));
                        }).toList(),
                        onChanged: (v) => setState(() => _selectedSttProvider = v),
                        validator: (v) => v == null ? 'Required' : null,
                      ),
                    ],

                    if (widget.type == 'tts') ...[
                      const SizedBox(height: AppSpacing.lg),
                      Text('Provider', style: Theme.of(context).textTheme.titleMedium),
                      const SizedBox(height: AppSpacing.xs),
                      DropdownButtonFormField<TtsProvider>(
                        initialValue: _selectedTtsProvider,
                        dropdownColor: AppColors.bgTertiary,
                        style: const TextStyle(color: AppColors.textPrimary),
                        decoration: const InputDecoration(hintText: 'Select TTS provider'),
                        items: TtsProvider.values.map((p) {
                          String label;
                          switch (p) {
                            case TtsProvider.fishAudio:
                              label = 'Fish Audio (Recommended)';
                              break;
                            case TtsProvider.elevenLabs:
                              label = 'ElevenLabs';
                              break;
                            case TtsProvider.openaiTts:
                              label = 'OpenAI TTS';
                              break;
                            case TtsProvider.azure:
                              label = 'Azure TTS';
                              break;
                          }
                          return DropdownMenuItem(value: p, child: Text(label));
                        }).toList(),
                        onChanged: (v) => setState(() => _selectedTtsProvider = v),
                        validator: (v) => v == null ? 'Required' : null,
                      ),
                      const SizedBox(height: AppSpacing.lg),
                      Text('TTS Speed', style: Theme.of(context).textTheme.titleMedium),
                      const SizedBox(height: AppSpacing.xs),
                      DropdownButtonFormField<double>(
                        initialValue: _selectedSpeed,
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

                    const SizedBox(height: AppSpacing.lg),
                    Text('API Key', style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: AppSpacing.xs),
                    TextFormField(
                      controller: _keyController,
                      style: const TextStyle(color: AppColors.textPrimary),
                      obscureText: true,
                      decoration: InputDecoration(
                        hintText: _hasExistingKey ? 'Enter new key to replace existing' : 'sk-...',
                      ),
                      validator: (v) {
                        // Allow empty in edit mode if existing key present.
                        if (_hasExistingKey) return null;
                        if (v == null || v.isEmpty) return 'Required';
                        return null;
                      },
                    ),

                    if (widget.type == 'llm') ...[
                      const SizedBox(height: AppSpacing.lg),
                      Text('Model', style: Theme.of(context).textTheme.titleMedium),
                      const SizedBox(height: AppSpacing.xs),
                      TextFormField(
                        controller: _modelController,
                        style: const TextStyle(color: AppColors.textPrimary),
                        decoration: const InputDecoration(hintText: 'e.g., deepseek-chat'),
                        validator: (v) => v == null || v.isEmpty ? 'Required' : null,
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      TextButton.icon(
                        onPressed: _isFetchingModels ? null : _fetchModels,
                        icon: _isFetchingModels
                            ? const SizedBox(
                                width: 14,
                                height: 14,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.refresh, size: 16),
                        label: const Text('Fetch available models'),
                      ),
                    ],

                    const SizedBox(height: AppSpacing.xxl),
                    Row(
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
                                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                                : const Text('Save'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  // B6: Real implementation of fetch models.
  Future<void> _fetchModels() async {
    final baseUrl = _urlController.text.trim();
    final apiKey = _keyController.text.trim();
    if (baseUrl.isEmpty || apiKey.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill Base URL and API Key first')),
      );
      return;
    }

    setState(() => _isFetchingModels = true);
    try {
      final tempProfile = LlmProfile(
        name: '_temp',
        baseUrl: baseUrl,
        apiKey: apiKey,
        model: _modelController.text.trim().isEmpty ? 'gpt-3.5-turbo' : _modelController.text.trim(),
      );
      final models = await LlmService(tempProfile).fetchModels();
      if (!mounted) return;

      if (models.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No models returned. Check URL/Key or your provider may not list models.')),
        );
        return;
      }

      // Show a picker dialog.
      final selected = await showDialog<String>(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: AppColors.bgTertiary,
          title: const Text('Available Models'),
          content: SizedBox(
            width: double.maxFinite,
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: models.length,
              itemBuilder: (ctx, i) {
                final m = models[i];
                return ListTile(
                  title: Text(m),
                  trailing: _modelController.text.trim() == m
                      ? const Icon(Icons.check, color: AppColors.accentPrimary, size: 18)
                      : null,
                  onTap: () => Navigator.pop(ctx, m),
                );
              },
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ],
        ),
      );

      if (selected != null && mounted) {
        setState(() => _modelController.text = selected);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to fetch models: ${_safeError(e)}')),
        );
      }
    } finally {
      if (mounted) setState(() => _isFetchingModels = false);
    }
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    final repo = ref.read(profileRepoProvider);

    try {
      // If editing and key field left blank, fetch the existing key from secure storage.
      String apiKey = _keyController.text;
      if (apiKey.isEmpty && _hasExistingKey && widget.profileId != null) {
        // ProfileRepository.getAll* loads keys from secure storage; reuse by quick query.
        switch (widget.type) {
          case 'llm':
            final all = await repo.getAllLlmProfiles();
            apiKey = all.where((x) => x.id == widget.profileId).firstOrNull?.apiKey ?? '';
            break;
          case 'stt':
            final all = await repo.getAllSttProfiles();
            apiKey = all.where((x) => x.id == widget.profileId).firstOrNull?.apiKey ?? '';
            break;
          case 'tts':
            final all = await repo.getAllTtsProfiles();
            apiKey = all.where((x) => x.id == widget.profileId).firstOrNull?.apiKey ?? '';
            break;
        }
      }

      switch (widget.type) {
        case 'llm':
          final profile = LlmProfile(
            id: widget.profileId,
            name: _nameController.text,
            baseUrl: _urlController.text,
            apiKey: apiKey,
            model: _modelController.text,
          );
          await repo.saveLlmProfile(profile);
          break;
        case 'stt':
          final profile = SttProfile(
            id: widget.profileId,
            name: _nameController.text,
            provider: _selectedSttProvider!,
            apiKey: apiKey,
          );
          await repo.saveSttProfile(profile);
          break;
        case 'tts':
          final profile = TtsProfile(
            id: widget.profileId,
            name: _nameController.text,
            provider: _selectedTtsProvider!,
            apiKey: apiKey,
            speed: _selectedSpeed,
          );
          await repo.saveTtsProfile(profile);
          break;
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Profile saved!')),
        );
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: ${_safeError(e)}')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  String _safeError(Object e) {
    final s = e.toString();
    return s.length > 160 ? '${s.substring(0, 160)}...' : s;
  }
}
