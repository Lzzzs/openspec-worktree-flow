---
name: "openspec-worktree-flow"
description: "Use when the user wants a portable, proposal-first workflow where approved changes should be prompted into their own git worktrees before implementation. Covers OpenSpec change scaffolding, status checks, asking whether to create a worktree at the handoff to implementation, listing worktrees, and cleaning them up after merge."
---

# OpenSpec Worktree Flow

Use this skill when the user wants to standardize or execute a reusable `OpenSpec + branch + worktree` delivery flow across repositories.

This skill assumes:

- one request or feature maps to one OpenSpec change
- proposal work happens in the main repository checkout
- implementation starts only after proposal approval
- approved changes should normally move into their own `codex/<change-id>` branch and sibling worktree at the handoff to implementation, even if it is the only active change

## Quick rules

1. Create or update `openspec/changes/<change-id>/` first.
2. Do not create a worktree for ideas that are still under review.
3. After approval and before implementation starts, explicitly ask whether to create the worktree now.
4. If the user confirms, create exactly one implementation branch and one worktree for that change.
5. Do all code changes for that request inside the worktree, not in the main checkout.
6. After merge, remove the worktree and optionally delete the branch.
7. If you are unsure whether a change is ready to start or safe to clean up, run `status` first.

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
- `start`: creates `codex/<change-id>` from `main`, `master`, `origin/main`, `origin/master`, or the current branch, then creates a sibling worktree named `<repo>-<change-id>`
- `status`: shows whether the proposal files, branch, and worktree exist and prints the next recommended step, including when to ask for worktree confirmation
- `list`: shows existing worktrees for the repository
- `cleanup`: removes the worktree and optionally deletes the implementation branch

## References

Open only what you need:

- workflow details and edge cases: `references/workflow.md`

## Guardrails

- Treat proposal approval as the point to ask whether implementation should move into a worktree.
- Worktree isolation should be recommended by default, but the user can explicitly decide whether to start it at that moment.
- By default, `init` and `start` expect to run from the main repository checkout, not from another linked worktree.
- If multiple requests touch the same shared module, parallelize proposals first and sequence the implementation.
- Prefer deterministic naming:
  - change: `<change-id>`
  - branch: `codex/<change-id>`
  - worktree dir: `../<repo>-<change-id>`
- `change-id` and capability names should be kebab-case.
- If the repository does not contain `openspec/`, `start` can still create the branch and worktree, but `init` requires OpenSpec to exist.
