import 'package:texo/features/security/domain/models/security_failure.dart';

export 'package:texo/features/security/domain/models/security_failure.dart'
    show SensitiveDataCategory;

/// Stub — MemoryQuery domain model
/// Generated during static repair. Class was referenced by tests but absent from lib/.
/// TODO: Restore from Step 17 source if available.
class MemoryQuery {
  final String query;
  final SensitiveDataCategory? categoryFilter;
  final int? maxResults;

  const MemoryQuery({
    required this.query,
    this.categoryFilter,
    this.maxResults,
  });
}
