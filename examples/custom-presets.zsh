# Example custom presets for claudes
#
# Copy this file to ~/.config/claudes/presets.zsh to activate your presets.
# This file is sourced after the built-in defaults, so you can override or extend.
#
# For richer, single-purpose recipes, see the sibling files in this directory:
#   review.zsh           · read-only PR review
#   cheap.zsh            · --bare single-file operations
#   ci.zsh               · --print --output-format stream-json for scripts
#   research-mcp.zsh     · strict-MCP research runs with companion JSON
#   offline.zsh          · airplane mode — no hooks, no MCP, no slash commands
#   audit.zsh            · security / compliance walk with tool lockdown
#   worktree.zsh         · function-form: spawn worktree + tmux pane
#   pr.zsh               · function-form: resume a PR-linked session
#
# ─────────────────────────────────────────────────────────────────────────────

# Override the default 'quick' preset to also bypass permissions
CLAUDES_PRESETS[quick]="--model sonnet --effort low --permission-mode bypassPermissions"
CLAUDES_DESCRIPTIONS[quick]="Sonnet 4.6 · low · bypass permissions · no friction"

# A long-context preset for big refactors
CLAUDES_PRESETS[bigctx]="--model claude-opus-4-7 --effort max --permission-mode plan"
CLAUDES_DESCRIPTIONS[bigctx]="Opus 4.7 · max · plan mode · large refactors"
CLAUDES_ALIASES[b]=bigctx

# A resume-last-session shortcut
CLAUDES_PRESETS[last]="--model opus --effort max --continue"
CLAUDES_DESCRIPTIONS[last]="Opus 4.7 · max · continue last session"

# Remove a built-in preset you don't want
# unset 'CLAUDES_PRESETS[research]'
# unset 'CLAUDES_DESCRIPTIONS[research]'
# unset 'CLAUDES_ALIASES[r]'
