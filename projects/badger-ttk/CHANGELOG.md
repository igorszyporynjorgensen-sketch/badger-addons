# Changelog

All notable, player-facing changes to **Badger Time To Kill (TTK)**. Version numbers match the addon's
`## Version` (and each CurseForge upload). Newest first. Format: [Keep a Changelog](https://keepachangelog.com/).

<!-- RELEASE PROCESS: accumulate changes under [Unreleased]. When a version bumps the .toc, rename
     [Unreleased] to "## [x.y.z] - YYYY-MM-DD" and paste that section's body into the CurseForge file's
     "Changelog" box on upload. Then start a fresh empty [Unreleased] above it. -->

## [Unreleased]

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
