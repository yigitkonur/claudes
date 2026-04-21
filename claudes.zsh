# ╔══════════════════════════════════════════════════════════════════╗
# ║  claudes — Claude Code preset picker for zsh                    ║
# ║                                                                  ║
# ║  Switch between Claude Code model/effort/mode combinations      ║
# ║  with a single command. Ship sensible defaults, extend with     ║
# ║  your own presets via ~/.config/claudes/presets.zsh             ║
# ║                                                                  ║
# ║  https://github.com/yigitkonur/claudes                          ║
# ╚══════════════════════════════════════════════════════════════════╝

# ============ DEFAULT PRESETS ============
# Users can override any of these in ~/.config/claudes/presets.zsh
typeset -gA CLAUDES_PRESETS
typeset -gA CLAUDES_DESCRIPTIONS
typeset -gA CLAUDES_ALIASES

CLAUDES_PRESETS[standard]="--model sonnet --effort max --permission-mode default"
CLAUDES_DESCRIPTIONS[standard]="Sonnet 4.6 · max effort · daily coding work"
CLAUDES_ALIASES[s]=standard

CLAUDES_PRESETS[quick]="--model sonnet --effort low --permission-mode default"
CLAUDES_DESCRIPTIONS[quick]="Sonnet 4.6 · low effort · fast/cheap edits"
CLAUDES_ALIASES[q]=quick

CLAUDES_PRESETS[plan]="--model opus --effort max --permission-mode plan"
CLAUDES_DESCRIPTIONS[plan]="Opus 4.7 · max effort · plan mode · deep thinking"
CLAUDES_ALIASES[p]=plan

CLAUDES_PRESETS[research]="--model opus --effort max --permission-mode default"
CLAUDES_DESCRIPTIONS[research]="Opus 4.7 · max effort · direct · explore/review"
CLAUDES_ALIASES[r]=research

# ============ USER OVERRIDES / CUSTOM PRESETS ============
# Drop your own presets into ~/.config/claudes/presets.zsh
#
# Example:
#   CLAUDES_PRESETS[haiku]="--model haiku --effort low"
#   CLAUDES_DESCRIPTIONS[haiku]="Haiku 4.5 · low · ultra-cheap"
#   CLAUDES_ALIASES[h]=haiku
#
_claudes_user_config="${XDG_CONFIG_HOME:-$HOME/.config}/claudes/presets.zsh"
[[ -f "$_claudes_user_config" ]] && source "$_claudes_user_config"
unset _claudes_user_config

# ============ INTERNAL HELPERS ============
_claudes_resolve() {
  # Resolve preset name (handles aliases). Returns preset key or empty.
  local input="$1"
  if [[ -n "${CLAUDES_PRESETS[$input]-}" ]]; then
    echo "$input"; return 0
  fi
  if [[ -n "${CLAUDES_ALIASES[$input]-}" ]]; then
    echo "${CLAUDES_ALIASES[$input]}"; return 0
  fi
  return 1
}

_claudes_print_presets() {
  # Print numbered list of presets (sorted by key).
  local -A _rev
  local _ak
  for _ak in ${(ko)CLAUDES_ALIASES}; do
    _rev[${CLAUDES_ALIASES[$_ak]}]="$_ak"
  done

  local i=1 key alias_char
  for key in ${(ko)CLAUDES_PRESETS}; do
    alias_char=""
    [[ -n "${_rev[$key]-}" ]] && alias_char=" (${_rev[$key]})"
    printf "    %d) %-14s · %s\n" "$i" "$key$alias_char" "${CLAUDES_DESCRIPTIONS[$key]}"
    ((i++))
  done
}

_claudes_key_by_index() {
  # Return the Nth preset key (1-based) or empty.
  local want="$1"
  local i=1 key
  for key in ${(ko)CLAUDES_PRESETS}; do
    [[ "$i" == "$want" ]] && { echo "$key"; return 0; }
    ((i++))
  done
  return 1
}

# ============ MAIN FUNCTION ============
function claudes() {
  local preset="${1:-}"
  local rest=()
  if [[ $# -gt 0 ]]; then shift; rest=("$@"); fi

  # Interactive picker
  if [[ -z "$preset" ]]; then
    if [[ ! -t 0 ]]; then
      echo "claudes: no preset and stdin is not a TTY — pass a preset name" >&2
      return 1
    fi
    echo ""
    echo "  Choose Claude preset:"
    echo ""
    _claudes_print_presets
    echo ""
    printf "  > "
    read -r choice
    if [[ -z "$choice" ]]; then
      echo "cancelled"; return 0
    fi
    # Numeric choice → resolve to key
    if [[ "$choice" =~ ^[0-9]+$ ]]; then
      local resolved
      resolved=$(_claudes_key_by_index "$choice") || { echo "invalid: $choice" >&2; return 1; }
      preset="$resolved"
    else
      preset="$choice"
    fi
  fi

  # Help / list commands
  case "$preset" in
    help|-h|--help)
      cat <<'EOF'
claudes — Claude Code preset picker

USAGE
  claudes                       Interactive picker
  claudes <preset> [args...]    Run a specific preset
  claudes list                  List all presets
  claudes help                  Show this help

BUILT-IN PRESETS
EOF
      _claudes_print_presets
      cat <<'EOF'

EXAMPLES
  claudes                       Pick from menu
  claudes standard              Sonnet 4.6 · max · default mode
  claudes s "fix the bug"       Alias + prompt
  claudes plan --resume         Plan mode + resume last session

CUSTOM PRESETS
  Edit ~/.config/claudes/presets.zsh:
    CLAUDES_PRESETS[mine]="--model sonnet --effort high"
    CLAUDES_DESCRIPTIONS[mine]="my custom preset"
    CLAUDES_ALIASES[m]=mine

MORE
  https://github.com/yigitkonur/claudes
EOF
      return 0
      ;;
    list|ls)
      echo ""
      _claudes_print_presets
      echo ""
      return 0
      ;;
  esac

  # Resolve preset (including aliases)
  local resolved
  resolved=$(_claudes_resolve "$preset") || {
    echo "claudes: unknown preset '$preset' (run 'claudes list' or 'claudes help')" >&2
    return 1
  }

  local flags="${CLAUDES_PRESETS[$resolved]}"
  local desc="${CLAUDES_DESCRIPTIONS[$resolved]}"

  echo "▶ ${resolved} · ${desc}"
  # shellcheck disable=SC2086  # intentional word-splitting on flags
  command claude ${=flags} "${rest[@]}"
}
