# Cheap / single-file preset
#
# Sonnet at low effort with --bare — skips auto project scan, hooks, LSP,
# plugin sync, and auto-memory. Tokens drop ~30-50% at the cost of context
# breadth. Pair with --add-dir if you need a specific folder visible.
#
# Copy the block you want into ~/.config/claudes/presets.zsh.

CLAUDES_PRESETS[cheap]="--model sonnet --effort low --permission-mode default --bare"
CLAUDES_DESCRIPTIONS[cheap]="Sonnet · low · --bare · single-file ops"
CLAUDES_ALIASES[c]=cheap

# Usage:
#   claudes cheap --add-dir ./src "explain this function"
#   echo "$CODE" | claudes c -p "summarize"
