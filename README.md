# claudes

> one command, everything you need to swap between claude code configs. model, effort, permission mode, mcp servers, system prompts, env vars — all in a named preset. zero deps beyond zsh and the [claude code](https://claude.com/claude-code) cli.

[![shell](https://img.shields.io/badge/shell-zsh-89e051?style=flat-square)](https://www.zsh.org/)
[![claude code](https://img.shields.io/badge/claude_code-compatible-f97316?style=flat-square)](https://claude.com/claude-code)
[![platform](https://img.shields.io/badge/platform-macOS_|_Linux-000000?style=flat-square)](#)
[![license](https://img.shields.io/badge/license-MIT-blue?style=flat-square)](LICENSE)

---

what the picker looks like out of the box:

```
  Choose Claude preset:

    1) standard  (s)  · Sonnet 4.6 · max effort · daily coding work
    2) quick     (q)  · Sonnet 4.6 · low effort · fast/cheap edits
    3) plan      (p)  · Opus 4.7 · max effort · plan mode · deep thinking
    4) research  (r)  · Opus 4.7 · max effort · direct · explore/review

  > _
```

four built-in presets. you pick from the menu or type a name/alias directly. that's the default experience.

**after you add your own presets from the [`examples/`](examples/) folder**, it looks more like this — your custom ones slot in numbered after the built-ins:

```
  Choose Claude preset:

    1) plan      (p)  · Opus 4.7 · max effort · plan mode · auto-approved
    2) max       (m)  · Opus 4.7 · max effort · skip permissions · yolo
    3) standard  (s)  · Sonnet 4.6 · auto effort · skip permissions · daily
    4) quick     (q)  · Sonnet 4.6 · low effort · skip permissions · fast
    5) review    (rv) · Sonnet · low · read-only PR/code review          [+prompt]
    6) rmcp      (rm) · Opus · max · strict research MCP · grounded      [+mcp +prompt]
    7) wt             · Opus · max · -w --tmux · parallel agent          [fn]

  > [enter = standard] _
```

items 5–7 are custom presets the user copied from `examples/`. items marked `[+prompt]`, `[+mcp]`, `[fn]` have extras attached — more on that [below](#the-six-dimensions). the `[enter = standard]` prompt and single-key selection come from the optional [enhanced ux layer](#enhanced-ux--single-key-picker).

---

## contents

1. [the pitch](#the-pitch)
2. [install](#install)
3. [quick tour](#quick-tour)
4. [built-in presets](#built-in-presets)
5. [the six dimensions](#the-six-dimensions)
6. [custom presets — how to add your own](#custom-presets--how-to-add-your-own)
7. [example presets to steal](#example-presets-to-steal)
8. [function-form presets — the escape hatch](#function-form-presets--the-escape-hatch)
9. [enhanced ux — single-key picker](#enhanced-ux--single-key-picker)
10. [hooks integration — auto-approve plans](#hooks-integration--auto-approve-plans)
11. [cli flag precedence](#cli-flag-precedence)
12. [reference](#reference)
13. [requirements, uninstall, contributing](#requirements)

---

## the pitch

`settings.json` holds one model, one effortLevel, one defaultMode. real work doesn't fit one baseline.

you want sonnet-fast for mechanical edits, opus-deep for architecture, plan mode when you're scoping a feature, a read-only tool subset for PR review, a completely different mcp server set for grounded research, and `--bare` when you're offline. you could paste 80-char flag strings on every launch. you'll stop doing that after two days.

`claudes` stores named presets as zsh associative-array entries. one line per dimension. shows a numbered picker when you forget names. resolves short aliases (`s`, `q`, `p`). passes every extra arg through transparently. no config file format, no dsl. you edit zsh. that's the whole api.

---

## install

```bash
curl -fsSL https://raw.githubusercontent.com/yigitkonur/claudes/main/install.sh | bash
```

or clone first if you want to inspect before running:

```bash
git clone https://github.com/yigitkonur/claudes.git
cd claudes && ./install.sh
```

the installer is interactive — it'll ask you four things:

1. **core install** — copies `claudes.zsh`, symlinks into `~/.zshrc.d/` or appends to `.zshrc`
2. **enhanced ux** — optional: single-key picker, `claude` → `claudes` remap, `enter = default` preset, `claude1..4` shortcuts (see [enhanced ux](#enhanced-ux--single-key-picker))
3. **preset scheme** — pick the recommended 4-slot scheme, keep built-in defaults, configure custom interactively, or skip
4. **finishing up** — writes config files, installs `configure.sh` for `claudes config`

re-running is safe. nothing gets overwritten without asking.

---

## quick tour

```bash
claudes                   # numbered picker — pick with enter
claudes standard          # launch directly by preset name
claudes s                 # same, via alias
claudes plan --resume     # preset + pass extra flags through to claude
claudes list              # show all presets with markers
claudes show research     # dry-run: print resolved flags without launching
claudes config            # interactive preset & ux manager
claudes config presets    # manage presets only
claudes config ux         # order, default preset, remap settings
claudes help              # full help
```

---

## built-in presets

four presets ship with `claudes.zsh`. they're intentionally minimal — real customization goes in your `~/.config/claudes/presets.zsh`.

| preset | alias | model | effort | mode | when to use |
|---|---|---|---|---|---|
| `standard` | `s` | sonnet 4.6 | max | default | daily coding, general work |
| `quick` | `q` | sonnet 4.6 | low | default | fast/cheap edits, trivial ops |
| `plan` | `p` | opus 4.7 | max | **plan** | complex scoping, deep thinking |
| `research` | `r` | opus 4.7 | max | default | code review, architecture, explore |

> **heads up on permission mode:** the built-ins explicitly pass `--permission-mode default`. if you've set `defaultMode: "plan"` in `~/.claude/settings.json` — common for power users — every launch would otherwise default to plan mode. the explicit flag overrides that. covered in full under [cli flag precedence](#cli-flag-precedence).

---

## the six dimensions

a preset can have any combination of these. only `CLAUDES_PRESETS[name]` is required.

### 1. `CLAUDES_PRESETS[name]` — the flags (required)

a string of cli flags, or a `fn:` sentinel for function-form presets:

```zsh
CLAUDES_PRESETS[mine]="--model sonnet --effort high --permission-mode acceptEdits"
```

anything `claude --help` recognizes works here: `--model`, `--effort`, `--permission-mode`, `--tools`, `--allowedTools`, `--disallowedTools`, `--dangerously-skip-permissions`, `--bare`, `--print`, `--max-budget-usd`, etc.

### 2. `CLAUDES_DESCRIPTIONS[name]` — picker label

one line, shows up in the picker and `claudes list`:

```zsh
CLAUDES_DESCRIPTIONS[mine]="Sonnet · high · my daily driver"
```

### 3. `CLAUDES_ALIASES[short]` — shortcut key

single-char or short string → preset name:

```zsh
CLAUDES_ALIASES[m]=mine   # claudes m now works
```

### 4. `CLAUDES_ENV[name]` — env vars

space-separated `KEY=value` pairs, exported into the claude process only — nothing leaks back to your shell:

```zsh
CLAUDES_ENV[bigctx]="CLAUDE_CODE_MAX_OUTPUT_TOKENS=32000 MAX_THINKING_TOKENS=48000"
```

useful for token budget knobs, `CLAUDE_ORCHESTRATOR=1`, provider-specific vars, anything that's not a cli flag.

### 5. `CLAUDES_MCP[name]` — a scoped mcp server set

path to a `.mcp.json`-shaped file. `claudes` expands `~`, checks the file exists, then passes `--mcp-config <path>`:

```zsh
CLAUDES_MCP[research]="$HOME/.config/claudes/mcp/research-only.json"
```

combine with `--strict-mcp-config` in the flags to load *only* that file's servers (ignores global mcp config). useful when you want a preset that talks to exactly one mcp and nothing else.

### 6. `CLAUDES_PROMPT[name]` — system-prompt addendum

string appended via `--append-system-prompt`. cheapest way to scope behavior per-preset:

```zsh
CLAUDES_PROMPT[review]="You are in read-only review mode. Do not edit files."
```

---

## custom presets — how to add your own

edit `~/.config/claudes/presets.zsh`. sourced after the built-ins, so your entries override them.

a minimum viable preset:

```zsh
CLAUDES_PRESETS[mine]="--model sonnet --effort high"
CLAUDES_DESCRIPTIONS[mine]="Sonnet · high · my daily driver"
CLAUDES_ALIASES[m]=mine
```

a richer one:

```zsh
# grounded research — opus, strict mcp, anti-fabrication prompt, bigger output budget
CLAUDES_PRESETS[rmcp]="--model opus --effort max --strict-mcp-config"
CLAUDES_DESCRIPTIONS[rmcp]="Opus · max · strict research mcp"
CLAUDES_ALIASES[rm]=rmcp
CLAUDES_MCP[rmcp]="$HOME/.config/claudes/mcp/research-only.json"
CLAUDES_PROMPT[rmcp]="Cite every non-trivial claim from a scraped source. No fabrication."
CLAUDES_ENV[rmcp]="CLAUDE_CODE_MAX_OUTPUT_TOKENS=32000"
```

to remove a built-in you don't want:

```zsh
unset 'CLAUDES_PRESETS[research]'
unset 'CLAUDES_DESCRIPTIONS[research]'
```

to see what a preset resolves to without launching:

```bash
claudes show rmcp
# preset:       rmcp
# flags:        --model opus --effort max --strict-mcp-config
# mcp-config:   /Users/you/.config/claudes/mcp/research-only.json
# prompt:       Cite every non-trivial claim from a scraped source...
# env:          CLAUDE_CODE_MAX_OUTPUT_TOKENS=32000
```

**interactive manager** — instead of editing the file by hand, run `claudes config presets`. it'll walk you through model/effort/mode, generate the flags, and write the entry for you.

---

## example presets to steal

the [`examples/`](examples/) folder has eight ready-to-copy presets. copy the block you want into `~/.config/claudes/presets.zsh` — or let `claudes config presets` do it via the guided wizard.

| file | preset | what it does |
|---|---|---|
| [`review.zsh`](examples/review.zsh) | `review` | sonnet low + read-only tools + no-edits prompt — pr walkthroughs |
| [`cheap.zsh`](examples/cheap.zsh) | `cheap` | sonnet low + `--bare` — single-file ops, fewer tokens |
| [`ci.zsh`](examples/ci.zsh) | `ci` | `--print --output-format stream-json --bare --max-budget-usd 1` — local scripts piping to `jq` |
| [`research-mcp.zsh`](examples/research-mcp.zsh) | `rmcp` | opus max + strict mcp + anti-fabrication prompt — grounded research |
| [`offline.zsh`](examples/offline.zsh) | `offline` | `--bare` + no mcp + no web tools — airplane mode |
| [`audit.zsh`](examples/audit.zsh) | `audit` | opus max + read-only tools + audit rubric prompt — security walks |
| [`worktree.zsh`](examples/worktree.zsh) | `wt` | `fn:` — spawns `-w <name> --tmux` for parallel agents |
| [`pr.zsh`](examples/pr.zsh) | `pr` | `fn:` — resolves pr via `gh`, then `--from-pr` to resume |

plus [`examples/mcp/research-only.json`](examples/mcp/research-only.json) — mcp config template for `CLAUDES_MCP[...]`.

---

## function-form presets — the escape hatch

flag strings can't express everything. some presets need to resolve a pr number from `gh`, pick a worktree name, cd somewhere, or branch on an argument. for those, use the `fn:` form.

define a zsh function, then point a preset at it:

```zsh
_claudes_preset_worktree() {
  local name="${1:-feat-$(date +%s)}"
  shift 2>/dev/null || true
  command claude -w "$name" --tmux --model opus --effort max "$@"
}

CLAUDES_PRESETS[wt]="fn:_claudes_preset_worktree"
CLAUDES_DESCRIPTIONS[wt]="Opus · max · -w --tmux · parallel agent"
```

```bash
claudes wt feature-auth             # named worktree
claudes wt                          # auto-named feat-<timestamp>
claudes wt refactor-db "start by…"  # name + initial prompt
```

`CLAUDES_ENV` still runs for `fn:` presets (in a subshell). `CLAUDES_MCP` and `CLAUDES_PROMPT` are ignored — the function owns those if it needs them.

---

## enhanced ux — single-key picker

install the ux layer for a faster daily workflow. the installer asks about this in step 2, or install manually:

```bash
# already ran the installer — just answer Y when it asks about enhanced ux
# manual install:
curl -fsSL https://raw.githubusercontent.com/yigitkonur/claudes/main/ux.zsh \
  -o ~/.local/share/claudes/ux.zsh
ln -sf ~/.local/share/claudes/ux.zsh ~/.zshrc.d/91-claudes-ux.zsh
```

what it adds:

**single-key selection** — no Enter needed in the picker. press `1`, `2`, `s`, `p` and it launches immediately. much faster than typing the full name.

**bare enter = default preset** — configure which preset Enter selects (default: `standard`). the picker shows `[enter = standard]` as a reminder.

**`claude1` .. `claude9`** — jump straight to the nth preset from the cli:
```bash
claude1   # → 1st preset in your order
claude3   # → 3rd preset
```

**`claude` → `claudes` remap** — typing `claude` opens the preset picker instead of the raw cli. configurable: warp-only (recommended), all terminals, or disabled.

configure all of this interactively:

```bash
claudes config ux
```

or edit `~/.config/claudes/ux-settings.zsh` directly:

```zsh
CLAUDES_ORDER=(plan max standard quick)   # picker slot order
CLAUDES_DEFAULT=standard                  # bare enter picks this
CLAUDES_REMAP_CLAUDE=warp                 # warp | all | none
```

---

## hooks integration — auto-approve plans

if you use plan mode (`claudes plan`), you probably want plan approvals auto-approved so you don't have to click through the permission prompt every time. the [`hooks-claude-code`](https://github.com/yigitkonur/hooks-claude-code) repo ships a hook for exactly this.

install it:

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/yigitkonur/hooks-claude-code/main/install.sh)
```

the installer asks you to pick a mode:

- **classic** — auto-approve plan exits instantly and silently. simple.
- **orchestrator** — auto-approve + inject a directive that makes claude execute plans step-by-step with strict completion criteria. better for complex multi-step tasks.

what happens under the hood: the hook wires into the `ExitPlanMode` `PermissionRequest` event in `~/.claude/settings.json`. whenever claude asks "ok to proceed?", the hook fires and approves automatically.

once installed, a preset like:

```zsh
CLAUDES_PRESETS[plan]="--model opus --effort max --permission-mode plan"
```

becomes a fully automated deep-thinking loop — plan → auto-approve → execute, no manual intervention.

uninstall:

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/yigitkonur/hooks-claude-code/main/uninstall.sh)
```

---

## cli flag precedence

the load-bearing mechanic behind all of this. claude code resolves config in this order, highest wins:

1. **cli flags** (`--model`, `--effort`, `--permission-mode`, etc.) ← what `claudes` uses
2. **env vars** (`ANTHROPIC_MODEL`, `CLAUDE_CODE_MAX_OUTPUT_TOKENS`, etc.)
3. **`~/.claude/settings.json`**
4. **managed/enterprise settings**

because cli flags win, a preset overrides your `settings.json` baseline without touching any files. two sessions with different presets don't interfere.

**anti-pattern to avoid:** don't mutate `settings.json` at runtime to swap models mid-session. it doesn't work reliably — claude code doesn't consistently re-read it between turns. pick the right config at launch via `claudes`. there's also a known bug with the `opusplan` model alias where it [runs sonnet in both phases](https://github.com/anthropics/claude-code/issues/35652) — another reason to use explicit preset selection.

---

## reference

### registries

| variable | type | purpose |
|---|---|---|
| `CLAUDES_PRESETS[name]` | string | cli flags, or `fn:<zsh_func>` |
| `CLAUDES_DESCRIPTIONS[name]` | string | one-line label for picker |
| `CLAUDES_ALIASES[short]` | string | `short → preset` shortcut |
| `CLAUDES_ENV[name]` | string | `"KEY=val KEY2=val2"` exported at launch |
| `CLAUDES_MCP[name]` | string | path to mcp json, injected as `--mcp-config` |
| `CLAUDES_PROMPT[name]` | string | appended via `--append-system-prompt` |

assign: `CLAUDES_PRESETS[foo]="..."` — unset: `unset 'CLAUDES_PRESETS[foo]'`

### commands

| command | behavior |
|---|---|
| `claudes` | interactive picker |
| `claudes <preset> [args...]` | launch preset, extra args pass through |
| `claudes list` / `ls` | list all presets with markers |
| `claudes show <preset>` | dry-run: print resolved config |
| `claudes config` | interactive preset & ux manager |
| `claudes config presets` | manage presets (add/edit/remove) |
| `claudes config ux` | set order, default preset, remap |
| `claudes help` | full help text |

### markers (picker + list)

| marker | meaning |
|---|---|
| `[fn]` | function-form preset |
| `[+env]` | preset exports env vars |
| `[+mcp]` | preset loads a `--mcp-config` |
| `[+prompt]` | preset appends a system prompt |

### files

| path | purpose |
|---|---|
| `~/.local/share/claudes/claudes.zsh` | the main function |
| `~/.local/share/claudes/ux.zsh` | ux layer (optional, installed by installer) |
| `~/.local/share/claudes/configure.sh` | preset manager, called by `claudes config` |
| `~/.config/claudes/presets.zsh` | your custom presets |
| `~/.config/claudes/ux-settings.zsh` | ux config (order, default, remap) |
| `~/.config/claudes/mcp/` | convention: mcp json files for `CLAUDES_MCP[...]` |
| `~/.zshrc.d/90-claudes.zsh` | symlink → claudes.zsh (if `~/.zshrc.d/` exists) |
| `~/.zshrc.d/91-claudes-ux.zsh` | symlink → ux.zsh (if ux layer installed) |

---

## requirements

- **zsh 5.0+** — uses associative arrays and zsh-specific parameter expansion
- **claude code cli 2.1+** — `npm install -g @anthropic-ai/claude-code`
- macOS or Linux

bash isn't supported. the function is small enough to port in an afternoon if you need it.

## uninstall

```bash
rm -rf ~/.local/share/claudes
rm -f ~/.zshrc.d/90-claudes.zsh ~/.zshrc.d/91-claudes-ux.zsh
# if no ~/.zshrc.d/, remove the source lines from ~/.zshrc starting with:
#   # claudes — https://github.com/yigitkonur/claudes
```

`~/.config/claudes/` is left in place so you don't lose your presets.

## contributing

prs welcome for:

- more recipes under `examples/`
- bash port as a sibling file
- optional `fzf` picker enhancement
- docs improvements

see [CONTRIBUTING.md](CONTRIBUTING.md) and [AGENTS.md](AGENTS.md) before touching core.

## related

- [claude code](https://claude.com/claude-code) — the cli this wraps
- [hooks-claude-code](https://github.com/yigitkonur/hooks-claude-code) — auto-approve plan exits and other hooks
- [awesome-claude-code](https://github.com/hesreallyhim/awesome-claude-code) — curated claude code tooling

## license

MIT © yigit konur — see [LICENSE](LICENSE).
