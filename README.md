# openspec-worktree-flow

A Codex skill for running a proposal-first `OpenSpec + branch + git worktree` workflow.

## What it does

- scaffolds an OpenSpec change with `init`
- checks change lifecycle state with `status`
- creates one implementation branch and one worktree per approved change with `start`
- lists active worktrees with `list`
- cleans up worktrees and optional branches with `cleanup`

## Install into Codex

Copy or install this repository into:

```bash
$HOME/.codex/skills/openspec-worktree-flow
```

If this repo is already checked out locally, you can run:

```bash
bash scripts/install_to_codex_home.sh
```

To replace an existing install:

```bash
bash scripts/install_to_codex_home.sh --force
```

Restart Codex after installing or updating the skill.

## Usage

```bash
export CODEX_HOME="${CODEX_HOME:-$HOME/.codex}"
export OWF="$CODEX_HOME/skills/openspec-worktree-flow/scripts/openspec_worktree.sh"
```

Create proposal artifacts:

```bash
"$OWF" init add-rrweb-recording --capability recording --title "rrweb 录制 MVP" --with-design
```

Inspect state:

```bash
"$OWF" status add-rrweb-recording
```

Start implementation:

```bash
"$OWF" start add-rrweb-recording
```

Clean up after merge:

```bash
"$OWF" cleanup add-rrweb-recording --remove-branch
```
