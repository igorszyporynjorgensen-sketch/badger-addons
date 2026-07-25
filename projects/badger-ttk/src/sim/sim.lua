local _, ns = ...

-- Pure sim driver: produce the render model the display draws from a scripted scenario — no live target,
-- no frames, no estimator. The dynamic preview is a DETERMINISTIC countdown (TTK = total − t) so the bars
-- are steady on a fixed timeline (WO-018); the estimator's live / immune-pause behavior is covered by the
-- engine specs, not here. Composes ns.RenderModel + ns.SimScenario. (Loaded after the engine + scenario.)

local RenderModel = ns.RenderModel

local Sim = {}

-- Replay `scenario` at time `t` (seconds into the fight). Returns (renderModel, ttk, health). TTK counts
-- down linearly from `total` to 0; each pop is active once the countdown has passed its fire moment
-- (t ≥ total − fireTTK) with its remaining duration, else planned. `total` is passed to RenderModel.build
-- as the fixed-timeline scale, which is what makes the bars hold steady.
function Sim.run(scenario, t)
    local total = scenario.total
    local ttk = total - t
    if ttk < 0 then
        ttk = 0
    end
    local health = (total > 0) and (ttk / total) or 0

    local entries = {}
    local pops = scenario.pops
    for i = 1, #pops do
        local p = pops[i]
        local entry = {
            id = p.id,
            name = p.name,
            duration = p.duration,
            cooldown = p.cooldown,
            offset = p.offset or 0,
        }
        local fireT = total - p.fireTTK -- seconds into the fight when the pop is used
        if t >= fireT then
            entry.active = true
            entry.remaining = math.max(0, (fireT + p.duration) - t)
        end
        entries[#entries + 1] = entry
    end

    return RenderModel.build(ttk, entries, total), ttk, health
end

-- A frozen, representative model for styling: a planned pop-line plus active bars that fit, over-cover
-- (Diamond Flask 60s outlasts the 50s kill → clamped to full width, demonstrating the width cap), and fall
-- short — on the same fixed 50s timeline as the dynamic sim so the preview matches its scale.
function Sim.staticPreview()
    local total = 50
    local ttk = 30
    local entries = {
        { id = "planned", name = "Recklessness", duration = 20, cooldown = 180, offset = 0 },
        { id = "fits", name = "Death Wish", active = true, remaining = 30, offset = 0 },
        { id = "over", name = "Diamond Flask", active = true, remaining = 60, offset = 0 },
        { id = "short", name = "Earthstrike", active = true, remaining = 12, offset = 0 },
    }
    return RenderModel.build(ttk, entries, total)
end

ns.Sim = Sim
