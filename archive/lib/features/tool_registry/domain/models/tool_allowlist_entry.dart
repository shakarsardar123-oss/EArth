/// tool_allowlist_entry.dart
/// AURA Assistant – Step 20: Tool Registry & Allowlist
///
/// Represents a single entry in the tool allowlist. A tool is allowed
/// to execute ONLY if it has an explicit [ToolAllowlistEntry] with
/// [isAllowed] == true. Absence from the allowlist = FAIL CLOSED = denied.
///
/// This is the core of the allowlist mechanism: tools are denied by
/// default, and must be explicitly allowed by user or admin action.
library;

import 'package:flutter/foundation.dart';

/// Who added the allowlist entry.
enum AllowlistSource {
  /// User explicitly allowed this tool.
  user,

  /// Administrator / system policy allowed this tool.
  admin,

  /// Automatically allowed during initial setup (pre-approved tools only).
  autoApproved,

  /// Source could not be determined. FAIL CLOSED → treat as untrusted.
  unknown,
}

/// A single entry in the tool allowlist.
///
/// An entry with [isAllowed] == true means the tool is permitted to
/// pass the allowlist gate. An entry with [isAllowed] == false is an
/// explicit denial (blocklist). The ABSENCE of an entry for a tool is
/// treated as denial — FAIL CLOSED.
///
/// @immutable.
@immutable
class ToolAllowlistEntry {
  /// The tool this entry refers to.
  final String toolId;

  /// Whether this tool is allowed. false = explicit denial (blocklist).
  final bool isAllowed;

  /// When this entry was created (UTC ISO 8601).
  final String addedAt;

  /// Who created this entry.
  final AllowlistSource addedBy;

  /// Human-readable reason for the allow/deny decision.
  final String reason;

  const ToolAllowlistEntry({
    required this.toolId,
    this.isAllowed = false, // FAIL CLOSED: default = denied
    this.addedAt = '',
    this.addedBy = AllowlistSource.unknown,
    this.reason = '',
  });

  /// Whether this entry represents an explicit denial (blocklist).
  bool get isDenied => !isAllowed;

  /// Whether the source is trusted. FAIL CLOSED: unknown → untrusted.
  bool get isTrustedSource => addedBy != AllowlistSource.unknown;

  ToolAllowlistEntry copyWith({
    String? toolId,
    bool? isAllowed,
    String? addedAt,
    AllowlistSource? addedBy,
    String? reason,
  }) {
    return ToolAllowlistEntry(
      toolId: toolId ?? this.toolId,
      isAllowed: isAllowed ?? this.isAllowed,
      addedAt: addedAt ?? this.addedAt,
      addedBy: addedBy ?? this.addedBy,
      reason: reason ?? this.reason,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ToolAllowlistEntry &&
          runtimeType == other.runtimeType &&
          toolId == other.toolId;

  @override
  int get hashCode => toolId.hashCode;

  @override
  String toString() =>
      'ToolAllowlistEntry(toolId: $toolId, isAllowed: $isAllowed, '
      'addedBy: $addedBy, reason: $reason)';
}
