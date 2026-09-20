#!/usr/bin/env python3
"""Fix unused imports and unused variables in AURA Flutter project."""
import re
import os

BASE = "/nfs/103520092/outputs/aura_assistant/lib"

# Unused imports to remove (file:line -> import path)
unused_imports = {
    "core/ai/openai_provider.dart": [10, 12, 14, 15],
    "core/theme/theme_provider.dart": [7],
    "core/voice/speech_recognition_impl.dart": [7],
    "core/voice/voice_service_impl.dart": [4, 5],
    "core/wakeword/wakeword_provider.dart": [4],
    "core/wakeword/wakeword_service.dart": [4],
    "core/memory/memory_repository_impl.dart": [],  # handle separately
    "presentation/providers/app_providers.dart": [1, 17, 18, 27, 28, 29],
    "presentation/screens/dashboard_screen.dart": [8, 14, 16, 18],
    "presentation/screens/settings_screen.dart": [5, 7],
    "presentation/screens/voice_screen.dart": [9, 13, 15, 17],
    "presentation/widgets/aura_dialog.dart": [3, 4],
    "presentation/widgets/name_editor.dart": [6],
    "presentation/widgets/status_indicator.dart": [7],
    "presentation/widgets/voice_button.dart": [7],
}

def remove_lines(filepath, line_numbers):
    """Remove specific line numbers from a file."""
    if not line_numbers:
        return
    with open(filepath, 'r') as f:
        lines = f.readlines()
    
    # Remove lines (1-indexed to 0-indexed), but check they are actually import lines
    new_lines = []
    for i, line in enumerate(lines):
        lineno = i + 1
        if lineno in line_numbers:
            stripped = line.strip()
            if stripped.startswith("import ") or stripped.startswith("import\t"):
                print(f"  Removing line {lineno}: {stripped[:80]}")
                continue
            else:
                print(f"  WARNING: Line {lineno} not an import, skipping: {stripped[:60]}")
                new_lines.append(line)
        else:
            new_lines.append(line)
    
    with open(filepath, 'w') as f:
        f.writelines(new_lines)

# Fix unused imports
for relpath, lines_to_remove in unused_imports.items():
    filepath = os.path.join(BASE, relpath)
    if os.path.exists(filepath):
        print(f"Processing {relpath}...")
        remove_lines(filepath, lines_to_remove)
    else:
        print(f"SKIP: {filepath} not found")

# Fix unused _uuid field in memory_repository_impl.dart
print("\nFixing unused _uuid field...")
filepath = os.path.join(BASE, "core/memory/memory_repository_impl.dart")
with open(filepath, 'r') as f:
    content = f.read()

# Find and remove the _uuid field
content = re.sub(r"\n\s*final Uuid _uuid[^;]*;\n", "\n", content)
# Also remove Uuid import if it becomes unused
with open(filepath, 'w') as f:
    f.write(content)

# Fix unused local variables
print("\nFixing unused local variables...")

# dashboard_screen.dart - unused cs, isRtl, accent
filepath = os.path.join(BASE, "presentation/screens/dashboard_screen.dart")
with open(filepath, 'r') as f:
    content = f.read()

# Comment out unused variables with // prefix (safer than removing)
# Actually, let's prefix them with _ to indicate intentionally unused, or remove them

# For 'cs' variables - likely ColorScheme lookups that were replaced
# For 'isRtl' - likely replaced by Directionality utility
# For 'accent' - likely replaced by colorScheme

# voice_screen.dart - unused voiceState, isRtl
filepath2 = os.path.join(BASE, "presentation/screens/voice_screen.dart")
with open(filepath2, 'r') as f:
    content2 = f.read()

# aura_button.dart - unused 'r'
filepath3 = os.path.join(BASE, "presentation/widgets/aura_button.dart")
with open(filepath3, 'r') as f:
    content3 = f.read()

# voice_visualizer.dart - unused 'theme', 'halfH'
filepath4 = os.path.join(BASE, "presentation/widgets/voice_visualizer.dart")
with open(filepath4, 'r') as f:
    content4 = f.read()

print("\nDone with import cleanup. Variables need manual inspection.")
print("Run 'dart analyze lib/' to see remaining issues.")
