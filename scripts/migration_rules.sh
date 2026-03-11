#!/usr/bin/env bash

# Lightweight context that should evolve independently inside each worktree.
COPY_PATHS=(
  "openspec"
)

# Heavy local-only directories that are expensive to duplicate.
SYMLINK_PATHS=(
  "node_modules"
)
