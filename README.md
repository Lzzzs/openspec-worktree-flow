# openspec-worktree-flow

[English](./README.md) | [简体中文](./README.zh-CN.md)

`openspec-worktree-flow` provides the `owf` CLI, a Codex-focused workflow for handing approved OpenSpec changes off into isolated worktrees.

It is designed for teams that already use OpenSpec for proposal/spec work, but want a separate, predictable way to bootstrap repository guidance and move implementation into sibling worktrees.

## User flow

Users only need to remember one command:

```bash
owf init
```

After that:

1. keep using the repository's normal OpenSpec proposal flow
2. approve the change
3. ask Codex to implement
4. Codex sees the `AGENTS.md` handoff rule and asks whether to create the implementation worktree

## Install

Global install:

```bash
npm install -g openspec-worktree-flow
```

One-off use:

```bash
npx openspec-worktree-flow init
```

Codex skill install for maintainers is still supported through:

```bash
bash scripts/install_to_codex_home.sh --force
```

## Commands

- `owf init [repo-path]`: bootstrap the repository by updating `AGENTS.md` and creating `.owf/migration_rules.sh`
- `owf status <change-id>`: inspect proposal / branch / worktree state
- `owf start <change-id>`: create the implementation branch and sibling worktree
- `owf cleanup <change-id>`: remove the worktree and optionally the branch
- `owf list`: list worktrees for the current repository

Advanced:

- `owf sync-agents [repo-path]`: refresh only the managed `AGENTS.md` block
- `owf change-init <change-id> ...`: scaffold OpenSpec change files with the legacy engine

## Repository bootstrap

Run once per repository:

```bash
owf init
```

This does two things:

- injects or refreshes a managed `AGENTS.md` block that tells Codex to resolve worktree handoff before implementation starts in the main checkout
- creates `.owf/migration_rules.sh`, the repo-local migration rules file that controls what gets copied or symlinked into new worktrees

Default migration rules:

- copy `openspec/`
- symlink `node_modules/`

Teams can edit `.owf/migration_rules.sh` per repository without modifying the global package.

## Implementation handoff

Once a proposal is approved and the user asks to implement, Codex should ask whether to create the worktree now.

Do not ask this during merge, rebase, cherry-pick, cleanup, archive, or other close-out tasks for the same change.

After confirmation:

```bash
owf start add-rrweb-recording
```

Default results:

- branch: `codex/add-rrweb-recording`
- worktree: `../<repo>-add-rrweb-recording`

## Cleanup

After merge:

```bash
owf cleanup add-rrweb-recording --remove-branch
```

## Trigger boundaries

Ask about worktree creation only when the request is moving from proposal to coding, for example:

- implement this change
- start coding
- continue implementation
- begin development for this approved proposal

Do not ask about creating a new worktree when the request is instead about:

- merging the implementation branch
- rebasing or cherry-picking
- cleaning up the branch or worktree
- archiving or closing out the change

## Release

To avoid publishing code without a matching git tag, use the bundled release script:

```bash
bash scripts/release.sh 0.1.4
```

Or through npm:

```bash
npm run release:owf -- 0.1.4
```

This script updates `package.json`, validates the package, creates a release commit, creates tag `v0.1.4`, pushes `main` and the tag, then publishes to npm.

## Repository structure

```text
.
├── bin/
│   └── owf.js
├── package.json
├── SKILL.md
├── agents/
│   └── openai.yaml
├── references/
│   └── workflow.md
├── templates/
│   └── agents_worktree_handoff.md
└── scripts/
    ├── install_to_codex_home.sh
    ├── migration_rules.sh
    └── openspec_worktree.sh
```

## License

MIT. See [LICENSE](./LICENSE).
