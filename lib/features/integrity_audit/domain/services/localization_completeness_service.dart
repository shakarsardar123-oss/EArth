/// localization_completeness_service.dart
/// AURA Assistant – Step 26: Domain service for localization completeness QA.
///
/// Verifies Kurdish Sorani (ku) RTL-first locale completeness across
/// Steps 22–25.
///
/// FAIL-CLOSED: missing key → gap, English leak → gap, RTL issue → gap.
library;

import '../models/localization_gap.dart';

/// Abstract interface for localization completeness checking.
///
/// Implementations compare English keys against Kurdish Sorani keys,
/// check for English text leakage into Sorani values, verify RTL
/// compatibility, and check format string placeholder counts.
abstract class LocalizationCompletenessService {
  /// Check localization completeness for a specific step.
  ///
  /// Returns [LocalizationGap]s for any issues found.
  /// FAIL-CLOSED: missing key → gap recorded.
  Future<List<LocalizationGap>> checkStep({
    required String step,
    required String locale,
  });

  /// Check localization completeness across all Steps 22–25.
  ///
  /// Returns [LocalizationGap]s for any issues found.
  Future<List<LocalizationGap>> checkAllSteps({
    required String locale,
  });

  /// Get the localization coverage percentage for a step (0.0 to 100.0).
  ///
  /// FAIL-CLOSED: any gap → coverage < 100.0.
  Future<double> coveragePercentage({
    required String step,
    required String locale,
  });

  /// Check for English text leakage in Kurdish Sorani values.
  ///
  /// Returns [LocalizationGap]s with [LocalizationGapType.englishLeak].
  Future<List<LocalizationGap>> checkEnglishLeakage({
    required String step,
    required String locale,
  });

  /// Check RTL compatibility of Kurdish Sorani values.
  ///
  /// Returns [LocalizationGap]s with [LocalizationGapType.rtlIssue].
  Future<List<LocalizationGap>> checkRtlCompatibility({
    required String step,
    required String locale,
  });

  /// Check format string placeholder consistency between English and Sorani.
  ///
  /// Returns [LocalizationGap]s with [LocalizationGapType.formatStringMismatch].
  Future<List<LocalizationGap>> checkFormatStrings({
    required String step,
    required String locale,
  });
}
