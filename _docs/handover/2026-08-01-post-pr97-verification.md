---
title: Next-session prompt — badger-ttk, post PR #97 verification
type: handover-prompt
date: 2026-08-01
branch: docs/D-021-IJ-pr97-verification
pr: https://github.com/igorszyporynjorgensen-sketch/badger-addons/pull/99
related:
  - docs/handover-2026-08-01.md
  - docs/reference/pr97-verification-2026-08-01.md
  - docs/reference/in-game-verification.md
  - docs/decisions.md
---

# Next-session prompt — badger-ttk, post PR #97 verification

Paste the block below as the **first message** of the next session. Everything it refers to is committed;
the narrative version is [`docs/handover-2026-08-01.md`](../../docs/handover-2026-08-01.md) and the canonical
state is [`docs/decisions.md`](../../docs/decisions.md) *Current state*.

## Where things stood when this was written

| | |
|---|---|
| **Shipped** | 0.9.48 (regime layer). GitHub-only — **not** on CurseForge. |
| **Gate** | green at `71273d7`, `pnpm validate --skip-nx-cache`, 0 warnings / 0 errors, 33 files. |
| **1.0.0 blocker** | one — the in-game `/reload`. Not done. |
| **PR #97 verification** | done. 32 agents, 18 candidates → 6 confirmed + 1 unrefuted. |
| **Open PR** | [#99](https://github.com/igorszyporynjorgensen-sketch/badger-addons/pull/99) — the docs this prompt points at. |
| **Next ids** | `D-022-IJ`, `WO-076-IJ`. |

**The finding that matters:** the regime layer's confidence caps were *learned* and *graded* under a show
gate the client does not implement. `driver.lua:67` consults confidence only while `not wasShown`, so once
the bar latches in any health bin every later cap — including a hard `0.0` — is unreachable. Viscidus's
shipped profile is bit-identical to shipping no regime at all; Skeram and Sulfuron are ~nullified. No player
sees a wrong number; the bar just stays up where the lab thought it went quiet. The fix is instrument-side.

**The question that outranks it:** `regimeFor` engages only when `UnitLevel("target") == -1`, and nobody has
verified that on a live instanced Era boss. If it reports a number, the regime layer has been inert for
everyone since release. One `/run` line settles it — protocol step **B5**.

## The prompt

```text
Picking up badger-ttk. You'll be on branch docs/D-021-IJ-pr97-verification — that's
deliberate; PR #99 carries these docs and main doesn't have them yet. If I've already merged
it, switch to main and pull first.

Read docs/handover-2026-08-01.md first, then
docs/reference/pr97-verification-2026-08-01.md ("Read this first" section), then
docs/decisions.md "Current state". Those are canonical.

Short version: 0.9.48 shipped the regime layer. The PR #97 verification is DONE — 32 agents,
6 confirmed findings. The big one is that THE LAB DOES NOT MODEL THE CLIENT: the driver's
show gate is sticky (confidence is only checked before the bar's first appearance), but the
grader and the learner both assume a cap can hide the bar in any bin. Result: Viscidus's
shipped profile is bit-identical to having no regime at all, Skeram and Sulfuron are
~nullified. No player sees a wrong number — the bar just stays up where we thought it went
quiet. The fix is instrument-side and cannot regress the addon.

A real in-game /reload is still the only 1.0.0 gate. I still haven't done it.

Do these in order:

1. Confirm the terminal MCP is live. I approved it at startup this time. You should have
   write_to_terminal / read_terminal_output / send_control_character from the `terminal`
   server (iterm-mcp@1.2.6, absolute path in .mcp.json). If they're NOT there, say so
   plainly — don't work around it silently. Diagnosis triad: no tools + no mcp-logs-terminal
   dir in ~/Library/Caches/claude-cli-nodejs/-Users-scandesign-PetProjects-badger-addons/ +
   empty enabledMcpjsonServers in ~/.claude.json. Once live, run lab/learning commands in MY
   terminal so I can watch them.

2. Propose WO-076-IJ: make the lab model the client. Instrument-only, so it cannot regress
   the addon:
     - teach estimator-batch.lua / estimator-perbin.lua the sticky gate (wasShown)
     - fix learn-regime.py:207-208's per-bin independent-hide assumption
     - pass damageable = not dead instead of hard-coding true
     - re-learn + re-grade, and show me the diff against the shipped caps
     - fix regimes_spec's "empty profile" test to accept a kills-only profile (D-019(b)
       already decided this — the spec is wrong, not the generator)
   Propose it, wait for me to set it Accepted, then branch + PR. I merge, you never do.

3. WO-077-IJ (can go first if you prefer, it's smaller): the two test holes — the per-bin
   confCap path has no test that it ever caps, and resetOnRise's magnitude threshold is
   untested. Both are pure spec additions.

4. DO NOT touch finding 5 (Thekal resetOnRise / the damageable hold) — parked by D-021-IJ.
   Can't be tested without a real ZG kill; the suspect code is on every boss's path and a
   blind change risks the regime==nil byte-identity guarantee. WO-076's instrument fix may
   dissolve it on its own. Also don't act on finding 7 — it never got an adversarial pass.

5. When I next log in, remind me to run protocol step B5 from
   docs/reference/in-game-verification.md: one /run line checking UnitLevel("target") == -1.
   If an instanced Era boss reports a number instead of -1, regimeFor never fires and the
   whole regime layer has been inert for every player since release. That outranks
   everything above.

Reminders: PATH="$HOME/.luarocks/bin:$PATH" for the gate, and --skip-nx-cache when the answer
matters (a cached green gate means nothing ran — it bit us). tools/fights/corpus/ is
disposable. Learning is client-side only, never CI. No version bump without a deliberate
release. Link PR numbers as clickable URLs. Don't run big multi-agent sweeps unless I ask.
```

## Standing constraints the prompt assumes

- **Nothing lands without explicit acceptance.** `docs/` is the standing exception for *editing*; everything
  else is propose-then-act. Code reaches `main` only via a branch + PR, and **the human merges** — always.
- **Work-order files live-mirror to `main`** (no branch/PR); the code they drive does not.
- **A version bump is a deliberate release act** (D-011). Conventional commits only decide *how much*.
- **[D-021-IJ]** — a finding that can be neither confirmed nor refuted is **parked**, and does not license a
  change to shared code.
