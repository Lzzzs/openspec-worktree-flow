#!/usr/bin/env bash

set -euo pipefail

force="false"

while (($#)); do
  case "$1" in
    --force)
      force="true"
      shift
      ;;
    *)
      echo "Error: unknown option: $1" >&2
      echo "Usage: install_to_codex_home.sh [--force]" >&2
      exit 1
      ;;
  esac
done

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
skill_dir="$(cd "$script_dir/.." && pwd)"
codex_home="${CODEX_HOME:-$HOME/.codex}"
dest_root="$codex_home/skills"
dest_dir="$dest_root/openspec-worktree-flow"

mkdir -p "$dest_root"

if [[ -e "$dest_dir" ]]; then
  if [[ "$force" != "true" ]]; then
    echo "Error: destination already exists: $dest_dir" >&2
    echo "Re-run with --force to replace the installed skill." >&2
    exit 1
  fi

  rm -rf "$dest_dir"
fi

cp -R "$skill_dir" "$dest_dir"

echo "Installed skill to:"
echo "  $dest_dir"
