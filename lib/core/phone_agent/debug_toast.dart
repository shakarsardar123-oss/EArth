/// Debug aid: shows a native Toast (also works while the app is in background).
library;

import 'package:flutter/services.dart';

const MethodChannel _toastChannel =
    MethodChannel('com.texo.texo/system_control');

void debugToast(String message) {
  final m = message.length > 160 ? message.substring(0, 160) : message;
  _toastChannel
      .invokeMethod<dynamic>('agentToast', {'message': m})
      .catchError((_) {});
}
