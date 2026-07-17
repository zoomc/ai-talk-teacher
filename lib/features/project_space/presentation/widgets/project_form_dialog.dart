import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/i18n/app_localizations.dart';
import '../../../../shared/providers.dart';
import '../../../../shared/widgets/glass_widgets.dart';
import '../../domain/project_icon_catalog.dart';
import '../../domain/project_models.dart';
import '../../domain/project_palette.dart';
import 'project_color_picker.dart';
import 'project_icon_picker.dart';

/// New/edit project dialog. Pass an existing [project] to edit; omit it
/// for create mode. Returns the saved [Project] via `Navigator.pop(context, p)`.
class ProjectFormDialog extends ConsumerStatefulWidget {
  final Project? project;
  const ProjectFormDialog({super.key, this.project});

  @override
  ConsumerState<ProjectFormDialog> createState() => _ProjectFormDialogState();
}

class _ProjectFormDialogState extends ConsumerState<ProjectFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _descriptionController;
  late final TextEditingController _goalController;
  late String _iconName;
  late String _colorHex;
  late ProjectStatus _status;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final p = widget.project;
    _nameController = TextEditingController(text: p?.name ?? '');
    _descriptionController = TextEditingController(text: p?.description ?? '');
    _goalController = TextEditingController(text: p?.goal ?? '');
    _iconName = p?.icon ?? ProjectIconCatalog.defaultName;
    _colorHex = p?.color ?? ProjectPalette.defaultHex;
    _status = p?.status ?? ProjectStatus.active;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _goalController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final isEdit = widget.project != null;
    return GlassDialog(
      title: Text(isEdit ? l.t('projects.dialog.edit') : l.t('projects.dialog.new')),
      content: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextFormField(
                controller: _nameController,
                decoration: InputDecoration(
                  labelText: l.t('projects.dialog.name_label'),
                ),
                validator: (v) =>
                    (v == null || v.isEmpty) ? l.t('common.required') : null,
              ),
              const SizedBox(height: AppSpacing.md),
              Text(l.t('projects.dialog.icon_label'),
                  style: Theme.of(context).textTheme.titleSmall),
              const SizedBox(height: AppSpacing.xs),
              ProjectIconPicker(
                selectedName: _iconName,
                onSelected: (n) => setState(() => _iconName = n),
              ),
              const SizedBox(height: AppSpacing.md),
              Text(l.t('projects.dialog.color_label'),
                  style: Theme.of(context).textTheme.titleSmall),
              const SizedBox(height: AppSpacing.xs),
              ProjectColorPicker(
                selectedHex: _colorHex,
                onSelected: (h) => setState(() => _colorHex = h),
              ),
              const SizedBox(height: AppSpacing.md),
              TextFormField(
                controller: _descriptionController,
                maxLines: 2,
                decoration: InputDecoration(
                  labelText: l.t('projects.dialog.description_label'),
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              TextFormField(
                controller: _goalController,
                maxLines: 2,
                decoration: InputDecoration(
                  labelText: l.t('projects.dialog.goal_label'),
                ),
              ),
              if (isEdit) ...[
                const SizedBox(height: AppSpacing.md),
                DropdownButtonFormField<ProjectStatus>(
                  initialValue: _status,
                  decoration: InputDecoration(
                    labelText: l.t('projects.dialog.status_label'),
                  ),
                  items: ProjectStatus.values
                      .map((s) => DropdownMenuItem(
                            value: s,
                            child: Text(l.t('projects.status.${s.name}')),
                          ))
                      .toList(),
                  onChanged: (v) => setState(() => _status = v ?? _status),
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.of(context).pop(),
          child: Text(l.t('common.cancel')),
        ),
        FilledButton(
          onPressed: _saving ? null : _save,
          child: _saving
              ? const SizedBox(
                  width: 18, height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2))
              : Text(l.t('common.save')),
        ),
      ],
    );
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    final repo = ref.read(projectRepoProvider);
    try {
      Project saved;
      if (widget.project == null) {
        saved = await repo.createProject(
          name: _nameController.text.trim(),
          icon: _iconName,
          color: _colorHex,
          description: _descriptionController.text.trim(),
          goal: _goalController.text.trim(),
        );
      } else {
        saved = widget.project!.copyWith(
          name: _nameController.text.trim(),
          icon: _iconName,
          color: _colorHex,
          description: _descriptionController.text.trim(),
          goal: _goalController.text.trim(),
          status: _status,
        );
        await repo.updateProject(saved);
      }
      if (mounted) Navigator.of(context).pop(saved);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${AppLocalizations.of(context).t('common.error')}: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
}
