/// step_24_introspection_repository.dart
/// AURA Assistant – Step 26: Domain repository for introspecting Step 24 (Trigger Integration).
///
/// Provides read-only access to Step 24's interface contracts for
/// cross-adapter compatibility verification.
///
/// FAIL-CLOSED: if Step 24 cannot be introspected → treated as incompatible.
library;

/// Interface method descriptor captured from Step 24.
class Step24MethodDescriptor {
  final String className;
  final String methodName;
  final List<String> parameterTypes;
  final List<String> parameterNames;
  final String returnType;
  final bool isAsync;

  const Step24MethodDescriptor({
    required this.className,
    required this.methodName,
    required this.parameterTypes,
    required this.parameterNames,
    required this.returnType,
    required this.isAsync,
  });
}

/// Interface model descriptor captured from Step 24.
class Step24ModelDescriptor {
  final String className;
  final List<String> fieldNames;
  final List<String> fieldTypes;
  final List<String> factoryNames;

  const Step24ModelDescriptor({
    required this.className,
    required this.fieldNames,
    required this.fieldTypes,
    required this.factoryNames,
  });
}

/// Trigger interface descriptor captured from Step 24.
class Step24TriggerDescriptor {
  final String triggerId;
  final String triggerType;
  final List<String> eventNames;
  final String handlerClassName;

  const Step24TriggerDescriptor({
    required this.triggerId,
    required this.triggerType,
    required this.eventNames,
    required this.handlerClassName,
  });
}

/// Step 24 introspection result.
class Step24IntrospectionResult {
  final String stepId;
  final List<Step24MethodDescriptor> methods;
  final List<Step24ModelDescriptor> models;
  final List<Step24TriggerDescriptor> triggers;
  final bool isAvailable;

  const Step24IntrospectionResult({
    required this.stepId,
    required this.methods,
    required this.models,
    required this.triggers,
    required this.isAvailable,
  });
}

/// Abstract repository for introspecting Step 24's interfaces.
///
/// Step 24 defines TriggerRepository which Step 25 consumes.
abstract class Step24IntrospectionRepository {
  /// Introspect all repository interfaces from Step 24.
  ///
  /// Returns [Step24IntrospectionResult] with all discovered interfaces.
  /// FAIL-CLOSED: if introspection fails → isAvailable=false.
  Future<Step24IntrospectionResult> introspect({
    required String locale,
  });

  /// Introspect a specific repository method from Step 24.
  ///
  /// FAIL-CLOSED: if not found → null.
  Future<Step24MethodDescriptor?> getMethodDescriptor({
    required String className,
    required String methodName,
  });

  /// Introspect a specific model class from Step 24.
  ///
  /// FAIL-CLOSED: if not found → null.
  Future<Step24ModelDescriptor?> getModelDescriptor({
    required String className,
  });

  /// Introspect all trigger descriptors from Step 24.
  ///
  /// FAIL-CLOSED: if unavailable → empty list.
  Future<List<Step24TriggerDescriptor>> getTriggerDescriptors();

  /// Check if Step 24 introspection data is available.
  ///
  /// FAIL-CLOSED: unavailable → false.
  Future<bool> isAvailable();
}
