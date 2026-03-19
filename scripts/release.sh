#!/usr/bin/env bash

set -euo pipefail

usage() {
  cat <<'EOF'
Usage:
  bash scripts/release.sh <version> [--no-publish]

Examples:
  bash scripts/release.sh 0.1.4
  bash scripts/release.sh 0.1.4 --no-publish

This script:
  1. verifies the git worktree is clean
  2. updates package.json to the target version
  3. runs npm pack --dry-run
  4. commits the version bump
  5. creates an annotated git tag v<version>
  6. pushes main and the tag
  7. publishes to npm unless --no-publish is provided
EOF
}

die() {
  echo "Error: $*" >&2
  exit 1
}

info() {
  echo "$*"
}

require_clean_worktree() {
  git diff --quiet --ignore-submodules -- || die "git working tree has unstaged changes"
  git diff --cached --quiet --ignore-submodules -- || die "git index has staged but uncommitted changes"
  [[ -z "$(git ls-files --others --exclude-standard)" ]] || die "git working tree has untracked files"
}

version_exists_locally() {
  local tag_name="$1"
  git rev-parse --verify --quiet "refs/tags/$tag_name" >/dev/null 2>&1
}

current_package_version() {
  node -p "require('./package.json').version"
}

write_package_version() {
  local version="$1"
  node -e "
    const fs = require('fs');
    const path = './package.json';
    const pkg = JSON.parse(fs.readFileSync(path, 'utf8'));
    pkg.version = '$version';
    fs.writeFileSync(path, JSON.stringify(pkg, null, 2) + '\n');
  "
}

main() {
  (($# >= 1)) || {
    usage
    exit 1
  }

  case "${1:-}" in
    -h|--help|help)
      usage
      exit 0
      ;;
  esac

  local target_version="$1"
  shift
  local publish_to_npm="true"

  while (($#)); do
    case "$1" in
      --no-publish)
        publish_to_npm="false"
        shift
        ;;
      *)
        die "unknown option: $1"
        ;;
    esac
  done

  [[ "$target_version" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] || die "version must use semver like 0.1.4"

  git rev-parse --is-inside-work-tree >/dev/null 2>&1 || die "not inside a git repository"
  require_clean_worktree

  local current_version=""
  local tag_name="v$target_version"
  current_version="$(current_package_version)"

  [[ "$current_version" != "$target_version" ]] || die "package.json is already at version $target_version"
  version_exists_locally "$tag_name" && die "git tag already exists locally: $tag_name"

  write_package_version "$target_version"
  info "Updated package.json to $target_version"

  npm pack --dry-run >/dev/null
  info "Validated npm package with npm pack --dry-run"

  git add package.json
  git commit -m "chore: release $tag_name"
  git tag -a "$tag_name" -m "$tag_name"
  info "Created commit and tag $tag_name"

  git push origin main
  git push origin "$tag_name"
  info "Pushed main and $tag_name"

  if [[ "$publish_to_npm" == "true" ]]; then
    npm publish
    info "Published $target_version to npm"
  else
    info "Skipped npm publish"
  fi
}

main "$@"
