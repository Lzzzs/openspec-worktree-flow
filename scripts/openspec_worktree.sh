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
  cat <<'USAGE'
Usage:
  openspec_worktree.sh init <change-id> --capability <capability> [--title <title>] [--with-design] [--allow-linked-worktree]
  openspec_worktree.sh start <change-id> [--base <branch-or-ref>] [--worktree-dir <path>] [--allow-missing-change] [--allow-linked-worktree] [--no-snapshot]
  openspec_worktree.sh repo-init [repo-path] [--allow-missing-openspec] [--force-rules]
  openspec_worktree.sh sync-agents [repo-path] [--allow-missing-openspec]
  openspec_worktree.sh status <change-id>
  openspec_worktree.sh cleanup <change-id> [--worktree-dir <path>] [--remove-branch] [--force]
  openspec_worktree.sh list

Commands:
  init     Scaffold an OpenSpec change in the current repository.
  start    Create or reuse codex/<change-id> and add a sibling worktree. When local files are dirty, use a temporary local snapshot commit by default, then apply selective migration rules from `scripts/migration_rules.sh`.
  repo-init  Bootstrap a repository for owf by updating AGENTS.md and creating repo-local migration rules in .owf/.
  sync-agents  Inject or refresh a managed AGENTS.md block that enforces worktree handoff before implementation.
  status   Show OpenSpec, branch, and worktree status for the change.
  cleanup  Remove the worktree for the change and optionally delete the branch.
  list     List worktrees for the current repository.
USAGE
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

script_root() {
  cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd
}

agents_template_file() {
  echo "$(script_root)/templates/agents_worktree_handoff.md"
}

bundled_migration_rules_file() {
  echo "$(script_root)/scripts/migration_rules.sh"
}

default_copy_paths() {
  COPY_PATHS=(
    "openspec"
  )
}

default_symlink_paths() {
  SYMLINK_PATHS=(
    "node_modules"
  )
}

load_migration_rules() {
  local root=""
  local repo_rules=""
  local bundled_rules=""

  default_copy_paths
  default_symlink_paths

  if git rev-parse --show-toplevel >/dev/null 2>&1; then
    root="$(git rev-parse --show-toplevel)"
    repo_rules="$root/.owf/migration_rules.sh"

    if [[ -f "$repo_rules" ]]; then
      # shellcheck source=/dev/null
      source "$repo_rules"
      return
    fi
  fi

  bundled_rules="$(bundled_migration_rules_file)"
  if [[ -f "$bundled_rules" ]]; then
    # shellcheck source=/dev/null
    source "$bundled_rules"
  fi
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

has_local_checkout_state() {
  ! git diff --quiet --ignore-submodules -- ||
    ! git diff --cached --quiet --ignore-submodules -- ||
    [[ -n "$(git ls-files --others --exclude-standard)" ]]
}

create_snapshot_commit() {
  local change_id="$1"
  local tmp_index=""
  local tree=""
  local commit=""
  local parent=""

  tmp_index="$(mktemp "${TMPDIR:-/tmp}/openspec-worktree-index.XXXXXX")"
  trap 'rm -f "$tmp_index"' RETURN

  if [[ -f "$(git rev-parse --git-path index)" ]]; then
    cp "$(git rev-parse --git-path index)" "$tmp_index"
  else
    : >"$tmp_index"
  fi

  GIT_INDEX_FILE="$tmp_index" git add -A
  tree="$(GIT_INDEX_FILE="$tmp_index" git write-tree)"
  parent="$(git rev-parse HEAD)"
  commit="$({ printf 'chore: temporary worktree snapshot for %s\n' "$change_id"; } | git commit-tree "$tree" -p "$parent")"

  rm -f "$tmp_index"
  trap - RETURN

  echo "$commit"
}

copy_path_into_worktree() {
  local source_root="$1"
  local target_root="$2"
  local rel_path="$3"
  local source_path="$source_root/$rel_path"
  local target_path="$target_root/$rel_path"

  [[ -e "$source_path" ]] || return

  rm -rf "$target_path"
  mkdir -p "$(dirname "$target_path")"

  if command -v rsync >/dev/null 2>&1; then
    if [[ -d "$source_path" ]]; then
      mkdir -p "$target_path"
      rsync -a --delete --exclude='.git' "$source_path/" "$target_path/"
    else
      rsync -a --exclude='.git' "$source_path" "$target_path"
    fi
  elif [[ -d "$source_path" ]]; then
    cp -R "$source_path" "$target_path"
  else
    cp "$source_path" "$target_path"
  fi
}

symlink_path_into_worktree() {
  local source_root="$1"
  local target_root="$2"
  local rel_path="$3"
  local source_path="$source_root/$rel_path"
  local target_path="$target_root/$rel_path"

  [[ -e "$source_path" ]] || return
  [[ -e "$target_path" || -L "$target_path" ]] && return

  mkdir -p "$(dirname "$target_path")"
  ln -s "$source_path" "$target_path"
}

apply_migration_rules() {
  local source_root="$1"
  local target_root="$2"
  local copied=()
  local linked=()
  local rel_path=""

  for rel_path in "${COPY_PATHS[@]}"; do
    if [[ -e "$source_root/$rel_path" ]]; then
      copy_path_into_worktree "$source_root" "$target_root" "$rel_path"
      copied+=("$rel_path")
    fi
  done

  for rel_path in "${SYMLINK_PATHS[@]}"; do
    if [[ -e "$source_root/$rel_path" && ! -e "$target_root/$rel_path" && ! -L "$target_root/$rel_path" ]]; then
      symlink_path_into_worktree "$source_root" "$target_root" "$rel_path"
      linked+=("$rel_path")
    fi
  done

  if ((${#copied[@]} > 0)); then
    info "  copied: $(IFS=', '; echo "${copied[*]}")"
  fi

  if ((${#linked[@]} > 0)); then
    info "  linked: $(IFS=', '; echo "${linked[*]}")"
  fi
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
    echo "Create proposal artifacts first with your proposal workflow or manually scaffold openspec/changes/$change_id/."
    return
  fi

  if [[ ! -f "$(proposal_file "$change_id")" || ! -f "$(tasks_file "$change_id")" ]]; then
    echo "Finish the proposal files before starting implementation."
    return
  fi

  if [[ -z "$worktree_path" ]]; then
    echo "Proposal artifacts exist. If the proposal is approved or the user is asking to start coding, proactively ask whether to create the worktree now, then run start after confirmation."
    return
  fi

  echo "Implementation worktree exists. Continue development there or clean it up after merge."
}

write_proposal() {
  local file="$1"
  local title="$2"

  cat >"$file" <<EOF2
# Change: $title

## Why
- [Describe the user or business need]

## What Changes
- [List the main behavior changes]

## Impact
- Affected specs: [list capabilities]
- Affected code: [list main modules or files]
EOF2
}

write_tasks() {
  local file="$1"

  cat >"$file" <<'EOF2'
## 1. Implementation
- [ ] 1.1 Define or refine the scope after approval
- [ ] 1.2 Implement the change
- [ ] 1.3 Validate the affected entry or workflow
- [ ] 1.4 Update OpenSpec artifacts to match the final implementation
EOF2
}

write_design() {
  local file="$1"

  cat >"$file" <<'EOF2'
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
EOF2
}

write_spec() {
  local file="$1"

  cat >"$file" <<'EOF2'
## ADDED Requirements
### Requirement: Placeholder Requirement
The system SHALL [describe the expected behavior].

#### Scenario: Success case
- **WHEN** [the triggering condition occurs]
- **THEN** [the observable outcome happens]
EOF2
}

agents_block_begin() {
  echo "<!-- BEGIN OPENSPEC WORKTREE FLOW -->"
}

agents_block_end() {
  echo "<!-- END OPENSPEC WORKTREE FLOW -->"
}

target_repo_root() {
  local input_path="${1:-.}"

  [[ -d "$input_path" ]] || die "repository path does not exist: $input_path"

  if git -C "$input_path" rev-parse --show-toplevel >/dev/null 2>&1; then
    git -C "$input_path" rev-parse --show-toplevel
    return
  fi

  cd "$input_path" && pwd
}

render_agents_block() {
  local template_file
  template_file="$(agents_template_file)"
  [[ -f "$template_file" ]] || die "AGENTS template is missing: $template_file"

  printf "%s\n" "$(agents_block_begin)"
  cat "$template_file"
  printf "\n%s\n" "$(agents_block_end)"
}

replace_or_append_managed_block() {
  local agents_file="$1"
  local block_file="$2"
  local begin_marker
  local end_marker
  local tmp_file

  begin_marker="$(agents_block_begin)"
  end_marker="$(agents_block_end)"
  tmp_file="$(mktemp "${TMPDIR:-/tmp}/openspec-worktree-agents.XXXXXX")"

  if [[ -f "$agents_file" ]] && grep -Fq "$begin_marker" "$agents_file"; then
    awk -v begin="$begin_marker" -v end="$end_marker" -v replacement="$block_file" '
      $0 == begin {
        while ((getline line < replacement) > 0) {
          print line
        }
        close(replacement)
        skipping = 1
        next
      }
      $0 == end {
        skipping = 0
        next
      }
      skipping != 1 { print }
    ' "$agents_file" >"$tmp_file"
  elif [[ -f "$agents_file" ]]; then
    cat "$agents_file" >"$tmp_file"
    if [[ -s "$agents_file" ]]; then
      printf "\n\n" >>"$tmp_file"
    fi
    cat "$block_file" >>"$tmp_file"
  else
    cat "$block_file" >"$tmp_file"
  fi

  mv "$tmp_file" "$agents_file"
}

ensure_repo_local_rules() {
  local target_root="$1"
  local force_rules="$2"
  local target_dir="$target_root/.owf"
  local target_rules="$target_dir/migration_rules.sh"
  local bundled_rules

  bundled_rules="$(bundled_migration_rules_file)"
  [[ -f "$bundled_rules" ]] || die "bundled migration rules are missing: $bundled_rules"

  mkdir -p "$target_dir"

  if [[ -f "$target_rules" && "$force_rules" != "true" ]]; then
    info "  kept:   $target_rules"
    return
  fi

  cp "$bundled_rules" "$target_rules"
  chmod +x "$target_rules"
  info "  wrote:  $target_rules"
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

cmd_sync_agents() {
  local repo_path="."
  local allow_missing_openspec="false"

  while (($#)); do
    case "$1" in
      --allow-missing-openspec)
        allow_missing_openspec="true"
        shift
        ;;
      -*)
        die "unknown option for sync-agents: $1"
        ;;
      *)
        [[ "$repo_path" == "." ]] || die "sync-agents accepts at most one repo path"
        repo_path="$1"
        shift
        ;;
    esac
  done

  local target_root=""
  local target_agents=""
  local target_openspec=""
  local block_file=""

  target_root="$(target_repo_root "$repo_path")"
  target_agents="$target_root/AGENTS.md"
  target_openspec="$target_root/openspec"
  block_file="$(mktemp "${TMPDIR:-/tmp}/openspec-worktree-managed-block.XXXXXX")"
  trap 'rm -f "$block_file"' RETURN

  if [[ ! -d "$target_openspec" && "$allow_missing_openspec" != "true" ]]; then
    die "openspec/ not found in target repository: $target_root"
  fi

  render_agents_block >"$block_file"
  replace_or_append_managed_block "$target_agents" "$block_file"

  rm -f "$block_file"
  trap - RETURN

  info "Updated AGENTS.md:"
  info "  $target_agents"
}

cmd_repo_init() {
  local repo_path="."
  local allow_missing_openspec="false"
  local force_rules="false"

  while (($#)); do
    case "$1" in
      --allow-missing-openspec)
        allow_missing_openspec="true"
        shift
        ;;
      --force-rules)
        force_rules="true"
        shift
        ;;
      -*)
        die "unknown option for repo-init: $1"
        ;;
      *)
        [[ "$repo_path" == "." ]] || die "repo-init accepts at most one repo path"
        repo_path="$1"
        shift
        ;;
    esac
  done

  local target_root=""

  target_root="$(target_repo_root "$repo_path")"

  if [[ "$allow_missing_openspec" == "true" ]]; then
    cmd_sync_agents "$target_root" --allow-missing-openspec
  else
    cmd_sync_agents "$target_root"
  fi

  ensure_repo_local_rules "$target_root" "$force_rules"

  info "Initialized owf repository support:"
  info "  repo:   $target_root"
}

cmd_start() {
  local change_id="$1"
  shift

  local base_ref=""
  local worktree_dir=""
  local allow_missing_change="false"
  local allow_linked_worktree="false"
  local use_snapshot="true"
  local branch_name="codex/$change_id"
  local start_ref=""
  local start_from_snapshot="false"
  local source_root=""

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
      --no-snapshot)
        use_snapshot="false"
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
  load_migration_rules

  source_root="$(repo_root)"

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

  start_ref="$base_ref"
  if [[ "$use_snapshot" == "true" && "$(has_local_checkout_state && echo yes || echo no)" == "yes" ]]; then
    if branch_exists "$branch_name"; then
      die "branch $branch_name already exists. Remove or rename the branch before starting with a local snapshot."
    fi
    start_ref="$(create_snapshot_commit "$change_id")"
    start_from_snapshot="true"
  fi

  if branch_exists "$branch_name"; then
    git worktree add "$worktree_dir" "$branch_name"
  else
    git worktree add "$worktree_dir" -b "$branch_name" "$start_ref"
  fi

  apply_migration_rules "$source_root" "$worktree_dir"

  info "Created worktree:"
  info "  branch: $branch_name"
  info "  path:   $worktree_dir"
  info "  base:   $base_ref"
  if [[ "$start_from_snapshot" == "true" ]]; then
    info "  sync:   created from a temporary local snapshot commit"
  elif [[ "$use_snapshot" == "false" ]]; then
    info "  sync:   skipped by --no-snapshot"
  else
    info "  sync:   checkout was clean, so no snapshot was needed"
  fi
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

  local cmd="$1"
  shift

  case "$cmd" in
    init)
      (($# >= 1)) || die "init requires <change-id>"
      cmd_init "$@"
      ;;
    start)
      (($# >= 1)) || die "start requires <change-id>"
      cmd_start "$@"
      ;;
    repo-init)
      cmd_repo_init "$@"
      ;;
    sync-agents)
      cmd_sync_agents "$@"
      ;;
    status)
      (($# == 1)) || die "status requires exactly <change-id>"
      cmd_status "$1"
      ;;
    cleanup)
      (($# >= 1)) || die "cleanup requires <change-id>"
      cmd_cleanup "$@"
      ;;
    list)
      (($# == 0)) || die "list takes no arguments"
      cmd_list
      ;;
    -h|--help|help)
      usage
      ;;
    *)
      die "unknown command: $cmd"
      ;;
  esac
}

main "$@"
