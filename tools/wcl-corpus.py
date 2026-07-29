#!/usr/bin/env python3
"""
wcl-corpus.py — harvest a CORPUS of real kills for one encounter into the ephemeral (gitignored) harvest
zone, so a learning session studies many fights across the performer spectrum, not one (WO-070 / D-013).

WCL V1 rankings return dozens of unique kills per encounter (fast→slow durations, varied specs / item
levels) — the performer spectrum. This dedupes them to (reportID, fightID), spreads the selection across
the duration range, and pulls each fight's EXACT curve by delegating to wcl-v1-to-fight.py (reuse, not
duplicate). Output lands in tools/fights/corpus/ — gitignored; empty it freely between sessions.

RUN (from the repo root; api key in .env, see wcl-v1-to-fight.py):
  python3 tools/wcl-corpus.py <encounterID> [--n N] [--metric speed|dps] [--out DIR]

  # Lucifron (MC) = encounterID 663
  python3 tools/wcl-corpus.py 663 --n 15

Then batch-grade the whole corpus:
  luajit tools/estimator-batch.lua

Stdlib only. Encounter IDs: WCL uses the classic encounter id (Lucifron 663, Magmadar 664, ...).
"""

import os
import sys
import json
import subprocess
import urllib.request
import urllib.parse
import urllib.error

BASE = "https://www.warcraftlogs.com/v1"
DEFAULT_OUT = "tools/fights/corpus"
TIMEOUT = 40


def die(msg):
    sys.stderr.write("error: " + msg + "\n")
    sys.exit(1)


def load_env(path=".env"):
    env = {}
    try:
        with open(path) as fh:
            for line in fh:
                line = line.strip()
                if line and not line.startswith("#") and "=" in line:
                    k, v = line.split("=", 1)
                    env[k.strip()] = v.strip().strip('"').strip("'")
    except FileNotFoundError:
        pass
    return env


def get(path, params):
    url = "%s/%s?%s" % (BASE, path, urllib.parse.urlencode(params))
    try:
        with urllib.request.urlopen(url, timeout=TIMEOUT) as r:
            d = json.loads(r.read().decode("utf-8"))
    except urllib.error.HTTPError as e:
        die("HTTP %s from /%s\n%s" % (e.code, path, e.read().decode("utf-8", "replace")[:400]))
    except urllib.error.URLError as e:
        die("network error: %s" % e.reason)
    if isinstance(d, dict) and d.get("error"):
        die("API error: %s" % d)
    return d


def main():
    argv = sys.argv[1:]
    if not argv:
        die("usage: wcl-corpus.py <encounterID> [--n N] [--metric speed|dps] [--out DIR] [--key KEY]")
    enc = None
    n, metric, out, key = 15, "speed", DEFAULT_OUT, None
    i = 0
    while i < len(argv):
        a = argv[i]
        if a == "--n":
            n = int(argv[i + 1]); i += 2
        elif a == "--metric":
            metric = argv[i + 1]; i += 2
        elif a == "--out":
            out = argv[i + 1]; i += 2
        elif a == "--key":
            key = argv[i + 1]; i += 2
        elif enc is None:
            enc = a; i += 1
        else:
            die("unexpected argument: " + a)
    if enc is None:
        die("missing <encounterID>")
    key = key or os.environ.get("WCL_API_KEY") or load_env().get("WCL_API_KEY")
    if not key:
        die("no API key — set WCL_API_KEY in .env, export it, or pass --key")

    # Gather unique (report, fight) kills across as many ranking pages as needed.
    fights = {}  # (reportID, fightID) -> { dur, start }
    page = 1
    while len(fights) < max(n * 6, 60) and page <= 8:
        d = get("rankings/encounter/%s" % enc, {"api_key": key, "metric": metric, "page": page})
        rk = d.get("rankings", [])
        if not rk:
            break
        for r in rk:
            rid, fid = r.get("reportID"), r.get("fightID")
            if rid and fid:
                fights[(rid, fid)] = {"dur": r.get("duration", 0) / 1000.0, "start": r.get("startTime", 0)}
        page += 1
    if not fights:
        die("no rankings for encounter %s (check the id / metric)" % enc)

    # WCL ARCHIVES old reports — their events 400 ("archived") and can't be pulled. The all-time speed
    # rankings are mostly old/archived, so attempt RECENT reports first (far likelier live) and skip
    # archived, keeping the first N that succeed. Recent kills still span a range of durations.
    cands = sorted(fights.items(), key=lambda kv: -kv[1]["start"])
    sys.stderr.write("encounter %s: %d unique kills in rankings; pulling recent-first until %d live\n"
                     % (enc, len(fights), n))

    os.makedirs(out, exist_ok=True)
    kept, archived, attempts = [], 0, 0
    cap = max(5 * n, 50)  # bound API calls even if archiving is heavy
    for (rid, fid), meta in cands:
        if len(kept) >= n or attempts >= cap:
            break
        attempts += 1
        outfile = "%s/%s-%s-%d.lua" % (out, enc, rid, fid)
        res = subprocess.run(
            [sys.executable, "tools/wcl-v1-to-fight.py", rid, str(fid), "--out", outfile],
            capture_output=True, text=True,
        )
        if res.returncode == 0:
            kept.append(meta["dur"])
            sys.stderr.write("  ok   %5.1fs  %s\n" % (meta["dur"], outfile))
        else:
            tail = (res.stderr.strip().splitlines() or ["?"])[-1]
            if "archived" in tail:
                archived += 1
            else:
                sys.stderr.write("  FAIL %5.1fs  %s#%s: %s\n" % (meta["dur"], rid, fid, tail))

    sys.stderr.write(
        "\nharvested %d fights into %s  (%d attempts, %d archived/skipped)\n"
        % (len(kept), out, attempts, archived)
    )
    if kept:
        sys.stderr.write("duration spread: %.1fs–%.1fs\n" % (min(kept), max(kept)))
    sys.stderr.write("batch-grade:  luajit tools/estimator-batch.lua %s\n" % out)


if __name__ == "__main__":
    main()
