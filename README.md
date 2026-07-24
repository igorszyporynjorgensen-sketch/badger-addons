---
title: Badger Addons
type: readme
depends_on: []
related:
  - CLAUDE.md
  - CONTRIBUTING.md
  - docs/architecture.md
---

# Badger Addons

A brand and monorepo home for lightweight **World of Warcraft Classic (TBC Anniversary)** UI addons —
unit frames and on-screen information, built the same disciplined way. The first addon is
**Badger Arena**.

- **Target client:** WoW Classic — The Burning Crusade Anniversary realms (`Interface: 2xxxx`).
- **Framework:** [Ace3](https://www.wowace.com/projects/ace3) (AceAddon · AceDB · AceConfig · AceEvent).
- **Monorepo:** [Nx](https://nx.dev) orchestrating the Lua toolchain (no JavaScript app).
- **Quality gate:** [StyLua](https://github.com/JohnnyMorganz/StyLua) · [Luacheck](https://github.com/lunarmodules/luacheck) · [Busted](https://lunarmodules.github.io/busted/) behind one `pnpm validate`.

## Layout

```
badger-addons/
├─ projects/
│  └─ badger-arena/        # the first addon (Nx project "badger-arena", folder "BadgerArena")
│     ├─ BadgerArena.toc   # manifest + load order
│     ├─ .pkgmeta          # embedded-library sources (Ace3 …) for the packager
│     ├─ src/              # Lua source; *_spec.lua colocated beside behaviour-bearing units
│     └─ Locales/
├─ tools/
│  ├─ wow-mock/            # shared Busted harness: a stand-in for the WoW client API
│  └─ build.sh             # packager wrapper -> installable build with libs
├─ docs/                   # the documentation-driven process (see CLAUDE.md)
└─ .claude/skills/         # project-local AI drivers (house-style · docs-process · badger-addons)
```

## Prerequisites

- **Node ≥ 20.9** (repo pins **22** via `.nvmrc`) and **pnpm ≥ 10** (pnpm-only).
- **Lua toolchain** — StyLua, plus Luacheck and Busted bound to **LuaJIT (Lua 5.1)** to match the WoW
  runtime (host Lua 5.5 is too new for these rocks):

  ```bash
  brew install stylua luarocks luajit
  luarocks --lua-version 5.1 --lua-dir="$(brew --prefix luajit)" install --local luacheck
  luarocks --lua-version 5.1 --lua-dir="$(brew --prefix luajit)" install --local busted
  # put the luarocks --local bin dir on PATH (zsh):
  echo 'export PATH="$HOME/.luarocks/bin:$PATH"' >> ~/.zshrc && exec zsh
  ```

## Everyday commands

```bash
pnpm install                        # installs Nx and wires the git hooks
pnpm validate                       # the gate: stylua --check · luacheck · busted (all projects)
pnpm test                           # Busted only
pnpm format                         # StyLua write

pnpm nx run badger-arena:build      # fetch libs + assemble projects/badger-arena/.release/BadgerArena
```

### Run it in WoW

1. `pnpm nx run badger-arena:build` (needs `curl`; pulls Ace3 via the BigWigs packager).
2. Copy `projects/badger-arena/.release/BadgerArena` into `…/World of Warcraft/_classic_/Interface/AddOns/`.
3. `/reload`, then `/badgerarena` (or `/bga`) to open the options panel.
4. Confirm the `.toc` `Interface` number against the live client: `/run print(select(4, GetBuildInfo()))`.

## How we work

Documentation-driven and propose-then-act — see [`CLAUDE.md`](CLAUDE.md),
[`CONTRIBUTING.md`](CONTRIBUTING.md), and [`docs/`](docs/). Work is planned as **work orders**, durable
choices are logged as **decisions**, and "done" means a green `pnpm validate`.

## License

[MIT](LICENSE) © 2026 Igor Szyporyn.
