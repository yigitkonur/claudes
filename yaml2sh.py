#!/usr/bin/env python3
"""yaml2sh.py — convert claudes.yaml to zsh-sourceable or JSON output.

Usage:
  python3 yaml2sh.py <path/to/claudes.yaml>          # zsh output (default)
  python3 yaml2sh.py --json <path/to/claudes.yaml>   # JSON output (for configure.sh)

Exit 0 on success, 1 on parse error (message to stderr).
"""

import sys
import os
import json
import re

# ── YAML parser ───────────────────────────────────────────────────────────
# Try pyyaml first (available on most dev machines).
# Fall back to our minimal stdlib parser for the specific subset we use.

def _parse_with_pyyaml(text):
    import yaml  # noqa: PLC0415
    return yaml.safe_load(text)


def _strip_inline_comment(s):
    """Remove trailing # comment from an unquoted value."""
    # Don't strip if the # is inside quotes
    in_single = False
    in_double = False
    for i, c in enumerate(s):
        if c == "'" and not in_double:
            in_single = not in_single
        elif c == '"' and not in_single:
            in_double = not in_double
        elif c == '#' and not in_single and not in_double:
            return s[:i].rstrip()
    return s


def _unquote(s):
    """Strip surrounding quotes from a scalar value."""
    s = s.strip()
    if (s.startswith('"') and s.endswith('"')) or \
       (s.startswith("'") and s.endswith("'")):
        return s[1:-1]
    return s


def _parse_flow_list(s):
    """Parse a flow-style YAML list like [a, b, c] or ["x y", z]."""
    s = s.strip()
    if not (s.startswith('[') and s.endswith(']')):
        return None
    inner = s[1:-1]
    if not inner.strip():
        return []
    items = []
    for item in re.split(r',\s*(?=(?:[^"\']*["\'][^"\']*["\'])*[^"\']*$)', inner):
        items.append(_unquote(item.strip()))
    return items


def _parse_minimal(text):
    """Minimal parser for the claudes.yaml subset.

    Handles:
    - Comments (# anywhere on line)
    - Top-level keys: ux, presets, remove_builtins
    - Nested dicts (2-space indent)
    - Doubly-nested dicts (4-space indent) — for preset.env
    - Flow lists: [a, b, c]
    - Block lists: "- item"
    - Quoted and unquoted scalar values
    """
    lines = text.splitlines()
    result = {}
    # State
    top_key = None        # e.g. "ux", "presets"
    mid_key = None        # e.g. "plan", "standard" (under presets)
    low_key = None        # e.g. "env" (under presets.plan)
    in_block_list = None  # (result_dict, key) when collecting a block list

    def indent_of(line):
        return len(line) - len(line.lstrip())

    for raw in lines:
        line = raw.rstrip()

        # Skip blank lines and full-line comments
        stripped = line.lstrip()
        if not stripped or stripped.startswith('#'):
            in_block_list = None
            continue

        ind = indent_of(line)
        stripped = _strip_inline_comment(stripped)

        # Block list item
        if stripped.startswith('- '):
            if in_block_list is not None:
                d, k = in_block_list
                d[k].append(_unquote(stripped[2:].strip()))
            continue

        # Not a list item — close any open block list
        in_block_list = None

        if ':' not in stripped:
            continue

        key, _, rest = stripped.partition(':')
        key = key.strip()
        rest = rest.strip()

        if ind == 0:
            top_key = key
            mid_key = None
            low_key = None
            if rest == '':
                result[top_key] = {} if top_key != 'remove_builtins' else []
                if top_key == 'remove_builtins':
                    in_block_list = (result, top_key)
            elif rest.startswith('['):
                parsed = _parse_flow_list(rest)
                result[top_key] = parsed if parsed is not None else []
            else:
                result[top_key] = _unquote(rest)

        elif ind == 2:
            if top_key is None:
                continue
            mid_key = key
            low_key = None
            if not isinstance(result.get(top_key), dict):
                result[top_key] = {}
            if rest == '':
                result[top_key][mid_key] = {}
            elif rest.startswith('['):
                parsed = _parse_flow_list(rest)
                result[top_key][mid_key] = parsed if parsed is not None else []
                in_block_list = None
            elif rest == '[]':
                result[top_key][mid_key] = []
            else:
                result[top_key][mid_key] = _unquote(rest)

        elif ind == 4:
            if top_key is None or mid_key is None:
                continue
            low_key = key
            if not isinstance(result.get(top_key, {}).get(mid_key), dict):
                if not isinstance(result.get(top_key), dict):
                    result[top_key] = {}
                result[top_key][mid_key] = {}
            if rest == '':
                result[top_key][mid_key][low_key] = {}
                in_block_list = (result[top_key][mid_key], low_key)
                result[top_key][mid_key][low_key] = []
            elif rest.startswith('['):
                parsed = _parse_flow_list(rest)
                result[top_key][mid_key][low_key] = parsed if parsed is not None else []
            else:
                result[top_key][mid_key][low_key] = _unquote(rest)

        elif ind == 6:
            # env sub-keys under presets.<name>.env
            if top_key is None or mid_key is None or low_key is None:
                continue
            parent = result.get(top_key, {}).get(mid_key, {})
            if not isinstance(parent.get(low_key), dict):
                parent[low_key] = {}
            parent[low_key][key] = _unquote(rest)

    return result


def load_yaml(path):
    with open(path, 'r') as f:
        text = f.read()
    try:
        return _parse_with_pyyaml(text)
    except ImportError:
        return _parse_minimal(text)


# ── Shell quoting ─────────────────────────────────────────────────────────

def _sh_quote(s):
    """Single-quote a string for safe zsh sourcing."""
    # Replace ' with '\'' to safely embed in single-quoted string
    return "'" + str(s).replace("'", "'\\''") + "'"


# ── Renderer ──────────────────────────────────────────────────────────────

def render_zsh(data):
    lines = []

    ux = data.get('ux') or {}
    order = ux.get('order') or []
    default = ux.get('default') or ''
    remap = ux.get('remap') or ''

    if order:
        if isinstance(order, list):
            lines.append('CLAUDES_ORDER=(%s)' % ' '.join(order))
        else:
            lines.append('CLAUDES_ORDER=(%s)' % order)
    if default:
        lines.append('CLAUDES_DEFAULT=%s' % default)
    if remap:
        lines.append('CLAUDES_REMAP_CLAUDE=%s' % remap)

    presets = data.get('presets') or {}
    for name, cfg in presets.items():
        if not isinstance(cfg, dict):
            continue
        flags = cfg.get('flags') or ''
        desc = cfg.get('description') or ''
        alias = cfg.get('alias') or ''
        prompt = cfg.get('prompt') or ''
        mcp = cfg.get('mcp') or ''
        env = cfg.get('env') or {}

        if flags:
            lines.append("CLAUDES_PRESETS[%s]=%s" % (name, _sh_quote(flags)))
        if desc:
            lines.append("CLAUDES_DESCRIPTIONS[%s]=%s" % (name, _sh_quote(desc)))
        if alias:
            lines.append("CLAUDES_ALIASES[%s]=%s" % (alias, name))
        if prompt:
            lines.append("CLAUDES_PROMPT[%s]=%s" % (name, _sh_quote(prompt)))
        if mcp:
            # Expand leading ~ so zsh doesn't need to
            expanded = os.path.expanduser(mcp)
            lines.append("CLAUDES_MCP[%s]=%s" % (name, _sh_quote(expanded)))
        if env and isinstance(env, dict):
            # CLAUDES_ENV[name] uses space-separated KEY=val pairs (existing format)
            pairs = ' '.join('%s=%s' % (k, v) for k, v in env.items())
            lines.append("CLAUDES_ENV[%s]=%s" % (name, _sh_quote(pairs)))

    remove = data.get('remove_builtins') or []
    if isinstance(remove, list):
        for name in remove:
            lines.append("unset 'CLAUDES_PRESETS[%s]'" % name)
            lines.append("unset 'CLAUDES_DESCRIPTIONS[%s]'" % name)

    return '\n'.join(lines)


def render_json(data):
    return json.dumps(data, indent=2)


# ── Main ──────────────────────────────────────────────────────────────────

def main():
    args = sys.argv[1:]
    output_json = False

    if '--json' in args:
        output_json = True
        args = [a for a in args if a != '--json']

    if not args:
        print("usage: yaml2sh.py [--json] <claudes.yaml>", file=sys.stderr)
        sys.exit(1)

    path = args[0]
    if not os.path.exists(path):
        print("yaml2sh: file not found: %s" % path, file=sys.stderr)
        sys.exit(1)

    try:
        data = load_yaml(path)
    except Exception as e:
        print("yaml2sh: parse error in %s: %s" % (path, e), file=sys.stderr)
        sys.exit(1)

    if data is None:
        data = {}

    if output_json:
        print(render_json(data))
    else:
        out = render_zsh(data)
        if out:
            print(out)


if __name__ == '__main__':
    main()
