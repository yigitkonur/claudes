#!/usr/bin/env bash
# claudes installer
#
# One-liner:
#   curl -fsSL https://raw.githubusercontent.com/yigitkonur/claudes/main/install.sh | bash
#
# Or clone and run:
#   git clone https://github.com/yigitkonur/claudes.git
#   cd claudes && ./install.sh
#
# Installs claudes.zsh into ~/.zshrc.d/ (if it exists) or appends a source
# line to ~/.zshrc. Also creates an example user-config file.

set -euo pipefail

REPO_RAW="https://raw.githubusercontent.com/yigitkonur/claudes/main"
INSTALL_DIR="$HOME/.local/share/claudes"
CONFIG_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/claudes"
ZSHRC="$HOME/.zshrc"
ZSHRC_D="$HOME/.zshrc.d"

if [ -t 1 ]; then
  GREEN='\033[0;32m'; YELLOW='\033[1;33m'; BLUE='\033[0;34m'; NC='\033[0m'
else
  GREEN=''; YELLOW=''; BLUE=''; NC=''
fi
ok()   { printf "${GREEN}[ok]${NC} %s\n" "$1"; }
warn() { printf "${YELLOW}[!!]${NC} %s\n" "$1"; }
info() { printf "${BLUE}[..]${NC} %s\n" "$1"; }

printf "\n  ${BLUE}claudes${NC} — Claude Code preset picker for zsh\n\n"

mkdir -p "$INSTALL_DIR" "$CONFIG_DIR"

# ── Fetch or copy claudes.zsh ──────────────────────────────────────────────
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [ -f "$SCRIPT_DIR/claudes.zsh" ]; then
  cp "$SCRIPT_DIR/claudes.zsh" "$INSTALL_DIR/claudes.zsh"
  info "Installed from local clone"
else
  info "Downloading claudes.zsh from GitHub..."
  if ! curl -fsSL "${REPO_RAW}/claudes.zsh" -o "$INSTALL_DIR/claudes.zsh"; then
    echo "Failed to download claudes.zsh" >&2
    exit 1
  fi
fi
ok "Script at $INSTALL_DIR/claudes.zsh"

# ── Wire into shell ────────────────────────────────────────────────────────
if [ -d "$ZSHRC_D" ]; then
  ln -sf "$INSTALL_DIR/claudes.zsh" "$ZSHRC_D/90-claudes.zsh"
  ok "Linked to $ZSHRC_D/90-claudes.zsh"
else
  MARK="# claudes — https://github.com/yigitkonur/claudes"
  if grep -qF "$MARK" "$ZSHRC" 2>/dev/null; then
    ok "Already sourced from $ZSHRC"
  else
    {
      echo ""
      echo "$MARK"
      echo "[ -f \"$INSTALL_DIR/claudes.zsh\" ] && source \"$INSTALL_DIR/claudes.zsh\""
    } >> "$ZSHRC"
    ok "Appended source line to $ZSHRC"
  fi
fi

# ── Drop example user config if none exists ────────────────────────────────
USER_PRESETS="$CONFIG_DIR/presets.zsh"
if [ ! -f "$USER_PRESETS" ]; then
  cat > "$USER_PRESETS" <<'EOF'
# ~/.config/claudes/presets.zsh
#
# Define your own Claude Code presets here. This file is sourced after the
# built-in defaults, so you can override any built-in or add new ones.
#
# Keys used:
#   CLAUDES_PRESETS[name]="<claude CLI flags>"
#   CLAUDES_DESCRIPTIONS[name]="one-line description"
#   CLAUDES_ALIASES[short]=name
#
# Example — uncomment and customize:
#
# CLAUDES_PRESETS[haiku]="--model haiku --effort low --permission-mode default"
# CLAUDES_DESCRIPTIONS[haiku]="Haiku 4.5 · low · near-instant, ultra-cheap"
# CLAUDES_ALIASES[h]=haiku
#
# See more examples:
#   https://github.com/yigitkonur/claudes/blob/main/examples/custom-presets.zsh
EOF
  ok "Example user-config at $USER_PRESETS"
fi

# ── Summary ────────────────────────────────────────────────────────────────
cat <<EOF

  ${GREEN}Installed.${NC}

  Restart your shell or:  source "$INSTALL_DIR/claudes.zsh"
  Then try:               claudes

  Add custom presets:     \$EDITOR "$USER_PRESETS"
  See built-in presets:   claudes list
  Full help:              claudes help

EOF
