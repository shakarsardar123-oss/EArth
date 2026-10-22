import 'package:flutter/material.dart';

import 'backend.dart';
import 'colors.dart';
import 'scope.dart';

/// First-run flow: the permissions come one at a time. Each step explains what
/// the permission is for and has one big button; when it is given the next one
/// appears.
class PermissionsFlowScreen extends StatefulWidget {
  const PermissionsFlowScreen({super.key, required this.extras});

  final TexoPermissionsExtras extras;

  @override
  State<PermissionsFlowScreen> createState() => _PermissionsFlowScreenState();
}

class _PermissionsFlowScreenState extends State<PermissionsFlowScreen> with WidgetsBindingObserver {
  int _i = 0;
  bool _granted = false;
  bool _busy = false;

  List<UiPermissionItem> get _items => widget.extras.permissionItems;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _check();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Back from a settings page: look again.
    if (state == AppLifecycleState.resumed) _check(auto: true);
  }

  Future<void> _check({bool auto = false}) async {
    if (_i >= _items.length) return;
    final int at = _i;
    final bool ok = await widget.extras.permissionGranted(_items[at].id);
    if (!mounted || at != _i) return;
    setState(() => _granted = ok);
    if (ok && auto) {
      Future<void>.delayed(const Duration(milliseconds: 600), () {
        if (mounted && _i == at) _next();
      });
    }
  }

  Future<void> _enable() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await widget.extras.requestPermission(_items[_i].id);
    } catch (_) {}
    if (mounted) setState(() => _busy = false);
    await _check(auto: true);
  }

  void _next() {
    if (_i + 1 >= _items.length) {
      _finish();
      return;
    }
    setState(() {
      _i++;
      _granted = false;
    });
    _check();
  }

  Future<void> _finish() async {
    try {
      await widget.extras.finishOnboarding();
    } catch (_) {}
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final bool ku = UiScope.of(context).s.isKu;
    final List<UiPermissionItem> items = _items;
    if (items.isEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _finish());
      return const Scaffold(body: SizedBox.shrink());
    }
    final UiPermissionItem it = items[_i];
    final bool last = _i == items.length - 1;
    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: UiColors.lightTop,
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    for (int k = 0; k < items.length; k++)
                      Expanded(
                        child: Container(
                          height: 5,
                          margin: const EdgeInsets.symmetric(horizontal: 3),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(3),
                            color: k <= _i ? UiColors.violet : const Color(0x22000000),
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  '${_i + 1} / ${items.length}',
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 13, color: UiColors.inkSoft),
                ),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: <Widget>[
                      Container(
                        width: 120,
                        height: 120,
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          color: Color(0x1F7C3AED),
                        ),
                        child: Icon(
                          _granted ? Icons.check_circle_outline : it.icon,
                          size: 56,
                          color: UiColors.violet,
                        ),
                      ),
                      const SizedBox(height: 28),
                      Text(
                        ku ? it.titleKu : it.titleEn,
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w700, color: UiColors.ink),
                      ),
                      const SizedBox(height: 14),
                      Text(
                        ku ? it.bodyKu : it.bodyEn,
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontSize: 16, height: 1.8, color: UiColors.inkSoft),
                      ),
                      if (_granted) ...<Widget>[
                        const SizedBox(height: 18),
                        Text(
                          ku ? 'چالاک کرا' : 'Enabled',
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: UiColors.violet),
                        ),
                      ],
                    ],
                  ),
                ),
                FilledButton(
                  onPressed: _busy ? null : (_granted ? _next : _enable),
                  style: FilledButton.styleFrom(
                    backgroundColor: UiColors.violet,
                    minimumSize: const Size.fromHeight(54),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                  ),
                  child: Text(
                    _granted
                        ? (last ? (ku ? 'تەواو' : 'Done') : (ku ? 'دواتر' : 'Next'))
                        : (ku ? 'چالاک بکە' : 'Enable'),
                    style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
                  ),
                ),
                const SizedBox(height: 6),
                TextButton(
                  onPressed: _next,
                  child: Text(
                    last ? (ku ? 'تێپەڕە و دەرچە' : 'Skip and finish') : (ku ? 'تێپەڕە' : 'Skip'),
                    style: const TextStyle(fontSize: 15, color: UiColors.inkSoft),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
