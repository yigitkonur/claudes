# Contributing

Thanks for your interest in improving `claudes`!

## Development

Clone, edit `claudes.zsh`, and `source` it in your shell:

```bash
git clone https://github.com/yigitkonur/claudes.git
cd claudes
source claudes.zsh
```

## Scope

This tool is deliberately small. The core value is:

1. A picker with sensible defaults
2. An easy way to define custom presets
3. Zero dependencies beyond zsh + Claude Code CLI

Additions that grow the script significantly need a clear reason. "Nice to have" features usually belong in a fork or a companion tool.

## Adding a built-in preset

Four is plenty. If you want a fifth, make the case in an issue first. What gap does it fill that a user-config preset wouldn't?

## Pull request checklist

- [ ] Shell-agnostic where possible (zsh-only constructs are fine; document them)
- [ ] `shellcheck -s bash claudes.zsh` runs clean (the `shell=bash` is for the linter; runtime is zsh)
- [ ] README updated if behavior or flags change
- [ ] CHANGELOG entry under `## [Unreleased]`

## Tests

There's no test suite yet. Manual smoke test:

```bash
source claudes.zsh
claudes list          # should print 4 presets
claudes help          # should show help + list
claudes s             # should start claude with sonnet max
# Load a user config and re-run to verify overrides work
```

## Code style

Follow the existing style:
- Tabs are spaces (2)
- Functions prefixed `_claudes_` are internal
- Comments with `# ──` separators mark sections
- Heredoc for multi-line help text
