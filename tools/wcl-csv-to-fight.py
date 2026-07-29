#!/usr/bin/env python3
"""
wcl-csv-to-fight.py — turn a Warcraft Logs "Events" CSV export into a fight file
for the estimator replay grader (tools/estimator-replay.lua). This is the tested,
no-credentials path of dev-mode "piece 2" (the API route lives in wcl-to-fight.py).

WHAT TO EXPORT (important):
  On the fight's *Events* view, FILTER THE TARGET to the boss, then "Export to CSV".
  WCL caps the export at ~300 rows, so an unfiltered pull only covers the first few
  seconds of a big fight — filtering to just the boss fits the whole fight in one
  file AND drops the add/cleave noise. Each row must look like:
      "Time","Event"
      "00:00.102","Skyju Multi-Shot  Lucifron *1492*"
  i.e. MM:SS.mmm  +  "<source> <ability>  <target> <amount>[ modifiers]".

RUN (from the repo root):
  python3 tools/wcl-csv-to-fight.py <events.csv> [--boss "Name"] [--maxhp N] [--out file.lua]

  --boss   the target to reconstruct (default: auto — the target whose LAST hit is
           latest, i.e. the one that dies at the kill; adds die earlier). "X Tick"
           DoT rows fold into "X". Names with spaces need quotes.
  --maxhp  the boss's true max HP (from the Damage-Done summary: the sum of the
           Amount column). Used as the exact health denominator AND to detect a
           truncated export. Omit to normalise by the events' own total (assumes
           the export is the complete fight).
  --out    output path (default: tools/fights/<slug>.lua).

Then grade it:
  luajit tools/estimator-replay.lua tools/fights/<slug>.lua

Stdlib only. Reads the CSV; writes one .lua fight file.
"""

import sys
import csv
import re

DT = 0.15  # resample cadence — matches the live driver (src/live/driver.lua INTERVAL)

# Trailing decorations on the result, stripped before we read the amount.
_MODS = re.compile(
    r"\s*(\([A-Za-z]:\s*[\d,]+\)|Glancing|Crushing|Blocked|Absorbed|Partial Resist|\(reflected\))\s*$"
)
_MISS = re.compile(
    r"\s+(Dodge|Parr(y|ied)|Miss(ed)?|Immune|Absorb(ed)?|Resist(ed)?|Evade[ds]?|Reflect|Deflect)\s*$"
)
_AMT = re.compile(r"\*?([\d,]+)\*?$")  # trailing amount, crit stars optional


def die(msg):
    sys.stderr.write("error: " + msg + "\n")
    sys.exit(1)


def parse_time(s):
    m, rest = s.split(":")
    return int(m) * 60 + float(rest)


def parse_result(right):
    """Split a '<target> <amount>[mods]' string into (target, amount). Misses → 0."""
    r = right.strip()
    while True:
        m = _MODS.search(r)
        if not m:
            break
        r = r[: m.start()].rstrip()
    m = _AMT.search(r)
    if m:
        return r[: m.start()].rstrip(), int(m.group(1).replace(",", ""))
    m = _MISS.search(r)
    return (r[: m.start()].rstrip() if m else r), 0


def norm_target(t):
    # Fold periodic (DoT) rows — "Lucifron Tick" — into their base target.
    return t[:-5].rstrip() if t.endswith(" Tick") else t


def lua_str(s):
    return '"' + s.replace("\\", "\\\\").replace('"', '\\"') + '"'


def main():
    argv = sys.argv[1:]
    if not argv:
        die("usage: wcl-csv-to-fight.py <events.csv> [--boss NAME] [--maxhp N] [--out FILE]")
    path = argv[0]
    boss = maxhp = out = None
    i = 1
    while i < len(argv):
        a = argv[i]
        if a == "--boss":
            boss = argv[i + 1]
            i += 2
        elif a == "--maxhp":
            maxhp = float(argv[i + 1])
            i += 2
        elif a == "--out":
            out = argv[i + 1]
            i += 2
        else:
            die("unknown argument: " + a)

    # Group every damage event by (normalised) target.
    by = {}  # target -> list of (t, amount)
    with open(path, newline="") as fh:
        rd = csv.reader(fh)
        next(rd, None)  # header
        for row in rd:
            if len(row) < 2 or not row[0] or not row[1]:
                continue
            parts = row[1].split("  ", 1)
            if len(parts) < 2:
                continue
            tgt, amt = parse_result(parts[1])
            by.setdefault(norm_target(tgt), []).append((parse_time(row[0]), amt))
    if not by:
        die("no parseable events — is this a WCL 'Events' export ('Time','Event')?")

    # Report what's in the file so the boss choice is transparent.
    sys.stderr.write("%-28s %5s %10s %8s %8s\n" % ("target", "hits", "damage", "first", "last"))
    stats = {}
    for tgt, evs in by.items():
        tot = sum(a for _, a in evs)
        last = max(t for t, _ in evs)
        stats[tgt] = (len(evs), tot, min(t for t, _ in evs), last)
    for tgt, (n, tot, first, last) in sorted(stats.items(), key=lambda kv: -kv[1][1]):
        sys.stderr.write("%-28s %5d %10d %8.2f %8.2f\n" % (tgt, n, tot, first, last))

    # Pick the boss: explicit name, else the target that dies last (adds die earlier).
    if boss:
        boss = norm_target(boss)
        if boss not in by:
            die("no target named %r; see the table above" % boss)
    else:
        boss = max(stats, key=lambda t: stats[t][3])  # latest last-hit
        sys.stderr.write("auto-selected boss: %r (latest last-hit)\n" % boss)

    evs = sorted(by[boss])
    ev_total = sum(a for _, a in evs)
    denom = maxhp if maxhp else ev_total
    if denom <= 0:
        die("boss took no damage in this file")

    # Truncation guard: with a known max HP, cumulative damage should reach ~100%.
    if maxhp and ev_total < 0.9 * maxhp:
        sys.stderr.write(
            "WARNING: events sum to %d but max HP is %.0f (%.0f%%). This export looks\n"
            "         TRUNCATED (WCL's ~300-row cap). Re-export with the target filtered\n"
            "         to the boss so the whole fight fits in one file.\n"
            % (ev_total, maxhp, 100.0 * ev_total / maxhp)
        )

    # Reconstruct the health curve: health(t) = 1 - cumulativeDamage(t) / denom.
    obs = [(0.0, 1.0)]
    cum = 0.0
    for t, a in evs:
        cum += a
        obs.append((t, max(0.0, 1.0 - cum / denom)))
    death = evs[-1][0]

    # Resample to DT with a stepwise hold — how the live driver polls UnitHealth.
    obs.sort()
    samples = []
    j, cur, st = 0, 1.0, 0.0
    while st <= death + 1e-9:
        while j < len(obs) and obs[j][0] <= st:
            cur = obs[j][1]
            j += 1
        samples.append((st, cur))
        st += DT
    samples.append((round(death, 2), 0.0))

    name = "%s (WCL events)" % boss
    lines = [
        "-- Auto-generated by tools/wcl-csv-to-fight.py — do not edit by hand.",
        "-- Reconstructed from a Warcraft Logs Events CSV: %s's health fraction over time." % boss,
        "",
        "return {",
        "    name = %s," % lua_str(name),
        "    samples = {",
    ]
    for t, h in samples:
        lines.append("        { t = %.2f, h = %.4f }," % (t, h))
    lines += ["    },", "}", ""]

    if not out:
        slug = "".join(c.lower() if c.isalnum() else "-" for c in boss).strip("-")
        out = "tools/fights/%s.lua" % slug
    with open(out, "w") as fh:
        fh.write("\n".join(lines))
    sys.stderr.write(
        "\nwrote %s  (%d samples, death=%.1fs, %d boss events, denom=%.0f)\n"
        % (out, len(samples), death, len(evs), denom)
    )
    sys.stderr.write("grade it:  luajit tools/estimator-replay.lua %s\n" % out)


if __name__ == "__main__":
    main()
