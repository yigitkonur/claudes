# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Fixed
- Bash installer prompts no longer use zsh-only lowercase expansion, fixing
  `unbound variable` failures under `set -u`.
- Installer config writes now validate the target directory before writing
  `claudes.yaml` or the generated cache.

## [0.2.0] — 2026-04-21

Presets now carry more than flag strings.

### Added
- `CLAUDES_ENV[preset]` — space-separated `KEY=val` pairs exported before launch
- `CLAUDES_MCP[preset]` — path to a JSON file passed via `--mcp-config`; existence
  is verified before launch, with a clear error if the file is missing
- `CLAUDES_PROMPT[preset]` — string appended via `--append-system-prompt`
- Function-form presets via `CLAUDES_PRESETS[name]="fn:<zsh_func>"` — full escape
  hatch for worktree spawning, interactive pickers, conditional flags, or anything
  that needs real zsh rather than a flag string
- `claudes show <preset>` — dry-run inspector that prints the resolved config
  (flags, env, mcp path, prompt) without launching Claude
- Preset markers in the list/picker output: `[fn] [+env] [+mcp] [+prompt]`
- Eight new ready-to-copy recipes under `examples/`:
  `review.zsh`, `cheap.zsh`, `ci.zsh`, `research-mcp.zsh`, `offline.zsh`,
  `audit.zsh`, `worktree.zsh`, `pr.zsh`
- `examples/mcp/research-only.json` — template MCP config for the research preset

### Changed
- Picker column width grows from 14 to 18 chars to fit longer preset names
- Example `custom-presets.zsh` now cross-references the single-purpose recipe files

### Design notes
- Env exports in function-form presets run inside a subshell — they don't leak
  to the calling shell
- `--append-system-prompt` and `--mcp-config` are injected after the main flag
  string but before pass-through args, so a pass-through `--append-system-prompt`
  wins if users really want to override a preset's prompt for one invocation
- No new built-in presets — four is still plenty; richer recipes ship as
  copy-paste files under `examples/`

## [0.1.0] — 2026-04-21

Initial release.

### Added
- `claudes` zsh function with four built-in presets: `standard`, `quick`, `plan`, `research`
- Short aliases: `s`, `q`, `p`, `r`
- Interactive numeric picker when no preset is passed
- Pass-through of additional `claude` args after the preset name
- `claudes list` to show all presets, `claudes help` for usage
- User config support at `~/.config/claudes/presets.zsh` with `CLAUDES_PRESETS`,
  `CLAUDES_DESCRIPTIONS`, `CLAUDES_ALIASES` associative arrays
- `install.sh` that supports both `~/.zshrc.d/` symlink and zshrc-append patterns
- Example custom presets at `examples/custom-presets.zsh`

### Design notes
- Non-plan presets explicitly pass `--permission-mode default` to override any
  `defaultMode: "plan"` in `~/.claude/settings.json`
- CLI flags take precedence over settings.json — no mid-session mutation needed
