/// In-memory ring buffer for recent reaction history.
///
/// Tracks which reactions have fired recently so the selector
/// can apply anti-repetition penalties. This is **not** persistent
/// storage — the buffer resets when the process restarts.
///
/// The history stores entries as (reactionId, timestamp) pairs
/// and supports queries for:
/// - Whether a reaction has fired within its cooldown window
/// - How many times a reaction has been selected recently
/// - The time since last firing for cooldown calculations
library;

import 'reaction_clock.dart';

/// A single entry in the reaction history buffer.
class ReactionHistoryEntry {
  const ReactionHistoryEntry({
    required this.reactionId,
    required this.timestamp,
  });

  /// The id of the reaction that fired.
  final String reactionId;

  /// When the reaction was selected.
  final DateTime timestamp;

  @override
  bool operator ==(Object other) =>
      other is ReactionHistoryEntry &&
      other.reactionId == reactionId &&
      other.timestamp == timestamp;

  @override
  int get hashCode => Object.hash(reactionId, timestamp);

  @override
  String toString() =>
      'ReactionHistoryEntry($reactionId at $timestamp)';
}

/// Ring buffer of recent reaction firings.
///
/// [maxSize] determines how many entries are retained. Older entries
/// are evicted when the buffer is full. Default is 64, which at
/// ~1 reaction per 10s covers ~10 minutes of history.
class ReactionHistory {
  ReactionHistory({
    this.maxSize = 64,
    required Clock clock,
  })  : _clock = clock,
        _entries = [];

  final int maxSize;
  final Clock _clock;
  final List<ReactionHistoryEntry> _entries;

  /// All entries currently in the buffer (oldest first).
  List<ReactionHistoryEntry> get entries =>
      List.unmodifiable(_entries);

  /// Number of entries in the buffer.
  int get length => _entries.length;

  /// Whether the buffer is empty.
  bool get isEmpty => _entries.isEmpty;

  /// Whether the buffer is full.
  bool get isFull => _entries.length >= maxSize;

  /// Records that a reaction with [reactionId] was just selected.
  void record(String reactionId) {
    if (isFull) {
      _entries.removeAt(0);
    }
    _entries.add(ReactionHistoryEntry(
      reactionId: reactionId,
      timestamp: _clock.now(),
    ));
  }

  /// Whether [reactionId] has been selected within [cooldown].
  bool isInCooldown(String reactionId, Duration cooldown) {
    final cutoff = _clock.now().subtract(cooldown);
    return _entries.any(
      (e) => e.reactionId == reactionId && e.timestamp.isAfter(cutoff),
    );
  }

  /// Time since the last firing of [reactionId].
  /// Returns null if the reaction has never been in the buffer.
  Duration? timeSinceLast(String reactionId) {
    final recent = _entries
        .where((e) => e.reactionId == reactionId)
        .lastOrNull;
    if (recent == null) return null;
    return _clock.now().difference(recent.timestamp);
  }

  /// How many times [reactionId] appears in the current buffer.
  int repeatCount(String reactionId) =>
      _entries.where((e) => e.reactionId == reactionId).length;

  /// Returns the last [n] entries (or fewer if buffer is smaller).
  List<ReactionHistoryEntry> recent({int n = 10}) {
    if (_entries.length <= n) return List.unmodifiable(_entries);
    return List.unmodifiable(_entries.sublist(_entries.length - n));
  }

  /// Clears all history.
  void clear() => _entries.clear();
}
