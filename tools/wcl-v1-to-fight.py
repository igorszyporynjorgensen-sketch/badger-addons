#!/usr/bin/env python3
"""
wcl-v1-to-fight.py — pull a whole Warcraft Logs fight (via the V1 API key) into a fight file for the
estimator replay grader (tools/estimator-replay.lua). The V1 API is the simplest path: no OAuth, just an
api_key query param, and its damage events carry the target's EXACT hitPoints/maxHitPoints — so the boss
health curve is read directly, not reconstructed. It also lists every enemy, so we capture the ADDS
timeline (when each add dies) — the phase structure a per-encounter profile (D-013) needs.

API KEY (never committed): read from --key, else $WCL_API_KEY, else a .env at the repo root
(KEY=VALUE lines; .env is gitignored). Set it once in .env:  WCL_API_KEY=xxxx…

RUN (from the repo root):
  python3 tools/wcl-v1-to-fight.py <reportCode> <fightId> [--out FILE] [--key KEY]
  python3 tools/wcl-v1-to-fight.py DkGZwX9NgvAKJymr 41

Stdlib only (urllib). Then grade it:  luajit tools/estimator-replay.lua tools/fights/<slug>.lua
"""

import os
import sys
import json
import urllib.request
import urllib.error
import urllib.parse


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

BASE = "https://www.warcraftlogs.com/v1"
DT = 0.15
TIMEOUT = 40


def die(msg):
    sys.stderr.write("error: " + msg + "\n")
    sys.exit(1)


def get(path, params):
    url = "%s/%s?%s" % (BASE, path, urllib.parse.urlencode(params))
    try:
        with urllib.request.urlopen(url, timeout=TIMEOUT) as r:
            d = json.loads(r.read().decode("utf-8"))
    except urllib.error.HTTPError as e:
        die("HTTP %s from /%s\n%s" % (e.code, path, e.read().decode("utf-8", "replace")[:600]))
    except urllib.error.URLError as e:
        die("network error: %s" % e.reason)
    if isinstance(d, dict) and d.get("error"):
        die("API error: %s" % d)
    return d


def lua_str(s):
    return '"' + s.replace("\\", "\\\\").replace('"', '\\"') + '"'


def main():
    argv = sys.argv[1:]
    out = key = None
    pos = []
    i = 0
    while i < len(argv):
        a = argv[i]
        if a == "--out":
            out = argv[i + 1]
            i += 2
        elif a == "--key":
            key = argv[i + 1]
            i += 2
        else:
            pos.append(a)
            i += 1
    if len(pos) < 2:
        die("usage: wcl-v1-to-fight.py <reportCode> <fightId> [--out FILE] [--key KEY]")
    code, fid = pos[0], int(pos[1])
    key = key or os.environ.get("WCL_API_KEY") or load_env().get("WCL_API_KEY")
    if not key:
        die("no API key — set WCL_API_KEY in .env (gitignored), export it, or pass --key")

    rep = get("report/fights/%s" % code, {"api_key": key, "translate": "true"})
    fight = next((x for x in rep.get("fights", []) if x.get("id") == fid), None)
    if not fight:
        die("no fight #%d in report %s" % (fid, code))
    start, end = fight["start_time"], fight["end_time"]
    dur = (end - start) / 1000.0
    sys.stderr.write(
        "fight #%d  %s  %s %dp  zone=%s  %.1fs  encounterID=%s\n"
        % (fid, fight["name"], "KILL" if fight.get("kill") else "wipe", fight.get("size", 0),
           fight.get("zoneName"), dur, fight.get("boss"))
    )

    # enemies in this fight: the Boss + adds (other NPCs)
    boss_id, adds = None, {}
    for en in rep.get("enemies", []):
        if not any(i.get("id") == fid for i in en.get("fights", [])):
            continue
        if en.get("type") == "Boss" or en["name"] == fight["name"]:
            boss_id = en["id"]
            boss_name = en["name"]
        else:
            adds[en["id"]] = en["name"]
    if boss_id is None:
        die("could not identify the boss enemy in fight %d" % fid)
    watch = set([boss_id]) | set(adds)

    # page damage-done events across the fight; keep per-target (t, hp, maxhp)
    series = {tid: [] for tid in watch}
    cur = start
    pages = 0
    while cur is not None and cur < end:
        d = get("report/events/damage-done/%s" % code, {"api_key": key, "start": cur, "end": end})
        for e in d.get("events", []):
            tid = e.get("targetID")
            if tid in watch and e.get("hitPoints") is not None and e.get("maxHitPoints"):
                series[tid].append(((e["timestamp"] - start) / 1000.0, e["hitPoints"], e["maxHitPoints"]))
        pages += 1
        cur = d.get("nextPageTimestamp")

    boss = sorted(series[boss_id])
    if not boss:
        die("no damage-with-hitPoints events on the boss (id %d)" % boss_id)
    maxhp = boss[-1][2]
    death = boss[-1][0]
    sys.stderr.write("boss %r id=%d  maxHP=%d  %d samples over %d pages\n"
                     % (boss_name, boss_id, maxhp, len(boss), pages))

    # adds timeline: when did each add stop taking damage (≈ death)?
    timeline = []
    for tid, name in adds.items():
        pts = sorted(series[tid])
        if pts:
            timeline.append((pts[-1][0], name, pts[-1][1]))
    timeline.sort()
    for t, name, hp in timeline:
        sys.stderr.write("  add down ~%.1fs: %s (last hp=%d)\n" % (t, name, hp))

    # boss health fraction, resampled to DT with a stepwise hold
    obs = [(0.0, 1.0)] + [(t, max(0.0, hp / mx)) for t, hp, mx in boss]
    obs.sort()
    samples = []
    j, cur_h, st = 0, 1.0, 0.0
    while st <= death + 1e-9:
        while j < len(obs) and obs[j][0] <= st:
            cur_h = obs[j][1]
            j += 1
        samples.append((st, cur_h))
        st += DT
    samples.append((round(death, 2), 0.0))

    lines = [
        "-- Auto-generated by tools/wcl-v1-to-fight.py — do not edit by hand.",
        "-- %s, %s fight %d (%s %dp): exact boss health fraction over time (WCL V1 hitPoints)."
        % (fight.get("zoneName"), code, fid, fight["name"], fight.get("size", 0)),
    ]
    for t, name, _hp in timeline:
        lines.append("-- timeline: add down ~%.1fs — %s" % (t, name))
    lines += ["", "return {", "    name = %s," % lua_str("%s — %s#%d" % (fight["name"], code, fid)),
              "    encounterID = %s," % (fight.get("boss") or "nil"), "    samples = {"]
    for t, h in samples:
        lines.append("        { t = %.2f, h = %.4f }," % (t, h))
    lines += ["    },", "}", ""]

    if not out:
        slug = "".join(c.lower() if c.isalnum() else "-" for c in fight["name"]).strip("-")
        out = "tools/fights/%s.lua" % slug
    with open(out, "w") as fh:
        fh.write("\n".join(lines))
    sys.stderr.write("\nwrote %s  (%d samples, death=%.1fs)\n" % (out, len(samples), death))
    sys.stderr.write("grade it:  luajit tools/estimator-replay.lua %s\n" % out)


if __name__ == "__main__":
    main()
