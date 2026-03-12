# Workflow Reference

## Purpose

This workflow keeps work isolated at three levels:

- spec isolation: one OpenSpec change per request
- branch isolation: one `codex/<change-id>` branch per approved change
- workspace isolation: one sibling worktree per implementation

## Standard operating procedure

1. Initialize the repository once with `owf init`.
2. Create or update the OpenSpec proposal in the main checkout.
3. Validate the proposal and get approval.
4. If needed, run `owf status <change-id>` to inspect the lifecycle state.
5. When the user asks to implement, treat that as the worktree handoff moment.
6. Ask whether to create the implementation worktree now unless the user already confirmed it.
7. After confirmation, run `owf start <change-id>`.
8. Implement and validate inside the worktree.
9. Merge the branch.
10. Run `owf cleanup <change-id> --remove-branch` when the worktree is no longer needed.

## Repository bootstrap

`owf init` updates two repository-owned artifacts:

- `AGENTS.md`: a managed block that tells Codex to resolve worktree handoff before implementation starts in the main checkout
- `.owf/migration_rules.sh`: repo-local migration rules that define what should be copied or symlinked when a worktree is created

The default rules are:

- copy `openspec/`
- symlink `node_modules/`

Teams can edit `.owf/migration_rules.sh` per repository to customize this behavior.

## When to create the worktree

Create the worktree only after proposal approval and only when implementation is about to begin.

If the proposal is approved and the user is asking to start coding, Codex should proactively use this flow. Do not wait for the user to name the tool.

At the handoff point, explicitly ask whether to create the worktree now unless the user already confirmed that decision.

## Naming rules

- `change-id`: verb-led kebab-case, for example `add-rrweb-recording`
- branch: `codex/<change-id>`
- worktree path: sibling directory named `<repo>-<change-id>`

## Edge cases

- If `main` does not exist, the engine falls back to `master`, then to the current branch.
- If the worktree directory already exists, `owf start` fails instead of reusing it implicitly.
- If the branch is already checked out in another worktree, `owf start` fails fast and prints the conflicting path.
- `owf cleanup` refuses to remove the current checkout.
- If the repository has no `openspec/` directory, `owf init` fails unless explicitly allowed with `--allow-missing-openspec`.
