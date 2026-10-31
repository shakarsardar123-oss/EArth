/// Step 24 — Trigger Result Value Object
///
/// Lightweight value object for trigger result summaries.
/// FAIL-CLOSED: unknown/errors default to denied.

enum TriggerResultCategory {
  launched,
  denied,
  failed,
  unavailable,
}

class TriggerResultVO {
  final TriggerResultCategory category;
  final String code;
  final String? message;

  const TriggerResultVO({
    required this.category,
    required this.code,
    this.message,
  });

  bool get isLaunched => category == TriggerResultCategory.launched;
  bool get isDenied => category == TriggerResultCategory.denied;
  bool get isFailed => category == TriggerResultCategory.failed;
  bool get isUnavailable => category == TriggerResultCategory.unavailable;

  @override
  String toString() =>
      'TriggerResultVO(category: $category, code: $code, message: $message)';
}
