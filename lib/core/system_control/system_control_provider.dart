import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../device/system_control_channel.dart';
import '../device/android_system_control_channel.dart';
import '../device/stub_system_control_channel.dart';

final systemControlChannelProvider = Provider<SystemControlChannel>((ref) {
  if (Platform.isAndroid) {
    return AndroidSystemControlChannel();
  }

  return StubSystemControlChannel(
    platformLabel: Platform.operatingSystem,
  );
});
