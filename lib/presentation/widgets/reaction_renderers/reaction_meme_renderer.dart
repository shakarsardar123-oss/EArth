/// Meme-style visual renderer for the Reaction Banner.
///
/// Displays a humorous text card with meme-like formatting.
/// No hardcoded jokes — content comes from reaction payload.
library;

import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';

class ReactionMemeRenderer extends StatelessWidget {
  const ReactionMemeRenderer({
    super.key,
    required this.topText,
    this.bottomText,
  });

  /// Top line of the meme text.
  final String topText;

  /// Optional bottom line (punchline).
  final String? bottomText;

  @override
  Widget build(BuildContext context) {
    final textDirection = Directionality.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.background.withOpacity(0.7),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.cyan.withOpacity(0.3), width: 1),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(topText, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Colors.white, letterSpacing: 0.5), textDirection: textDirection, textAlign: TextAlign.center),
          if (bottomText != null && bottomText!.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(bottomText!, style: TextStyle(fontSize: 11, color: AppColors.cyan.withOpacity(0.8), fontStyle: FontStyle.italic), textDirection: textDirection, textAlign: TextAlign.center),
          ],
        ],
      ),
    );
  }
}
