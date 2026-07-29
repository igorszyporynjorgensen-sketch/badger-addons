#!/usr/bin/env python3
"""
ttk-lab — the client-run estimator learning session, with a live terminal dashboard (WO-071).

The human runs a session in their own terminal, watches the raid-meter-style display update in real
time, and when it finishes tells the AI — which reads the run summary + corpus and refreshes the web
Estimator Lab. Learning stays entirely client-side (never git/CI).

USAGE (from the repo root; WCL key in .env for hunt):
  python3 tools/ttk-lab.py hunt 150664 150665 ... [--n 6]   # pull kills AND grade each as it lands
  python3 tools/ttk-lab.py grade                            # re-grade the whole corpus (estimator loop)
  python3 tools/ttk-lab.py grade --est path/to/estimator.lua  # grade a candidate estimator (WO-069)

  --n N       kills per encounter for hunt (default 6)
  --corpus D  harvest zone (default tools/fights/corpus)
  --plain     force plain line output (auto when stdout is not a TTY)

Ends by writing  <corpus>/_run-summary.json  (inside the gitignored zone) — per-fight rows + aggregates —
and printing its path: that's the handoff. Stdlib only; grading runs luajit/lua on estimator-batch.lua's
single-file mode.
"""

import os
import sys
import json
import time
import glob
import shutil
import datetime
import subprocess
import importlib.util

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
os.chdir(ROOT)

# Reuse the WO-070 harvester's API helpers (module name has a hyphen, so load by path).
_spec = importlib.util.spec_from_file_location("wclcorpus", os.path.join(ROOT, "tools", "wcl-corpus.py"))
_wcl = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(_wcl)

LUA = shutil.which("luajit") or shutil.which("lua") or "luajit"
SPIN = "⠋⠙⠹⠸⠼⠴⠦⠧⠇⠏"
BLOCKS = "▏▎▍▌▋▊▉█"

C = dict(reset="\x1b[0m", dim="\x1b[38;5;244m", faint="\x1b[38;5;238m", gold="\x1b[38;5;178m",
         good="\x1b[38;5;71m", warn="\x1b[38;5;214m", bad="\x1b[38;5;203m", ink="\x1b[38;5;252m")


def sev(mape):
    return "good" if mape < 0.20 else ("warn" if mape < 0.40 else "bad")


def bar(frac, width):
    frac = max(0.0, min(1.0, frac))
    whole = int(frac * width)
    rem = frac * width - whole
    out = "█" * whole
    if whole < width and rem > 1 / 8:
        out += BLOCKS[int(rem * 8) - 1]
    return out.ljust(width)


def grade_one(path, est=None):
    """Grade one fight via estimator-batch.lua single-file mode → dict (mape None = never confident)."""
    cmd = [LUA, "tools/estimator-batch.lua", path] + ([est] if est else [])
    res = subprocess.run(cmd, capture_output=True, text=True)
    for line in res.stdout.splitlines():
        if line.startswith("RESULT\t"):
            _, name, dur, mape, bias, within, shown = line.split("\t")
            return dict(file=os.path.basename(path), name=name, dur=float(dur),
                        mape=None if mape == "NC" else float(mape),
                        bias=float(bias), within=float(within), shown=float(shown))
    return None


class Dash:
    """Raid-meter terminal display. Live in-place repaint on a TTY; plain event lines otherwise."""

    def __init__(self, mode, live):
        self.mode, self.live = mode, live
        self.encs = {}   # enc id → {boss, target, fights[], nc, status}
        self.order = []
        self.t0 = time.time()
        self.tick = 0
        self.note = ""
        if self.live:
            sys.stdout.write("\x1b[?25l\x1b[2J\x1b[H")

    def add_enc(self, enc, target):
        if enc not in self.encs:
            self.encs[enc] = dict(boss=str(enc), target=target, fights=[], nc=0, status="")
            self.order.append(enc)

    def record(self, enc, fight):
        e = self.encs[enc]
        if fight["mape"] is None:
            e["nc"] += 1
        else:
            e["fights"].append(fight)
        if " — " in fight["name"]:
            e["boss"] = fight["name"].split(" — ")[0]
        if not self.live:
            n = sum(len(x["fights"]) + x["nc"] for x in self.encs.values())
            m = "hidden (never confident)" if fight["mape"] is None else \
                f"MAPE {fight['mape']:6.1%}  bias {fight['bias']:+5.1f}s"
            agg = self.aggregate()
            tail = f"  ·  agg mean {agg['mape_mean']:.1%}" if agg else ""
            print(f"[{n:3d}] {e['boss']:<24.24s} {fight['dur']:6.1f}s  {m}{tail}")

    def aggregate(self):
        mapes = [f["mape"] for e in self.encs.values() for f in e["fights"]]
        if not mapes:
            return None
        s = sorted(mapes)
        alln = [f for e in self.encs.values() for f in e["fights"]]
        return dict(
            fights=len(mapes), nc=sum(e["nc"] for e in self.encs.values()),
            mape_mean=sum(mapes) / len(mapes), mape_median=s[len(s) // 2],
            mape_p90=s[max(0, min(len(s) - 1, round(0.9 * len(s)) - 1))],
            bias_s=sum(f["bias"] for f in alln) / len(alln),
            within15=sum(f["within"] for f in alln) / len(alln),
            shown=sum(f["shown"] for f in alln) / len(alln),
        )

    def render(self, note=None):
        if note is not None:
            self.note = note
        if not self.live:
            return
        self.tick += 1
        el = int(time.time() - self.t0)
        lines = []
        head = f" 🦡 {C['gold']}BADGER TTK · ESTIMATOR LAB{C['reset']}"
        right = f"{self.mode} · {el // 60:02d}:{el % 60:02d} {C['gold']}{SPIN[self.tick % len(SPIN)]}{C['reset']}"
        lines.append(head + " " * max(1, 74 - 26 - len(self.mode) - 9) + right)
        lines.append(C["faint"] + "─" * 78 + C["reset"])
        for enc in self.order:
            e = self.encs[enc]
            done = len(e["fights"]) + e["nc"]
            if e["fights"]:
                mu = sum(f["mape"] for f in e["fights"]) / len(e["fights"])
                bi = sum(f["bias"] for f in e["fights"]) / len(e["fights"])
                durs = [f["dur"] for f in e["fights"]]
                col = C[sev(mu)]
                meter = col + bar(mu / 1.5, 22) + C["reset"]
                stats = (f"{col}{mu:7.1%}{C['reset']} {C['dim']}{bi:+5.1f}s "
                         f"{min(durs):3.0f}–{max(durs):3.0f}s{C['reset']}")
            else:
                meter = C["faint"] + bar(0, 22) + C["reset"]
                stats = C["faint"] + ("  hidden ×%d" % e["nc"] if e["nc"] else "  …") + C["reset"]
            ncmark = f" {C['faint']}(+{e['nc']} hid){C['reset']}" if e["nc"] and e["fights"] else ""
            lines.append(f" {C['ink']}{e['boss']:<20.20s}{C['reset']} {meter} "
                         f"{C['dim']}{done}/{e['target']}{C['reset']} {stats}{ncmark}")
        lines.append(C["faint"] + "─" * 78 + C["reset"])
        agg = self.aggregate()
        if agg:
            col = C[sev(agg["mape_mean"])]
            lines.append(f" {C['ink']}{agg['fights']} graded{C['reset']}{C['dim']} · {agg['nc']} hidden · "
                         f"mean {C['reset']}{col}{agg['mape_mean']:.1%}{C['reset']}{C['dim']} · "
                         f"median {agg['mape_median']:.1%} · p90 {agg['mape_p90']:.1%} · "
                         f"bias {agg['bias_s']:+.1f}s · shown {agg['shown']:.0%}{C['reset']}")
        else:
            lines.append(C["faint"] + " warming up…" + C["reset"])
        lines.append(f" {C['dim']}{self.note}{C['reset']}")
        sys.stdout.write("\x1b[H" + "".join(l + "\x1b[K\n" for l in lines) + "\x1b[J")
        sys.stdout.flush()

    def close(self):
        if self.live:
            sys.stdout.write("\x1b[?25h")
            sys.stdout.flush()


def write_summary(dash, corpus, est):
    agg = dash.aggregate()
    out = dict(
        mode=dash.mode,
        when=datetime.datetime.now().isoformat(timespec="seconds"),
        estimator=est or "projects/badger-ttk/src/engine/estimator.lua",
        corpus=corpus,
        aggregate=agg,
        encounters={
            str(enc): dict(
                boss=e["boss"], graded=len(e["fights"]), hidden=e["nc"],
                mape_mean=(sum(f["mape"] for f in e["fights"]) / len(e["fights"])) if e["fights"] else None,
                bias_mean=(sum(f["bias"] for f in e["fights"]) / len(e["fights"])) if e["fights"] else None,
            ) for enc, e in dash.encs.items()
        },
        fights=[f for e in dash.encs.values() for f in e["fights"]] +
               [dict(file="?", name=e["boss"], mape=None) for e in dash.encs.values() for _ in range(e["nc"])],
    )
    path = os.path.join(corpus, "_run-summary.json")
    with open(path, "w") as fh:
        json.dump(out, fh, indent=2)
    return path, agg


def cmd_grade(corpus, est, live):
    files = sorted(f for f in glob.glob(os.path.join(corpus, "*.lua")))
    if not files:
        sys.exit(f"no fixtures in {corpus} — hunt first:  python3 tools/ttk-lab.py hunt <encounterID...>")
    dash = Dash("grade", live)
    groups = {}
    for f in files:
        enc = os.path.basename(f).split("-")[0]
        groups.setdefault(enc, []).append(f)
    for enc, fl in groups.items():
        dash.add_enc(enc, len(fl))
    try:
        dash.render("grading corpus…")
        for enc, fl in groups.items():
            for f in fl:
                r = grade_one(f, est)
                if r:
                    dash.record(enc, r)
                dash.render(f"grading {os.path.basename(f)}")
        return finish(dash, corpus, est)
    finally:
        dash.close()


def cmd_hunt(encs, n, corpus, est, live):
    key = os.environ.get("WCL_API_KEY") or _wcl.load_env().get("WCL_API_KEY")
    if not key:
        sys.exit("no API key — set WCL_API_KEY in .env (gitignored)")
    os.makedirs(corpus, exist_ok=True)
    dash = Dash("hunt", live)
    for enc in encs:
        dash.add_enc(enc, n)
    try:
        for enc in encs:
            dash.render(f"rankings for {enc}…")
            fights, page = {}, 1
            while len(fights) < max(n * 6, 60) and page <= 8:
                d = _wcl.get("rankings/encounter/%s" % enc, {"api_key": key, "metric": "speed", "page": page})
                rk = d.get("rankings", [])
                if not rk:
                    break
                for r in rk:
                    if r.get("reportID") and r.get("fightID"):
                        fights[(r["reportID"], r["fightID"])] = r.get("startTime", 0)
                page += 1
            cands = sorted(fights.items(), key=lambda kv: -kv[1])
            got, tried, skipped = 0, 0, 0
            for (rid, fid), _ in cands:
                if got >= n or tried >= max(5 * n, 40):
                    break
                outfile = os.path.join(corpus, "%s-%s-%d.lua" % (enc, rid, fid))
                if not os.path.exists(outfile):
                    tried += 1
                    dash.render(f"{dash.encs[enc]['boss']}: pulling {rid}#{fid}  ({skipped} archived skipped)")
                    res = subprocess.run([sys.executable, "tools/wcl-v1-to-fight.py", rid, str(fid),
                                          "--out", outfile], capture_output=True, text=True)
                    if res.returncode != 0:
                        skipped += 1
                        continue
                got += 1
                r = grade_one(outfile, est)
                if r:
                    dash.record(enc, r)
                dash.render(f"{dash.encs[enc]['boss']}: {got}/{n}")
        return finish(dash, corpus, est)
    finally:
        dash.close()


def finish(dash, corpus, est):
    path, agg = write_summary(dash, corpus, est)
    dash.render("done")
    if dash.live:
        print()
    if agg:
        print(f"🦡 done — {agg['fights']} graded, {agg['nc']} hidden · mean MAPE {agg['mape_mean']:.1%} · "
              f"median {agg['mape_median']:.1%} · bias {agg['bias_s']:+.1f}s")
    print(f"   summary: {path}   ← tell Claude it's ready and the web dashboard gets refreshed")


def main():
    args = sys.argv[1:]
    if not args or args[0] in ("-h", "--help"):
        print(__doc__)
        return
    mode = args.pop(0)
    n, corpus, est, plain, encs = 6, os.path.join("tools", "fights", "corpus"), None, False, []
    i = 0
    while i < len(args):
        a = args[i]
        if a == "--n":
            n = int(args[i + 1]); i += 2
        elif a == "--corpus":
            corpus = args[i + 1]; i += 2
        elif a == "--est":
            est = args[i + 1]; i += 2
        elif a == "--plain":
            plain = True; i += 1
        else:
            encs.append(a); i += 1
    live = sys.stdout.isatty() and not plain
    if mode == "grade":
        cmd_grade(corpus, est, live)
    elif mode == "hunt":
        if not encs:
            sys.exit("hunt needs encounter ids, e.g.:  python3 tools/ttk-lab.py hunt 150664 150665 --n 6")
        cmd_hunt(encs, n, corpus, est, live)
    else:
        sys.exit(f"unknown mode {mode!r} — use hunt or grade")


if __name__ == "__main__":
    main()
