import 'package:flutter/material.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../chat/domain/tutor_emotion.dart';
import '../../domain/viseme_mapping.dart';
import '../../domain/viseme_timeline.dart';
import '../widgets/avatar_stage.dart';

/// Manual avatar QA surface. It is intentionally reachable only in Demo/E2E
/// builds through the conditional `/lab/avatar` route.
class AvatarLabScreen extends StatefulWidget {
  const AvatarLabScreen({super.key});

  @override
  State<AvatarLabScreen> createState() => _AvatarLabScreenState();
}

class _AvatarLabScreenState extends State<AvatarLabScreen> {
  final _avatarKey = GlobalKey<AvatarStageState>();
  late final TextEditingController _sampleController;
  AvatarPhase _phase = AvatarPhase.idle;
  TutorEmotion _emotion = TutorEmotion.neutral;
  TutorGestureCue _gesture = TutorGestureCue.idle;
  bool _prefer3d = true;
  bool _reduceMotion = false;

  @override
  void initState() {
    super.initState();
    _sampleController = TextEditingController(
      text: 'That sounds great! Tell me more.',
    );
  }

  @override
  void dispose() {
    _sampleController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Avatar Lab'),
        actions: [
          IconButton(
            tooltip: 'Close Avatar Lab',
            onPressed: () => Navigator.of(context).maybePop(),
            icon: const Icon(Icons.close),
          ),
        ],
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final wide = constraints.maxWidth >= 760;
          final preview = SizedBox(
            height: wide ? 560 : 420,
            child: RepaintBoundary(
              child: AvatarStage(
                key: _avatarKey,
                phase: _phase,
                emotion: _emotion,
                gesture: _gesture,
                tutorName: 'Maya',
                speakingText: _phase == AvatarPhase.speaking
                    ? _sampleController.text
                    : null,
                prefer3d: _prefer3d,
                reduceMotion: _reduceMotion,
              ),
            ),
          );
          final controls = _buildControls(context);
          return SingleChildScrollView(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: wide
                ? Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(child: preview),
                      const SizedBox(width: AppSpacing.lg),
                      SizedBox(width: 340, child: controls),
                    ],
                  )
                : Column(children: [preview, controls]),
          );
        },
      ),
    );
  }

  Widget _buildControls(BuildContext context) {
    final visemePreview = _phase == AvatarPhase.speaking;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('State', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: AppSpacing.xs),
            Wrap(
              spacing: AppSpacing.xs,
              runSpacing: AppSpacing.xs,
              children: [
                for (final phase in AvatarPhase.values)
                  ChoiceChip(
                    label: Text(phase.name),
                    selected: _phase == phase,
                    onSelected: (_) => setState(() => _phase = phase),
                  ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            DropdownButtonFormField<TutorEmotion>(
              initialValue: _emotion,
              decoration: const InputDecoration(labelText: 'Emotion'),
              items: [
                for (final emotion in TutorEmotion.values)
                  DropdownMenuItem(value: emotion, child: Text(emotion.id)),
              ],
              onChanged: (value) {
                if (value != null) setState(() => _emotion = value);
              },
            ),
            const SizedBox(height: AppSpacing.sm),
            DropdownButtonFormField<TutorGestureCue>(
              initialValue: _gesture,
              decoration: const InputDecoration(labelText: 'Gesture cue'),
              items: [
                for (final gesture in TutorGestureCue.values)
                  DropdownMenuItem(value: gesture, child: Text(gesture.id)),
              ],
              onChanged: (value) {
                if (value != null) setState(() => _gesture = value);
              },
            ),
            const SizedBox(height: AppSpacing.sm),
            SwitchListTile.adaptive(
              contentPadding: EdgeInsets.zero,
              title: const Text('Cinematic 3D'),
              subtitle: const Text('Use the WebGL teacher with 2D fallback'),
              value: _prefer3d,
              onChanged: (value) => setState(() => _prefer3d = value),
            ),
            SwitchListTile.adaptive(
              contentPadding: EdgeInsets.zero,
              title: const Text('Reduce motion'),
              value: _reduceMotion,
              onChanged: (value) => setState(() => _reduceMotion = value),
            ),
            TextField(
              controller: _sampleController,
              decoration: const InputDecoration(labelText: 'Speech sample'),
            ),
            const SizedBox(height: AppSpacing.sm),
            FilledButton.icon(
              onPressed: visemePreview ? _playVisemeSample : null,
              icon: const Icon(Icons.record_voice_over),
              label: const Text('Apply deterministic visemes'),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              '2D renderer: layered vector fallback · 3D: WebGL/GLB · '
              'visemes: ${visemePreview ? 'ready' : 'switch to speaking'}',
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
            ),
          ],
        ),
      ),
    );
  }

  void _playVisemeSample() {
    _avatarKey.currentState?.setVisemeTimeline(
      const VisemeTimeline(
        duration: 2.4,
        cues: [
          VisemeCue(start: 0, viseme: RhubarbViseme.x),
          VisemeCue(start: 0.35, viseme: RhubarbViseme.g),
          VisemeCue(start: 0.85, viseme: RhubarbViseme.f),
          VisemeCue(start: 1.35, viseme: RhubarbViseme.h),
          VisemeCue(start: 1.9, viseme: RhubarbViseme.x),
        ],
      ),
    );
  }
}
