# Example custom presets for claudes
#
# Copy this file to ~/.config/claudes/presets.zsh to activate your presets.
# This file is sourced after the built-in defaults, so you can override or extend.
#
# ─────────────────────────────────────────────────────────────────────────────

# Add a Haiku preset for ultra-cheap operations
CLAUDES_PRESETS[haiku]="--model haiku --effort low --permission-mode default"
CLAUDES_DESCRIPTIONS[haiku]="Haiku 4.5 · low effort · ultra-cheap, near-instant"
CLAUDES_ALIASES[h]=haiku

# Override the default 'quick' preset to also bypass permissions
CLAUDES_PRESETS[quick]="--model sonnet --effort low --permission-mode bypassPermissions"
CLAUDES_DESCRIPTIONS[quick]="Sonnet 4.6 · low · bypass permissions · no friction"

# Add a long-context preset for big refactors
CLAUDES_PRESETS[bigctx]="--model claude-opus-4-7 --effort max --permission-mode plan"
CLAUDES_DESCRIPTIONS[bigctx]="Opus 4.7 · max · plan mode · large refactors"
CLAUDES_ALIASES[b]=bigctx

# Add a resume-last-session shortcut
CLAUDES_PRESETS[resume]="--model opus --effort max --continue"
CLAUDES_DESCRIPTIONS[resume]="Opus 4.7 · max · continue last session"

# Add a MCP-rich research preset that loads specific MCPs
CLAUDES_PRESETS[deepresearch]="--model opus --effort max --permission-mode default --mcp-config ~/.config/claudes/research-mcps.json"
CLAUDES_DESCRIPTIONS[deepresearch]="Opus 4.7 · max · with custom research MCPs"
CLAUDES_ALIASES[dr]=deepresearch

# Remove a built-in preset you don't want
# unset 'CLAUDES_PRESETS[research]'
# unset 'CLAUDES_DESCRIPTIONS[research]'
# unset 'CLAUDES_ALIASES[r]'
