/// Central Permissions Dashboard Page.
///
/// Full-screen page that shows all 10 permissions with their statuses,
/// allows individual or batch request, and opens explanation sheets.
/// Kurdish-first RTL layout.
library;

import 'package:flutter/material.dart';
import 'package:texo/l10n/app_localizations.dart';
import 'package:texo/features/device_integration/domain/models/permission_status.dart';
import 'package:texo/features/central_permissions/application/central_permission_controller.dart';
import 'package:texo/features/central_permissions/application/central_permission_state.dart';
import 'package:texo/features/central_permissions/presentation/permission_status_card.dart';
import 'package:texo/features/central_permissions/presentation/permission_explanation_sheet.dart';
import 'package:texo/features/central_permissions/domain/models/permission_explanation.dart';

class PermissionRequestPage extends StatefulWidget {
  final CentralPermissionController controller;

  const PermissionRequestPage({
    super.key,
    required this.controller,
  });

  @override
  State<PermissionRequestPage> createState() => _PermissionRequestPageState();
}

class _PermissionRequestPageState extends State<PermissionRequestPage> {
  CentralPermissionState? _lastState;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    widget.controller.listen(_onStateChanged);
    _checkAll();
  }

  void _onStateChanged(CentralPermissionState state) {
    if (!mounted) return;
    setState(() {
      _lastState = state;
      _isLoading = state.isLoading;
    });
  }

  Future<void> _checkAll() async {
    setState(() => _isLoading = true);
    await widget.controller.checkAllPermissions();
  }

  Future<void> _requestAll() async {
    setState(() => _isLoading = true);
    await widget.controller.requestAllPermissions();
  }

  Future<void> _requestSingle(DevicePermission permission) async {
    final explanation = PermissionExplanation.defaults[permission] ??
        PermissionExplanation(
          permission: permission,
          titleKey: 'perm_${permission.name}_title',
          bodyKey: 'perm_${permission.name}_body',
          featureName: 'unknown',
        );
    final userConfirmed = await showPermissionExplanationSheet(
      context: context,
      explanation: explanation,
    );
    if (!userConfirmed) return;
    await widget.controller.requestPermission(permission);
  }

  void _openSettings(DevicePermission permission) {
    widget.controller.openPermissionSettings(permission);
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final isRtl = Directionality.of(context) == TextDirection.rtl;

    return Directionality(
      // Kurdish-first: default RTL, LTR only for English
      textDirection: isRtl ? TextDirection.rtl : TextDirection.ltr,
      child: Scaffold(
        appBar: AppBar(
          title: Text(s.perm_dashboard_title),
          centerTitle: true,
        ),
        body: _isLoading
            ? Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const CircularProgressIndicator(),
                    const SizedBox(height: 16),
                    Text(s.perm_loading),
                  ],
                ),
              )
            : _buildBody(context, s),
        bottomNavigationBar: _buildBottomBar(context, s),
      ),
    );
  }

  Widget _buildBody(BuildContext context, S s) {
    final state = _lastState;

    // Error state
    if (state?.hasFailure ?? false) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline, size: 48, color: Colors.red[300]),
            const SizedBox(height: 16),
            Text(
              s.perm_error_occurred,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: _checkAll,
              icon: const Icon(Icons.refresh),
              label: Text(s.perm_check_all),
            ),
          ],
        ),
      );
    }

    // All granted
    if (state?.allGranted ?? false) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.check_circle_outline, size: 64, color: Colors.green[400]),
            const SizedBox(height: 16),
            Text(
              s.perm_all_granted,
              style: Theme.of(context).textTheme.headlineSmall,
            ),
          ],
        ),
      );
    }

    // Some denied / not yet checked
    final permissions = DevicePermission.values;
    final statusMap = state?.statuses ?? {};

    return Column(
      children: [
        // Subtitle
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
          child: Text(
            s.perm_dashboard_subtitle,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ),
        if (state?.someDenied ?? false)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
            child: Text(
              s.perm_some_denied,
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: Colors.orange[700]),
            ),
          ),
        // Permission cards
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            itemCount: permissions.length,
            itemBuilder: (context, index) {
              final perm = permissions[index];
              final status = statusMap[perm] ?? PermissionStatus.notRequested;
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: PermissionStatusCard(
                  permission: perm,
                  status: status,
                  onRequest: () => _requestSingle(perm),
                  onOpenSettings: () => _openSettings(perm),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget? _buildBottomBar(BuildContext context, S s) {
    final state = _lastState;
    if (_isLoading) return null;
    if (state?.allGranted ?? false) return null;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _checkAll,
                icon: const Icon(Icons.refresh),
                label: Text(s.perm_check_all),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: FilledButton.icon(
                onPressed: _requestAll,
                icon: const Icon(Icons.checklist),
                label: Text(s.perm_request_all),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
