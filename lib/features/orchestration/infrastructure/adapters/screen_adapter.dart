/// Step 23 — Screen Adapter
///
/// Adapter implementing ScreenRepository.
///
/// ScreenRepository:
///   executeAction(String action, Map<String, dynamic> parameters)
///     →Future<ScreenActionResult>
///   isAvailable()→Future<bool>
///
/// Returns ScreenActionResult (not bool).
/// Map<String,dynamic> parameters is non-nullable (not Map<String,dynamic>?).
/// NO isScreenAvailable() — renamed to isAvailable().
/// ScreenActionResult factories: success({resultData}), failed({errorMessage}).
///
/// ── CLASSIFICATION: CLASS C (BLOCKED — NO UNIFIED ACTION DISPATCHER) ──
/// AURA ships three real screen subsystems — screen_capture/,
/// screen_understanding/, screen_search/ — but they are READ/OBSERVE
/// oriented (capture a frame, understand it, search within it). None of
/// them exposes a generic `executeAction(action, params)` dispatcher that
/// PERFORMS an arbitrary screen action (tap/scroll/type/gesture), which is
/// what this repository contract requires. On Android that capability
/// would be an AccessibilityService gesture-dispatch layer that does not
/// exist in the codebase yet.
///
/// BLOCKED: wiring requires a real screen-action executor (Step 15
/// gesture/accessibility dispatch). Until it exists this adapter is
/// FAIL-CLOSED: executeAction() returns a failed ScreenActionResult (it
/// never fakes success) and isAvailable() returns false. Both flip to real
/// behaviour once the dispatcher lands and executeAction is wired to it.
/// This adapter creates NO second screen subsystem.
/// ─────────────────────────────────────────────────────────────────────

import '../../domain/orchestration_domain.dart';

class ScreenAdapter implements ScreenRepository {
  /// Create adapter.
  ScreenAdapter();

  @override
  Future<ScreenActionResult> executeAction(
    String action,
    Map<String, dynamic> parameters,
  ) async {
    try {
      // BLOCKED + FAIL-CLOSED: no real screen-action dispatcher exists (see
      // header). The only ScreenActionRepository implementation in the
      // codebase is StubScreenActionRepository, which itself returns
      // deniedUnverified for every action, and android_device_executor
      // documents that Android DeviceChannel has no dispatchGesture
      // capability. Because the action cannot actually be performed, this
      // adapter must FAIL HONESTLY rather than report a fake success — a
      // blocked capability that returns success() would let the
      // orchestrator believe a screen action succeeded when nothing ran.
      return ScreenActionResult.failed(
        errorMessage:
            'Screen action dispatcher unavailable (BLOCKED: no gesture/'
            'accessibility dispatch layer implemented). Action "$action" '
            'was not performed.',
      );
    } catch (e) {
      // FAIL-CLOSED: error → failed result
      return ScreenActionResult.failed(errorMessage: 'Screen action error: $e');
    }
  }

  @override
  Future<bool> isAvailable() async {
    // FAIL-CLOSED: the screen-action dispatcher is not implemented, so the
    // subsystem is genuinely unavailable. Returning false here is the honest
    // signal — a BLOCKED adapter must not advertise availability. This flips
    // to a real capability probe once a gesture/accessibility dispatch layer
    // (Step 15) lands and executeAction is wired to it.
    return false;
  }
}
