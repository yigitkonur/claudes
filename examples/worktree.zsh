# Worktree preset (function-form)
#
# Spawns an isolated git worktree + tmux pane, then launches Claude inside it.
# First positional arg becomes the worktree name; remaining args pass through.
# Good for parallel agents on the same repo without branch collisions.
#
# Copy the block you want into ~/.config/claudes/presets.zsh.

_claudes_preset_worktree() {
  local name="${1:-feat-$(date +%s)}"
  shift 2>/dev/null || true
  command claude -w "$name" --tmux --model opus --effort max --permission-mode default "$@"
}

CLAUDES_PRESETS[wt]="fn:_claudes_preset_worktree"
CLAUDES_DESCRIPTIONS[wt]="Opus · max · -w --tmux · parallel agent"

# Usage:
#   claudes wt feature-auth                # named worktree
#   claudes wt                             # auto-name: feat-<timestamp>
#   claudes wt refactor-db "start by..."   # name + prompt
