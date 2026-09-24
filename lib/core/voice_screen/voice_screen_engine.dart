/// Concrete implementation of [VoiceScreenService] — the
/// full voice→screen pipeline orchestrator for AURA.
///
/// Coordinates VoiceService + ScreenCaptureService +
/// ScreenUnderstandingService + ScreenSearchService +
/// FloatingAuraService into one sequential pipeline with
/// concurrency guard, stale-result protection (generationId),
/// and cancellation support.
library;

import 'dart:async';

import 'package:permission_handler/permission_handler.dart' as ph;

import '../errors/failures.dart';
import '../errors/result.dart';
import '../floating_aura/floating_texo_overlay_position.dart';
import '../floating_aura/floating_aura_service.dart';
import '../permissions/permission_service.dart';
import '../screen_capture/screen_capture_service.dart';
import '../screen_search/search_result.dart';
import '../screen_search/search_service.dart';
import '../screen_understanding/screen_understanding_service.dart';
import '../security/security_policy.dart';
import '../../services/voice/voice_service.dart';
import 'voice_screen_constants.dart';
import 'voice_screen_service.dart';
import 'voice_screen_state.dart';

/// Orchestrates the full voice→screen interaction pipeline.
///
/// Pipeline stages:
/// 1. Concurrency guard (single-active-interaction)
/// 2. Security boundary check
/// 3. Permission check (microphone)
/// 4. Floating overlay show
/// 5. Voice listening start
/// 6. On recognized text → decide
/// 7. Screen capture (single frame)
/// 8. Screen understanding (analyze frame)
/// 9. Screen search (query + representation)
/// 10. Combine context
/// 11. Complete
///
/// Concurrency protection: compare-and-swap on [_active].
/// Stale-result protection: monotonically-increasing [_generationId]
///   checked before each stage transition.
/// Cancellation: [_cancelled] flag checked before each stage.
class VoiceScreenEngine implements VoiceScreenService {
  VoiceScreenEngine({
    required VoiceService voiceService,
    required ScreenCaptureService screenCaptureService,
    required ScreenUnderstandingService screenUnderstandingService,
    required ScreenSearchService screenSearchService,
    required FloatingAuraService floatingAuraService,
    required SecurityPolicy securityPolicy,
    required PermissionService permissionService,
  })  : _voiceService = voiceService,
        _screenCaptureService = screenCaptureService,
        _screenUnderstandingService = screenUnderstandingService,
        _screenSearchService = screenSearchService,
        _floatingAuraService = floatingAuraService,
        _securityPolicy = securityPolicy,
        _permissionService = permissionService;

  // ── Dependencies ────────────────────────────────────────────────

  final VoiceService _voiceService;
  final ScreenCaptureService _screenCaptureService;
  final ScreenUnderstandingService _screenUnderstandingService;
  final ScreenSearchService _screenSearchService;
  final FloatingAuraService _floatingAuraService;
  final SecurityPolicy _securityPolicy;
  final PermissionService _permissionService;

  // ── State ────────────────────────────────────────────────────────

  /// Whether an interaction is currently active (concurrency guard).
  bool _active = false;

  /// Whether the current interaction has been cancelled.
  bool _cancelled = false;

  /// Monotonically increasing generation ID for stale-result protection.
  int _generationId = 0;

  /// Current search query override (from startInteraction).
  VoiceScreenSearchQuery? _pendingQuery;

  /// The current state.
  VoiceScreenState _state = VoiceScreenState.initial;

  /// Broadcast controller for state changes.
  final _stateController =
      StreamController<VoiceScreenState>.broadcast();

  /// Subscription to voice state changes.
  StreamSubscription<VoiceState>? _voiceStateSub;

  // ── VoiceScreenService interface ─────────────────────────────────

  @override
  VoiceScreenState get state => _state;

  @override
  Stream<VoiceScreenState> get stateStream => _stateController.stream;

  @override
  Future<Result<void, VoiceScreenFailure>> startInteraction([
    VoiceScreenSearchQuery? query,
  ]) async {
    // ── Concurrency guard ──────────────────────────────────────────
    if (_active) {
      return const Result.failure(VoiceScreenFailure(
        message: 'An interaction is already active',
        code: 'CONCURRENT_CONFLICT',
        phase: VoiceScreenPhase.concurrentConflict,
      ));
    }
    _active = true;

    // ── New generation ─────────────────────────────────────────────
    _generationId++;
    final gen = _generationId;
    _cancelled = false;
    _pendingQuery = query;

    _setState(VoiceScreenState(
      status: VoiceScreenStatus.listening,
      generationId: gen,
    ));

    // ── Security check ─────────────────────────────────────────────
    final securityViolations = _securityPolicy.checkSecurityBoundaries(
      attemptsPermissionBypass: false,
      attemptsSecurityBypass: false,
      attemptsShellExec: false,
      attemptsArbitraryPackage: false,
      attemptsIntentAbuse: false,
      attemptsAccessibilityAbuse: false,
      attemptsHiddenBackgroundAction: false,
      attemptsSilentSensitiveAction: false,
    );
    if (securityViolations.isNotEmpty) {
      final messages = securityViolations.map((v) => v.message).join('; ');
      await _finishWithError(
        VoiceScreenFailure(
          message: 'Security boundary violation: $messages',
          code: 'SECURITY_VIOLATION',
          phase: VoiceScreenPhase.security,
        ),
        gen,
      );
      return Result.failure(VoiceScreenFailure(
        message: 'Security boundary violation: $messages',
        code: 'SECURITY_VIOLATION',
        phase: VoiceScreenPhase.security,
      ));
    }

    // ── Permission check ──────────────────────────────────────────
    if (_isStaleOrCancelled(gen)) {
      return Result.failure(_cancelledFailure());
    }

    final permissionResult = await _permissionService
        .requestPermission(ph.Permission.microphone);
    if (permissionResult.isFailure) {
      final pf = permissionResult.fold<PermissionFailure>(
        onSuccess: (_) => const PermissionFailure(
          message: 'Unknown permission failure',
        ),
        onFailure: (f) => f,
      );
      await _finishWithError(
        VoiceScreenFailure(
          message: pf.message,
          code: pf.code,
          phase: VoiceScreenPhase.permission,
        ),
        gen,
        status: VoiceScreenStatus.permissionDenied,
      );
      return Result.failure(VoiceScreenFailure(
        message: pf.message,
        code: pf.code,
        phase: VoiceScreenPhase.permission,
      ));
    }

    // ── Floating overlay ──────────────────────────────────────────
    if (_isStaleOrCancelled(gen)) {
      return Result.failure(_cancelledFailure());
    }

    final overlayResult = await _floatingAuraService
        .showOverlay(FloatingAuraOverlayPosition.defaults);
    // Overlay failures propagate but don't corrupt core pipeline state.
    if (overlayResult.isFailure) {
      final of_ = overlayResult.fold<FloatingAuraOverlayFailure>(
        onSuccess: (_) => const FloatingAuraOverlayFailure(
          message: 'Unknown overlay failure',
        ),
        onFailure: (f) => f,
      );
      await _finishWithError(
        VoiceScreenFailure(
          message: of_.message,
          code: of_.code,
          phase: VoiceScreenPhase.overlay,
        ),
        gen,
      );
      return Result.failure(VoiceScreenFailure(
        message: of_.message,
        code: of_.code,
        phase: VoiceScreenPhase.overlay,
      ));
    }

    // ── Start voice listening ──────────────────────────────────────
    if (_isStaleOrCancelled(gen)) {
      return Result.failure(_cancelledFailure());
    }

    _setState(state.copyWith(
      status: VoiceScreenStatus.listening,
      generationId: gen,
    ));

    try {
      await _voiceService.startListening(
        onRecognized: (text) {
          _onRecognizedText(text, gen);
        },
        locale: VoiceScreenDefaults.locale,
      );
    } catch (e) {
      await _finishWithError(
        VoiceScreenFailure(
          message: 'Voice service error: $e',
          code: 'VOICE_ERROR',
          phase: VoiceScreenPhase.voice,
        ),
        gen,
      );
      return Result.failure(VoiceScreenFailure(
        message: 'Voice service error: $e',
        code: 'VOICE_ERROR',
        phase: VoiceScreenPhase.voice,
      ));
    }

    return const Result.success(null);
  }

  @override
  Future<Result<void, VoiceScreenFailure>> processRecognizedText(
    String text,
  ) async {
    if (!_active) {
      return const Result.failure(VoiceScreenFailure(
        message: 'No active interaction to process text for',
        code: 'NO_ACTIVE_INTERACTION',
        phase: VoiceScreenPhase.lifecycle,
      ));
    }
    return _runPipeline(text, _generationId);
  }

  @override
  Future<Result<void, VoiceScreenFailure>> cancelCurrentInteraction() async {
    if (!_active) {
      return const Result.success(null);
    }

    _cancelled = true;

    // Cancel downstream services.
    _screenUnderstandingService.cancel();
    _screenSearchService.cancel();

    // Stop voice if it is listening.
    try {
      await _voiceService.stopListening();
    } catch (_) {
      // Best-effort; don't let stop-listen errors corrupt cancellation.
    }

    // Stop capture if it was started.
    try {
      await _screenCaptureService.stopCapture();
    } catch (_) {
      // Best-effort.
    }

    // Hide overlay.
    try {
      await _floatingAuraService.hideOverlay();
    } catch (_) {
      // Best-effort.
    }

    _setState(state.copyWith(
      status: VoiceScreenStatus.cancelled,
      failure: const VoiceScreenFailure(
        message: 'Interaction cancelled',
        code: 'CANCELLED',
        phase: VoiceScreenPhase.cancelled,
      ),
    ));

    _active = false;
    return const Result.success(null);
  }

  @override
  void dispose() {
    _voiceStateSub?.cancel();
    _voiceStateSub = null;
    _stateController.close();
  }

  // ── Internal pipeline ─────────────────────────────────────────────

  /// Callback from voice service when text is recognized.
  void _onRecognizedText(String text, int gen) {
    if (_isStaleOrCancelled(gen)) return;
    processRecognizedText(text);
  }

  /// Run the capture→understand→search→combine pipeline.
  Future<Result<void, VoiceScreenFailure>> _runPipeline(
    String recognizedText,
    int gen,
  ) async {
    // ── Transcribing ────────────────────────────────────────────────
    if (_isStaleOrCancelled(gen)) {
      return Result.failure(_cancelledFailure());
    }

    _setState(state.copyWith(
      status: VoiceScreenStatus.transcribing,
      recognizedText: recognizedText,
      generationId: gen,
    ));

    // ── Deciding ────────────────────────────────────────────────────
    _setState(state.copyWith(
      status: VoiceScreenStatus.deciding,
      generationId: gen,
    ));

    // ── Screen capture ──────────────────────────────────────────────
    if (_isStaleOrCancelled(gen)) {
      return Result.failure(_cancelledFailure());
    }

    _setState(state.copyWith(
      status: VoiceScreenStatus.capturingScreen,
      generationId: gen,
    ));

    final captureResult =
        await _screenCaptureService.captureSingleFrame();
    if (captureResult.isFailure) {
      final cf = captureResult.fold<ScreenCaptureFailure>(
        onSuccess: (_) => const ScreenCaptureFailure(
          message: 'Unknown capture failure',
        ),
        onFailure: (f) => f,
      );
      await _finishWithError(
        VoiceScreenFailure(
          message: cf.message,
          code: cf.code,
          phase: VoiceScreenPhase.capture,
        ),
        gen,
      );
      return Result.failure(VoiceScreenFailure(
        message: cf.message,
        code: cf.code,
        phase: VoiceScreenPhase.capture,
      ));
    }

    final frame = captureResult.getOrElse(() => throw StateError(
      'captureSingleFrame succeeded but no frame',
    ));

    // ── Screen understanding ────────────────────────────────────────
    if (_isStaleOrCancelled(gen)) {
      return Result.failure(_cancelledFailure());
    }

    _setState(state.copyWith(
      status: VoiceScreenStatus.understandingScreen,
      generationId: gen,
    ));

    final understandingResult =
        await _screenUnderstandingService.analyzeFrame(frame);
    if (understandingResult.isFailure) {
      final uf = understandingResult.fold<ScreenUnderstandingFailure>(
        onSuccess: (_) => const ScreenUnderstandingFailure(
          message: 'Unknown understanding failure',
        ),
        onFailure: (f) => f,
      );
      await _finishWithError(
        VoiceScreenFailure(
          message: uf.message,
          code: uf.code,
          phase: VoiceScreenPhase.understanding,
        ),
        gen,
      );
      return Result.failure(VoiceScreenFailure(
        message: uf.message,
        code: uf.code,
        phase: VoiceScreenPhase.understanding,
      ));
    }

    final representation =
        understandingResult.getOrElse(() => throw StateError(
      'analyzeFrame succeeded but no representation',
    ));

    // ── Screen search ────────────────────────────────────────────────
    if (_isStaleOrCancelled(gen)) {
      return Result.failure(_cancelledFailure());
    }

    _setState(state.copyWith(
      status: VoiceScreenStatus.searchingScreen,
      generationId: gen,
    ));

    final searchQuery = _buildSearchQuery(recognizedText);

    final searchResult = await _screenSearchService.search(
      searchQuery,
      representation,
    );
    if (searchResult.isFailure) {
      final sf = searchResult.fold<ScreenSearchFailure>(
        onSuccess: (_) => const ScreenSearchFailure(
          message: 'Unknown search failure',
        ),
        onFailure: (f) => f,
      );
      await _finishWithError(
        VoiceScreenFailure(
          message: sf.message,
          code: sf.code,
          phase: VoiceScreenPhase.search,
        ),
        gen,
      );
      return Result.failure(VoiceScreenFailure(
        message: sf.message,
        code: sf.code,
        phase: VoiceScreenPhase.search,
      ));
    }

    final results = searchResult.getOrElse(() => throw StateError(
      'search succeeded but no results',
    ));

    // ── Combine context ─────────────────────────────────────────────
    if (_isStaleOrCancelled(gen)) {
      return Result.failure(_cancelledFailure());
    }

    _setState(state.copyWith(
      status: VoiceScreenStatus.combiningContext,
      generationId: gen,
    ));

    final context = VoiceScreenContext(
      recognizedText: recognizedText,
      searchResults: results,
      screenRepresentation: representation,
      capturedFrameTimestamp: frame.timestamp > 0
          ? DateTime.fromMillisecondsSinceEpoch(frame.timestamp)
          : null,
      generationId: gen,
    );

    // ── Complete ────────────────────────────────────────────────────
    await _completeSuccessfully(context, gen);
    return const Result.success(null);
  }

  /// Build a [SearchQuery] from the recognized text and pending query.
  SearchQuery _buildSearchQuery(String recognizedText) {
    final pending = _pendingQuery;

    // Resolve target type: VoiceScreenSearchQuery.targetType (string)
    // → SearchTargetType enum.
    SearchTargetType resolveTargetType(String? typeStr) {
      if (typeStr == null || typeStr.isEmpty) {
        return SearchTargetType.uiElement;
      }
      switch (typeStr.toLowerCase()) {
        case 'text':
          return SearchTargetType.text;
        case 'element':
          return SearchTargetType.uiElement;
        case 'semantic':
          return SearchTargetType.semantic;
        case 'region':
          return SearchTargetType.region;
        default:
          return SearchTargetType.uiElement;
      }
    }

    return SearchQuery(
      targetType: resolveTargetType(pending?.targetType),
      query: pending?.query ?? recognizedText,
      minConfidence: pending?.minConfidence ??
          VoiceScreenDefaults.minConfidence,
      maxResults: pending?.maxResults ??
          VoiceScreenDefaults.maxResults,
    );
  }

  // ── Helpers ──────────────────────────────────────────────────────

  /// Whether the given generation is stale or cancelled.
  bool _isStaleOrCancelled(int gen) {
    return gen != _generationId || _cancelled;
  }

  /// Cancelled failure with standard message.
  VoiceScreenFailure _cancelledFailure() {
    return const VoiceScreenFailure(
      message: 'Interaction was cancelled',
      code: 'CANCELLED',
      phase: VoiceScreenPhase.cancelled,
    );
  }

  /// Transition to completed state with the combined context.
  Future<void> _completeSuccessfully(
    VoiceScreenContext context,
    int gen,
  ) async {
    // Hide overlay on success.
    try {
      await _floatingAuraService.hideOverlay();
    } catch (_) {
      // Best-effort; overlay cleanup should not block completion.
    }

    _setState(state.copyWith(
      status: VoiceScreenStatus.completed,
      context: context,
      generationId: gen,
    ));
    _active = false;
  }

  /// Transition to error state, hide overlay, and release active flag.
  Future<void> _finishWithError(
    VoiceScreenFailure failure,
    int gen, {
    VoiceScreenStatus status = VoiceScreenStatus.error,
  }) async {
    // Hide overlay on error.
    try {
      await _floatingAuraService.hideOverlay();
    } catch (_) {
      // Best-effort.
    }

    _setState(state.copyWith(
      status: status,
      failure: failure,
      generationId: gen,
    ));
    _active = false;
  }

  /// Update state and notify listeners.
  void _setState(VoiceScreenState newState) {
    _state = newState;
    if (!_stateController.isClosed) {
      _stateController.add(newState);
    }
  }
}
