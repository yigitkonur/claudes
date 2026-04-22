# ux.zsh — Enhanced UX layer for claudes
#
# Source AFTER claudes.zsh (e.g. as ~/.zshrc.d/91-claudes-ux.zsh).
# Install via: curl -fsSL https://raw.githubusercontent.com/yigitkonur/claudes/main/install.sh | bash
#
# Features enabled by this file:
#   • CLAUDES_ORDER   — fix picker slot order instead of alphabetical
#   • CLAUDES_DEFAULT — bare Enter in picker launches this preset
#   • Single-key      — press 1-9 or alias letter without Enter → instant launch
#   • claude1..claude9 — jump to Nth preset by position from the CLI
#   • CLAUDES_REMAP_CLAUDE — remap `claude` → `claudes` (warp|all|none)
#
# Tune behaviour in ~/.config/claudes/ux-settings.zsh (written by the installer
# or `claudes config ux`). This file just provides safe defaults.

# ── Defaults (overridden by ux-settings.zsh below) ───────────────────────
typeset -ga CLAUDES_ORDER        # empty = alphabetical fallback
: ${CLAUDES_DEFAULT:=standard}   # Enter-key preset
: ${CLAUDES_REMAP_CLAUDE:=warp}  # warp | all | none

# ── User UX settings (from shared YAML cache) ─────────────────────────────
# claudes.zsh (90-) already generated ~/.config/claudes/.claudes-cache.zsh.
# Source it here for CLAUDES_ORDER / DEFAULT / REMAP; it's a cache-hit no-op.
_claudes_ux_cache="${XDG_CONFIG_HOME:-$HOME/.config}/claudes/.claudes-cache.zsh"
_claudes_ux_yaml="${XDG_CONFIG_HOME:-$HOME/.config}/claudes/claudes.yaml"
_claudes_ux_y2sh="$HOME/.local/share/claudes/yaml2sh.py"
if [[ -f "$_claudes_ux_yaml" && -f "$_claudes_ux_y2sh" ]]; then
  if [[ ! -f "$_claudes_ux_cache" || "$_claudes_ux_yaml" -nt "$_claudes_ux_cache" ]]; then
    python3 "$_claudes_ux_y2sh" "$_claudes_ux_yaml" > "$_claudes_ux_cache" 2>/dev/null
  fi
  [[ -f "$_claudes_ux_cache" ]] && source "$_claudes_ux_cache"
fi
unset _claudes_ux_cache _claudes_ux_yaml _claudes_ux_y2sh

# ── Override _claudes_print_presets to respect CLAUDES_ORDER ─────────────
_claudes_print_presets() {
  local -A _rev
  local _ak
  for _ak in ${(ko)CLAUDES_ALIASES}; do
    _rev[${CLAUDES_ALIASES[$_ak]}]="$_ak"
  done
  local i=1 key alias_char marker_str

  # Ordered presets first
  for key in $CLAUDES_ORDER; do
    [[ -z "${CLAUDES_PRESETS[$key]-}" ]] && continue
    alias_char=""
    [[ -n "${_rev[$key]-}" ]] && alias_char=" (${_rev[$key]})"
    marker_str=$(_claudes_markers "$key")
    printf "    %d) %-18s · %s%s\n" "$i" "$key$alias_char" "${CLAUDES_DESCRIPTIONS[$key]:-}" "$marker_str"
    ((i++))
  done

  # Any preset not in CLAUDES_ORDER (custom extras stay visible)
  for key in ${(ko)CLAUDES_PRESETS}; do
    (( ${#CLAUDES_ORDER} > 0 )) && (( ${CLAUDES_ORDER[(I)$key]} > 0 )) && continue
    alias_char=""
    [[ -n "${_rev[$key]-}" ]] && alias_char=" (${_rev[$key]})"
    marker_str=$(_claudes_markers "$key")
    printf "    %d) %-18s · %s%s\n" "$i" "$key$alias_char" "${CLAUDES_DESCRIPTIONS[$key]:-}" "$marker_str"
    ((i++))
  done
}

# ── Override _claudes_key_by_index to respect CLAUDES_ORDER ──────────────
_claudes_key_by_index() {
  local want="$1" i=1 key
  for key in $CLAUDES_ORDER; do
    [[ -z "${CLAUDES_PRESETS[$key]-}" ]] && continue
    [[ "$i" == "$want" ]] && { echo "$key"; return 0; }
    ((i++))
  done
  for key in ${(ko)CLAUDES_PRESETS}; do
    (( ${#CLAUDES_ORDER} > 0 )) && (( ${CLAUDES_ORDER[(I)$key]} > 0 )) && continue
    [[ "$i" == "$want" ]] && { echo "$key"; return 0; }
    ((i++))
  done
  return 1
}

# ── Wrap claudes() with single-key, Enter-defaults picker ────────────────
if typeset -f claudes >/dev/null 2>&1; then
  functions -c claudes _claudes_upstream

  claudes() {
    # Non-interactive / args passed → delegate straight to upstream.
    if [[ $# -gt 0 || ! -t 0 ]]; then
      _claudes_upstream "$@"
      return $?
    fi

    echo ""
    echo "  Choose Claude preset:"
    echo ""
    _claudes_print_presets
    echo ""
    printf "  > [enter = %s] " "$CLAUDES_DEFAULT"

    local key
    read -k 1 key
    echo ""

    # Bare Enter → default preset
    if [[ "$key" == $'\n' ]]; then
      _claudes_upstream "$CLAUDES_DEFAULT"
      return $?
    fi

    key="${key:l}"  # normalise to lowercase

    # Digit → positional preset
    if [[ "$key" =~ ^[0-9]$ ]]; then
      local name
      name=$(_claudes_key_by_index "$key" 2>/dev/null)
      if [[ -z "$name" ]]; then
        echo "claudes: no preset at position $key" >&2
        return 1
      fi
      _claudes_upstream "$name"
      return $?
    fi

    # Letter → alias or preset name
    _claudes_upstream "$key"
  }
fi

# ── claude1..claude9 — jump straight to Nth preset ───────────────────────
_claudes_by_pos() {
  local n="$1"; shift
  local name
  name=$(_claudes_key_by_index "$n" 2>/dev/null) || {
    echo "claudes: no preset at position $n" >&2
    return 1
  }
  claudes "$name" "$@"
}

for _cpos in 1 2 3 4 5 6 7 8 9; do
  eval "claude${_cpos}() { _claudes_by_pos ${_cpos} \"\$@\"; }"
done
unset _cpos

# ── claude → claudes remap ────────────────────────────────────────────────
_claudes_do_remap() {
  unalias claude 2>/dev/null
  function claude { claudes "$@"; }
}

case "$CLAUDES_REMAP_CLAUDE" in
  all)  _claudes_do_remap ;;
  warp) [[ "$TERM_PROGRAM" == "WarpTerminal" ]] && _claudes_do_remap ;;
  none) ;;
esac
unfunction _claudes_do_remap 2>/dev/null
