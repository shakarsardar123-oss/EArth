import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:texo/l10n/app_localizations.dart';

import '../../core/providers/phase3_connection_points.dart';
import '../../core/theme/app_colors.dart';
import 'glass_card.dart';
import 'glass_dialog.dart';

/// Agent name editor row — opens a glass dialog to change the name.
///
/// Rebuilt with new design system: GlassDialog, GlassTextField,
/// GlassButton instead of AuraDialog/AuraTextField/AuraButton.
class NameEditor extends ConsumerStatefulWidget {
  const NameEditor({super.key});

  @override
  ConsumerState<NameEditor> createState() => _NameEditorState();
}

class _NameEditorState extends ConsumerState<NameEditor> {
  late TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: ref.read(agentNameProvider));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = S.of(context);
    final currentName = ref.watch(agentNameProvider);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: GlassCard(
        onTap: () => _showEditDialog(context, currentName),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.violet.withOpacity(0.12),
                border: Border.all(
                  color: AppColors.violetLight.withOpacity(0.2),
                  width: 0.5,
                ),
              ),
              child: Icon(
                Icons.smart_toy_outlined,
                color: AppColors.cyan,
                size: 20,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l10n.agentNameLabel,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: AppColors.violetLight,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    currentName,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: AppColors.onBackground,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.edit_outlined,
              size: 18,
              color: AppColors.hint,
            ),
          ],
        ),
      ),
    );
  }

  void _showEditDialog(BuildContext context, String currentName) {
    final l10n = S.of(context);
    _controller.text = currentName;
    _controller.selection = TextSelection.collapsed(offset: currentName.length);

    GlassDialog.show(
      context: context,
      icon: Icons.smart_toy_outlined,
      title: l10n.changeName,
      content: Padding(
        padding: const EdgeInsets.only(top: 8),
        child: GlassTextField(
          controller: _controller,
          label: l10n.agentNameLabel,
          autofocus: true,
        ),
      ),
      actions: [
        GlassButton(
          label: l10n.saveChanges,
          variant: GlassButtonVariant.filled,
          onPressed: () {
            final name = _controller.text.trim();
            if (name.isNotEmpty) {
              ref.read(agentNameProvider.notifier).state = name;
            }
            Navigator.of(context).pop();
          },
        ),
      ],
    );
  }
}
