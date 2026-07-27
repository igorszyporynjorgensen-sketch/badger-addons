---
title: Badger Addons
type: readme
depends_on: []
related:
  - CLAUDE.md
  - CONTRIBUTING.md
  - docs/architecture.md
---

<div align="center">

# 🦡 Badger Addons

### Lightweight **World of Warcraft Classic** UI addons — unit frames & on-screen info, built the disciplined way. **Lua** in the client, **Nx + pnpm** holding the tooling together.

<br/>

[![Lua](https://img.shields.io/badge/Lua-5.1-2C2D72?style=for-the-badge&logo=lua&logoColor=white)](https://www.lua.org)
[![WoW Classic](https://img.shields.io/badge/WoW_Classic-Era_%26_TBC-F8B700?style=for-the-badge&logo=battledotnet&logoColor=white)](https://worldofwarcraft.blizzard.com/wowclassic)
[![Ace3](https://img.shields.io/badge/Ace3-framework-5A3E85?style=for-the-badge)](https://www.wowace.com/projects/ace3)
[![Nx](https://img.shields.io/badge/Nx-23.1-143055?style=for-the-badge&logo=nx&logoColor=white)](https://nx.dev)
[![pnpm](https://img.shields.io/badge/pnpm-10-F69220?style=for-the-badge&logo=pnpm&logoColor=white)](https://pnpm.io)

[![StyLua](https://img.shields.io/badge/StyLua-format-3A3A3A?style=for-the-badge)](https://github.com/JohnnyMorganz/StyLua)
[![Luacheck](https://img.shields.io/badge/Luacheck-lint-00A98F?style=for-the-badge)](https://github.com/lunarmodules/luacheck)
[![Busted](https://img.shields.io/badge/Busted-tested-8A2BE2?style=for-the-badge)](https://lunarmodules.github.io/busted/)

<br/>

[Overview](#-overview) · [The Addons](#-the-addons) · [Tech Stack](#-tech-stack) · [Install](#-prerequisites) · [Commands](#-everyday-commands) · [Layout](#-project-layout) · [Testing](#-testing) · [How we work](#-how-we-work)

</div>

---

## ✨ Overview

**Badger Addons** is an [Nx](https://nx.dev) + [pnpm](https://pnpm.io) monorepo of small, focused
**WoW Classic** UI addons under the *Badger* brand. Each addon is written in **Lua** for the WoW client's
Lua 5.1 sandbox and targets **its own client flavor**:

- **Badger TTK** → **Classic Era / Hardcore** (Vanilla 1.15.x)
- **Badger Arena** → **TBC Anniversary** (2.5.x)

There is **no JavaScript application** here — Nx and pnpm exist only to orchestrate the Lua toolchain
([StyLua](https://github.com/JohnnyMorganz/StyLua) · [Luacheck](https://github.com/lunarmodules/luacheck) ·
[Busted](https://lunarmodules.github.io/busted/)) behind one `pnpm validate` gate. Every addon is built on
[Ace3](https://www.wowace.com/projects/ace3) and shares one branded config-window library,
**BadgerConfigUI-1.0**. Testable logic runs off-client against a shared WoW-API mock, so the timing math and
UI assembly are unit-tested without a running game.

> [!NOTE]
> This repo follows a **propose-then-act** working agreement — nothing outside `docs/` changes without human
> acceptance first, every code change lands via a branch + PR (merging is human-only), and jobs are run as
> **work orders**. See [`CLAUDE.md`](CLAUDE.md) and [`docs/workorders.md`](docs/workorders.md).

---

## 🎯 The Addons

### 🗡 Badger TTK &nbsp;·&nbsp; _Time To Kill_ &nbsp;·&nbsp; the flagship

A right-anchored **time-until-the-target-dies** bar, plus **utility cooldown-timing bars** that light up at
the exact moment to fire each cooldown so its buff lands on the kill (**waiting → fire now → used**). A
live-but-smart TTK estimator (health-loss EWMA + execute correction + a recorded-history prior), a curated
per-class cooldown table, config-driven per-encounter gating, an open user-authored skin system, and a
built-in animated **Preview**.

| | |
| --- | --- |
| **Flavor** | Classic Era / Hardcore — Vanilla **1.15.x** (`Interface: 11509`) |
| **Open it** | `/bttk` or `/badgerttk` |
| **Status** | pre-1.0 (`0.9.x`) — closing in on release |
| **Project** | [`projects/badger-ttk/`](projects/badger-ttk/) |

### ⚔️ Badger Arena &nbsp;·&nbsp; arena unit-frames & info

Arena unit-frames and on-screen information for rated play.

| | |
| --- | --- |
| **Flavor** | TBC Anniversary — **2.5.x** (`Interface: 20504`) |
| **Open it** | `/ba` or `/badgerarena` |
| **Status** | early (`0.1.x`) |
| **Project** | [`projects/badger-arena/`](projects/badger-arena/) |

---

## 🧰 Tech Stack

| Layer                | Technology                                                                              | Notes                                                              |
| -------------------- | --------------------------------------------------------------------------------------- | ------------------------------------------------------------------ |
| **Monorepo**         | [Nx](https://nx.dev) · [pnpm](https://pnpm.io/workspaces)                                | 23.1 · 10 — orchestrates the Lua tooling; no JS app                |
| **Language**         | [Lua](https://www.lua.org) 5.1                                                           | The WoW client's sandbox; LuaJIT for the toolchain                 |
| **Framework**        | [Ace3](https://www.wowace.com/projects/ace3)                                            | AceAddon · AceDB · AceConfig · AceEvent · AceGUI · AceLocale       |
| **Config window**    | `BadgerConfigUI-1.0` (in-repo shared lib)                                                | One branded AceConfigDialog tree + global header, per addon        |
| **Media**            | [LibSharedMedia-3.0](https://www.wowace.com/projects/libsharedmedia-3-0)                 | Textures / fonts / borders for skins                               |
| **Format**           | [StyLua](https://github.com/JohnnyMorganz/StyLua)                                        | `stylua --check` in the gate                                       |
| **Lint**             | [Luacheck](https://github.com/lunarmodules/luacheck)                                     | `std = lua51`; **no `_G` leaks** — named exports on `ns` only      |
| **Tests**            | [Busted](https://lunarmodules.github.io/busted/) + `tools/wow-mock`                      | Colocated `*_spec.lua`; off-client WoW-API stand-in                |
| **Packaging**        | [BigWigs packager](https://github.com/BigWigsMods/packager)                              | Fetches Ace3 externals; assembles the installable `.release`       |
| **Targets**          | TBC Anniversary **2.5.x** · Classic Era / Hardcore **1.15.x**                            | Per-project flavor (scoped `.luacheckrc` overlays keep it honest)  |

---

## 📋 Prerequisites

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

---

## 🚀 Everyday commands

```bash
pnpm install                     # installs Nx and wires the git hooks
pnpm validate                    # the gate: stylua --check · luacheck · busted (all projects)
pnpm test                        # Busted only
pnpm format                      # StyLua write

pnpm nx run badger-ttk:build     # fetch libs + assemble projects/badger-ttk/.release/BadgerTTK
pnpm nx run badger-arena:build   # same for badger-arena
```

### Run it in WoW

1. `pnpm nx run badger-ttk:build` (needs `curl`; pulls Ace3 via the BigWigs packager).
2. Copy `projects/badger-ttk/.release/BadgerTTK` into `…/World of Warcraft/_classic_era_/Interface/AddOns/`.
3. `/reload`, then `/bttk` (or `/badgerttk`) to open the options.
4. Confirm the `.toc` `Interface` number against the live client: `/run print((select(4, GetBuildInfo())))`.

---

## 🗂 Project Layout

```
badger-addons/
├─ projects/
│  ├─ badger-ttk/            # 🗡 the flagship — Time To Kill (Classic Era / Hardcore)
│  │  ├─ BadgerTTK.toc       #    manifest + load order
│  │  ├─ .pkgmeta            #    embedded-library sources (Ace3 …) for the packager
│  │  ├─ src/                #    Lua source; *_spec.lua colocated beside behaviour-bearing units
│  │  └─ Locales/
│  └─ badger-arena/          # ⚔️ arena unit-frames (TBC Anniversary)
├─ libs/
│  └─ BadgerConfigUI-1.0/    # shared, SHIPPED LibStub config-UI library (embedded into each addon's Libs/)
├─ tools/
│  ├─ wow-mock/              # shared Busted harness: a stand-in for the WoW client API
│  └─ build.sh               # packager wrapper -> installable build with libs
├─ docs/                     # the documentation-driven process (work orders · decisions · architecture)
└─ .claude/skills/           # project-local AI drivers (house-style · docs-process)
```

---

## 🧪 Testing

Behaviour-bearing units carry a colocated **`*_spec.lua`** and run under [Busted](https://lunarmodules.github.io/busted/)
against **`tools/wow-mock`** — a stand-in for the WoW client API — so the timing math, layout geometry, and
options-tree assembly are verified **off-client**. The thin frame/event edge that can't be unit-tested is
proven with an in-game `/reload`. `pnpm validate` runs StyLua, Luacheck, and Busted across every project.

---

## 🤝 How we work

Documentation-driven and **propose-then-act** — see [`CLAUDE.md`](CLAUDE.md),
[`CONTRIBUTING.md`](CONTRIBUTING.md), and [`docs/`](docs/). Work is planned as **work orders**
([`docs/workorders.md`](docs/workorders.md)), durable choices are logged as **decisions**
([`docs/decisions.md`](docs/decisions.md)), and "done" means a green `pnpm validate` — confirmed in-game
for anything that changes what you see on screen.

---

## 📚 Documentation

- [`CLAUDE.md`](CLAUDE.md) — the working agreement for AI agents in this repo.
- [`docs/engineering-principles.md`](docs/engineering-principles.md) — the house style & constitution.
- [`docs/architecture.md`](docs/architecture.md) — how the pieces fit.
- [`docs/workorders.md`](docs/workorders.md) · [`docs/decisions.md`](docs/decisions.md) — the plan and the *why*.

---

## 📜 License

[MIT](LICENSE) © 2026 Igor Szyporyn.
