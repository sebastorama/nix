# Global instructions

- Don't run dev server commands (e.g., `bun run dev`) — assume it's already running.
- Don't run build commands unless specifically told to.
- Focus on checking commands like `pnpm check`, `bun run lint`, etc.

## Package Managers
- Use pnpm if the project already uses it, otherwise use bun.
- Never use npm or yarn.

## Tech Stack Preferences

When uncertain, prefer: Tailwind v4, TypeScript, pnpm, React, Convex, Clerk.

## Code Style
- Always strive for concise, simple solutions.
- YAGNI principles decide if a piece of code is needed or not.
- If a problem can be solved in a simpler way, propose it.

## Git
- Never commit changes unless the user explicitly asks you to commit them.
- Always use Conventional Commits format for the commit headline (e.g., `feat: ...`, `fix: ...`, `chore: ...`).

## General preferences
- If asked to do too much work at once, stop and state that clearly.
- If computer use is helpful for completing or verifying work, shell out to gpt-5.6-sol with Codex for it.

## Worktrees

- when asked to make a worktree for anything, do it inside .worktrees/<project-name>/<branch-name> and give me the
explicit cd command
