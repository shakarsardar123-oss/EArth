/// step_23_introspection_repository.dart
/// AURA Assistant – Step 26: Domain repository for introspecting Step 23 (Orchestration).
///
/// Provides read-only access to Step 23's interface contracts for
/// cross-adapter compatibility verification.
///
/// FAIL-CLOSED: if Step 23 cannot be introspected → treated as incompatible.
library;

/// Interface method descriptor captured from Step 23.
class Step23MethodDescriptor {
  final String className;
  final String methodName;
  final List<String> parameterTypes;
  final List<String> parameterNames;
  final String returnType;
  final bool isAsync;
  final bool usesNamedParams;

  const Step23MethodDescriptor({
    required this.className,
    required this.methodName,
    required this.parameterTypes,
    required this.parameterNames,
    required this.returnType,
    required this.isAsync,
    required this.usesNamedParams,
  });
}

/// Interface model descriptor captured from Step 23.
class Step23ModelDescriptor {
  final String className;
  final List<String> fieldNames;
  final List<String> fieldTypes;
  final List<String> factoryNames;

  const Step23ModelDescriptor({
    required this.className,
    required this.fieldNames,
    required this.fieldTypes,
    required this.factoryNames,
  });
}

/// Step 23 introspection result.
class Step23IntrospectionResult {
  final String stepId;
  final List<Step23MethodDescriptor> methods;
  final List<Step23ModelDescriptor> models;
  final Set<String> uniqueRepositories;
  final bool isAvailable;

  const Step23IntrospectionResult({
    required this.stepId,
    required this.methods,
    required this.models,
    required this.uniqueRepositories,
    required this.isAvailable,
  });
}

/// Abstract repository for introspecting Step 23's interfaces.
///
/// Step 23 uses named parameters and has additional repositories
/// (ScreenRepository, VoiceRepository) that Step 25 lacks.
abstract class Step23IntrospectionRepository {
  /// Introspect all repository interfaces from Step 23.
  ///
  /// Returns [Step23IntrospectionResult] with all discovered interfaces.
  /// FAIL-CLOSED: if introspection fails → isAvailable=false.
  Future<Step23IntrospectionResult> introspect({
    required String locale,
  });

  /// Introspect a specific repository method from Step 23.
  ///
  /// FAIL-CLOSED: if not found → null.
  Future<Step23MethodDescriptor?> getMethodDescriptor({
    required String className,
    required String methodName,
  });

  /// Introspect a specific model class from Step 23.
  ///
  /// FAIL-CLOSED: if not found → null.
  Future<Step23ModelDescriptor?> getModelDescriptor({
    required String className,
  });

  /// Get the set of unique repository class names from Step 23.
  ///
  /// FAIL-CLOSED: if unavailable → empty set.
  Future<Set<String>> getRepositoryNames();

  /// Check if Step 23 introspection data is available.
  ///
  /// FAIL-CLOSED: unavailable → false.
  Future<bool> isAvailable();
}
