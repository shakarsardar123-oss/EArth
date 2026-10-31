/// step_25_introspection_repository.dart
/// AURA Assistant – Step 26: Domain repository for introspecting Step 25 (Advanced Agent).
///
/// Provides read-only access to Step 25's interface contracts for
/// cross-adapter compatibility verification.
///
/// FAIL-CLOSED: if Step 25 cannot be introspected → treated as incompatible.
library;

/// Interface method descriptor captured from Step 25.
class Step25MethodDescriptor {
  final String className;
  final String methodName;
  final List<String> parameterTypes;
  final List<String> parameterNames;
  final String returnType;
  final bool isAsync;
  final bool usesPositionalParams;

  const Step25MethodDescriptor({
    required this.className,
    required this.methodName,
    required this.parameterTypes,
    required this.parameterNames,
    required this.returnType,
    required this.isAsync,
    required this.usesPositionalParams,
  });
}

/// Interface model descriptor captured from Step 25.
class Step25ModelDescriptor {
  final String className;
  final List<String> fieldNames;
  final List<String> fieldTypes;
  final List<String> factoryNames;

  const Step25ModelDescriptor({
    required this.className,
    required this.fieldNames,
    required this.fieldTypes,
    required this.factoryNames,
  });
}

/// Step 25 introspection result.
class Step25IntrospectionResult {
  final String stepId;
  final List<Step25MethodDescriptor> methods;
  final List<Step25ModelDescriptor> models;
  final Set<String> uniqueRepositories;
  final bool isAvailable;

  const Step25IntrospectionResult({
    required this.stepId,
    required this.methods,
    required this.models,
    required this.uniqueRepositories,
    required this.isAvailable,
  });
}

/// Abstract repository for introspecting Step 25's interfaces.
///
/// Step 25 uses positional params, has TriggerRepository (from Step 24),
/// and lacks ScreenRepository/VoiceRepository (from Step 23).
abstract class Step25IntrospectionRepository {
  /// Introspect all repository interfaces from Step 25.
  ///
  /// Returns [Step25IntrospectionResult] with all discovered interfaces.
  /// FAIL-CLOSED: if introspection fails → isAvailable=false.
  Future<Step25IntrospectionResult> introspect({
    required String locale,
  });

  /// Introspect a specific repository method from Step 25.
  ///
  /// FAIL-CLOSED: if not found → null.
  Future<Step25MethodDescriptor?> getMethodDescriptor({
    required String className,
    required String methodName,
  });

  /// Introspect a specific model class from Step 25.
  ///
  /// FAIL-CLOSED: if not found → null.
  Future<Step25ModelDescriptor?> getModelDescriptor({
    required String className,
  });

  /// Get the set of unique repository class names from Step 25.
  ///
  /// FAIL-CLOSED: if unavailable → empty set.
  Future<Set<String>> getRepositoryNames();

  /// Check if Step 25 introspection data is available.
  ///
  /// FAIL-CLOSED: unavailable → false.
  Future<bool> isAvailable();
}
