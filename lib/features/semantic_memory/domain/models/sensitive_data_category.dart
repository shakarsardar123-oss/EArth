/// Stub — SensitiveDataCategory for semantic_memory
/// Re-exports from security domain. Tests expecting semantic_memory-specific
/// enum values (financial, credential, health, personal) should be updated
/// to use security domain values (financialAccount, medicalRecord, etc.).
/// Generated during static repair.
// TODO: Resolve SensitiveDataCategory enum mismatch — see CATEGORY C issue in final report.
export 'package:aura_assistant/features/security/domain/models/security_failure.dart' show SensitiveDataCategory;
