/// Riverpod providers for the AURA screen-search / target-detection subsystem.
///
/// Exposes:
/// - [screenSearchServiceProvider] — the concrete
///   [ScreenSearchService] instance.
/// - [screenSearchStateProvider] — the current
///   [ScreenSearchState] as a [StateNotifierProvider].
library;

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../errors/result.dart';
import '../errors/failures.dart';
import '../screen_understanding/screen_understanding_result.dart';
import 'search_result.dart';
import 'search_state.dart';
import 'search_service.dart';
import 'search_engine.dart';

/// Provider for the [ScreenSearchService] singleton.
///
/// Default: [SearchEngine]. Override this provider in tests
/// to inject a fake.
final screenSearchServiceProvider = Provider<ScreenSearchService>((ref) {
  return SearchEngine();
});

/// StateNotifier that wraps a [ScreenSearchService] and
/// publishes [ScreenSearchState] changes to Riverpod.
class ScreenSearchStateNotifier
    extends StateNotifier<ScreenSearchState> {
  ScreenSearchStateNotifier(this._service)
      : super(const ScreenSearchState());

  final ScreenSearchService _service;
  StreamSubscription<ScreenSearchState>? _stateSub;

  /// Current service reference (read-only for tests).
  ScreenSearchService get service => _service;

  /// Search the given [representation] for targets matching [query].
  ///
  /// Delegates to the underlying [ScreenSearchService]
  /// and updates state accordingly.
  Future<Result<SearchResults, ScreenSearchFailure>> search(
    SearchQuery query,
    ScreenRepresentation representation,
  ) async {
    final result = await _service.search(query, representation);

    // Sync state from service after search completes.
    state = _service.state;

    return result;
  }

  /// Cancel any in-progress search.
  void cancel() {
    _service.cancel();
    state = _service.state;
  }

  @override
  void dispose() {
    _stateSub?.cancel();
    _service.dispose();
    super.dispose();
  }
}

/// StateNotifierProvider for screen-search state.
///
/// Tests can override this with a controlled notifier.
final screenSearchStateProvider =
    StateNotifierProvider<ScreenSearchStateNotifier,
        ScreenSearchState>((ref) {
  final service = ref.watch(screenSearchServiceProvider);
  return ScreenSearchStateNotifier(service);
});
