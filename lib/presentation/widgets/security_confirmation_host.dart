/// Host widget that renders the pending tool-security confirmation dialog.
///
/// Wrap any long-lived screen (e.g. the main shell) with this widget so that
/// risky tool calls surface a modal approval prompt. No action is approved
/// unless the user explicitly taps the approve button.
///
/// All hardcoded strings now use l10n keys for Kurdish RTL support.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:aura_assistant/l10n/app_localizations.dart';

import '../../core/agent/agent_confirmation_manager.dart' show ToolRiskLevel;
import '../../core/security/confirmation_guard.dart';
import '../providers/security_confirmation_provider.dart';

class SecurityConfirmationHost extends ConsumerStatefulWidget {
  const SecurityConfirmationHost({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<SecurityConfirmationHost> createState() =>
      _SecurityConfirmationHostState();
}

class _SecurityConfirmationHostState
    extends ConsumerState<SecurityConfirmationHost> {
  bool _dialogOpen = false;

  @override
  Widget build(BuildContext context) {
    ref.listen<ToolConfirmationRequest?>(securityConfirmationProvider,
        (previous, next) {
      if (next != null && !_dialogOpen) {
        _showDialog(next);
      } else if (next == null && _dialogOpen) {
        _dialogOpen = false;
        final navigator = Navigator.of(context, rootNavigator: true);
        if (navigator.canPop()) navigator.pop();
      }
    });
    return widget.child;
  }

  Future<void> _showDialog(ToolConfirmationRequest request) async {
    _dialogOpen = true;
    final controller = ref.read(securityConfirmationProvider.notifier);
    final l10n = S.of(context);
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      useRootNavigator: true,
      builder: (dialogContext) {
        final theme = Theme.of(dialogContext);
        return AlertDialog(
          icon: const Icon(Icons.shield_outlined),
          title: Text(_riskTitle(l10n, request.riskLevel),
              textDirection: TextDirection.rtl),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(request.message, textDirection: TextDirection.rtl),
              const SizedBox(height: 12),
              Text(
                'Tool: ${request.toolName}',
                style: theme.textTheme.bodySmall,
              ),
              if (request.contextDescription.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  request.contextDescription,
                  style: theme.textTheme.bodySmall,
                  textDirection: TextDirection.rtl,
                ),
              ],
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext).pop();
                controller.reject();
              },
              child: Text(l10n.securityCancel),
            ),
            FilledButton(
              onPressed: () {
                Navigator.of(dialogContext).pop();
                controller.approve();
              },
              child: Text(l10n.securityAllowOnce),
            ),
          ],
        );
      },
    );
    if (_dialogOpen) {
      // Dialog closed without an explicit decision → treat as denial.
      _dialogOpen = false;
      controller.reject();
    }
  }

  String _riskTitle(S l10n, ToolRiskLevel level) {
    switch (level) {
      case ToolRiskLevel.critical:
        return l10n.securityRiskCritical;
      case ToolRiskLevel.high:
        return l10n.securityRiskHigh;
      case ToolRiskLevel.medium:
        return l10n.securityRiskMedium;
      default:
        return l10n.securityRiskLow;
    }
  }
}