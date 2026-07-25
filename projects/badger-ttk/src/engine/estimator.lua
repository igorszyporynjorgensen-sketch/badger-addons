local _, ns = ...

-- Pure TTK estimator: feed (t, healthFraction) samples, read a smoothed time-to-kill + confidence. No
-- WoW API and no frames — a driver samples UnitHealth and calls sample()/ttk(); this stays plain Lua so
-- it runs under Busted. The estimate is an EWMA of the health-loss RATE (fraction/second); the
-- `reactivity` setting (0..1) maps to the EWMA time-constant λ. Inspiration:
-- docs/reference/ttk-estimator-inspiration.md (mined for approach, not copied).
--
-- Prepared for boss phase/state: sample() takes an optional `damageable` flag to pause through immune /
-- hardened phases (e.g. C'Thun's body between "Weakened" windows, a boss submerge) so those zero-damage
-- stretches never corrupt the rate. A per-encounter weakened/hardened *damage-taken modifier* is a
-- future hook fed the same way (from a boss profile / the encounter registry, WO #6 / WO-014).

local Estimator = {}
Estimator.__index = Estimator

local LAMBDA_MIN = 0.5 -- seconds — most reactive (reactivity = 1): snappy but noisier
local LAMBDA_MAX = 5.0 -- seconds — most stable (reactivity = 0): smooth but slower
local DEFAULT_RATE_FLOOR = 0.0002 -- fraction/sec; below this the target is ~not dying → TTK unknown
local CONF_SAMPLES = 8 -- rate updates to reach full confidence

local function clamp01(x)
    if x < 0 then
        return 0
    elseif x > 1 then
        return 1
    end
    return x
end

local function lambdaFor(reactivity)
    return LAMBDA_MAX - clamp01(reactivity or 0.5) * (LAMBDA_MAX - LAMBDA_MIN)
end

-- opts: { reactivity, executeThreshold, executeModifier, rateFloor, history }. The caller (a driver)
-- reads these from db.profile and passes plain values; the estimator never touches db or the WoW API.
function Estimator.new(opts)
    opts = opts or {}
    local self = setmetatable({}, Estimator)
    self.lambda = lambdaFor(opts.reactivity)
    self.executeThreshold = opts.executeThreshold or 0
    self.executeModifier = opts.executeModifier or 1
    self.rateFloor = opts.rateFloor or DEFAULT_RATE_FLOOR
    -- WO-014 seam: an imported E(h) history profile to blend with the live estimate. v1 leaves it nil
    -- and stays pure-live; WO-014 reads it in ttk() without changing this interface.
    self.history = opts.history
    self:reset()
    return self
end

-- Clear all live state — call on a target change so one target's rate never bleeds into the next.
function Estimator:reset()
    self.prevT = nil
    self.prevH = nil
    self.lastH = nil
    self.rate = nil -- EWMA of the health-loss rate (fraction/sec)
    self.updates = 0 -- rate updates since reset, for warm-up / confidence
end

-- Feed one sample: t (seconds, monotonic), h (health fraction in [0,1]). `damageable` defaults true;
-- pass false during an immune / hardened phase so the estimator neither measures a rate nor bridges one
-- across the gap — it drops its previous reference and the last live estimate simply holds until damage
-- resumes.
function Estimator:sample(t, h, damageable)
    if damageable == false then
        self.prevT = nil
        return
    end
    if self.prevT ~= nil then
        local dt = t - self.prevT
        if dt > 0 then
            local r = (self.prevH - h) / dt
            if r < 0 then
                r = 0 -- a heal never shortens TTK or drives the rate negative
            end
            local alpha = 1 - math.exp(-dt / self.lambda)
            if self.rate == nil then
                self.rate = r
            else
                self.rate = alpha * r + (1 - alpha) * self.rate
            end
            self.updates = self.updates + 1
        end
    end
    self.prevT = t
    self.prevH = h
    self.lastH = h
end

-- Returns (ttk_seconds, confidence) — ttk is nil while warming up or when the target is ~not dying.
function Estimator:ttk()
    if self.rate == nil or self.rate < self.rateFloor or self.lastH == nil then
        return nil, 0
    end
    local ttk = self.lastH / self.rate
    -- Execute-phase correction: below the threshold a plain linear model over-estimates (raids dump
    -- burst), so shorten. A real history curve (WO-014) captures this and would supersede it.
    if self.lastH < self.executeThreshold then
        ttk = ttk / self.executeModifier
    end
    -- WO-014: if self.history is set, blend `ttk` with self.history:project(self.lastH) here.
    return ttk, clamp01(self.updates / CONF_SAMPLES)
end

ns.Estimator = Estimator
