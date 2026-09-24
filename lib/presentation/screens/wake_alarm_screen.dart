import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:texo/l10n/app_localizations.dart';

import '../../domain/entities/alarm/wake_alarm.dart';
import '../../domain/entities/alarm/wake_verification_config.dart';
import '../../domain/entities/alarm/wake_verification_state.dart';
import '../../core/theme/app_colors.dart';
import '../providers/alarm_providers.dart';
import '../widgets/glass_card.dart';
import '../widgets/glass_dialog.dart';
import '../widgets/camera_preview_widget.dart';
import '../widgets/wireframe_background.dart';

/// Full-screen alarm screen — rebuilt with glass design.
/// Displays alarm info, camera preview for face verification,
/// and glass-styled action buttons for stop/snooze.
/// All alarm/verification logic preserved (P0 safe).
class WakeAlarmScreen extends ConsumerStatefulWidget {
  const WakeAlarmScreen({super.key, required this.alarm});

  final WakeAlarm alarm;

  @override
  ConsumerState<WakeAlarmScreen> createState() => _WakeAlarmScreenState();
}

class _WakeAlarmScreenState extends ConsumerState<WakeAlarmScreen>
    with TickerProviderStateMixin {
  late AnimationController _pulseController;
  late AnimationController _slideController;
  late Animation<double> _pulseAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
    _pulseAnimation = CurvedAnimation(
      parent: _pulseController,
      curve: Curves.easeInOut,
    );

    _slideController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    )..forward();
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _slideController,
      curve: Curves.easeOutCubic,
    ));
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _slideController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = S.of(context);
    final alarm = widget.alarm;
    final vState = ref.watch(wakeVerificationStateProvider);

    final isRinging = vState == WakeVerificationState.ringing;
    final isChecking = vState == WakeVerificationState.checking ||
        vState == WakeVerificationState.faceDetected;
    final isAwaitingVoice =
        vState == WakeVerificationState.awaitingVoiceConfirmation;
    final isVerified = vState == WakeVerificationState.verified;

    // Determine background tint based on state
    final bgColor = isRinging
        ? AppColors.error.withValues(alpha: 0.08)
        : isVerified
            ? AppColors.cyan.withValues(alpha: 0.06)
            : AppColors.background;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Stack(
          children: [
            // ── Dark gradient background ──
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    AppColors.background,
                    bgColor,
                    AppColors.background,
                  ],
                ),
              ),
            ),

            // ── Wireframe constellation overlay ──
            const Positioned.fill(
              child: WireframeBackground(
                opacity: 0.3,
                nodeCount: 15,
                lineDistance: 80,
              ),
            ),

            // ── Content ──
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
              child: Column(
                children: [
                  // ─── Top: Time & Label ───
                  SlideTransition(
                    position: _slideAnimation,
                    child: Column(
                      children: [
                        const SizedBox(height: 32),
                        Text(
                          alarm.time.formatted,
                          style: TextStyle(
                            fontSize: 64,
                            fontWeight: FontWeight.w800,
                            color: isRinging ? AppColors.error : AppColors.onBackground,
                            letterSpacing: 2,
                          ),
                        ),
                        const SizedBox(height: 8),
                        if (alarm.label.isNotEmpty)
                          Text(
                            alarm.label,
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w500,
                              color: AppColors.hint,
                            ),
                          ),
                        const SizedBox(height: 24),
                        _buildStateIndicator(context, l10n, vState),
                      ],
                    ),
                  ),

                  const Spacer(flex: 2),

                  // ─── Camera preview area ───
                  if (isChecking || isAwaitingVoice)
                    _buildCameraArea(context, vState),

                  // ─── Pulse ring when ringing ───
                  if (isRinging) _buildPulseRing(),

                  const Spacer(flex: 2),

                  // ─── Action buttons ───
                  SlideTransition(
                    position: _slideAnimation,
                    child: _buildActionButtons(
                      context,
                      l10n,
                      alarm,
                      isRinging,
                      isChecking,
                      isAwaitingVoice,
                      isVerified,
                    ),
                  ),

                  const SizedBox(height: 32),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Glass-styled state indicator pill.
  Widget _buildStateIndicator(
    BuildContext context,
    S l10n,
    WakeVerificationState vState,
  ) {
    final icon = switch (vState) {
      WakeVerificationState.ringing => Icons.alarm,
      WakeVerificationState.checking => Icons.face,
      WakeVerificationState.faceDetected => Icons.face,
      WakeVerificationState.awaitingVoiceConfirmation => Icons.mic,
      WakeVerificationState.verified => Icons.check_circle,
      WakeVerificationState.snoozed => Icons.snooze,
      WakeVerificationState.timeout => Icons.timer_off,
      WakeVerificationState.error => Icons.error,
      _ => Icons.alarm,
    };

    final label = switch (vState) {
      WakeVerificationState.ringing => l10n.alarmRinging,
      WakeVerificationState.checking => l10n.alarmCheckingFace,
      WakeVerificationState.faceDetected => l10n.alarmFaceDetected,
      WakeVerificationState.awaitingVoiceConfirmation =>
        l10n.alarmAwaitingVoice,
      WakeVerificationState.verified => l10n.alarmVerified,
      WakeVerificationState.snoozed => l10n.alarmSnoozed,
      WakeVerificationState.timeout => l10n.alarmTimeout,
      WakeVerificationState.error => l10n.alarmError,
      _ => l10n.alarmScheduled,
    };

    final color = switch (vState) {
      WakeVerificationState.ringing => AppColors.error,
      WakeVerificationState.checking => AppColors.cyan,
      WakeVerificationState.faceDetected => AppColors.cyan,
      WakeVerificationState.awaitingVoiceConfirmation => AppColors.violetLight,
      WakeVerificationState.verified => AppColors.cyan,
      _ => AppColors.hint,
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(
          color: color.withValues(alpha: 0.3),
          width: 0.5,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(width: 10),
          Text(
            label,
            style: TextStyle(
              fontSize: 15,
              color: color,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  /// Glass-styled camera preview container.
  Widget _buildCameraArea(
    BuildContext context,
    WakeVerificationState vState,
  ) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(28),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 0, sigmaY: 0),
        child: Container(
          height: 180,
          width: double.infinity,
          decoration: BoxDecoration(
            color: AppColors.glassBackground,
            borderRadius: BorderRadius.circular(28),
            border: Border.all(
              color: AppColors.glassBorder,
              width: 0.5,
            ),
          ),
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Live camera preview from WakeCameraService
              const CameraPreviewWidget(),
              if (vState == WakeVerificationState.faceDetected)
                Positioned(
                  top: 12,
                  right: 12,
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: AppColors.cyan.withValues(alpha: 0.9),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.check,
                      color: Colors.white,
                      size: 16,
                    ),
                  ),
                ),
              Positioned(
                bottom: 8,
                left: 8,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.black54,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.lock_outline, size: 12, color: Colors.white70),
                      const SizedBox(width: 4),
                      Text(
                        S.of(context).alarmPrivacyMode,
                        style: const TextStyle(fontSize: 10, color: Colors.white70),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Pulse ring with AURA design colors.
  Widget _buildPulseRing() {
    return ScaleTransition(
      scale: _pulseAnimation,
      child: Container(
        width: 120,
        height: 120,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: AppColors.error.withValues(alpha: 0.12),
          border: Border.all(
            color: AppColors.error.withValues(alpha: 0.4),
            width: 3,
          ),
        ),
        child: Icon(
          Icons.alarm,
          size: 56,
          color: AppColors.error,
        ),
      ),
    );
  }

  /// Glass-styled action buttons.
  Widget _buildActionButtons(
    BuildContext context,
    S l10n,
    WakeAlarm alarm,
    bool isRinging,
    bool isChecking,
    bool isAwaitingVoice,
    bool isVerified,
  ) {
    final notifier = ref.read(wakeVerificationStateProvider.notifier);

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        // Snooze button — outlined glass
        if (isRinging || isAwaitingVoice)
          GlassButton(
            label: l10n.alarmSnooze,
            variant: GlassButtonVariant.outlined,
            icon: Icons.snooze,
            onPressed: () => notifier.snooze(alarm),
          ),

        // Stop / Dismiss button — filled glass (red tinted)
        if (isRinging || isChecking || isAwaitingVoice)
          _buildStopButton(context, l10n, alarm, notifier),

        // Done button (when verified) — filled glass
        if (isVerified)
          GlassButton(
            label: l10n.alarmDone,
            variant: GlassButtonVariant.filled,
            icon: Icons.check_circle_outline,
            onPressed: () {
              notifier.stopAlarm(alarm);
              Navigator.of(context).pop();
            },
          ),
      ],
    );
  }

  /// Stop/I'm Awake button — glass styled with error color override.
  Widget _buildStopButton(
    BuildContext context,
    S l10n,
    WakeAlarm alarm,
    WakeVerificationNotifier notifier,
  ) {
    if (!alarm.requiresVerification) {
      return GlassButton(
        label: l10n.alarmStop,
        variant: GlassButtonVariant.filled,
        icon: Icons.stop_circle,
        onPressed: () {
          notifier.stopAlarm(alarm);
          Navigator.of(context).pop();
        },
      );
    }

    return GlassButton(
      label: l10n.alarmImAwake,
      variant: GlassButtonVariant.filled,
      icon: Icons.wb_sunny_outlined,
      onPressed: () {
        if (alarm.verificationConfig.mode == WakeVerificationMode.none) {
          notifier.stopAlarm(alarm);
          Navigator.of(context).pop();
        }
      },
    );
  }
}
