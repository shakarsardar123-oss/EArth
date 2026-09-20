/// Hand-written localization: English (base).
/// Use [S] for English, [SEn] for explicit English, [SKu] for Sorani Kurdish.
class SStrings {
  // Game Assistance — Widget
  static const String gameAssistanceTitle = 'Game Assistance';
  static const String gameAssistanceModeOff = 'Off';
  static const String gameAssistanceModeObserve = 'Observe';
  static const String gameAssistanceModeAssist = 'Assist';
  static const String gameAssistanceModeTactical = 'Tactical';
  static const String gameAssistanceStatusIdle = 'Idle';
  static const String gameAssistanceStatusDetecting = 'Detecting game…';
  static const String gameAssistanceStatusAnalyzing = 'Analyzing screen…';
  static const String gameAssistanceStatusSearching = 'Searching targets…';
  static const String gameAssistanceStatusGenerating = 'Generating assistance…';
  static const String gameAssistanceStatusError = 'Error occurred';
  static const String gameAssistanceGameDetected = 'Game detected';
  static const String gameAssistanceGameName = 'Game';
  static const String gameAssistanceGameCategory = 'Category';
  static const String gameAssistanceConfidence = 'Confidence';
  static const String gameAssistanceScreenAnalysis = 'Screen Analysis';
  static const String gameAssistanceHealth = 'Health';
  static const String gameAssistanceAmmo = 'Ammo';
  static const String gameAssistanceEntities = 'Entities';
  static const String gameAssistanceControls = 'Controls';
  static const String gameAssistanceTargetsFound = 'Targets found';
  static const String gameAssistanceTargetsLabel = 'targets';
  static const String gameAssistanceSafetyNotice =
      'AURA provides screen information only. No automatic gameplay actions are performed.';

  // Game Assistance — Legacy compat (used by controller/report)
  static const String gameAssistTitle = 'Game Assistance';
  static const String gameAssistModeOff = 'Off';
  static const String gameAssistModeObserve = 'Observe';
  static const String gameAssistModeAssist = 'Assist';
  static const String gameAssistModeTactical = 'Tactical';
  static const String gameDetected = 'Game detected';
  static const String gameNotDetected = 'No game detected';
  static const String gameDetectionConfidence = 'Confidence';
  static const String gameAssistSearching = 'Searching…';
  static const String gameAssistTargetFound = 'Target found';
  static const String gameAssistTargetNotFound = 'Target not found';
  static const String gameAssistWarning = 'Warning';
  static const String gameAssistSuggestion = 'Suggestion';
  static const String gameAssistError = 'Error';
  static const String gameAssistIdle = 'Idle';
  static const String gameAssistProcessing = 'Processing…';
  static const String gameAssistScreenAnalysis = 'Screen Analysis';
  static const String gameAssistTargetDetection = 'Target Detection';
  static const String gameAssistVoiceActive = 'Listening…';
  static const String gameAssistModeChanged = 'Mode changed';
  static const String gameAssistSafetyNotice =
      'AURA provides screen information only. No automatic gameplay.';

  // Device Integration
  static const String deviceIntegrationActionCompleted =
      'Action completed successfully';
  static const String deviceIntegrationActionFailed =
      'Could not complete the action';
  static const String deviceIntegrationPermissionRequired =
      'Permission required';
  static const String deviceIntegrationTargetNotFound =
      'Target not found on screen';
  static const String deviceIntegrationActionProhibited =
      'That action is prohibited';
  static const String deviceIntegrationCapturingScreen =
      'Capturing screen…';
  static const String deviceIntegrationAnalyzingScreen =
      'Analyzing screen…';
  static const String deviceIntegrationSearchingTarget =
      'Searching for target…';
  static const String deviceIntegrationResolvingTarget =
      'Resolving target…';
  static const String deviceIntegrationVerifyingAction =
      'Verifying action…';
  static const String deviceIntegrationExecutingAction =
      'Executing action…';
  static const String deviceIntegrationScreenCaptureFailed =
      'Screen capture failed';
  static const String deviceIntegrationScreenAnalysisFailed =
      'Screen analysis failed';
  static const String deviceIntegrationSearchFailed =
      'Screen search failed';
  static const String deviceIntegrationLowConfidence =
      'Confidence too low';
  static const String deviceIntegrationVerificationPassed =
      'Verification passed';
  static const String deviceIntegrationVerificationFailed =
      'Verification failed';
  static const String deviceIntegrationVerificationSkipped =
      'Verification skipped';
  static const String deviceIntegrationInternetRequired =
      'Internet connection required for this action';
  static const String deviceIntegrationOfflineAvailable =
      'This action works offline';

  // Floating Aura Overlay
  static const String floatingAuraOverlayIdle =
      'Overlay idle';
  static const String floatingAuraOverlayRequestingPermission =
      'Requesting overlay permission…';
  static const String floatingAuraOverlayShowing =
      'Showing overlay…';
  static const String floatingAuraOverlayHiding =
      'Hiding overlay…';
  static const String floatingAuraOverlayError =
      'Overlay error';
  static const String floatingAuraPermissionRequired =
      'Overlay permission required';
  static const String floatingAuraOverlayActive =
      'Floating overlay is active';
  static const String floatingAuraOverlayHidden =
      'Floating overlay is hidden';

  // Assistant Integration
  static const String assistantTitle = 'Assistant Integration';
  static const String assistantStatusChecking = 'Checking assistant status…';
  static const String assistantStatusAvailable = 'AURA can be set as default assistant';
  static const String assistantStatusActive = 'AURA is your default assistant';
  static const String assistantStatusUnsupported = 'Assistant role not supported on this device';
  static const String assistantStatusFailed = 'Could not check assistant status';
  static const String assistantRequestDefault = 'Set as default assistant';
  static const String assistantRequestingDefault = 'Opening assistant settings…';
  static const String assistantRequestCancelled = 'Assistant setup was cancelled';
  static const String assistantInvocationProcessing = 'Processing assistant invocation…';
  static const String assistantInvocationVoice = 'Listening for voice command…';
  static const String assistantInvocationContext = 'Processing context: ';
  static const String assistantInvocationFailed = 'Assistant invocation failed';
  static const String assistantOpenSettingsFailed = 'Could not open assistant settings';
  static const String assistantPipelineRoutingFailed = 'Could not route invocation to pipeline';
  static const String assistantVoiceInvocationFailed = 'Voice invocation failed';
  static const String assistantRefreshStatus = 'Refresh status';

  // General
  static const String ok = 'OK';
  static const String cancel = 'Cancel';
  static const String error = 'Error';

  // Step 5: Reaction Banner + Speech Coordination
  static const String reactionBannerLabel = 'AURA Reaction';
  static const String speakingIndicatorLabel = 'Speaking…';

  // Semantic Memory keys (added to fix missing localization)
  static const String memory_pageTitle = 'Memory Management';
  static const String memory_addNew = 'Add New Memory';
  static const String memory_searchHint = 'Search memories…';
  static const String memory_filterAll = 'All';
  static const String memory_errorPrefix = 'Error';
  static const String memory_retry = 'Retry';
  static const String memory_noSearchResults = 'No memories match your search';
  static const String memory_emptyMessage = 'No memories stored yet';
  static const String memory_contentLabel = 'Content';
  static const String memory_typeLabel = 'Type';
  static const String memory_cancel = 'Cancel';
  static const String memory_save = 'Save';
  static const String memory_importance = 'Importance';
  static const String memory_source = 'Source';
  static const String memory_delete = 'Delete';
  static const String memory_confirmDelete = 'Forget this memory?';
  static const String memory_deleteConfirm = 'This action cannot be undone.';
  static const String memory_createdAt = 'Created';
  static const String memory_updatedAt = 'Updated';
  static const String memory_tag = 'Tag';
  static const String memory_detailsTitle = 'Memory Details';
  static const String memory_editContent = 'Edit content';
  static const String memory_noMemoriesFound = 'No memories found';
  static const String memory_loading = 'Loading memories…';
  static const String memory_recallSuccess = 'Memory recalled';
  static const String memory_recallFail = 'Could not recall memory';
  static const String memory_storeSuccess = 'Memory stored';
  static const String memory_storeFail = 'Could not store memory';
  static const String memory_typeFact = 'Fact';
  static const String memory_typePreference = 'Preference';
  static const String memory_typeEvent = 'Event';
  static const String memory_typeInstruction = 'Instruction';

  /// Current locale instance — resolves based on AuraLocale selection.
  static SStrings current = SStrings();
}
