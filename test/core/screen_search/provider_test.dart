/// Tests for screen-search Riverpod providers — Step 10.
library;

import 'package:aura_assistant/core/errors/failures.dart';
import 'package:aura_assistant/core/screen_search/search_result.dart';
import 'package:aura_assistant/core/screen_search/search_state.dart';
import 'package:aura_assistant/core/screen_search/search_provider.dart';
import 'package:aura_assistant/core/screen_search/search_service.dart';
import 'package:aura_assistant/core/screen_understanding/screen_understanding_result.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fake_search_service.dart';

void main() {
  late ProviderContainer container;
  late FakeScreenSearchService fakeService;

  setUp(() {
    fakeService = FakeScreenSearchService();
    container = ProviderContainer(overrides: [
      screenSearchServiceProvider.overrideWithValue(fakeService),
    ]);
  });

  tearDown(() {
    container.dispose();
  });

  // Helper: build a ScreenRepresentation for testing.
  ScreenRepresentation makeRepresentation() {
    return ScreenRepresentation(
      metadata: ScreenMetadata(
        timestamp: 1700000000000,
        width: 1080,
        height: 1920,
      ),
    );
  }

  // ----------------------------------------------------------------
  // screenSearchServiceProvider
  // ----------------------------------------------------------------
  group('screenSearchServiceProvider', () {
    test('can be overridden with a fake', () {
      final service = container.read(screenSearchServiceProvider);
      expect(service, same(fakeService));
    });

    test('provides a ScreenSearchService', () {
      final service = container.read(screenSearchServiceProvider);
      expect(service, isA<ScreenSearchService>());
    });
  });

  // ----------------------------------------------------------------
  // screenSearchStateProvider
  // ----------------------------------------------------------------
  group('screenSearchStateProvider', () {
    test('initial state is idle', () {
      final state = container.read(screenSearchStateProvider);
      expect(state.status, ScreenSearchStatus.idle);
      expect(state.results, isNull);
      expect(state.searchCount, 0);
    });

    test('notifier exposes service reference', () {
      final notifier = container.read(
        screenSearchStateProvider.notifier,
      );
      expect(notifier.service, same(fakeService));
    });

    test('search updates state on success', () async {
      const query = SearchQuery(
        targetType: SearchTargetType.text,
        query: 'Login',
      );
      final rep = makeRepresentation();

      final textItem = ScreenTextItem(
        text: 'Login',
        boundingBox: const TextBoundingBox(
          x: 0.0, y: 0.0, width: 0.2, height: 0.03,
        ),
        confidence: 0.95,
      );

      final searchResults = SearchResults(
        query: query,
        results: [
          SearchResult(
            targetType: SearchTargetType.text,
            boundingBox: textItem.boundingBox,
            confidence: 0.95,
            matchReason: MatchReason.textMatch,
            rank: 1,
            matchedText: textItem,
          ),
        ],
      );

      fakeService.configure(FakeSearchConfig(results: searchResults));

      final notifier = container.read(
        screenSearchStateProvider.notifier,
      );
      await notifier.search(query, rep);

      final state = container.read(screenSearchStateProvider);
      expect(state.status, ScreenSearchStatus.success);
      expect(state.results, isNotNull);
      expect(state.results!.count, 1);
    });

    test('search updates state on failure', () async {
      const query = SearchQuery(
        targetType: SearchTargetType.text,
        query: 'Login',
      );
      final rep = makeRepresentation();

      fakeService.configure(FakeSearchConfig(
        failure: ScreenSearchFailure(
          message: 'Parse error',
          phase: ScreenSearchPhase.queryParsing,
        ),
      ));

      final notifier = container.read(
        screenSearchStateProvider.notifier,
      );
      await notifier.search(query, rep);

      final state = container.read(screenSearchStateProvider);
      expect(state.status, ScreenSearchStatus.error);
      expect(state.errorMessage, 'Parse error');
    });

    test('cancel updates state to cancelled', () {
      final notifier = container.read(
        screenSearchStateProvider.notifier,
      );
      notifier.cancel();

      final state = container.read(screenSearchStateProvider);
      expect(state.status, ScreenSearchStatus.cancelled);
    });

    test('cancel is forwarded to service', () {
      final notifier = container.read(
        screenSearchStateProvider.notifier,
      );
      notifier.cancel();

      expect(fakeService.cancelCallCount, 1);
    });

    test('search is forwarded to service with correct args', () async {
      const query = SearchQuery(
        targetType: SearchTargetType.text,
        query: 'Button',
      );
      final rep = makeRepresentation();

      fakeService.configure(const FakeSearchConfig());

      final notifier = container.read(
        screenSearchStateProvider.notifier,
      );
      await notifier.search(query, rep);

      expect(fakeService.searchCallCount, 1);
      expect(fakeService.lastQuery, query);
      expect(fakeService.lastRepresentation, rep);
    });
  });
}
