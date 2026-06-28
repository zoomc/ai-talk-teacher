import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../shared/widgets/glass_widgets.dart';
import '../../../../shared/providers.dart';
import '../../../chat/data/tts_playback_service.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  String _correctionStrength = 'moderate';
  String _ttsSpeed = '1.0';
  String _theme = 'system';
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final repo = ref.read(profileRepoProvider);
    final cs = await repo.getSetting('correction_strength');
    final ts = await repo.getSetting('tts_speed');
    final th = await repo.getSetting('theme');
    if (mounted) {
      setState(() {
        if (cs != null) _correctionStrength = cs;
        if (ts != null) _ttsSpeed = ts;
        if (th != null) _theme = th;
        _isLoading = false;
      });
    }
  }

  String _capitalize(String s) =>
      s.isEmpty ? s : '${s[0].toUpperCase()}${s.substring(1)}';

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        body: Container(
          decoration: const BoxDecoration(gradient: AppColors.gradientBg),
          child: const Center(child: CircularProgressIndicator()),
        ),
      );
    }

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(gradient: AppColors.gradientBg),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Settings',
                  style: Theme.of(context).textTheme.displayLarge,
                ),
                const SizedBox(height: AppSpacing.xl),

                // Services section
                _SettingsSection(
                  title: 'Services',
                  children: [
                    _SettingsTile(
                      icon: Icons.cloud_outlined,
                      title: 'Service Configuration',
                      subtitle: 'Manage LLM, STT, TTS profiles',
                      onTap: () => context.push('/service-config'),
                    ),
                  ],
                ),

                const SizedBox(height: AppSpacing.lg),

                // Learning section
                _SettingsSection(
                  title: 'Learning',
                  children: [
                    _SettingsTile(
                      icon: Icons.speed,
                      title: 'Correction Strength',
                      subtitle: _capitalize(_correctionStrength),
                      onTap: _showCorrectionStrengthDialog,
                    ),
                    _SettingsTile(
                      icon: Icons.volume_up_outlined,
                      title: 'TTS Speed',
                      subtitle: '${_ttsSpeed}x',
                      onTap: _showTtsSpeedDialog,
                    ),
                    _SettingsTile(
                      icon: Icons.language,
                      title: 'Interface Language',
                      subtitle: 'English',
                      onTap: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                              'Interface language switching coming in a future update',
                            ),
                          ),
                        );
                      },
                    ),
                  ],
                ),

                const SizedBox(height: AppSpacing.lg),

                // Appearance section
                _SettingsSection(
                  title: 'Appearance',
                  children: [
                    _SettingsTile(
                      icon: Icons.dark_mode_outlined,
                      title: 'Theme',
                      subtitle: _capitalize(_theme),
                      onTap: _showThemeDialog,
                    ),
                  ],
                ),

                const SizedBox(height: AppSpacing.lg),

                // Data section
                _SettingsSection(
                  title: 'Data',
                  children: [
                    _SettingsTile(
                      icon: Icons.download_outlined,
                      title: 'Export Learning Data',
                      subtitle: 'Download your progress and corrections',
                      onTap: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Export coming soon')),
                        );
                      },
                    ),
                    _SettingsTile(
                      icon: Icons.delete_outline,
                      title: 'Clear Cache',
                      subtitle: 'Free up storage space',
                      onTap: _clearCache,
                      isDestructive: true,
                    ),
                  ],
                ),

                const SizedBox(height: AppSpacing.lg),

                // About section
                _SettingsSection(
                  title: 'About',
                  children: [
                    _SettingsTile(
                      icon: Icons.info_outline,
                      title: 'SpeakFlow',
                      subtitle: 'Version 1.0.0',
                      onTap: () {},
                    ),
                  ],
                ),

                const SizedBox(height: AppSpacing.xxl),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _clearCache() async {
    try {
      await TtsPlaybackService().clearCache();
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Cache cleared')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to clear cache: $e')));
      }
    }
  }

  void _showCorrectionStrengthDialog() {
    String local = _correctionStrength;
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          backgroundColor: AppColors.bgTertiary,
          title: const Text('Correction Strength'),
          content: RadioGroup<String>(
            groupValue: local,
            onChanged: (v) {
              if (v != null) setDialogState(() => local = v);
            },
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                RadioListTile<String>(
                  title: const Text('Gentle'),
                  subtitle: const Text('Occasionally correct errors'),
                  value: 'gentle',
                  activeColor: AppColors.accentPrimary,
                ),
                RadioListTile<String>(
                  title: const Text('Moderate'),
                  subtitle: const Text('Correct most errors'),
                  value: 'moderate',
                  activeColor: AppColors.accentPrimary,
                ),
                RadioListTile<String>(
                  title: const Text('Strict'),
                  subtitle: const Text('Correct every error'),
                  value: 'strict',
                  activeColor: AppColors.accentPrimary,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                await ref
                    .read(profileRepoProvider)
                    .setSetting('correction_strength', local);
                if (mounted) setState(() => _correctionStrength = local);
                if (ctx.mounted) Navigator.pop(ctx);
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }

  void _showTtsSpeedDialog() {
    String local = _ttsSpeed;
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          backgroundColor: AppColors.bgTertiary,
          title: const Text('TTS Speed'),
          content: RadioGroup<String>(
            groupValue: local,
            onChanged: (v) {
              if (v != null) setDialogState(() => local = v);
            },
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                RadioListTile<String>(
                  title: const Text('0.75x (Slower)'),
                  value: '0.75',
                  activeColor: AppColors.accentPrimary,
                ),
                RadioListTile<String>(
                  title: const Text('1.0x (Normal)'),
                  value: '1.0',
                  activeColor: AppColors.accentPrimary,
                ),
                RadioListTile<String>(
                  title: const Text('1.25x (Faster)'),
                  value: '1.25',
                  activeColor: AppColors.accentPrimary,
                ),
                RadioListTile<String>(
                  title: const Text('1.5x (Fastest)'),
                  value: '1.5',
                  activeColor: AppColors.accentPrimary,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                await ref
                    .read(profileRepoProvider)
                    .setSetting('tts_speed', local);
                if (mounted) setState(() => _ttsSpeed = local);
                if (ctx.mounted) Navigator.pop(ctx);
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }

  void _showThemeDialog() {
    String local = _theme;
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          backgroundColor: AppColors.bgTertiary,
          title: const Text('Theme'),
          content: RadioGroup<String>(
            groupValue: local,
            onChanged: (v) {
              if (v != null) setDialogState(() => local = v);
            },
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                RadioListTile<String>(
                  title: const Text('System'),
                  value: 'system',
                  activeColor: AppColors.accentPrimary,
                ),
                RadioListTile<String>(
                  title: const Text('Dark'),
                  value: 'dark',
                  activeColor: AppColors.accentPrimary,
                ),
                RadioListTile<String>(
                  title: const Text('Light'),
                  value: 'light',
                  activeColor: AppColors.accentPrimary,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                await ref.read(profileRepoProvider).setSetting('theme', local);
                if (mounted) setState(() => _theme = local);
                if (ctx.mounted) Navigator.pop(ctx);
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }
}

class _SettingsSection extends StatelessWidget {
  final String title;
  final List<Widget> children;

  const _SettingsSection({required this.title, required this.children});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(
            left: AppSpacing.xs,
            bottom: AppSpacing.sm,
          ),
          child: Text(
            title,
            style: Theme.of(
              context,
            ).textTheme.titleSmall?.copyWith(color: AppColors.textSecondary),
          ),
        ),
        GlassCard(child: Column(children: children)),
      ],
    );
  }
}

class _SettingsTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final bool isDestructive;

  const _SettingsTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.isDestructive = false,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: onTap,
      leading: Icon(
        icon,
        color: isDestructive ? AppColors.error : AppColors.accentSecondary,
      ),
      title: Text(
        title,
        style: TextStyle(
          color: isDestructive ? AppColors.error : AppColors.textPrimary,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: Theme.of(
          context,
        ).textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
      ),
      trailing: const Icon(
        Icons.chevron_right,
        color: AppColors.textMuted,
        size: 20,
      ),
    );
  }
}
