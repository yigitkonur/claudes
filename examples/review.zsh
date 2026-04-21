# Read-only PR review preset
#
# Sonnet low-effort, tools clipped to read + inspect + safe git, and a
# system-prompt addendum that instructs no edits. Good for walking through a
# diff, auditing a branch, or scoping work before implementation.
#
# Copy the block you want into ~/.config/claudes/presets.zsh.

CLAUDES_PRESETS[review]="--model sonnet --effort low --permission-mode default --tools Read,Grep,Glob,Bash"
CLAUDES_DESCRIPTIONS[review]="Sonnet · low · read-only PR/code review"
CLAUDES_ALIASES[rv]=review
CLAUDES_PROMPT[review]="You are in read-only review mode. Do not edit, create, or delete files. Do not run Bash commands that mutate state (install, write, commit, push, rm). Prefer Read, Grep, Glob, and inspection-only Bash (git diff, git log, ls, cat). Report findings as a numbered list; each finding names the file and line, explains the concern, and proposes the smallest fix."

# Usage:
#   claudes review              # interactive read-only session
#   claudes rv --from-pr 123    # review a specific PR
