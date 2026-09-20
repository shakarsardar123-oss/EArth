/// Data arriving from an Android assistant invocation.
///
/// When Android launches AURA as the default assistant (ACTION_ASSIST),
/// the system passes supplemental data via the incoming Intent.
/// This entity captures that data in a structured, immutable form.
library;

import 'assistant_status.dart';

/// How the assistant was triggered.
enum InvocationTrigger {
  /// Home-button long-press or gesture.
  homeButton,

  /// Dedicated assistant key on some devices.
  assistantKey,

  /// Voice trigger (e.g. "Hey Google" replaced by AURA).
  voiceTrigger,

  /// Third-party app invoked ACTION_ASSIST.
  externalApp,

  /// Unknown / fallback.
  unknown,
}

/// Immutable payload from an Android assistant invocation.
class AssistantInvocation {
  /// How the assistant was triggered (best-effort detection).
  final InvocationTrigger trigger;

  /// Text snippet from the Intent's EXTRA_ASSIST_CONTEXT, if provided.
  final String? assistContext;

  /// URI from the Intent's EXTRA_ASSIST_URI, if provided.
  final String? assistUri;

  /// Package name of the calling app, if available.
  final String? callingPackage;

  /// Timestamp of the invocation event.
  final DateTime invokedAt;

  /// The assistant status at the time of invocation.
  final AssistantStatus statusAtInvocation;

  const AssistantInvocation({
    this.trigger = InvocationTrigger.unknown,
    this.assistContext,
    this.assistUri,
    this.callingPackage,
    required this.invokedAt,
    required this.statusAtInvocation,
  });

  /// Whether the invocation included context text.
  bool get hasContext => assistContext != null && assistContext!.isNotEmpty;

  /// Whether the invocation included a URI.
  bool get hasUri => assistUri != null && assistUri!.isNotEmpty;

  /// Whether the invocation was triggered by voice.
  bool get isVoiceTriggered => trigger == InvocationTrigger.voiceTrigger;

  AssistantInvocation copyWith({
    InvocationTrigger? trigger,
    String? assistContext,
    bool clearAssistContext = false,
    String? assistUri,
    bool clearAssistUri = false,
    String? callingPackage,
    bool clearCallingPackage = false,
    DateTime? invokedAt,
    AssistantStatus? statusAtInvocation,
  }) {
    return AssistantInvocation(
      trigger: trigger ?? this.trigger,
      assistContext: clearAssistContext
          ? null
          : (assistContext ?? this.assistContext),
      assistUri: clearAssistUri ? null : (assistUri ?? this.assistUri),
      callingPackage: clearCallingPackage
          ? null
          : (callingPackage ?? this.callingPackage),
      invokedAt: invokedAt ?? this.invokedAt,
      statusAtInvocation: statusAtInvocation ?? this.statusAtInvocation,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AssistantInvocation &&
          trigger == other.trigger &&
          assistContext == other.assistContext &&
          assistUri == other.assistUri &&
          callingPackage == other.callingPackage &&
          invokedAt == other.invokedAt;

  @override
  int get hashCode =>
      Object.hash(trigger, assistContext, assistUri, callingPackage, invokedAt);

  @override
  String toString() =>
      'AssistantInvocation(trigger: $trigger, '
      'context: $assistContext, '
      'uri: $assistUri, '
      'from: $callingPackage)';
}
