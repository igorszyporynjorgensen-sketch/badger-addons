---
wo: WO-071-IJ
status: Accepted
assigned: IJ
mr: ~
decision: D-013-IJ
depends_on:
  - docs/workorders/WO-070-IJ.md
related:
  - tools/ttk-lab.py
  - tools/estimator-batch.lua
---

# WO-071-IJ — `ttk-lab`: live terminal dashboard for client-run learning sessions

- **Created:** 2026-07-29
- **Objective — from the human:** *"could I not also run it in my terminal and tell you when its done and
  output files were available — then add some awesome real time output dashboard in the terminal - I would
  love that."* Make the learning sessions fully **human-runnable**: one command that hunts and/or grades
  with a **live raid-meter-style terminal dashboard**, and ends by writing a machine-readable run summary
  the AI ingests later ("tell Claude it's done").
- **Design — `tools/ttk-lab.py` (stdlib only, no deps):**
  - `python3 tools/ttk-lab.py hunt <encounterID...> [--n N]` — pulls kills per encounter (reusing the
    WO-070 rankings logic + `wcl-v1-to-fight.py` per fight) **and grades each fight the moment it lands**.
  - `python3 tools/ttk-lab.py grade` — re-grades the existing corpus with the same live display. This is
    the loop for WO-069 estimator iterations: change the estimator, `grade`, watch the numbers move.
  - **Live dashboard (ANSI, in-place repaint):** per-encounter meter rows (progress, duration range, mean
    MAPE meter colored by severity, bias), a live aggregate footer (fights done, mean/median MAPE, bias,
    elapsed), spinner. Degrades to plain line output when stdout is not a TTY (CI-safe, AI-readable).
  - **Handoff contract:** on finish, writes `tools/fights/corpus/_run-summary.json` (inside the gitignored
    harvest zone) with per-fight rows + aggregates, and prints the path — the human tells the AI, the AI
    reads the summary + corpus and refreshes the web dashboard (`docs/reference/estimator-scoreboard.json`
    + the Estimator Lab artifact).
  - **`tools/estimator-batch.lua` gains a single-file mode** (arg ends in `.lua` → grade that one fight,
    print one tab-separated `RESULT` line) so the TUI can grade incrementally without loading the whole
    corpus per fight. Directory mode unchanged.
- **Constitution check:** dev tooling only; addon untouched; no `_G`; no version bump (D-011). Learning
  stays client-side (never git/CI); the WCL key stays in `.env`; the summary lives in the gitignored zone.
- **Acceptance:** `hunt` and `grade` both render the live dashboard in a real terminal and plain lines when
  piped; `_run-summary.json` written with per-fight + aggregate data; single-file batch mode returns the
  same numbers as directory mode for the same fight; gate green.

**Phase 1** 1. [ ] estimator-batch single-file mode. 2. [ ] ttk-lab.py (hunt · grade · TUI · summary). PR.
