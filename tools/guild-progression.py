#!/usr/bin/env python3
"""
guild-progression.py — pull ONE guild's raid nights in chronological order (WO-078 follow-up).

Every other corpus tool samples ACROSS guilds: a spread of strangers, one kill each. That answers "how do
raids in general kill this boss". It cannot answer the question that actually matters to a player —
"how well can the addon predict MY raid, given it has watched MY raid before" — because the addon's history
prior (D-012, `history.lua`) keys on the encounter and accumulates kill by kill over a career.

A guild raiding weekly is the closest available proxy for one player's history: broadly the same roster,
gear and strategy from week to week. Pulling their nights in order lets the estimator be replayed the way
it is actually lived — walk-forward, where kill N is predicted using only kills 1..N-1 as the prior.

  python3 tools/guild-progression.py "<guild>" "<server>" <region> [--out DIR] [--max-nights N]

Writes <out>/<enc>-<report>-<fight>.lua plus <out>/progression.json (the chronological index the
simulator walks). Stdlib only; read-only against the repo.
"""
import os
import sys
import json
import time
import urllib.request
import urllib.parse
import subprocess
import datetime

BASE = "https://www.warcraftlogs.com/v1"
MC = {150663: "Lucifron", 150664: "Magmadar", 150665: "Gehennas", 150666: "Garr",
      150667: "Shazzrah", 150668: "Baron Geddon", 150669: "Sulfuron Harbinger",
      150670: "Golemagg", 150671: "Majordomo", 150672: "Ragnaros"}

C = dict(r="\x1b[0m", dim="\x1b[38;5;244m", gold="\x1b[38;5;178m", good="\x1b[38;5;71m",
         warn="\x1b[38;5;214m", bad="\x1b[38;5;203m", ink="\x1b[38;5;252m", bold="\x1b[1m")

KEY = None
CALLS = [0]


def get(path, **q):
    q["api_key"] = KEY
    url = "%s/%s?%s" % (BASE, path, urllib.parse.urlencode(q))
    CALLS[0] += 1
    for a in range(3):
        try:
            with urllib.request.urlopen(url, timeout=60) as r:
                return json.loads(r.read().decode())
        except Exception as e:
            if any(s in str(e) for s in ("429", "500", "502", "timed out")):
                time.sleep(2 + 2 * a)
                continue
            return None
    return None


def main():
    global KEY
    a = sys.argv[1:]
    if len(a) < 3:
        sys.exit('usage: guild-progression.py "<guild>" "<server>" <region> [--out DIR] [--max-nights N]')
    guild, server, region = a[0], a[1], a[2]
    out = a[a.index("--out") + 1] if "--out" in a else "tools/fights/guild"
    maxn = int(a[a.index("--max-nights") + 1]) if "--max-nights" in a else 12
    KEY = os.environ.get("WCL_API_KEY") or next(
        (l.split("=", 1)[1].strip() for l in open(".env") if l.startswith("WCL_API_KEY")), None)
    if not KEY:
        sys.exit("no WCL_API_KEY")

    print(f"\n{C['gold']}{C['bold']}🦡  GUILD PROGRESSION — {guild} ({server}-{region}){C['r']}")
    print(f"{C['dim']}their raid nights in order, so the estimator can be replayed walk-forward{C['r']}")
    print(C["dim"] + "─" * 84 + C["r"])

    # Reports the rankings know about for this guild (the guild endpoint 400s on names with spaces).
    reports = {}
    for enc in MC:
        for part in (3, 4, 5):
            for page in (1, 2, 3):
                d = get("rankings/encounter/%s" % enc, metric="speed", page=page, partition=part)
                for r in (d or {}).get("rankings", []):
                    if r.get("guildName") == guild and r.get("serverName") == server:
                        reports[r["reportID"]] = r.get("startTime", 0)
    if not reports:
        sys.exit(f"no reports found for {guild} ({server}-{region})")
    nights = sorted(reports.items(), key=lambda kv: kv[1])[:maxn]
    print(f"  {len(reports)} nights found, using {len(nights)}\n")

    os.makedirs(out, exist_ok=True)
    prog, pulled = [], 0
    for code, _ in nights:
        rep = get("report/fights/%s" % code, translate="true")
        if not rep:
            continue
        kills = [f for f in rep.get("fights", [])
                 if f.get("kill") and f.get("boss") in MC and f.get("size", 0) >= 20]
        kills.sort(key=lambda f: f["start_time"])
        night = datetime.datetime.fromtimestamp(
            rep.get("start", 0) / 1000, datetime.UTC).strftime("%Y-%m-%d")
        print(f"  {C['ink']}{night}{C['r']}  {code}  {len(kills)} MC kills")
        for f in kills:
            path = "%s/%d-%s-%d.lua" % (out, f["boss"], code, f["id"])
            if not os.path.exists(path):
                p = subprocess.run(
                    [sys.executable, "tools/wcl-v1-to-fight.py", code, str(f["id"]), "--out", path],
                    capture_output=True, text=True)
                if p.returncode != 0:
                    continue
                pulled += 1
                time.sleep(2.0)  # ~5 fights/min, the measured 800-calls/hour budget
            prog.append(dict(enc=f["boss"], boss=MC[f["boss"]], report=code, fight=f["id"],
                             night=night, start=f["start_time"] + rep.get("start", 0),
                             dur=(f["end_time"] - f["start_time"]) / 1000.0,
                             size=f.get("size"), path=path))
    prog.sort(key=lambda x: (x["night"], x["start"]))
    json.dump(dict(guild=guild, server=server, region=region, fights=prog),
              open(os.path.join(out, "progression.json"), "w"), indent=1)

    print(C["dim"] + "─" * 84 + C["r"])
    seen = {}
    for x in prog:
        seen[x["enc"]] = seen.get(x["enc"], 0) + 1
    repeats = sum(1 for v in seen.values() if v > 1)
    print(f"  {C['good']}{len(prog)} kills{C['r']} over {len({x['night'] for x in prog})} nights "
          f"· {len(seen)} distinct bosses · {C['bold']}{repeats}{C['r']} bosses killed more than once")
    print(f"  {C['dim']}{pulled} newly pulled · {CALLS[0]} API calls · index: {out}/progression.json{C['r']}")
    print(f"\n{C['gold']}🦡 ready — replay it with tools/ttk-career.lua{C['r']}\n")


if __name__ == "__main__":
    main()
