#!/usr/bin/env python3
"""
wcl-to-fight.py — turn a Warcraft Logs fight into a fight file for the estimator
replay grader (tools/estimator-replay.lua). This is "piece 2" of the dev-mode loop.

The WoW addon sandbox cannot fetch a URL, and Warcraft Logs blocks direct page
scraping (HTTP 403). So this companion tool runs OUTSIDE the game, on your machine,
against your own free WCL API v2 client, and reconstructs the boss's *health curve*
from the fight's damage events — the one thing the estimator actually consumes.

SETUP (once, free — ~2 minutes):
  1. Go to  https://www.warcraftlogs.com/api/clients/
  2. "Create Client": any name; Redirect URL can be  http://localhost .
  3. Copy the Client ID and Client Secret it gives you.

RUN (from the repo root):
  python3 tools/wcl-to-fight.py <clientId> <clientSecret> <reportCode> <fightId> [outfile.lua]

  For  fresh.warcraftlogs.com/reports/DkGZwX9NgvAKJymr?fight=41  that's:
  python3 tools/wcl-to-fight.py  YOUR_ID  YOUR_SECRET  DkGZwX9NgvAKJymr  41

Then grade it:
  luajit tools/estimator-replay.lua tools/fights/<generated>.lua

Stdlib only (urllib) — nothing to pip-install. Your credentials come from argv and
are never written anywhere. Fresh/Classic and Retail reports use the same endpoint.
"""

import sys
import json
import base64
import urllib.request
import urllib.error
import urllib.parse

API = "https://www.warcraftlogs.com/api/v2/client"
OAUTH = "https://www.warcraftlogs.com/oauth/token"
DT = 0.15  # resample cadence — matches the live driver (src/live/driver.lua INTERVAL)
TIMEOUT = 30


def die(msg):
    sys.stderr.write("error: " + msg + "\n")
    sys.exit(1)


def post(url, data, headers):
    req = urllib.request.Request(url, data=data, headers=headers, method="POST")
    try:
        with urllib.request.urlopen(req, timeout=TIMEOUT) as r:
            return json.loads(r.read().decode("utf-8"))
    except urllib.error.HTTPError as e:
        body = e.read().decode("utf-8", "replace")
        die("HTTP %s from %s\n%s" % (e.code, url, body[:1000]))
    except urllib.error.URLError as e:
        die("network error reaching %s: %s" % (url, e.reason))


def get_token(cid, secret):
    basic = base64.b64encode(("%s:%s" % (cid, secret)).encode()).decode()
    body = urllib.parse.urlencode({"grant_type": "client_credentials"}).encode()
    res = post(
        OAUTH,
        body,
        {"Authorization": "Basic " + basic, "Content-Type": "application/x-www-form-urlencoded"},
    )
    if "access_token" not in res:
        die("no access_token in OAuth response: " + json.dumps(res))
    return res["access_token"]


def gql(tok, query, variables):
    body = json.dumps({"query": query, "variables": variables}).encode()
    res = post(API, body, {"Authorization": "Bearer " + tok, "Content-Type": "application/json"})
    if "errors" in res:
        die("GraphQL errors: " + json.dumps(res["errors"], indent=2))
    return res["data"]


META = """
query($code:String!,$fid:Int!){
  reportData{ report(code:$code){
    startTime
    fights(fightIDs:[$fid]){ id name startTime endTime kill encounterID size difficulty }
    masterData{ actors(type:"NPC"){ id name gameID } }
  }}
}"""

EVENTS = """
query($code:String!,$fid:Int!,$start:Float!,$end:Float!,$target:Int!){
  reportData{ report(code:$code){
    events(fightIDs:[$fid], startTime:$start, endTime:$end,
           dataType:DamageDone, hostilityType:Friendlies, targetID:$target, limit:10000){
      data nextPageTimestamp
    }
  }}
}"""


def lua_str(s):
    return '"' + s.replace("\\", "\\\\").replace('"', '\\"') + '"'


def main():
    if len(sys.argv) < 5:
        die("usage: wcl-to-fight.py <clientId> <clientSecret> <reportCode> <fightId> [outfile.lua]")
    cid, secret, code, fid = sys.argv[1], sys.argv[2], sys.argv[3], int(sys.argv[4])
    out = sys.argv[5] if len(sys.argv) > 5 else None

    tok = get_token(cid, secret)
    rep = gql(tok, META, {"code": code, "fid": fid})["reportData"]["report"]

    fights = rep["fights"]
    if not fights:
        die("no fight #%d in report %s" % (fid, code))
    f = fights[0]
    dur = (f["endTime"] - f["startTime"]) / 1000.0
    sys.stderr.write(
        "fight #%d  %r  %s  %.1fs  size=%s  %s\n"
        % (
            fid,
            f["name"],
            "KILL" if f["kill"] else "wipe",
            dur,
            f.get("size"),
            ("encounterID=%s" % f["encounterID"]) if f.get("encounterID") else "trash/no-encounter",
        )
    )

    # Resolve the boss actor by matching the encounter name (adds like "Flamewaker
    # Protector" have different names, so we only reconstruct the boss's own curve).
    actors = rep["masterData"]["actors"]
    boss = next((a for a in actors if a["name"] == f["name"]), None)
    if not boss:
        names = ", ".join(sorted({a["name"] for a in actors}))
        die("no NPC actor named %r in the report; NPCs present: %s" % (f["name"], names))
    sys.stderr.write("boss actor id=%d (%s)\n" % (boss["id"], boss["name"]))

    # Page every friendly-source damage event on the boss.
    raw = []  # (timestamp_ms, amount, hitPoints, maxHitPoints)
    start = f["startTime"]
    while True:
        d = gql(
            tok,
            EVENTS,
            {"code": code, "fid": fid, "start": start, "end": f["endTime"], "target": boss["id"]},
        )
        ev = d["reportData"]["report"]["events"]
        for e in ev["data"]:
            raw.append((e["timestamp"], e.get("amount", 0), e.get("hitPoints"), e.get("maxHitPoints")))
        nxt = ev.get("nextPageTimestamp")
        if not nxt:
            break
        start = nxt
    if not raw:
        die("no damage events on the boss — check the fight/target, or advanced logging was off")

    raw.sort(key=lambda x: x[0])

    # Prefer the per-event remaining HP (advanced logging); else reconstruct the
    # curve from cumulative damage (health(t) = 1 - dealt(t)/total). Both land as
    # (fight-relative seconds, health fraction) observations.
    obs = []
    have_hp = all(r[2] is not None and r[3] for r in raw)
    if have_hp:
        for ts, _amt, hp, mhp in raw:
            obs.append(((ts - f["startTime"]) / 1000.0, max(0.0, min(1.0, hp / mhp))))
        sys.stderr.write("health from per-event hitPoints (%d events)\n" % len(raw))
    else:
        total = sum(r[1] for r in raw) or 1
        cum = 0.0
        for ts, amt, _hp, _mhp in raw:
            cum += amt
            obs.append(((ts - f["startTime"]) / 1000.0, max(0.0, 1.0 - cum / total)))
        sys.stderr.write("health reconstructed from cumulative damage (%d events, total=%d)\n" % (len(raw), total))

    # Resample to DT with a stepwise hold (health stays at its last observed value
    # between events) — exactly how the live driver polls UnitHealth every INTERVAL.
    obs.sort()
    samples = []
    j, cur, st = 0, 1.0, 0.0
    while st <= dur + 1e-9:
        while j < len(obs) and obs[j][0] <= st:
            cur = obs[j][1]
            j += 1
        samples.append((st, cur))
        st += DT
    samples.append((round(dur, 2), 0.0))

    name = "%s — %s#%d" % (f["name"], code, fid)
    lines = [
        "-- Auto-generated by tools/wcl-to-fight.py — do not edit by hand.",
        "-- Warcraft Logs report %s, fight %d (%s): the boss's health fraction over time." % (code, fid, f["name"]),
        "",
        "return {",
        "    name = %s," % lua_str(name),
        "    samples = {",
    ]
    for t, h in samples:
        lines.append("        { t = %.2f, h = %.4f }," % (t, h))
    lines += ["    },", "}", ""]
    text = "\n".join(lines)

    if not out:
        slug = "".join(c.lower() if c.isalnum() else "-" for c in f["name"]).strip("-")
        out = "tools/fights/%s-%s.lua" % (slug, code.lower())
    with open(out, "w") as fh:
        fh.write(text)
    sys.stderr.write("wrote %s  (%d samples, death=%.1fs)\n" % (out, len(samples), dur))
    sys.stderr.write("grade it:  luajit tools/estimator-replay.lua %s\n" % out)


if __name__ == "__main__":
    main()
