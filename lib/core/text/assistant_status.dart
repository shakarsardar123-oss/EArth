import 'package:flutter/foundation.dart';

/// What the assistant is doing right now (shown instead of a plain "working...").
final ValueNotifier<String> assistantStatus = ValueNotifier<String>('');
