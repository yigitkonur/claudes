#!/usr/bin/env bash
# claudes installer — interactive setup for the Claude Code preset picker
#
# One-liner:   curl -fsSL https://raw.githubusercontent.com/yigitkonur/claudes/main/install.sh | bash
# Local clone: git clone https://github.com/yigitkonur/claudes && cd claudes && ./install.sh

set -euo pipefail

REPO_RAW="https://raw.githubusercontent.com/yigitkonur/claudes/main"
INSTALL_DIR="$HOME/.local/share/claudes"
CONFIG_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/claudes"
ZSHRC="$HOME/.zshrc"
ZSHRC_D="$HOME/.zshrc.d"
USER_PRESETS="$CONFIG_DIR/presets.zsh"
UX_SETTINGS="$CONFIG_DIR/ux-settings.zsh"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-/dev/stdin}")" 2>/dev/null && pwd || echo "")"

# ── Colours ───────────────────────────────────────────────────────────────
if [ -t 1 ]; then
  C_BOLD='\033[1m'; C_DIM='\033[2m'; C_RST='\033[0m'
  C_GRN='\033[0;32m'; C_YLW='\033[1;33m'; C_BLU='\033[0;34m'; C_RED='\033[0;31m'
else
  C_BOLD=''; C_DIM=''; C_RST=''; C_GRN=''; C_YLW=''; C_BLU=''; C_RED=''
fi
ok()   { printf "${C_GRN}[ok]${C_RST} %s\n" "$1"; }
warn() { printf "${C_YLW}[!!]${C_RST} %s\n" "$1"; }
info() { printf "${C_BLU}[..]${C_RST} %s\n" "$1"; }
err()  { printf "${C_RED}[err]${C_RST} %s\n" "$1" >&2; }
step() { printf "\n${C_BOLD}%s${C_RST}\n\n" "$1"; }
ask()  { printf "${C_BLU}>${C_RST} %s " "$1"; }

# ── Fetch helper ──────────────────────────────────────────────────────────
_fetch_or_copy() {
  local src_name="$1" dst="$2"
  if [ -n "$SCRIPT_DIR" ] && [ -f "$SCRIPT_DIR/$src_name" ]; then
    cp "$SCRIPT_DIR/$src_name" "$dst"
    info "Installed $src_name from local clone"
  else
    info "Downloading $src_name..."
    if ! curl -fsSL "${REPO_RAW}/${src_name}" -o "$dst"; then
      err "Failed to download $src_name" && exit 1
    fi
  fi
  [ -s "$dst" ] || { err "$src_name is empty — download may have failed"; exit 1; }
}

# ── Banner ────────────────────────────────────────────────────────────────
printf "\n"
printf "${C_BOLD}  claudes${C_RST} — Claude Code preset picker\n"
printf "${C_DIM}  https://github.com/yigitkonur/claudes${C_RST}\n"
printf "\n"

# ── Prerequisites check ───────────────────────────────────────────────────
if ! command -v zsh &>/dev/null; then
  err "zsh is required (claudes is a zsh plugin). Install zsh first." && exit 1
fi

# ── Step 1: Install claudes.zsh ───────────────────────────────────────────
step "Step 1/4 — Core install"

mkdir -p "$INSTALL_DIR" "$CONFIG_DIR"
_fetch_or_copy "claudes.zsh" "$INSTALL_DIR/claudes.zsh"
ok "Script at $INSTALL_DIR/claudes.zsh"

if [ -d "$ZSHRC_D" ]; then
  ln -sf "$INSTALL_DIR/claudes.zsh" "$ZSHRC_D/90-claudes.zsh"
  ok "Linked to $ZSHRC_D/90-claudes.zsh"
else
  MARK="# claudes — https://github.com/yigitkonur/claudes"
  if grep -qF "$MARK" "$ZSHRC" 2>/dev/null; then
    ok "Already sourced from $ZSHRC"
  else
    printf '\n%s\n[ -f "%s/claudes.zsh" ] && source "%s/claudes.zsh"\n' \
      "$MARK" "$INSTALL_DIR" "$INSTALL_DIR" >> "$ZSHRC"
    ok "Appended to $ZSHRC"
  fi
fi

# ── Step 2: Enhanced UX ───────────────────────────────────────────────────
step "Step 2/4 — Enhanced UX"

printf "  The UX layer adds:\n"
printf "    • ${C_BOLD}Single-key picker${C_RST}  — press 1/2/3 or p/s/q, no Enter needed\n"
printf "    • ${C_BOLD}Enter default${C_RST}      — bare Enter picks your chosen default preset\n"
printf "    • ${C_BOLD}claude1..claude9${C_RST}  — jump straight to preset N from the CLI\n"
printf "    • ${C_BOLD}claude → claudes${C_RST}  — remap the \`claude\` command\n"
printf "\n"

ask "Install enhanced UX? [Y/n]:"
read -r want_ux
INSTALL_UX=1
[[ "${want_ux:l}" == "n" ]] && INSTALL_UX=0

UX_ORDER=""
UX_DEFAULT="standard"
UX_REMAP="warp"

if [ "$INSTALL_UX" -eq 1 ]; then
  # claude remap
  printf "\n  ${C_BOLD}Remap 'claude' → 'claudes'${C_RST}\n"
  printf "  Typing \`claude\` opens the preset picker instead of the raw CLI.\n\n"
  printf "    1) Warp only   ${C_DIM}(recommended — real \`claude\` still reachable elsewhere)${C_RST}\n"
  printf "    2) All terminals\n"
  printf "    3) None        ${C_DIM}(skip remap entirely)${C_RST}\n\n"
  ask "Remap [1]:"
  read -r remap_choice
  case "${remap_choice:-1}" in
    1|"") UX_REMAP=warp ;;
    2)    UX_REMAP=all  ;;
    3)    UX_REMAP=none ;;
    *)    warn "Invalid — defaulting to warp." ; UX_REMAP=warp ;;
  esac

  # Default preset
  printf "\n  ${C_BOLD}Default preset${C_RST} — which preset bare Enter selects:\n"
  printf "  ${C_DIM}Change any time: claudes config ux${C_RST}\n\n"
  ask "Default preset [standard]:"
  read -r def_preset
  [[ -n "$def_preset" ]] && UX_DEFAULT="$def_preset"

  _fetch_or_copy "ux.zsh" "$INSTALL_DIR/ux.zsh"
  ok "UX layer at $INSTALL_DIR/ux.zsh"

  if [ -d "$ZSHRC_D" ]; then
    ln -sf "$INSTALL_DIR/ux.zsh" "$ZSHRC_D/91-claudes-ux.zsh"
    ok "Linked to $ZSHRC_D/91-claudes-ux.zsh"
  else
    MARK2="# claudes-ux — https://github.com/yigitkonur/claudes"
    if ! grep -qF "$MARK2" "$ZSHRC" 2>/dev/null; then
      printf '\n%s\n[ -f "%s/ux.zsh" ] && source "%s/ux.zsh"\n' \
        "$MARK2" "$INSTALL_DIR" "$INSTALL_DIR" >> "$ZSHRC"
      ok "Appended ux.zsh to $ZSHRC"
    fi
  fi
fi

# ── Step 3: Preset scheme ─────────────────────────────────────────────────
step "Step 3/4 — Presets"

printf "  Choose a preset scheme:\n\n"
printf "    ${C_BOLD}1) Recommended${C_RST}  4-slot opinionated scheme:\n"
printf "       ${C_DIM}  plan     · Opus max + plan mode${C_RST}\n"
printf "       ${C_DIM}  max      · Opus max + skip permissions (yolo)${C_RST}\n"
printf "       ${C_DIM}  standard · Sonnet auto + skip permissions (daily)${C_RST}\n"
printf "       ${C_DIM}  quick    · Sonnet low + skip permissions (fast)${C_RST}\n\n"
printf "    ${C_BOLD}2) Built-in defaults${C_RST}  standard / quick / plan / research\n"
printf "    ${C_BOLD}3) Custom${C_RST}             configure presets interactively now\n"
printf "    ${C_BOLD}4) Skip${C_RST}               configure later via \`claudes config\`\n\n"

ask "Choice [1]:"
read -r preset_choice

case "${preset_choice:-1}" in
  1)
    mkdir -p "$CONFIG_DIR"
    cat > "$USER_PRESETS" <<'EOF'
# ~/.config/claudes/presets.zsh — recommended 4-slot preset scheme
# Edit manually or run: claudes config presets

# ── 1 · plan ─────── Opus · max effort · plan mode
CLAUDES_PRESETS[plan]="--model opus --effort max --permission-mode plan"
CLAUDES_DESCRIPTIONS[plan]="Opus 4.7 · max effort · plan mode"
CLAUDES_ALIASES[p]=plan

# ── 2 · max ──────── Opus · max effort · skip permissions (yolo)
CLAUDES_PRESETS[max]="--model opus --effort max --dangerously-skip-permissions"
CLAUDES_DESCRIPTIONS[max]="Opus 4.7 · max effort · skip permissions · yolo"
CLAUDES_ALIASES[m]=max

# ── 3 · standard ─── Sonnet · auto effort · skip permissions (daily driver)
CLAUDES_PRESETS[standard]="--model sonnet --dangerously-skip-permissions"
CLAUDES_DESCRIPTIONS[standard]="Sonnet 4.6 · auto effort · skip permissions · daily"
CLAUDES_ALIASES[s]=standard

# ── 4 · quick ────── Sonnet · low effort · skip permissions
CLAUDES_PRESETS[quick]="--model sonnet --effort low --dangerously-skip-permissions"
CLAUDES_DESCRIPTIONS[quick]="Sonnet 4.6 · low effort · skip permissions · fast/cheap"
CLAUDES_ALIASES[q]=quick

# Remove the built-in research preset (superseded by the scheme above)
unset "CLAUDES_PRESETS[research]" "CLAUDES_DESCRIPTIONS[research]" 2>/dev/null || true
EOF
    ok "Wrote recommended presets to $USER_PRESETS"
    UX_ORDER="plan max standard quick"
    ;;
  2)
    info "Keeping built-in defaults."
    ;;
  3)
    _fetch_or_copy "configure.sh" "$INSTALL_DIR/configure.sh"
    chmod +x "$INSTALL_DIR/configure.sh"
    info "Launching interactive preset configurator…"
    bash "$INSTALL_DIR/configure.sh" presets
    ;;
  4)
    info "Skipped. Edit $USER_PRESETS or run: claudes config"
    ;;
  *)
    warn "Unknown choice — keeping built-in defaults."
    ;;
esac

# ── Step 4: Finish up ────────────────────────────────────────────────────
step "Step 4/4 — Finishing up"

# Write ux-settings.zsh
if [ "$INSTALL_UX" -eq 1 ]; then
  mkdir -p "$CONFIG_DIR"
  {
    printf '# ~/.config/claudes/ux-settings.zsh — managed by: claudes config ux\n\n'
    [[ -n "$UX_ORDER" ]] && printf 'CLAUDES_ORDER=(%s)\n' "$UX_ORDER"
    printf 'CLAUDES_DEFAULT=%s\n' "$UX_DEFAULT"
    printf 'CLAUDES_REMAP_CLAUDE=%s\n' "$UX_REMAP"
  } > "$UX_SETTINGS"
  ok "UX settings at $UX_SETTINGS"
fi

# Always install configure.sh so `claudes config` works
_fetch_or_copy "configure.sh" "$INSTALL_DIR/configure.sh"
chmod +x "$INSTALL_DIR/configure.sh"
ok "configure.sh at $INSTALL_DIR/configure.sh"

# ── Summary ───────────────────────────────────────────────────────────────
printf "\n${C_GRN}${C_BOLD}  Done!${C_RST}\n\n"
printf "  Restart shell or:  ${C_DIM}exec zsh${C_RST}\n"
printf "  Open picker:       ${C_DIM}claudes${C_RST}"
[ "$INSTALL_UX" -eq 1 ] && [[ "$UX_REMAP" != "none" ]] && printf " ${C_DIM}(or just: claude)${C_RST}"
printf "\n"
printf "  List presets:      ${C_DIM}claudes list${C_RST}\n"
printf "  Manage presets:    ${C_DIM}claudes config${C_RST}\n"
printf "\n"
