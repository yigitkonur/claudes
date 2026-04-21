# claudes — Claude Code preset picker for zsh

> **Model, effort, permission mode, MCP servers, system prompts, tool subsets, env vars — all bundled into named presets you can launch with a single command.** Zero dependencies beyond zsh and the Claude Code CLI.

[![Shell](https://img.shields.io/badge/shell-zsh-89e051?style=flat-square)](https://www.zsh.org/)
[![Claude Code](https://img.shields.io/badge/Claude_Code-compatible-f97316?style=flat-square)](https://claude.com/claude-code)
[![Platform](https://img.shields.io/badge/platform-macOS_|_Linux-000000?style=flat-square)](#)
[![License](https://img.shields.io/badge/license-MIT-blue?style=flat-square)](LICENSE)

```
  Choose Claude preset:

    1) standard   (s)  · Sonnet 4.6 · max effort · daily coding work
    2) quick      (q)  · Sonnet 4.6 · low effort · fast/cheap edits
    3) plan       (p)  · Opus 4.7 · max · plan mode · deep thinking
    4) research   (r)  · Opus 4.7 · max · direct · explore/review
    5) review     (rv) · Sonnet · low · read-only PR/code review         [+prompt]
    6) rmcp       (rm) · Opus · max · strict research MCP · grounded     [+mcp +prompt]
    7) wt              · Opus · max · -w --tmux · parallel agent         [fn]

  > _
```

---

## Why `claudes` exists

Claude Code's `settings.json` supports a single baseline `model`, `effortLevel`, and `defaultMode`. Real work doesn't fit one baseline:

- **Fast mechanical edits** want Sonnet with low effort, no plan-first ceremony
- **Complex features** want Opus with max effort and plan mode
- **Code review** wants a model that *can't* edit files and an MCP set that's scoped to the task
- **Research** wants a system prompt that forbids fabrication and only the research MCP loaded
- **CI/scripts** want `--print --bare --output-format stream-json` piped into `jq`
- **Offline / hotel wifi** wants zero MCP, zero skills, zero WebFetch

`claudes` is a ~200-line zsh function that bundles **seven dimensions of config** into named presets — model, effort, permission-mode, MCP set, system-prompt addendum, env vars, and an escape-hatch function form — then launches Claude with exactly the right flags. Picker when you forget; alias when you don't; pass-through for everything else.

## Keywords

Claude Code CLI launcher · zsh preset manager · Anthropic Claude model switcher · MCP config switcher · append-system-prompt preset · tool scoping · effort level selector · plan mode toggle · Sonnet Opus picker · --bare mode · CI/headless Claude · --from-pr session · worktree automation · dotfiles · developer productivity

---

## Install

### One-liner

```bash
curl -fsSL https://raw.githubusercontent.com/yigitkonur/claudes/main/install.sh | bash
```

### Manual

```bash
git clone https://github.com/yigitkonur/claudes.git
cd claudes
./install.sh
```

### What `install.sh` does

1. Copies `claudes.zsh` to `~/.local/share/claudes/claudes.zsh`
2. If you have `~/.zshrc.d/`, symlinks it as `~/.zshrc.d/90-claudes.zsh`
3. Otherwise appends a `source` line to `~/.zshrc`
4. Creates an empty user-config at `~/.config/claudes/presets.zsh`

Nothing in your shell config is overwritten. Re-running is safe.

---

## Usage

```bash
claudes                 # interactive picker
claudes standard        # run a named preset
claudes s               # same, via alias
claudes plan --resume   # pass extra args through to claude
claudes list            # show all presets (built-in + yours)
claudes show research   # dry-run: print resolved config without launching
claudes help            # full help
```

### Built-in presets

| Preset | Alias | Model | Effort | Permission Mode | When to use |
|--------|-------|-------|--------|-----------------|-------------|
| `standard` | `s` | Sonnet 4.6 | max | default | Daily coding work |
| `quick` | `q` | Sonnet 4.6 | low | default | Fast/cheap edits, trivial ops |
| `plan` | `p` | Opus 4.7 | max | **plan** | Deep thinking, complex tasks |
| `research` | `r` | Opus 4.7 | max | default | Code review, architecture, exploration |

> **Why non-plan presets pin `--permission-mode default`:** Claude Code CLI flags beat `settings.json`. If you've set `defaultMode: "plan"` in `~/.claude/settings.json`, every session would otherwise start in plan mode. The explicit flag overrides it.

---

## What you can put in a preset

A preset isn't just a string of CLI flags. Five independent dimensions:

| Registry | Type | Injects | Example |
|---|---|---|---|
| `CLAUDES_PRESETS[name]` | flag string, or `fn:<func>` | the command itself | `"--model sonnet --effort max"` |
| `CLAUDES_DESCRIPTIONS[name]` | string | picker listing | `"Sonnet · max · daily"` |
| `CLAUDES_ALIASES[short]` | string | short alias | `s → standard` |
| `CLAUDES_ENV[name]` | `"K=v K2=v2"` | env exported before launch | `"CLAUDE_CODE_MAX_OUTPUT_TOKENS=16000"` |
| `CLAUDES_MCP[name]` | path to JSON | `--mcp-config <path>` | `"~/.config/claudes/mcp/research.json"` |
| `CLAUDES_PROMPT[name]` | string | `--append-system-prompt <str>` | `"Read-only review mode."` |

All registries except `CLAUDES_PRESETS` are optional. Missing keys are no-ops. The picker and `claudes list` show compact markers so you can see which extras a preset carries at a glance:

```
5) review     (rv) · Sonnet · low · read-only PR/code review         [+prompt]
6) rmcp       (rm) · Opus · max · strict research MCP · grounded     [+mcp +prompt]
7) wt              · Opus · max · -w --tmux · parallel agent         [fn]
```

### Function-form presets (the escape hatch)

Sometimes a flag string isn't enough — you want to spawn a worktree, resolve a PR number from `gh`, `cd` somewhere first, or branch on an argument. Use the `fn:` form:

```zsh
_my_worktree() {
  local name="${1:-feat-$(date +%s)}"; shift 2>/dev/null || true
  command claude -w "$name" --tmux --model opus --effort max "$@"
}

CLAUDES_PRESETS[wt]="fn:_my_worktree"
CLAUDES_DESCRIPTIONS[wt]="Opus · max · -w --tmux · parallel agent"
```

`CLAUDES_ENV` still applies to `fn:` presets (runs inside a subshell so exports don't leak). `CLAUDES_MCP` and `CLAUDES_PROMPT` are ignored — the function is expected to handle those itself if it wants them.

### Custom presets: minimum viable

Edit `~/.config/claudes/presets.zsh`:

```zsh
CLAUDES_PRESETS[mine]="--model sonnet --effort high"
CLAUDES_DESCRIPTIONS[mine]="my daily driver"
CLAUDES_ALIASES[m]=mine
```

Full single-dimension and multi-dimension examples:

```zsh
# Read-only review mode
CLAUDES_PRESETS[review]="--model sonnet --effort low --tools Read,Grep,Glob,Bash"
CLAUDES_DESCRIPTIONS[review]="Sonnet · low · read-only review"
CLAUDES_ALIASES[rv]=review
CLAUDES_PROMPT[review]="You are in read-only review mode. Do not edit files."

# Grounded-research with a dedicated MCP set and token budget
CLAUDES_PRESETS[rmcp]="--model opus --effort max --strict-mcp-config"
CLAUDES_DESCRIPTIONS[rmcp]="Opus · max · strict research MCP"
CLAUDES_MCP[rmcp]="$HOME/.config/claudes/mcp/research-only.json"
CLAUDES_PROMPT[rmcp]="Cite every non-trivial claim from a scraped source. No fabrication."
CLAUDES_ENV[rmcp]="CLAUDE_CODE_MAX_OUTPUT_TOKENS=32000"
```

### Remove a built-in

```zsh
unset 'CLAUDES_PRESETS[research]'
unset 'CLAUDES_DESCRIPTIONS[research]'
unset 'CLAUDES_ALIASES[r]'
```

---

## Ready-to-copy recipes

The [`examples/`](examples) directory ships eight curated recipes. Copy the block you want into `~/.config/claudes/presets.zsh`.

| File | Preset | Shape | Real use case |
|---|---|---|---|
| [`review.zsh`](examples/review.zsh) | `review` | Sonnet low + read-only tools + no-edits prompt | PR walkthroughs, code-only scoping |
| [`cheap.zsh`](examples/cheap.zsh) | `cheap` | Sonnet low + `--bare` | Single-file ops, throwaway questions (~30-50% fewer tokens) |
| [`ci.zsh`](examples/ci.zsh) | `ci` | `--print --output-format stream-json --bare --max-budget-usd 1` | Local scripts, pipes into `jq` |
| [`research-mcp.zsh`](examples/research-mcp.zsh) | `rmcp` | Opus max + strict MCP + anti-fabrication prompt | Grounded research runs |
| [`offline.zsh`](examples/offline.zsh) | `offline` | `--bare` + no MCP + no slash commands + no WebFetch/Search | Airplane / hotel wifi |
| [`audit.zsh`](examples/audit.zsh) | `audit` | Opus max + read-only tools + audit-rubric prompt | Security / compliance walks |
| [`worktree.zsh`](examples/worktree.zsh) | `wt` | `fn:` — spawns `-w <name> --tmux` | Parallel agents on one repo |
| [`pr.zsh`](examples/pr.zsh) | `pr` | `fn:` — resolves PR via `gh`, then `--from-pr` | Resume PR-linked sessions |

And a template MCP file at [`examples/mcp/research-only.json`](examples/mcp/research-only.json) for presets that use `CLAUDES_MCP[...]`.

---

## How It Works

`claudes` stores presets in zsh associative arrays:

```zsh
typeset -gA CLAUDES_PRESETS CLAUDES_DESCRIPTIONS CLAUDES_ALIASES \
            CLAUDES_ENV CLAUDES_MCP CLAUDES_PROMPT
```

On invocation:
1. If no argument, prints a numbered menu and reads your choice
2. Resolves the preset (aliases → canonical key)
3. If `fn:<name>` — calls that zsh function with the pass-through args, optionally under a subshell with `CLAUDES_ENV` exported
4. Otherwise — builds a flag vector from the string, appends `--mcp-config` / `--append-system-prompt` if the sibling registries are set, prepends an `env KEY=VAL` prefix if `CLAUDES_ENV` is set, then runs `command claude` with the whole vector

Your `~/.config/claudes/presets.zsh` is sourced after the defaults, so user config wins.

### CLI Flag Precedence

Load-bearing insight. Claude Code resolves configuration in this order (highest wins):

1. **CLI flags** (`--model`, `--effort`, `--permission-mode`, `--mcp-config`, `--append-system-prompt`, …) ← what `claudes` uses
2. **Environment variables** (`ANTHROPIC_MODEL`, etc.)
3. **`~/.claude/settings.json`**
4. **Managed/enterprise settings**

Because CLI flags win, `claudes` overrides your `settings.json` baseline cleanly without mutating any files at runtime. Each preset is self-contained.

### The "settings.json mutation" anti-pattern

An earlier design rewrote `settings.json` from a hook to swap Opus → Sonnet after plan approval. It was unreliable — Claude Code does not consistently re-read `settings.json` between turns, especially within a single tool call. Picking the right config at launch via `claudes` avoids the problem entirely.

---

## Why not just aliases?

You could write `alias quick='claude --model sonnet --effort low'` and skip this tool. That works for 2–3 presets. `claudes` scales better:

- Six registries, not one string — MCP paths need existence checks, prompts have quoting, env vars need export timing
- Single picker when you forget the names
- One place to inspect all your presets (`claudes list` / `claudes show`)
- Pass-through args without wrestling with zsh alias quoting
- Config file with documented structure — easy to sync across machines and dotfiles
- Markers (`[fn] [+mcp] [+prompt]`) so you remember which preset does what without cat-ing the file

If three aliases are enough for you, three aliases are enough.

---

## Requirements

- **zsh 5.0+** — uses associative arrays and parameter expansion features
- **Claude Code CLI 2.1+** — `npm install -g @anthropic-ai/claude-code`
- macOS or Linux

Bash is not supported. The function is small enough to port in an hour if you want.

---

## Configuration Reference

### Registries

| Variable | Type | Purpose |
|----------|------|---------|
| `CLAUDES_PRESETS[name]` | string | CLI flags passed to `claude`, OR `fn:<zsh_func>` for function-form |
| `CLAUDES_DESCRIPTIONS[name]` | string | One-line description for the picker |
| `CLAUDES_ALIASES[short]` | string | Map short alias → preset name |
| `CLAUDES_ENV[name]` | string | Space-separated `KEY=value` pairs, exported before launch |
| `CLAUDES_MCP[name]` | string | Path to a JSON file; passed as `--mcp-config <path>` (tilde expansion supported) |
| `CLAUDES_PROMPT[name]` | string | Appended via `--append-system-prompt` |

Assign with `CLAUDES_PRESETS[foo]="..."`, unset with `unset 'CLAUDES_PRESETS[foo]'`.

### Files

| File | Purpose |
|------|---------|
| `~/.local/share/claudes/claudes.zsh` | The installed function |
| `~/.config/claudes/presets.zsh` | Your custom presets (sourced after defaults) |
| `~/.config/claudes/mcp/*.json` | Convention: MCP config files referenced by `CLAUDES_MCP[...]` |
| `~/.zshrc.d/90-claudes.zsh` | Symlink that auto-loads the function (if dir exists) |

### Commands

| Command | Behavior |
|---|---|
| `claudes` | Interactive numbered picker |
| `claudes <preset>` | Launch a preset (resolves aliases) |
| `claudes <preset> [args...]` | Launch with extra args passed to `claude` |
| `claudes list` / `claudes ls` | List all presets with extras markers |
| `claudes show <preset>` | Dry-run: print the resolved config |
| `claudes help` | Full help |

---

## Uninstall

```bash
rm -rf ~/.local/share/claudes
rm -f ~/.zshrc.d/90-claudes.zsh
# If installed via zshrc append, remove the block starting with:
#   # claudes — https://github.com/yigitkonur/claudes
```

`~/.config/claudes/` is left alone so you don't lose your presets.

---

## Contributing

PRs welcome for:

- Additional useful recipes under `examples/` (keep built-ins at four)
- Bash port as a sibling file
- Better interactive picker (optional `fzf` integration)
- Docs improvements

Open an issue first for larger changes. See [CONTRIBUTING.md](CONTRIBUTING.md).

---

## Related

- **[Claude Code](https://claude.com/claude-code)** — The CLI this tool wraps.
- **[RTK](https://github.com/rtk-ai/rtk)** — Token-savings proxy for LLM CLIs. Complementary.
- **[awesome-claude-code](https://github.com/hesreallyhim/awesome-claude-code)** — Curated list where this tool lives.

---

## License

MIT © Yigit Konur. See [LICENSE](LICENSE).
