---
wo: WO-076-IJ
status: Proposed
assigned: IJ
mr:
decision: D-021-IJ
depends_on:
  - docs/workorders/WO-075-IJ.md
related:
  - docs/reference/pr97-verification-2026-08-01.md
  - docs/reference/estimator-replay.md
  - tools/estimator-batch.lua
  - tools/estimator-perbin.lua
  - tools/estimator-replay.lua
  - tools/learn-regime.py
  - projects/badger-ttk/src/live/driver.lua
  - projects/badger-ttk/src/raids/regimes_spec.lua
---

# WO-076-IJ — Make the lab model the client (the sticky show gate)

- **Created:** 2026-08-01
- **Anchor:** the PR #97 verification ([docs/reference/pr97-verification-2026-08-01.md](../reference/pr97-verification-2026-08-01.md)),
  confirmed finding: **the lab does not model the client.**
- **Objective:** teach the grading/learning instruments the client's **sticky** show gate, so learned
  confidence caps are derived under the rule the addon actually enforces — then re-learn, re-grade, and
  show the human the diff against the shipped caps.
- **Scope discipline:** **instrument-only.** No file under `projects/badger-ttk/src/` changes behaviour,
  with the single exception of a *spec* correction (§4). The shipped addon cannot regress, because the
  shipped addon is not touched.

## The defect

`driver.lua:68` gates on confidence **only before the bar's first appearance**:

```lua
if not wasShown and not settings.showAnyTarget then
    ...
    if minConf and minConf > 0 and context.conf and context.conf < minConf then
        return false
    end
end
```

Once the bar latches in **any** health bin, every later `confCap` — including a hard `0.0` — is
unreachable. The comment at `driver.lua:75-77` says so explicitly and deliberately ("Sticky like minTTK —
once shown, a mid-fight confidence dip never hides the bars").

The instruments assume the opposite. All three graders apply the gate **per tick, independently**:

- `tools/estimator-batch.lua:110` — `if conf and conf >= MINCONF then`
- `tools/estimator-replay.lua:62` — same
- `tools/estimator-perbin.lua` — same shape

And `tools/learn-regime.py:154-163` derives each bin's cap independently, then reports at `:207-208`
"`N/BINS` bins would HIDE the bar" — a claim that is only true for bins reached **before first show**.

**Consequence.** Caps were *learned* and *graded* under a rule the client does not implement. Per the PR #97
verification: Viscidus's shipped profile is bit-identical to shipping no regime at all; Skeram and Sulfuron
are ~nullified. No player is shown a *wrong* number by this — the bar simply stays up where the lab believed
it went quiet.

### Onyxia is the sharpest case (measured 2026-08-01)

Onyxia ships `confCap = { [20] = 0.0, [11] = 0.0, [10] = 0.91, [8] = 0.89, [7] = 0.93 }`.

- `[20] = 0.0` (95–100% health) **works** — the bar has not latched yet, so the gate is live.
- `[11] = 0.0` (50–55% health — **the air phase**) is **unreachable**. By 50% health the bar has been up
  since bin ~19.

A per-bin run over all 200 corpus fixtures (`estimator-perbin.lua 151084`) shows bin 11 is the fight's
**worst-tracking bin**: median relative error **45.9%**, median absolute **59.0s**, on 22,036 samples — one
of the most-sampled bins, because the fight sits in the air phase. The learner drew the right conclusion and
asked for silence exactly there; the client cannot honour it.

A 20-kill grade the same day (`ttk-lab.py hunt 151084 --n 20`) returned mean MAPE **45.9%**, median 43.9%,
bias **+22.8s**, **shown 86.9%** — and most of that hidden ~13% is the air phase the client will in fact
show. So the headline number is optimistic for Onyxia specifically, and the in-game bar reads ~59s long
through the air phase. (Train/holdout was 11/9 of those 20, grading 45.1% vs 47.0% — the profile
generalizes; this is a gate defect, not overfitting.)

## Scope

Branch `fix/WO-076-IJ-lab-models-client` off this Accepted WO. One PR. `pnpm validate --skip-nx-cache`
green; human merges.

### 1. Teach the graders the sticky gate

In `estimator-batch.lua`, `estimator-perbin.lua` and `estimator-replay.lua`, replace the per-tick
independent `conf >= MINCONF` test with a **latch**: once a tick passes the gate, every subsequent tick in
that fight is shown regardless of confidence. Mirror `driver.lua`'s ordering exactly (the `minTTK`
qualification is part of the same `not wasShown` block — model both, or document why `minTTK` is out of
scope for a health-curve replay).

The three tools share this logic by copy-paste today; `estimator-batch.lua:9` already flags a shared
`tools/estimator-grade.lua` as a future refactor. Extracting it here is **in scope and preferred** — it is
the difference between fixing this once and fixing it three times.

### 2. Fix the learner's independent-hide assumption

`learn-regime.py:154-163` may keep deriving a per-bin *measurement*, but the emitted profile and the
printed summary must account for the latch: a `0.0` in a bin the bar reaches after first show is **dead
data**. Decide and implement one of:

- **(a)** emit caps only for bins reachable pre-show, and report the rest as "measurably wrong but
  unreachable — needs a mechanism other than confidence"; or
- **(b)** emit them but mark them inert, so `assemble-regimes.py` and the shipped table stay honest.

Whichever is chosen, `:207-208`'s "`N/BINS` bins would HIDE the bar" must stop overstating. **(a) is the
recommendation** — dead data in a shipped table is what caused this WO.

This will surface the real question, which this WO **records but does not solve**: *the air phase needs a
non-confidence mechanism* (the bar is already up; hiding it mid-fight would need a deliberate un-show, and
D-020 removed the `freeze` tier). Flag it for a follow-up decision rather than inventing one here.

### 3. Pass `damageable` honestly

All three graders hard-code `est:sample(s.t, s.h, true)` (`estimator-batch.lua:105`,
`estimator-perbin.lua:82`, `estimator-replay.lua:48`). Pass `damageable = not dead` from the fight curve
instead. The estimator has supported the flag since `estimator.lua:128`; only `estimator-sim.lua:203` ever
exercises it.

### 4. Fix the `regimes_spec` "empty profile" test

`projects/badger-ttk/src/raids/regimes_spec.lua:53-59` fails a profile carrying only `kills`. **[D-019-IJ]
(b) already decided a kills-only profile is legitimate** — the spec is wrong, not the generator. This is
the one `src/` change, and it is test-only.

### 5. Re-learn, re-grade, present the diff

Re-run the learners and graders across the corpus and **present the human a diff of the newly-derived caps
against `src/raids/regimes.lua` as shipped** — per boss, with the MAPE / `shown%` delta.

**Do not ship a caps change in this PR.** Instruments land first; whether the shipped table changes is a
separate, human-gated call once the honest numbers exist (D-011 principle — and per [D-021-IJ], a re-derived
number is not by itself a licence to edit shared data).

## Out of scope

- **Finding 5 — Thekal `resetOnRise` / the damageable hold.** Parked by **[D-021-IJ]**: neither confirmed
  nor refuted, untestable without a real ZG kill, and the suspect code sits on every boss's path where a
  blind change risks the `regime == nil` byte-identity guarantee. §3 of this WO touches `damageable` in the
  **graders only** — it must not alter estimator behaviour. If the re-grade happens to dissolve finding 5,
  record that; do not act on it here.
- **Finding 7** — never received an adversarial pass. Not actionable.
- **Any version bump.** Instruments are not shipped code (D-011).
- **The Onyxia air-phase mechanism** — recorded in §2, deferred to its own decision.

## Constitution check

- **Instrument-only**, so the "never regress the addon" principle holds by construction; the lone `src/`
  edit is a spec that D-019(b) already ruled wrong.
- **Learning stays client-side, never CI** — unchanged.
- **No version bump** (D-011).
- **Testability:** §1 and §3 are covered by the existing corpus regression guard — every non-regime boss row
  must stay byte-identical; profiled rows are *expected* to move, and that movement is the deliverable.

## Acceptance criteria

1. The three graders latch the show gate; a fight whose bar shows once is graded as shown thereafter.
2. Shared grading logic extracted (or a written reason it was not).
3. `learn-regime.py` no longer claims unreachable bins hide the bar.
4. `damageable` is passed from the curve, not hard-coded.
5. `regimes_spec` accepts a kills-only profile.
6. The re-learned-vs-shipped caps diff is presented to the human; **no caps change ships in this PR**.
7. `pnpm validate --skip-nx-cache` green (`PATH="$HOME/.luarocks/bin:$PATH"`); non-regime corpus rows
   byte-identical.
8. `CHANGELOG [Unreleased]` notes the instrument fix.

## Open questions

- **[NEEDS CLARIFICATION]** §2 — option **(a)** (drop unreachable caps) or **(b)** (emit-but-mark-inert)?
  Recommendation: **(a)**.
- **[NEEDS CLARIFICATION]** §1 — should the replay graders also model the `minTTK` qualification, or is
  confidence-only the right fidelity for a health-curve replay?

*Both must be resolved before this WO moves to `Accepted`.*
