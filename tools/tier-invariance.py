#!/usr/bin/env python3
"""
tier-invariance.py — does an encounter's NORMALIZED rhythm shape depend on how fast the raid kills it?

This is the question that decides whether one shipped profile can serve everyone (WO-077).

The rhythm profile (learn-rhythm.py) is scale-free: per health bin it stores m = that bin's share of
health divided by its share of time, so m = 1.0 means "this bin went at the fight's own average pace".
If m is INVARIANT across fast and slow kills, then a speedguild and a pug share one shape and differ only
in scale — the corpus's well-known fast-end bias would then be harmless, and one profile fits all.
If m VARIES with kill speed, a single profile is a compromise that is wrong at both ends, and the client
must infer which end it is in — for which early absolute HP/s is the only available signal.

  python3 tools/tier-invariance.py <encounterID> [--corpus DIR] [--bins 20] [--min-dur 12]

Prints the per-bin profile for each duration tercile plus the divergence. Read-only; stdlib only.
"""
import re
import sys
import glob
import statistics as st

enc = sys.argv[1] if len(sys.argv) > 1 else sys.exit("usage: tier-invariance.py <encounterID>")
corpus = sys.argv[sys.argv.index("--corpus") + 1] if "--corpus" in sys.argv else "tools/fights/mc"
BINS = int(sys.argv[sys.argv.index("--bins") + 1]) if "--bins" in sys.argv else 20
MIN_DUR = float(sys.argv[sys.argv.index("--min-dur") + 1]) if "--min-dur" in sys.argv else 12.0
FLOOR, CAP = 0.10, 6.0

C = dict(r="\x1b[0m", dim="\x1b[38;5;244m", gold="\x1b[38;5;178m", good="\x1b[38;5;71m",
         warn="\x1b[38;5;214m", bad="\x1b[38;5;203m", ink="\x1b[38;5;252m", bold="\x1b[1m")


def profile(path):
    """Same math as learn-rhythm.py:45-70 — one m per health bin, top-down."""
    pts = [(float(a), float(b)) for a, b in
           re.findall(r"t = ([\d.]+), h = ([\d.]+)", open(path).read())]
    if len(pts) < 20:
        return None, None
    death = pts[-1][0]
    if death < MIN_DUR:
        return None, None

    def T(e):
        pt, ph = pts[0]
        if ph <= e:
            return pt
        for t, h in pts[1:]:
            if h <= e < ph:
                span = ph - h
                return pt + (t - pt) * ((ph - e) / span if span > 0 else 0)
            pt, ph = t, h
        return death

    times = [T(1.0 - i / BINS) for i in range(BINS + 1)]
    ms = []
    for i in range(BINS):
        dt = times[i + 1] - times[i]
        ms.append(max(FLOOR, min(CAP, (1.0 / BINS) * death / dt)) if dt > 1e-6 else CAP)
    return ms, death


rows = []
for f in sorted(glob.glob(f"{corpus}/*/{enc}-*.lua")) or sorted(glob.glob(f"{corpus}/{enc}-*.lua")):
    ms, d = profile(f)
    if ms:
        rows.append((d, ms))
if len(rows) < 30:
    sys.exit(f"only {len(rows)} usable kills for {enc} in {corpus} — need >=30 to tercile")
rows.sort()
t = len(rows) // 3
groups = [("FAST", rows[:t]), ("MID", rows[t:2 * t]), ("SLOW", rows[2 * t:])]

print(f"\n{C['gold']}{C['bold']}TIER INVARIANCE — encounter {enc}, {len(rows)} kills{C['r']}")
for name, g in groups:
    print(f"  {C['dim']}{name:<5} n={len(g):3d}  {g[0][0]:6.1f}-{g[-1][0]:6.1f}s{C['r']}")
prof = {n: [st.median(k[1][i] for k in g) for i in range(BINS)] for n, g in groups}

print(f"\n{'bin':>4}{'health':>11}{'FAST':>8}{'MID':>8}{'SLOW':>8}{'SLOW-FAST':>11}")
step = 100 // BINS
worst = (0.0, None)
for i in range(BINS):
    hi, lo = 100 - i * step, 100 - (i + 1) * step
    f_, m_, s_ = prof["FAST"][i], prof["MID"][i], prof["SLOW"][i]
    d = s_ - f_
    if abs(d) > abs(worst[0]):
        worst = (d, (hi, lo))
    col = C["bad"] if abs(d) > 0.35 else (C["warn"] if abs(d) > 0.20 else C["dim"])
    print(f"{i+1:>4}{hi:>8}-{lo:<3}{f_:>8.3f}{m_:>8.3f}{s_:>8.3f}{col}{d:>+11.3f}{C['r']}")

diffs = [abs(prof["SLOW"][i] - prof["FAST"][i]) for i in range(BINS)]
mean_d = st.mean(diffs)
# Monotonic bins: FAST<MID<SLOW or FAST>MID>SLOW — a systematic trend rather than noise.
mono = sum(1 for i in range(BINS)
           if (prof["FAST"][i] < prof["MID"][i] < prof["SLOW"][i])
           or (prof["FAST"][i] > prof["MID"][i] > prof["SLOW"][i]))
# The divergence is only comparable across bosses once the SAMPLED DURATION RANGE is accounted for: a
# corpus spanning 14-52s cannot show as much drift as one spanning 14-116s, whatever the truth is. Report
# drift per unit of range so two encounters can actually be compared.
fast_med = st.median(k[0] for k in groups[0][1])
slow_med = st.median(k[0] for k in groups[2][1])
ratio = slow_med / fast_med if fast_med > 0 else 1.0
print(f"\n  duration range          FAST median {fast_med:.1f}s -> SLOW median {slow_med:.1f}s "
      f"({ratio:.1f}x)")
print(f"  drift per x of range    {mean_d / max(1e-9, ratio - 1):.3f}  "
      f"{C['dim']}(comparable across bosses){C['r']}")
print(f"  mean |SLOW-FAST|        {mean_d:.3f}")
print(f"  largest divergence      {worst[0]:+.3f} at health {worst[1][0]}-{worst[1][1]}%")
print(f"  monotone in tier         {mono}/{BINS} bins  "
      f"{C['dim']}(FAST<MID<SLOW or reverse — a trend, not noise){C['r']}")
verdict = ("NOT invariant — one profile is a compromise" if mean_d > 0.15 or mono >= BINS * 0.5
           else "consistent with invariance — one profile may serve all tiers")
col = C["bad"] if "NOT" in verdict else C["good"]
print(f"  {C['bold']}verdict: {col}{verdict}{C['r']}\n")
