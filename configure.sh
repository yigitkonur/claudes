#!/usr/bin/env bash
# configure.sh — Interactive preset & UX manager for claudes
#
# Usage (standalone):    bash configure.sh [presets|ux]
# Usage (via claudes):   claudes config [presets|ux]
#
# Manages: ~/.config/claudes/claudes.yaml

set -euo pipefail

CONFIG_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/claudes"
CLAUDES_YAML="$CONFIG_DIR/claudes.yaml"
INSTALL_DIR="$HOME/.local/share/claudes"
Y2SH="$INSTALL_DIR/yaml2sh.py"
CACHE="$CONFIG_DIR/.claudes-cache.zsh"

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
hdr()  { printf "\n${C_BOLD}%s${C_RST}\n\n" "$1"; }
ask()  { printf "${C_BLU}>${C_RST} %s " "$1"; }

# ── Require yaml2sh.py ────────────────────────────────────────────────────
if [ ! -f "$Y2SH" ]; then
  err "yaml2sh.py not found at $Y2SH"
  err "Re-run: curl -fsSL https://raw.githubusercontent.com/yigitkonur/claudes/main/install.sh | bash"
  exit 1
fi

# ── YAML read/write via python3 ───────────────────────────────────────────
_yaml_get_json() {
  [ -f "$CLAUDES_YAML" ] || echo '{}'
  python3 "$Y2SH" --json "$CLAUDES_YAML" 2>/dev/null || echo '{}'
}

_yaml_write() {
  # Rewrites claudes.yaml from a python3 data dict passed as JSON on stdin.
  local json_in="$1"
  mkdir -p "$CONFIG_DIR"
  python3 - "$CLAUDES_YAML" "$json_in" <<'PYEOF'
import sys, json, os

path = sys.argv[1]
data = json.loads(sys.argv[2])

lines = ["# ~/.config/claudes/claudes.yaml", "# edit directly or run: claudes config", ""]

ux = data.get('ux') or {}
lines.append("ux:")
order = ux.get('order') or []
if order:
    lines.append("  order: [%s]" % ', '.join(order))
lines.append("  default: %s" % (ux.get('default') or 'standard'))
lines.append("  remap: %s  # warp | all | none" % (ux.get('remap') or 'warp'))
lines.append("")

lines.append("presets:")
presets = data.get('presets') or {}
if not presets:
    lines.append("  # no user presets — built-ins (standard, quick, plan, research) are active")
for name, cfg in presets.items():
    if not isinstance(cfg, dict):
        continue
    lines.append("  %s:" % name)
    if cfg.get('flags'):
        lines.append('    flags: "%s"' % cfg['flags'].replace('"', '\\"'))
    if cfg.get('description'):
        lines.append('    description: "%s"' % cfg['description'].replace('"', '\\"'))
    if cfg.get('alias'):
        lines.append('    alias: %s' % cfg['alias'])
    if cfg.get('prompt'):
        lines.append('    prompt: "%s"' % cfg['prompt'].replace('"', '\\"'))
    if cfg.get('mcp'):
        lines.append('    mcp: "%s"' % cfg['mcp'])
    env = cfg.get('env')
    if env and isinstance(env, dict):
        lines.append('    env:')
        for k, v in env.items():
            lines.append('      %s: "%s"' % (k, str(v)))
    lines.append("")

remove = data.get('remove_builtins') or []
if remove:
    lines.append("remove_builtins:")
    for r in remove:
        lines.append("  - %s" % r)
else:
    lines.append("remove_builtins: []")

lines.append("")
with open(path, 'w') as f:
    f.write('\n'.join(lines))
print("ok")
PYEOF
}

_yaml_invalidate_cache() {
  rm -f "$CACHE"
}

# ── Read helpers ──────────────────────────────────────────────────────────
_json_get() {
  # $1 = json string, $2 = python expression evaluated on the parsed dict
  python3 -c "import sys,json; d=json.loads(sys.argv[1]); print(sys.argv[2])" "$1" "$2" 2>/dev/null || echo ""
}

_get_preset_names() {
  local jdata; jdata=$(_yaml_get_json)
  python3 -c "
import sys, json
d = json.loads(sys.argv[1])
presets = d.get('presets') or {}
for k in presets:
    print(k)
" "$jdata" 2>/dev/null || true
}

_get_preset_field() {
  local name="$1" field="$2"
  local jdata; jdata=$(_yaml_get_json)
  python3 -c "
import sys, json
d = json.loads(sys.argv[1])
p = (d.get('presets') or {}).get(sys.argv[2]) or {}
val = p.get(sys.argv[3]) or ''
if isinstance(val, dict):
    print(json.dumps(val))
else:
    print(val)
" "$jdata" "$name" "$field" 2>/dev/null || echo ""
}

_get_ux_field() {
  local field="$1" default="${2:-}"
  local jdata; jdata=$(_yaml_get_json)
  python3 -c "
import sys, json
d = json.loads(sys.argv[1])
ux = d.get('ux') or {}
val = ux.get(sys.argv[2])
if val is None:
    print(sys.argv[3])
elif isinstance(val, list):
    print(' '.join(val))
else:
    print(val)
" "$jdata" "$field" "$default" 2>/dev/null || echo "$default"
}

# ── Show current presets ──────────────────────────────────────────────────
_show_user_presets() {
  local names=()
  while IFS= read -r n; do [[ -n "$n" ]] && names+=("$n"); done < <(_get_preset_names)
  if [[ ${#names[@]} -eq 0 ]]; then
    printf "    ${C_DIM}(no user presets — built-ins are active)${C_RST}\n"
    return
  fi
  local i=1
  for name in "${names[@]}"; do
    local flags; flags=$(_get_preset_field "$name" "flags")
    local desc;  desc=$(_get_preset_field "$name" "description")
    local alias_char; alias_char=$(_get_preset_field "$name" "alias")
    local label="$name"
    [[ -n "$alias_char" ]] && label="$name ($alias_char)"
    printf "    %d) %-22s %s\n" "$i" "$label" "${C_DIM}${flags}${C_RST}"
    [[ -n "$desc" ]] && printf "       %-22s ${C_DIM}%s${C_RST}\n" "" "$desc"
    ((i++))
  done
}

# ── Flag builder ──────────────────────────────────────────────────────────
_pick_model() {
  hdr "Model"
  printf "    1) sonnet  — Sonnet 4.6 (fast, daily driver)\n"
  printf "    2) opus    — Opus 4.7 (smartest, slower)\n"
  printf "    3) haiku   — Haiku 4.5 (cheapest, fastest)\n\n"
  while true; do
    ask "Choice [1-3]:"; read -r m
    case "$m" in
      1) echo "sonnet"; return ;;
      2) echo "opus";   return ;;
      3) echo "haiku";  return ;;
      *) err "Enter 1, 2, or 3." ;;
    esac
  done
}

_pick_effort() {
  hdr "Effort / reasoning"
  printf "    1) auto   — Claude decides (omit --effort flag)\n"
  printf "    2) low    — fast, minimal reasoning\n"
  printf "    3) medium\n"
  printf "    4) high\n"
  printf "    5) max    — slowest, deepest reasoning\n\n"
  while true; do
    ask "Choice [1-5]:"; read -r e
    case "$e" in
      1) echo "";              return ;;
      2) echo "--effort low";    return ;;
      3) echo "--effort medium"; return ;;
      4) echo "--effort high";   return ;;
      5) echo "--effort max";    return ;;
      *) err "Enter 1-5." ;;
    esac
  done
}

_pick_mode() {
  hdr "Permission mode"
  printf "    1) default          — normal approvals\n"
  printf "    2) skip (yolo)      — --dangerously-skip-permissions\n"
  printf "    3) plan             — plan-only, no execution\n"
  printf "    4) acceptEdits      — auto-accept file edits, approve shell\n\n"
  while true; do
    ask "Choice [1-4]:"; read -r p
    case "$p" in
      1) echo "";                                 return ;;
      2) echo "--dangerously-skip-permissions";   return ;;
      3) echo "--permission-mode plan";           return ;;
      4) echo "--permission-mode acceptEdits";    return ;;
      *) err "Enter 1-4." ;;
    esac
  done
}

_build_flags() {
  local model effort mode
  model=$(_pick_model)
  effort=$(_pick_effort)
  mode=$(_pick_mode)
  local flags="--model $model"
  [[ -n "$effort" ]] && flags+=" $effort"
  [[ -n "$mode"   ]] && flags+=" $mode"
  echo "$flags"
}

_auto_desc() {
  local flags="$1" model_label effort_label mode_label
  if echo "$flags" | grep -q 'sonnet'; then model_label="Sonnet 4.6"
  elif echo "$flags" | grep -q 'opus';   then model_label="Opus 4.7"
  else model_label="Haiku 4.5"; fi
  if echo "$flags" | grep -q '\-\-effort'; then
    local ev; ev=$(echo "$flags" | grep -o '\-\-effort [^ ]*' | awk '{print $2}')
    effort_label="$ev effort"
  else
    effort_label="auto effort"
  fi
  if echo "$flags" | grep -q 'dangerously-skip'; then mode_label="skip permissions"
  elif echo "$flags" | grep -q 'plan';            then mode_label="plan mode"
  elif echo "$flags" | grep -q 'acceptEdits';     then mode_label="accept edits"
  else                                                  mode_label="default mode"; fi
  echo "$model_label · $effort_label · $mode_label"
}

# ── YAML mutation helpers ─────────────────────────────────────────────────
_upsert_preset() {
  # args: name flags desc alias prompt mcp env_json
  local name="$1" flags="$2" desc="$3" alias_char="$4" prompt="$5" mcp_path="$6" env_json="${7:-{}}"
  local jdata; jdata=$(_yaml_get_json)
  local new_json
  new_json=$(python3 - "$jdata" "$name" "$flags" "$desc" "$alias_char" "$prompt" "$mcp_path" "$env_json" <<'PYEOF'
import sys, json
d = json.loads(sys.argv[1])
name, flags, desc, alias_char, prompt, mcp_path, env_json = sys.argv[2:]
if 'presets' not in d or not isinstance(d.get('presets'), dict):
    d['presets'] = {}
cfg = d['presets'].get(name) or {}
if flags:        cfg['flags']       = flags
if desc:         cfg['description'] = desc
if alias_char:   cfg['alias']       = alias_char
if prompt:       cfg['prompt']      = prompt
if mcp_path:     cfg['mcp']         = mcp_path
env = json.loads(env_json) if env_json else {}
if env:          cfg['env']         = env
d['presets'][name] = cfg
print(json.dumps(d))
PYEOF
)
  _yaml_write "$new_json"
  _yaml_invalidate_cache
}

_remove_preset() {
  local name="$1"
  local jdata; jdata=$(_yaml_get_json)
  local new_json
  new_json=$(python3 -c "
import sys, json
d = json.loads(sys.argv[1])
presets = d.get('presets') or {}
presets.pop(sys.argv[2], None)
d['presets'] = presets
print(json.dumps(d))
" "$jdata" "$name")
  _yaml_write "$new_json"
  _yaml_invalidate_cache
}

_update_ux() {
  local order="$1" default="$2" remap="$3"
  local jdata; jdata=$(_yaml_get_json)
  local new_json
  new_json=$(python3 -c "
import sys, json
d = json.loads(sys.argv[1])
d['ux'] = d.get('ux') or {}
order = sys.argv[2]
if order:
    d['ux']['order'] = [x.strip() for x in order.split() if x.strip()]
d['ux']['default'] = sys.argv[3]
d['ux']['remap']   = sys.argv[4]
print(json.dumps(d))
" "$jdata" "$order" "$default" "$remap")
  _yaml_write "$new_json"
  _yaml_invalidate_cache
}

# ── Preset management ─────────────────────────────────────────────────────
cmd_presets() {
  while true; do
    hdr "Preset manager"
    printf "  ${C_DIM}User presets in $CLAUDES_YAML:${C_RST}\n\n"
    _show_user_presets
    printf "\n"
    printf "    a) Add preset\n"
    printf "    e) Edit preset\n"
    printf "    r) Remove preset\n"
    printf "    q) Back / quit\n\n"
    ask "Choice:"; read -r action

    case "${action:l}" in
      a) _action_add ;;
      e) _action_edit ;;
      r) _action_remove ;;
      q|"") return 0 ;;
      *) warn "Unknown choice." ;;
    esac
  done
}

_action_add() {
  hdr "Add preset"
  ask "Preset name (e.g. 'myfast'):"; read -r name
  [[ -z "$name" ]] && warn "Cancelled." && return

  local existing; existing=$(_get_preset_field "$name" "flags")
  if [[ -n "$existing" ]]; then
    warn "Preset '$name' already exists. Use Edit to modify it."
    return
  fi

  local flags; flags=$(_build_flags)
  local model; model=$(echo "$flags" | grep -o '\-\-model [^ ]*' | awk '{print $2}')
  local auto_desc; auto_desc=$(_auto_desc "$flags")

  printf "\n  Auto-description: ${C_DIM}%s${C_RST}\n" "$auto_desc"
  ask "Custom description [enter to keep]:"; read -r desc
  [[ -z "$desc" ]] && desc="$auto_desc"

  ask "Single-char alias [enter to skip]:"; read -r alias_char
  [[ ${#alias_char} -gt 1 ]] && alias_char="${alias_char:0:1}"

  ask "System-prompt addendum [enter to skip]:"; read -r prompt

  ask "MCP config path [enter to skip]:"; read -r mcp_path

  printf "\n  Preview:\n"
  printf "    name:  %s\n" "$name"
  printf "    flags: %s\n" "$flags"
  [[ -n "$desc" ]]       && printf "    desc:  %s\n" "$desc"
  [[ -n "$alias_char" ]] && printf "    alias: %s\n" "$alias_char"
  [[ -n "$prompt" ]]     && printf "    prompt: %s\n" "$prompt"
  [[ -n "$mcp_path" ]]   && printf "    mcp:   %s\n" "$mcp_path"
  printf "\n"
  ask "Save? [Y/n]:"; read -r confirm
  [[ "${confirm:l}" == "n" ]] && warn "Cancelled." && return

  _upsert_preset "$name" "$flags" "$desc" "$alias_char" "$prompt" "$mcp_path" "{}"
  ok "Preset '$name' added to $CLAUDES_YAML"
}

_action_edit() {
  local names=()
  while IFS= read -r n; do [[ -n "$n" ]] && names+=("$n"); done < <(_get_preset_names)
  [[ ${#names[@]} -eq 0 ]] && warn "No user presets to edit." && return

  hdr "Edit preset"
  local i=1
  for n in "${names[@]}"; do printf "    %d) %s\n" "$i" "$n"; ((i++)); done
  printf "\n"
  ask "Preset number:"; read -r idx
  if ! [[ "$idx" =~ ^[0-9]+$ ]] || (( idx < 1 || idx > ${#names[@]} )); then
    err "Invalid number."; return
  fi
  local name="${names[$((idx-1))]}"

  local flags desc alias_char prompt mcp_path
  flags=$(_get_preset_field "$name" "flags")
  desc=$(_get_preset_field "$name" "description")
  alias_char=$(_get_preset_field "$name" "alias")
  prompt=$(_get_preset_field "$name" "prompt")
  mcp_path=$(_get_preset_field "$name" "mcp")

  printf "\n  Editing '%s'\n" "$name"
  ask "Rebuild flags interactively? [Y/n]:"; read -r rebuild
  if [[ "${rebuild:l}" != "n" ]]; then
    flags=$(_build_flags)
  else
    printf "  Current flags: ${C_DIM}%s${C_RST}\n" "$flags"
    ask "New flags [enter to keep]:"; read -r new_flags
    [[ -n "$new_flags" ]] && flags="$new_flags"
  fi

  printf "  Current description: ${C_DIM}%s${C_RST}\n" "$desc"
  ask "New description [enter to keep]:"; read -r new_desc
  [[ -n "$new_desc" ]] && desc="$new_desc"

  printf "  Current alias: ${C_DIM}%s${C_RST}\n" "${alias_char:-(none)}"
  ask "New alias [enter to keep, - to clear]:"; read -r new_alias
  if [[ "$new_alias" == "-" ]]; then alias_char=""
  elif [[ -n "$new_alias" ]]; then alias_char="${new_alias:0:1}"; fi

  printf "  Current prompt: ${C_DIM}%s${C_RST}\n" "${prompt:-(none)}"
  ask "New prompt [enter to keep, - to clear]:"; read -r new_prompt
  if [[ "$new_prompt" == "-" ]]; then prompt=""
  elif [[ -n "$new_prompt" ]]; then prompt="$new_prompt"; fi

  printf "  Current mcp: ${C_DIM}%s${C_RST}\n" "${mcp_path:-(none)}"
  ask "New mcp path [enter to keep, - to clear]:"; read -r new_mcp
  if [[ "$new_mcp" == "-" ]]; then mcp_path=""
  elif [[ -n "$new_mcp" ]]; then mcp_path="$new_mcp"; fi

  _upsert_preset "$name" "$flags" "$desc" "$alias_char" "$prompt" "$mcp_path" "{}"
  ok "Preset '$name' updated."
}

_action_remove() {
  local names=()
  while IFS= read -r n; do [[ -n "$n" ]] && names+=("$n"); done < <(_get_preset_names)
  [[ ${#names[@]} -eq 0 ]] && warn "No user presets to remove." && return

  hdr "Remove preset"
  local i=1
  for n in "${names[@]}"; do printf "    %d) %s\n" "$i" "$n"; ((i++)); done
  printf "\n"
  ask "Preset number to remove:"; read -r idx
  if ! [[ "$idx" =~ ^[0-9]+$ ]] || (( idx < 1 || idx > ${#names[@]} )); then
    err "Invalid number."; return
  fi
  local name="${names[$((idx-1))]}"
  ask "Remove '$name'? [y/N]:"; read -r confirm
  [[ "${confirm:l}" != "y" ]] && warn "Cancelled." && return
  _remove_preset "$name"
  ok "Preset '$name' removed."
}

# ── UX settings ───────────────────────────────────────────────────────────
cmd_ux() {
  local order default remap
  order=$(_get_ux_field "order" "")
  default=$(_get_ux_field "default" "standard")
  remap=$(_get_ux_field "remap" "warp")

  hdr "UX settings"
  printf "  Current:\n"
  printf "    Order:   ${C_DIM}%s${C_RST}\n" "${order:-(alphabetical)}"
  printf "    Default: ${C_DIM}%s${C_RST}\n" "$default"
  printf "    Remap:   ${C_DIM}%s${C_RST}\n\n" "$remap"

  printf "  ${C_BOLD}Picker order${C_RST} — space-separated preset names:\n"
  printf "  ${C_DIM}Example: plan max standard quick${C_RST}\n"
  ask "Order [$order]:"; read -r new_order
  [[ -n "$new_order" ]] && order="$new_order"

  printf "\n  ${C_BOLD}Default preset${C_RST} — bare Enter selects this:\n"
  ask "Default [$default]:"; read -r new_default
  [[ -n "$new_default" ]] && default="$new_default"

  printf "\n  ${C_BOLD}Remap 'claude' → 'claudes'${C_RST}\n"
  printf "    1) warp  — Warp terminal only ${C_DIM}(recommended)${C_RST}\n"
  printf "    2) all   — every terminal\n"
  printf "    3) none  — never\n\n"
  local remap_n
  case "$remap" in warp) remap_n=1 ;; all) remap_n=2 ;; *) remap_n=3 ;; esac
  ask "Remap [$remap_n]:"; read -r r
  case "$r" in
    1) remap=warp ;; 2) remap=all ;; 3) remap=none ;; "") ;;
    *) warn "Invalid — keeping '$remap'." ;;
  esac

  _update_ux "$order" "$default" "$remap"
  ok "Updated $CLAUDES_YAML"
  printf "\n  ${C_DIM}Restart shell (or: source ~/.zshrc.d/9*-claudes*.zsh) to apply.${C_RST}\n"
}

# ── Main menu ─────────────────────────────────────────────────────────────
cmd_main() {
  hdr "claudes config"
  printf "  Config: ${C_DIM}%s${C_RST}\n\n" "$CLAUDES_YAML"
  printf "    1) Manage presets\n"
  printf "    2) UX settings (order, default, remap)\n"
  printf "    q) Quit\n\n"
  ask "Choice:"; read -r choice
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
