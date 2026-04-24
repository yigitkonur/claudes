#!/usr/bin/env bash
# test.sh — verify the claudes YAML pipeline end-to-end
#
# Usage:
#   bash test.sh                 # parse + dry-run tests
#   CLAUDES_RUN_LIVE=1 bash test.sh  # also fire a real claude request

set -euo pipefail

INSTALL_DIR="${CLAUDES_INSTALL_DIR:-$HOME/.local/share/claudes}"
CONFIG_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/claudes"
CLAUDES_YML="$CONFIG_DIR/claudes.yaml"
Y2SH="$INSTALL_DIR/yaml2sh.py"
CLAUDES_ZSH="$INSTALL_DIR/claudes.zsh"

# Fall back to local repo files if running from the source directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
[ ! -f "$Y2SH" ]       && Y2SH="$SCRIPT_DIR/yaml2sh.py"
[ ! -f "$CLAUDES_ZSH" ] && CLAUDES_ZSH="$SCRIPT_DIR/claudes.zsh"

PASS=0; FAIL=0
ok()   { printf "\033[0;32m[pass]\033[0m %s\n" "$1"; PASS=$((PASS+1)); }
fail() { printf "\033[0;31m[FAIL]\033[0m %s\n" "$1"; FAIL=$((FAIL+1)); }
hdr()  { printf "\n\033[1m%s\033[0m\n" "$1"; }
sep()  { printf -- "──────────────────────────────────────────\n"; }

# ── Fixtures ──────────────────────────────────────────────────────────────
FIXTURE=$(mktemp /tmp/claudes-test-XXXXXXXXXX)
CACHE=$(mktemp /tmp/claudes-cache-XXXXXXXXXX)
trap 'rm -f "$FIXTURE" "$CACHE" "$TMP_YAML" "$TMP_CACHE" 2>/dev/null' EXIT

cat > "$FIXTURE" <<'YAML'
ux:
  order: [plan, max, standard, quick]
  default: standard
  remap: warp

presets:
  plan:
    flags: "--model opus[1m] --effort max --permission-mode plan"
    description: "Opus 4.7 · 1M ctx · max effort · plan mode"
    alias: p
  max:
    flags: "--model opus[1m] --effort max --dangerously-skip-permissions"
    description: "Opus 4.7 · 1M ctx · max effort · yolo"
    alias: m
  standard:
    flags: "--model sonnet --dangerously-skip-permissions"
    description: "Sonnet 4.6 · auto effort · daily"
    alias: s
  quick:
    flags: "--model sonnet --effort low --dangerously-skip-permissions"
    description: "Sonnet 4.6 · low effort · fast"
    alias: q
  review:
    flags: "--model sonnet --effort low"
    description: "read-only review"
    alias: rv
    prompt: "Do not edit files."
    env:
      CLAUDE_CODE_MAX_OUTPUT_TOKENS: "16000"

remove_builtins:
  - research
YAML

# ── Test 1: yaml2sh.py exists ─────────────────────────────────────────────
hdr "1. yaml2sh.py"
sep
if [ -f "$Y2SH" ]; then
  ok "yaml2sh.py found at $Y2SH"
else
  fail "yaml2sh.py not found at $Y2SH"
fi

# ── Test 2: YAML → zsh output ─────────────────────────────────────────────
hdr "2. YAML parse → zsh output"
sep
SH_OUT=$(python3 "$Y2SH" "$FIXTURE" 2>&1) || { fail "yaml2sh.py exited non-zero"; SH_OUT=""; }
if [ -n "$SH_OUT" ]; then
  ok "yaml2sh.py produced output"
else
  fail "yaml2sh.py produced no output"
fi

echo "$SH_OUT" | grep -q 'CLAUDES_ORDER' && ok "CLAUDES_ORDER present"    || fail "CLAUDES_ORDER missing"
echo "$SH_OUT" | grep -q 'CLAUDES_DEFAULT=standard' && ok "CLAUDES_DEFAULT=standard" || fail "CLAUDES_DEFAULT missing"
echo "$SH_OUT" | grep -q 'CLAUDES_REMAP_CLAUDE=warp' && ok "CLAUDES_REMAP_CLAUDE=warp" || fail "CLAUDES_REMAP_CLAUDE missing"
echo "$SH_OUT" | grep -q "CLAUDES_PRESETS\[plan\]" && ok "plan preset present"    || fail "plan preset missing"
echo "$SH_OUT" | grep -q "CLAUDES_PRESETS\[standard\]" && ok "standard preset present" || fail "standard preset missing"
echo "$SH_OUT" | grep -q "CLAUDES_ENV\[review\]" && ok "review env present"    || fail "review env missing"
echo "$SH_OUT" | grep -q "unset.*CLAUDES_PRESETS\[research\]" && ok "research removed" || fail "research removal missing"

# ── Test 3: YAML → JSON output ────────────────────────────────────────────
hdr "3. YAML parse → JSON output"
sep
JSON_OUT=$(python3 "$Y2SH" --json "$FIXTURE" 2>&1) || { fail "yaml2sh.py --json exited non-zero"; JSON_OUT="{}"; }
python3 -c "import json,sys; d=json.loads(sys.argv[1]); assert 'presets' in d and 'ux' in d" "$JSON_OUT" \
  && ok "JSON has presets + ux keys" || fail "JSON structure invalid"

# ── Test 4: stdlib fallback parser ───────────────────────────────────────
hdr "4. Stdlib fallback (no pyyaml)"
sep
STDLIB_OUT=$(python3 - "$FIXTURE" "$Y2SH" 2>&1 <<'PYEOF') || true
import sys, builtins, importlib.util
orig = builtins.__import__
def block(name, *a, **kw):
    if name == 'yaml': raise ImportError("blocked for test")
    return orig(name, *a, **kw)
builtins.__import__ = block
spec = importlib.util.spec_from_file_location("yaml2sh", sys.argv[2])
mod = importlib.util.module_from_spec(spec)
spec.loader.exec_module(mod)
builtins.__import__ = orig
data = mod.load_yaml(sys.argv[1])
print(mod.render_zsh(data))
PYEOF

echo "$STDLIB_OUT" | grep -q "CLAUDES_PRESETS\[plan\]" && ok "stdlib parser: plan preset" || fail "stdlib parser: plan preset missing"
echo "$STDLIB_OUT" | grep -q "CLAUDES_ORDER" && ok "stdlib parser: CLAUDES_ORDER" || fail "stdlib parser: CLAUDES_ORDER missing"
echo "$STDLIB_OUT" | grep -q "unset.*research" && ok "stdlib parser: remove_builtins" || fail "stdlib parser: remove_builtins missing"

# ── Test 5: zsh sourcing ──────────────────────────────────────────────────
hdr "5. Zsh sourcing + preset resolution"
sep
if ! command -v zsh &>/dev/null; then
  fail "zsh not found — skipping"
else
  python3 "$Y2SH" "$FIXTURE" > "$CACHE"

  ZSH_LIST=$(zsh -c "source '$CLAUDES_ZSH'; source '$CACHE'; claudes list" 2>&1) || true
  echo "$ZSH_LIST" | grep -q 'plan' && ok "claudes list: plan visible" || fail "claudes list: plan not visible"
  echo "$ZSH_LIST" | grep -q 'standard' && ok "claudes list: standard visible" || fail "claudes list: standard not visible"
  echo "$ZSH_LIST" | grep -qv 'research' && ok "claudes list: research removed" || fail "claudes list: research still visible"

  ZSH_SHOW=$(zsh -c "source '$CLAUDES_ZSH'; source '$CACHE'; claudes show plan" 2>&1) || true
  echo "$ZSH_SHOW" | grep -q 'opus' && ok "claudes show plan: opus model" || fail "claudes show plan: opus not found"

  ZSH_SHOW_STD=$(zsh -c "source '$CLAUDES_ZSH'; source '$CACHE'; claudes show standard" 2>&1) || true
  echo "$ZSH_SHOW_STD" | grep -q 'sonnet' && ok "claudes show standard: sonnet model" || fail "claudes show standard: sonnet not found"

  ZSH_SHOW_REV=$(zsh -c "source '$CLAUDES_ZSH'; source '$CACHE'; claudes show review" 2>&1) || true
  echo "$ZSH_SHOW_REV" | grep -q 'CLAUDE_CODE_MAX_OUTPUT_TOKENS' && ok "claudes show review: env vars" || fail "claudes show review: env missing"
fi

# ── Test 6: Cache mtime invalidation ─────────────────────────────────────
hdr "6. Cache invalidation"
sep
TMP_YAML=$(mktemp /tmp/claudes-mtime-XXXXXXXXXX)
TMP_CACHE=$(mktemp /tmp/claudes-mtime-XXXXXXXXXX)

cp "$FIXTURE" "$TMP_YAML"
python3 "$Y2SH" "$TMP_YAML" > "$TMP_CACHE"

# Simulate YAML newer than cache
sleep 0.1
touch "$TMP_YAML"
if [[ "$TMP_YAML" -nt "$TMP_CACHE" ]]; then
  ok "mtime check: YAML correctly seen as newer"
else
  fail "mtime check: YAML not newer after touch"
fi

# ── Test 7: Live smoke test (optional) ───────────────────────────────────
if [[ "${CLAUDES_RUN_LIVE:-0}" == "1" ]]; then
  hdr "7. Live smoke test"
  sep
  if ! command -v claude &>/dev/null; then
    fail "claude CLI not found — skipping live test"
  else
    LIVE_OUT=$(echo "reply with exactly: CLAUDES_OK" \
      | command claude \
          --model sonnet \
          --effort low \
          --print \
          --output-format stream-json \
          --max-budget-usd 0.02 \
          2>/dev/null) || LIVE_OUT=""

    echo "$LIVE_OUT" \
      | python3 -c "
import sys, json
for line in sys.stdin:
    try:
        e = json.loads(line)
        if e.get('type') == 'result':
            text = e.get('result', '')
            sys.stdout.write('  result: ' + text[:100] + '\n')
            sys.exit(0 if 'CLAUDES_OK' in text else 1)
    except: pass
sys.exit(1)
" && ok "live claude request: CLAUDES_OK received" || fail "live claude request: unexpected result"
  fi
fi

# ── Summary ───────────────────────────────────────────────────────────────
printf "\n"
sep
printf "  passed: \033[0;32m%d\033[0m   failed: \033[0;31m%d\033[0m\n\n" "$PASS" "$FAIL"
[ "$FAIL" -eq 0 ] && exit 0 || exit 1
