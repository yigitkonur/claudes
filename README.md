# claude code with presets

> one command, six dimensions. switch model, effort, permission-mode, MCP servers, system prompts, and env vars with a single preset name. zero deps beyond zsh and the [claude code](https://claude.com/claude-code) CLI.

[![shell](https://img.shields.io/badge/shell-zsh-89e051?style=flat-square)](https://www.zsh.org/)
[![claude code](https://img.shields.io/badge/claude_code-compatible-f97316?style=flat-square)](https://claude.com/claude-code)
[![platform](https://img.shields.io/badge/platform-macOS_|_Linux-000000?style=flat-square)](#)
[![license](https://img.shields.io/badge/license-MIT-blue?style=flat-square)](LICENSE)

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

## table of contents

1. [the pitch](#the-pitch)
2. [install](#install)
3. [a 60-second tour](#a-60-second-tour)
4. [what a preset actually is](#what-a-preset-actually-is)
5. [the six dimensions](#the-six-dimensions)
6. [function-form presets — the escape hatch](#function-form-presets--the-escape-hatch)
7. [recipes you can steal](#recipes-you-can-steal)
8. [why this works — cli flag precedence](#why-this-works--cli-flag-precedence)
9. [writing your own](#writing-your-own)
10. [reference](#reference)
11. [requirements, uninstall, contributing](#requirements)

---

## the pitch

claude code's `settings.json` holds one `model`, one `effortLevel`, one `defaultMode`. real work doesn't fit one baseline. you want sonnet-fast for mechanical edits, opus-deep for architecture, plan mode when you're scoping a feature, a read-only tool subset when you're just reviewing a PR, a completely different MCP server set when you're doing grounded research, and `--bare` when you're on a plane. you could paste 80-character flag strings on every launch. you'll stop after two days.

`claudes` is a zsh function that stores named presets as associative-array entries. one line per dimension. it shows you a numbered picker when you forget the names, resolves short aliases (`s`, `q`, `p`, `r`), and passes every arg through transparently. there is no config file format, no plugin system, no dsl. you edit zsh. that's the entire api.

**keywords (for search)**: claude code preset manager · claude cli launcher · MCP config switcher · append-system-prompt per preset · tool subset scoping · opus plan mode alias · sonnet low effort · claude code dotfiles · headless claude scripts · worktree automation · anthropic claude model switcher · zsh associative arrays · claude code with presets

---

## install

one-liner:

```bash
curl -fsSL https://raw.githubusercontent.com/yigitkonur/claudes/main/install.sh | bash
```

manual:

```bash
git clone https://github.com/yigitkonur/claudes.git
cd claudes && ./install.sh
```

what the installer does:

1. copies `claudes.zsh` to `~/.local/share/claudes/claudes.zsh`
2. if `~/.zshrc.d/` exists, symlinks it as `~/.zshrc.d/90-claudes.zsh`
3. else appends a `source` line to `~/.zshrc`
4. creates an empty user-config at `~/.config/claudes/presets.zsh`

nothing in your shell config is overwritten. re-running is safe. zero state outside those four paths.

---

## a 60-second tour

```bash
claudes                          # numbered picker
claudes standard                 # sonnet 4.6 · max effort · default mode
claudes s                        # same thing, via alias
claudes plan --resume            # plan preset + pass --resume through to claude
claudes list                     # show all registered presets with markers
claudes show research            # dry-run: print resolved config without launching
claudes help                     # full help
```

four presets ship by default. they're minimal on purpose — you'll add the ones that fit your work.

| preset | alias | model | effort | permission mode | when |
|---|---|---|---|---|---|
| `standard` | `s` | sonnet 4.6 | max | default | daily coding |
| `quick` | `q` | sonnet 4.6 | low | default | fast/cheap edits, trivial ops |
| `plan` | `p` | opus 4.7 | max | **plan** | deep thinking, complex scoping |
| `research` | `r` | opus 4.7 | max | default | code review, architecture, explore |

> **gotcha worth knowing up front:** the three non-plan presets explicitly pass `--permission-mode default`. if you've set `defaultMode: "plan"` in your global `~/.claude/settings.json` — and most power users do — every launch would otherwise start in plan mode, because settings.json wins when no flag is present. the explicit flag overrides it. this is covered in detail under [cli flag precedence](#why-this-works--cli-flag-precedence).

---

## what a preset actually is

the whole tool fits in one sentence: **a preset is a name that maps to some combination of CLI flags, an MCP config path, a system-prompt string, and a few env vars.** when you run `claudes review`, the function looks up the name, composes those pieces into one `claude` invocation, and execs it.

here's the shape of a preset. each registry is an optional zsh associative array:

```zsh
CLAUDES_PRESETS[review]="--model sonnet --effort low --tools Read,Grep,Glob,Bash"
CLAUDES_DESCRIPTIONS[review]="Sonnet · low · read-only PR review"
CLAUDES_ALIASES[rv]=review
CLAUDES_PROMPT[review]="You are in read-only review mode. Do not edit files."
CLAUDES_ENV[review]="CLAUDE_CODE_MAX_OUTPUT_TOKENS=16000"
# CLAUDES_MCP[review]="$HOME/.config/claudes/mcp/review-only.json"   # optional
```

when you run `claudes review`, that becomes:

```bash
env CLAUDE_CODE_MAX_OUTPUT_TOKENS=16000 \
  command claude \
    --model sonnet --effort low --tools Read,Grep,Glob,Bash \
    --append-system-prompt "You are in read-only review mode. Do not edit files."
```

everything else — the picker, `show`, aliases, markers — is just ergonomics around that composition step.

---

## the six dimensions

every preset mixes and matches these. the first one is the only required one.

### 1. `CLAUDES_PRESETS[name]` — the flag string (or a function)

this is the core. a string of CLI flags passed through to `claude`:

```zsh
CLAUDES_PRESETS[mine]="--model sonnet --effort high --permission-mode acceptEdits"
```

or a function-form sentinel (see [the escape hatch](#function-form-presets--the-escape-hatch)):

```zsh
CLAUDES_PRESETS[wt]="fn:_claudes_preset_worktree"
```

any flag `claude --help` recognizes is fair game — `--model`, `--effort`, `--permission-mode`, `--tools`, `--allowedTools`, `--disallowedTools`, `--bare`, `--print`, `--output-format`, `--max-budget-usd`, `--fallback-model`, and so on.

### 2. `CLAUDES_DESCRIPTIONS[name]` — what the picker shows

one line. shows up in the interactive picker and in `claudes list`:

```zsh
CLAUDES_DESCRIPTIONS[mine]="Sonnet · high · my daily driver"
```

### 3. `CLAUDES_ALIASES[short]` — the shortcut

maps a short key to a preset name. that's it:

```zsh
CLAUDES_ALIASES[m]=mine
```

now `claudes m` and `claudes mine` both work.

### 4. `CLAUDES_ENV[name]` — env vars before launch

space-separated `KEY=value` pairs. exported into the environment of the `claude` process only — nothing leaks back to your shell:

```zsh
CLAUDES_ENV[bigctx]="CLAUDE_CODE_MAX_OUTPUT_TOKENS=32000 MAX_THINKING_TOKENS=48000"
```

useful for things that aren't CLI flags: token budget knobs, `CLAUDE_ORCHESTRATOR=1`, provider endpoints, feature flags.

### 5. `CLAUDES_MCP[name]` — a scoped MCP set

path to a JSON file in the standard `.mcp.json` shape. `claudes` expands `~`, verifies the file exists (fails loud if not), then passes it as `--mcp-config <path>`:

```zsh
CLAUDES_MCP[research]="$HOME/.config/claudes/mcp/research-only.json"
```

pair with `--strict-mcp-config` in the flag string to load *only* that file's servers and ignore globals. huge for "i want this preset to talk to my research MCP and nothing else."

a minimal file:

```json
{
  "mcpServers": {
    "research-powerpack": {
      "type": "http",
      "url": "https://research.example.com/mcp"
    }
  }
}
```

### 6. `CLAUDES_PROMPT[name]` — a system-prompt addendum

a string appended via `--append-system-prompt`. great for behavioral scoping that doesn't need code:

```zsh
CLAUDES_PROMPT[review]="You are in read-only review mode. Do not edit, create, or delete files. Report findings as numbered items with file:line references."
```

this is the cheapest way to turn a general-purpose model into a role-specific one. no fine-tuning, no separate binary.

---

## function-form presets — the escape hatch

flag strings can't express everything. some presets need to resolve a PR number from `gh` first, pick a worktree name based on the current time, cd somewhere, or branch on an argument. for those, reach for the `fn:` form.

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

now:

```bash
claudes wt feature-auth             # named worktree
claudes wt                          # auto-named: feat-<timestamp>
claudes wt refactor-db "start by…"  # name + prompt
```

`CLAUDES_ENV` still applies to `fn:` presets — exports run inside a subshell so nothing leaks. `CLAUDES_MCP` and `CLAUDES_PROMPT` are *ignored* — the function is expected to manage those itself if it wants them. that keeps the contract clean: flag-form is declarative; fn-form is imperative.

---

## recipes you can steal

the [`examples/`](examples) directory ships eight single-purpose files. copy the block you want into `~/.config/claudes/presets.zsh` and you're done.

| file | preset | shape | real use case |
|---|---|---|---|
| [`review.zsh`](examples/review.zsh) | `review` | sonnet low + read-only tools + no-edits prompt | PR walkthroughs, code scoping |
| [`cheap.zsh`](examples/cheap.zsh) | `cheap` | sonnet low + `--bare` | single-file ops, ~30-50% fewer tokens |
| [`ci.zsh`](examples/ci.zsh) | `ci` | `--print --output-format stream-json --bare --max-budget-usd 1` | local scripts piping to `jq` |
| [`research-mcp.zsh`](examples/research-mcp.zsh) | `rmcp` | opus max + strict MCP + anti-fabrication prompt | grounded research runs |
| [`offline.zsh`](examples/offline.zsh) | `offline` | `--bare` + no MCP + no slash commands + no WebFetch/Search | airplane / hotel wifi |
| [`audit.zsh`](examples/audit.zsh) | `audit` | opus max + read-only tools + audit-rubric prompt | security / compliance walks |
| [`worktree.zsh`](examples/worktree.zsh) | `wt` | `fn:` — spawns `-w <name> --tmux` | parallel agents on one repo |
| [`pr.zsh`](examples/pr.zsh) | `pr` | `fn:` — resolves PR via `gh`, then `--from-pr` | resume PR-linked sessions |

plus a template [`examples/mcp/research-only.json`](examples/mcp/research-only.json) for presets that use `CLAUDES_MCP[...]`.

the list at [awesome-claude-code](https://github.com/hesreallyhim/awesome-claude-code) is a great place to find other patterns to adapt.

---

## why this works — cli flag precedence

the load-bearing insight behind everything above. claude code resolves configuration in this order, highest wins:

1. **CLI flags** (`--model`, `--effort`, `--permission-mode`, `--mcp-config`, `--append-system-prompt`, …) ← what `claudes` uses
2. **env vars** (`ANTHROPIC_MODEL`, `CLAUDE_CODE_MAX_OUTPUT_TOKENS`, …)
3. **`~/.claude/settings.json`**
4. **managed/enterprise settings**

because CLI flags win, a preset can cleanly override your `settings.json` baseline *without mutating any files at runtime*. each preset is self-contained. start two sessions with different presets, they don't interfere.

### the settings.json mutation anti-pattern (cautionary tale)

an earlier version of this setup rewrote `~/.claude/settings.json` from a hook to swap opus → sonnet after plan approval. the goal was "plan on opus, execute on sonnet, save tokens." it didn't work reliably. claude code does not consistently re-read `settings.json` between turns — especially within a single tool call. you'd see the plan approved, the file rewritten, and the next turn still running on opus.

the fix was the design you're reading now: pick the right config at launch via `claudes`. no mid-session mutation. no race conditions. the community workaround `opusplan` model alias also has [a known bug](https://github.com/anthropics/claude-code/issues/35652) where it runs sonnet in both phases — another reason to use explicit preset selection.

---

## writing your own

edit `~/.config/claudes/presets.zsh`. it's sourced after the built-ins, so anything you set overrides.

a minimum viable preset is four lines:

```zsh
CLAUDES_PRESETS[mine]="--model sonnet --effort high"
CLAUDES_DESCRIPTIONS[mine]="my daily driver"
CLAUDES_ALIASES[m]=mine
```

a richer one touches multiple registries:

```zsh
# grounded research — opus, strict MCP, anti-fabrication prompt, bigger output budget
CLAUDES_PRESETS[rmcp]="--model opus --effort max --permission-mode default --strict-mcp-config"
CLAUDES_DESCRIPTIONS[rmcp]="Opus · max · strict research MCP"
CLAUDES_ALIASES[rm]=rmcp
CLAUDES_MCP[rmcp]="$HOME/.config/claudes/mcp/research-only.json"
CLAUDES_PROMPT[rmcp]="Cite every non-trivial claim from a scraped source. No fabrication."
CLAUDES_ENV[rmcp]="CLAUDE_CODE_MAX_OUTPUT_TOKENS=32000"
```

to remove a built-in:

```zsh
unset 'CLAUDES_PRESETS[research]'
unset 'CLAUDES_DESCRIPTIONS[research]'
unset 'CLAUDES_ALIASES[r]'
```

to see what a preset resolves to without launching it:

```bash
claudes show rmcp
# preset:       rmcp
# description:  Opus · max · strict research MCP
# flags:        --model opus --effort max --permission-mode default --strict-mcp-config
# mcp-config:   /Users/you/.config/claudes/mcp/research-only.json
# prompt:       Cite every non-trivial claim from a scraped source. No fabrication.
# env:          CLAUDE_CODE_MAX_OUTPUT_TOKENS=32000
```

---

## reference

### registries

| variable | type | purpose |
|---|---|---|
| `CLAUDES_PRESETS[name]` | string | CLI flags, or `fn:<zsh_func>` |
| `CLAUDES_DESCRIPTIONS[name]` | string | one-line description for picker |
| `CLAUDES_ALIASES[short]` | string | `short → preset` map |
| `CLAUDES_ENV[name]` | string | `"KEY=val KEY2=val2"` exported at launch |
| `CLAUDES_MCP[name]` | string | path to MCP JSON; injected as `--mcp-config` |
| `CLAUDES_PROMPT[name]` | string | appended via `--append-system-prompt` |

assign with `CLAUDES_PRESETS[foo]="..."`. unset with `unset 'CLAUDES_PRESETS[foo]'`.

### commands

| command | behavior |
|---|---|
| `claudes` | interactive numbered picker |
| `claudes <preset>` | launch preset (aliases resolved) |
| `claudes <preset> [args...]` | launch with extra args passed to `claude` |
| `claudes list` / `ls` | list all presets with extras markers |
| `claudes show <preset>` | dry-run: print resolved config |
| `claudes help` | full help |

### markers

shown in the picker and `list`:

| marker | meaning |
|---|---|
| `[fn]` | preset is a zsh function — full flexibility |
| `[+env]` | preset sets extra env vars |
| `[+mcp]` | preset loads its own `--mcp-config` |
| `[+prompt]` | preset appends a system prompt |

### files

| path | purpose |
|---|---|
| `~/.local/share/claudes/claudes.zsh` | the installed function |
| `~/.config/claudes/presets.zsh` | your custom presets (sourced after defaults) |
| `~/.config/claudes/mcp/*.json` | convention: MCP configs referenced by `CLAUDES_MCP[...]` |
| `~/.zshrc.d/90-claudes.zsh` | symlink that auto-loads the function (if dir exists) |

---

## requirements

- **zsh 5.0+** — uses associative arrays and parameter expansion features
- **claude code CLI 2.1+** — `npm install -g @anthropic-ai/claude-code`
- macOS or Linux

bash isn't supported. the function is small enough to port in an hour if you need it.

## uninstall

```bash
rm -rf ~/.local/share/claudes
rm -f ~/.zshrc.d/90-claudes.zsh
# if installed via zshrc append, remove the block starting with:
#   # claudes — https://github.com/yigitkonur/claudes
```

`~/.config/claudes/` is left alone so you don't lose your presets.

## contributing

PRs welcome for:

- more recipes under `examples/` (built-ins stay at four)
- bash port as a sibling file
- optional `fzf` picker enhancement
- docs improvements

see [CONTRIBUTING.md](CONTRIBUTING.md) and [AGENTS.md](AGENTS.md) before opening a PR that touches core.

## related

- [claude code](https://claude.com/claude-code) — the CLI this wraps
- [awesome-claude-code](https://github.com/hesreallyhim/awesome-claude-code) — curated list of claude code tooling
- [RTK](https://github.com/rtk-ai/rtk) — token-savings proxy for LLM CLIs, complementary

## license

MIT © yigit konur. see [LICENSE](LICENSE).
