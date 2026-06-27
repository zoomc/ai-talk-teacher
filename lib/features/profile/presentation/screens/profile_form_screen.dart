import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../shared/providers.dart';
import '../../domain/profile_models.dart';

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

  @override
  void initState() {
    super.initState();
    if (widget.type == 'llm') {
      _urlController.text = 'https://api.deepseek.com';
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
      body: SingleChildScrollView(
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
                  value: _selectedSttProvider,
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
                  value: _selectedTtsProvider,
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
              ],

              const SizedBox(height: AppSpacing.lg),
              Text('API Key', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: AppSpacing.xs),
              TextFormField(
                controller: _keyController,
                style: const TextStyle(color: AppColors.textPrimary),
                obscureText: true,
                decoration: const InputDecoration(hintText: 'sk-...'),
                validator: (v) => v == null || v.isEmpty ? 'Required' : null,
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
                  onPressed: _fetchModels,
                  icon: const Icon(Icons.refresh, size: 16),
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

  Future<void> _fetchModels() async {
    // TODO: Implement model fetching
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Model fetching will be implemented with LLM service')),
    );
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    final repo = ref.read(profileRepoProvider);

    try {
      switch (widget.type) {
        case 'llm':
          final profile = LlmProfile(
            id: widget.profileId,
            name: _nameController.text,
            baseUrl: _urlController.text,
            apiKey: _keyController.text,
            model: _modelController.text,
          );
          await repo.saveLlmProfile(profile);
          if (profile.isActive) await repo.setActiveLlmProfile(profile.id);
          break;
        case 'stt':
          final profile = SttProfile(
            id: widget.profileId,
            name: _nameController.text,
            provider: _selectedSttProvider!,
            apiKey: _keyController.text,
          );
          await repo.saveSttProfile(profile);
          if (profile.isActive) await repo.setActiveSttProfile(profile.id);
          break;
        case 'tts':
          final profile = TtsProfile(
            id: widget.profileId,
            name: _nameController.text,
            provider: _selectedTtsProvider!,
            apiKey: _keyController.text,
          );
          await repo.saveTtsProfile(profile);
          if (profile.isActive) await repo.setActiveTtsProfile(profile.id);
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
          SnackBar(content: Text('Error: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }
}
