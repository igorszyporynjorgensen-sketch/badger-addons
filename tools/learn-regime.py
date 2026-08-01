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

# ── 1. per-bin measured error, from the real estimator ──────────────────────────────────────────────
luajit = shutil.which("luajit") or shutil.which("lua")
if not luajit:
    sys.exit("luajit not found (needed to replay the estimator)")
# --suppress-flush: measure with that categorical fact already enabled, because it is going to ship. Caps
# must be calibrated against the estimator the client actually runs (on Buru the flag cuts the error ~3x;
# caps learned without it would silence a readout that is, with the flag, perfectly usable).
suppress_flush = "--suppress-flush" in sys.argv
cmd = (
    [luajit, "tools/estimator-perbin.lua", str(enc), corpus]
    + (["--even"] if split_even else [])
    + (["--suppress-flush"] if suppress_flush else [])
)
proc = subprocess.run(cmd, capture_output=True, text=True)
if proc.returncode != 0:
    sys.exit(f"estimator-perbin failed: {proc.stderr.strip()[:300]}")

measured = {}  # bin -> (n, medianRel, medianAbs)
for line in proc.stdout.splitlines():
    parts = line.split("\t")
    if len(parts) == 4:
        b, n, mr, ma = int(parts[0]), int(parts[1]), float(parts[2]), float(parts[3])
        measured[b] = (n, mr, ma)

caps = {}
for b, (n, mr, ma) in measured.items():
    if n < 20:  # too little evidence in this bin to judge it
        continue
    if ma <= ABS_OK or mr <= REL_OK:
        continue  # measurably useful here — no cap, whichever currency says so
    if ma >= ABS_BAD:
        caps[b] = 0.0  # tens of seconds wrong: unusable regardless of ratio
        continue
    frac = (mr - REL_OK) / (REL_BAD - REL_OK)
    cap = round(max(0.0, min(1.0, 1.0 - frac)), 2)
    if cap < 0.995:
        caps[b] = cap

# NOTE: the universal raid floor (ns.Regimes.default) is deliberately NOT folded in here. It is a blanket
# assumption for bosses we have never measured; where we HAVE measured, the measurement wins — folding the
# floor in anyway silenced bins the data shows are accurate (measured on Chromaggus, whose 90-95% band is
# among the most readable in the corpus, yet the blanket floor hid it and made the grade worse).

# ── 2. curve shape: genuine flat stalls and phase resets ────────────────────────────────────────────
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


def freeze_earns_its_keep(band):
    """A detected stall only SHIPS if freezing it measurably improves the grade.

    Detection alone is not evidence: a fight can stall briefly and still be better served by the rhythm
    (Onyxia's air phase is a slowdown — freezing it changes nothing), while a true freeze phase transforms
    the readout (Viscidus). Decided on the TRAIN half only; the held-out half stays clean for reporting.
    """
    import shutil as _sh
    import tempfile as _tf

    train = files  # already the train half when --split-even
    if len(train) < 6:
        return False
    tmp = _tf.mkdtemp()
    try:
        for f in train:
            _sh.copy(f, tmp)
        cand = f"tools/candidates/regime-{enc}.lua"
        saved = open(cand).read() if glob.glob(cand) else None

        def grade_with(extra):
            with open(cand, "w") as fh:
                fh.write(f"return {{ encounterID = {enc},{extra} }}\n")
            out = subprocess.run([luajit, "tools/estimator-batch.lua", tmp], capture_output=True, text=True).stdout
            m = re.search(r"MAPE\s+mean\s+([\d.]+)%", out)
            return float(m.group(1)) if m else None

        caps_lua = " suppressFlush = true," if suppress_flush else ""  # both arms carry the shipping facts
        if caps:
            caps_lua += " confCap = { " + ", ".join(f"[{b}] = {caps[b]}" for b in sorted(caps, reverse=True)) + " },"
        band_lua = f" freeze = {{ {{ lo = {band[0]}, hi = {band[1]}, stallSec = {band[2]} }} }},"
        without, with_ = grade_with(caps_lua), grade_with(caps_lua + band_lua)
        if saved is not None:
            open(cand, "w").write(saved)
        if without is None or with_ is None:
            return False
        print(f"  freeze check (train): MAPE {without:.1f}% without → {with_:.1f}% with")
        return with_ <= without - 0.5  # must actually help, not merely not-hurt
    finally:
        _sh.rmtree(tmp, ignore_errors=True)


if freeze and not freeze_earns_its_keep(freeze):
    print("  freeze band detected but does NOT improve the grade — not emitted (a slowdown, not a stall)")
    freeze = None

# ── 3. emit ─────────────────────────────────────────────────────────────────────────────────────────
src = f"{kills} kills" + (", TRAIN half of an even/odd split — odd half held out" if split_even else "")
lines = [f"    encounterID = {enc},", f"    kills = {kills},"]
if caps:
    body = ", ".join(f"[{b}] = {caps[b]}" for b in sorted(caps, reverse=True))
    lines.append(f"    confCap = {{ {body} }},")
if freeze:
    lines.append(f"    freeze = {{ {{ lo = {freeze[0]}, hi = {freeze[1]}, stallSec = {freeze[2]} }} }},")
if reset_on_rise:
    lines.append(f"    resetOnRise = {reset_on_rise},")

with open(f"tools/candidates/regime-{enc}.lua", "w") as fh:
    fh.write(
        f"""-- Learned regime profile — encounter {enc} ({src}; WO-075). AUTO-GENERATED by
-- tools/learn-regime.py; do not hand-edit. confCap[i] caps CONFIDENCE in health bin i (bin {BINS} =
-- h in (0.95,1.0], bin 1 = the execute end), learned from the estimator's OWN measured error over real
-- kills: where the readout is measurably wrong the bar goes QUIET (the client hides it below
-- minConfidenceToShow = 0.5) instead of showing a confident-wrong countdown.
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
    tag = " ← QUIET (measurably wrong)" if cap < 0.5 else (" ← capped" if cap < 0.995 else "")
    print(f"  {hi:3d}–{lo:3d}%  err {mr * 100:5.1f}% / {ma:5.1f}s  n{n:6d}  cap {cap:4.2f}  {bar}{tag}")
if freeze:
    print(f"\n  freeze band: h {freeze[0]:.2f}–{freeze[1]:.2f}, stallSec {freeze[2]}  ({len(mid_fight)} stalls / {kills} kills)")
if reset_on_rise:
    print(f"  resetOnRise: {reset_on_rise}  ({rises}/{kills} kills show a >={RISE_MIN} one-sample rise)")
quiet = sum(1 for b in caps if caps[b] < 0.5)
print(f"\n  {quiet}/{BINS} bins would HIDE the bar (cap < minConf 0.5)")
