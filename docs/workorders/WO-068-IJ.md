---
wo: WO-068-IJ
status: Accepted
assigned: IJ
mr: ~
decision: ~
depends_on:
  - docs/workorders/WO-067-IJ.md
related:
  - tools/wcl-to-fight.py
---

# WO-068-IJ — Warcraft Logs → fight-file converter (piece 2)

- **Created / Updated:** 2026-07-29
- **Objective — from the human:** turn a real Warcraft Logs fight (they linked an MC Lucifron kill) into a
  fight file the replay grader (WO-067) can score. Direct page fetch is 403'd (Cloudflare) — the data is
  behind the WCL v2 API, so this is the external converter D-012/WO-067 anticipated.
- **Approach:** `tools/wcl-to-fight.py` (stdlib only — `urllib`, so no pip): OAuth client-credentials →
  GraphQL. Resolve the fight window + boss actor (name-match the encounter), page the boss's damage-taken
  events, reconstruct the **health fraction curve** (prefer per-event `hitPoints`; else `1 −
  cumulativeDamage/total`), resample to 0.15s, and write a `tools/fights/<name>.lua` fight file. The user
  runs it locally with their own API-client credentials (kept off the repo).
- **Setup the human does once (free):** create a Warcraft Logs **API v2 client** at
  `warcraftlogs.com/api/clients` → a client id + secret. Then:
  `python3 tools/wcl-to-fight.py <id> <secret> DkGZwX9NgvAKJymr 41`
- **Acceptance:** produces a fight file whose curve looks sane (monotone 1→0), the replay grader scores it,
  and we read the real Lucifron lessons. First run is a debug pass (can't verify live from here).
- **Behavior delta:** none (in-game) — a dev/companion converter, runs outside the addon.
- **Constitution check:** Principles OK — dev tooling; no shipped-code/`_G` change; no version bump (D-011).
  Credentials are the user's and never committed.

**Phase 1** 1. [ ] wcl-to-fight.py.
**Phase 2** 1. [ ] first real fight through it + the grader (iterate on WCL field specifics as needed). PR.
