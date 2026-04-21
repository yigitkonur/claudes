# CI / headless / scripting preset
#
# Print mode + stream-json + --bare + budget cap. Designed for piping into
# jq, tee, or a workflow step. --max-budget-usd only works with --print.
#
# Copy the block you want into ~/.config/claudes/presets.zsh.

CLAUDES_PRESETS[ci]="--print --output-format stream-json --bare --max-budget-usd 1 --model sonnet --effort low --permission-mode default"
CLAUDES_DESCRIPTIONS[ci]="Sonnet · low · --print --bare · scripts & CI"
CLAUDES_ALIASES[ci]=ci

# Usage:
#   claudes ci "lint this diff" | jq -r '.content[0].text'
#   cat error.log | claudes ci "diagnose"
#
# For GitHub Actions, use anthropics/claude-code-action@v1 directly;
# this preset is for local scripts and one-shot pipes.
