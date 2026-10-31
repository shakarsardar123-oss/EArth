/// step_22_introspection_repository.dart
/// AURA Assistant – Step 26: Domain repository for introspecting Step 22 (Tool Execution).
///
/// Provides read-only access to Step 22's interface contracts for
/// cross-adapter compatibility verification.
///
/// FAIL-CLOSED: if Step 22 cannot be introspected → treated as incompatible.
library;

/// Interface method descriptor captured from Step 22.
class Step22MethodDescriptor {
  final String className;
  final String methodName;
  final List<String> parameterTypes;
  final List<String> parameterNames;
  final String returnType;
  final bool isAsync;

  const Step22MethodDescriptor({
    required this.className,
    required this.methodName,
    required this.parameterTypes,
    required this.parameterNames,
    required this.returnType,
    required this.isAsync,
  });
}

/// Interface model descriptor captured from Step 22.
class Step22ModelDescriptor {
  final String className;
  final List<String> fieldNames;
  final List<String> fieldTypes;
  final List<String> factoryNames;

  const Step22ModelDescriptor({
    required this.className,
    required this.fieldNames,
    required this.fieldTypes,
    required this.factoryNames,
  });
}

/// Step 22 introspection result.
class Step22IntrospectionResult {
  final String stepId;
  final List<Step22MethodDescriptor> methods;
  final List<Step22ModelDescriptor> models;
  final bool isAvailable;

  const Step22IntrospectionResult({
    required this.stepId,
    required this.methods,
    required this.models,
    required this.isAvailable,
  });
}

/// Abstract repository for introspecting Step 22's interfaces.
///
/// Used by the integrity audit to compare Step 22 contracts against
/// downstream adapters (Step 25) and verify compatibility.
abstract class Step22IntrospectionRepository {
  /// Introspect all repository interfaces from Step 22.
  ///
  /// Returns [Step22IntrospectionResult] with all discovered interfaces.
  /// FAIL-CLOSED: if introspection fails → isAvailable=false.
  Future<Step22IntrospectionResult> introspect({
    required String locale,
  });

  /// Introspect a specific repository interface from Step 22.
  ///
  /// FAIL-CLOSED: if not found → empty methods + isAvailable=false.
  Future<Step22MethodDescriptor?> getMethodDescriptor({
    required String className,
    required String methodName,
  });

  /// Introspect a specific model class from Step 22.
  ///
  /// FAIL-CLOSED: if not found → null.
  Future<Step22ModelDescriptor?> getModelDescriptor({
    required String className,
  });

  /// Check if Step 22 introspection data is available.
  ///
  /// FAIL-CLOSED: unavailable → false.
  Future<bool> isAvailable();
}
