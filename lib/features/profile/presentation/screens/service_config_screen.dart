import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../shared/widgets/glass_widgets.dart';
import '../../../../shared/providers.dart';
import '../../domain/profile_models.dart';
import '../../../chat/data/llm_service.dart';
import '../../../chat/data/stt_service.dart';
import '../../../chat/data/tts_service.dart';

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
                        type: 'llm',
                        id: p.id,
                        name: p.name,
                        subtitle: '${p.model} • ${p.baseUrl}',
                        isActive: p.isActive,
                        onTap: () => _activateProfile('llm', p.id),
                      )),
                  _buildAddButton(context, 'llm'),

                  const SizedBox(height: AppSpacing.xl),
                  _buildSectionHeader(context, '🎤', 'Speech Recognition (STT)', 'Convert speech to text'),
                  const SizedBox(height: AppSpacing.sm),
                  ..._sttProfiles.map((p) => _buildProfileCard(
                        context,
                        type: 'stt',
                        id: p.id,
                        name: p.name,
                        subtitle: p.providerDisplayName,
                        isActive: p.isActive,
                        onTap: () => _activateProfile('stt', p.id),
                      )),
                  _buildAddButton(context, 'stt'),

                  const SizedBox(height: AppSpacing.xl),
                  _buildSectionHeader(context, '🔊', 'Text-to-Speech (TTS)', 'Convert text to speech'),
                  const SizedBox(height: AppSpacing.sm),
                  ..._ttsProfiles.map((p) => _buildProfileCard(
                        context,
                        type: 'tts',
                        id: p.id,
                        name: p.name,
                        subtitle: '${p.providerDisplayName}${p.voiceName != null ? ' • ${p.voiceName}' : ''}',
                        isActive: p.isActive,
                        onTap: () => _activateProfile('tts', p.id),
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
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppColors.accentPrimary.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(AppRadius.sm),
                        ),
                        child: const Text('Active',
                            style: TextStyle(color: AppColors.accentPrimary, fontSize: 10, fontWeight: FontWeight.w600)),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 2),
                Text(subtitle, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.textSecondary)),
              ],
            ),
          ),
          if (isTesting)
            const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
          else
            PopupMenuButton<String>(
              color: AppColors.bgSecondary,
              icon: const Icon(Icons.more_vert, size: 20, color: AppColors.textMuted),
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
                      Icon(Icons.edit, size: 18, color: AppColors.textSecondary),
                      SizedBox(width: AppSpacing.sm),
                      Text('Edit'),
                    ],
                  ),
                ),
                const PopupMenuItem(
                  value: 'test',
                  child: Row(
                    children: [
                      Icon(Icons.network_check, size: 18, color: AppColors.textSecondary),
                      SizedBox(width: AppSpacing.sm),
                      Text('Test Connection'),
                    ],
                  ),
                ),
                const PopupMenuItem(
                  value: 'delete',
                  child: Row(
                    children: [
                      Icon(Icons.delete_outline, size: 18, color: AppColors.error),
                      SizedBox(width: AppSpacing.sm),
                      Text('Delete', style: TextStyle(color: AppColors.error)),
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

  // ========== Test Connection ==========

  Future<void> _testConnection(String type, String id) async {
    final key = '${type}_$id';
    setState(() => _testingId = key);

    final stopwatch = Stopwatch()..start();
    String result;
    try {
      if (type == 'llm') {
        final profile = _llmProfiles.firstWhere((p) => p.id == id);
        final models = await LlmService(profile).fetchModels().timeout(const Duration(seconds: 10));
        final ms = stopwatch.elapsedMilliseconds;
        result = models.isNotEmpty
            ? '✓ Connected (${ms}ms, ${models.length} models)'
            : '✗ Failed: No models returned';
      } else if (type == 'stt') {
        final profile = _sttProfiles.firstWhere((p) => p.id == id);
        await SttService(profile).transcribe(_silentWav()).timeout(const Duration(seconds: 10));
        final ms = stopwatch.elapsedMilliseconds;
        result = '✓ Connected (${ms}ms)';
      } else {
        final profile = _ttsProfiles.firstWhere((p) => p.id == id);
        final bytes = await TtsService(profile).synthesize('test').timeout(const Duration(seconds: 10));
        final ms = stopwatch.elapsedMilliseconds;
        result = bytes.isNotEmpty ? '✓ Connected (${ms}ms)' : '✗ Failed: Empty response';
      }
    } catch (e) {
      final msg = e.toString();
      if ((type == 'stt' || type == 'tts') && (msg.contains('401') || msg.contains('403'))) {
        result = '✗ Auth failed';
      } else {
        result = '✗ Failed: ${_safeError(e)}';
      }
    }

    if (mounted) {
      setState(() => _testingId = null);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(result)));
    }
  }

  Uint8List _silentWav() {
    const sampleRate = 16000;
    const numChannels = 1;
    const bitsPerSample = 16;
    const durationMs = 100;
    final numSamples = sampleRate * numChannels * durationMs ~/ 1000;
    final dataSize = numSamples * (bitsPerSample ~/ 8);
    final totalSize = 44 + dataSize;

    final bytes = ByteData(totalSize);
    bytes.setUint8(0, 0x52); // R
    bytes.setUint8(1, 0x49); // I
    bytes.setUint8(2, 0x46); // F
    bytes.setUint8(3, 0x46); // F
    bytes.setUint32(4, totalSize - 8, Endian.little);
    bytes.setUint8(8, 0x57); // W
    bytes.setUint8(9, 0x41); // A
    bytes.setUint8(10, 0x56); // V
    bytes.setUint8(11, 0x45); // E
    bytes.setUint8(12, 0x66); // f
    bytes.setUint8(13, 0x6D); // m
    bytes.setUint8(14, 0x74); // t
    bytes.setUint8(15, 0x20); // (space)
    bytes.setUint32(16, 16, Endian.little);
    bytes.setUint16(20, 1, Endian.little);
    bytes.setUint16(22, numChannels, Endian.little);
    bytes.setUint32(24, sampleRate, Endian.little);
    bytes.setUint32(28, sampleRate * numChannels * bitsPerSample ~/ 8, Endian.little);
    bytes.setUint16(32, numChannels * bitsPerSample ~/ 8, Endian.little);
    bytes.setUint16(34, bitsPerSample, Endian.little);
    bytes.setUint8(36, 0x64); // d
    bytes.setUint8(37, 0x61); // a
    bytes.setUint8(38, 0x74); // t
    bytes.setUint8(39, 0x61); // a
    bytes.setUint32(40, dataSize, Endian.little);
    return bytes.buffer.asUint8List();
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
            child: const Text('Delete', style: TextStyle(color: AppColors.error)),
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
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Profile deleted')));
        await _loadProfiles();
      }
    } catch (e) {
      if (mounted) {
        final msg = e.toString();
        if (msg.contains('Cannot delete active')) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Cannot delete the active profile. Switch to another profile first.')),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(_safeError(e))));
        }
      }
    }
  }

  String _safeError(Object e) {
    final msg = e.toString();
    return msg.length > 160 ? msg.substring(0, 160) : msg;
  }
}
