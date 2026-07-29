---
wo: WO-068-IJ
status: In progress
assigned: IJ
mr: ~
decision: D-013-IJ
depends_on:
  - docs/workorders/WO-067-IJ.md
related:
  - tools/wcl-v1-to-fight.py
  - tools/wcl-csv-to-fight.py
  - tools/wcl-to-fight.py
  - tools/fights/lucifron.lua
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

- **Outcome / on the branch** (dev tooling; PR opens once the estimator R&D session settles): three
  converters + a grader fix. **Primary: `wcl-v1-to-fight.py`** — the WCL **V1 API** (an `api_key` from a
  gitignored `.env`; no OAuth) pulls a whole fight in one call, reading the boss's **exact** health from
  per-event `hitPoints`/`maxHitPoints` and capturing the **adds** timeline. Fallbacks:
  `wcl-csv-to-fight.py` (no-credentials, target-filtered CSV) and `wcl-to-fight.py` (V2 OAuth). Grader fix:
  `estimator-replay.lua` grades **only what the client shows** (confidence ≥ `minConfidenceToShow`).
  Fixture: `tools/fights/lucifron.lua` (regenerated from exact API data).
- **First real fight → the finding (corrected; see `docs/reference/estimator-replay.md`):** the CSV pull
  implied a scary "confident 30-min adds-gate" (~1069% MAPE); the **exact API pull overturned it** — a
  fairly steady curve, bar correctly hidden ~5s, **65.7% MAPE**, reads ~+9s long (can't anticipate the mild
  acceleration). The add wasn't even killed first (cleave-all — a low-tier norm). Encounter-specific, **not
  a generic retune** → motivates the regime-aware overhaul **[D-013-IJ] / WO-069** (fable + ultracode);
  grading real fights is its proving ground.
- **Follow-up:** widen the V1 puller to a **curated corpus** (relevance window · performer spectrum) to
  feed the WO-069 design.

**Phase 1** 1. [x] wcl-v1-to-fight.py (V1, exact hitPoints, .env key) · [x] CSV + V2 fallbacks.
**Phase 2** 1. [x] first real fight (Lucifron) graded → finding corrected → D-013 / WO-069. PR pending.
