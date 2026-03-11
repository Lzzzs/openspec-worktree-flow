# Workflow Reference

## Purpose

This workflow keeps parallel requests isolated at three levels:

- spec isolation: one OpenSpec change per request
- branch isolation: one `codex/<change-id>` branch per request
- workspace isolation: one sibling worktree per request

## Standard operating procedure

1. Define the request and choose a unique `change-id`.
2. In the main repository checkout, create or update:
   - `openspec/changes/<change-id>/proposal.md`
   - `openspec/changes/<change-id>/tasks.md`
   - `openspec/changes/<change-id>/specs/<capability>/spec.md`
3. Validate the proposal and get approval.
4. Run `status <change-id>` if you need to confirm the current lifecycle state.
5. After approval, create the implementation worktree.
6. Implement and validate only inside that worktree.
7. Merge the branch.
8. Remove the worktree.
9. Archive the OpenSpec change after deployment or when the team normally archives changes.

## Naming rules

- `change-id`: verb-led kebab-case, for example `add-rrweb-recording`
- branch: `codex/<change-id>`
- worktree path: sibling directory named `<repo>-<change-id>`

Example:

- repository root: `kefu-workbench`
- change id: `update-network-status-hints`
- branch: `codex/update-network-status-hints`
- worktree: `../kefu-workbench-update-network-status-hints`

## When to create the worktree

Create the worktree only after proposal approval and only when implementation is about to begin.

Do not create a worktree when:

- the change is still under discussion
- the proposal may be merged into another change
- the work is only a small documentation fix

## When to keep or remove the worktree

Remove it when:

- the branch is merged and no follow-up fix is expected
- the proposal is canceled
- the request is folded into another change

Keep it temporarily when:

- review comments are still arriving
- post-merge validation or rollout follow-up is still active
- the change is merged but not yet operationally closed

## Typical commands

Initialize a change:

```bash
"$OWF" init add-rrweb-recording --capability recording --title "rrweb 录制 MVP"
```

Start implementation:

```bash
"$OWF" start add-rrweb-recording
```

Check whether the change is ready to start or safe to clean up:

```bash
"$OWF" status add-rrweb-recording
```

Use a specific base branch:

```bash
"$OWF" start add-rrweb-recording --base develop
```

List active worktrees:

```bash
"$OWF" list
```

Cleanup:

```bash
"$OWF" cleanup add-rrweb-recording --remove-branch
```

## Edge cases

- If `main` does not exist, the script falls back to `master`, then to the current branch.
- If the local base branch does not exist but `origin/main` or `origin/master` does, the script uses the remote-tracking ref.
- If the worktree directory already exists, the script stops instead of reusing it implicitly.
- If the local branch already exists, `start` reuses that branch instead of recreating it.
- If the branch is already checked out in another worktree, `start` fails fast and prints the conflicting path.
- `init` and `start` default to the main checkout. Running them from another linked worktree requires `--allow-linked-worktree`.
- `cleanup` refuses to remove the current checkout, so run it from a different checkout.
- If the repository has no `openspec/` directory, `init` fails fast because the repository is not set up for OpenSpec scaffolding.
