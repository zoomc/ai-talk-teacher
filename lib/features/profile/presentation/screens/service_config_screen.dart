import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:path_provider/path_provider.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/util/responsive.dart';
import '../../../../core/i18n/app_localizations.dart';
import '../../../../shared/widgets/glass_widgets.dart';
import '../../../../shared/providers.dart';
import '../../domain/profile_models.dart';
import '../../../chat/data/llm_service.dart';
import '../../../chat/data/stt_service.dart';
import '../../../chat/data/tts_service.dart';

class ServiceConfigScreen extends ConsumerStatefulWidget {
  const ServiceConfigScreen({super.key});

  @override
  ConsumerState<ServiceConfigScreen> createState() =>
      _ServiceConfigScreenState();
}

class _ServiceConfigScreenState extends ConsumerState<ServiceConfigScreen> {
  List<LlmProfile> _llmProfiles = [];
  List<SttProfile> _sttProfiles = [];
  List<TtsProfile> _ttsProfiles = [];
  bool _isLoading = true;
  String? _testingId;

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
    if (mounted) {
      setState(() {
        _llmProfiles = llm;
        _sttProfiles = stt;
        _ttsProfiles = tts;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isLight = Theme.of(context).brightness == Brightness.light;
    final l = AppLocalizations.of(context);
    return Scaffold(
      backgroundColor: isLight ? AppColors.lightBgPrimary : AppColors.bgPrimary,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new),
          onPressed: () => context.pop(),
        ),
        title: Text(l.t('service.title')),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SafeArea(
              // bottom:true keeps Import/Export + trailing spacing out
              // from behind the home indicator on notched iPhones.
              top: false,
              child: Center(
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    maxWidth: Responsive.contentMaxWidth(context),
                  ),
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(AppSpacing.lg),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildSectionHeader(
                          context,
                          '🧠',
                          l.t('service.llm_section'),
                          l.t('service.llm_section_subtitle'),
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        ..._llmProfiles.map(
                          (p) => _buildProfileCard(
                            context,
                            type: 'llm',
                            id: p.id,
                            name: p.name,
                            subtitle: '${p.model} • ${p.baseUrl}',
                            isActive: p.isActive,
                            onTap: () => _activateProfile('llm', p.id),
                          ),
                        ),
                        _buildAddButton(context, 'llm'),

                        const SizedBox(height: AppSpacing.xl),
                        _buildSectionHeader(
                          context,
                          '🎤',
                          l.t('service.stt_section'),
                          l.t('service.stt_section_subtitle'),
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        ..._sttProfiles.map(
                          (p) => _buildProfileCard(
                            context,
                            type: 'stt',
                            id: p.id,
                            name: p.name,
                            subtitle: p.providerDisplayName,
                            isActive: p.isActive,
                            onTap: () => _activateProfile('stt', p.id),
                          ),
                        ),
                        _buildAddButton(context, 'stt'),

                        const SizedBox(height: AppSpacing.xl),
                        _buildSectionHeader(
                          context,
                          '🔊',
                          l.t('service.tts_section'),
                          l.t('service.tts_section_subtitle'),
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        ..._ttsProfiles.map(
                          (p) => _buildProfileCard(
                            context,
                            type: 'tts',
                            id: p.id,
                            name: p.name,
                            subtitle:
                                '${p.providerDisplayName}${p.voiceName != null ? ' • ${p.voiceName}' : ''}',
                            isActive: p.isActive,
                            onTap: () => _activateProfile('tts', p.id),
                          ),
                        ),
                        _buildAddButton(context, 'tts'),

                        const SizedBox(height: AppSpacing.xl),
                        // Import/Export buttons
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: _importProfiles,
                                icon: const Icon(Icons.download),
                                label: Text(l.t('service.import_all')),
                              ),
                            ),
                            const SizedBox(width: AppSpacing.md),
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: _exportProfiles,
                                icon: const Icon(Icons.upload),
                                label: Text(l.t('service.export_all')),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: AppSpacing.xxl),
                      ],
                    ),
                  ),
                ),
              ),
            ),
    );
  }

  Widget _buildSectionHeader(
    BuildContext context,
    String emoji,
    String title,
    String subtitle,
  ) {
    return Row(
      children: [
        Text(emoji, style: const TextStyle(fontSize: 24)),
        const SizedBox(width: AppSpacing.sm),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleLarge),
            Text(
              subtitle,
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildProfileCard(
    BuildContext context, {
    required String type,
    required String id,
    required String name,
    required String subtitle,
    required bool isActive,
    required VoidCallback onTap,
  }) {
    final isTesting = _testingId == '${type}_$id';
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
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.accentPrimary.withValues(
                            alpha: 0.15,
                          ),
                          borderRadius: BorderRadius.circular(AppRadius.sm),
                        ),
                        child: const Text(
                          'Active',
                          style: TextStyle(
                            color: AppColors.accentPrimary,
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          if (isTesting)
            const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          else
            PopupMenuButton<String>(
              color: Theme.of(context).brightness == Brightness.light
                  ? AppColors.lightBgSecondary
                  : AppColors.bgSecondary,
              icon: const Icon(
                Icons.more_vert,
                size: 20,
                color: AppColors.textMuted,
              ),
              onSelected: (value) {
                switch (value) {
                  case 'edit':
                    context.push('/profile-form/$type?id=$id');
                    break;
                  case 'test':
                    _testConnection(type, id);
                    break;
                  case 'delete':
                    _confirmDelete(type, id, name);
                    break;
                }
              },
              itemBuilder: (context) => [
                const PopupMenuItem(
                  value: 'edit',
                  child: Row(
                    children: [
                      Icon(
                        Icons.edit,
                        size: 18,
                        color: AppColors.textSecondary,
                      ),
                      SizedBox(width: AppSpacing.sm),
                      Text('Edit'),
                    ],
                  ),
                ),
                const PopupMenuItem(
                  value: 'test',
                  child: Row(
                    children: [
                      Icon(
                        Icons.network_check,
                        size: 18,
                        color: AppColors.textSecondary,
                      ),
                      SizedBox(width: AppSpacing.sm),
                      Text('Test Connection'),
                    ],
                  ),
                ),
                // D15: when the profile is active, Delete is disabled with a
                // hint so the user learns *why* (switch active first) instead
                // of hitting a snackbar after confirming.
                if (isActive)
                  const PopupMenuItem(
                    enabled: false,
                    value: '_disabled_delete',
                    child: Row(
                      children: [
                        Icon(
                          Icons.delete_outline,
                          size: 18,
                          color: AppColors.textMuted,
                        ),
                        SizedBox(width: AppSpacing.sm),
                        Text(
                          'Delete (switch active first)',
                          style: TextStyle(color: AppColors.textMuted),
                        ),
                      ],
                    ),
                  )
                else
                  const PopupMenuItem(
                    value: 'delete',
                    child: Row(
                      children: [
                        Icon(
                          Icons.delete_outline,
                          size: 18,
                          color: AppColors.error,
                        ),
                        SizedBox(width: AppSpacing.sm),
                        Text(
                          'Delete',
                          style: TextStyle(color: AppColors.error),
                        ),
                      ],
                    ),
                  ),
              ],
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

  // ========== Export / Import ==========

  Future<void> _exportProfiles() async {
    final repo = ref.read(profileRepoProvider);
    try {
      final json = await repo.exportAllProfilesJson();
      Directory? dir;
      try {
        dir = await getDownloadsDirectory();
      } catch (_) {
        dir = null;
      }
      dir ??= await getApplicationDocumentsDirectory();
      final timestamp = DateTime.now().toIso8601String().replaceAll(
        RegExp(r'[:.]'),
        '-',
      );
      final file = File('${dir.path}/speakflow_profiles_$timestamp.json');
      await file.writeAsString(json);
      if (mounted) {
        await showDialog<void>(
          context: context,
          builder: (ctx) => AlertDialog(
            backgroundColor: Theme.of(context).brightness == Brightness.light
                ? AppColors.lightBgTertiary
                : AppColors.bgTertiary,
            title: const Text('Export Complete'),
            content: Text('Profiles exported to:\n${file.path}'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('OK'),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Export failed: ${_safeError(e)}')),
        );
      }
    }
  }

  Future<void> _importProfiles() async {
    final controller = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Theme.of(context).brightness == Brightness.light
            ? AppColors.lightBgTertiary
            : AppColors.bgTertiary,
        title: const Text('Import Profiles'),
        content: SizedBox(
          width: double.maxFinite,
          child: TextField(
            controller: controller,
            maxLines: 12,
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontFamily: 'monospace',
              fontSize: 12,
            ),
            decoration: const InputDecoration(
              hintText: 'Paste exported JSON here',
              border: OutlineInputBorder(),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, controller.text),
            child: const Text('Import'),
          ),
        ],
      ),
    );
    if (result == null) return;
    final text = result.trim();
    if (text.isEmpty) return;

    final repo = ref.read(profileRepoProvider);
    try {
      final count = await repo.importProfilesJson(text);
      await _loadProfiles();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Imported $count profiles. Please edit each to re-enter API keys.',
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Invalid JSON')));
      }
    }
  }

  // ========== Test Connection ==========

  Future<void> _testConnection(String type, String id) async {
    final key = '${type}_$id';
    setState(() => _testingId = key);

    final stopwatch = Stopwatch()..start();
    String result;
    try {
      if (type == 'llm') {
        final profile = _llmProfiles.firstWhere((p) => p.id == id);
        final count = await LlmService(
          profile,
        ).testConnection().timeout(const Duration(seconds: 15));
        final ms = stopwatch.elapsedMilliseconds;
        result = '✓ Connected (${ms}ms, $count models)';
      } else if (type == 'stt') {
        final profile = _sttProfiles.firstWhere((p) => p.id == id);
        await SttService(
          profile,
        ).testConnection().timeout(const Duration(seconds: 15));
        final ms = stopwatch.elapsedMilliseconds;
        result = '✓ Connected (${ms}ms)';
      } else {
        final profile = _ttsProfiles.firstWhere((p) => p.id == id);
        await TtsService(
          profile,
        ).testConnection().timeout(const Duration(seconds: 15));
        final ms = stopwatch.elapsedMilliseconds;
        result = '✓ Connected (${ms}ms)';
      }
    } catch (e) {
      result = '✗ ${_safeError(e)}';
    }

    if (mounted) {
      setState(() => _testingId = null);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(result)));
    }
  }

  // ========== Delete ==========

  Future<void> _confirmDelete(String type, String id, String name) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Profile'),
        content: Text('Are you sure you want to delete "$name"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text(
              'Delete',
              style: TextStyle(color: AppColors.error),
            ),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      final repo = ref.read(profileRepoProvider);
      switch (type) {
        case 'llm':
          await repo.deleteLlmProfile(id);
          break;
        case 'stt':
          await repo.deleteSttProfile(id);
          break;
        case 'tts':
          await repo.deleteTtsProfile(id);
          break;
      }
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Profile deleted')));
        await _loadProfiles();
      }
    } catch (e) {
      if (mounted) {
        final msg = e.toString();
        if (msg.contains('Cannot delete active')) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Cannot delete the active profile. Switch to another profile first.',
              ),
            ),
          );
        } else {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(_safeError(e))));
        }
      }
    }
  }

  String _safeError(Object e) {
    final msg = e.toString();
    return msg.length > 160 ? msg.substring(0, 160) : msg;
  }
}
