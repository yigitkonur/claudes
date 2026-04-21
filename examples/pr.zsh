# Pull-request session preset (function-form)
#
# Resumes or opens a Claude Code session linked to a PR. With no arg, uses
# the PR associated with the current branch (via gh). With an arg, uses that
# PR number or URL.
#
# Requires: gh CLI. Copy the block you want into ~/.config/claudes/presets.zsh.

_claudes_preset_pr() {
  local pr="${1:-$(gh pr view --json number -q .number 2>/dev/null)}"
  if [[ -z "$pr" ]]; then
    echo "claudes pr: no PR specified and no PR on current branch" >&2
    return 1
  fi
  shift 2>/dev/null || true
  command claude --from-pr "$pr" --model opus --effort max --permission-mode default "$@"
}

CLAUDES_PRESETS[pr]="fn:_claudes_preset_pr"
CLAUDES_DESCRIPTIONS[pr]="Opus · max · --from-pr · PR-linked session"

# Usage:
#   claudes pr              # current branch's PR
#   claudes pr 1234         # specific PR number
#   claudes pr https://github.com/org/repo/pull/1234
