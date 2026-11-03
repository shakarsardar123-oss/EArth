import 'package:flutter/foundation.dart';

/// What the assistant is doing right now (shown instead of a plain "working...").
final ValueNotifier<String> assistantStatus = ValueNotifier<String>('');

/// Web pages the last answer was based on (filled when Google Search was used).
final ValueNotifier<List<String>> assistantSources = ValueNotifier<List<String>>(<String>[]);
