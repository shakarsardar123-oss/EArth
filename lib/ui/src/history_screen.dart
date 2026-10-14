import 'package:flutter/material.dart';

import 'backend.dart';
import 'chat_screen.dart';
import 'colors.dart';
import 'scope.dart';
import 'strings.dart';
import 'widgets.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  Future<List<UiConversation>>? _future;
  final TextEditingController _search = TextEditingController();

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _future ??= UiScope.of(context).backend.conversations();
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  String _timeLabel(UiStrings s, DateTime t, int diffDays) {
    if (diffDays <= 0) {
      final String h = t.hour.toString().padLeft(2, '0');
      final String m = t.minute.toString().padLeft(2, '0');
      return s.digits('$h:$m');
    }
    return s.digits('${t.day}/${t.month}');
  }

  @override
  Widget build(BuildContext context) {
    final UiScope scope = UiScope.of(context);
    final UiStrings s = scope.s;
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
                    Expanded(
                      child: Text(
                        s.t('historyTitle'),
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                      ),
                    ),
                    UiIconButton(
                      icon: Icons.add,
                      label: s.t('newChat'),
                      size: 22,
                      color: Colors.white,
                      background: UiColors.violet,
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute<void>(builder: (BuildContext _) => const ChatScreen()),
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                height: 48,
                margin: const EdgeInsets.fromLTRB(16, 6, 16, 4),
                padding: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(
                  color: UiColors.white,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: const <BoxShadow>[
                    BoxShadow(color: Color(0x1A1E5096), blurRadius: 18, offset: Offset(0, 4)),
                  ],
                ),
                child: Row(
                  children: <Widget>[
                    const Icon(Icons.search, size: 20, color: UiColors.inkFaint),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextField(
                        controller: _search,
                        onChanged: (String _) => setState(() {}),
                        style: const TextStyle(fontSize: 15, color: UiColors.ink),
                        decoration: InputDecoration(
                          border: InputBorder.none,
                          hintText: s.t('search'),
                          hintStyle: const TextStyle(color: UiColors.inkFaint),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: FutureBuilder<List<UiConversation>>(
                  future: _future,
                  builder: (BuildContext c, AsyncSnapshot<List<UiConversation>> snap) {
                    final String q = _search.text.trim().toLowerCase();
                    final List<UiConversation> all = (snap.data ?? const <UiConversation>[])
                        .where((UiConversation x) =>
                            q.isEmpty || x.title.toLowerCase().contains(q) || x.snippet.toLowerCase().contains(q))
                        .toList();
                    if (snap.connectionState != ConnectionState.done && all.isEmpty) {
                      return const SizedBox.shrink();
                    }
                    if (all.isEmpty) {
                      return Center(
                        child: Text(s.t('empty'), style: const TextStyle(color: UiColors.inkSoft)),
                      );
                    }
                    final DateTime now = DateTime.now();
                    final DateTime today = DateTime(now.year, now.month, now.day);
                    final Map<String, List<UiConversation>> groups = <String, List<UiConversation>>{
                      'today': <UiConversation>[],
                      'yesterday': <UiConversation>[],
                      'week': <UiConversation>[],
                      'older': <UiConversation>[],
                    };
                    final Map<String, int> diffs = <String, int>{};
                    for (final UiConversation x in all) {
                      final DateTime d = DateTime(x.time.year, x.time.month, x.time.day);
                      final int diff = today.difference(d).inDays;
                      diffs[x.id] = diff;
                      final String key =
                          diff <= 0 ? 'today' : (diff == 1 ? 'yesterday' : (diff <= 7 ? 'week' : 'older'));
                      groups[key]!.add(x);
                    }
                    final List<Widget> children = <Widget>[];
                    int n = 0;
                    groups.forEach((String key, List<UiConversation> items) {
                      if (items.isEmpty) return;
                      children.add(Padding(
                        padding: const EdgeInsets.fromLTRB(4, 14, 4, 4),
                        child: Text(
                          s.t(key),
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: UiColors.inkSoft,
                          ),
                        ),
                      ));
                      for (final UiConversation x in items) {
                        final bool current = n == 0;
                        final Duration delay = Duration(milliseconds: 60 * n);
                        n++;
                        children.add(Padding(
                          padding: const EdgeInsets.only(bottom: 6),
                          child: PopIn(
                            delay: delay,
                            child: GestureDetector(
                              onTap: () => Navigator.of(context).push(
                                MaterialPageRoute<void>(
                                  builder: (BuildContext _) => ChatScreen(conversationId: x.id),
                                ),
                              ),
                              child: Container(
                                constraints: const BoxConstraints(minHeight: 64),
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                                decoration: BoxDecoration(
                                  color: current ? const Color(0xFFF1EAFE) : UiColors.white,
                                  borderRadius: BorderRadius.circular(18),
                                  border: Border.all(
                                    color: current ? const Color(0xB38B5CF6) : Colors.transparent,
                                  ),
                                  boxShadow: UiColors.cardShadow,
                                ),
                                child: Row(
                                  children: <Widget>[
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: <Widget>[
                                          Text(
                                            x.title,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                                          ),
                                          Text(
                                            x.snippet,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: const TextStyle(
                                              fontSize: 13,
                                              height: 1.6,
                                              color: UiColors.inkSoft,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Text(
                                      _timeLabel(s, x.time, diffs[x.id] ?? 0),
                                      style: const TextStyle(fontSize: 12, color: UiColors.inkSoft),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ));
                      }
                    });
                    return ListView(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 28),
                      children: children,
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
