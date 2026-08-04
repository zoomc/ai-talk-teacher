import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../database/database_helper.dart';
import '../theme/app_colors.dart';
import 'runtime_config.dart';
import 'simulation_runtime.dart';
import '../../shared/providers.dart';

/// Visible, non-blocking indicator for isolated Simulation builds.
class RuntimeModeBanner extends ConsumerWidget {
  const RuntimeModeBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!RuntimeConfig.isSimulation) return const SizedBox.shrink();
    final fixtureId = ref.watch(simulationFixtureProvider);
    final fixture = SimulationFixtures.byId(fixtureId);
    final isE2e = RuntimeConfig.isE2E;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.accentPrimary.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: AppColors.accentPrimary.withValues(alpha: 0.35),
        ),
      ),
      child: Wrap(
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 12,
        runSpacing: 8,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.science_outlined,
                size: 18,
                color: AppColors.accentPrimary,
              ),
              const SizedBox(width: 8),
              Text(
                isE2e ? 'E2E Simulation' : 'Demo Simulation',
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ],
          ),
          Text(
            'No real AI requests · isolated ${RuntimeConfig.storageNamespace} data',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          if (!isE2e)
            DropdownButton<String>(
              value: fixture.id,
              isDense: true,
              underline: const SizedBox.shrink(),
              items: [
                for (final option in SimulationFixtures.values)
                  DropdownMenuItem(value: option.id, child: Text(option.title)),
              ],
              onChanged: (value) {
                if (value == null) return;
                ref.read(simulationFixtureProvider.notifier).state = value;
                ref.read(simulationRuntimeProvider).selectFixture(value);
              },
            ),
          if (!isE2e)
            OutlinedButton.icon(
              onPressed: () async {
                await DatabaseHelper.resetIsolatedRuntimeData();
                ref.read(simulationRuntimeProvider).reset();
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Demo data reset')),
                  );
                }
              },
              icon: const Icon(Icons.restart_alt, size: 16),
              label: const Text('Reset data'),
            ),
        ],
      ),
    );
  }
}
