# 🦡 Badger Time To Kill (TTK)

**Know exactly how long your target has left — and exactly when to fire every cooldown so its buff lands on the kill.**

Badger TTK drops a clean, right-anchored **time-to-kill bar** on your screen that counts your target down to zero, driven by a genuinely smart estimator. Above it, **utility timing bars** tell you the precise moment to pop each trinket and cooldown so the buff actually covers the kill — no more burning a 20-second trinket on a mob that dies in eight.

Built for **WoW Classic Era & Hardcore**. Open the config with **`/bttk`** (or `/badgerttk`).

---

## ⚡ A time-to-kill estimate that doesn't lie

Most TTK tools jitter — the number leaps up and down every swing until it's useless. Badger's estimator is an **event-interval "chunk clock"**: instead of naïvely differentiating your target's health every frame, it measures each hit as a *chunk-over-time* event, so the readout **glides down like a real countdown** even against big, spiky melee damage.

- 🧠 **Learns as you play** — it records your kill speed per mob **and** per level, so you get an accurate estimate from the very first tick of a familiar fight.
- 🎚️ **Confidence-gated** — bars only appear once the estimate is actually trustworthy; a tunable threshold stops trash mobs from flashing them up.
- 🛡️ **Handles the messy stuff** — immune/hardened phases, heals, execute-phase burst, and real kill-speed changes (heroism, adds dying) are tracked, not fumbled.
- 📌 **Sticky when it counts** — once the bars are up they stay through the endgame, right when the "fire now" call matters most.

## 🎯 Fire cooldowns at the perfect moment

Each utility bar shows the optimal moment to fire a cooldown so its buff spans the kill, with a dead-simple action signal:

**Waiting** → **FIRE NOW!** (green) → **Fired** (draining)

- Fire late? The bar flashes a green "you're behind" window so you can see it at a glance.
- Per-ability **enable / timing offset / colour** overrides.
- Ships with a curated set of **Warrior** cooldowns & on-use trinkets, plus per-raid & per-encounter show-gating so the bars only appear where they matter.

## 🎨 Ridiculously configurable

This is where Badger TTK shows off. Everything lives in a clean, searchable config window:

**📐 Display** — screen anchor, drag-to-move with a lock toggle, horizontal/vertical offset, scale, growth direction, bar width, **independent TTK & utility bar heights**, spacing, max bars, container opacity, **separate foreground & background bar opacity**, frame strata, and per-text X/Y nudges for both bar types.

**🖌️ Look & Skins** — LibSharedMedia textures, fonts & borders, font sizes, and **five fully independent colours** (TTK target · utility waiting / fire / fired · bar text).
- **Save** your current look as a named skin; **Delete** ones you don't want.
- **Export** any skin to a paste-ready snippet and **Import** skins from friends — share your themes.
- Ships with **Default** and **Modern** built-in skins.

**⚙️ Behavior** — master on/off, in-combat-only, hide-on-dead, hostile-only, show-any-target, show-utility-outside-raid, a **minimum-TTK gate**, a **minimum-confidence gate**, estimator **reactivity** (stability vs. snappiness), execute-phase tuning, and kill-history recording toggles.

**🔎 Readout** — bar names, countdown timers, **icons** (each utility bar shows its ability's icon; the TTK bar shows your target's **live portrait**), `m:ss` or raw seconds, trend band, and confidence.

**✨ And the niceties** — full **profile** support (per-character or shared, copy & reset), a **live Preview mode** with play/pause so you can style your bars with no target in sight, and quick **Lock / Show-preview / Play** controls right in the window header.

## 📥 Getting started

1. Install and `/reload`.
2. Type **`/bttk`** to open the config.
3. Attack something — the TTK bar appears. Tweak the **Display** and **Skin** nodes to taste.
4. Try the **Modern** skin, or craft your own and **Export** it to share.

---

*Lightweight, no bloat, one tidy window. Made with 🦡 by Scan Design Media.*
