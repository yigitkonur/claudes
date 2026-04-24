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
CLAUDES_YAML="$CONFIG_DIR/claudes.yaml"
CACHE="$CONFIG_DIR/.claudes-cache.zsh"

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
  local src="$1" dst="$2"
  if [ -n "$SCRIPT_DIR" ] && [ -f "$SCRIPT_DIR/$src" ]; then
    cp "$SCRIPT_DIR/$src" "$dst"
    info "Installed $src from local clone"
  else
    info "Downloading $src..."
    curl -fsSL "${REPO_RAW}/${src}" -o "$dst" || { err "Failed to download $src"; exit 1; }
  fi
  [ -s "$dst" ] || { err "$src is empty — download may have failed"; exit 1; }
}

# ── Banner ────────────────────────────────────────────────────────────────
printf "\n"
printf "${C_BOLD}  claudes${C_RST} — Claude Code preset picker\n"
printf "${C_DIM}  https://github.com/yigitkonur/claudes${C_RST}\n\n"

if ! command -v zsh &>/dev/null; then
  err "zsh is required. Install zsh first." && exit 1
fi
if ! command -v python3 &>/dev/null; then
  err "python3 is required. Install python3 first." && exit 1
fi

# ── Step 1: Core install ──────────────────────────────────────────────────
step "Step 1/4 — Core install"

mkdir -p "$INSTALL_DIR" "$CONFIG_DIR"

_fetch_or_copy "claudes.zsh"   "$INSTALL_DIR/claudes.zsh"
_fetch_or_copy "yaml2sh.py"    "$INSTALL_DIR/yaml2sh.py"
_fetch_or_copy "configure.sh"  "$INSTALL_DIR/configure.sh"
_fetch_or_copy "test.sh"       "$INSTALL_DIR/test.sh"
chmod +x "$INSTALL_DIR/configure.sh" "$INSTALL_DIR/test.sh"
ok "Scripts at $INSTALL_DIR/"

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

# ── Migrate old format (if present) ──────────────────────────────────────
OLD_PRESETS="$CONFIG_DIR/presets.zsh"
OLD_UX="$CONFIG_DIR/ux-settings.zsh"
if [ -f "$OLD_PRESETS" ] || [ -f "$OLD_UX" ]; then
  warn "Old config files found (.zsh format)."
  ask "Migrate to claudes.yaml? [Y/n]:"; read -r do_migrate
  if [[ "${do_migrate:l}" != "n" ]]; then
    python3 - "$OLD_PRESETS" "$OLD_UX" "$CLAUDES_YAML" "$INSTALL_DIR/yaml2sh.py" <<'PYEOF'
import sys, os, subprocess, json

old_presets, old_ux, yaml_out, y2sh = sys.argv[1:]
data = {'ux': {}, 'presets': {}, 'remove_builtins': []}

# Load old presets via zsh
if os.path.exists(old_presets):
    r = subprocess.run(
        ['zsh', '-c', 'source "%s"; for k in ${(ko)CLAUDES_PRESETS}; do printf "PRESET\t%s\t%s\n" "$k" "${CLAUDES_PRESETS[$k]}"; done; for k in ${(ko)CLAUDES_DESCRIPTIONS}; do printf "DESC\t%s\t%s\n" "$k" "${CLAUDES_DESCRIPTIONS[$k]}"; done; for k in ${(ko)CLAUDES_ALIASES}; do printf "ALIAS\t%s\t%s\n" "$k" "${CLAUDES_ALIASES[$k]}"; done' % old_presets],
        capture_output=True, text=True)
    for line in r.stdout.splitlines():
        parts = line.split('\t', 2)
        if len(parts) < 3: continue
        kind, key, val = parts
        if kind == 'PRESET':
            if key not in data['presets']: data['presets'][key] = {}
            data['presets'][key]['flags'] = val
        elif kind == 'DESC':
            if key not in data['presets']: data['presets'][key] = {}
            data['presets'][key]['description'] = val
        elif kind == 'ALIAS':
            if val not in data['presets']: data['presets'][val] = {}
            data['presets'][val]['alias'] = key

# Load old ux settings via zsh
if os.path.exists(old_ux):
    r = subprocess.run(
        ['zsh', '-c', 'source "%s"; echo "ORDER:${CLAUDES_ORDER[*]:-}"; echo "DEFAULT:${CLAUDES_DEFAULT:-standard}"; echo "REMAP:${CLAUDES_REMAP_CLAUDE:-warp}"' % old_ux],
        capture_output=True, text=True)
    for line in r.stdout.splitlines():
        if line.startswith('ORDER:'):
            v = line[6:].strip()
            if v: data['ux']['order'] = v.split()
        elif line.startswith('DEFAULT:'):
            data['ux']['default'] = line[8:].strip() or 'standard'
        elif line.startswith('REMAP:'):
            data['ux']['remap'] = line[6:].strip() or 'warp'

# Write YAML
import importlib.util
spec = importlib.util.spec_from_file_location("yaml2sh", y2sh)
mod = importlib.util.module_from_spec(spec)
spec.loader.exec_module(mod)

lines = ["# ~/.config/claudes/claudes.yaml — migrated from old .zsh format", ""]
lines.append("ux:")
order = data['ux'].get('order') or []
if order:
    lines.append("  order: [%s]" % ', '.join(order))
lines.append("  default: %s" % (data['ux'].get('default') or 'standard'))
lines.append("  remap: %s" % (data['ux'].get('remap') or 'warp'))
lines.append("")
lines.append("presets:")
for name, cfg in data['presets'].items():
    lines.append("  %s:" % name)
    if cfg.get('flags'):       lines.append('    flags: "%s"' % cfg['flags'])
    if cfg.get('description'): lines.append('    description: "%s"' % cfg['description'])
    if cfg.get('alias'):       lines.append('    alias: %s' % cfg['alias'])
    lines.append("")
lines.append("remove_builtins: []")

with open(yaml_out, 'w') as f:
    f.write('\n'.join(lines))
print("migrated")
PYEOF
    ok "Migrated to $CLAUDES_YAML"
    info "Keeping old files as backup — remove manually: rm $OLD_PRESETS $OLD_UX"
  fi
fi

# ── Step 2: Enhanced UX ───────────────────────────────────────────────────
step "Step 2/4 — Enhanced UX"

printf "  The UX layer adds:\n"
printf "    • ${C_BOLD}Single-key picker${C_RST}  — 1/2/3 or p/s/q, no Enter needed\n"
printf "    • ${C_BOLD}Enter default${C_RST}      — bare Enter picks your chosen default\n"
printf "    • ${C_BOLD}claude1..claude9${C_RST}  — jump to preset N from the CLI\n"
printf "    • ${C_BOLD}claude → claudes${C_RST}  — remap the \`claude\` command\n\n"

ask "Install enhanced UX? [Y/n]:"; read -r want_ux
INSTALL_UX=1; [[ "${want_ux:l}" == "n" ]] && INSTALL_UX=0

UX_ORDER="" UX_DEFAULT="standard" UX_REMAP="warp"

if [ "$INSTALL_UX" -eq 1 ]; then
  printf "\n  ${C_BOLD}Remap 'claude' → 'claudes'${C_RST}\n\n"
  printf "    1) Warp only   ${C_DIM}(recommended)${C_RST}\n"
  printf "    2) All terminals\n"
  printf "    3) None\n\n"
  ask "Remap [1]:"; read -r rc
  case "${rc:-1}" in
    1|"") UX_REMAP=warp ;; 2) UX_REMAP=all ;; 3) UX_REMAP=none ;;
    *) warn "Defaulting to warp."; UX_REMAP=warp ;;
  esac

  printf "\n  ${C_BOLD}Default preset${C_RST} — bare Enter selects:\n"
  ask "Default [standard]:"; read -r dp
  [[ -n "$dp" ]] && UX_DEFAULT="$dp"

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

# ── Step 3: Presets ───────────────────────────────────────────────────────
step "Step 3/4 — Presets"

# Skip if we already migrated or YAML already exists
if [ -f "$CLAUDES_YAML" ]; then
  ok "Using existing $CLAUDES_YAML"
else
  printf "  Choose a preset scheme:\n\n"
  printf "    ${C_BOLD}1) Recommended${C_RST}  4-slot scheme:\n"
  printf "       ${C_DIM}  plan     · Opus max + plan mode${C_RST}\n"
  printf "       ${C_DIM}  max      · Opus max + skip permissions (yolo)${C_RST}\n"
  printf "       ${C_DIM}  standard · Sonnet auto + skip permissions (daily)${C_RST}\n"
  printf "       ${C_DIM}  quick    · Sonnet low + skip permissions (fast)${C_RST}\n\n"
  printf "    ${C_BOLD}2) Built-in defaults${C_RST}  standard / quick / plan / research\n"
  printf "    ${C_BOLD}3) Custom${C_RST}             configure interactively now\n"
  printf "    ${C_BOLD}4) Skip${C_RST}               configure later via \`claudes config\`\n\n"

  ask "Choice [1]:"; read -r pc
  case "${pc:-1}" in
    1)
      UX_ORDER="plan max standard quick"
      mkdir -p "$CONFIG_DIR"
      cat > "$CLAUDES_YAML" <<'EOF'
# ~/.config/claudes/claudes.yaml
# edit directly or run: claudes config

ux:
  order: [plan, max, standard, quick]
  default: standard
  remap: warp  # warp | all | none

presets:
  plan:
    flags: "--model opus[1m] --effort max --permission-mode plan"
    description: "Opus 4.7 · 1M ctx · max effort · plan mode"
    alias: p

  max:
    flags: "--model opus[1m] --effort max --dangerously-skip-permissions"
    description: "Opus 4.7 · 1M ctx · max effort · skip permissions · yolo"
    alias: m

  standard:
    flags: "--model sonnet --dangerously-skip-permissions"
    description: "Sonnet 4.6 · auto effort · skip permissions · daily"
    alias: s

  quick:
    flags: "--model sonnet --effort low --dangerously-skip-permissions"
    description: "Sonnet 4.6 · low effort · skip permissions · fast/cheap"
    alias: q

remove_builtins: [research]
EOF
      ok "Wrote recommended presets to $CLAUDES_YAML"
      ;;
    2) info "Keeping built-in defaults." ;;
    3)
      info "Launching interactive preset configurator…"
      bash "$INSTALL_DIR/configure.sh" presets
      ;;
    4) info "Skipped. Edit $CLAUDES_YAML or run: claudes config" ;;
    *) warn "Unknown choice — keeping built-in defaults." ;;
  esac
fi

# ── Step 4: Finish ────────────────────────────────────────────────────────
step "Step 4/4 — Finishing up"

# Merge UX settings into YAML (only if UX layer was installed and YAML exists)
if [ "$INSTALL_UX" -eq 1 ] && [ -f "$CLAUDES_YAML" ]; then
  python3 - "$CLAUDES_YAML" "$UX_ORDER" "$UX_DEFAULT" "$UX_REMAP" <<'PYEOF'
import sys, json, os

yaml_path, order_str, default, remap = sys.argv[1:]

# Read file, patch/add ux section
with open(yaml_path, 'r') as f:
    content = f.read()

# Find and update ux block using simple text replacement
import re

order_val = "  order: [%s]" % order_str if order_str else None
default_val = "  default: %s" % default
remap_val = "  remap: %s  # warp | all | none" % remap

if 'ux:' in content:
    # Replace existing default/remap lines
    content = re.sub(r'^  default: .*$', default_val, content, flags=re.MULTILINE)
    content = re.sub(r'^  remap: .*$', remap_val, content, flags=re.MULTILINE)
    if order_str:
        if re.search(r'^  order:', content, re.MULTILINE):
            content = re.sub(r'^  order: .*$', order_val, content, flags=re.MULTILINE)
        else:
            content = content.replace('ux:\n', 'ux:\n' + order_val + '\n')
else:
    ux_block = "ux:\n"
    if order_str: ux_block += order_val + "\n"
    ux_block += default_val + "\n"
    ux_block += remap_val + "\n\n"
    content = ux_block + content

with open(yaml_path, 'w') as f:
    f.write(content)
PYEOF
  ok "UX settings merged into $CLAUDES_YAML"
fi

# Warm the cache
if [ -f "$CLAUDES_YAML" ]; then
  python3 "$INSTALL_DIR/yaml2sh.py" "$CLAUDES_YAML" > "$CACHE" && ok "Cache warmed: $CACHE"
fi

# ── Summary ───────────────────────────────────────────────────────────────
printf "\n${C_GRN}${C_BOLD}  Done!${C_RST}\n\n"
printf "  Restart shell or:  ${C_DIM}exec zsh${C_RST}\n"
printf "  Open picker:       ${C_DIM}claudes${C_RST}"
[ "$INSTALL_UX" -eq 1 ] && [[ "$UX_REMAP" != "none" ]] && printf " ${C_DIM}(or: claude)${C_RST}"
printf "\n"
printf "  List presets:      ${C_DIM}claudes list${C_RST}\n"
printf "  Manage presets:    ${C_DIM}claudes config${C_RST}\n"
printf "  Config file:       ${C_DIM}%s${C_RST}\n" "$CLAUDES_YAML"
printf "\n"
