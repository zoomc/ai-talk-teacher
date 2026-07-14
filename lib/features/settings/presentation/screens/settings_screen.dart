import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/i18n/app_localizations.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/services/install_prompt_service.dart';
import '../../../../core/services/version_service.dart';
import '../../../../shared/widgets/glass_widgets.dart';
import '../../../../shared/providers.dart';
import '../../../chat/data/tts_playback_service.dart';
import '../../../profile/domain/services/connection_tester.dart';

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

  /// Phase-1 P0 #8 — toggle low-bandwidth mode. Updates the global
  /// provider (immediate rebuild of the chat panel) and persists the
  /// choice so the next app launch respects it.
  Future<void> _toggleLowBandwidth(bool value) async {
    ref.read(lowBandwidthProvider.notifier).state = value;
    await ref.read(profileRepoProvider).setSetting(
          'low_bandwidth',
          value ? 'true' : 'false',
        );
  }

  String _capitalize(String s) =>
      s.isEmpty ? s : '${s[0].toUpperCase()}${s.substring(1)}';

  ThemeMode _parseThemeMode(String s) {
    switch (s) {
      case 'dark':
        return ThemeMode.dark;
      case 'light':
        return ThemeMode.light;
      case 'system':
      default:
        return ThemeMode.system;
    }
  }

  AppLocalizations get _l => AppLocalizations.of(context);

  @override
  Widget build(BuildContext context) {
    final isLight = Theme.of(context).brightness == Brightness.light;
    final lowBandwidth = ref.watch(lowBandwidthProvider);
    if (_isLoading) {
      return Scaffold(
        body: Container(
          decoration: BoxDecoration(
              color: lowBandwidth
                  ? (isLight ? AppColors.lightFlatBg : AppColors.darkFlatBg)
                  : null,
              gradient: lowBandwidth
                  ? null
                  : (isLight
                      ? AppColors.lightGradientBg
                      : AppColors.gradientBg)),
          child: const Center(child: CircularProgressIndicator()),
        ),
      );
    }

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          // P0 #8 — flat color in low-bandwidth mode.
          color: lowBandwidth
              ? (isLight ? AppColors.lightFlatBg : AppColors.darkFlatBg)
              : null,
          gradient: lowBandwidth
              ? null
              : (isLight ? AppColors.lightGradientBg : AppColors.gradientBg),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _l.t('settings.title'),
                  style: Theme.of(context).textTheme.displayLarge,
                ),
                const SizedBox(height: AppSpacing.xl),

                _SettingsSection(
                  title: _l.t('settings.services'),
                  children: [
                    _SettingsTile(
                      icon: Icons.cloud_outlined,
                      title: _l.t('settings.service_config'),
                      subtitle: _l.t('settings.service_config_subtitle'),
                      onTap: () => context.push('/service-config'),
                    ),
                    _SettingsTile(
                      icon: Icons.surround_sound_outlined,
                      title: _l.t('settings.voice_health'),
                      subtitle: _l.t('settings.voice_health_desc'),
                      onTap: () => context.push('/voice-health'),
                    ),
                    _SettingsTile(
                      icon: Icons.wifi_tethering,
                      title: _l.t('settings.test_current_profile'),
                      subtitle: _l.t('settings.test_current_profile_sub'),
                      onTap: _testCurrentProfile,
                    ),
                    _SettingsTile(
                      icon: Icons.restart_alt,
                      title: _l.t('settings.rerun_onboarding'),
                      subtitle: _l.t('settings.rerun_onboarding_sub'),
                      onTap: () => context.push('/onboarding'),
                    ),
                  ],
                ),

                const SizedBox(height: AppSpacing.lg),

                _SettingsSection(
                  title: _l.t('settings.learning'),
                  children: [
                    _SettingsTile(
                      icon: Icons.speed,
                      title: _l.t('settings.correction_strength'),
                      subtitle: _capitalize(_correctionStrength),
                      onTap: _showCorrectionStrengthDialog,
                    ),
                    _SettingsTile(
                      icon: Icons.volume_up_outlined,
                      title: _l.t('settings.tts_speed'),
                      subtitle: '${_ttsSpeed}x',
                      onTap: _showTtsSpeedDialog,
                    ),
                    _SettingsTile(
                      icon: Icons.restart_alt,
                      title: _l.t('placement.retake'),
                      subtitle: _l.t('placement.retake_sub'),
                      onTap: _retakePlacement,
                    ),
                  ],
                ),

                const SizedBox(height: AppSpacing.lg),

                _SettingsSection(
                  title: _l.t('settings.appearance'),
                  children: [
                    _SettingsTile(
                      icon: Icons.dark_mode_outlined,
                      title: _l.t('settings.theme'),
                      subtitle: _themeDisplayName(_theme),
                      onTap: _showThemeDialog,
                    ),
                    _SettingsTile(
                      icon: Icons.language,
                      title: _l.t('settings.language'),
                      subtitle: _localeDisplayName(ref.watch(localeProvider)),
                      onTap: _showLanguageDialog,
                    ),
                    // Phase-1 P0 #8 — low-bandwidth toggle. A switch tile
                    // instead of a chevron tile because the value flips in
                    // place; tapping the row OR the switch toggles it.
                    _SettingsToggleTile(
                      icon: Icons.data_saver_off,
                      title: _l.t('settings.low_bandwidth'),
                      subtitle: _l.t('settings.low_bandwidth_desc'),
                      value: ref.watch(lowBandwidthProvider),
                      onChanged: _toggleLowBandwidth,
                    ),
                  ],
                ),

                const SizedBox(height: AppSpacing.lg),

                _SettingsSection(
                  title: _l.t('settings.data'),
                  children: [
                    _SettingsTile(
                      icon: Icons.delete_outline,
                      title: _l.t('settings.clear_cache'),
                      subtitle: _l.t('settings.clear_cache_subtitle'),
                      onTap: _clearCache,
                      isDestructive: true,
                    ),
                  ],
                ),

                const SizedBox(height: AppSpacing.lg),

                _AppSection(),

                const SizedBox(height: AppSpacing.lg),

                _SettingsSection(
                  title: _l.t('settings.about'),
                  children: [
                    _SettingsTile(
                      icon: Icons.refresh,
                      title: _l.t('settings.rerun_setup'),
                      subtitle: _l.t('settings.rerun_setup_sub'),
                      onTap: _rerunOnboarding,
                    ),
                    _SettingsTile(
                      icon: Icons.info_outline,
                      title: _l.t('app.name'),
                      subtitle: _l.tArg('settings.version',
                          {'version': kAppVersion}),
                      onTap: _showAboutDialog,
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

  String _themeDisplayName(String key) {
    switch (key) {
      case 'dark':
        return _l.t('settings.theme_dark');
      case 'light':
        return _l.t('settings.theme_light');
      case 'system':
      default:
        return _l.t('settings.theme_system');
    }
  }

  String _localeDisplayName(AppLocale locale) => locale.nativeName;

  Future<void> _clearCache() async {
    try {
      await TtsPlaybackService().clearCache();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(_l.t('settings.cache_cleared'))),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_l.tArg('settings.cache_clear_failed',
                {'error': e.toString()})),
          ),
        );
      }
    }
  }

  Future<void> _testCurrentProfile() async {
    final repo = ref.read(profileRepoProvider);
    // Capture the root navigator BEFORE any await — after an unmount the
    // widget's `context` is dead, but the root navigator's state lives for
    // the whole app, so we can still pop the loading dialog we're about
    // to push.
    final rootNav = Navigator.of(context, rootNavigator: true);
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Dialog(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(),
              SizedBox(width: 16),
              Text('Testing…'),
            ],
          ),
        ),
      ),
    );
    final lines = <String>[];
    try {
      final llm = await repo.getActiveLlmProfile();
      if (llm == null) {
        lines.add(
          'LLM: ${_l.tArg('settings.test_no_active', {'kind': 'LLM'})}',
        );
      } else {
        final r = await ConnectionTester.testLlm(llm);
        lines.add('LLM: ${r.message}');
      }
      final stt = await repo.getActiveSttProfile();
      if (stt == null) {
        lines.add(
          'STT: ${_l.tArg('settings.test_no_active', {'kind': 'STT'})}',
        );
      } else {
        final r = await ConnectionTester.testStt(stt);
        lines.add('STT: ${r.message}');
      }
      final tts = await repo.getActiveTtsProfile();
      if (tts == null) {
        lines.add(
          'TTS: ${_l.tArg('settings.test_no_active', {'kind': 'TTS'})}',
        );
      } else {
        final r = await ConnectionTester.testTts(tts);
        lines.add('TTS: ${r.message}');
      }
    } catch (e) {
      lines.add('✗ ${e.toString()}');
    }
    // Always pop the loading dialog — even on unmount — so it can't
    // outlive the probe.
    rootNav.pop();
    if (!mounted) return;
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(_l.t('settings.test_results_title')),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: lines
              .map(
                (l) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Text(l),
                ),
              )
              .toList(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(_l.t('common.confirm')),
          ),
        ],
      ),
    );
  }

  /// Re-run the first-run wizard: clear the onboarding + placement flags so
  /// the router redirect sends the user back to /onboarding. Existing
  /// profiles are kept so they can be reused or edited.
  Future<void> _rerunOnboarding() async {
    final repo = ref.read(profileRepoProvider);
    await repo.setSetting('onboarding_completed', 'false');
    await repo.setSetting('placement_completed', 'false');
    if (mounted) context.go('/onboarding');
  }

  /// Re-take just the placement test (keeps onboarding + profiles intact).
  Future<void> _retakePlacement() async {
    await ref
        .read(profileRepoProvider)
        .setSetting('placement_completed', 'false');
    if (mounted) context.go('/placement');
  }

  void _showAboutDialog() {
    final isLight = Theme.of(context).brightness == Brightness.light;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor:
            isLight ? AppColors.lightBgSecondary : AppColors.bgTertiary,
        title: Text(_l.t('app.name')),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(_l.tArg('settings.version', {'version': kAppVersion})),
            const SizedBox(height: AppSpacing.md),
            Text(
              _l.t('settings.about_body'),
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(_l.t('common.back')),
          ),
        ],
      ),
    );
  }

  void _showCorrectionStrengthDialog() {
    String local = _correctionStrength;
    final isLight = Theme.of(context).brightness == Brightness.light;
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          backgroundColor: isLight
              ? AppColors.lightBgSecondary
              : AppColors.bgTertiary,
          title: Text(_l.t('settings.correction_strength')),
          content: RadioGroup<String>(
            groupValue: local,
            onChanged: (v) {
              if (v != null) setDialogState(() => local = v);
            },
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                RadioListTile<String>(
                  title: Text(_l.t('settings.correction_gentle')),
                  subtitle: Text(_l.t('settings.correction_gentle_sub')),
                  value: 'gentle',
                  activeColor: AppColors.accentPrimary,
                ),
                RadioListTile<String>(
                  title: Text(_l.t('settings.correction_moderate')),
                  subtitle: Text(_l.t('settings.correction_moderate_sub')),
                  value: 'moderate',
                  activeColor: AppColors.accentPrimary,
                ),
                RadioListTile<String>(
                  title: Text(_l.t('settings.correction_strict')),
                  subtitle: Text(_l.t('settings.correction_strict_sub')),
                  value: 'strict',
                  activeColor: AppColors.accentPrimary,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(_l.t('common.cancel')),
            ),
            ElevatedButton(
              onPressed: () async {
                await ref
                    .read(profileRepoProvider)
                    .setSetting('correction_strength', local);
                if (mounted) setState(() => _correctionStrength = local);
                if (ctx.mounted) Navigator.pop(ctx);
              },
              child: Text(_l.t('common.save')),
            ),
          ],
        ),
      ),
    );
  }

  void _showTtsSpeedDialog() {
    String local = _ttsSpeed;
    final isLight = Theme.of(context).brightness == Brightness.light;
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          backgroundColor: isLight
              ? AppColors.lightBgSecondary
              : AppColors.bgTertiary,
          title: Text(_l.t('settings.tts_speed')),
          content: RadioGroup<String>(
            groupValue: local,
            onChanged: (v) {
              if (v != null) setDialogState(() => local = v);
            },
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                RadioListTile<String>(
                  title: Text(_l.t('profile.speed_slower')),
                  value: '0.75',
                  activeColor: AppColors.accentPrimary,
                ),
                RadioListTile<String>(
                  title: Text(_l.t('profile.speed_normal')),
                  value: '1.0',
                  activeColor: AppColors.accentPrimary,
                ),
                RadioListTile<String>(
                  title: Text(_l.t('profile.speed_faster')),
                  value: '1.25',
                  activeColor: AppColors.accentPrimary,
                ),
                RadioListTile<String>(
                  title: Text(_l.t('profile.speed_fastest')),
                  value: '1.5',
                  activeColor: AppColors.accentPrimary,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(_l.t('common.cancel')),
            ),
            ElevatedButton(
              onPressed: () async {
                await ref
                    .read(profileRepoProvider)
                    .setSetting('tts_speed', local);
                if (mounted) setState(() => _ttsSpeed = local);
                if (ctx.mounted) Navigator.pop(ctx);
              },
              child: Text(_l.t('common.save')),
            ),
          ],
        ),
      ),
    );
  }

  void _showThemeDialog() {
    String local = _theme;
    final isLight = Theme.of(context).brightness == Brightness.light;
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          backgroundColor: isLight
              ? AppColors.lightBgSecondary
              : AppColors.bgTertiary,
          title: Text(_l.t('settings.theme')),
          content: RadioGroup<String>(
            groupValue: local,
            onChanged: (v) {
              if (v != null) setDialogState(() => local = v);
            },
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                RadioListTile<String>(
                  title: Text(_l.t('settings.theme_system')),
                  value: 'system',
                  activeColor: AppColors.accentPrimary,
                ),
                RadioListTile<String>(
                  title: Text(_l.t('settings.theme_dark')),
                  value: 'dark',
                  activeColor: AppColors.accentPrimary,
                ),
                RadioListTile<String>(
                  title: Text(_l.t('settings.theme_light')),
                  value: 'light',
                  activeColor: AppColors.accentPrimary,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(_l.t('common.cancel')),
            ),
            ElevatedButton(
              onPressed: () async {
                await ref.read(profileRepoProvider).setSetting('theme', local);
                ref.read(themeModeProvider.notifier).state =
                    _parseThemeMode(local);
                if (mounted) setState(() => _theme = local);
                if (ctx.mounted) Navigator.pop(ctx);
              },
              child: Text(_l.t('common.save')),
            ),
          ],
        ),
      ),
    );
  }

  void _showLanguageDialog() {
    AppLocale local = ref.read(localeProvider);
    final isLight = Theme.of(context).brightness == Brightness.light;
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          backgroundColor: isLight
              ? AppColors.lightBgSecondary
              : AppColors.bgTertiary,
          title: Text(_l.t('settings.language')),
          content: SizedBox(
            width: double.maxFinite,
            child: ListView(
              shrinkWrap: true,
              children: AppLocale.values
                  .map(
                    (locale) => RadioListTile<AppLocale>(
                      title: Text(locale.nativeName),
                      subtitle: Text(locale.englishName),
                      value: locale,
                      groupValue: local,
                      onChanged: (v) {
                        if (v != null) setDialogState(() => local = v);
                      },
                      activeColor: AppColors.accentPrimary,
                    ),
                  )
                  .toList(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(_l.t('common.cancel')),
            ),
            ElevatedButton(
              onPressed: () async {
                // Persist + push to the global provider so MaterialApp
                // rebuilds with the new locale immediately.
                await ref
                    .read(profileRepoProvider)
                    .setSetting('app_language', local.code);
                ref.read(localeProvider.notifier).state = local;
                if (ctx.mounted) Navigator.pop(ctx);
              },
              child: Text(_l.t('common.save')),
            ),
          ],
        ),
      ),
    );
  }
}

/// Section for app-level web/PWA controls: manual update check + install
/// banner reset. Reads the version + install providers directly so the
/// tiles reflect current state, and degrades gracefully on non-web
/// platforms (providers report `platformUnsupported`).
class _AppSection extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final versionState = ref.watch(versionServiceProvider);
    final installState = ref.watch(installPromptServiceProvider);

    if (installState.platformUnsupported && !versionState.isChecking &&
        versionState.serverVersion == null) {
      return const SizedBox.shrink();
    }

    final children = <Widget>[
      _SettingsTile(
        icon: Icons.system_update_alt_outlined,
        title: l.t('settings.check_updates'),
        subtitle: versionState.isChecking
            ? l.t('settings.checking')
            : (versionState.newVersionAvailable
                ? l.tArg('settings.update_available',
                    {'version': versionState.serverVersion ?? ''})
                : (versionState.serverVersion != null
                    ? l.tArg('settings.up_to_date',
                        {'version': versionState.serverVersion!})
                    : l.t('settings.tap_to_check'))),
        onTap: () async {
          await ref.read(versionServiceProvider.notifier).checkNow();
          if (!context.mounted) return;
          final s = ref.read(versionServiceProvider);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(s.newVersionAvailable
                  ? l.tArg('settings.new_version_in_banner',
                      {'version': s.serverVersion ?? ''})
                  : l.t('settings.latest_version')),
            ),
          );
        },
      ),
      if (installState.hasDismissed && !installState.isStandalone)
        _SettingsTile(
          icon: Icons.install_mobile_outlined,
          title: l.t('settings.show_install_again'),
          subtitle: l.t('settings.show_install_again_sub'),
          onTap: () async {
            await ref
                .read(installPromptServiceProvider.notifier)
                .resetDismissal();
            if (!context.mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(l.t('settings.install_will_show')),
              ),
            );
          },
        ),
    ];

    return _SettingsSection(title: l.t('settings.app'), children: children);
  }
}

class _SettingsSection extends StatelessWidget {
  final String title;
  final List<Widget> children;

  const _SettingsSection({required this.title, required this.children});

  @override
  Widget build(BuildContext context) {
    final isLight = Theme.of(context).brightness == Brightness.light;
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
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  color: isLight
                      ? AppColors.lightTextSecondary
                      : AppColors.textSecondary,
                ),
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
    final isLight = Theme.of(context).brightness == Brightness.light;
    final titleColor = isDestructive
        ? AppColors.error
        : (isLight ? AppColors.lightTextPrimary : AppColors.textPrimary);
    final subtitleColor = isLight
        ? AppColors.lightTextSecondary
        : AppColors.textSecondary;
    final chevronColor =
        isLight ? AppColors.lightTextMuted : AppColors.textMuted;
    return ListTile(
      onTap: onTap,
      leading: Icon(
        icon,
        color: isDestructive ? AppColors.error : AppColors.accentSecondary,
      ),
      title: Text(title, style: TextStyle(color: titleColor)),
      subtitle: Text(
        subtitle,
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: subtitleColor,
            ),
      ),
      trailing: Icon(
        Icons.chevron_right,
        color: chevronColor,
        size: 20,
      ),
    );
  }
}

/// Phase-1 P0 #8 — settings tile with a trailing Switch instead of a
/// chevron. Tapping the row OR the switch toggles the value, mirroring
/// the standard Material SwitchListTile affordance but styled to match
/// the existing _SettingsTile look (icon + title + subtitle).
class _SettingsToggleTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _SettingsToggleTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final isLight = Theme.of(context).brightness == Brightness.light;
    final titleColor =
        isLight ? AppColors.lightTextPrimary : AppColors.textPrimary;
    final subtitleColor = isLight
        ? AppColors.lightTextSecondary
        : AppColors.textSecondary;
    return ListTile(
      onTap: () => onChanged(!value),
      leading: Icon(icon, color: AppColors.accentSecondary),
      title: Text(title, style: TextStyle(color: titleColor)),
      subtitle: Text(
        subtitle,
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: subtitleColor,
            ),
      ),
      trailing: Switch(
        value: value,
        onChanged: onChanged,
      ),
    );
  }
}
