# Workflow Reference

## Purpose

This workflow keeps requests isolated at three levels:

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
5. If the user now asks to implement, write code, or begin coding, treat that as the worktree handoff moment.
6. Ask whether to create the implementation worktree now unless the user already made that decision explicitly.
7. If the user confirms, create the implementation worktree.
8. `start` should create the worktree from a temporary local snapshot commit when local checkout files need to follow into the new worktree.
9. Implement and validate only inside that worktree.
10. Merge the branch.
11. Remove the worktree.
12. Archive the OpenSpec change after deployment or when the team normally archives changes.

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

Create the worktree only after proposal approval and only when implementation is about to begin. This applies even if there is only one active request in the repository.

If the proposal is approved and the user is asking to start coding, the assistant should proactively use this flow. Do not wait for the user to name the skill.

At that handoff point, the assistant should explicitly ask whether to create the worktree now unless the user already confirmed that choice.

Do not create a worktree when:

- the change is still under discussion
- the proposal may be merged into another change
- the work is only a small documentation fix

Once a change is approved and will receive implementation work, the assistant should recommend moving into a worktree instead of continuing in the main checkout, then wait for confirmation.

## Snapshot behavior when starting

`start` creates the branch and worktree first from a clean base when the checkout is clean.

If the current checkout contains local changes that should follow into the worktree, `start` creates a temporary local snapshot commit from the current checkout state and uses that commit as the worktree base. This is intended to carry over:

- uncommitted proposal files
- staged file contents that are present in the working tree
- unstaged tracked edits
- untracked files that are not ignored

This snapshot is local-only and does not push anything. The new worktree starts with the right files, while the original checkout keeps its existing working tree and staging state.

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
- If the local branch already exists, `start` reuses that branch instead of recreating it unless an explicit reset workflow is chosen outside the script.
- If the branch is already checked out in another worktree, `start` fails fast and prints the conflicting path.
- `init` and `start` default to the main checkout. Running them from another linked worktree requires `--allow-linked-worktree`.
- `cleanup` refuses to remove the current checkout, so run it from a different checkout.
- If the repository has no `openspec/` directory, `init` fails fast because the repository is not set up for OpenSpec scaffolding.
