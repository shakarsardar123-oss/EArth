/// Re-export — SensitiveDataCategory from security_failure.dart
/// Tests importing from this path will get the security domain enum.
/// NOTE: This enum uses values like financialAccount, medicalRecord, unknown
/// Tests expecting financial/credential/health/personal values may need updating.
/// Generated during static repair.
// TODO: Resolve SensitiveDataCategory enum mismatch — see CATEGORY C issue in final report.
export 'package:aura_assistant/features/security/domain/models/security_failure.dart' show SensitiveDataCategory;
