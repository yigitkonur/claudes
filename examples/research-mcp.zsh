# Strict-MCP research preset
#
# Loads only the research MCP set and nothing else (--strict-mcp-config),
# with a system-prompt addendum that pins Claude to citing scraped sources
# rather than fabricating. Requires the companion JSON at
# ~/.config/claudes/mcp/research-only.json — see examples/mcp/ for a template.
#
# Copy the block you want into ~/.config/claudes/presets.zsh.

CLAUDES_PRESETS[rmcp]="--model opus --effort max --permission-mode default --strict-mcp-config"
CLAUDES_DESCRIPTIONS[rmcp]="Opus · max · strict research MCP · grounded"
CLAUDES_ALIASES[rm]=rmcp
CLAUDES_MCP[rmcp]="$HOME/.config/claudes/mcp/research-only.json"
CLAUDES_PROMPT[rmcp]="You are in grounded-research mode. Do not answer from memory on any claim that can be verified online. For every non-trivial fact, first run a web-search or scrape-links call via the research-powerpack MCP, then cite the source URL inline. If the tool returns no evidence, say 'no evidence found' — never fabricate."

# Setup:
#   mkdir -p ~/.config/claudes/mcp
#   cp examples/mcp/research-only.json ~/.config/claudes/mcp/
#   # Edit the JSON to point at your MCP server(s).
#
# Usage:
#   claudes rmcp "what is the current Kubernetes LTS?"
