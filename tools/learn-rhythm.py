#!/usr/bin/env python3
"""
learn-rhythm.py — learn an encounter's RHYTHM PROFILE from harvested fight curves (WO-069 loop 1).

The profile is m(h): the kill-rate at health h relative to the fight's average rate (1.0 = average,
2.0 = twice as fast — an execute dump; 0.3 = a slow stretch — an adds gate / setup). The estimator
consumes it as an injected dependency (opts.rhythm): live observation calibrates the SCALE (this
group's speed), the profile supplies the SHAPE (what the fight does next).

  python3 tools/learn-rhythm.py <encounterID> [--bins 20] [--corpus tools/fights/corpus]

Reads  <corpus>/<enc>-*.lua, computes per-kill per-bin normalized rates (bin-edge crossing times by
linear interpolation), takes the MEDIAN across kills (robust to one weird pull), floors/caps the bins
(0.10..6.0 — a zero-rate bin would explode the integral), and writes:
  tools/candidates/rhythm-<enc>.lua   — the profile table a candidate estimator (or the driver) injects
Also prints the learned shape as ASCII so the rhythm is *visible*. Stdlib only.
"""

import re
import sys
import glob
import statistics

enc = sys.argv[1] if len(sys.argv) > 1 else sys.exit("usage: learn-rhythm.py <encounterID> [--bins N]")
BINS = int(sys.argv[sys.argv.index("--bins") + 1]) if "--bins" in sys.argv else 20
corpus = sys.argv[sys.argv.index("--corpus") + 1] if "--corpus" in sys.argv else "tools/fights/corpus"
FLOOR, CAP = 0.10, 6.0

files = sorted(glob.glob(f"{corpus}/{enc}-*.lua"))
if not files:
    sys.exit(f"no fixtures for encounter {enc} in {corpus}")

per_kill = []  # each: list of m per bin (index 0 = health (BINS-1)/BINS..1.0 — top of the fight)
for f in files:
    pts = [(float(a), float(b)) for a, b in re.findall(r"t = ([\d.]+), h = ([\d.]+)", open(f).read())]
    if len(pts) < 4:
        continue
    death = pts[-1][0]
    # T(e): first time health reaches edge e (linear interpolation between samples; h is monotone-ish —
    # use the first downward crossing so a stray heal can't rewind time).
    def T(e):
        prev_t, prev_h = pts[0]
        if prev_h <= e:
            return prev_t
        for t, h in pts[1:]:
            if h <= e < prev_h:
                span_h = prev_h - h
                return prev_t + (t - prev_t) * ((prev_h - e) / span_h if span_h > 0 else 0)
            prev_t, prev_h = t, h
        return death
    edges = [1.0 - i / BINS for i in range(BINS + 1)]  # 1.0 .. 0.0, top-down
    times = [T(e) for e in edges]
    ms = []
    for i in range(BINS):
        dt = times[i + 1] - times[i]
        w = 1.0 / BINS
        # m = (bin rate) / (average rate) = (w/dt) / (1/death) = w*death/dt
        m = (w * death / dt) if dt > 1e-6 else CAP
        ms.append(max(FLOOR, min(CAP, m)))
    per_kill.append(ms)

if not per_kill:
    sys.exit("no usable curves")

# Median across kills, per bin (top-down order: bin 1 = highest health).
profile_top_down = [round(statistics.median(k[i] for k in per_kill), 3) for i in range(BINS)]
# The estimator indexes bins bottom-up (bins[1] = h near 0), so reverse for the Lua table.
bins_bottom_up = list(reversed(profile_top_down))

with open(f"tools/candidates/rhythm-{enc}.lua", "w") as fh:
    fh.write(f"""-- Learned rhythm profile — encounter {enc} ({len(per_kill)} kills, WO-069 loop 1). AUTO-GENERATED
-- by tools/learn-rhythm.py; do not hand-edit. bins[i] covers health ((i-1)/K, i/K] — bins[1] is the
-- EXECUTE end, bins[{BINS}] the pull. Value = kill-rate relative to the fight's average (1.0 = average).
return {{
    encounterID = {enc},
    kills = {len(per_kill)},
    bins = {{ {", ".join(str(b) for b in bins_bottom_up)} }},
}}
""")

print(f"learned from {len(per_kill)} kills → tools/candidates/rhythm-{enc}.lua")
print(f"\nLucifron's rhythm  (m = rate vs fight average; ▏1.0 = average)")
for i, m in enumerate(profile_top_down):
    hi, lo = 100 - i * 100 // BINS, 100 - (i + 1) * 100 // BINS
    bar = "█" * max(1, round(m * 12))
    tag = " ← slow (gate/setup)" if m < 0.6 else (" ← FAST (burn/execute)" if m > 1.5 else "")
    print(f"  {hi:3d}–{lo:3d}%  {m:5.2f}  {bar}{tag}")
