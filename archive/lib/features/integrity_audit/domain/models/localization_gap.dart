/// localization_gap.dart
/// AURA Assistant – Step 26: Domain model for localization completeness gaps.
///
/// Kurdish Sorani (ku) RTL-first locale is the primary target.
/// FAIL-CLOSED: missing key → treated as gap, English leak → gap.
library;

/// A single localization gap found during QA audit.
///
/// Gaps are classified by type:
/// - [missingKey]: key exists in English but not in Kurdish Sorani
/// - [englishLeak]: Kurdish Sorani value contains English text
/// - [rtlIssue]: value not RTL-compatible
/// - [formatStringMismatch]: interpolation placeholder count differs
class LocalizationGap {
  /// Unique gap identifier.
  final String gapId;

  /// The step where this gap was found.
  final String sourceStep;

  /// Type of the localization gap.
  final LocalizationGapType gapType;

  /// The localization key involved.
  final String key;

  /// The English value (reference).
  final String englishValue;

  /// The Kurdish Sorani value (may be empty if key is missing).
  final String soraniValue;

  /// Description of the gap.
  final String description;

  /// Whether the Sorani text is RTL-compatible.
  final bool rtlCompatible;

  const LocalizationGap({
    required this.gapId,
    required this.sourceStep,
    required this.gapType,
    required this.key,
    required this.englishValue,
    required this.soraniValue,
    required this.description,
    this.rtlCompatible = true,
  });

  /// Factory for missing key gaps.
  factory LocalizationGap.missingKey({
    required String gapId,
    required String sourceStep,
    required String key,
    required String englishValue,
  String? description,
  }) {
    return LocalizationGap(
      gapId: gapId,
      sourceStep: sourceStep,
      gapType: LocalizationGapType.missingKey,
      key: key,
      englishValue: englishValue,
      soraniValue: '',
      description: description ?? 'Key "$key" missing in Kurdish Sorani (ku) locale',
      rtlCompatible: true,
    );
  }

  /// Factory for English leak gaps.
  factory LocalizationGap.englishLeak({
    required String gapId,
    required String sourceStep,
    required String key,
    required String englishValue,
    required String soraniValue,
    String? description,
  }) {
    return LocalizationGap(
      gapId: gapId,
      sourceStep: sourceStep,
      gapType: LocalizationGapType.englishLeak,
      key: key,
      englishValue: englishValue,
      soraniValue: soraniValue,
      description: description ?? 'Kurdish Sorani value for "$key" contains English text',
      rtlCompatible: true,
    );
  }

  /// Factory for RTL compatibility issues.
  factory LocalizationGap.rtlIssue({
    required String gapId,
    required String sourceStep,
    required String key,
    required String englishValue,
    required String soraniValue,
    String? description,
  }) {
    return LocalizationGap(
      gapId: gapId,
      sourceStep: sourceStep,
      gapType: LocalizationGapType.rtlIssue,
      key: key,
      englishValue: englishValue,
      soraniValue: soraniValue,
      description: description ?? 'Kurdish Sorani value for "$key" has RTL compatibility issue',
      rtlCompatible: false,
    );
  }

  /// Factory for format string mismatches.
  factory LocalizationGap.formatMismatch({
    required String gapId,
    required String sourceStep,
    required String key,
    required String englishValue,
    required String soraniValue,
    required String description,
  }) {
    return LocalizationGap(
      gapId: gapId,
      sourceStep: sourceStep,
      gapType: LocalizationGapType.formatStringMismatch,
      key: key,
      englishValue: englishValue,
      soraniValue: soraniValue,
      description: description,
      rtlCompatible: true,
    );
  }

  /// Whether this gap is about a missing key.
  bool get isMissingKey => gapType == LocalizationGapType.missingKey;

  /// Whether this gap has an empty Sorani value.
  bool get hasEmptySorani => soraniValue.isEmpty;

  @override
  String toString() =>
      'LocalizationGap($gapId: $gapType, key=$key, step=$sourceStep)';
}

/// Types of localization gaps.
enum LocalizationGapType {
  /// Key exists in English but missing in Kurdish Sorani.
  missingKey,

  /// Kurdish Sorani value contains English text.
  englishLeak,

  /// Value not RTL-compatible.
  rtlIssue,

  /// Interpolation placeholder count differs between English and Sorani.
  formatStringMismatch,
}
