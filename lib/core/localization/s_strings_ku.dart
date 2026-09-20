/// Hand-written localization: Sorani Kurdish (ckb).
library;

import 's_strings.dart';

class SStringsKu extends SStrings {
  // Game Assistance — Widget
  @override
  String get gameAssistanceTitle => 'یارمەتی یاری';
  @override
  String get gameAssistanceModeOff => 'ناچالاک';
  @override
  String get gameAssistanceModeObserve => 'چاودێری';
  @override
  String get gameAssistanceModeAssist => 'یارمەتی';
  @override
  String get gameAssistanceModeTactical => 'تاکتیکی';
  @override
  String get gameAssistanceStatusIdle => 'بێکار';
  @override
  String get gameAssistanceStatusDetecting => 'دۆزینەوەی یاری…';
  @override
  String get gameAssistanceStatusAnalyzing => 'شیکاری شاشە…';
  @override
  String get gameAssistanceStatusSearching => 'گەڕانی ئامانج…';
  @override
  String get gameAssistanceStatusGenerating => 'بەرهەمهێنانی یارمەتی…';
  @override
  String get gameAssistanceStatusError => 'هەڵە ڕوویدا';
  @override
  String get gameAssistanceGameDetected => 'یاری دۆزرایەوە';
  @override
  String get gameAssistanceGameName => 'یاری';
  @override
  String get gameAssistanceGameCategory => 'جۆر';
  @override
  String get gameAssistanceConfidence => 'متمەنە';
  @override
  String get gameAssistanceScreenAnalysis => 'شیکاری شاشە';
  @override
  String get gameAssistanceHealth => 'تەندروستی';
  @override
  String get gameAssistanceAmmo => 'گوللە';
  @override
  String get gameAssistanceEntities => 'هەستیارەکان';
  @override
  String get gameAssistanceControls => 'کۆنتڕۆڵەکان';
  @override
  String get gameAssistanceTargetsFound => 'ئامانجەکان دۆزرایەوە';
  @override
  String get gameAssistanceTargetsLabel => 'ئامانج';
  @override
  String get gameAssistanceSafetyNotice =>
      'AURA تەنها زانیاری شاشە پێشکەش دەکات. هیچ کردارێکی یاریکردنی ئۆتۆماتیکی ئەنجام نادرێت.';

  // Game Assistance — Legacy compat
  @override
  String get gameAssistTitle => 'یارمەتی یاری';
  @override
  String get gameAssistModeOff => 'ناچالاک';
  @override
  String get gameAssistModeObserve => 'چاودێری';
  @override
  String get gameAssistModeAssist => 'یارمەتی';
  @override
  String get gameAssistModeTactical => 'تاکتیکی';
  @override
  String get gameDetected => 'یاری دۆزرایەوە';
  @override
  String get gameNotDetected => 'هیچ یارییەک نەدۆزرایەوە';
  @override
  String get gameDetectionConfidence => 'متمەنە';
  @override
  String get gameAssistSearching => 'گەڕان…';
  @override
  String get gameAssistTargetFound => 'ئامانج دۆزرایەوە';
  @override
  String get gameAssistTargetNotFound => 'ئامانج نەدۆزرایەوە';
  @override
  String get gameAssistWarning => 'ئاگاداری';
  @override
  String get gameAssistSuggestion => 'پێشنیار';
  @override
  String get gameAssistError => 'هەڵە';
  @override
  String get gameAssistIdle => 'بێکار';
  @override
  String get gameAssistProcessing => 'پرۆسێسینگ…';
  @override
  String get gameAssistScreenAnalysis => 'شیکاری شاشە';
  @override
  String get gameAssistTargetDetection => 'دۆزینەوەی ئامانج';
  @override
  String get gameAssistVoiceActive => 'گوێگرتن…';
  @override
  String get gameAssistModeChanged => 'دۆخ گۆڕدرا';
  @override
  String get gameAssistSafetyNotice =>
      'AURA تەنها زانیاری شاشە پێشکەش دەکات. هیچ یاریکردنی ئۆتۆماتیکی نییە.';

  // Device Integration
  @override
  String get deviceIntegrationActionCompleted => 'کردارەکە ئەنجام درا';
  @override
  String get deviceIntegrationActionFailed => 'نەتوانرا ئەو کردارە ئەنجام بدرێت';
  @override
  String get deviceIntegrationPermissionRequired => 'مۆڵەت پێویستە';
  @override
  String get deviceIntegrationTargetNotFound => 'ئەو شتە لەسەر شاشە نەدۆزرایەوە';
  @override
  String get deviceIntegrationActionProhibited => 'ئەو کردارە قەدەغەیە';
  @override
  String get deviceIntegrationCapturingScreen => 'وێنەی شاشە دەگیرێت…';
  @override
  String get deviceIntegrationAnalyzingScreen => 'شیکاری شاشە…';
  @override
  String get deviceIntegrationSearchingTarget => 'گەڕانی ئامانج…';
  @override
  String get deviceIntegrationResolvingTarget => 'دۆزینەوەی ئامانج…';
  @override
  String get deviceIntegrationVerifyingAction => 'پشتڕاستکردنەوەی کردار…';
  @override
  String get deviceIntegrationExecutingAction => 'ئەنجامدانی کردار…';
  @override
  String get deviceIntegrationScreenCaptureFailed => 'وێنەی شاشە نەگیرا';
  @override
  String get deviceIntegrationScreenAnalysisFailed => 'شیکاری شاشە سەرکەوتوو نەبوو';
  @override
  String get deviceIntegrationSearchFailed => 'گەڕانی شاشە سەرکەوتوو نەبوو';
  @override
  String get deviceIntegrationLowConfidence => 'متمەنە زۆر کەمە';
  @override
  String get deviceIntegrationVerificationPassed => 'پشتڕاستکردنەوە سەرکەوتوو بوو';
  @override
  String get deviceIntegrationVerificationFailed => 'پشتڕاستکردنەوە سەرکەوتوو نەبوو';
  @override
  String get deviceIntegrationVerificationSkipped => 'پشتڕاستکردنەوە بەجێهێڵدرا';
  @override
  String get deviceIntegrationInternetRequired => 'پەیوەندی ئینتەرنێت بۆ ئەم کردارە پێویستە';
  @override
  String get deviceIntegrationOfflineAvailable => 'ئەم کردارە بێ ئینتەرنێت کاردەکات';

  // Floating Aura Overlay
  @override
  String get floatingAuraOverlayIdle =>
      'ئۆڤەرلەی چاوەڕوانە';
  @override
  String get floatingAuraOverlayRequestingPermission =>
      'داواکردنی مۆڵەتی ئۆڤەرلەی…';
  @override
  String get floatingAuraOverlayShowing =>
      'پیشاندانی ئۆڤەرلەی…';
  @override
  String get floatingAuraOverlayHiding =>
      'شاردنەوەی ئۆڤەرلەی…';
  @override
  String get floatingAuraOverlayError =>
      'هەڵەی ئۆڤەرلەی';
  @override
  String get floatingAuraPermissionRequired =>
      'مۆڵەتی ئۆڤەرلەی پێویستە';
  @override
  String get floatingAuraOverlayActive =>
      'ئۆڤەرلەی سەرەوە چالاکە';
  @override
  String get floatingAuraOverlayHidden =>
      'ئۆڤەرلەی سەرەوە شاردراوەتەوە';

  // Assistant Integration
  @override
  String get assistantTitle => 'یەکگرتوویی یارمەتیدەر';
  @override
  String get assistantStatusChecking => 'پشکنینی دۆخی یارمەتیدەر…';
  @override
  String get assistantStatusAvailable => 'AURA دەکرێت وەک یارمەتیدەری بنەڕەتی دابنرێت';
  @override
  String get assistantStatusActive => 'AURA یارمەتیدەری بنەڕەتیتە';
  @override
  String get assistantStatusUnsupported => 'ڕۆڵی یارمەتیدەر لەسەر ئەم ئامێرە پشتگیری ناکرێت';
  @override
  String get assistantStatusFailed => 'نەتوانرا دۆخی یارمەتیدەر بپشکنرێت';
  @override
  String get assistantRequestDefault => 'دانان وەک یارمەتیدەری بنەڕەتی';
  @override
  String get assistantRequestingDefault => 'کردنەوەی ڕێکخستنەکانی یارمەتیدەر…';
  @override
  String get assistantRequestCancelled => 'دامەزراندنی یارمەتیدەر هەڵپەshrدرا';
  @override
  String get assistantInvocationProcessing => 'پرۆسێسکردنی داواکاری یارمەتیدەر…';
  @override
  String get assistantInvocationVoice => 'گوێگرتن بۆ فەرمانی دەنگی…';
  @override
  String get assistantInvocationContext => 'پرۆسێسکردنی کۆنتێکست: ';
  @override
  String get assistantInvocationFailed => 'داواکاری یارمەتیدەر سەرکەوتوو نەبوو';
  @override
  String get assistantOpenSettingsFailed => 'نەتوانرا ڕێکخستنەکانی یارمەتیدەر بکرێنەوە';
  @override
  String get assistantPipelineRoutingFailed => 'نەتوانرا داواکاری بۆ پایپلاین بنێردرێت';
  @override
  String get assistantVoiceInvocationFailed => 'داواکاری دەنگی سەرکەوتوو نەبوو';
  @override
  String get assistantRefreshStatus => 'نوێکردنەوەی دۆخ';

  // Step 5: Reaction Banner + Speech Coordination
  @override
  String get reactionBannerLabel => 'کاردانەوەی AURA';
  @override
  String get speakingIndicatorLabel => 'دەنگ دەهێنێت…';

  // General
  @override
  String get ok => 'باشە';
  @override
  String get cancel => 'پاشگەزبوونەوە';
  @override
  String get error => 'هەڵە';

  // Semantic Memory — Kurdish overrides
  @override
  String get memory_pageTitle => 'بەڕێوەبردنی بیرگە';
  @override
  String get memory_addNew => 'زیادکردنی بیرگەی نوێ';
  @override
  String get memory_searchHint => 'گەڕان لە بیرگەکان…';
  @override
  String get memory_filterAll => 'هەمووی';
  @override
  String get memory_errorPrefix => 'هەڵە';
  @override
  String get memory_retry => 'دووبارەکردنەوە';
  @override
  String get memory_noSearchResults => 'هیچ بیرگەیەک لە گەڕانەکەدا نییە';
  @override
  String get memory_emptyMessage => 'هێشتا هیچ بیرگەیەک نییە';
  @override
  String get memory_contentLabel => 'ناوەڕۆک';
  @override
  String get memory_typeLabel => 'جۆر';
  @override
  String get memory_cancel => 'پاشگەزبوونەوە';
  @override
  String get memory_save => 'پاشەکەوتکردن';
  @override
  String get memory_importance => 'گرنگی';
  @override
  String get memory_source => 'سەرچاوە';
  @override
  String get memory_delete => 'سڕینەوە';
  @override
  String get memory_confirmDelete => 'ئەم بیرگەیە بسڕدرێتەوە؟';
  @override
  String get memory_deleteConfirm => 'ئەم کردارە ناتوانرێت بگەڕێنرێتەوە.';
  @override
  String get memory_createdAt => 'دروستکراوە';
  @override
  String get memory_updatedAt => 'نوێکراوەتەوە';
  @override
  String get memory_tag => 'تاگ';
  @override
  String get memory_detailsTitle => 'وردەکاری بیرگە';
  @override
  String get memory_editContent => 'دەستکاری ناوەڕۆک';
  @override
  String get memory_noMemoriesFound => 'هیچ بیرگەیەک نەدۆزرایەوە';
  @override
  String get memory_loading => 'بارکردنی بیرگەکان…';
  @override
  String get memory_recallSuccess => 'بیرگە گەڕایەوە';
  @override
  String get memory_recallFail => 'نەتوانرا بیرگە بگەڕێنرێت';
  @override
  String get memory_storeSuccess => 'بیرگە پاشەکەوتکرا';
  @override
  String get memory_storeFail => 'نەتوانرا بیرگە پاشەکەوت بکرێت';
  @override
  String get memory_typeFact => 'ڕاستی';
  @override
  String get memory_typePreference => 'پەسند';
  @override
  String get memory_typeEvent => 'ڕووداو';
  @override
  String get memory_typeInstruction => 'ڕێنمایی';
}
