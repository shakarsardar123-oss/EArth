import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:texo/l10n/app_localizations.dart';

import '../../core/localization/locale_provider.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/responsive.dart';
import '../providers/app_providers.dart';
import '../widgets/widgets.dart';
import '../widgets/glass_dialog.dart';
import '../widgets/api_key_settings_section.dart';

/// Settings screen — fully rebuilt with glass/dark/gradient design.
///
/// Matches the visual language of Dashboard, Chat, and Voice:
/// - Deep black/navy gradient background
/// - WireframeBackground constellation overlay
/// - GlassCard for each section
/// - GlassDialog instead of AuraDialog
/// - GlassTextField instead of AuraTextField
/// - Inline layout (no LayoutContainer)
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = S.of(context);
    final theme = Theme.of(context);
    final layout = ResponsiveLayout.of(context);

    return Scaffold(
      backgroundColor: AppColors.amoledBlack,
      body: SafeArea(
        child: Stack(
          children: [
            // ── AMOLED pure black background (no gradient) ──
            // Requirement: #000000 pure black for AMOLED screens

            // ── Wireframe constellation ──
            const WireframeBackground(
              opacity: 0.4,
              nodeCount: 18,
              lineDistance: 100,
            ),

            // ── Content ──
            Center(
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: layout.maxContentWidth),
                child: Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: layout.horizontalPadding,
                    vertical: 8,
                  ),
                  child: CustomScrollView(
                    slivers: [
                      // ── Header ──
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.only(bottom: 20, top: 8),
                          child: Text(
                            l10n.settingsTab,
                            style: theme.textTheme.headlineMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                              color: AppColors.onBackground,
                            ),
                          ),
                        ),
                      ),

                      // ── Assistant Identity Section ──
                      SliverToBoxAdapter(
                        child: _SectionHeader(title: l10n.assistantIdentity),
                      ),
                      SliverToBoxAdapter(child: const NameEditor()),

                      // ── Appearance Section ──
                      SliverToBoxAdapter(
                        child: _SectionHeader(title: l10n.appearance),
                      ),
                      SliverToBoxAdapter(child: const ThemeSelector()),
                      SliverToBoxAdapter(child: SizedBox(height: 12)),

                      // Language selection
                      SliverToBoxAdapter(
                        child: _LanguageSelector(),
                      ),

                      // Text direction
                      SliverToBoxAdapter(
                        child: _TextDirectionToggle(),
                      ),

                      // ── AI Provider / API key Section ──
                      SliverToBoxAdapter(
                        child: const _SectionHeader(title: 'AI provider'),
                      ),
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          child: GlassCard(
                            padding: const EdgeInsets.all(16),
                            child: const ApiKeySettingsSection(),
                          ),
                        ),
                      ),

                      // ── Permissions Section ──
                      SliverToBoxAdapter(
                        child: _SectionHeader(title: l10n.perm_request),
                      ),
                      SliverToBoxAdapter(
                        child: const PermissionsSection(),
                      ),

                      // ── General Section ──
                      SliverToBoxAdapter(
                        child: _SectionHeader(title: l10n.general),
                      ),
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                          child: GlassCard(
                            onTap: () => _showAboutDialog(context, l10n),
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                            child: Row(
                              children: [
                                Container(
                                  width: 40,
                                  height: 40,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: AppColors.violet.withOpacity(0.12),
                                    border: Border.all(
                                      color: AppColors.violetLight.withOpacity(0.2),
                                      width: 0.5,
                                    ),
                                  ),
                                  child: Icon(
                                    Icons.info_outline_rounded,
                                    color: AppColors.cyan,
                                    size: 20,
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Text(
                                    l10n.aboutApp,
                                    style: TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w600,
                                      color: AppColors.onBackground,
                                    ),
                                  ),
                                ),
                                Icon(
                                  Icons.chevron_right,
                                  size: 18,
                                  color: AppColors.hint,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),

                      // ── Phase 3 Notice ──
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 24),
                          child: Text(
                            l10n.phaseNotice,
                            style: TextStyle(
                              fontSize: 11,
                              color: AppColors.hint,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ),

                      SliverToBoxAdapter(child: SizedBox(height: 24)),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showAboutDialog(BuildContext context, S l10n) {
    GlassDialog.show(
      context: context,
      icon: Icons.auto_awesome_rounded,
      title: l10n.aboutApp,
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(height: 8),
          Text(
            l10n.version,
            style: TextStyle(fontSize: 13, color: AppColors.onBackground),
          ),
          SizedBox(height: 4),
          Text(
            l10n.builtWith,
            style: TextStyle(fontSize: 12, color: AppColors.hint),
          ),
          SizedBox(height: 16),
          Text(
            l10n.phaseNotice,
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 11, color: AppColors.hint),
          ),
        ],
      ),
    );
  }
}

/// Section header with accent color — matches new design language.
class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title});
  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 4),
      child: Row(
        children: [
          Container(
            width: 3,
            height: 16,
            decoration: BoxDecoration(
              color: AppColors.cyan,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            title,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: AppColors.violetLight,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }
}

/// Language selector row — glass styled with cyan icon.
class _LanguageSelector extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = S.of(context);
    final currentLocale = ref.watch(overriddenLocaleProvider);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: GlassCard(
        onTap: () => _showLocaleDialog(context, ref, currentLocale),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.violet.withOpacity(0.12),
                border: Border.all(
                  color: AppColors.violetLight.withOpacity(0.2),
                  width: 0.5,
                ),
              ),
              child: Icon(
                Icons.language_rounded,
                color: AppColors.cyan,
                size: 20,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l10n.languageSelection,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: AppColors.violetLight,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    currentLocale == AuraLocale.ku ? l10n.kurdish : 'English',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: AppColors.onBackground,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right,
              size: 18,
              color: AppColors.hint,
            ),
          ],
        ),
      ),
    );
  }

  void _showLocaleDialog(BuildContext context, WidgetRef ref, AuraLocale current) {
    final l10n = S.of(context);
    final notifier = ref.read(overriddenLocaleProvider.notifier);

    GlassDialog.show(
      context: context,
      icon: Icons.language_rounded,
      title: l10n.languageSelection,
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 8),
          _LocaleOption(
            label: l10n.kurdish,
            isSelected: current == AuraLocale.ku,
            onTap: () {
              notifier.setLocale(AuraLocale.ku);
              Navigator.of(context).pop();
            },
          ),
          const SizedBox(height: 8),
          _LocaleOption(
            label: 'English',
            isSelected: current == AuraLocale.en,
            onTap: () {
              notifier.setLocale(AuraLocale.en);
              Navigator.of(context).pop();
            },
          ),
        ],
      ),
    );
  }
}

/// Locale option row in dialog — glass styled.
class _LocaleOption extends StatelessWidget {
  const _LocaleOption({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.violet.withOpacity(0.15)
              : AppColors.glassBackground,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected
                ? AppColors.cyan.withOpacity(0.4)
                : AppColors.glassBorder,
            width: isSelected ? 1 : 0.5,
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                  color: isSelected ? AppColors.cyan : AppColors.onBackground,
                ),
              ),
            ),
            if (isSelected)
              Icon(Icons.check_circle, size: 18, color: AppColors.cyan),
          ],
        ),
      ),
    );
  }
}

/// Text direction toggle — glass styled switch.
class _TextDirectionToggle extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = S.of(context);
    final currentLocale = ref.watch(overriddenLocaleProvider);
    final isRtl = currentLocale.textDirection == TextDirection.rtl;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: GlassCard(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.violet.withOpacity(0.12),
                border: Border.all(
                  color: AppColors.violetLight.withOpacity(0.2),
                  width: 0.5,
                ),
              ),
              child: Icon(
                Icons.format_textdirection_r_to_l,
                color: AppColors.cyan,
                size: 20,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l10n.textDirection,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: AppColors.violetLight,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    isRtl ? l10n.directionRtl : l10n.directionLtr,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: AppColors.onBackground,
                    ),
                  ),
                ],
              ),
            ),
            Switch(
              value: isRtl,
              activeColor: AppColors.cyan,
              onChanged: (value) {
                final notifier = ref.read(overriddenLocaleProvider.notifier);
                notifier.setLocale(value ? AuraLocale.ku : AuraLocale.en);
              },
            ),
          ],
        ),
      ),
    );
  }
}
