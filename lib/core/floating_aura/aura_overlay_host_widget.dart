/// Root widget rendered by the overlay [FlutterView].
///
/// Phase 6-B: Flutter Overlay Hosting Foundation.
///
/// This widget is rendered inside the native [FlutterView] that lives
/// in the overlay's [expandedContentContainer].
///
/// ## Architecture decision: Secondary FlutterEngine
///
/// Phase 6-B uses a **secondary FlutterEngine** with its own Dart entry
/// point ([auraOverlayMain]). This engine runs in a separate Dart isolate
/// with its own [ProviderScope]. The reasons:
///
/// 1. **Render tree isolation**: A [FlutterView] attached to the SAME
///    engine renders the SAME widget tree as the main activity's
///    [FlutterView]. To render DIFFERENT content in the overlay, a
///    separate engine with a separate entry point is required.
/// 2. **Lifecycle independence**: The overlay can survive the main
///    activity being paused/destroyed (Phase 6-F concern).
/// 3. **Proven pattern**: Secondary engine + custom entry point is the
///    standard pattern for floating overlay / always-on-top Flutter UIs.
///
/// ## Communication between isolates
///
/// The overlay isolate communicates with the main isolate via
/// MethodChannel/EventChannel (to be wired in Phase 6-C). For Phase 6-B,
/// no inter-isolate communication is needed — we only prove that the
/// FlutterView hosting infrastructure works.
///
/// ## Phase 6-B scope
/// This widget displays a minimal placeholder confirming that the
/// FlutterView hosting infrastructure is working. It does NOT connect
/// to ReactionEngine, ReactionSelector, ReactionState, VoiceService,
/// VoiceState, SpeakingIndicator, AuraReactionBanner, any reaction
/// renderers, AgentReactionAdapter, or VoiceReactionAdapter. Those
/// are Phase 6-C and later.
///
/// ## Constraints
/// - The overlay FlutterView size is 280×400dp (matches native
///   [expandedContentContainer] dimensions).
/// - There is NO [MediaQuery] from the main activity's widget tree.
/// - There is NO [Navigator] from the main activity.
/// - [Directionality] is set to RTL for Kurdish Sorani.
/// - Background color: 0xFF0B0E14 (dark surface).
/// - NO reaction/voice imports or references.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../theme/app_colors.dart';
import 'floating_aura_constants.dart';

/// Root widget for the overlay FlutterView.
///
/// Renders a dark container with a cyan-accented placeholder message
/// confirming that the Flutter overlay hosting infrastructure is
/// operational. This is the minimum safe foundation — no reaction
/// or voice systems are connected.
class AuraOverlayHostWidget extends ConsumerWidget {
  const AuraOverlayHostWidget({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Directionality(
      // Kurdish Sorani is RTL.
      textDirection: TextDirection.rtl,
      child: Container(
        // Match native expandedContentContainer dimensions (280×400dp)
        // and dark background.
        width: FloatingAuraDefaults.expandedWidth,
        height: FloatingAuraDefaults.expandedHeight,
        color: const Color(0xFF0B0E14),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Cyan accent circle — mirrors the collapsed native icon.
            Container(
              width: 48.0,
              height: 48.0,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.cyan,
              ),
            ),
            const SizedBox(height: 16.0),
            // Status message.
            const Text(
              'AURA Overlay Ready',
              textDirection: TextDirection.ltr,
              style: TextStyle(
                color: AppColors.cyan,
                fontSize: 18.0,
                fontWeight: FontWeight.w600,
                fontFamily: 'Roboto', // Safe fallback — no GoogleFonts.
              ),
            ),
            const SizedBox(height: 8.0),
            // Sub-message.
            const Text(
              'FlutterView hosting active',
              textDirection: TextDirection.ltr,
              style: TextStyle(
                color: Color(0x99FFFFFF), // 60% white
                fontSize: 12.0,
                fontWeight: FontWeight.w400,
                fontFamily: 'Roboto',
              ),
            ),
            const SizedBox(height: 16.0),
            // Dimension confirmation.
            Text(
              '${FloatingAuraDefaults.expandedWidth.toInt()}'
              '×'
              '${FloatingAuraDefaults.expandedHeight.toInt()}dp',
              textDirection: TextDirection.ltr,
              style: const TextStyle(
                color: Color(0x66FFFFFF), // 40% white
                fontSize: 10.0,
                fontWeight: FontWeight.w300,
                fontFamily: 'Roboto',
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Secondary Dart entry point for the overlay FlutterEngine.
///
/// This function is invoked by the native side when creating the
/// secondary [FlutterEngine] for the overlay. It runs in its own
/// Dart isolate with its own [ProviderScope].
///
/// ## @pragma('vm:entry-point')
///
/// Required so that the AOT compiler does not tree-shake this function.
/// The native side references it by name as the entry point for
/// the secondary engine.
///
/// ## Phase 6-B scope
///
/// For now, this only renders the placeholder [AuraOverlayHostWidget].
/// In Phase 6-C, it will be extended to wire up inter-isolate
/// MethodChannel/EventChannel communication with the main isolate.
@pragma('vm:entry-point')
void auraOverlayMain() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(
    const ProviderScope(
      child: AuraOverlayHostWidget(),
    ),
  );
}
