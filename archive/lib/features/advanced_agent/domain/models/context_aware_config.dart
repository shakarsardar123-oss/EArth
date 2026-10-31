/// context_aware_config.dart
/// AURA Assistant – Step 25: Advanced Agent Capabilities
///
/// Configuration for context-aware execution (capability 6).
/// Controls how execution adapts to connectivity, locale, and memory.
library;

/// Execution context mode.
enum ExecutionContextMode {
  /// Full online execution with all features.
  online,

  /// Offline/degraded mode — no network, limited tool access.
  offline,

  /// Hybrid mode — partial connectivity.
  hybrid,
  ;

  /// FAIL-CLOSED: any unknown name maps to [offline].
  static ExecutionContextMode fromName(String name) {
    return ExecutionContextMode.values.firstWhere(
      (e) => e.name == name,
      orElse: () => ExecutionContextMode.offline,
    );
  }
}

/// Configuration governing how the context-aware execution service
/// adapts behavior based on runtime conditions.
class ContextAwareConfig {
  /// Whether memory context should be injected into execution.
  final bool useMemoryContext;

  /// Whether connectivity checks should gate tool execution.
  final bool useConnectivityGate;

  /// Whether locale-specific adaptations should be applied.
  final bool useLocaleAdaptation;

  /// Default execution context mode.
  final ExecutionContextMode defaultMode;

  /// Whether to fall back to degraded mode on error.
  /// FAIL-CLOSED: defaults to true (safe degradation).
  final bool degradeOnError;

  /// Whether to require online connectivity for tool execution.
  final bool requireOnlineForTools;

  /// Maximum number of memory entries to inject as context.
  final int maxMemoryContextEntries;

  /// Default locale for all operations.
  final String locale;

  const ContextAwareConfig({
    this.useMemoryContext = true,
    this.useConnectivityGate = true,
    this.useLocaleAdaptation = true,
    this.defaultMode = ExecutionContextMode.online,
    this.degradeOnError = true,
    this.requireOnlineForTools = true,
    this.maxMemoryContextEntries = 10,
    this.locale = 'ku',
  });

  ContextAwareConfig copyWith({
    bool? useMemoryContext,
    bool? useConnectivityGate,
    bool? useLocaleAdaptation,
    ExecutionContextMode? defaultMode,
    bool? degradeOnError,
    bool? requireOnlineForTools,
    int? maxMemoryContextEntries,
    String? locale,
  }) =>
      ContextAwareConfig(
        useMemoryContext: useMemoryContext ?? this.useMemoryContext,
        useConnectivityGate: useConnectivityGate ?? this.useConnectivityGate,
        useLocaleAdaptation: useLocaleAdaptation ?? this.useLocaleAdaptation,
        defaultMode: defaultMode ?? this.defaultMode,
        degradeOnError: degradeOnError ?? this.degradeOnError,
        requireOnlineForTools: requireOnlineForTools ?? this.requireOnlineForTools,
        maxMemoryContextEntries:
            maxMemoryContextEntries ?? this.maxMemoryContextEntries,
        locale: locale ?? this.locale,
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ContextAwareConfig &&
          useMemoryContext == other.useMemoryContext &&
          useConnectivityGate == other.useConnectivityGate &&
          defaultMode == other.defaultMode &&
          locale == other.locale;

  @override
  int get hashCode =>
      Object.hash(useMemoryContext, useConnectivityGate, defaultMode, locale);

  @override
  String toString() =>
      'ContextAwareConfig(mode: $defaultMode, memory: $useMemoryContext, '
      'connectivity: $useConnectivityGate, locale: $locale)';
}
