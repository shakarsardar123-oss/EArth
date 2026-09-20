/// segmentation_config.dart
/// AURA Assistant – Step 27: Continuous Listening & Smart Segmentation
///
/// Domain model for segmentation configuration.
/// FAIL-CLOSED: any invalid config → disabled.
library;

import 'package:meta/meta.dart';
import 'listening_session.dart' show SegmentationMode;

/// Immutable segmentation configuration.
@immutable
class SegmentationConfig {
  /// Segmentation mode.
  final SegmentationMode mode;

  /// Silence threshold in milliseconds.
  final int silenceThresholdMs;

  /// Maximum segment duration in milliseconds.
  final int maxSegmentDurationMs;

  /// Minimum segment duration in milliseconds.
  final int minSegmentDurationMs;

  /// Whether VAD (voice activity detection) is enabled.
  final bool vadEnabled;

  /// VAD sensitivity (0.0-1.0).
  final double vadSensitivity;

  /// Whether speaker change detection is enabled.
  final bool speakerChangeEnabled;

  /// STT language code — Kurdish Sorani: 'ckb_IQ'.
  final String sttLanguage;

  /// Locale — Kurdish Sorani RTL first.
  final String locale;

  /// Whether the config is enabled.
  final bool enabled;

  const SegmentationConfig({
    this.mode = SegmentationMode.hybrid,
    this.silenceThresholdMs = 800,
    this.maxSegmentDurationMs = 30000,
    this.minSegmentDurationMs = 200,
    this.vadEnabled = true,
    this.vadSensitivity = 0.5,
    this.speakerChangeEnabled = false,
    this.sttLanguage = 'ckb_IQ',
    this.locale = 'ku',
    this.enabled = true,
  });

  /// FAIL-CLOSED: disabled config.
  factory SegmentationConfig.disabled() =>
      const SegmentationConfig(enabled: false);

  /// Whether the config is usable.
  bool get isUsable =>
      enabled &&
      mode.isUsable &&
      silenceThresholdMs > 0 &&
      maxSegmentDurationMs > minSegmentDurationMs;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SegmentationConfig &&
          mode == other.mode &&
          silenceThresholdMs == other.silenceThresholdMs &&
          maxSegmentDurationMs == other.maxSegmentDurationMs &&
          vadEnabled == other.vadEnabled &&
          enabled == other.enabled;

  @override
  int get hashCode => Object.hash(
        mode,
        silenceThresholdMs,
        maxSegmentDurationMs,
        vadEnabled,
        enabled,
      );

  @override
  String toString() =>
      'SegmentationConfig(mode: $mode, enabled: $enabled, '
      'silence: ${silenceThresholdMs}ms, max: ${maxSegmentDurationMs}ms)';
}
