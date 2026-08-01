-- SHARED grading harness for the off-client lab (WO-076). Extracted from estimator-batch.lua /
-- estimator-replay.lua / estimator-perbin.lua, which had carried three copies of the same gate — and
-- three copies of the same bug.
--
-- WHY THIS EXISTS: the lab must model the CLIENT, not an idealised version of it. The client's show gate
-- is STICKY (src/live/driver.lua:55-80): `minTTK` and `minConfidenceToShow` are consulted only while
-- `not wasShown`, so once the bar latches in any health bin every later confidence cap — including a hard
-- 0.0 — is unreachable. The graders used to re-test confidence on every tick independently, so a cap
-- appeared to hide the bar mid-fight. It cannot. Caps learned under the old assumption are dead data:
-- Viscidus's shipped profile is bit-identical to shipping no regime at all, and Onyxia's `[11] = 0.0`
-- (the air phase — the fight's worst bin) never fires. See docs/workorders/WO-076-IJ.md.

local M = {}

-- Grading window. Both ends are about measurement noise, NOT about what the client shows.
M.WARMUP = 3.0 -- ignore the opening: no evidence yet
M.TAIL = 6.0 -- ignore the last seconds: as actual→0 the % error explodes for any tiny miss

-- The client's defaults (src/core.lua:22-23). Model BOTH terms of the gate: they sit in the same
-- `not wasShown` block, and while raid kills run 100-200s the corpus also holds 10-12s Lucifron kills
-- where the predicted TTK genuinely crosses minTTK.
M.MINCONF = 0.5 -- minConfidenceToShow
M.MINTTK = 10 -- minTTK

local Gate = {}
Gate.__index = Gate

-- A sticky show gate. Mirrors driver.lua's ordering; the contextual terms it drops (enabled, hasTarget,
-- inCombat, hostile) are all constant-true in a health-curve replay, and `dead` is covered by TAIL.
function M.newGate(minConf, minTTK)
    return setmetatable({
        shown = false,
        minConf = minConf or M.MINCONF,
        minTTK = minTTK or M.MINTTK,
    }, Gate)
end

-- Feed EVERY tick, in order — including ticks outside the grading window. The bar can latch during the
-- warm-up, so a gate that only sees in-scope ticks latches late and understates the divergence.
-- Returns whether the bar is on screen for this tick.
function Gate:update(pred, conf)
    if self.shown then
        return true -- sticky: a mid-fight confidence dip never hides the bars (driver.lua:75-77)
    end
    if not (pred and pred >= self.minTTK) then
        return false
    end
    -- No confidence info → no gate, exactly as the driver treats a nil `context.conf`.
    if self.minConf > 0 and conf and conf < self.minConf then
        return false
    end
    self.shown = true
    return true
end

-- Has the bar latched yet? (Reachability: a confCap can only ever act while this is false.)
function Gate:latched()
    return self.shown
end

-- `damageable` for a replayed curve. The graders used to hard-code `true`; a fight file's curve ends at
-- death, and a dead boss is not damageable. The estimator has accepted the flag since estimator.lua:128.
function M.damageable(h)
    return (h or 0) > 0
end

return M
