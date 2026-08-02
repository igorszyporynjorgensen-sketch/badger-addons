#!/usr/bin/env python3
"""
wcl-spectrum.py — harvest a PHASE x PERFORMANCE-TIER corpus (WO-077).

The problem with tools/wcl-corpus.py: it never sends `partition` (wcl-corpus.py:100), so it can only ever
see ONE phase, and it takes kills recent-first, which samples neither the top nor the bottom of the
performance spectrum deliberately. Every profile learned to date therefore came from one phase at the fast
end of the speed leaderboard.

This tool samples on two axes on purpose:

  PHASE GROUP   prog = partitions 1+2 · mid = 3 · farm = 4+5      (partition IS the content phase)
  TIER          t1/t2/t3 = trimmed duration TERCILES within each (boss, phase group)

TIERS ARE DURATION QUANTILES, NEVER PAGE POSITION. The deepest leaderboard page is not "slow raids" — it
is the pathological tail (wipe-recovery, disconnects, half-AFK), which describes the LOGGING, not the
encounter. Measured: mid pages are tight (Ragnaros P1 p10 = 57.5-58.9s) while the final page alone spans
131.6-260.7s. Training on that teaches the estimator noise.

THE CURATION RULE: a kill may be excluded only for a reason statable WITHOUT looking at how the estimator
scored it — a duration outlier past the trim, a curve that resets, an implausible stall. "It graded badly"
is never a reason. Excluding hard-but-real kills is how a lab flatters itself, which is exactly the failure
WO-076 corrected.

Rankings rows are enumerated FIRST (they carry duration/startTime/comp for free), so quantiles and trimming
cost no extra fight pulls. Output is split into train/ val/ test/ SUBDIRECTORIES, stratified within every
cell — every consumer already accepts a corpus dir, so this needs no learner changes, and `test/` can be
touched exactly once.

RUN (from the repo root; WCL_API_KEY in .env):
  python3 tools/wcl-spectrum.py --raid mc --n 450
  python3 tools/wcl-spectrum.py 150672 --n 600 --out tools/fights/mc
  python3 tools/wcl-spectrum.py --raid mc --plan-only      # enumerate + show the plan, pull nothing

Stdlib only.
"""

import os
import re
import sys
import json
import time
import glob
import urllib.error
import urllib.parse
import urllib.request
import subprocess
from concurrent.futures import ThreadPoolExecutor

BASE = "https://www.warcraftlogs.com/v1"
DEFAULT_OUT = "tools/fights/mc"
TIMEOUT = 60
PAGE_ROWS = 50
MAX_PAGE = 20  # measured hard ceiling: page 21 -> HTTP 400

MC = {
    150663: "Lucifron", 150664: "Magmadar", 150665: "Gehennas", 150666: "Garr",
    150667: "Shazzrah", 150668: "Baron Geddon", 150669: "Sulfuron Harbinger",
    150670: "Golemagg", 150671: "Majordomo", 150672: "Ragnaros",
}

# Phase groups. `partition` maps to the content phase; see docs/reference/wcl-corpus-supply.md.
GROUPS = [("prog", [1, 2]), ("mid", [3]), ("farm", [4, 5])]
TIERS = ["t1", "t2", "t3"]

# Trim rule (grade-blind): drop kills longer than TRIM_MULT x the (boss, group) MEDIAN duration. The
# median is robust to the tail it is being used to remove. TRIM_MULT=3.0 keeps genuinely slow raids —
# Ragnaros P1 spans 18s..82s, a 4.5x spread, all legitimate — while cutting the 131-261s outliers that
# sit alone on the last page.
TRIM_MULT = 3.0
SPLITS = (("train", 0.60), ("val", 0.20), ("test", 0.20))

C = dict(r="\x1b[0m", dim="\x1b[38;5;244m", gold="\x1b[38;5;178m", good="\x1b[38;5;71m",
         warn="\x1b[38;5;214m", bad="\x1b[38;5;203m", ink="\x1b[38;5;252m", bold="\x1b[1m")


def die(msg):
    sys.stderr.write("error: " + msg + "\n")
    sys.exit(1)


def load_key():
    k = os.environ.get("WCL_API_KEY")
    if k:
        return k
    try:
        for line in open(".env"):
            if line.startswith("WCL_API_KEY"):
                return line.split("=", 1)[1].strip().strip('"').strip("'")
    except FileNotFoundError:
        pass
    die("no API key — set WCL_API_KEY in .env or the environment")


KEY = None
CALLS = [0]


def get(path, **params):
    params["api_key"] = KEY
    url = "%s/%s?%s" % (BASE, path, urllib.parse.urlencode(params))
    CALLS[0] += 1
    for attempt in range(4):
        try:
            with urllib.request.urlopen(url, timeout=TIMEOUT) as r:
                return json.loads(r.read().decode("utf-8"))
        except urllib.error.HTTPError as e:
            if e.code in (429, 500, 502, 503):
                time.sleep(1.5 * (attempt + 1))
                continue
            return None
        except Exception:
            time.sleep(1.5 * (attempt + 1))
    return None


def enumerate_kills(enc, partition):
    """Every ranked kill for one (encounter, partition). Rows carry duration/startTime/comp for free."""
    out = {}
    for page in range(1, MAX_PAGE + 1):
        d = get("rankings/encounter/%s" % enc, metric="speed", page=page, partition=partition)
        rows = (d or {}).get("rankings", [])
        if not rows:
            break
        for r in rows:
            rid, fid = r.get("reportID"), r.get("fightID")
            dur = (r.get("duration") or 0) / 1000.0
            if rid and fid and dur > 0:
                out[(rid, fid)] = dict(
                    report=rid, fight=fid, dur=dur, start=r.get("startTime"),
                    partition=partition, guild=r.get("guildName"),
                    melee=r.get("melee"), ranged=r.get("ranged"), healers=r.get("healers"),
                    ilvl=r.get("itemLevel"),
                )
        if len(rows) < PAGE_ROWS:
            break
    return list(out.values())


def plan_boss(enc, name, per_boss):
    """Enumerate, trim, tier, and allocate — all before a single fight is pulled."""
    cells, excluded = {}, {"outlier": 0}
    for gname, parts in GROUPS:
        pool = []
        for p in parts:
            pool.extend(enumerate_kills(enc, p))
        if not pool:
            continue
        durs = sorted(k["dur"] for k in pool)
        med = durs[len(durs) // 2]
        keep = [k for k in pool if k["dur"] <= TRIM_MULT * med]
        excluded["outlier"] += len(pool) - len(keep)
        keep.sort(key=lambda k: k["dur"])
        # Terciles of the TRIMMED distribution -> t1 fastest, t3 slowest-but-real.
        n = len(keep)
        for i, k in enumerate(keep):
            k["tier"] = TIERS[min(2, (i * 3) // max(1, n))]
            k["group"] = gname
        for t in TIERS:
            cells[(gname, t)] = [k for k in keep if k["tier"] == t]
    if not cells:
        return None
    # Equal quota per cell; shortfalls redistribute to cells that still have supply.
    quota = max(1, per_boss // max(1, len(cells)))
    chosen, deficit = [], 0
    for key in sorted(cells):
        avail = cells[key]
        take = min(quota, len(avail))
        deficit += quota - take
        # Spread the take ACROSS the cell's duration range rather than taking its fastest — otherwise
        # every tier collapses toward its own fast edge and the tiers stop being distinct.
        if take and len(avail) > take:
            step = len(avail) / take
            chosen.extend(avail[int(i * step)] for i in range(take))
        else:
            chosen.extend(avail[:take])
    if deficit:
        picked = {(k["report"], k["fight"]) for k in chosen}
        spare = [k for key in sorted(cells) for k in cells[key]
                 if (k["report"], k["fight"]) not in picked]
        spare.sort(key=lambda k: k["dur"])
        if spare:
            step = max(1, len(spare) // max(1, deficit))
            chosen.extend(spare[::step][:deficit])
    # Deterministic split, stratified WITHIN each cell: walk each cell in duration order and deal
    # round-robin into train/val/test, so every split spans every cell and every duration range.
    by_cell = {}
    for k in chosen:
        by_cell.setdefault((k["group"], k["tier"]), []).append(k)
    pattern = (["train"] * 3) + ["val"] + ["test"]  # 3:1:1 = 60/20/20
    for key in sorted(by_cell):
        ks = sorted(by_cell[key], key=lambda k: k["dur"])
        for i, k in enumerate(ks):
            k["split"] = pattern[i % len(pattern)]
    return dict(enc=enc, name=name, chosen=chosen, cells={str(k): len(v) for k, v in cells.items()},
                excluded=excluded)


def fname(out, k, enc):
    # Encounter id stays the FIRST dash-token — five call sites glob on `<enc>-*.lua`.
    return "%s/%s/%d-%s%s-%s-%s.lua" % (out, k["split"], enc, k["group"][0], k["tier"],
                                        k["report"], k["fight"])


def main():
    global KEY
    argv = sys.argv[1:]
    if not argv:
        die("usage: wcl-spectrum.py [--raid mc | <encounterID>...] [--n N] [--out DIR] [--plan-only]")
    encs, per_boss, out, plan_only = [], 450, DEFAULT_OUT, False
    i = 0
    while i < len(argv):
        a = argv[i]
        if a == "--raid":
            if argv[i + 1] != "mc":
                die("only --raid mc is defined")
            encs = list(MC)
            i += 2
        elif a == "--n":
            per_boss = int(argv[i + 1]); i += 2
        elif a == "--out":
            out = argv[i + 1]; i += 2
        elif a == "--plan-only":
            plan_only = True; i += 1
        elif a.isdigit():
            encs.append(int(a)); i += 1
        else:
            die("unexpected argument: " + a)
    if not encs:
        die("no encounters given")
    KEY = load_key()

    print(f"\n{C['gold']}{C['bold']}🦡  MC SPECTRUM HARVEST — {len(encs)} bosses x ~{per_boss} kills{C['r']}")
    print(f"{C['dim']}3 phase groups x 3 trimmed-duration terciles · trim > {TRIM_MULT}x median "
          f"· split 60/20/20 stratified within every cell{C['r']}")
    print(C["dim"] + "─" * 104 + C["r"])

    plans, jobs = [], []
    for enc in encs:
        name = MC.get(enc, str(enc))
        p = plan_boss(enc, name, per_boss)
        if not p:
            print(f"  {C['bad']}{name:<20} no ranked kills{C['r']}")
            continue
        plans.append(p)
        sp = {s: sum(1 for k in p["chosen"] if k["split"] == s) for s, _ in SPLITS}
        durs = sorted(k["dur"] for k in p["chosen"])
        print(f"  {C['ink']}{name:<20}{C['r']} {len(p['chosen']):>4} kills  "
              f"{C['dim']}train{C['r']}{sp['train']:>4} {C['dim']}val{C['r']}{sp['val']:>4} "
              f"{C['dim']}test{C['r']}{sp['test']:>4}  "
              f"{C['dim']}{durs[0]:.0f}-{durs[-1]:.0f}s  trimmed {p['excluded']['outlier']}{C['r']}")
        for k in p["chosen"]:
            jobs.append((enc, k, fname(out, k, enc)))

    print(C["dim"] + "─" * 104 + C["r"])
    print(f"  {C['bold']}{len(jobs)} fights{C['r']} · {CALLS[0]} enumeration calls")
    if plan_only:
        print(f"\n{C['warn']}--plan-only: nothing pulled{C['r']}\n")
        return

    for s, _ in SPLITS:
        os.makedirs(os.path.join(out, s), exist_ok=True)
    todo = [j for j in jobs if not os.path.exists(j[2])]
    print(f"  {len(jobs) - len(todo)} already on disk · pulling {C['gold']}{len(todo)}{C['r']}\n")

    t0, done, failed = time.time(), [0], []

    def pull(job):
        enc, k, path = job
        r = subprocess.run(
            [sys.executable, "tools/wcl-v1-to-fight.py", k["report"], str(k["fight"]), "--out", path],
            capture_output=True, text=True)
        done[0] += 1
        if r.returncode != 0:
            failed.append((k["report"], k["fight"]))
        if done[0] % 50 == 0 or done[0] == len(todo):
            el = time.time() - t0
            rate = done[0] / el if el else 0
            eta = (len(todo) - done[0]) / rate if rate else 0
            print(f"    {C['dim']}{done[0]:>5}/{len(todo)}  {el:5.0f}s elapsed  "
                  f"~{eta:4.0f}s left  {len(failed)} failed{C['r']}", flush=True)
        return r.returncode == 0

    with ThreadPoolExecutor(max_workers=6) as ex:
        list(ex.map(pull, todo))

    manifest = [dict(enc=p["enc"], boss=p["name"], **k) for p in plans for k in p["chosen"]]
    with open(os.path.join(out, "manifest.json"), "w") as fh:
        json.dump(dict(trimMult=TRIM_MULT, groups=[g for g, _ in GROUPS], tiers=TIERS,
                       perBoss=per_boss, fights=manifest), fh, indent=1)

    print(f"\n  {C['good']}{len(todo) - len(failed)} pulled{C['r']}, {len(failed)} failed, "
          f"{time.time()-t0:.0f}s, {CALLS[0]} API calls")
    for s, _ in SPLITS:
        n = len(glob.glob(os.path.join(out, s, "*.lua")))
        print(f"    {C['dim']}{s:<6}{C['r']}{n:>6} fixtures")
    print(f"  manifest: {out}/manifest.json")
    print(f"\n{C['gold']}🦡 harvest complete{C['r']}\n")


if __name__ == "__main__":
    main()
