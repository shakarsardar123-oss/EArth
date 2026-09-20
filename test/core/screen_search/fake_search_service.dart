/// Hand-written fake [ScreenSearchService] for Step 10 tests.
library;

import 'dart:async';

import 'package:aura_assistant/core/errors/result.dart';
import 'package:aura_assistant/core/errors/failures.dart';
import 'package:aura_assistant/core/screen_understanding/screen_understanding_result.dart';
import 'package:aura_assistant/core/screen_search/search_result.dart';
import 'package:aura_assistant/core/screen_search/search_state.dart';
import 'package:aura_assistant/core/screen_search/search_service.dart';

/// Configuration for [FakeScreenSearchService].
class FakeSearchConfig {
  /// If non-null, [search] returns this failure instead of results.
  final ScreenSearchFailure? failure;

  /// If non-null, [search] returns these results on success.
  final SearchResults? results;

  /// If true, [search] throws an unexpected exception.
  final bool shouldThrow;

  /// Delay before completing the search (simulates async work).
  final Duration delay;

  /// If true, the service will report [ScreenSearchStatus.cancelled]
  /// after [cancel] is called.
  final bool supportCancellation;

  const FakeSearchConfig({
    this.failure,
    this.results,
    this.shouldThrow = false,
    this.delay = Duration.zero,
    this.supportCancellation = true,
  });
}

/// A fake [ScreenSearchService] with configurable behaviour.
///
/// - Call [configure] before each test to set up expected outcomes.
/// - Tracks call counts for assertions.
class FakeScreenSearchService implements ScreenSearchService {
  FakeSearchConfig _config = const FakeSearchConfig();
  ScreenSearchState _state = const ScreenSearchState();
  final _stateController = StreamController<ScreenSearchState>.broadcast();
  bool _cancelled = false;

  /// Call counts for verification.
  int searchCallCount = 0;
  int cancelCallCount = 0;
  int disposeCallCount = 0;

  /// Last query and representation passed to [search].
  SearchQuery? lastQuery;
  ScreenRepresentation? lastRepresentation;

  /// Configure the fake's behaviour.
  void configure(FakeSearchConfig config) {
    _config = config;
  }

  @override
  ScreenSearchState get state => _state;

  @override
  Stream<ScreenSearchState> get stateStream => _stateController.stream;

  @override
  Future<Result<SearchResults, ScreenSearchFailure>> search(
    SearchQuery query,
    ScreenRepresentation representation,
  ) async {
    searchCallCount++;
    lastQuery = query;
    lastRepresentation = representation;
    _cancelled = false;

    // Transition to searching.
    _setState(const ScreenSearchState(status: ScreenSearchStatus.searching));

    if (_config.delay > Duration.zero) {
      await Future.delayed(_config.delay);
    }

    // If cancelled during delay, return cancellation failure.
    if (_cancelled && _config.supportCancellation) {
      _setState(const ScreenSearchState(
        status: ScreenSearchStatus.cancelled,
      ));
      return Result.failure(ScreenSearchFailure(
        message: 'Search was cancelled',
        phase: ScreenSearchPhase.cancelled,
      ));
    }

    if (_config.shouldThrow) {
      throw Exception('Unexpected error in fake search');
    }

    if (_config.failure != null) {
      _setState(ScreenSearchState(
        status: ScreenSearchStatus.error,
        errorMessage: _config.failure!.message,
      ));
      return Result.failure(_config.failure!);
    }

    final results = _config.results ?? SearchResults(
      query: query,
      results: const [],
    );

    final hasResults = results.hasResults;
    _setState(ScreenSearchState(
      status: hasResults
          ? ScreenSearchStatus.success
          : ScreenSearchStatus.noResults,
      results: results,
      searchCount: 1,
    ));

    return Result.success(results);
  }

  @override
  void cancel() {
    cancelCallCount++;
    _cancelled = true;
    _setState(const ScreenSearchState(
      status: ScreenSearchStatus.cancelled,
    ));
  }

  @override
  Future<void> dispose() async {
    disposeCallCount++;
    await _stateController.close();
  }

  void _setState(ScreenSearchState newState) {
    _state = newState;
    _stateController.add(newState);
  }
}
