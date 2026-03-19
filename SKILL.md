---
name: "openspec-worktree-flow"
description: "Use when a Codex repository relies on OpenSpec proposals and the work is moving from approved change to implementation in an isolated git worktree. Covers bootstrapping repositories with `owf init`, inspecting lifecycle state, starting implementation worktrees, applying migration rules, and cleaning up after merge. Do not trigger worktree prompts for merge, rebase, cleanup, archive, or other close-out tasks."
---

# OpenSpec Worktree Flow

Use this skill when a repository already uses OpenSpec for proposals, but Codex needs to manage the handoff from approved change to implementation worktree.

## Quick rules

1. Treat `owf init` as the repository bootstrap step. It should keep `AGENTS.md` and `.owf/migration_rules.sh` in place.
2. Proposal work stays in the main checkout.
3. If an approved proposal exists and the user asks to implement, write code, or continue implementation, resolve worktree handoff before coding in the main checkout.
4. The repository-level `AGENTS.md` block is the strongest trigger for proactive behavior. Keep it synced through `owf init` or `owf sync-agents`.
5. Ask whether to create the implementation worktree now unless the user already made that choice explicitly.
6. After confirmation, use `owf start <change-id>` and do implementation work in the sibling worktree.
7. Prefer repo-local migration rules from `.owf/migration_rules.sh`; fall back to the bundled defaults only when the repository has not been bootstrapped yet.
8. Clean up with `owf cleanup <change-id> --remove-branch` after merge when the worktree is no longer needed.
9. If the user is merging, rebasing, cherry-picking, cleaning up, archiving, or otherwise closing out the change, do not ask to create a new worktree.

## Commands

Bootstrap the repository:

```bash
owf init
```

Check lifecycle state:

```bash
owf status add-rrweb-recording
```

Start implementation after confirmation:

```bash
owf start add-rrweb-recording
```

Clean up after merge:

```bash
owf cleanup add-rrweb-recording --remove-branch
```

Advanced:

```bash
owf sync-agents
owf change-init add-rrweb-recording --capability recording --title "rrweb 录制 MVP"
```

## References

Open only what you need:

- workflow details and edge cases: `references/workflow.md`

## Guardrails

- Worktree isolation should be recommended by default once implementation begins.
- If the proposal is approved and the user asks to start coding, do not continue in the main checkout without first resolving the handoff.
- Do not prompt for worktree creation during merge, rebase, cherry-pick, cleanup, archive, or other close-out tasks.
- `owf start` should normally run from the main checkout, not from an existing linked worktree.
- `change-id` and capability names should remain kebab-case.
