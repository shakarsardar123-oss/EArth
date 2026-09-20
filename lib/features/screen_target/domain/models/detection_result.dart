/// detection_result.dart
/// AURA Assistant – Step 27: Universal Screen Target Detection & Correction
///
/// Domain model for the result of a screen detection scan.
/// FAIL-CLOSED: unknown → empty, error → empty.
library;

import 'package:meta/meta.dart';
import 'screen_target.dart';

/// Status of a detection scan.
enum DetectionStatus {
  completed,
  partial,
  failed,
  denied,
  deniedPermission,
  unavailable,
  unknown,
  ;

  static DetectionStatus fromName(String name) =>
      DetectionStatus.values.firstWhere(
        (e) => e.name == name,
        orElse: () => DetectionStatus.unknown,
      );

  bool get isUsable => this == completed || this == partial;
  bool get isBlocking =>
      this == failed ||
      this == denied ||
      this == deniedPermission ||
      this == unavailable ||
      this == unknown;
}

/// Immutable detection result.
@immutable
class DetectionResult {
  /// Unique result identifier.
  final String resultId;

  /// Screen identifier that was scanned.
  final String screenId;

  /// Detection status.
  final DetectionStatus status;

  /// Detected targets.
  final List<ScreenTarget> targets;

  /// Scan duration in milliseconds.
  final int scanDurationMs;

  /// Timestamp of the scan.
  final DateTime scannedAt;

  /// Locale — Kurdish Sorani RTL first.
  final String locale;

  /// Number of verified targets.
  int get verifiedCount => targets.where((t) => t.verified).length;

  /// Number of actionable targets.
  int get actionableCount => targets.where((t) => t.isActionable).length;

  const DetectionResult({
    required this.resultId,
    required this.screenId,
    this.status = DetectionStatus.unknown,
    this.targets = const [],
    this.scanDurationMs = 0,
    required this.scannedAt,
    this.locale = 'ku',
  });

  /// FAIL-CLOSED: empty result for denied/failed scans.
  factory DetectionResult.denied({
    required String resultId,
    required String screenId,
  }) =>
      DetectionResult(
        resultId: resultId,
        screenId: screenId,
        status: DetectionStatus.denied,
        targets: [],
        scannedAt: DateTime.now(),
      );

  /// FAIL-CLOSED: unknown state → empty.
  factory DetectionResult.unknown({
    required String resultId,
    required String screenId,
  }) =>
      DetectionResult(
        resultId: resultId,
        screenId: screenId,
        status: DetectionStatus.unknown,
        targets: [],
        scannedAt: DateTime.now(),
      );

  bool get isUsable => status.isUsable && targets.isNotEmpty;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DetectionResult && resultId == other.resultId;

  @override
  int get hashCode => resultId.hashCode;

  @override
  String toString() =>
      'DetectionResult(id: $resultId, status: $status, '
      'targets: ${targets.length}, verified: $verifiedCount)';
}
