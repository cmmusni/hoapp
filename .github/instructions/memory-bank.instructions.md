---
description: "Mandatory memory-bank read protocol. Every agent reads /memories/repo/memory-bank/ once at the start of a fresh session before doing any work."
applyTo: "**"
---

# Memory Bank Protocol

This repo uses a structured memory bank stored under `/memories/repo/memory-bank/`. It is the source of truth for project scope, architecture, conventions, and current state.

## Files

Read in this order:

1. `/memories/repo/memory-bank/projectbrief.md` — what HOApp is, scope, non-goals
2. `/memories/repo/memory-bank/productContext.md` — users, problems, UX principles
3. `/memories/repo/memory-bank/systemPatterns.md` — architecture, layering, key patterns
4. `/memories/repo/memory-bank/techContext.md` — stack, commands, constraints
5. `/memories/repo/memory-bank/activeContext.md` — current focus, recent changes, open bugs
6. `/memories/repo/memory-bank/progress.md` — what works, what's broken, what's next

## When to read

- **At the start of a fresh session**: read ALL six files in a single parallel batch BEFORE any other work.
- **Within the same session**: do NOT re-read. Trust the loaded context.
- **After context reset** (you have no recollection of the contents): read again, once.

## When to update

After completing meaningful work, update the affected file(s):

| Trigger | File to update |
|---|---|
| Discovered/fixed a bug, changed current focus, applied new migration | `activeContext.md` |
| Feature shipped, status changed, new known-broken item | `progress.md` |
| New architectural pattern, layering change | `systemPatterns.md` |
| New tooling, command, env var, version bump | `techContext.md` |
| Scope or non-goal changed | `projectbrief.md` |
| New user role, problem domain, UX principle | `productContext.md` |

Use the `memory` tool with `str_replace` or `insert` for surgical edits. Keep entries concise (bullets > prose). Do NOT rewrite files wholesale.

## Rules

- Memory bank reads do not count as "work" — they are the prerequisite.
- If a memory file is missing, create it via the `memory` tool with the appropriate template content.
- If memory contradicts code, code wins — fix the memory.
- Never store secrets, tokens, or PII in memory files.
