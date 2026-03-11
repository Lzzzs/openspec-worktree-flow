---
name: "openspec-worktree-flow"
description: "Use when a repository follows OpenSpec and the work is moving from proposal approval into implementation, especially to hand off into an isolated git worktree. Covers proposal scaffolding, status checks, proactive worktree handoff when coding begins, a reusable migration-rules library for worktrees, listing worktrees, and cleaning them up after merge."
---

# OpenSpec Worktree Flow

Use this skill when the repository uses OpenSpec and the request is following a proposal-first workflow.

This skill assumes:

- one request or feature maps to one OpenSpec change
- proposal work happens in the main repository checkout
- implementation starts only after proposal approval
- approved changes should normally move into their own `codex/<change-id>` branch and sibling worktree at the handoff to implementation, even if it is the only active change

## Quick rules

1. Create or update `openspec/changes/<change-id>/` first.
2. Do not create a worktree for ideas that are still under review.
3. If an approved proposal exists and the user asks to implement, write code, or start coding, use this skill immediately. Do not wait for the user to mention the skill name.
4. At the handoff from approved proposal to implementation, explicitly ask whether to create the worktree now unless the user has already made that choice.
5. If the user confirms, create exactly one implementation branch and one worktree for that change.
6. `start` should carry the current checkout files into the new worktree by combining a temporary local snapshot commit with selective migration rules.
7. Prefer direct copy for lightweight ignored context such as `openspec/`.
8. Maintain copy and symlink decisions in the migration-rules library at `scripts/migration_rules.sh`.
9. Prefer symlinks for heavyweight local-only directories such as `node_modules/`.
10. Do all code changes for that request inside the worktree, not in the main checkout.
11. After merge, remove the worktree and optionally delete the branch.
12. If you are unsure whether a change is ready to start or safe to clean up, run `status` first.

## Script path

When installed as a user skill:

```bash
export CODEX_HOME="${CODEX_HOME:-$HOME/.codex}"
export OWF="$CODEX_HOME/skills/openspec-worktree-flow/scripts/openspec_worktree.sh"
```

For the draft in a repository checkout:

```bash
export OWF="$(pwd)/codex-skills/openspec-worktree-flow/scripts/openspec_worktree.sh"
```

## Commands

Initialize a change scaffold:

```bash
"$OWF" init add-rrweb-recording --capability recording --title "rrweb 录制 MVP" --with-design
```

Start implementation after user confirmation:

```bash
"$OWF" start add-rrweb-recording
```

Inspect lifecycle state:

```bash
"$OWF" status add-rrweb-recording
```

List worktrees:

```bash
"$OWF" list
```

Clean up after merge:

```bash
"$OWF" cleanup add-rrweb-recording --remove-branch
```

## What the script does

- `init`: scaffolds `proposal.md`, `tasks.md`, one spec delta file, and optional `design.md`
- `start`: creates `codex/<change-id>` from `main`, `master`, `origin/main`, `origin/master`, the current branch, or a temporary local snapshot commit when local checkout files must follow into the worktree, then applies selective migration rules from `scripts/migration_rules.sh`
- `status`: shows whether the proposal files, branch, and worktree exist and prints the next recommended step, including when to ask for worktree confirmation
- `list`: shows existing worktrees for the repository
- `cleanup`: removes the worktree and optionally deletes the implementation branch

## References

Open only what you need:

- workflow details and edge cases: `references/workflow.md`

## Guardrails

- Treat proposal approval as the point to hand off into a worktree when implementation begins.
- Worktree isolation should be recommended by default, but the user can explicitly decide whether to start it at that moment.
- If the user has already approved the proposal and asked to start implementation, do not continue coding in the main checkout without first resolving the worktree handoff.
- By default, `init` and `start` expect to run from the main repository checkout, not from another linked worktree.
- If multiple requests touch the same shared module, parallelize proposals first and sequence the implementation.
- Prefer deterministic naming:
  - change: `<change-id>`
  - branch: `codex/<change-id>`
  - worktree dir: `../<repo>-<change-id>`
- `change-id` and capability names should be kebab-case.
- If the repository does not contain `openspec/`, `start` can still create the branch and worktree, but `init` requires OpenSpec to exist.
