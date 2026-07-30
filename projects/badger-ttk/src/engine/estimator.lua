local _, ns = ...

-- Pure TTK estimator — event-interval design ("chunk clock", WO-056). No WoW API and no frames — a
-- driver samples UnitHealth and calls sample()/ttk(); this stays plain Lua so it runs under Busted.
--
-- WHY THIS SHAPE: health under WoW melee is a staircase — big chunks every couple of seconds, nothing
-- between. The previous estimator differentiated that staircase per 0.15s poll, producing an impulse
-- train (a 30% hit read as chunk/0.15 = ~15x the true rate; the ~16 ticks between read 0) and then
-- smoothed the impulses with an EWMA — a structural, seconds-scale sawtooth the reactivity slider could
-- not fix (WO-056's three-analyst diagnosis + unanimous four-design judge panel). Here a health DROP is
-- an EVENT observed as (chunk, span since the previous event); the rate is a fading ratio — the
-- exponentially-forgotten sum of chunks over the exponentially-forgotten sum of spans. Periodic hits C
-- every P seconds yield exactly C/P (zero ripple, by construction); continuous decay telescopes to the
-- exact rate. Between events the fit is FROZEN and ttk() counts down by wall clock like a timer,
-- re-syncing at each event and pausing at a grace boundary when a hit is overdue.
--
-- The kill-history prior (WO-025) enters in the SAME units as live evidence: priorWeight pseudo-seconds
-- of observation at priorRate. Before the first hit the estimate is exactly h/priorRate (immediate and
-- steady); as real events fold in, the prior fades at exactly the pace evidence arrives.
--
-- Regime changes (heroism, adds dying, execute dumps) are caught by a two-consecutive-events flush:
-- an observation ≥ JUMP_RATIO out of band arms a counter, a second consecutive one fires it, and the
-- run's own events become the new evidence. Two panel-mandated grafts harden this: the band is compared
-- against the belief FROZEN when the run armed (folding burst events lifts the live belief enough that
-- the second test narrowly fails — all three judges measured ZERO flushes on a ×3 burst without this),
-- and the flush RE-SEEDS the evidence from the triggering run itself rather than scaling the old sums
-- (which would preserve the old regime's ratio and slow adoption ~2x).
--
-- Prepared for boss phase/state: sample() takes an optional `damageable` flag to pause through immune /
-- hardened phases (e.g. C'Thun's body between "Weakened" windows, a boss submerge) so those zero-damage
-- stretches never corrupt the rate. A per-encounter weakened/hardened *damage-taken modifier* is a
-- future hook fed the same way (from a boss profile / the encounter registry, WO #6 / WO-014).

local Estimator = {}
Estimator.__index = Estimator

local TAU_MIN = 2.0 -- s of damage-time memory at reactivity 1 (~1 swing): snappy but jumpier
local TAU_MAX = 10.0 -- s at reactivity 0 (~4 swings): smooth but slower to genuine change
local DEFAULT_RATE_FLOOR = 0.0002 -- fraction/s; below this the target is ~not dying → TTK unknown
local PRIOR_FLOOR = 0.5 -- with a prior, the effective rate never falls below this × the prior,
-- so staleness decay can't balloon TTK beyond ~2× the historical estimate
local PRIOR_WEIGHT_DEFAULT = 6.0 -- prior strength: pseudo-seconds of observation (opts.priorWeight)
local CONF_TIME = 6.0 -- observed damage-seconds to full confidence...
local CONF_EVENTS = 3 -- ...AND at least this many damage events (min of the two ramps)
local INTERVAL_BLEND = 0.3 -- weight of the newest inter-event span in the typical-span EWMA
local GRACE_MULT = 1.5 -- staleness grace = this × the typical span (a normal gap is not evidence)
local GRACE_MIN, GRACE_MAX = 1.0, 6.0 -- grace clamp, seconds
local SPAN_CAP = 15.0 -- cap any event's span (a long disengage is ~starting over, not one giant gap)
local FIRST_SPAN_MAX = 4.0 -- event #1: idle watching before the pull is not combat time
local FIRST_SPAN_MIN = 1.5 -- event #1, discrete hits: one chunk can't fairly claim under ~half a swing
local DISCRETE_CHUNK = 0.02 -- a ≥2% drop in one poll = discrete-hit combat (the floor above applies);
-- smaller drops are continuous decay, which must stay EXACT from the first changed tick
local JUMP_RATIO = 2.5 -- obs vs belief ratio that arms the regime-change flush
local JUMP_COUNT = 2 -- consecutive out-of-band events to fire (a lone crit can never flush)
local JUMP_KEEP = 0.25 -- a flush keeps this fraction of the PRIOR (old sums are replaced by the run)

local function clamp01(x)
    if x < 0 then
        return 0
    elseif x > 1 then
        return 1
    end
    return x
end

local function tauFor(reactivity)
    return TAU_MAX - clamp01(reactivity or 0.5) * (TAU_MAX - TAU_MIN)
end

-- opts: { reactivity, executeThreshold, executeModifier, rateFloor, priorRate, priorWeight, rhythm }.
-- The caller (a driver) reads these from db.profile and passes plain values; the estimator never touches
-- db or the WoW API. priorWeight is optional and defaulted — existing call sites are untouched.
function Estimator.new(opts)
    opts = opts or {}
    local self = setmetatable({}, Estimator)
    self.tau = tauFor(opts.reactivity)
    self.executeThreshold = opts.executeThreshold or 0
    self.executeModifier = opts.executeModifier or 1
    self.rateFloor = opts.rateFloor or DEFAULT_RATE_FLOOR
    self.priorRate = opts.priorRate
    self.priorWeight = opts.priorWeight or PRIOR_WEIGHT_DEFAULT
    -- Rhythm profile (WO-069): an INJECTED dependency — the encounter's learned SHAPE (see
    -- src/raids/rhythms.lua). The driver resolves which profile applies and passes it here; the
    -- estimator never looks anything up. nil ⇒ exactly the previous behavior.
    self.rhythm = opts.rhythm
    self:reset()
    return self
end

-- Clear all live state — call on a target change so one target's evidence never bleeds into the next.
function Estimator:reset()
    self.lastH = nil -- current health fraction; the level reference for the next chunk
    self.prevSampleT = nil -- last damageable sample time; nil = reference dropped (pre-first / immune)
    self.openSpan = 0 -- damageable seconds since the last event (frozen through holds)
    self.sumD = 0 -- fading damage evidence (health fraction)
    self.sumT = 0 -- fading time evidence (seconds)
    self.priorT = (self.priorRate and self.priorRate > 0) and self.priorWeight or 0
    self.pRef = nil -- smoothed typical inter-event span (drives the staleness grace)
    self.events = 0 -- damage events since reset
    self.dmgTime = 0 -- un-faded damage-observation seconds since the first event (confidence only)
    self.jumpHi, self.jumpLo = 0, 0 -- consecutive out-of-band event counters
    self.jumpBase = nil -- belief FROZEN when a run armed (graft: a self-healing base goes deaf)
    self.runD, self.runT = 0, 0 -- the armed run's own evidence (graft: re-seeds the fit on flush)
    self.slowFlushed = false -- a jumpLo flush fired: live evidence proved the fight SLOWER than the
    -- prior, so the prior floor must stop binding (WO-061 — it capped genuinely slow fights forever)
end

-- Feed one sample: t (seconds, monotonic), h (health fraction in [0,1]). `damageable` defaults true;
-- pass false during an immune / hardened phase — the reference drops, all evidence and the open span
-- freeze, and ttk() holds bit-identically until damage resumes.
function Estimator:sample(t, h, damageable)
    if damageable == false then
        self.prevSampleT = nil
        return
    end
    if self.prevSampleT == nil then
        -- (Re)acquire: first sample ever, or damage resuming after a hold. Re-anchor WITHOUT an event
        -- so an h change during the hold can never read as a chunk or bridge a rate across the gap.
        self.prevSampleT = t
        self.lastH = h
        return
    end
    local dt = t - self.prevSampleT
    if dt <= 0 then
        return -- same-frame duplicate; a drop simply merges into the next tick's chunk
    end
    self.prevSampleT = t
    if self.events > 0 then
        self.dmgTime = self.dmgTime + dt
    end
    self.openSpan = self.openSpan + dt
    local drop = self.lastH - h
    if drop > 0 then
        -- EVENT: `drop` arrived over `openSpan` damageable seconds.
        local span = self.openSpan
        if span > SPAN_CAP then
            span = SPAN_CAP
        end
        if self.events == 0 then
            if span > FIRST_SPAN_MAX then
                span = FIRST_SPAN_MAX
            end
            if drop >= DISCRETE_CHUNK and span < FIRST_SPAN_MIN then
                span = FIRST_SPAN_MIN
            end
        end
        -- Regime change? Compare the observation against belief BEFORE folding it in. While a run is
        -- armed the band uses the belief FROZEN at arming (jumpBase) — comparing against the live,
        -- self-healing belief provably never reaches two-in-a-row on a real ×3 burst.
        local obs = drop / span
        local den = self.sumT + self.priorT
        local flushed = false
        if den > 0 then
            local belief = (self.sumD + (self.priorRate or 0) * self.priorT) / den
            if belief > 0 then
                local base = self.jumpBase or belief
                if obs > base * JUMP_RATIO then
                    if self.jumpHi == 0 then
                        self.jumpBase, self.runD, self.runT = belief, 0, 0
                    end
                    self.jumpHi, self.jumpLo = self.jumpHi + 1, 0
                elseif obs * JUMP_RATIO < base then
                    if self.jumpLo == 0 then
                        self.jumpBase, self.runD, self.runT = belief, 0, 0
                    end
                    self.jumpLo, self.jumpHi = self.jumpLo + 1, 0
                else
                    self.jumpHi, self.jumpLo, self.jumpBase = 0, 0, nil
                end
                if self.jumpHi > 0 or self.jumpLo > 0 then
                    self.runD, self.runT = self.runD + drop, self.runT + span
                end
                if self.jumpHi >= JUMP_COUNT or self.jumpLo >= JUMP_COUNT then
                    -- The kill speed genuinely changed. RE-SEED: the run's own events become the
                    -- evidence (scaling the old sums would keep the old regime's ratio), and the
                    -- prior mostly yields — it described the old regime.
                    if self.jumpLo >= JUMP_COUNT then
                        self.slowFlushed = true -- release the prior floor: this fight IS slower
                    end
                    self.sumD, self.sumT = self.runD, self.runT
                    self.priorT = self.priorT * JUMP_KEEP
                    self.jumpHi, self.jumpLo, self.jumpBase = 0, 0, nil
                    self.runD, self.runT = 0, 0
                    flushed = true
                end
            end
        end
        if not flushed then
            -- Fold with duration-weighted fading: older evidence decays by the span just observed, so
            -- memory is measured in damage-time (τ seconds of it), not in tick counts.
            local q = math.exp(-span / self.tau)
            self.sumD = self.sumD * q + drop
            self.sumT = self.sumT * q + span
            self.priorT = self.priorT * q
        end
        self.pRef = (self.pRef == nil) and span
            or (INTERVAL_BLEND * span + (1 - INTERVAL_BLEND) * self.pRef)
        self.events = self.events + 1
        self.openSpan = 0
        self.lastH = h
    elseif drop < 0 then
        -- Heal: raise the level reference only — no event, nothing negative; openSpan keeps timing
        -- the next chunk (a heal doesn't reset the swing clock).
        self.lastH = h
    end
    -- drop == 0: a waiting tick carries no rate information; openSpan already advanced.
end

-- Returns (ttk_seconds, confidence) — ttk is nil while unknown (no evidence and no prior) or when the
-- target is ~not dying. Confidence ramps 0→1 with observed damage EVIDENCE (time and events), never
-- with zero-information waiting ticks — so the prior keeps steadying the early fight instead of dying
-- 1.2 seconds in (the old tick-counting bug that neutered the history blend).
function Estimator:ttk()
    if self.lastH == nil then
        return nil, 0
    end
    local a = self.dmgTime / CONF_TIME
    local b = self.events / CONF_EVENTS
    local conf = clamp01(a < b and a or b)
    -- Staleness: inside a normal between-hit gap the fit is FROZEN (a waiting tick carries no rate
    -- information). Only open-interval time beyond the grace counts, folded as a zero-damage
    -- observation-in-progress — silence decays the rate smoothly instead of exponentially-per-tick.
    local pending, tickdown = 0, 0
    if self.events > 0 then
        local grace = GRACE_MULT * self.pRef
        if grace < GRACE_MIN then
            grace = GRACE_MIN
        elseif grace > GRACE_MAX then
            grace = GRACE_MAX
        end
        if self.openSpan > grace then
            pending = self.openSpan - grace
        end
        tickdown = (self.openSpan < grace) and self.openSpan or grace
    end
    local f = math.exp(-pending / self.tau)
    local num = self.sumD * f
    local den = self.sumT * f + pending
    if self.priorRate and self.priorRate > 0 then
        -- Bayesian pseudo-observations: priorT seconds at the recorded rate, in the evidence units.
        num = num + self.priorRate * self.priorT
        den = den + self.priorT
    end
    if den <= 0 then
        return nil, conf -- no evidence, no prior: unknown
    end
    -- A full-strength history prior IS confidence (WO-061): its evidence share starts at 1 (instant
    -- show on a history-backed pull) and fades exactly as live evidence takes over — while the live
    -- ramp rises complementarily. Unknown mobs still ramp from 0, so the slider gates as labeled.
    if self.priorRate and self.priorRate > 0 and self.priorT > 0 then
        local share = self.priorT / den
        if share > conf then
            conf = share
        end
    end
    local rate = num / den
    if self.priorRate and self.priorRate > 0 and not self.slowFlushed then
        -- Cap STALENESS balloons at ~2x history — but never live contrarian evidence: once a jumpLo
        -- flush proved the fight slower, the floor yields (WO-061; it used to bind forever).
        local floor = self.priorRate * PRIOR_FLOOR
        if rate < floor then
            rate = floor
        end
    end
    if rate < self.rateFloor then
        return nil, conf
    end
    local ttk
    if self.rhythm and self.rhythm.bins and #self.rhythm.bins > 0 then
        -- Rhythm-aware remaining time (WO-069): live rate calibrates the SCALE (this group's speed),
        -- the profile supplies the SHAPE (what the fight does next). m(h) = rate at health h relative
        -- to the fight average; implied average R = rate / m(hNow); remaining = S(h) / R with
        -- S(h) = ∫₀ʰ dh'/m (piecewise-constant bins; bins[1] = the execute end). m ≡ 1 reproduces
        -- lastH/rate exactly. Validated on nine MC encounters' held-out kills (median error ~halved).
        -- The profile SUBSUMES the execute correction — its execute bins ARE the per-boss measured
        -- version of that guess, so applying both would double-count.
        local bins = self.rhythm.bins
        local K = #bins
        local h = self.lastH
        local idx = math.floor(h * K) + 1
        if idx > K then
            idx = K
        end
        local w = 1 / K
        local S = 0
        for i = 1, idx - 1 do
            S = S + w / bins[i]
        end
        S = S + (h - (idx - 1) * w) / bins[idx]
        ttk = S * bins[idx] / rate
    else
        ttk = self.lastH / rate
        -- Execute-phase correction: below the threshold a plain linear model over-estimates (raids
        -- dump burst), so shorten.
        if self.lastH < self.executeThreshold then
            ttk = ttk / self.executeModifier
        end
    end
    -- The between-event countdown: the readout falls 1s per second like a timer, re-syncing at each
    -- event and pausing at the grace boundary when a hit is overdue (it never marches to zero on a
    -- target nobody is hitting).
    ttk = ttk - tickdown
    if ttk < 0.05 then
        -- Overdue countdowns floor just above zero: the display maps ttk <= 0 to "no data", which
        -- blanked the text + utility bars on a still-alive target (WO-061). nil stays the only unknown.
        ttk = 0.05
    end
    return ttk, conf
end

ns.Estimator = Estimator
