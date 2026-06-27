import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../shared/widgets/glass_widgets.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(gradient: AppColors.gradientBg),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Settings', style: Theme.of(context).textTheme.displayLarge),
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
                      subtitle: 'Moderate',
                      onTap: () => _showCorrectionStrengthDialog(context),
                    ),
                    _SettingsTile(
                      icon: Icons.volume_up_outlined,
                      title: 'TTS Speed',
                      subtitle: '1.0x',
                      onTap: () {},
                    ),
                    _SettingsTile(
                      icon: Icons.language,
                      title: 'Interface Language',
                      subtitle: 'English',
                      onTap: () {},
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
                      subtitle: 'System',
                      onTap: () => _showThemeDialog(context),
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
                      onTap: () {},
                    ),
                    _SettingsTile(
                      icon: Icons.delete_outline,
                      title: 'Clear Cache',
                      subtitle: 'Free up storage space',
                      onTap: () => _showClearCacheDialog(context),
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

  void _showCorrectionStrengthDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.bgTertiary,
        title: const Text('Correction Strength'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            RadioListTile(
              title: const Text('Gentle'),
              subtitle: const Text('Occasionally correct errors'),
              value: 'gentle',
              groupValue: 'moderate',
              onChanged: (_) {},
              activeColor: AppColors.accentPrimary,
            ),
            RadioListTile(
              title: const Text('Moderate'),
              subtitle: const Text('Correct most errors'),
              value: 'moderate',
              groupValue: 'moderate',
              onChanged: (_) {},
              activeColor: AppColors.accentPrimary,
            ),
            RadioListTile(
              title: const Text('Strict'),
              subtitle: const Text('Correct every error'),
              value: 'strict',
              groupValue: 'moderate',
              onChanged: (_) {},
              activeColor: AppColors.accentPrimary,
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(onPressed: () => Navigator.pop(context), child: const Text('Save')),
        ],
      ),
    );
  }

  void _showThemeDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.bgTertiary,
        title: const Text('Theme'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            RadioListTile(
              title: const Text('System'),
              value: 'system',
              groupValue: 'system',
              onChanged: (_) {},
              activeColor: AppColors.accentPrimary,
            ),
            RadioListTile(
              title: const Text('Dark'),
              value: 'dark',
              groupValue: 'system',
              onChanged: (_) {},
              activeColor: AppColors.accentPrimary,
            ),
            RadioListTile(
              title: const Text('Light'),
              value: 'light',
              groupValue: 'system',
              onChanged: (_) {},
              activeColor: AppColors.accentPrimary,
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(onPressed: () => Navigator.pop(context), child: const Text('Save')),
        ],
      ),
    );
  }

  void _showClearCacheDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.bgTertiary,
        title: const Text('Clear Cache'),
        content: const Text('This will clear cached TTS audio files. Your learning data and profiles will not be affected.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Cache cleared')),
              );
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            child: const Text('Clear'),
          ),
        ],
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
        Text(
          title,
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
            color: AppColors.textSecondary,
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        GlassCard(
          padding: EdgeInsets.zero,
          child: Column(children: children),
        ),
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
      leading: Icon(icon, color: isDestructive ? AppColors.error : AppColors.textSecondary),
      title: Text(
        title,
        style: TextStyle(color: isDestructive ? AppColors.error : AppColors.textPrimary),
      ),
      subtitle: Text(subtitle, style: TextStyle(color: AppColors.textMuted)),
      trailing: const Icon(Icons.arrow_forward_ios, size: 16, color: AppColors.textMuted),
      onTap: onTap,
    );
  }
}
