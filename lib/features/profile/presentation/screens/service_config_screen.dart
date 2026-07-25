import 'dart:io';

import 'package:file_picker/file_picker.dart';
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

  /// BL-075: reload when the user returns from ProfileFormScreen so edits
  /// and new profiles are reflected immediately. We only reload after the
  /// initial load has completed; this avoids calling setState during the
  /// first build.
  bool _hasInitiallyLoaded = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final route = ModalRoute.of(context);
    if (route?.isCurrent == true && _hasInitiallyLoaded) {
      _loadProfiles();
    }
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
        _hasInitiallyLoaded = true;
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
                          icon: Icons.psychology_outlined,
                          semanticsLabel: l.t('service.llm_section'),
                          title: l.t('service.llm_section'),
                          subtitle: l.t('service.llm_section_subtitle'),
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
                          icon: Icons.mic_outlined,
                          semanticsLabel: l.t('service.stt_section'),
                          title: l.t('service.stt_section'),
                          subtitle: l.t('service.stt_section_subtitle'),
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
                          icon: Icons.volume_up_outlined,
                          semanticsLabel: l.t('service.tts_section'),
                          title: l.t('service.tts_section'),
                          subtitle: l.t('service.tts_section_subtitle'),
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
    BuildContext context, {
    required IconData icon,
    required String semanticsLabel,
    required String title,
    required String subtitle,
  }) {
    return Row(
      children: [
        Semantics(
          label: semanticsLabel,
          child: Icon(
            icon,
            size: 28,
            color: AppColors.accentSecondary,
          ),
        ),
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
    final l = AppLocalizations.of(context);
    final isTesting = _testingId == '${type}_$id';
    return GlassCard(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      onTap: onTap,
      glowColor: isActive ? AppColors.accentPrimary : null,
      child: Row(
        children: [
          // UX-037: Radio-style indicator so users can see the card is
          // selectable and which profile is currently active.
          Radio<bool>(
            value: true,
            groupValue: isActive,
            onChanged: (_) => onTap(),
            activeColor: AppColors.accentPrimary,
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        name,
                        style: Theme.of(context).textTheme.titleMedium,
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                      ),
                    ),
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
                        child: Text(
                          l.t('service.active'),
                          style: const TextStyle(
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
                // UX-040: truncate long URLs so the card height stays stable.
                Text(
                  subtitle,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.textSecondary,
                      ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
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
            // UX-038: wrap the popup icon in a 44×44 IconButton so the
            // touch target meets iOS/Android accessibility guidelines.
            IconButton(
              icon: const Icon(
                Icons.more_vert,
                size: 20,
                color: AppColors.textMuted,
              ),
              tooltip: l.t('service.options'),
              style: IconButton.styleFrom(
                minimumSize: const Size(44, 44),
              ),
              onPressed: () async {
                final value = await _showProfileMenu(context, isActive);
                if (value == null) return;
                switch (value) {
                  case 'edit':
                    await context.push('/profile-form/$type?id=$id');
                    await _loadProfiles();
                    break;
                  case 'test':
                    _testConnection(type, id);
                    break;
                  case 'delete':
                    _confirmDelete(type, id, name);
                    break;
                }
              },
            ),
        ],
      ),
    );
  }

  Future<String?> _showProfileMenu(BuildContext context, bool isActive) {
    final l = AppLocalizations.of(context);
    return showModalBottomSheet<String>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.edit, color: AppColors.textSecondary),
              title: Text(l.t('service.edit')),
              onTap: () => Navigator.pop(ctx, 'edit'),
            ),
            ListTile(
              leading: const Icon(
                Icons.network_check,
                color: AppColors.textSecondary,
              ),
              title: Text(l.t('service.test_connection')),
              onTap: () => Navigator.pop(ctx, 'test'),
            ),
            if (isActive)
              ListTile(
                leading: const Icon(
                  Icons.delete_outline,
                  color: AppColors.textMuted,
                ),
                title: Text(
                  l.t('service.delete_active_first'),
                  style: const TextStyle(color: AppColors.textMuted),
                ),
                enabled: false,
                onTap: null,
              )
            else
              ListTile(
                leading: const Icon(
                  Icons.delete_outline,
                  color: AppColors.error,
                ),
                title: Text(
                  l.t('service.delete'),
                  style: const TextStyle(color: AppColors.error),
                ),
                onTap: () => Navigator.pop(ctx, 'delete'),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildAddButton(BuildContext context, String type) {
    final l = AppLocalizations.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.sm),
      child: SizedBox(
        height: 44,
        child: Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: () async {
              await context.push('/profile-form/$type');
              await _loadProfiles();
            },
            icon: const Icon(Icons.add, size: 18),
            label: Text(l.t('service.add_profile')),
          ),
        ),
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
    // BL-077: invalidate the active-profile providers so any consumers
    // watching them rebuild with the newly activated profile. Services that
    // still read the repository ad-hoc will pick up the change on their
    // next request.
    ref.invalidate(activeLlmProfileProvider);
    ref.invalidate(activeSttProfileProvider);
    ref.invalidate(activeTtsProfileProvider);
    await _loadProfiles();
  }

  // ========== Export / Import ==========

  Future<void> _exportProfiles() async {
    final l = AppLocalizations.of(context);
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
            title: Text(l.t('service.export_complete')),
            content: Text(l.tArg('service.exported_to', {'path': file.path})),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: Text(l.t('common.ok')),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l.tArg('service.export_failed', {'error': _safeError(e)})),
          ),
        );
      }
    }
  }

  Future<void> _importProfiles() async {
    final l = AppLocalizations.of(context);
    final controller = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l.t('service.import_profiles')),
        content: SizedBox(
          width: double.maxFinite,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: controller,
                maxLines: 10,
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontFamily: 'monospace',
                  fontSize: 12,
                ),
                decoration: InputDecoration(
                  hintText: l.t('service.import_hint'),
                  border: const OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              // UX-035: file picker so mobile users can import from a file.
              OutlinedButton.icon(
                onPressed: () async {
                  final pick = await FilePicker.platform.pickFiles(
                    type: FileType.custom,
                    allowedExtensions: ['json'],
                    allowMultiple: false,
                    withData: true,
                  );
                  if (pick == null || pick.files.isEmpty) return;
                  final bytes = pick.files.first.bytes;
                  final path = pick.files.first.path;
                  String? text;
                  if (bytes != null) {
                    text = utf8.decode(bytes);
                  } else if (path != null) {
                    text = await File(path).readAsString();
                  }
                  if (text != null && ctx.mounted) {
                    controller.text = text;
                  }
                },
                icon: const Icon(Icons.folder_open, size: 18),
                label: Text(l.t('service.import_choose_file')),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(l.t('common.cancel')),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, controller.text),
            child: Text(l.t('common.import')),
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
            content: Text(l.tArg('service.imported_count', {'count': '$count'})),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l.t('service.invalid_json'))),
        );
      }
    }
  }

  // ========== Test Connection ==========

  Future<void> _testConnection(String type, String id) async {
    final l = AppLocalizations.of(context);
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
        result = l.tArg('profile.connected_models', {
          'ms': '$ms',
          'count': '$count',
        });
      } else if (type == 'stt') {
        final profile = _sttProfiles.firstWhere((p) => p.id == id);
        await SttService(
          profile,
        ).testConnection().timeout(const Duration(seconds: 15));
        final ms = stopwatch.elapsedMilliseconds;
        result = l.tArg('profile.connected', {
          'ms': '$ms',
          'extra': '',
        });
      } else {
        final profile = _ttsProfiles.firstWhere((p) => p.id == id);
        await TtsService(
          profile,
        ).testConnection().timeout(const Duration(seconds: 15));
        final ms = stopwatch.elapsedMilliseconds;
        result = l.tArg('profile.connected', {
          'ms': '$ms',
          'extra': '',
        });
      }
    } catch (e) {
      result = l.tArg('profile.error', {'error': _safeError(e)});
    }

    if (mounted) {
      setState(() => _testingId = null);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(result)),
      );
    }
  }

  // ========== Delete ==========

  Future<void> _confirmDelete(String type, String id, String name) async {
    final l = AppLocalizations.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l.t('service.delete_profile')),
        content: Text(l.tArg('service.delete_profile_confirm', {'name': name})),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(l.t('common.cancel')),
          ),
          // UX-042: destructive action uses a filled error button so it
          // stands out from Cancel and matches Material guidelines.
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: AppColors.textOnAccent,
            ),
            onPressed: () => Navigator.pop(context, true),
            child: Text(l.t('service.delete')),
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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l.t('service.profile_deleted'))),
        );
        await _loadProfiles();
      }
    } catch (e) {
      if (mounted) {
        final msg = e.toString();
        if (msg.contains('Cannot delete active')) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(l.t('service.cannot_delete_active'))),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(_safeError(e))),
          );
        }
      }
    }
  }

  String _safeError(Object e) {
    final msg = e.toString();
    return msg.length > 160 ? msg.substring(0, 160) : msg;
  }
}
