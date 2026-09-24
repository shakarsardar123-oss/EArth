/// Step 20 — Tool Registry Barrel Export
///
/// Exports all domain and application services for the tool_registry feature.
///
/// AUDIT FIX — Bug #1:
///   Added missing export for tool_execution_gate (application layer).
///   The application/ tool_execution_gate.dart is used by domain services
///   but was not re-exported here, causing import resolution failures.

export 'tool_registry_service.dart';
export 'tool_confirmation_service.dart';
export '../../application/tool_execution_gate.dart';
