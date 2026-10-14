import 'package:flutter/material.dart';

import 'backend.dart';
import 'colors.dart';
import 'scope.dart';
import 'strings.dart';
import 'widgets.dart';

class _Opt {
  const _Opt(this.label, this.value);

  final String label;
  final String value;
}

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  Map<String, bool> _toggles = <String, bool>{};
  Map<String, bool> _perms = <String, bool>{};
  bool _hasKey = false;
  bool _loaded = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_loaded) {
      _loaded = true;
      _load(UiScope.of(context).backend);
    }
  }

  Future<void> _load(TexoBackend b) async {
    final Map<String, bool> t = await b.toggles();
    final Map<String, bool> p = await b.permissionStates();
    final bool k = await b.hasApiKey();
    if (!mounted) return;
    setState(() {
      _toggles = t;
      _perms = p;
      _hasKey = k;
    });
  }

  Widget _card({required Widget child, EdgeInsets padding = const EdgeInsets.fromLTRB(16, 14, 16, 14)}) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: UiColors.white,
        borderRadius: BorderRadius.circular(22),
        boxShadow: UiColors.cardShadow,
      ),
      child: child,
    );
  }

  Widget _title(String text) => Text(
        text,
        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: UiColors.inkSoft),
      );

  Widget _segmented(List<_Opt> opts, String selected, ValueChanged<String> onChanged) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: UiColors.segTrack,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: <Widget>[
          for (final _Opt o in opts)
            Expanded(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => onChanged(o.value),
                child: Container(
                  height: 44,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: o.value == selected ? UiColors.white : Colors.transparent,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: o.value == selected
                        ? const <BoxShadow>[
                            BoxShadow(color: Color(0x2E141E50), blurRadius: 6, offset: Offset(0, 1)),
                          ]
                        : null,
                  ),
                  child: Text(
                    o.label,
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _switchRow(UiStrings s, TexoBackend b, String key, String label, String sub) {
    final bool on = _toggles[key] ?? false;
    return SizedBox(
      height: 64,
      child: Row(
        children: <Widget>[
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(label, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
                Text(sub, style: const TextStyle(fontSize: 13, height: 1.6, color: UiColors.inkSoft)),
              ],
            ),
          ),
          Semantics(
            toggled: on,
            label: label,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () {
                setState(() => _toggles = <String, bool>{..._toggles, key: !on});
                b.setToggle(key, !on);
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: 52,
                height: 32,
                padding: const EdgeInsets.all(4),
                alignment: on ? AlignmentDirectional.centerEnd : AlignmentDirectional.centerStart,
                decoration: BoxDecoration(
                  color: on ? UiColors.violet : UiColors.switchOff,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Container(
                  width: 24,
                  height: 24,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white,
                    boxShadow: <BoxShadow>[
                      BoxShadow(color: Color(0x4D000000), blurRadius: 4, offset: Offset(0, 1)),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _statusRow(UiStrings s, String label, String sub, bool on, VoidCallback onTap, {String? statusText}) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: SizedBox(
        height: 64,
        child: Row(
          children: <Widget>[
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(label, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
                  Text(sub, style: const TextStyle(fontSize: 13, height: 1.6, color: UiColors.inkSoft)),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: on ? const Color(0xFFDDF5E6) : const Color(0xFFECEEF3),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                statusText ?? (on ? s.t('on') : s.t('off')),
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: on ? const Color(0xFF146C3B) : const Color(0xFF4B4F5C),
                ),
              ),
            ),
            const SizedBox(width: 6),
            const Icon(Icons.chevron_right, size: 20, color: UiColors.inkSoft),
          ],
        ),
      ),
    );
  }

  Future<void> _editKey(BuildContext context, UiStrings s, TexoBackend b) async {
    final TextEditingController ctl = TextEditingController();
    final String? value = await showDialog<String>(
      context: context,
      builder: (BuildContext ctx) => AlertDialog(
        title: Text(s.t('apiKey')),
        content: TextField(
          controller: ctl,
          obscureText: true,
          autofocus: true,
          decoration: InputDecoration(hintText: s.t('apiKeyHint')),
        ),
        actions: <Widget>[
          TextButton(onPressed: () => Navigator.of(ctx).pop(), child: Text(s.t('cancel'))),
          TextButton(onPressed: () => Navigator.of(ctx).pop(ctl.text), child: Text(s.t('save'))),
        ],
      ),
    );
    ctl.dispose();
    if (value == null || value.trim().isEmpty) return;
    await b.setApiKey(value.trim());
    final bool k = await b.hasApiKey();
    if (!mounted) return;
    setState(() => _hasKey = k);
  }

  @override
  Widget build(BuildContext context) {
    final UiScope scope = UiScope.of(context);
    final UiStrings s = scope.s;
    final TexoBackend b = scope.backend;
    final UiSettings settings = scope.settings;
    return Scaffold(
      body: UiBackground(
        kind: 1,
        child: SafeArea(
          child: Column(
            children: <Widget>[
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
                child: Row(
                  children: <Widget>[
                    UiIconButton(
                      icon: Icons.arrow_back_ios_new,
                      label: s.t('back'),
                      size: 22,
                      onTap: () => Navigator.of(context).pop(),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      s.t('settings'),
                      style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(16, 6, 16, 28),
                  children: <Widget>[
                    _card(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          _title(s.t('language')),
                          const SizedBox(height: 10),
                          _segmented(
                            const <_Opt>[_Opt('کوردی', 'ku'), _Opt('English', 'en')],
                            settings.lang,
                            settings.setLang,
                          ),
                          const SizedBox(height: 10),
                          Text(
                            s.t('langNote'),
                            style: const TextStyle(fontSize: 13, height: 1.7, color: UiColors.inkSoft),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),
                    _card(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          _title(s.t('appearance')),
                          const SizedBox(height: 10),
                          _segmented(
                            <_Opt>[
                              _Opt(s.t('light'), 'light'),
                              _Opt(s.t('dark'), 'dark'),
                              _Opt(s.t('system'), 'system'),
                            ],
                            settings.theme,
                            settings.setTheme,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),
                    _card(
                      padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          _title(s.t('voice')),
                          _switchRow(s, b, 'wake', s.t('wake'), s.t('wakeSub')),
                          _switchRow(s, b, 'read', s.t('readAloud'), s.t('readSub')),
                          _switchRow(s, b, 'hap', s.t('haptics'), s.t('hapSub')),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),
                    _card(
                      padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          _title(s.t('permissions')),
                          _statusRow(s, s.t('overlay'), s.t('overlaySub'), _perms['overlay'] ?? false,
                              () => b.openPermission('overlay')),
                          _statusRow(s, s.t('access'), s.t('accessSub'), _perms['access'] ?? false,
                              () => b.openPermission('access')),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),
                    _card(
                      padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          _statusRow(
                            s,
                            s.t('apiKey'),
                            s.t('apiKeySub'),
                            _hasKey,
                            () => _editKey(context, s, b),
                            statusText: _hasKey ? s.t('keySet') : s.t('keyMissing'),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 18),
                    Row(
                      children: <Widget>[
                        const TexoLogo(size: 40, radius: 11, shadow: false),
                        const SizedBox(width: 12),
                        Text(
                          'TEXO\n${s.t('version')}',
                          style: const TextStyle(fontSize: 13, height: 1.6, color: UiColors.inkSoft),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
