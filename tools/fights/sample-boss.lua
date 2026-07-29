-- A synthetic "realistic boss" fight for validating the replay grader (WO-067) until a real Warcraft Logs
-- trace is pasted in. The importer (piece 2) will emit this exact shape: { name, samples = { {t, h}, ... } }
-- — the boss's health FRACTION over time, polled at the driver's 0.15s cadence. Deterministic (fixed LCG)
-- so runs reproduce. ~200s: a steady phase 1, a Bloodlust surge at ~45% HP, an execute burst under 20%,
-- and a brief mid-fight lull (a mechanic where damage stops) — all rhythm for the estimator to track.
local DT = 0.15
local seed = 7
local function rnd()
    seed = (seed * 1103515245 + 12345) % 2147483648
    return seed / 2147483648
end

local samples, t, h = {}, 0, 1.0
while h > 0 do
    samples[#samples + 1] = { t = t, h = h }
    local rate
    if h > 0.45 then
        rate = 1 / 210 -- phase 1: steady raid chip
    elseif h > 0.20 then
        rate = 1.6 / 210 -- Bloodlust / Heroism
    else
        rate = 2.4 / 210 -- execute
    end
    local lull = (t >= 60 and t < 65) -- a 5s mechanic: no damage on the boss
    if not lull then
        h = h - rate * DT * (0.8 + 0.4 * rnd())
    end
    t = t + DT
end
samples[#samples + 1] = { t = t, h = 0 }

return { name = "sample-boss (P1 / Bloodlust / execute, with a 5s lull)", samples = samples }
