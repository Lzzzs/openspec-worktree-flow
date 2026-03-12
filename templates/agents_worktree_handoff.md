## OpenSpec Worktree Handoff

When this repository uses OpenSpec, treat proposal approval and implementation as separate phases.

- If an approved OpenSpec change exists and the user asks to implement, write code, start coding, continue implementation, or fix that change, resolve the worktree handoff before making code edits in the main checkout.
- Use the `owf` CLI to inspect the lifecycle state and handle the handoff.
- If the implementation worktree does not exist yet, explicitly ask whether to create it now unless the user already made that choice.
- Once the user confirms, create the implementation branch and sibling worktree, then do implementation work there instead of in the main checkout.
- Keep proposal editing in the main checkout. Move into the implementation worktree only when coding begins.
