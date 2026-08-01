#!/usr/bin/env python3
"""
assemble-regimes.py — build src/raids/regimes.lua from the learned candidates + the hand-authored facts.

Deterministic and idempotent: it reads every tools/candidates/regime-<enc>.lua the lab has learned
(numeric fields — confCap, freeze bands, resetOnRise), merges the CATEGORICAL facts below (domain
knowledge no statistic can derive — hideBar, suppressFlush, and the reserved CLEU slots), folds the
universal raid floor into every profile by element-wise min, and emits the shipped table.

  python3 tools/assemble-regimes.py [--out projects/badger-ttk/src/raids/regimes.lua] [--dry-run]

Candidates are keyed by the WCL **Fresh** encounter id (the corpus fixtures carry those); the shipped
table keys the **classic** DungeonEncounterID and aliases +150000 at load, exactly like rhythms.lua.
Never hand-edit the emitted file — change a fact here or re-learn, then re-run. Stdlib only.
"""

import re
import sys
import glob

OUT = sys.argv[sys.argv.index("--out") + 1] if "--out" in sys.argv else "projects/badger-ttk/src/raids/regimes.lua"
DRY = "--dry-run" in sys.argv
BINS = 20
FRESH_OFFSET = 150000
SHOW_THRESHOLD = 0.5  # the client's default minConfidenceToShow — below this the bar stays hidden

# The universal raid gate — folded into every profile and returned for un-profiled boss-level targets.
DEFAULT_CONFCAP = {20: 0.0, 19: 0.10}

# ── CATEGORICAL FACTS (hand-authored — domain truths, not statistics) ───────────────────────────────
# Keyed by CLASSIC DungeonEncounterID. Learned numeric fields are merged in from the candidates.
FACTS = {
    671: {
        "name": "Majordomo Executus",
        "note": "the encounter ends by killing his four Flamewaker adds, not him; his own health is pure\n    -- noise. A CLEU add-counter that makes him estimable is a deferred future WO (design §5).",
        "hideBar": True,
    },
    721: {
        "name": "Buru the Gorger",
        "note": "scripted egg-phase chunk damage fires the two-cliff regime flush on a MECHANIC rather\n    -- than a real kill-speed change, discarding a sound prior — suppress the flush, keep folding evidence.",
        "suppressFlush": True,
    },
    669: {
        "name": "Sulfuron Harbinger",
        "note": "his healers pollute the curve (heals only flatten a monotonic slope, so they are invisible\n    -- to health polling). Cap confidence; the CLEU heal add-back is the deferred fix (design §5).",
        "healPolluted": True,
    },
    792: {
        "name": "Jin'do the Hexxer",
        "note": "healed by adds — same invisible-heal pollution as Sulfuron. Reserved for the CLEU tier.",
        "healPolluted": True,
    },
    715: {
        "name": "Twin Emperors",
        "note": "two bosses share one health pool readout and swap places; the true remaining pool is not\n    -- visible to health polling alone. Reserved for the CLEU/second-pool tier.",
        "secondPool": True,
    },
    789: {
        "name": "High Priest Thekal",
        "note": "he RESURRECTS — the pool refills mid-encounter, so the old pool's \"about to die\" must not\n    -- bleed into the new one (`resetOnRise`, learned: 30/30 kills show a >=25% one-sample rise). NOTE the id:\n    -- Thekal is 789 and Gahz'ranka is 790 — verified against WCL fixture names; keying the reset on 790 would\n    -- silently no-op. The caps still quiet the bar: measured 55-100% error in EVERY bin (three priests behind\n    -- one health readout), so the reset improves the underlying estimate without yet making it showable.",
    },
    790: {"name": "Gahz'ranka (the id next to Thekal's — must NOT carry his reset)"},
    709: {"name": "The Prophet Skeram"},
    616: {"name": "Chromaggus"},
    713: {"name": "Viscidus"},
    716: {"name": "Ouro"},
    719: {"name": "General Rajaxx"},
    717: {"name": "C'Thun"},
    1084: {"name": "Onyxia"},
}


def parse_candidate(path):
    """Pull the learned fields out of a candidate file (a tiny, fixed Lua literal we emit ourselves)."""
    txt = open(path).read()
    out = {}
    m = re.search(r"encounterID\s*=\s*(\d+)", txt)
    if not m:
        return None, None
    enc = int(m.group(1))
    m = re.search(r"kills\s*=\s*(\d+)", txt)
    if m:
        out["kills"] = int(m.group(1))
    m = re.search(r"confCap\s*=\s*\{(.*?)\}", txt, re.S)
    if m:
        out["confCap"] = {int(k): float(v) for k, v in re.findall(r"\[(\d+)\]\s*=\s*([\d.]+)", m.group(1))}
    m = re.search(r"resetOnRise\s*=\s*([\d.]+)", txt)
    if m:
        out["resetOnRise"] = float(m.group(1))
    return enc, out


# ── gather: learned candidates (Fresh ids) → classic ids ────────────────────────────────────────────
learned = {}
for path in sorted(glob.glob("tools/candidates/regime-*.lua")):
    enc, fields = parse_candidate(path)
    if enc is None:
        continue
    classic = enc - FRESH_OFFSET if enc >= FRESH_OFFSET else enc
    learned[classic] = fields

ids = sorted(set(learned) | set(FACTS))
if not ids:
    sys.exit("no candidates and no facts — nothing to assemble")


def fmt_cap(caps):
    """Render the LEARNED caps descending.

    The universal floor is deliberately NOT folded in: it is the blanket assumption for bosses nobody has
    measured, and where we HAVE measured, the measurement wins. Folding it in anyway silenced bins the data
    shows are accurate (Chromaggus' 90-95% band is among the most readable in the corpus, yet the blanket
    floor hid it and made his grade worse). Un-profiled bosses still get the floor via ns.Regimes.default.
    """
    merged = {b: v for b, v in (caps or {}).items() if v < 0.995}  # only caps that bite
    return ", ".join(f"[{b}] = {round(merged[b], 2)}" for b in sorted(merged, reverse=True))


blocks = []
for cid in ids:
    fields = learned.get(cid, {})
    facts = FACTS.get(cid, {})
    name = facts.get("name", f"encounter {cid}")
    # A boss we have MEASURED always ships a profile — even one with no caps. "Measured: nothing to cap" is
    # a real finding, and the profile's presence is what stops `regimeFor` falling back to the blanket
    # default (which would re-impose the very caps the measurement refuted). Only a boss with neither
    # measurement nor a categorical fact is skipped.
    has_content = (
        cid in learned
        or bool(fields.get("confCap") or fields.get("resetOnRise"))
        or any(k in facts for k in ("hideBar", "suppressFlush", "healPolluted", "secondPool"))
    )
    if not has_content:
        continue
    lines = [f"    -- {name}" + (f" — {facts['note']}" if facts.get("note") else "")]
    lines.append(f"    [{cid}] = {{")
    if facts.get("hideBar"):
        lines.append("        hideBar = true,")
    if facts.get("suppressFlush"):
        lines.append("        suppressFlush = true,")
    if fields.get("resetOnRise"):
        lines.append(f"        resetOnRise = {fields['resetOnRise']},")
    if not facts.get("hideBar"):  # a hidden bar needs no confidence cap
        caps = fields.get("confCap") or {}
        # If EVERY bin measured below the client's show threshold, the readout is unusable for the whole
        # fight. The scalar form says that in one line instead of twenty zeroes — behaviourally identical
        # (all bins already hide), and it stays a measured claim rather than a hand-authored hideBar.
        if len(caps) == BINS and max(caps.values()) < SHOW_THRESHOLD:
            lines.append(f"        confCap = {round(max(caps.values()), 2)}, -- every bin measured unreadable")
        else:
            cap = fmt_cap(caps)
            if cap:
                lines.append(f"        confCap = {{ {cap} }},")
            elif cid in learned:
                lines.append(
                    "        -- measured: the readout is reliable across this fight, so nothing is capped."
                )
                lines.append(
                    "        -- The profile exists so the blanket default cap does NOT apply to it."
                )
    # Reserved CLEU slots — inert today, forward-compatible (design §2.1).
    for slot in ("healPolluted", "secondPool"):
        if facts.get(slot):
            lines.append(f"        {slot} = true, -- reserved for the CLEU tier (inert today)")
    if fields.get("kills"):
        lines.append(f"        kills = {fields['kills']},")
    lines.append("    },")
    blocks.append("\n".join(lines))

header = f"""local _, ns = ...

-- Per-encounter REGIME PROFILES (WO-075 / D-014) — the fight's STRUCTURE that a health curve alone can't
-- convey, consumed by nil-guarded seams in the estimator: `confCap` (where the readout is measurably wrong,
-- cap confidence so the bar goes QUIET rather than showing a confident-wrong countdown), `hideBar` (health
-- is pure noise), `suppressFlush` (scripted chunk damage must not trigger the regime-change flush), and
-- `resetOnRise` (a phase reset starts a fresh pool).
-- Injected as `opts.regime` behind the frozen estimator API; every field is optional, an absent field is a
-- no-op, and `regime = nil` reproduces the baseline EXACTLY. Kept separate from rhythms.lua so the two
-- pipelines never mix. Dual-keyed classic + WCL-Fresh (+{FRESH_OFFSET}).
--
-- AUTO-GENERATED by tools/assemble-regimes.py from the lab's tools/candidates/regime-*.lua (numeric fields
-- learned by tools/learn-regime.py from the estimator's own measured per-bin error on real kills) plus the
-- hand-authored categorical facts in that script. NEVER hand-edit this file — change a fact or re-learn,
-- then re-run the assembler.

-- The universal raid gate — folded into every profile below and returned for un-profiled boss-level
-- targets: raids open slow, so the bar is never certain at/near full health.
local DEFAULT_CONFCAP = {{ {", ".join(f"[{b}] = {v}" for b, v in sorted(DEFAULT_CONFCAP.items(), reverse=True))} }}

local profiles = {{
"""

footer = f"""}}

-- Key aliasing (mirrors rhythms.lua): the live client fires the classic DungeonEncounterID in
-- ENCOUNTER_START; WCL's Fresh partition names the same encounter at +{FRESH_OFFSET}. Alias both so either
-- reality resolves; the in-game /reload confirms which. `default` is the un-profiled boss fallback.
local regimes = {{ default = {{ confCap = DEFAULT_CONFCAP }} }}
for id, prof in pairs(profiles) do
    regimes[id] = prof
    regimes[id + {FRESH_OFFSET}] = prof
end

ns.Regimes = regimes
"""

out = header + "\n".join(blocks) + "\n" + footer

# Luacheck caps lines at 120 (W631). StyLua re-wraps long CODE lines, but never comments — so a long note in
# FACTS would silently break the gate on a file nobody hand-edits. Fail here instead, pointing at the line.
too_long = [
    (i, ln) for i, ln in enumerate(out.splitlines(), 1) if len(ln) > 120 and ln.lstrip().startswith("--")
]
if too_long:
    for i, ln in too_long:
        sys.stderr.write(f"error: generated comment line {i} is {len(ln)} chars (>120): {ln[:80]}...\n")
    sys.exit("aborting: shorten the offending note in FACTS (the linter would reject this file)")

if DRY:
    print(out)
else:
    with open(OUT, "w") as fh:
        fh.write(out)
    print(f"assembled {len(blocks)} regime profiles → {OUT}")
    for cid in ids:
        if cid in learned:
            print(f"  [{cid:>5}] {FACTS.get(cid, {}).get('name', '?')}  (learned)")
