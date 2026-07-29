---
wo: WO-070-IJ
status: Accepted
assigned: IJ
mr: ~
decision: D-013-IJ
depends_on:
  - docs/workorders/WO-068-IJ.md
related:
  - tools/wcl-corpus.py
  - tools/estimator-batch.lua
---

# WO-070-IJ — Corpus harvest + batch-grade (the "learning how to learn" data engine)

- **Created:** 2026-07-29
- **Objective — from the human:** make learning sessions optimal — *"place the logs you require in a folder
  that will be deleted/emptied often (so does not go to git); after harvesting sufficient data do the actual
  learning; have the simulated run created as a log of its own (on my machine or a git pipeline); study the
  outcome of ~200 simulated-run comparisons (speed up execution as much as possible)."*
- **Architecture:**
  1. **Ephemeral harvest zone** — `tools/fights/corpus/` is **gitignored** (raw pulled curves never bloat
     git; empty it freely between sessions). Committed fixtures (e.g. `tools/fights/lucifron.lua`) stay the
     curated few; the corpus is transient bulk.
  2. **Harvest** — `tools/wcl-corpus.py <encounterID> [--n N]`: WCL **V1 rankings** give ~76 unique kills
     per call across the **performer spectrum** (fast→slow durations, specs, item levels); it dedupes to
     `(reportID, fightID)` and pulls each fight's exact curve by delegating to `wcl-v1-to-fight.py`
     (reuse, not duplicate), writing fixtures into the harvest zone. Curation (relevance window /
     `classicSeasonID`, spectrum spread) per D-013.
  3. **Batch-grade** — `tools/estimator-batch.lua [dir]`: replays every fixture through the estimator and
     prints a **per-fight table + aggregate** (mean/median/p90 MAPE · bias · within-15% · confidently-shown
     · distribution). This is the "study 200 runs" artifact — pure Lua, fast; runnable locally or in CI.
- **Not learning yet.** This is the *data engine* for the WO-069 overhaul, still the "learning how to learn"
  phase — harvest + measure the estimator across many real kills; the actual regime redesign is D-013/WO-069
  (fable + ultracode), which consumes this corpus.
- **Constitution check:** dev tooling; addon untouched; no `_G`; no version bump (D-011). The harvest zone is
  gitignored; the WCL key stays in `.env`. Reuses the tested `wcl-v1-to-fight.py` rather than duplicating.
- **Acceptance:** one command harvests N real kills of an encounterID into the (gitignored) corpus; one
  command batch-grades them into an aggregate summary; demonstrated on Lucifron across the spectrum.

**Phase 1** 1. [ ] gitignore the harvest zone · `wcl-corpus.py` (rankings → fixtures).
**Phase 2** 1. [ ] `estimator-batch.lua` (aggregate grade) · demonstrate on a real Lucifron corpus. PR.
