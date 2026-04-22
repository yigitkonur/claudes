#!/usr/bin/env bash
# configure.sh — Interactive preset & UX manager for claudes
#
# Usage (standalone):    bash configure.sh [presets|ux]
# Usage (via claudes):   claudes config [presets|ux]
#
# Manages two files:
#   ~/.config/claudes/presets.zsh      — user preset definitions
#   ~/.config/claudes/ux-settings.zsh  — order, default, remap settings

set -euo pipefail

CONFIG_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/claudes"
USER_PRESETS="$CONFIG_DIR/presets.zsh"
UX_SETTINGS="$CONFIG_DIR/ux-settings.zsh"
INSTALL_DIR="$HOME/.local/share/claudes"

# ── Colour helpers ────────────────────────────────────────────────────────
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
hdr()  { printf "\n${C_BOLD}%s${C_RST}\n\n" "$1"; }
prompt() { printf "${C_BLU}>${C_RST} %s " "$1"; }

# ── Parse presets.zsh ─────────────────────────────────────────────────────
# Returns list of user-defined preset names (keys in CLAUDES_PRESETS that
# appear in presets.zsh, i.e. not the built-ins from claudes.zsh).
_cfg_preset_names() {
  [[ -f "$USER_PRESETS" ]] || return 0
  grep '^CLAUDES_PRESETS\[' "$USER_PRESETS" \
    | sed 's/^CLAUDES_PRESETS\[\([^]]*\)\].*/\1/' \
    | grep -v '^$' || true
}

_cfg_preset_flags() {   # $1 = name
  [[ -f "$USER_PRESETS" ]] || { echo ""; return; }
  grep "^CLAUDES_PRESETS\[$1\]=" "$USER_PRESETS" \
    | sed 's/^CLAUDES_PRESETS\[[^]]*\]="//;s/"$//' | head -1 || echo ""
}

_cfg_preset_desc() {   # $1 = name
  [[ -f "$USER_PRESETS" ]] || { echo ""; return; }
  grep "^CLAUDES_DESCRIPTIONS\[$1\]=" "$USER_PRESETS" \
    | sed 's/^CLAUDES_DESCRIPTIONS\[[^]]*\]="//;s/"$//' | head -1 || echo ""
}

_cfg_preset_alias() {   # $1 = name
  [[ -f "$USER_PRESETS" ]] || { echo ""; return; }
  grep "^CLAUDES_ALIASES\[.\]=$1$" "$USER_PRESETS" \
    | sed 's/^CLAUDES_ALIASES\[\(.\)\].*/\1/' | head -1 || echo ""
}

_cfg_all_preset_names() {
  # All presets (built-ins + user), via zsh
  if [[ -f "$INSTALL_DIR/claudes.zsh" ]]; then
    zsh -c "
      source '$INSTALL_DIR/claudes.zsh' 2>/dev/null
      [[ -f '$USER_PRESETS' ]] && source '$USER_PRESETS' 2>/dev/null
      for k in \${(ko)CLAUDES_PRESETS}; do printf '%s\n' \"\$k\"; done
    " 2>/dev/null || true
  fi
}

# ── UX settings reader ────────────────────────────────────────────────────
_cfg_ux_order() {
  [[ -f "$UX_SETTINGS" ]] || { echo ""; return; }
  grep '^CLAUDES_ORDER=' "$UX_SETTINGS" \
    | sed 's/^CLAUDES_ORDER=(\(.*\))/\1/' | head -1 || echo ""
}

_cfg_ux_default() {
  [[ -f "$UX_SETTINGS" ]] || { echo "standard"; return; }
  grep '^CLAUDES_DEFAULT=' "$UX_SETTINGS" \
    | sed 's/^CLAUDES_DEFAULT=//' | tr -d '"'"'" | head -1 || echo "standard"
}

_cfg_ux_remap() {
  [[ -f "$UX_SETTINGS" ]] || { echo "warp"; return; }
  grep '^CLAUDES_REMAP_CLAUDE=' "$UX_SETTINGS" \
    | sed 's/^CLAUDES_REMAP_CLAUDE=//' | tr -d '"'"'" | head -1 || echo "warp"
}

# ── Writers ───────────────────────────────────────────────────────────────
# We keep a structured comment block at the top and emit each preset as a
# clean block. We only write what the user explicitly configured — built-ins
# live in claudes.zsh.

_cfg_write_presets() {
  # $@ = lines of the form: NAME|FLAGS|DESC|ALIAS (pipe-separated)
  mkdir -p "$CONFIG_DIR"
  local tmp; tmp="$(mktemp)"

  cat > "$tmp" <<'HEADER'
# ~/.config/claudes/presets.zsh — user presets managed by `claudes config`
# Edit manually or run: claudes config presets
#
# Tip: built-in presets (standard, quick, plan, research) live in claudes.zsh.
# Add new presets or OVERRIDE built-ins here.

HEADER

  # Unset built-ins that user wants to override (if they appear in our list)
  local has_unset=0
  for entry in "$@"; do
    local name; name="${entry%%|*}"
    for builtin in standard quick plan research; do
      if [[ "$name" == "$builtin" ]]; then
        has_unset=1
        break
      fi
    done
  done

  for entry in "$@"; do
    IFS='|' read -r name flags desc alias_char <<< "$entry"
    printf 'CLAUDES_PRESETS[%s]="%s"\n' "$name" "$flags" >> "$tmp"
    [[ -n "$desc" ]] && printf 'CLAUDES_DESCRIPTIONS[%s]="%s"\n' "$name" "$desc" >> "$tmp"
    [[ -n "$alias_char" ]] && printf 'CLAUDES_ALIASES[%s]=%s\n' "$alias_char" "$name" >> "$tmp"
    printf '\n' >> "$tmp"
  done

  mv "$tmp" "$USER_PRESETS"
  ok "Wrote $USER_PRESETS"
}

_cfg_write_ux() {
  # $1=order (space-sep), $2=default, $3=remap
  mkdir -p "$CONFIG_DIR"
  local order="$1" default="$2" remap="$3"
  local tmp; tmp="$(mktemp)"

  cat > "$tmp" <<HEADER
# ~/.config/claudes/ux-settings.zsh — managed by \`claudes config ux\`
# Edit manually or run: claudes config ux

HEADER

  if [[ -n "$order" ]]; then
    printf 'CLAUDES_ORDER=(%s)\n' "$order" >> "$tmp"
  fi
  printf 'CLAUDES_DEFAULT=%s\n' "$default" >> "$tmp"
  printf 'CLAUDES_REMAP_CLAUDE=%s\n' "$remap" >> "$tmp"

  mv "$tmp" "$UX_SETTINGS"
  ok "Wrote $UX_SETTINGS"
}

# ── Flag builder helpers ──────────────────────────────────────────────────
_cfg_pick_model() {
  hdr "Model"
  printf "    1) sonnet  — Sonnet 4.6 (fast, daily driver)\n"
  printf "    2) opus    — Opus 4.7 (smartest, slower)\n"
  printf "    3) haiku   — Haiku 4.5 (cheapest, fastest)\n\n"
  while true; do
    prompt "Choice [1-3]:"
    read -r m
    case "$m" in
      1) echo "sonnet"; return ;;
      2) echo "opus";   return ;;
      3) echo "haiku";  return ;;
      *) err "Enter 1, 2, or 3." ;;
    esac
  done
}

_cfg_pick_effort() {
  hdr "Effort / reasoning"
  printf "    1) auto   — Claude decides (omit --effort flag)\n"
  printf "    2) low    — fast, minimal reasoning\n"
  printf "    3) medium\n"
  printf "    4) high\n"
  printf "    5) max    — slowest, deepest reasoning\n\n"
  while true; do
    prompt "Choice [1-5]:"
    read -r e
    case "$e" in
      1) echo ""; return ;;
      2) echo "--effort low";    return ;;
      3) echo "--effort medium"; return ;;
      4) echo "--effort high";   return ;;
      5) echo "--effort max";    return ;;
      *) err "Enter 1-5." ;;
    esac
  done
}

_cfg_pick_mode() {
  hdr "Permission mode"
  printf "    1) default          — normal approvals\n"
  printf "    2) skip (yolo)      — --dangerously-skip-permissions\n"
  printf "    3) plan             — plan-only, no execution\n"
  printf "    4) acceptEdits      — auto-accept file edits, approve shell\n\n"
  while true; do
    prompt "Choice [1-4]:"
    read -r p
    case "$p" in
      1) echo "";                                      return ;;
      2) echo "--dangerously-skip-permissions";        return ;;
      3) echo "--permission-mode plan";                return ;;
      4) echo "--permission-mode acceptEdits";         return ;;
      *) err "Enter 1-4." ;;
    esac
  done
}

_cfg_build_flags() {
  # Interactive flag builder. Echoes the final flags string.
  local model effort mode
  model=$(_cfg_pick_model)
  effort=$(_cfg_pick_effort)
  mode=$(_cfg_pick_mode)

  local flags="--model $model"
  [[ -n "$effort" ]] && flags+=" $effort"
  [[ -n "$mode"   ]] && flags+=" $mode"
  echo "$flags"
}

_cfg_auto_desc() {
  # $1=model $2=flags — generate a description from flags
  local model effort_label mode_label
  case "$1" in
    sonnet) model="Sonnet 4.6" ;;
    opus)   model="Opus 4.7"   ;;
    haiku)  model="Haiku 4.5"  ;;
    *)      model="$1"         ;;
  esac
  if echo "$2" | grep -q '\-\-effort'; then
    local ev; ev=$(echo "$2" | grep -o '\-\-effort [^ ]*' | awk '{print $2}')
    effort_label="$ev effort"
  else
    effort_label="auto effort"
  fi
  if echo "$2" | grep -q 'dangerously-skip'; then
    mode_label="skip permissions"
  elif echo "$2" | grep -q 'plan'; then
    mode_label="plan mode"
  elif echo "$2" | grep -q 'acceptEdits'; then
    mode_label="accept edits"
  else
    mode_label="default mode"
  fi
  echo "$model · $effort_label · $mode_label"
}

# ── Preset management ─────────────────────────────────────────────────────
_cfg_show_user_presets() {
  local names=()
  while IFS= read -r n; do [[ -n "$n" ]] && names+=("$n"); done < <(_cfg_preset_names)
  if [[ ${#names[@]} -eq 0 ]]; then
    printf "    ${C_DIM}(no user presets — built-ins from claudes.zsh are active)${C_RST}\n"
    return
  fi
  local i=1
  for name in "${names[@]}"; do
    local flags desc alias_char
    flags=$(_cfg_preset_flags "$name")
    desc=$(_cfg_preset_desc "$name")
    alias_char=$(_cfg_preset_alias "$name")
    local label="$name"
    [[ -n "$alias_char" ]] && label="$name ($alias_char)"
    printf "    %d) %-20s %s\n" "$i" "$label" "${C_DIM}$flags${C_RST}"
    [[ -n "$desc" ]] && printf "       %-20s ${C_DIM}%s${C_RST}\n" "" "$desc"
    ((i++))
  done
}

cmd_presets() {
  while true; do
    hdr "Preset manager"
    printf "  ${C_DIM}User presets (from $USER_PRESETS):${C_RST}\n\n"
    _cfg_show_user_presets
    printf "\n"
    printf "    a) Add preset\n"
    printf "    e) Edit preset\n"
    printf "    r) Remove preset\n"
    printf "    q) Back / quit\n\n"
    prompt "Choice:"
    read -r action

    case "${action:l}" in
      a) _action_add_preset ;;
      e) _action_edit_preset ;;
      r) _action_remove_preset ;;
      q|"") return 0 ;;
      *) warn "Unknown choice." ;;
    esac
  done
}

_action_add_preset() {
  hdr "Add preset"

  prompt "Preset name (e.g. 'myfast'):"
  read -r name
  if [[ -z "$name" ]]; then warn "Cancelled."; return; fi
  if _cfg_preset_flags "$name" | grep -q '.'; then
    warn "Preset '$name' already exists. Use Edit to change it."
    return
  fi

  local flags
  flags=$(_cfg_build_flags)

  local auto_desc model
  model=$(echo "$flags" | grep -o '\-\-model [^ ]*' | awk '{print $2}')
  auto_desc=$(_cfg_auto_desc "$model" "$flags")

  printf "\n  Auto-description: ${C_DIM}%s${C_RST}\n" "$auto_desc"
  prompt "Custom description [enter to keep]:"
  read -r desc
  [[ -z "$desc" ]] && desc="$auto_desc"

  prompt "Single-char alias [enter to skip]:"
  read -r alias_char
  [[ ${#alias_char} -gt 1 ]] && alias_char="${alias_char:0:1}" && warn "Using first char: $alias_char"

  printf "\n  Preview:\n"
  printf "    CLAUDES_PRESETS[%s]=\"%s\"\n" "$name" "$flags"
  printf "    CLAUDES_DESCRIPTIONS[%s]=\"%s\"\n" "$name" "$desc"
  [[ -n "$alias_char" ]] && printf "    CLAUDES_ALIASES[%s]=%s\n" "$alias_char" "$name"
  printf "\n"
  prompt "Save? [Y/n]:"
  read -r confirm
  [[ "${confirm:l}" == "n" ]] && warn "Cancelled." && return

  # Load existing, append, rewrite
  local -a entries=()
  while IFS= read -r n; do
    [[ -z "$n" ]] && continue
    local ef ed ea
    ef=$(_cfg_preset_flags "$n")
    ed=$(_cfg_preset_desc "$n")
    ea=$(_cfg_preset_alias "$n")
    entries+=("$n|$ef|$ed|$ea")
  done < <(_cfg_preset_names)
  entries+=("$name|$flags|$desc|$alias_char")
  _cfg_write_presets "${entries[@]}"
}

_action_edit_preset() {
  local names=()
  while IFS= read -r n; do [[ -n "$n" ]] && names+=("$n"); done < <(_cfg_preset_names)
  if [[ ${#names[@]} -eq 0 ]]; then warn "No user presets to edit."; return; fi

  hdr "Edit preset"
  local i=1
  for n in "${names[@]}"; do printf "    %d) %s\n" "$i" "$n"; ((i++)); done
  printf "\n"
  prompt "Preset number:"
  read -r idx
  if ! [[ "$idx" =~ ^[0-9]+$ ]] || (( idx < 1 || idx > ${#names[@]} )); then
    err "Invalid number."; return
  fi
  local name="${names[$((idx-1))]}"

  printf "\n  Editing '%s' — press Enter to rebuild flags interactively.\n\n" "$name"
  prompt "Rebuild flags interactively? [Y/n]:"
  read -r rebuild

  local flags desc alias_char
  if [[ "${rebuild:l}" == "n" ]]; then
    flags=$(_cfg_preset_flags "$name")
    printf "  Current flags: ${C_DIM}%s${C_RST}\n" "$flags"
    prompt "New flags [enter to keep]:"
    read -r new_flags
    [[ -n "$new_flags" ]] && flags="$new_flags"
  else
    flags=$(_cfg_build_flags)
  fi

  desc=$(_cfg_preset_desc "$name")
  printf "\n  Current description: ${C_DIM}%s${C_RST}\n" "$desc"
  prompt "New description [enter to keep]:"
  read -r new_desc
  [[ -n "$new_desc" ]] && desc="$new_desc"

  alias_char=$(_cfg_preset_alias "$name")
  printf "\n  Current alias: ${C_DIM}%s${C_RST}\n" "${alias_char:-(none)}"
  prompt "New alias [enter to keep, - to clear]:"
  read -r new_alias
  if [[ "$new_alias" == "-" ]]; then
    alias_char=""
  elif [[ -n "$new_alias" ]]; then
    alias_char="${new_alias:0:1}"
  fi

  # Rewrite with updated entry
  local -a entries=()
  for n in "${names[@]}"; do
    if [[ "$n" == "$name" ]]; then
      entries+=("$name|$flags|$desc|$alias_char")
    else
      local ef ed ea
      ef=$(_cfg_preset_flags "$n")
      ed=$(_cfg_preset_desc "$n")
      ea=$(_cfg_preset_alias "$n")
      entries+=("$n|$ef|$ed|$ea")
    fi
  done
  _cfg_write_presets "${entries[@]}"
}

_action_remove_preset() {
  local names=()
  while IFS= read -r n; do [[ -n "$n" ]] && names+=("$n"); done < <(_cfg_preset_names)
  if [[ ${#names[@]} -eq 0 ]]; then warn "No user presets to remove."; return; fi

  hdr "Remove preset"
  local i=1
  for n in "${names[@]}"; do printf "    %d) %s\n" "$i" "$n"; ((i++)); done
  printf "\n"
  prompt "Preset number to remove:"
  read -r idx
  if ! [[ "$idx" =~ ^[0-9]+$ ]] || (( idx < 1 || idx > ${#names[@]} )); then
    err "Invalid number."; return
  fi
  local name="${names[$((idx-1))]}"
  prompt "Remove '$name'? [y/N]:"
  read -r confirm
  [[ "${confirm:l}" != "y" ]] && warn "Cancelled." && return

  local -a entries=()
  for n in "${names[@]}"; do
    [[ "$n" == "$name" ]] && continue
    local ef ed ea
    ef=$(_cfg_preset_flags "$n")
    ed=$(_cfg_preset_desc "$n")
    ea=$(_cfg_preset_alias "$n")
    entries+=("$n|$ef|$ed|$ea")
  done

  if [[ ${#entries[@]} -eq 0 ]]; then
    # File would be empty — just write header
    mkdir -p "$CONFIG_DIR"
    printf '# ~/.config/claudes/presets.zsh\n' > "$USER_PRESETS"
    ok "Removed '$name'. No user presets remaining."
  else
    _cfg_write_presets "${entries[@]}"
  fi
}

# ── UX settings ───────────────────────────────────────────────────────────
cmd_ux() {
  local order default remap
  order=$(_cfg_ux_order)
  default=$(_cfg_ux_default)
  remap=$(_cfg_ux_remap)

  hdr "UX settings"
  printf "  Current:\n"
  printf "    Order:   ${C_DIM}%s${C_RST}\n" "${order:-(alphabetical)}"
  printf "    Default: ${C_DIM}%s${C_RST}\n" "$default"
  printf "    Remap:   ${C_DIM}%s${C_RST}\n\n" "$remap"

  # Picker order
  printf "  ${C_BOLD}Picker order${C_RST} — space-separated preset names (Enter to keep current):\n"
  printf "  ${C_DIM}Example: plan max standard quick${C_RST}\n"
  prompt "Order [$order]:"
  read -r new_order
  [[ -n "$new_order" ]] && order="$new_order"

  # Default preset
  printf "\n  ${C_BOLD}Default preset${C_RST} — which preset bare Enter selects:\n"
  prompt "Default [$default]:"
  read -r new_default
  [[ -n "$new_default" ]] && default="$new_default"

  # Remap
  printf "\n  ${C_BOLD}Remap 'claude' → 'claudes'${C_RST}\n"
  printf "    1) warp  — only inside Warp terminal ${C_DIM}(recommended)${C_RST}\n"
  printf "    2) all   — in every terminal\n"
  printf "    3) none  — never (keep real claude CLI)\n\n"
  local remap_n
  case "$remap" in warp) remap_n=1 ;; all) remap_n=2 ;; *) remap_n=3 ;; esac
  prompt "Remap [$remap_n]:"
  read -r r
  case "$r" in
    1) remap=warp ;;
    2) remap=all  ;;
    3) remap=none ;;
    "") ;; # keep
    *) warn "Invalid — keeping '$remap'." ;;
  esac

  _cfg_write_ux "$order" "$default" "$remap"
  printf "\n  ${C_DIM}Restart your shell (or: source ~/.zshrc.d/91-claudes-ux.zsh) to apply.${C_RST}\n"
}

# ── Main menu ─────────────────────────────────────────────────────────────
cmd_main() {
  hdr "claudes config"
  printf "    1) Manage presets\n"
  printf "    2) UX settings (order, default, remap)\n"
  printf "    q) Quit\n\n"
  prompt "Choice:"
  read -r choice
  case "${choice:l}" in
    1|presets) cmd_presets ;;
    2|ux)      cmd_ux ;;
    q|"")      return 0 ;;
    *) warn "Unknown choice." ;;
  esac
}

# ── Entry point ───────────────────────────────────────────────────────────
case "${1:-}" in
  presets) cmd_presets ;;
  ux)      cmd_ux ;;
  *)       cmd_main ;;
esac
