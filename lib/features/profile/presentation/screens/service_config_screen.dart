import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../shared/widgets/glass_widgets.dart';
import '../../../../shared/providers.dart';
import '../../domain/profile_models.dart';

class ServiceConfigScreen extends ConsumerStatefulWidget {
  const ServiceConfigScreen({super.key});

  @override
  ConsumerState<ServiceConfigScreen> createState() => _ServiceConfigScreenState();
}

class _ServiceConfigScreenState extends ConsumerState<ServiceConfigScreen> {
  List<LlmProfile> _llmProfiles = [];
  List<SttProfile> _sttProfiles = [];
  List<TtsProfile> _ttsProfiles = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadProfiles();
  }

  Future<void> _loadProfiles() async {
    final repo = ref.read(profileRepoProvider);
    final llm = await repo.getAllLlmProfiles();
    final stt = await repo.getAllSttProfiles();
    final tts = await repo.getAllTtsProfiles();
    setState(() {
      _llmProfiles = llm;
      _sttProfiles = stt;
      _ttsProfiles = tts;
      _isLoading = false;
    });
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
        title: const Text('Service Configuration'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildSectionHeader(context, '🧠', 'AI Dialogue', 'Chat completion model'),
                  const SizedBox(height: AppSpacing.sm),
                  ..._llmProfiles.map((p) => _buildProfileCard(
                    context,
                    name: p.name,
                    subtitle: '${p.model} • ${p.baseUrl}',
                    isActive: p.isActive,
                    onTap: () => _activateProfile('llm', p.id),
                    onEdit: () => context.push('/profile-form/llm?id=${p.id}'),
                  )),
                  _buildAddButton(context, 'llm'),

                  const SizedBox(height: AppSpacing.xl),
                  _buildSectionHeader(context, '🎤', 'Speech Recognition (STT)', 'Convert speech to text'),
                  const SizedBox(height: AppSpacing.sm),
                  ..._sttProfiles.map((p) => _buildProfileCard(
                    context,
                    name: p.name,
                    subtitle: p.providerDisplayName,
                    isActive: p.isActive,
                    onTap: () => _activateProfile('stt', p.id),
                    onEdit: () => context.push('/profile-form/stt?id=${p.id}'),
                  )),
                  _buildAddButton(context, 'stt'),

                  const SizedBox(height: AppSpacing.xl),
                  _buildSectionHeader(context, '🔊', 'Text-to-Speech (TTS)', 'Convert text to speech'),
                  const SizedBox(height: AppSpacing.sm),
                  ..._ttsProfiles.map((p) => _buildProfileCard(
                    context,
                    name: p.name,
                    subtitle: '${p.providerDisplayName}${p.voiceName != null ? ' • ${p.voiceName}' : ''}',
                    isActive: p.isActive,
                    onTap: () => _activateProfile('tts', p.id),
                    onEdit: () => context.push('/profile-form/tts?id=${p.id}'),
                  )),
                  _buildAddButton(context, 'tts'),

                  const SizedBox(height: AppSpacing.xl),
                  // Import/Export buttons
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () {},
                          icon: const Icon(Icons.download),
                          label: const Text('Import All'),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () {},
                          icon: const Icon(Icons.upload),
                          label: const Text('Export All'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.xxl),
                ],
              ),
            ),
    );
  }

  Widget _buildSectionHeader(BuildContext context, String emoji, String title, String subtitle) {
    return Row(
      children: [
        Text(emoji, style: const TextStyle(fontSize: 24)),
        const SizedBox(width: AppSpacing.sm),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleLarge),
            Text(subtitle, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.textSecondary)),
          ],
        ),
      ],
    );
  }

  Widget _buildProfileCard(
    BuildContext context, {
    required String name,
    required String subtitle,
    required bool isActive,
    required VoidCallback onTap,
    required VoidCallback onEdit,
  }) {
    return GlassCard(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      onTap: onTap,
      glowColor: isActive ? AppColors.accentPrimary : null,
      child: Row(
        children: [
          if (isActive)
            Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                color: AppColors.accentPrimary,
                borderRadius: BorderRadius.circular(AppRadius.sm),
              ),
              child: const Icon(Icons.check, color: Colors.white, size: 16),
            )
          else
            Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                border: Border.all(color: AppColors.glassBorder),
                borderRadius: BorderRadius.circular(AppRadius.sm),
              ),
            ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(name, style: Theme.of(context).textTheme.titleMedium),
                    if (isActive) ...[
                      const SizedBox(width: AppSpacing.xs),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppColors.accentPrimary.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(AppRadius.sm),
                        ),
                        child: const Text('Active', style: TextStyle(color: AppColors.accentPrimary, fontSize: 10, fontWeight: FontWeight.w600)),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 2),
                Text(subtitle, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.textSecondary)),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.edit, size: 18, color: AppColors.textMuted),
            onPressed: onEdit,
          ),
        ],
      ),
    );
  }

  Widget _buildAddButton(BuildContext context, String type) {
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.sm),
      child: TextButton.icon(
        onPressed: () => context.push('/profile-form/$type'),
        icon: const Icon(Icons.add, size: 18),
        label: const Text('Add Profile'),
      ),
    );
  }

  Future<void> _activateProfile(String type, String id) async {
    final repo = ref.read(profileRepoProvider);
    switch (type) {
      case 'llm':
        await repo.setActiveLlmProfile(id);
        break;
      case 'stt':
        await repo.setActiveSttProfile(id);
        break;
      case 'tts':
        await repo.setActiveTtsProfile(id);
        break;
    }
    await _loadProfiles();
  }
}
