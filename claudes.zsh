# ╔══════════════════════════════════════════════════════════════════╗
# ║  claudes — Claude Code preset picker for zsh                    ║
# ║                                                                  ║
# ║  Switch between Claude Code model/effort/mode combinations,     ║
# ║  MCP sets, system prompts, tool subsets, and env vars with      ║
# ║  a single command. Sensible defaults, extend with your own.     ║
# ║                                                                  ║
# ║  https://github.com/yigitkonur/claudes                          ║
# ╚══════════════════════════════════════════════════════════════════╝

# ============ PRESET REGISTRIES ============
# All registries are zsh associative arrays. All are optional except
# CLAUDES_PRESETS itself. Missing keys are no-ops.
typeset -gA CLAUDES_PRESETS        # preset → CLI flag string, OR "fn:<func_name>"
typeset -gA CLAUDES_DESCRIPTIONS   # preset → one-line human description
typeset -gA CLAUDES_ALIASES        # short → preset
typeset -gA CLAUDES_ENV            # preset → "KEY=val KEY2=val2" (space-separated)
typeset -gA CLAUDES_MCP            # preset → path to --mcp-config JSON file
typeset -gA CLAUDES_PROMPT         # preset → string appended via --append-system-prompt

# ============ DEFAULT PRESETS ============
# Four built-ins, intentionally minimal. Add more in ~/.config/claudes/presets.zsh.
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
# Drop your own presets into ~/.config/claudes/presets.zsh.
# See the examples/ directory in the repo for ready-to-copy recipes.
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

_claudes_markers() {
  # Compact marker suffix showing which extras a preset carries.
  # E.g. "+mcp +prompt" or "fn" for a function-form preset.
  local key="$1"
  local -a marks=()
  [[ "${CLAUDES_PRESETS[$key]-}" == fn:* ]] && marks+=(fn)
  [[ -n "${CLAUDES_ENV[$key]-}"    ]] && marks+=(+env)
  [[ -n "${CLAUDES_MCP[$key]-}"    ]] && marks+=(+mcp)
  [[ -n "${CLAUDES_PROMPT[$key]-}" ]] && marks+=(+prompt)
  (( ${#marks[@]} )) && echo " [${marks[*]}]"
}

_claudes_print_presets() {
  # Print numbered list of presets (sorted by key).
  local -A _rev
  local _ak
  for _ak in ${(ko)CLAUDES_ALIASES}; do
    _rev[${CLAUDES_ALIASES[$_ak]}]="$_ak"
  done

  local i=1 key alias_char marker_str
  for key in ${(ko)CLAUDES_PRESETS}; do
    alias_char=""
    [[ -n "${_rev[$key]-}" ]] && alias_char=" (${_rev[$key]})"
    marker_str=$(_claudes_markers "$key")
    printf "    %d) %-18s · %s%s\n" "$i" "$key$alias_char" "${CLAUDES_DESCRIPTIONS[$key]}" "$marker_str"
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

_claudes_expand_tilde() {
  # Expand leading ~ in paths (since assoc array values are not auto-expanded).
  local p="$1"
  echo "${p/#\~/$HOME}"
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
  claudes show <preset>         Show resolved config for a preset
  claudes help                  Show this help

BUILT-IN PRESETS
EOF
      _claudes_print_presets
      cat <<'EOF'

PRESET MARKERS (shown in list/picker)
  [fn]      preset is a zsh function (full flexibility)
  [+env]    preset exports extra env vars before launch
  [+mcp]    preset loads its own MCP server set (--mcp-config)
  [+prompt] preset appends a system prompt (--append-system-prompt)

EXAMPLES
  claudes                       Pick from menu
  claudes standard              Sonnet 4.6 · max · default mode
  claudes s "fix the bug"       Alias + prompt
  claudes plan --resume         Plan mode + resume last session
  claudes show research         Dry-run print of resolved command

CUSTOM PRESETS
  Edit ~/.config/claudes/presets.zsh:

  # Simple flag-string preset
  CLAUDES_PRESETS[mine]="--model sonnet --effort high"
  CLAUDES_DESCRIPTIONS[mine]="my custom preset"
  CLAUDES_ALIASES[m]=mine

  # Preset with MCP + system prompt + env var
  CLAUDES_PRESETS[review]="--model sonnet --effort low --tools Read,Grep,Glob,Bash"
  CLAUDES_DESCRIPTIONS[review]="read-only review mode"
  CLAUDES_MCP[review]="$HOME/.config/claudes/mcp/research-only.json"
  CLAUDES_PROMPT[review]="You are in read-only review mode. Do not edit files."
  CLAUDES_ENV[review]="CLAUDE_CODE_MAX_OUTPUT_TOKENS=16000"

  # Function-form preset (full zsh power)
  _my_worktree() { command claude -w "${1:-feat-$(date +%s)}" --tmux --model opus --effort max "${@:2}"; }
  CLAUDES_PRESETS[wt]="fn:_my_worktree"
  CLAUDES_DESCRIPTIONS[wt]="Opus · max · spawn worktree + tmux"

MORE
  https://github.com/yigitkonur/claudes
  Ready-to-copy recipes: examples/ directory in the repo
EOF
      return 0
      ;;
    list|ls)
      echo ""
      _claudes_print_presets
      echo ""
      return 0
      ;;
    show)
      local target="${rest[1]:-}"
      if [[ -z "$target" ]]; then
        echo "usage: claudes show <preset>" >&2; return 1
      fi
      local r
      r=$(_claudes_resolve "$target") || { echo "unknown preset: $target" >&2; return 1; }
      echo "preset:       $r"
      echo "description:  ${CLAUDES_DESCRIPTIONS[$r]}"
      echo "flags:        ${CLAUDES_PRESETS[$r]}"
      [[ -n "${CLAUDES_ENV[$r]-}"    ]] && echo "env:          ${CLAUDES_ENV[$r]}"
      [[ -n "${CLAUDES_MCP[$r]-}"    ]] && echo "mcp-config:   ${CLAUDES_MCP[$r]}"
      [[ -n "${CLAUDES_PROMPT[$r]-}" ]] && echo "prompt:       ${CLAUDES_PROMPT[$r]}"
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

  # ── Function-form preset (fn:<name>) ─────────────────────────────────
  # Full escape hatch: user-defined zsh function gets called with rest args.
  # CLAUDES_ENV still applies; MCP and PROMPT are ignored (the function owns those).
  if [[ "$flags" == fn:* ]]; then
    local fn_name="${flags#fn:}"
    if ! typeset -f "$fn_name" > /dev/null 2>&1; then
      echo "claudes: preset function '$fn_name' is not defined" >&2
      return 1
    fi
    echo "▶ ${resolved} · ${desc}"
    if [[ -n "${CLAUDES_ENV[$resolved]-}" ]]; then
      # Subshell so env exports don't leak to the calling shell.
      (
        local _p
        for _p in ${=CLAUDES_ENV[$resolved]}; do export "$_p"; done
        "$fn_name" "${rest[@]}"
      )
    else
      "$fn_name" "${rest[@]}"
    fi
    return $?
  fi

  # ── Flag-string preset ───────────────────────────────────────────────
  local -a extra_flags=()

  if [[ -n "${CLAUDES_MCP[$resolved]-}" ]]; then
    local mcp_path
    mcp_path=$(_claudes_expand_tilde "${CLAUDES_MCP[$resolved]}")
    if [[ ! -f "$mcp_path" ]]; then
      echo "claudes: MCP config not found for '$resolved': $mcp_path" >&2
      return 1
    fi
    extra_flags+=(--mcp-config "$mcp_path")
  fi

  if [[ -n "${CLAUDES_PROMPT[$resolved]-}" ]]; then
    extra_flags+=(--append-system-prompt "${CLAUDES_PROMPT[$resolved]}")
  fi

  local -a env_prefix=()
  if [[ -n "${CLAUDES_ENV[$resolved]-}" ]]; then
    env_prefix=(env ${=CLAUDES_ENV[$resolved]})
  fi

  echo "▶ ${resolved} · ${desc}"
  # shellcheck disable=SC2086  # intentional word-splitting on $flags
  "${env_prefix[@]}" command claude ${=flags} "${extra_flags[@]}" "${rest[@]}"
}
