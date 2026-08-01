---
title: In-game verification (/reload checklist)
type: reference
related:
  - docs/decisions.md
  - docs/handover-2026-08-01.md
---

# In-game verification — the `/reload` checklist

The gate the off-client suite **cannot** cover: `pnpm validate` proves lint/format/tests, never that the addon
loads and behaves in WoW. Passing this unlocks **1.0.0** and every CurseForge upload (D-015).

Written for **0.9.48** (the regime layer), but it is the standing ritual for any release.

## Install

```
projects/badger-ttk/.release/BadgerTTK/          →  <WoW>/_classic_era_/Interface/AddOns/BadgerTTK/
```
or unzip the release asset `BadgerTTK-0.9.48.zip` into `Interface/AddOns/`. Then either restart the client or
`/reload`. **Enable Lua errors first** — silent failures are the thing we're hunting:

```
/console scriptErrors 1
```

---

## Pass A — solo, ~5 minutes (this is the one that unblocks 1.0.0)

Everything here works on any mob in the world; no raid needed.

**A1. It loads clean.**
`/reload` → no Lua error popup, no red text. Confirm it's actually loaded and at the right version:
```
/dump GetAddOnMetadata("BadgerTTK","Version")
```
Expect `0.9.48`.

**A2. The Interface number matches the live build.**
```
/run print((select(4, GetBuildInfo())))
```
Compare with `## Interface: 11509` in the `.toc`. If it differs, tell me the number — it's a one-line fix.
(A mismatch usually shows as the addon being flagged out-of-date rather than failing outright.)

**A3. The config opens.**
```
/badgerttk        (or /bttk)
```
The tree window with the Badger banner should open. Click through **Display · Behavior · Readout · Raids ·
Skins · Simulation** — no errors, nothing blank.

**A4. Bars track a real target.**
Attack any mob that lives more than ~10 seconds. Expect: the TTK bar appears once the estimate is confident
and counts **down** smoothly; the utility bars move through *waiting → fire now → fired*. (Defaults hide the
bar below **10s** TTK and below **0.5** confidence — both in Behavior if you want to poke them.)

**A5. Kill history is recording** (the D-012 schema from 0.9.46). Kill a few mobs, then `/reload` (saved
variables only flush on reload/logout), then:
```
/run local h=BadgerTTKDB and BadgerTTKDB.global and BadgerTTKDB.global.history local e,c=0,0 if h then for _ in pairs(h.encounter or {}) do e=e+1 end for _ in pairs(h.creature or {}) do c=c+1 end end print("history — encounter ids:",e," creature ids:",c)
```
Expect `creature ids` > 0 after solo kills. (`encounter ids` only fills on instanced bosses.)

> **Pass A is the 1.0.0 gate.** If A1–A5 are clean, 1.0.0 can be cut and CurseForge can be uploaded.

---

## Pass B — in a raid (confirms the 0.9.48 regime layer)

Do this whenever you next raid; it isn't required for 1.0.0, but it's what proves the new behaviour.

**B1. The encounter id-space — the one genuinely open question.**
Profiles are dual-keyed (`663` classic **and** `150663` Fresh) so either resolves, but we've never confirmed
which one the live client fires. Paste this **after every `/reload`**, then pull any boss:

```
/run local f=CreateFrame("Frame") f:RegisterEvent("ENCOUNTER_START") f:SetScript("OnEvent",function(_,_,id,name) print("|cff00ff00BadgerTTK id-check:|r",id,name) end) print("id-check armed")
```

It prints the id + boss name on the pull. **Tell me that number** — e.g. Lucifron printing `663` vs `150663`
settles it for good and lets us drop the aliasing if we want.

**B2. The bar goes quiet where it should.** New in 0.9.48 — expect *no bar* (or a bar that appears late)
rather than a confident wrong number:

| boss | expected |
|---|---|
| **Majordomo Executus** | **no TTK bar at all** (his fight is his adds) |
| **Twin Emperors**, **High Priest Thekal** | effectively silent the whole fight |
| **General Rajaxx** | quiet through the opening waves, then normal |
| **Viscidus** | quiet through the freeze/shatter phases |
| **Onyxia** | quiet through the air phase, normal on the ground |
| **Chromaggus**, **Ouro** | completely normal — measured as readable, deliberately untouched |
| **Buru the Gorger** | should now read *much* closer than before (was ~1 min long) |

**B3. Nothing else changed.** On any boss without a profile — and on all solo play — the bar should behave
exactly as it did in 0.9.47. This is guaranteed by construction (byte-identical when no regime applies), so a
difference here is a genuine bug worth reporting.

---

## Reporting back

Short is fine. The three things that matter most:

1. **Pass A clean?** yes / no (+ the exact error text if not)
2. **The build number** from A2, if it isn't `11509`
3. **The encounter id** from B1, when you next raid — `663`-style or `150663`-style

Anything unexpected: `/console scriptErrors 1`, reproduce, and paste the error — the first line and the file
path in it are usually enough to locate it exactly.
