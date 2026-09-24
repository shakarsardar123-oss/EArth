/// stub_screen_action_repository.dart
/// AURA Assistant – Step 27: Screen Target
///
/// FAIL-CLOSED stub: all operations return denied/unverified.
library;

import '../domain/models/screen_target.dart';
import '../domain/repositories/screen_action_repository.dart';

class StubScreenActionRepository implements ScreenActionRepository {
  @override
  bool get hasPermission => false;

  @override
  bool get isAvailable => false;

  @override
  Future<ScreenActionResult> tap(ScreenTarget target) async =>
      ScreenActionResult.deniedUnverified;

  @override
  Future<ScreenActionResult> longPress(ScreenTarget target) async =>
      ScreenActionResult.deniedUnverified;

  @override
  Future<ScreenActionResult> swipe({
    required ScreenTarget target,
    required String direction,
  }) async => ScreenActionResult.deniedUnverified;

  @override
  Future<ScreenActionResult> typeText({
    required ScreenTarget target,
    required String text,
  }) async => ScreenActionResult.deniedUnverified;

  @override
  Future<ScreenActionResult> scroll({
    required ScreenTarget target,
    required String direction,
  }) async => ScreenActionResult.deniedUnverified;
}
