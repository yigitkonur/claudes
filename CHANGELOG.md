# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

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

### Design Notes
- Non-plan presets explicitly pass `--permission-mode default` to override any
  `defaultMode: "plan"` in `~/.claude/settings.json`
- CLI flags take precedence over settings.json — no mid-session mutation needed
