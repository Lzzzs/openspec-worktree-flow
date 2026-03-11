# openspec-worktree-flow

[English](./README.md) | [简体中文](./README.zh-CN.md)

`openspec-worktree-flow` is a Codex skill for running a proposal-first workflow with:

- one OpenSpec change per request
- one `codex/<change-id>` branch per approved change
- one sibling `git worktree` per implementation

It is designed for teams that want approved implementation work to happen outside the main checkout. That includes both single-request and multi-request development.

## What problem it solves

Teams often run into the same failures:

- several requests share one branch
- work starts before the proposal is stable
- the main checkout accumulates partial implementation changes
- stale worktrees and local branches are left behind after merge

This skill standardizes the flow:

1. create proposal artifacts in the main checkout
2. get approval
3. move the approved change into one isolated branch and worktree for implementation
4. clean up after merge

## Commands

The skill exposes one script:

```bash
openspec_worktree.sh
```

Supported commands:

- `init`: scaffold an OpenSpec change
- `status`: inspect proposal, branch, and worktree state for a change
- `start`: create the implementation branch and worktree
- `list`: list repository worktrees
- `cleanup`: remove the worktree and optionally delete the branch

## Install into Codex

### Option 1: copy into Codex skills

Install this repository into:

```bash
$HOME/.codex/skills/openspec-worktree-flow
```

If the repository is already checked out locally:

```bash
bash scripts/install_to_codex_home.sh
```

To replace an existing install:

```bash
bash scripts/install_to_codex_home.sh --force
```

Restart Codex after installing or updating the skill.

### Option 2: use the script directly from a local checkout

If you just want to try the workflow without installing the skill into Codex:

```bash
export OWF="$(pwd)/scripts/openspec_worktree.sh"
```

## Standard workflow

Set the script path:

```bash
export CODEX_HOME="${CODEX_HOME:-$HOME/.codex}"
export OWF="$CODEX_HOME/skills/openspec-worktree-flow/scripts/openspec_worktree.sh"
```

### 1. Create proposal artifacts in the main checkout

```bash
"$OWF" init add-rrweb-recording --capability recording --title "rrweb recording MVP" --with-design
```

This creates:

- `openspec/changes/add-rrweb-recording/proposal.md`
- `openspec/changes/add-rrweb-recording/tasks.md`
- `openspec/changes/add-rrweb-recording/design.md`
- `openspec/changes/add-rrweb-recording/specs/recording/spec.md`

### 2. Inspect status

```bash
"$OWF" status add-rrweb-recording
```

Use `status` before `start` if you want to confirm that the proposal exists and the implementation worktree has not already been created.

### 3. Start implementation after approval

```bash
"$OWF" start add-rrweb-recording
```

By default this creates:

- branch: `codex/add-rrweb-recording`
- worktree: `../<repo>-add-rrweb-recording`

### 4. Develop inside the worktree

Example:

```bash
cd ../your-repo-add-rrweb-recording
```

Do implementation, validation, and commits in that worktree, not in the main checkout. This is the default path even when only one request is active.

### 5. Clean up after merge

```bash
"$OWF" cleanup add-rrweb-recording --remove-branch
```

## Guardrails

- `init` and `start` default to the main checkout, not an existing linked worktree
- approved implementation work should move into a worktree instead of staying in the main checkout
- `change-id` and capability names must be kebab-case
- `start` fails if the branch is already checked out elsewhere
- `cleanup` refuses to remove the current checkout
- `init` requires `openspec/`
- `start` can still work without `openspec/`, but warns unless explicitly allowed

## Repository structure

```text
.
├── SKILL.md
├── README.md
├── agents/
│   └── openai.yaml
├── references/
│   └── workflow.md
└── scripts/
    ├── install_to_codex_home.sh
    └── openspec_worktree.sh
```

## Versioning

- tag releases when command behavior changes
- treat script flag changes as versioned interface changes
- update the installed Codex skill after pulling a newer release

## License

MIT. See [LICENSE](./LICENSE).
