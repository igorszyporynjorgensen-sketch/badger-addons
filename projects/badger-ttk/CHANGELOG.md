## 0.9.48 (2026-08-01)

### Added

- **The bar now goes quiet instead of guessing.** On fights (and phases) where a boss's health simply can't
  tell you when it will die, the countdown now hides rather than showing a confident, wrong number. Which
  fights those are wasn't guessed — it was **measured** across ~900 real raid kills, per boss and per health
  range, so the bar stays up wherever it's actually trustworthy.
  - **Buru the Gorger** is the big win: his scripted egg damage used to wreck the estimate, and the countdown
    is now roughly **five times closer** (it used to read over a minute long; now it's a few seconds off).
  - **Twin Emperors** and **High Priest Thekal** stay quiet — two bosses sharing one health readout, and a
    boss who resurrects, genuinely can't be read from health alone.
  - **General Rajaxx** hides during his opening waves, **Viscidus** through his freeze phases, **Skeram**
    around his images, **C'Thun** behind his opening gate, and **Onyxia** through the air phase.
  - **Majordomo Executus** no longer shows a bar at all — his encounter ends with his adds, not his health.
  - Bosses the measurements found perfectly readable (**Chromaggus**, **Ouro**) are untouched.
- **Thekal's resurrect is understood.** When he refills his health mid-fight, the estimate starts fresh
  instead of dragging the old pool's "about to die" into the new one.

### Changed

- Estimates on every other fight — and all solo play — are **completely unchanged**.

## 0.9.47 (2026-07-30)

### Added

- **Onyxia now anticipated.** The TTK bar reads Onyxia's fight shape — the fast ground phase, the ~50%-health
  **air phase** where she's untargetable (whelps out), and the final execute burn — instead of assuming
  steady damage. Learned from real raid kills and validated on held-out fights, like the other boss rhythms.
  Applies automatically when the encounter starts; no configuration. (Naxxramas still awaits a log corpus.)

### ❤️ Thank You

- Claude Opus 4.8 (1M context)
- Igor Szyporyn

## 0.9.46 (2026-07-30)

### Changed

- **Kill history now records the full Warcraft-Logs-shaped record** for each kill — encounter/creature,
  fight duration, group size & composition, and a timestamp — instead of a single running-mean rate. This
  makes your own kills forward-compatible with the planned log-import (they'll blend into one prior). *One
  time only:* existing pre-1.0 kill history (the old running-mean data) is reset on upgrade; it rebuilds as
  you play.

## [0.9.45] - 2026-07-30

### Added
- **Learned boss rhythms — Molten Core, Blackwing Lair, Zul'Gurub & both Ahn'Qiraj raids.** The TTK
  bar now *anticipates* each boss's fight shape — slow pulls, Frenzy lulls, priest-heal suppression,
  Viscidus' freeze phases, C'Thun's weakness windows, execute burns — using rhythm profiles for **41
  bosses across five raids**, learned from ~2,000 real raid kills (Warcraft Logs) and validated on
  held-out kills. Applies automatically when the encounter starts; no configuration. (Excluded:
  Majordomo and Edge of Madness — their encounters aren't a single boss-health curve; Naxxramas and
  Onyxia await a usable log corpus.)

## [0.9.44] - 2026-07-29

### Added
- **Naxxramas** in the raid show-gating list — every boss from Anub'Rekhan to Kel'Thuzad.

### Changed
- Tidied the options: Display controls grouped into logical rows (placement, size, opacity), a wider
  ability-offset slider with clearer per-ability sections, and cleaner Behavior/Estimator layouts.

## [0.9.43] - 2026-07-29

First public (pre-1.0) release.

### Added
- **Time-to-kill bar** — a right-anchored countdown to your target's death, driven by an event-interval
  ("chunk clock") estimator that stays smooth even against big, spiky melee hits and **learns your kill
  speed per mob and per level**.
- **Utility cooldown-timing bars** — *waiting → fire now → fired* — so each cooldown's buff lands on the
  kill. Ships with a curated set of Warrior cooldowns & on-use trinkets, plus per-raid and per-encounter
  show-gating (Molten Core through Temple of Ahn'Qiraj).
- **Icons** — ability icons on the utility bars, and your target's **live portrait** on the TTK bar.
- **Skins** — LibSharedMedia textures/fonts/borders, five independent state colours, and per-ability
  colour overrides. **Save, delete, export & import** named skins. Built-in **Default** and **Modern**
  skins.
- **Deep configuration** — full Display, Behavior and Readout options; a minimum-TTK and
  minimum-confidence gate; estimator reactivity; per-character or shared **profiles**; and a live
  **Preview** mode with play/pause for styling your bars without a target.
