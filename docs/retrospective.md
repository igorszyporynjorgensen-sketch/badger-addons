---
title: Retrospective
type: retrospective
depends_on: []
related:
  - docs/milestones.md
  - docs/decisions.md
---

# Retrospective

What we learned building **Badger Addons** — the things worth remembering that aren't a single
decision (those live in [decisions.md](decisions.md)) or a milestone summary
([milestones.md](milestones.md)). Honest notes: what went well, what bit us, what we'd do differently.
Append-only, newest on top; one entry per milestone or per notable lesson.

---

## 2026-07-24 — Foundation (post-M-001)

**Went well.**
- The web-stack scaffold's *essence* — the documentation-driven process, one `validate` gate, house
  style, project-local Claude drivers — transferred cleanly to a Lua/WoW addon by swapping the tools
  (StyLua/Luacheck/Busted for Prettier/ESLint/Vitest) and keeping the discipline.
- Loading each source file through the real `(addonName, ns)` vararg contract in the Busted harness
  means specs exercise the *shipped* file, not a copy.

**What bit us / surprises.**
- The host Lua is **5.5**, too new for the Luacheck/Busted rocks (Luacheck failed to load its
  `standards` module). Fix: bind both to **LuaJIT (5.1)** via a separate luarocks tree — which also
  matches the WoW runtime, so it's an upgrade, not just a workaround.
- The `~/.luarocks/bin` dir must be on `PATH` for Nx to find `luacheck`/`busted` — documented in the
  README prerequisites.

**Do differently next time.**
- Consider committing a small `hererocks`/pinned toolchain bootstrap so a fresh machine gets an
  identical 5.1 tool environment without the manual luarocks dance.
