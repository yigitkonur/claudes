# Offline / airplane preset
#
# No MCP servers, no slash-command skills, no WebFetch, no WebSearch, --bare
# to skip hooks/LSP/plugins. Works on hotel wifi that blocks arbitrary hosts
# or on a plane with patchy connectivity — Claude Code stays fully local
# except for Anthropic's own API.
#
# Copy the block you want into ~/.config/claudes/presets.zsh.

CLAUDES_PRESETS[offline]="--model sonnet --effort low --permission-mode default --bare --disable-slash-commands --strict-mcp-config --disallowedTools WebFetch,WebSearch"
CLAUDES_DESCRIPTIONS[offline]="Sonnet · low · bare · no MCP/skills/web"
CLAUDES_ALIASES[o]=offline

# Usage:
#   claudes offline "refactor this file"
#
# Note: --strict-mcp-config with no --mcp-config file means "no MCP servers at all".
