#!/usr/bin/env python3
"""
learn-regime.py — learn an encounter's REGIME PROFILE from harvested fight curves (WO-075 / D-014).

Where a RHYTHM profile (learn-rhythm.py) says "what the fight does next", a REGIME profile says
"where the fight is UNREADABLE" — the structural facts a health curve alone cannot convey. The
estimator consumes it as an injected dependency (opts.regime) through nil-guarded seams.

THE CORE METHOD — confCap from the estimator's OWN MEASURED ERROR.
For each health bin we replay the real, shipped estimator (rhythm injected, no regime) over the training
kills and measure how wrong the readout actually is there — `tools/estimator-perbin.lua`. Where the bar is
measurably right it stays confident; where it is measurably wrong its confidence is capped so the client
hides it (minConfidenceToShow = 0.5) instead of showing a confident-wrong countdown.

Why measured error and not a statistical proxy: the obvious proxy — the dispersion (CV) of remaining time
per bin — explodes as the fight ends purely because its denominator vanishes, so it would silence the
ENDGAME, the stretch the readout gets most right (measured: ~3s error with 10s to live). Measuring the
estimator itself has no such artifact, and it is the same quantity the acceptance criterion is stated in.
A bin counts as readable if its median relative error is small OR its median absolute error is small (a
few seconds late in a fight is useful even when it is a large fraction of what remains).

Also detects, and emits only when clearly present:
  * freeze bands  — health genuinely FLAT (a stall) in a consistent, tight band across most kills.
  * resetOnRise   — most kills show a large one-sample health RISE (a phase reset / a fresh pool).

  python3 tools/learn-regime.py <encounterID> [--bins 20] [--corpus DIR] [--split-even]

Writes tools/candidates/regime-<enc>.lua and prints the learned regime as ASCII. Stdlib only (it shells
out to luajit for the replay). Regenerate through the lab; never hand-edit the emitted file.
"""

import re
import sys
import glob
import shutil
import subprocess
import statistics

enc = sys.argv[1] if len(sys.argv) > 1 else sys.exit("usage: learn-regime.py <encounterID> [--bins N]")
BINS = int(sys.argv[sys.argv.index("--bins") + 1]) if "--bins" in sys.argv else 20
corpus = sys.argv[sys.argv.index("--corpus") + 1] if "--corpus" in sys.argv else "tools/fights/corpus"
split_even = "--split-even" in sys.argv

# Readability thresholds (what "the bar is useful here" means), in BOTH error currencies — because each one
# alone misjudges an end of the fight. The relative mapping is anchored so the cap crosses the client's show
# threshold (minConfidenceToShow = 0.5) exactly when the median error reaches 50%: the bar hides where it is
# typically wrong by more than half. The absolute rules cover what a ratio cannot: a few seconds off is
# useful even when it is a big fraction of what remains (the endgame), while a countdown tens of seconds off
# is unusable no matter how long the fight is (the pull, and a long unreadable phase).
REL_OK, REL_BAD = 0.30, 0.70  # median relative error: <=30% is useful, >=70% is noise
ABS_OK, ABS_BAD = 5.0, 45.0  # median absolute error: <=5s is always useful, >=45s is never usable
# Curve-shape detection.
FLAT_EPS = 0.01  # health span that still counts as "not moving" within a stall run
STALL_MIN_SEC = 3.0  # a stall must last at least this long
BAND_MAX_WIDTH = 0.35  # a learned freeze band wider than this is not a real phase — don't emit it
RISE_MIN = 0.25  # a one-sample health rise this large is a phase-reset candidate

files = sorted(glob.glob(f"{corpus}/{enc}-*.lua"))
if not files:
    sys.exit(f"no fixtures for encounter {enc} in {corpus}")
if split_even:
    total = len(files)
    files = files[0::2]
    print(f"train/test split: learning from {len(files)} of {total} (even-indexed); odd half held out")


# A categorical fact supplied by the operator (it is domain knowledge, not a statistic); it is active while
# measuring so the derived caps match the shipping configuration.
suppress_flush = "--suppress-flush" in sys.argv
# ── 1. curve shape: phase resets (and stall diagnostics) — determined BEFORE measuring ──────────────
stalls, rises, kills = [], 0, 0
for f in files:
    pts = [(float(a), float(b)) for a, b in re.findall(r"t = ([\d.]+), h = ([\d.]+)", open(f).read())]
    if len(pts) < 4:
        continue
    kills += 1
    # The DOMINANT stall of this kill: its single longest genuinely-flat mid-fight stretch. Counting every
    # flat run would just count the normal chunky-health plateaus between hits (~14 per kill) and "detect"
    # a phase that isn't there; a fight either HAS a stall phase or it doesn't.
    best = None
    i = 0
    while i < len(pts):
        j = i
        while j + 1 < len(pts) and abs(pts[j + 1][1] - pts[i][1]) < FLAT_EPS:
            j += 1  # extend a run of genuinely FLAT health
        run = pts[j][0] - pts[i][0]
        if j > i and run >= STALL_MIN_SEC and 0.05 < pts[i][1] < 0.98:
            if best is None or run > best[1]:
                best = (pts[i][1], run)
        i = j + 1 if j > i else i + 1
    if best:
        stalls.append(best)
    if any(pts[m + 1][1] - pts[m][1] >= RISE_MIN for m in range(len(pts) - 1)):
        rises += 1

if kills == 0:
    sys.exit("no usable curves")

freeze = None
mid_fight = stalls  # one dominant mid-fight stall per kill (see above)
if len(mid_fight) >= max(4, 0.5 * kills):  # at least half the kills have a real stall phase

    def q(a, p):
        return a[max(0, min(len(a) - 1, int(p * len(a))))]

    hs = sorted(h for h, _ in mid_fight)
    lo_b, hi_b = round(q(hs, 0.10), 2), round(q(hs, 0.90), 2)
    if 0.02 <= hi_b - lo_b <= BAND_MAX_WIDTH:  # a tight, real band — not "the whole fight"
        dur = statistics.median(d for _, d in mid_fight)
        freeze = (lo_b, hi_b, round(min(max(2.0, dur * 0.5), 6.0), 1))

reset_on_rise = round(RISE_MIN, 2) if rises >= 0.5 * kills else None


# NOTE — the `freeze` tier was REMOVED from the estimator in PR3 (D-020): across the whole roster no freeze
# band improved a grade and freezing alone made Viscidus worse, and it duplicated the driver's first-class
# `damageable = false`. The stall DETECTION below is kept as a printed diagnostic only (knowing a boss stalls
# at h≈0.92 in 29/30 kills is real knowledge for the future CLEU tier) and is never emitted into a profile.

# ── 2. per-bin measured error, from the real estimator RUNNING THE FACTS IT WILL SHIP WITH ──────────
luajit = shutil.which("luajit") or shutil.which("lua")
if not luajit:
    sys.exit("luajit not found (needed to replay the estimator)")
# The caps are DERIVED, so they must be measured against an estimator already carrying this profile's OTHER
# fields — the ones the client will run with. Measured without them the error is inflated (Buru ~3x without
# suppressFlush, Thekal ~1.5x without resetOnRise) and the caps would silence readouts that are in fact fine.
context = []
if suppress_flush:
    context.append("suppressFlush = true")
if reset_on_rise:
    context.append(f"resetOnRise = {reset_on_rise}")
if context:
    print(f"  measuring with the shipping facts active: {{{', '.join(context)}}}")


def run_perbin(extra_caps=None):
    """Replay the corpus per health bin. Returns {bin: (n, medianRel, medianAbs, preShow)}.

    `extra_caps` injects a candidate confCap so REACHABILITY is measured with those caps active — caps
    interact, because a cap that holds the bar hidden in one bin is what lets a later bin still be
    pre-show. The error columns are unaffected by confidence, so injecting caps never contaminates the
    measurement the caps are derived FROM.
    """
    fields = list(context)
    if extra_caps:
        body = ", ".join(f"[{b}] = {extra_caps[b]}" for b in sorted(extra_caps, reverse=True))
        fields.append(f"confCap = {{ {body} }}")
    lua = "{ " + ", ".join(fields) + " }" if fields else ""
    cmd = (
        [luajit, "tools/estimator-perbin.lua", str(enc), corpus]
        + (["--even"] if split_even else [])
        + (["--regime", lua] if lua else [])
    )
    proc = subprocess.run(cmd, capture_output=True, text=True)
    if proc.returncode != 0:
        sys.exit(f"estimator-perbin failed: {proc.stderr.strip()[:300]}")
    out = {}
    for line in proc.stdout.splitlines():
        parts = line.split("\t")
        if len(parts) == 5:
            b, n, mr, ma, pre = parts
            out[int(b)] = (int(n), float(mr), float(ma), float(pre))
    if not out:
        sys.exit("estimator-perbin returned no rows (expected 5-column TSV — stale tool?)")
    return out


perbin = run_perbin()
measured = {b: v[:3] for b, v in perbin.items()}  # bin -> (n, medianRel, medianAbs)


def derive(measured):
    """The measurement → cap rule. Unchanged by WO-076; reachability is applied separately, after."""
    out = {}
    for b, (n, mr, ma) in measured.items():
        if n < 20:  # too little evidence in this bin to judge it
            continue
        if ma <= ABS_OK or mr <= REL_OK:
            continue  # measurably useful here — no cap, whichever currency says so
        if ma >= ABS_BAD:
            out[b] = 0.0  # tens of seconds wrong: unusable regardless of ratio
            continue
        frac = (mr - REL_OK) / (REL_BAD - REL_OK)
        cap = round(max(0.0, min(1.0, 1.0 - frac)), 2)
        if cap < 0.995:
            out[b] = cap
    return out


# ── 2b. REACHABILITY (WO-076) — drop caps the client can never apply ────────────────────────────────
# The client's show gate is STICKY (src/live/driver.lua:55-80): minTTK and minConfidenceToShow are
# consulted only while `not wasShown`. Once the bar latches, every later cap — including a hard 0.0 — is
# unreachable. Caps derived without this are dead data; it is why Viscidus's shipped profile was
# bit-identical to shipping no regime at all, and why Onyxia's `[11] = 0.0` (the air phase, its WORST
# bin at 45.9% / 59.0s) never fired. D-021 says a re-derived number is not licence to edit shipped data,
# so this only stops the learner EMITTING dead caps — the shipped table is a separate human call.
#
# Iterate, because caps interact: keeping bin 20's cap is what holds the bar hidden into bin 19. Dropping
# a cap can only make later bins latch EARLIER, so the set shrinks monotonically and converges fast.
REACH_MIN = 0.05  # a cap must be able to act on ≥5% of its bin's in-scope samples to be worth shipping

caps = derive(measured)
unreachable = {}
for _ in range(BINS):  # bounded; converges in 2-3 passes in practice
    if not caps:
        break
    reach = {b: v[3] for b, v in run_perbin(caps).items()}
    dead = {b: reach.get(b, 0.0) for b, c in caps.items() if reach.get(b, 0.0) < REACH_MIN}
    if not dead:
        break
    for b in dead:
        unreachable[b] = (caps.pop(b), dead[b])
final_reach = {b: v[3] for b, v in run_perbin(caps).items()} if caps else {}

# NOTE: the universal raid floor (ns.Regimes.default) is deliberately NOT folded in here. It is a blanket
# assumption for bosses we have never measured; where we HAVE measured, the measurement wins — folding the
# floor in anyway silenced bins the data shows are accurate (measured on Chromaggus, whose 90-95% band is
# among the most readable in the corpus, yet the blanket floor hid it and made the grade worse).

# ── 3. emit ─────────────────────────────────────────────────────────────────────────────────────────
src = f"{kills} kills" + (", TRAIN half of an even/odd split — odd half held out" if split_even else "")
lines = [f"    encounterID = {enc},", f"    kills = {kills},"]
if caps:
    body = ", ".join(f"[{b}] = {caps[b]}" for b in sorted(caps, reverse=True))
    lines.append(f"    confCap = {{ {body} }},")
if reset_on_rise:
    lines.append(f"    resetOnRise = {reset_on_rise},")

with open(f"tools/candidates/regime-{enc}.lua", "w") as fh:
    fh.write(
        f"""-- Learned regime profile — encounter {enc} ({src}; WO-075). AUTO-GENERATED by
-- tools/learn-regime.py; do not hand-edit. confCap[i] caps CONFIDENCE in health bin i (bin {BINS} =
-- h in (0.95,1.0], bin 1 = the execute end), learned from the estimator's OWN measured error over real
-- kills: where the readout is measurably wrong the bar goes QUIET (the client hides it below
-- minConfidenceToShow = 0.5) instead of showing a confident-wrong countdown.
--
-- Only REACHABLE bins carry a cap (WO-076): the client's show gate is sticky, so a cap can act only
-- while the bar has not yet latched. Bins that are measurably wrong but only reached after the bar is
-- already up are deliberately left uncapped — a cap there would never fire.
return {{
{chr(10).join(lines)}
}}
"""
    )

print(f"learned from {kills} kills → tools/candidates/regime-{enc}.lua")
print(f"\nEncounter {enc} regime  (measured estimator error per health bin → confidence cap)")
for b in range(BINS, 0, -1):
    if b not in measured:
        continue
    n, mr, ma = measured[b]
    hi, lo = b * 100 // BINS, (b - 1) * 100 // BINS
    cap = caps.get(b, 1.0)
    bar = "█" * max(1, round(min(mr, 1.5) * 13))
    if b in unreachable:
        dropped_cap, reach = unreachable[b]
        tag = f" ← WRONG BUT UNREACHABLE (cap {dropped_cap:.2f} dropped; bar already up, {reach * 100:.1f}% pre-show)"
    elif cap < 0.5:
        tag = " ← QUIET (measurably wrong)"
    elif cap < 0.995:
        tag = " ← capped"
    else:
        tag = ""
    print(f"  {hi:3d}–{lo:3d}%  err {mr * 100:5.1f}% / {ma:5.1f}s  n{n:6d}  cap {cap:4.2f}  {bar}{tag}")
if freeze:
    print(f"\n  [diagnostic only, not emitted] stall band: h {freeze[0]:.2f}–{freeze[1]:.2f}, ~{freeze[2]}s  ({len(mid_fight)}/{kills} kills)")
if reset_on_rise:
    print(f"  resetOnRise: {reset_on_rise}  ({rises}/{kills} kills show a >={RISE_MIN} one-sample rise)")
quiet = sum(1 for b in caps if caps[b] < 0.5)
print(f"\n  {quiet}/{BINS} bins can HIDE the bar (cap < minConf 0.5, and reachable before it latches)")
if unreachable:
    detail = ", ".join(
        f"[{b}] {c:.2f}" for b, (c, _) in sorted(unreachable.items(), reverse=True)
    )
    print(
        f"  {len(unreachable)} cap(s) DROPPED as unreachable: {detail}\n"
        f"    The show gate is sticky (driver.lua:55-80) — by these bins the bar has already latched, so\n"
        f"    no confidence value can hide it. These bins are measurably wrong but need a mechanism other\n"
        f"    than confidence; emitting a cap here would ship dead data. (WO-076)"
    )
if caps and final_reach:
    worst = min((final_reach.get(b, 0.0), b) for b in caps)
    print(f"  reachability of kept caps: min {worst[0] * 100:.1f}% pre-show (bin {worst[1]})")
