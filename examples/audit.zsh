# Security / compliance audit preset
#
# Opus at max effort (audits benefit from deep reasoning) with tools clipped
# to read-only and git-inspection. The system prompt loads an audit rubric so
# every finding is classified and actionable rather than hand-wavy.
#
# Copy the block you want into ~/.config/claudes/presets.zsh.

CLAUDES_PRESETS[audit]="--model opus --effort max --permission-mode default --tools Read,Grep,Glob,Bash --disallowedTools WebFetch,WebSearch"
CLAUDES_DESCRIPTIONS[audit]="Opus · max · read-only · security/compliance audit"
CLAUDES_ALIASES[a]=audit
CLAUDES_PROMPT[audit]="You are running a security and compliance audit. Use only read-only tools (Read, Grep, Glob, Bash for inspection). For each finding, output: (1) severity [critical/high/medium/low/info], (2) CWE or category, (3) exact file:line, (4) evidence quote, (5) concrete remediation. Do not fabricate issues — if the code is clean, say so. Do not propose refactors outside the audit scope."

# Usage:
#   claudes audit                          # interactive audit
#   claudes a -p "audit @src/auth/"        # scripted
