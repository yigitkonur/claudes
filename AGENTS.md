# agents.md — working in this repo

instructions for AI agents (Claude Code, Codex, Aider, etc.) contributing to `claudes`. written for humans too.

## what this repo is

a single zsh function (`claudes.zsh`, ~260 lines) that turns named preset keys into `claude` CLI invocations. presets compose six independent dimensions — flag string, description, alias, env vars, MCP config path, and system-prompt addendum — plus a `fn:` escape hatch to a zsh function for anything weirder.

the repo is deliberately small. it is not a framework.

## layout

```
claudes.zsh              the function. source of truth.
install.sh               copies claudes.zsh into ~/.local/share + wires ~/.zshrc.d/
examples/                curated recipes users copy into their own config
  custom-presets.zsh     grab-bag starter
  review.zsh             read-only PR review preset
  cheap.zsh              --bare single-file preset
  ci.zsh                 --print --output-format stream-json preset
  research-mcp.zsh       strict-MCP preset with companion json
  offline.zsh            airplane mode preset
  audit.zsh              security/compliance preset
  worktree.zsh           fn-form: spawn -w --tmux
  pr.zsh                 fn-form: --from-pr via gh
  mcp/research-only.json template MCP config
README.md                user-facing docs
CHANGELOG.md             keep-a-changelog, semver
CONTRIBUTING.md          scope + style rules — read before adding anything
.github/workflows/       shellcheck on install.sh only (zsh files are not scanned)
```

## the registries

all zsh associative arrays. all optional except `CLAUDES_PRESETS`.

| registry | shape | injected as |
|---|---|---|
| `CLAUDES_PRESETS[name]` | `"--flag1 value --flag2"` or `"fn:<zsh_function>"` | command itself |
| `CLAUDES_DESCRIPTIONS[name]` | string | picker + `list` display |
| `CLAUDES_ALIASES[short]` | string → preset name | short alias resolution |
| `CLAUDES_ENV[name]` | `"KEY=val KEY2=val2"` | prepended `env` prefix |
| `CLAUDES_MCP[name]` | path to .json (tilde-expanded) | `--mcp-config <path>` |
| `CLAUDES_PROMPT[name]` | string | `--append-system-prompt <string>` |

when adding a new recipe, reach for the *minimum* registries that express it. a preset that only changes model + effort should not touch env, mcp, or prompt. a preset that needs a worktree + tmux must be `fn:` — there's no way to express that declaratively.

## testing

no test suite. smoke tests go through the `zsh -c` pattern:

```bash
zsh -c '
  source ./claudes.zsh
  claudes list                           # prints 4 built-ins
  claudes show standard                  # prints resolved config
  source ./examples/review.zsh
  claudes list                           # now shows review with [+prompt] marker
  claudes show review                    # prints flags + prompt
  source ./examples/worktree.zsh
  claudes show wt                        # flags: fn:_claudes_preset_worktree
'
```

lint before committing:

```bash
shellcheck -s bash -S warning ./install.sh   # CI severity. must be clean.
```

shellcheck on `claudes.zsh` itself will warn about zsh-specific syntax (`${(ko)...}`, `${=var}`, `export "$_p"`). those are expected — CI deliberately does not scan `.zsh` files. the workflow config is `additional_files: 'install.sh'`, nothing else.

## hard constraints

these are non-negotiable, inherited from `CONTRIBUTING.md` and project history:

- **four built-in presets, no more.** new recipes go under `examples/`, not into `CLAUDES_PRESETS` in `claudes.zsh`. if you think a fifth built-in is warranted, open an issue and make the case.
- **no haiku anywhere.** not in built-ins, not in examples, not in install-time templates, not in README. the project owner does not use haiku. if a recipe wants a cheap/fast preset, use `sonnet + --effort low + --bare`.
- **non-plan presets must pin `--permission-mode default`.** settings.json may have `defaultMode: "plan"`; without the explicit flag every preset leaks into plan mode. the three non-plan built-ins already do this — preserve it.
- **no mid-session mutation of settings.json.** an earlier design wrote to `~/.claude/settings.json` from a hook to swap models after plan approval. it was unreliable. all config happens at launch time via CLI flags.
- **zero new dependencies.** zsh + claude code CLI. nothing else. `jq`, `fzf`, `gh` may appear in optional recipes but never in `claudes.zsh` core.
- **shellcheck -s bash -S warning clean on install.sh.** the zsh file gets noise; install.sh must not.

## style

- 2-space indentation (not tabs)
- internal helpers prefixed `_claudes_`
- `# ──` rule lines mark sections inside functions
- heredocs (`cat <<'EOF'`) for multi-line help text
- conventional commits: `type(scope): imperative summary` (e.g., `feat(presets): add CLAUDES_PROMPT`, `fix(picker): handle numeric out-of-range`)
- one commit, one purpose
- README and CHANGELOG updated in the same commit as user-visible changes

## what not to do

- do not introduce a dsl, plugin system, or config-file format. presets are zsh variables. that is the entire api.
- do not add abstractions for single-use code. three similar presets in `examples/` is fine; a meta-preset-generator is not.
- do not silently fall back when an `MCP` path is missing. fail loud with a clear error (current behavior — preserve it).
- do not mutate the caller's environment. env exports for `fn:` presets go in a subshell. env prefix for flag-string presets uses `env KEY=val command claude ...` without `export`.
- do not assume the user's `claude` binary — always use `command claude` so shell aliases (`alias claude='claude --effort max'`) don't recurse.
- do not rewrite working code to match a cleaner style. match the existing style instead.

## release flow

when shipping a user-visible change:

1. update `claudes.zsh` (and examples if relevant)
2. update `README.md` — reference table + relevant section
3. append to `CHANGELOG.md` under a new version, keep-a-changelog format
4. commit with a conventional-commit message
5. `git push origin main`
6. no npm, no release binary, no tagged build — the repo *is* the release

for bumping the version in `CHANGELOG.md`: patch for docs/typo, minor for new registries or new built-in flags, major only if breaking the assoc-array contract.

## related repos

- `~/.claude/` — the project owner's global Claude Code config. agents should not read or modify it from within this repo.
- `github.com/yigitkonur/script-dotfiles` — the owner's private dotfiles. contains a `zsh/.zshrc.d/90-claude-orchestrator.zsh` with the `claude --effort max` alias and `orchestrator` toggle function. the dedicated `claudes` install at `~/.zshrc.d/90-claudes.zsh` loads *after* that file and supersedes any inline `claudes` function there.
