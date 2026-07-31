local _, ns = ...

-- Per-encounter REGIME PROFILES (WO-075 / D-014) — the fight's STRUCTURE that the health curve alone can't
-- convey, consumed by nil-guarded seams in the estimator: `freeze` bands (untargetable / stall phases hold
-- the countdown), `hideBar` (health is pure noise → no bar), `confCap` (unreadable phases → the bar goes
-- QUIET instead of showing a confident-wrong number), `resetOnRise` (phase-reset bosses). Injected as
-- `opts.regime` behind the frozen estimator API; every field is optional, an absent field is a no-op, and
-- `regime = nil` reproduces the baseline exactly. Kept SEPARATE from rhythms.lua so the two pipelines never
-- mix. Dual-keyed classic + WCL-Fresh (+150000), like rhythms.
--
-- PR1 (0.9.48): the health-only structural wins provable today — Onyxia's air-phase stall freeze, Majordomo
-- hidden, and the universal raid `confCap` floor folded into every profile. Values are hand-authored domain
-- facts + Onyxia's band derived from its corpus stall analysis (a ~7-8s flat-health hold at ~48-52% in
-- melee-heavy kills); `tools/learn-regime.py` formalizes learned confCap/bands as the roster grows (PR2+).

-- The universal raid gate — folded into every profile below and returned for un-profiled boss-level targets.
-- Raids open slow and the bar is never certain at/near full health.
local DEFAULT_CONFCAP = { [20] = 0.0, [19] = 0.10 }

local profiles = {
    -- Onyxia — the air phase (~35-60% health) is untargetable to melee, so the countdown reads long there.
    -- Learned from 200 real kills: across raids the air phase is a SLOWDOWN, not a true stall (health keeps
    -- falling via ranged), so a stall-gated FREEZE is the wrong tool — it does nothing or over-holds and
    -- reads worse (measured: a heavy right tail). The honest fix is a per-health-bin confCap over the
    -- air-phase bins: the bar goes QUIET where the fight is unreadable instead of guessing. Result vs the
    -- 0.9.47 rhythm baseline: MAPE mean 57%→44%, reads-long bias +41s→+20s (bar shown ~55%, quiet through
    -- the air phase + the pull). Bins are K=20 (bin 20 = h∈(0.95,1], bin 8 ≈ h∈(0.35,0.40]); values here are
    -- hand-derived from the air-phase health range — tools/learn-regime.py formalizes them (per-bin CV) in
    -- PR2. Fresh 151084 → classic 1084.
    [1084] = {
        confCap = {
            [20] = 0.0,
            [19] = 0.10,
            [12] = 0.4,
            [11] = 0.4,
            [10] = 0.4,
            [9] = 0.4,
            [8] = 0.4,
        },
        kills = 200,
    },
    -- Majordomo Executus — the encounter ends by killing his four Flamewaker adds, not him; his own health
    -- is pure noise, so never show a countdown. The CLEU add-counter that turns this "estimable" is a
    -- deferred future WO (design §5). Fresh 150671 → classic 671.
    [671] = {
        hideBar = true,
    },
}

-- Key aliasing (mirrors rhythms.lua): the live client fires the classic DungeonEncounterID in
-- ENCOUNTER_START; WCL's Fresh partition names the same encounter at +150000. Alias both so either reality
-- resolves; the in-game /reload confirms which. `default` is the un-profiled fallback (see driver.regimeFor).
local regimes = { default = { confCap = DEFAULT_CONFCAP } }
for id, prof in pairs(profiles) do
    regimes[id] = prof
    regimes[id + 150000] = prof
end

ns.Regimes = regimes
