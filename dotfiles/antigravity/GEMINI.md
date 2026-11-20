# Guidelines

- Don't run dev server commands (e.g., `bun run dev`) — assume it's already running.
- Don't run build commands unless specifically told to.
- Focus on checking commands like `pnpm check`, `bun run lint`, etc.

## Package Managers

- Use pnpm if the project already uses it, otherwise use bun.
- Never use npm or yarn.

## Tech Stack Preferences

When uncertain, prefer: Tailwind v4, TypeScript, pnpm, React, Convex, Clerk.

## Code Style

- Always strive for simple solutions. Simple means easy to read, not short.
- Name each step. If a return line has 2 or more operators (`&&`, `||`, `?:`,
  arithmetic, comparison), split it: one `const` per step, with a name that says
  what the value means. Then return.
  ```diff
  -  return runningSince !== undefined && now - runningSince < RUN_LEASE_MS
  +  if (runningSince === undefined) return false
  +  const heldFor = now - runningSince
  +  const expired = heldFor >= RUN_LEASE_MS
  +  return !expired
  ```
- Guard clauses first. Handle the empty or missing case and return early.
- YAGNI principles decide if a piece of code is needed or not.
- If a problem can be solved in a simpler way, propose it.

## Git

- Never commit changes unless the user explicitly asks you to commit them.
- Always use Conventional Commits format for the commit headline (e.g., `feat: ...`, `fix: ...`, `chore: ...`).

## General Preferences

- If asked to do too much work at once, stop and state that clearly.
- When asked to build an interactive HTML explanation, expose it with `tailscale serve` and send me the link.

## Worktrees

- When asked to make a worktree for anything, do it inside `.worktrees/<project-name>/<branch-name>` and give me the explicit `cd` command.
