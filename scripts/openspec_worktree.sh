#!/usr/bin/env bash

set -euo pipefail

die() {
  echo "Error: $*" >&2
  exit 1
}

warn() {
  echo "Warning: $*" >&2
}

info() {
  echo "$*"
}

usage() {
  cat <<'EOF'
Usage:
  openspec_worktree.sh init <change-id> --capability <capability> [--title <title>] [--with-design] [--allow-linked-worktree]
  openspec_worktree.sh start <change-id> [--base <branch-or-ref>] [--worktree-dir <path>] [--allow-missing-change] [--allow-linked-worktree]
  openspec_worktree.sh status <change-id>
  openspec_worktree.sh cleanup <change-id> [--worktree-dir <path>] [--remove-branch] [--force]
  openspec_worktree.sh list

Commands:
  init     Scaffold an OpenSpec change in the current repository.
  start    Create or reuse codex/<change-id> and add a sibling worktree.
  status   Show OpenSpec, branch, and worktree status for the change.
  cleanup  Remove the worktree for the change and optionally delete the branch.
  list     List worktrees for the current repository.
EOF
}

require_git_repo() {
  git rev-parse --is-inside-work-tree >/dev/null 2>&1 || die "not inside a git repository"
}

repo_root() {
  git rev-parse --show-toplevel
}

repo_name() {
  basename "$(repo_root)"
}

openspec_root() {
  echo "$(repo_root)/openspec"
}

change_dir() {
  local change_id="$1"
  echo "$(openspec_root)/changes/$change_id"
}

proposal_file() {
  local change_id="$1"
  echo "$(change_dir "$change_id")/proposal.md"
}

tasks_file() {
  local change_id="$1"
  echo "$(change_dir "$change_id")/tasks.md"
}

design_file() {
  local change_id="$1"
  echo "$(change_dir "$change_id")/design.md"
}

current_branch() {
  git branch --show-current
}

is_main_checkout() {
  [[ -d "$(repo_root)/.git" ]]
}

require_main_checkout() {
  local allow_linked="${1:-false}"

  if [[ "$allow_linked" == "true" ]]; then
    return
  fi

  is_main_checkout && return

  die "current checkout is a linked worktree. Run this from the main repository checkout or pass --allow-linked-worktree"
}

validate_kebab() {
  local label="$1"
  local value="$2"

  [[ -n "$value" ]] || die "$label cannot be empty"
  [[ "$value" =~ ^[a-z0-9]+(-[a-z0-9]+)*$ ]] || die "$label must be kebab-case using lowercase letters, digits, and hyphens: $value"
}

branch_exists() {
  local branch_name="$1"
  git show-ref --verify --quiet "refs/heads/$branch_name"
}

change_exists() {
  local change_id="$1"
  [[ -d "$(change_dir "$change_id")" ]]
}

default_base_ref() {
  if git show-ref --verify --quiet refs/heads/main; then
    echo "main"
    return
  fi

  if git show-ref --verify --quiet refs/heads/master; then
    echo "master"
    return
  fi

  if git show-ref --verify --quiet refs/remotes/origin/main; then
    echo "origin/main"
    return
  fi

  if git show-ref --verify --quiet refs/remotes/origin/master; then
    echo "origin/master"
    return
  fi

  local branch
  branch="$(current_branch)"
  [[ -n "$branch" ]] || die "could not determine a default base branch"
  echo "$branch"
}

ref_exists() {
  local ref="$1"
  git rev-parse --verify --quiet "$ref^{commit}" >/dev/null 2>&1
}

default_worktree_dir() {
  local change_id="$1"
  local root
  local parent
  root="$(repo_root)"
  parent="$(cd "$root/.." && pwd)"
  echo "$parent/$(repo_name)-$change_id"
}

find_worktree_for_branch() {
  local branch_name="$1"

  git worktree list --porcelain | awk -v target="refs/heads/$branch_name" '
    /^worktree / { path=$2 }
    /^branch / {
      if ($2 == target) {
        print path
        exit
      }
    }
  '
}

find_worktree_for_path() {
  local target_path="$1"

  git worktree list --porcelain | awk -v target="$target_path" '
    /^worktree / {
      if ($2 == target) {
        print $2
        exit
      }
    }
  '
}

recommendation_for_change() {
  local change_id="$1"
  local branch_name="codex/$change_id"
  local worktree_path
  worktree_path="$(find_worktree_for_branch "$branch_name")"

  if [[ ! -d "$(openspec_root)" ]]; then
    echo "Repository has no openspec/. Use start only if this repo is intentionally not using OpenSpec."
    return
  fi

  if ! change_exists "$change_id"; then
    echo "Create proposal artifacts first with init or manually scaffold openspec/changes/$change_id/."
    return
  fi

  if [[ ! -f "$(proposal_file "$change_id")" || ! -f "$(tasks_file "$change_id")" ]]; then
    echo "Finish the proposal files before starting implementation."
    return
  fi

  if [[ -z "$worktree_path" ]]; then
    echo "Proposal artifacts exist. If approved, run start to create the implementation worktree."
    return
  fi

  echo "Implementation worktree exists. Continue development there or clean it up after merge."
}

write_proposal() {
  local file="$1"
  local title="$2"

  cat >"$file" <<EOF
# Change: $title

## Why
- [Describe the user or business need]

## What Changes
- [List the main behavior changes]

## Impact
- Affected specs: [list capabilities]
- Affected code: [list main modules or files]
EOF
}

write_tasks() {
  local file="$1"

  cat >"$file" <<'EOF'
## 1. Implementation
- [ ] 1.1 Define or refine the scope after approval
- [ ] 1.2 Implement the change
- [ ] 1.3 Validate the affected entry or workflow
- [ ] 1.4 Update OpenSpec artifacts to match the final implementation
EOF
}

write_design() {
  local file="$1"

  cat >"$file" <<'EOF'
## Context
[Background, constraints, and stakeholders]

## Goals / Non-Goals
- Goals: [...]
- Non-Goals: [...]

## Decisions
- Decision: [What and why]
- Alternatives considered: [Options and rationale]

## Risks / Trade-offs
- [Risk] -> [Mitigation]

## Migration Plan
[Steps and rollback]

## Open Questions
- [...]
EOF
}

write_spec() {
  local file="$1"

  cat >"$file" <<'EOF'
## ADDED Requirements
### Requirement: Placeholder Requirement
The system SHALL [describe the expected behavior].

#### Scenario: Success case
- **WHEN** [the triggering condition occurs]
- **THEN** [the observable outcome happens]
EOF
}

cmd_init() {
  local change_id="$1"
  shift

  local capability=""
  local title=""
  local with_design="false"
  local allow_linked_worktree="false"

  while (($#)); do
    case "$1" in
      --capability)
        [[ $# -ge 2 ]] || die "--capability requires a value"
        capability="$2"
        shift 2
        ;;
      --title)
        [[ $# -ge 2 ]] || die "--title requires a value"
        title="$2"
        shift 2
        ;;
      --with-design)
        with_design="true"
        shift
        ;;
      --allow-linked-worktree)
        allow_linked_worktree="true"
        shift
        ;;
      *)
        die "unknown option for init: $1"
        ;;
    esac
  done

  require_git_repo
  require_main_checkout "$allow_linked_worktree"
  [[ -d "$(openspec_root)" ]] || die "openspec/ not found in this repository"
  validate_kebab "change-id" "$change_id"
  [[ -n "$capability" ]] || die "--capability is required for init"
  validate_kebab "capability" "$capability"

  if [[ -z "$title" ]]; then
    title="$change_id"
  fi

  local dir
  dir="$(change_dir "$change_id")"
  [[ ! -e "$dir" ]] || die "change already exists: $dir"

  mkdir -p "$dir/specs/$capability"
  write_proposal "$dir/proposal.md" "$title"
  write_tasks "$dir/tasks.md"
  write_spec "$dir/specs/$capability/spec.md"

  if [[ "$with_design" == "true" ]]; then
    write_design "$dir/design.md"
  fi

  info "Created OpenSpec change scaffold:"
  info "  $dir"
}

cmd_start() {
  local change_id="$1"
  shift

  local base_ref=""
  local worktree_dir=""
  local allow_missing_change="false"
  local allow_linked_worktree="false"
  local branch_name="codex/$change_id"

  while (($#)); do
    case "$1" in
      --base)
        [[ $# -ge 2 ]] || die "--base requires a value"
        base_ref="$2"
        shift 2
        ;;
      --worktree-dir)
        [[ $# -ge 2 ]] || die "--worktree-dir requires a value"
        worktree_dir="$2"
        shift 2
        ;;
      --allow-missing-change)
        allow_missing_change="true"
        shift
        ;;
      --allow-linked-worktree)
        allow_linked_worktree="true"
        shift
        ;;
      *)
        die "unknown option for start: $1"
        ;;
    esac
  done

  require_git_repo
  require_main_checkout "$allow_linked_worktree"
  validate_kebab "change-id" "$change_id"

  if [[ -d "$(openspec_root)" ]]; then
    if ! change_exists "$change_id"; then
      [[ "$allow_missing_change" == "true" ]] || die "openspec/changes/$change_id was not found. Create the proposal first or pass --allow-missing-change"
      warn "proceeding without openspec/changes/$change_id because --allow-missing-change was provided"
    else
      [[ -f "$(proposal_file "$change_id")" ]] || warn "proposal.md is missing for $change_id"
      [[ -f "$(tasks_file "$change_id")" ]] || warn "tasks.md is missing for $change_id"
    fi
  else
    warn "openspec/ not found in this repository; start will create only the branch and worktree"
  fi

  if [[ -z "$base_ref" ]]; then
    base_ref="$(default_base_ref)"
  fi

  ref_exists "$base_ref" || die "base ref does not exist locally: $base_ref"

  if [[ -z "$worktree_dir" ]]; then
    worktree_dir="$(default_worktree_dir "$change_id")"
  fi

  local attached_branch_path=""
  attached_branch_path="$(find_worktree_for_branch "$branch_name")"
  if [[ -n "$attached_branch_path" ]]; then
    die "branch $branch_name is already checked out in worktree: $attached_branch_path"
  fi

  local attached_path=""
  attached_path="$(find_worktree_for_path "$worktree_dir")"
  if [[ -n "$attached_path" ]]; then
    die "worktree path is already registered: $attached_path"
  fi

  [[ ! -e "$worktree_dir" ]] || die "worktree path already exists on disk: $worktree_dir"

  if branch_exists "$branch_name"; then
    git worktree add "$worktree_dir" "$branch_name"
  else
    git worktree add "$worktree_dir" -b "$branch_name" "$base_ref"
  fi

  info "Created worktree:"
  info "  branch: $branch_name"
  info "  path:   $worktree_dir"
  info "  base:   $base_ref"
}

cmd_status() {
  local change_id="$1"
  local branch_name="codex/$change_id"
  local worktree_path=""

  require_git_repo
  validate_kebab "change-id" "$change_id"

  worktree_path="$(find_worktree_for_branch "$branch_name")"

  info "Repository:      $(repo_root)"
  info "Main checkout:   $(is_main_checkout && echo yes || echo no)"
  info "Current branch:  $(current_branch)"
  info "OpenSpec:        $([[ -d "$(openspec_root)" ]] && echo present || echo missing)"
  info "Change dir:      $([[ -d "$(change_dir "$change_id")" ]] && echo present || echo missing)"
  info "Proposal:        $([[ -f "$(proposal_file "$change_id")" ]] && echo present || echo missing)"
  info "Tasks:           $([[ -f "$(tasks_file "$change_id")" ]] && echo present || echo missing)"
  info "Design:          $([[ -f "$(design_file "$change_id")" ]] && echo present || echo missing)"
  info "Branch:          $(branch_exists "$branch_name" && echo present || echo missing)"
  info "Worktree:        ${worktree_path:-missing}"
  info "Next step:       $(recommendation_for_change "$change_id")"
}

cmd_cleanup() {
  local change_id="$1"
  shift

  local worktree_dir=""
  local remove_branch="false"
  local force="false"
  local branch_name="codex/$change_id"

  while (($#)); do
    case "$1" in
      --worktree-dir)
        [[ $# -ge 2 ]] || die "--worktree-dir requires a value"
        worktree_dir="$2"
        shift 2
        ;;
      --remove-branch)
        remove_branch="true"
        shift
        ;;
      --force)
        force="true"
        shift
        ;;
      *)
        die "unknown option for cleanup: $1"
        ;;
    esac
  done

  require_git_repo
  validate_kebab "change-id" "$change_id"

  if [[ -z "$worktree_dir" ]]; then
    worktree_dir="$(find_worktree_for_branch "$branch_name")"
  fi

  [[ -n "$worktree_dir" ]] || die "could not determine a worktree path for $branch_name"
  [[ -e "$worktree_dir" ]] || die "worktree path does not exist: $worktree_dir"

  if [[ "$(repo_root)" == "$worktree_dir" ]]; then
    die "refusing to remove the current checkout. Run cleanup from a different checkout."
  fi

  if [[ "$force" == "true" ]]; then
    git worktree remove --force "$worktree_dir"
  else
    git worktree remove "$worktree_dir"
  fi

  if [[ "$remove_branch" == "true" ]] && branch_exists "$branch_name"; then
    local remaining_branch_path=""
    remaining_branch_path="$(find_worktree_for_branch "$branch_name")"

    if [[ -n "$remaining_branch_path" ]]; then
      warn "branch $branch_name is still checked out in another worktree: $remaining_branch_path"
    else
      if [[ "$force" == "true" ]]; then
        git branch -D "$branch_name"
      else
        git branch -d "$branch_name"
      fi
    fi
  fi

  info "Cleaned up:"
  info "  path:   $worktree_dir"
  info "  branch: $branch_name"
}

cmd_list() {
  require_git_repo
  git worktree list
}

main() {
  (($# >= 1)) || {
    usage
    exit 1
  }

  local command="$1"
  shift

  case "$command" in
    init)
      (($# >= 1)) || die "init requires <change-id>"
      cmd_init "$@"
      ;;
    start)
      (($# >= 1)) || die "start requires <change-id>"
      cmd_start "$@"
      ;;
    status)
      (($# >= 1)) || die "status requires <change-id>"
      cmd_status "$@"
      ;;
    cleanup)
      (($# >= 1)) || die "cleanup requires <change-id>"
      cmd_cleanup "$@"
      ;;
    list)
      cmd_list
      ;;
    -h|--help|help)
      usage
      ;;
    *)
      die "unknown command: $command"
      ;;
  esac
}

main "$@"
