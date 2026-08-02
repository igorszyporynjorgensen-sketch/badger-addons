#!/usr/bin/env python3
"""
corpus-audit.py — flag fight logs that are bad MEASUREMENTS, before they are learned from (WO-077).

A confidence model calibrated on corrupt curves learns to distrust the estimator everywhere, and a rhythm
profile learned from them encodes artifacts of the LOGGING as if they were properties of the encounter.
So the corpus needs a quality gate.

THE RULE THAT KEEPS THIS HONEST: every check here is computable from the curve alone. None of them may
consult how the estimator scored the fight. A slow, messy, genuinely hard kill is the most valuable data
in the corpus — it is the closest thing we have to a real pug — and excluding it because it grades badly
is how a lab flatters itself. That is the failure WO-076 corrected; this tool must not reintroduce it.

  python3 tools/corpus-audit.py [--corpus DIR] [--fix]

Checks (all grade-blind):
  LATE START   the curve does not begin near full health — the log opened mid-pull, so t=0 is not the
               pull and every elapsed-time reading is offset. This is the failure that made a Lucifron
               CSV export read 1069% MAPE where the exact API pull read 66% (D-012).
  RESET        health jumps UP by a lot — a phase reset, an encounter restart, or a mis-attributed target.
               Legitimate on a few bosses (Thekal resurrects), so it is reported per encounter, not
               globally condemned.
  GAP          a long stretch with no health change AND no samples — a logging dropout, not a stall.
  SPARSE       too few samples for the fight's length: the curve is being interpolated more than measured.
  FLATLINE     the fight ends without the boss reaching low health — a wipe mislabelled as a kill.

`--fix` moves offenders to <corpus>/_rejected/ with the reason recorded, so the exclusion is auditable
and reversible rather than a silent deletion.
"""
import os
import re
import sys
import glob
import shutil
import statistics as st
from collections import defaultdict

corpus = sys.argv[sys.argv.index("--corpus") + 1] if "--corpus" in sys.argv else "tools/fights/mc"
FIX = "--fix" in sys.argv

# Thresholds, chosen to catch artifacts rather than difficulty.
START_MIN = 0.97      # curve must begin at >=97% health
RISE_MAX = 0.10       # an upward jump beyond this is a reset, not a heal tick
GAP_MAX = 8.0         # seconds of dead air with zero health movement
MIN_SAMPLES_PER_S = 2.0
END_MAX = 0.05        # a kill must actually reach ~0

C = dict(r="\x1b[0m", dim="\x1b[38;5;244m", gold="\x1b[38;5;178m", good="\x1b[38;5;71m",
         warn="\x1b[38;5;214m", bad="\x1b[38;5;203m", ink="\x1b[38;5;252m", bold="\x1b[1m")


def curve(path):
    return [(float(a), float(b)) for a, b in
            re.findall(r"t = ([\d.]+), h = ([\d.]+)", open(path).read())]


def audit(pts):
    """Return a list of grade-blind defects for one curve."""
    bad = []
    if len(pts) < 8:
        return ["SPARSE"]
    death = pts[-1][0]
    if pts[0][1] < START_MIN:
        bad.append("LATE-START")
    if pts[-1][1] > END_MAX:
        bad.append("FLATLINE")
    if death > 0 and len(pts) / death < MIN_SAMPLES_PER_S:
        bad.append("SPARSE")
    rise = 0.0
    for i in range(1, len(pts)):
        d = pts[i][1] - pts[i - 1][1]
        if d > rise:
            rise = d
    if rise > RISE_MAX:
        bad.append("RESET")
    # dead air: a long run with literally no health movement at all
    run_start, run_h, worst = pts[0][0], pts[0][1], 0.0
    for t, h in pts[1:]:
        if abs(h - run_h) < 1e-9:
            worst = max(worst, t - run_start)
        else:
            run_start, run_h = t, h
    if worst > GAP_MAX:
        bad.append("GAP")
    return bad


files = sorted(glob.glob(f"{corpus}/*/*.lua")) or sorted(glob.glob(f"{corpus}/*.lua"))
files = [f for f in files if "_rejected" not in f]
if not files:
    sys.exit(f"no fixtures under {corpus}")

by_enc = defaultdict(lambda: {"n": 0, "defects": defaultdict(int), "bad": []})
total_bad = 0
for f in files:
    pts = curve(f)
    enc = os.path.basename(f).split("-")[0]
    rec = by_enc[enc]
    rec["n"] += 1
    d = audit(pts)
    if d:
        total_bad += 1
        rec["bad"].append((f, d))
        for x in d:
            rec["defects"][x] += 1

print(f"\n{C['gold']}{C['bold']}🦡  CORPUS AUDIT — {len(files)} fixtures under {corpus}{C['r']}")
print(f"{C['dim']}grade-blind checks only: nothing here consults how the estimator scored a fight{C['r']}")
print(C["dim"] + "─" * 92 + C["r"])
print(f"{C['dim']}{'encounter':<12}{'n':>6}{'clean':>8}{'LATE-START':>12}{'RESET':>8}{'GAP':>7}"
      f"{'SPARSE':>9}{'FLATLINE':>10}{C['r']}")
for enc in sorted(by_enc):
    r = by_enc[enc]
    d = r["defects"]
    clean = r["n"] - len(r["bad"])
    col = C["good"] if clean == r["n"] else (C["warn"] if clean > 0.9 * r["n"] else C["bad"])
    print(f"{C['ink']}{enc:<12}{C['r']}{r['n']:>6}{col}{clean:>8}{C['r']}"
          f"{d['LATE-START']:>12}{d['RESET']:>8}{d['GAP']:>7}{d['SPARSE']:>9}{d['FLATLINE']:>10}")
print(C["dim"] + "─" * 92 + C["r"])
pct = 100.0 * total_bad / len(files)
col = C["good"] if pct < 2 else (C["warn"] if pct < 10 else C["bad"])
print(f"  {col}{total_bad}/{len(files)} ({pct:.1f}%) flagged{C['r']}")

# RESET is expected on some encounters — report it, do not assume it is corruption.
resets = {e: r["defects"]["RESET"] for e, r in by_enc.items() if r["defects"]["RESET"]}
if resets:
    print(f"\n  {C['dim']}RESET is legitimate where a boss genuinely refills (Thekal). Per encounter:{C['r']}")
    for e, n in sorted(resets.items(), key=lambda kv: -kv[1]):
        frac = 100.0 * n / by_enc[e]["n"]
        note = "likely REAL mechanic" if frac > 50 else "likely artifact"
        print(f"    {e}: {n}/{by_enc[e]['n']} ({frac:.0f}%) — {note}")

if FIX:
    rej = os.path.join(corpus, "_rejected")
    os.makedirs(rej, exist_ok=True)
    moved = 0
    with open(os.path.join(rej, "REASONS.txt"), "a") as log:
        for enc, r in by_enc.items():
            for f, d in r["bad"]:
                # Never reject for RESET alone where it is the encounter's own mechanic.
                if d == ["RESET"] and r["defects"]["RESET"] > 0.5 * r["n"]:
                    continue
                shutil.move(f, os.path.join(rej, os.path.basename(f)))
                log.write(f"{os.path.basename(f)}\t{','.join(d)}\n")
                moved += 1
    print(f"\n  {C['warn']}moved {moved} fixtures to {rej}/ with reasons recorded{C['r']}")
else:
    print(f"\n  {C['dim']}--fix moves offenders to {corpus}/_rejected/ with reasons (auditable, reversible){C['r']}")
print("")
