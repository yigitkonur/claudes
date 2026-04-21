# claudes — Claude Code preset picker for zsh

> One command to switch between Claude Code model, effort, and permission-mode combinations. Ship sensible defaults, extend with your own presets. Zero dependencies beyond zsh and the Claude Code CLI.

[![Shell](https://img.shields.io/badge/shell-zsh-89e051?style=flat-square)](https://www.zsh.org/)
[![Claude Code](https://img.shields.io/badge/Claude_Code-compatible-f97316?style=flat-square)](https://claude.com/claude-code)
[![Platform](https://img.shields.io/badge/platform-macOS_|_Linux-000000?style=flat-square)](#)
[![License](https://img.shields.io/badge/license-MIT-blue?style=flat-square)](LICENSE)

```
  Choose Claude preset:

    1) standard (s)  · Sonnet 4.6 · max effort · daily coding work
    2) quick    (q)  · Sonnet 4.6 · low effort · fast/cheap edits
    3) plan     (p)  · Opus 4.7 · max · plan mode · deep thinking
    4) research (r)  · Opus 4.7 · max · direct · explore/review

  > _
```

---

## Why `claudes` exists

Claude Code's `settings.json` supports a single baseline `model`, `effortLevel`, and `defaultMode`. But different tasks want different combinations:

- **Fast mechanical edits** want Sonnet with low effort
- **Complex features** want Opus with max effort and plan mode
- **Architecture reviews** want Opus deep thinking *without* plan-first ceremony
- **Quick one-off questions** want the cheapest fast model

You can pass `--model`, `--effort`, and `--permission-mode` flags on every launch, but typing `claude --model sonnet --effort max --permission-mode default` gets tedious. `claudes` is a 120-line zsh function that:

1. Ships four practical defaults
2. Lets you add your own presets in one line each
3. Shows an interactive picker when you don't remember
4. Supports short aliases (`s`, `q`, `p`, `r`)
5. Passes extra args through to `claude` transparently

## Keywords

Claude Code CLI launcher · zsh preset manager · Anthropic Claude model switcher · effort level selector · plan mode toggle · Sonnet Opus Haiku picker · Claude Code config · shell function · developer productivity

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
claudes help            # full help
```

### Built-in presets

| Preset | Alias | Model | Effort | Permission Mode | When to use |
|--------|-------|-------|--------|-----------------|-------------|
| `standard` | `s` | Sonnet 4.6 | max | default | Daily coding work |
| `quick` | `q` | Sonnet 4.6 | low | default | Fast/cheap edits, trivial ops |
| `plan` | `p` | Opus 4.7 | max | **plan** | Deep thinking, complex tasks |
| `research` | `r` | Opus 4.7 | max | default | Code review, architecture, exploration |

> **Note:** Non-plan presets explicitly pass `--permission-mode default` to override any `defaultMode: "plan"` you may have set in `~/.claude/settings.json`. Without this, every preset would start in plan mode.

---

## Custom Presets

Edit `~/.config/claudes/presets.zsh`:

```zsh
# A Haiku preset for ultra-cheap operations
CLAUDES_PRESETS[haiku]="--model haiku --effort low --permission-mode default"
CLAUDES_DESCRIPTIONS[haiku]="Haiku 4.5 · low · ultra-cheap, near-instant"
CLAUDES_ALIASES[h]=haiku

# Override a built-in — make `quick` bypass permissions
CLAUDES_PRESETS[quick]="--model sonnet --effort low --permission-mode bypassPermissions"
CLAUDES_DESCRIPTIONS[quick]="Sonnet 4.6 · low · bypass · no friction"

# Resume last session shortcut
CLAUDES_PRESETS[last]="--model opus --effort max --continue"
CLAUDES_DESCRIPTIONS[last]="Opus 4.7 · max · continue last session"
```

Any flag accepted by `claude` is valid. Full [examples/custom-presets.zsh](examples/custom-presets.zsh).

### Remove a built-in

```zsh
unset 'CLAUDES_PRESETS[research]'
unset 'CLAUDES_DESCRIPTIONS[research]'
unset 'CLAUDES_ALIASES[r]'
```

---

## How It Works

`claudes` is a zsh function that stores presets in associative arrays:

```zsh
typeset -gA CLAUDES_PRESETS          # preset → CLI flags
typeset -gA CLAUDES_DESCRIPTIONS     # preset → human description
typeset -gA CLAUDES_ALIASES          # short → preset
```

On invocation:
1. If no argument, prints a numbered menu and reads your choice
2. Resolves aliases (`s` → `standard`)
3. Runs `command claude` with the preset's flags plus anything you passed

User config at `~/.config/claudes/presets.zsh` is sourced after the defaults, so your customizations override built-ins.

### CLI Flag Precedence

This is the load-bearing insight behind the tool. Claude Code resolves configuration in this order (highest wins):

1. **CLI flags** (`--model`, `--effort`, `--permission-mode`) ← what `claudes` uses
2. **Environment variables** (`ANTHROPIC_MODEL`, etc.)
3. **`~/.claude/settings.json`**
4. **Managed/enterprise settings**

Because CLI flags win, `claudes` can cleanly override your baseline `settings.json` without mutating any files at runtime.

### The "settings.json mutation" anti-pattern

An earlier design had a hook rewrite `settings.json` mid-session to swap Opus → Sonnet after plan approval. It was unreliable — Claude Code does not consistently re-read `settings.json` between turns, especially within a single Claude-side tool call. Picking the right model at launch time via `claudes` avoids that problem entirely.

---

## Why not just aliases?

You could write `alias quick='claude --model sonnet --effort low'` and skip this tool. That works for 2-3 presets. `claudes` scales better:

- Single picker when you forget the names
- One place to see all your presets (`claudes list`)
- Passes through args without wrestling with zsh alias quoting
- Config file with documented structure — easy to sync across machines
- Sorted, consistent display

If two aliases are enough for you, two aliases are enough.

---

## Requirements

- **zsh 5.0+** — uses associative arrays and parameter expansion features
- **Claude Code CLI** — `npm install -g @anthropic-ai/claude-code`
- macOS or Linux

Bash is not supported. If you need bash, the function is small enough to port in an hour.

---

## Configuration Reference

| Variable | Type | Purpose |
|----------|------|---------|
| `CLAUDES_PRESETS[name]` | string | CLI flags passed to `claude` |
| `CLAUDES_DESCRIPTIONS[name]` | string | One-line description for the picker |
| `CLAUDES_ALIASES[short]` | string | Map short alias → preset name |

All are zsh associative arrays. Assign with `CLAUDES_PRESETS[foo]="..."`, unset with `unset 'CLAUDES_PRESETS[foo]'`.

| File | Purpose |
|------|---------|
| `~/.local/share/claudes/claudes.zsh` | The installed function |
| `~/.config/claudes/presets.zsh` | Your custom presets (sourced after defaults) |
| `~/.zshrc.d/90-claudes.zsh` | Symlink that auto-loads the function (if dir exists) |

---

## Uninstall

```bash
rm -rf ~/.local/share/claudes
rm -f ~/.zshrc.d/90-claudes.zsh
# If installed via zshrc append, remove the block starting with:
#   # claudes — https://github.com/yigitkonur/claudes
```

`~/.config/claudes/presets.zsh` is left alone so you don't lose your config.

---

## Contributing

PRs welcome for:

- Additional useful built-in presets (but keep the default list minimal — four is plenty)
- Bash port as a sibling file
- Better interactive picker (fzf integration as an optional enhancement)
- Docs improvements

Open an issue first for larger changes. See [CONTRIBUTING.md](CONTRIBUTING.md).

---

## Related

- **[Claude Code](https://claude.com/claude-code)** — The CLI this tool wraps.
- **[RTK](https://github.com/rtk-ai/rtk)** — Token-savings proxy for LLM CLIs. Complementary.
- **[Ghostty](https://ghostty.org/)** / **Warp** / iTerm2 — Any terminal with zsh.

---

## License

MIT © Yigit Konur. See [LICENSE](LICENSE).
