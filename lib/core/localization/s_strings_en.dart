/// Hand-written localization: English (explicit).
/// Inherit from [S] – same values, explicit identity.
library;

import 's_strings.dart';

class SStringsEn extends SStrings {
  // Assistant Integration – explicit English overrides
  @override
  String get assistantTitle => 'Assistant Integration';
  @override
  String get assistantStatusChecking => 'Checking assistant status…';
  @override
  String get assistantStatusAvailable => 'AURA can be set as default assistant';
  @override
  String get assistantStatusActive => 'AURA is your default assistant';
  @override
  String get assistantStatusUnsupported => 'Assistant role not supported on this device';
  @override
  String get assistantStatusFailed => 'Could not check assistant status';
  @override
  String get assistantRequestDefault => 'Set as default assistant';
  @override
  String get assistantRequestingDefault => 'Opening assistant settings…';
  @override
  String get assistantRequestCancelled => 'Assistant setup was cancelled';
  @override
  String get assistantInvocationProcessing => 'Processing assistant invocation…';
  @override
  String get assistantInvocationVoice => 'Listening for voice command…';
  @override
  String get assistantInvocationContext => 'Processing context: ';
  @override
  String get assistantInvocationFailed => 'Assistant invocation failed';
  @override
  String get assistantOpenSettingsFailed => 'Could not open assistant settings';
  @override
  String get assistantPipelineRoutingFailed => 'Could not route invocation to pipeline';
  @override
  String get assistantVoiceInvocationFailed => 'Voice invocation failed';
  @override
  String get assistantRefreshStatus => 'Refresh status';

  // Step 5: Reaction Banner + Speech Coordination
  @override
  String get reactionBannerLabel => 'AURA Reaction';
  @override
  String get speakingIndicatorLabel => 'Speaking…';
}
