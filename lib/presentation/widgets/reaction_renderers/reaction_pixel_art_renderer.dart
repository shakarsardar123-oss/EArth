/// Pixel-art visual style renderer for the Reaction Banner.
///
/// Displays a grid-based pixel art representation using
/// colored containers in a grid layout.
library;

import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';

class ReactionPixelArtRenderer extends StatelessWidget {
  const ReactionPixelArtRenderer({
    super.key,
    required this.grid,
    this.label,
    this.cellSize = 4.0,
  });

  /// 2D grid of color values (row-major). 0 = empty, 1 = primary, 2 = accent.
  final List<List<int>> grid;

  /// Optional label text.
  final String? label;

  /// Size of each pixel cell in logical pixels.
  final double cellSize;

  Color _cellColor(int value) => switch (value) {
    0 => Colors.transparent,
    1 => AppColors.cyan,
    2 => AppColors.background, // dark accent
    _ => AppColors.cyan.withOpacity(0.5),
  };

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: grid.map((row) => Row(
              mainAxisSize: MainAxisSize.min,
              children: row.map((cell) => Container(
                width: cellSize,
                height: cellSize,
                color: _cellColor(cell),
              )).toList(),
            )).toList(),
          ),
        ),
        if (label != null && label!.isNotEmpty) ...[
          const SizedBox(height: 4),
          Text(label!, style: TextStyle(fontSize: 11, color: AppColors.cyan.withOpacity(0.7), fontFamily: 'monospace'), textDirection: Directionality.of(context), textAlign: TextAlign.center),
        ],
      ],
    );
  }
}
