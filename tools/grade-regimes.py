#!/usr/bin/env python3
"""
grade-regimes.py — per-boss BASELINE vs REGIME comparison on the held-out half (WO-075 acceptance).

For every encounter that has a learned candidate (tools/candidates/regime-<enc>.lua), replays the
HELD-OUT (odd-indexed) fixtures twice — once with the regime injected, once without — and prints MAPE
next to **shown%**. Reporting both is the point: a regime earns its keep by making the bar QUIET where it
was confident-wrong, and a MAPE that improves purely because rows disappeared is not a win but a
disclosure. Rows the cap silences are counted, so "honest quiet" is visible rather than hidden.

  python3 tools/grade-regimes.py [--corpus DIR]

Stdlib only (shells out to luajit + the existing batch grader). Lab tooling — never ships.
"""

import os
import re
import sys
import glob
import shutil
import subprocess
import tempfile

corpus = sys.argv[sys.argv.index("--corpus") + 1] if "--corpus" in sys.argv else "tools/fights/corpus"
luajit = shutil.which("luajit") or shutil.which("lua") or sys.exit("luajit not found")

NAMES = {
    "150616": "Chromaggus", "150669": "Sulfuron", "150709": "Skeram", "150713": "Viscidus",
    "150715": "Twin Emperors", "150716": "Ouro", "150717": "C'Thun", "150719": "Rajaxx",
    "150721": "Buru", "150792": "Jin'do", "151084": "Onyxia",
}

AGG = re.compile(r"MAPE\s+mean\s+([\d.]+)%\s+median\s+([\d.]+)%")
BIAS = re.compile(r"bias\s+mean\s+([+-][\d.]+)s")


def grade(d, shipped=False):
    """Run the batch grader over a directory → (mean, median, bias, shown%, graded-n).

    `shipped` grades src/raids/regimes.lua — the profile the client actually gets, including the
    hand-authored categorical facts the learner never emits. Grading candidates alone misreports any boss
    whose fix is such a fact.
    """
    cmd = [luajit, "tools/estimator-batch.lua", d] + (["--shipped"] if shipped else [])
    out = subprocess.run(cmd, capture_output=True, text=True).stdout
    m, b = AGG.search(out), BIAS.search(out)
    shown, n = [], 0
    for line in out.splitlines():
        cols = line.split()
        if len(cols) >= 6 and cols[-1].endswith("%") and "MAPE" not in line:
            try:
                shown.append(float(cols[-1].rstrip("%")))
                n += 1
            except ValueError:
                pass
    if not m:
        return None
    return (float(m.group(1)), float(m.group(2)), float(b.group(1)) if b else 0.0,
            (sum(shown) / len(shown)) if shown else 0.0, n)


rows = []
for cand in sorted(glob.glob("tools/candidates/regime-*.lua")):
    enc = re.search(r"regime-(\d+)\.lua", cand).group(1)
    files = sorted(glob.glob(f"{corpus}/{enc}-*.lua"))
    held = files[1::2]  # the odd-indexed HELD-OUT half (learners train on the even half)
    if len(held) < 3:
        continue
    with tempfile.TemporaryDirectory() as tmp:
        for f in held:
            shutil.copy(f, tmp)
        stash = cand + ".stash"
        os.rename(cand, stash)  # baseline: no candidate and no --shipped ⇒ regime = nil
        base = grade(tmp)
        os.rename(stash, cand)
        reg = grade(tmp, shipped=True)  # exactly what the client will run
    if base and reg:
        rows.append((enc, len(held), base, reg))
    elif base and not reg:
        # No confident rows survived: the regime silenced the bar for the WHOLE fight. That is a real
        # (and deliberate) outcome for a boss whose health is uninformative — surface it, never drop it.
        rows.append((enc, len(held), base, None))

if not rows:
    sys.exit("no encounters with both a candidate and a held-out half")

print(f"\nHELD-OUT per-boss grade — baseline (rhythm only) vs + learned regime   [{corpus}]")
print(f"{'boss':<15}{'n':>4}  {'MAPE mean':>19}  {'median':>15}  {'bias':>15}  {'shown%':>15}")
for enc, n, b, r in rows:
    name = NAMES.get(enc, enc)
    if r is None:
        print(
            f"{name:<15}{n:>4}  {b[0]:>8.1f} →  SILENT   {b[1]:>6.1f} →      -  "
            f"{b[2]:>+6.1f} →      -  {b[3]:>6.0f} →     0%   (health uninformative all fight)"
        )
        continue
    print(
        f"{name:<15}{n:>4}  {b[0]:>8.1f} → {r[0]:>7.1f}%  {b[1]:>6.1f} → {r[1]:>5.1f}%  "
        f"{b[2]:>+6.1f} → {r[2]:>+5.1f}s  {b[3]:>6.0f} → {r[3]:>5.0f}%"
    )
print("\n  shown% falling = the bar going QUIET where it was measurably wrong (the intended trade).")
print("  A MAPE drop that comes only from hidden rows is a disclosure, not a win — read the two together.")
